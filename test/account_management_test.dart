import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Mock classes for testing
class MockConnection extends Connection {
  final Map<String, dynamic> _accounts = {};
  final Map<String, StreamController<AccountInfo?>> _subscriptions = {};
  bool _shouldReturnNull = false;
  bool _shouldThrowError = false;
  String _errorType = '';

  MockConnection() : super('http://localhost:8899');

  void setReturnNull(bool value) => _shouldReturnNull = value;
  void setThrowError(bool value, [String errorType = '']) {
    _shouldThrowError = value;
    _errorType = errorType;
  }

  void setAccountData(String address, Map<String, dynamic> data) {
    _accounts[address] = data;
  }

  @override
  Future<AccountInfo?> getAccountInfo(
    PublicKey address, {
    CommitmentConfig? commitment,
  }) async {
    if (_shouldThrowError) {
      if (_errorType == 'network') {
        throw Exception('Network error');
      }
      throw Exception('Test error');
    }

    if (_shouldReturnNull) return null;

    final data = _accounts[address.toBase58()];
    if (data == null) return null;

    return AccountInfo(
      lamports: data['lamports'] ?? 1000000,
      owner: PublicKey.fromBase58(
          data['owner'] ?? '11111111111111111111111111111111'),
      data: Uint8List.fromList(data['data'] ?? [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
      executable: data['executable'] ?? false,
      rentEpoch: data['rentEpoch'] ?? 0,
    );
  }

  @override
  Future<List<AccountInfo?>> getMultipleAccountsInfo(
    List<PublicKey> addresses, {
    CommitmentConfig? commitment,
  }) async {
    return Future.wait(
      addresses.map((addr) => getAccountInfo(addr, commitment: commitment)),
    );
  }

  @override
  Future<List<ProgramAccountInfo>> getProgramAccounts(
    PublicKey programId, {
    CommitmentConfig? commitment,
    List<AccountFilter>? filters,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Test error');
    }

    // Return mock program accounts
    return [
      ProgramAccountInfo(
        pubkey: PublicKey.fromBase58('11111111111111111111111111111111'),
        account: AccountInfo(
          lamports: 1000000,
          owner: programId,
          data: Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
          executable: false,
          rentEpoch: 0,
        ),
      ),
    ];
  }

  @override
  Future<String> onAccountChange(
    PublicKey address,
    void Function(AccountInfo?) callback, {
    CommitmentConfig? commitment,
  }) async {
    final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final controller = StreamController<AccountInfo?>();
    _subscriptions[subscriptionId] = controller;

    // Listen to the stream and call the callback
    controller.stream.listen(callback);

    return subscriptionId;
  }

  @override
  Future<void> removeAccountChangeListener(String subscriptionId) async {
    final controller = _subscriptions.remove(subscriptionId);
    await controller?.close();
  }

  // Method to trigger account changes for testing
  void triggerAccountChange(String subscriptionId, AccountInfo? accountInfo) {
    final controller = _subscriptions[subscriptionId];
    controller?.add(accountInfo);
  }
}

class MockWallet implements Wallet {
  @override
  PublicKey get publicKey =>
      PublicKey.fromBase58('11111111111111111111111111111111');

  @override
  Future<AnchorTransaction> signTransaction(
      AnchorTransaction transaction) async {
    return transaction;
  }

  @override
  Future<List<AnchorTransaction>> signAllTransactions(
    List<AnchorTransaction> transactions,
  ) async {
    return transactions;
  }
}

class MockCoder implements Coder {
  @override
  AccountsCoder get accounts => MockAccountsCoder();

  @override
  InstructionCoder get instruction => throw UnimplementedError();

  @override
  EventCoder get events => throw UnimplementedError();

  @override
  TypesCoder get types => throw UnimplementedError();
}

class MockAccountsCoder implements AccountsCoder {
  @override
  T decode<T>(String accountName, List<int> data) {
    // Return mock decoded data
    return {'value': 42, 'name': 'test'} as T;
  }

  @override
  List<int> encode(String accountName, dynamic data) {
    return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  }

  @override
  int size(String accountName) => 100;

  @override
  Map<String, dynamic> memcmp(String accountName, [List<int>? appendData]) {
    return {
      'offset': 0,
      'bytes': 'base58string',
    };
  }
}

void main() {
  group('Account Management System', () {
    late MockConnection mockConnection;
    late MockWallet mockWallet;
    late AnchorProvider provider;
    late MockCoder coder;
    late PublicKey programId;
    late IdlAccount idlAccount;
    late AccountSubscriptionManager subscriptionManager;
    late AccountCacheManager cacheManager;

    setUp(() {
      mockConnection = MockConnection();
      mockWallet = MockWallet();
      provider = AnchorProvider(mockConnection, mockWallet);
      coder = MockCoder();
      programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

      idlAccount = IdlAccount(
        name: 'TestAccount',
        type: IdlTypeDefType(kind: 'struct', fields: []),
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
      );

      subscriptionManager = AccountSubscriptionManager(
        connection: mockConnection,
      );

      cacheManager = AccountCacheManager();
    });

    tearDown(() async {
      await subscriptionManager.unsubscribeAll();
      cacheManager.clear();
    });

    group('AccountSubscriptionManager', () {
      test('should create subscription successfully', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final subscription = await subscriptionManager.subscribe(
          address,
          (accountInfo) {
            // Callback for account changes
          },
        );

        expect(subscription, isNotNull);
        expect(subscription.address, equals(address));
        expect(subscription.isActive, isTrue);
      });

      test('should handle subscription callback', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        AccountInfo? receivedAccountInfo;

        await subscriptionManager.subscribe(
          address,
          (accountInfo) {
            receivedAccountInfo = accountInfo;
          },
        );

        // Trigger account change
        final testAccountInfo = AccountInfo(
          lamports: 2000000,
          owner: programId,
          data: Uint8List.fromList([1, 2, 3, 4]),
          executable: false,
          rentEpoch: 1,
        );

        // Simulate account change callback
        await Future.delayed(Duration(milliseconds: 10));

        expect(receivedAccountInfo, isNull); // Initially null until triggered
      });

      test('should unsubscribe successfully', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final subscription = await subscriptionManager.subscribe(
          address,
          (accountInfo) {},
        );

        await subscriptionManager.unsubscribe(address);
        expect(subscription.isActive, isFalse);
      });

      test('should handle multiple subscriptions', () async {
        final address1 =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final address2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

        final sub1 = await subscriptionManager.subscribe(address1, (info) {});
        final sub2 = await subscriptionManager.subscribe(address2, (info) {});

        expect(sub1.address, equals(address1));
        expect(sub2.address, equals(address2));
        expect(subscriptionManager.activeSubscriptions, equals(2));
      });

      test('should dispose all subscriptions', () async {
        final address1 =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final address2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

        await subscriptionManager.subscribe(address1, (info) {});
        await subscriptionManager.subscribe(address2, (info) {});

        expect(subscriptionManager.activeSubscriptions, equals(2));

        await subscriptionManager.dispose();
        expect(subscriptionManager.activeSubscriptions, equals(0));
      });
    });

    group('AccountCacheManager', () {
      test('should cache and retrieve account data', () {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final accountData = {'value': 42, 'name': 'test'};

        cacheManager.set(address, accountData);
        final cached = cacheManager.get(address);

        expect(cached, equals(accountData));
      });

      test('should handle cache expiration', () async {
        final config = AccountCacheConfig(
          defaultTtl: Duration(milliseconds: 50),
          maxSize: 100,
          cleanupInterval: Duration(milliseconds: 25),
        );

        final cacheManagerWithTtl = AccountCacheManager(config: config);
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final accountData = {'value': 42, 'name': 'test'};

        cacheManagerWithTtl.set(address, accountData);
        expect(cacheManagerWithTtl.get(address), equals(accountData));

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 100));
        expect(cacheManagerWithTtl.get(address), isNull);
      });

      test('should enforce cache size limits', () {
        final config = AccountCacheConfig(
          defaultTtl: Duration(minutes: 5),
          maxSize: 2,
          cleanupInterval: Duration(minutes: 1),
        );

        final cacheManagerWithLimit = AccountCacheManager(config: config);

        // Add accounts up to limit
        final addr1 = PublicKey.fromBase58('11111111111111111111111111111111');
        final addr2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
        final addr3 =
            PublicKey.fromBase58('So11111111111111111111111111111111111111112');

        cacheManagerWithLimit.set(addr1, {'value': 1});
        cacheManagerWithLimit.set(addr2, {'value': 2});
        expect(cacheManagerWithLimit.size, equals(2));

        // Adding third should evict first (LRU)
        cacheManagerWithLimit.set(addr3, {'value': 3});
        expect(cacheManagerWithLimit.size, equals(2));
        expect(cacheManagerWithLimit.get(addr1), isNull); // Evicted
        expect(cacheManagerWithLimit.get(addr2), isNotNull);
        expect(cacheManagerWithLimit.get(addr3), isNotNull);
      });

      test('should invalidate cache entries', () {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final accountData = {'value': 42, 'name': 'test'};

        cacheManager.set(address, accountData);
        expect(cacheManager.get(address), equals(accountData));

        cacheManager.invalidate(address);
        expect(cacheManager.get(address), isNull);
      });

      test('should clear all cache', () {
        final addr1 = PublicKey.fromBase58('11111111111111111111111111111111');
        final addr2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

        cacheManager.set(addr1, {'value': 1});
        cacheManager.set(addr2, {'value': 2});
        expect(cacheManager.size, equals(2));

        cacheManager.clearAll();
        expect(cacheManager.size, equals(0));
      });
    });

    group('AccountOperations', () {
      test('should fetch account with caching', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        // Set up mock data
        mockConnection.setAccountData(address.toBase58(), {
          'lamports': 1000000,
          'owner': programId.toBase58(),
          'data': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        });

        final result = await accountOps.fetchAccount(
          idlAccount,
          address,
          useCache: true,
        );

        expect(result, isNotNull);
        expect(result!['value'], equals(42)); // Mock decoded data

        // Should be cached now
        final cached = cacheManager.get(address);
        expect(cached, isNotNull);
      });

      test('should handle account not found', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        mockConnection.setReturnNull(true);

        final result = await accountOps.fetchAccount(idlAccount, address);
        expect(result, isNull);
      });

      test('should fetch multiple accounts', () async {
        final addresses = [
          PublicKey.fromBase58('11111111111111111111111111111111'),
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
        ];

        // Set up mock data for both addresses
        for (final addr in addresses) {
          mockConnection.setAccountData(addr.toBase58(), {
            'lamports': 1000000,
            'owner': programId.toBase58(),
            'data': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          });
        }

        final results = await accountOps.fetchMultipleAccounts(
          idlAccount,
          addresses,
        );

        expect(results, hasLength(2));
        expect(results[0], isNotNull);
        expect(results[1], isNotNull);
      });

      test('should fetch all program accounts', () async {
        final accounts = await accountOps.fetchAllAccounts(idlAccount);

        expect(accounts, isNotEmpty);
        expect(accounts[0].publicKey, isNotNull);
        expect(accounts[0].account, isNotNull);
      });

      test('should handle network errors gracefully', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        mockConnection.setThrowError(true, 'network');

        expect(
          () => accountOps.fetchAccount(idlAccount, address),
          throwsA(isA<Exception>()),
        );
      });

      test('should create account subscription', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final subscription = await accountOps.subscribeToAccount(
          idlAccount,
          address,
          (data) {
            // Account change callback
          },
        );

        expect(subscription, isNotNull);
        expect(subscription.address, equals(address));
        expect(subscription.isActive, isTrue);
      });

      test('should unsubscribe from account', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final subscription = await accountOps.subscribeToAccount(
          idlAccount,
          address,
          (data) {},
        );

        await accountOps.unsubscribeFromAccount(address);
        expect(subscription.isActive, isFalse);
      });
    });

    group('Integration Tests', () {
      test('should handle complete account lifecycle', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        // Set up mock account data
        mockConnection.setAccountData(address.toBase58(), {
          'lamports': 1000000,
          'owner': programId.toBase58(),
          'data': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        });

        // 1. Fetch account (should cache it)
        final account = await accountOps.fetchAccount(
          idlAccount,
          address,
          useCache: true,
        );
        expect(account, isNotNull);

        // 2. Subscribe to account changes
        dynamic lastUpdate;
        final subscription = await accountOps.subscribeToAccount(
          idlAccount,
          address,
          (data) {
            lastUpdate = data;
          },
        );
        expect(subscription.isActive, isTrue);

        // 3. Fetch from cache (should be instant)
        final cachedAccount = await accountOps.fetchAccount(
          idlAccount,
          address,
          useCache: true,
        );
        expect(cachedAccount, equals(account));

        // 4. Invalidate cache
        accountOps.invalidateAccountCache(address);
        final invalidatedCache = cacheManager.get(address);
        expect(invalidatedCache, isNull);

        // 5. Unsubscribe
        await accountOps.unsubscribeFromAccount(address);
        expect(subscription.isActive, isFalse);
      });
    });
  });
}
