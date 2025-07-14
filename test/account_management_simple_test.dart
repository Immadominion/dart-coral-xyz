import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Mock classes for testing
class MockConnection extends Connection {

  MockConnection() : super('http://localhost:8899');
  final Map<String, dynamic> _accounts = {};
  bool _shouldReturnNull = false;

  void setReturnNull(bool value) => _shouldReturnNull = value;

  void setAccountData(String address, Map<String, dynamic> data) {
    _accounts[address] = data;
  }

  @override
  Future<AccountInfo?> getAccountInfo(
    PublicKey address, {
    CommitmentConfig? commitment,
  }) async {
    if (_shouldReturnNull) return null;

    final data = _accounts[address.toBase58()];
    if (data == null) return null;

    return AccountInfo(
      lamports: (data['lamports'] is int)
          ? data['lamports'] as int
          : int.tryParse(data['lamports']?.toString() ?? '') ?? 1000000,
      owner: PublicKey.fromBase58(
          data['owner']?.toString() ?? '11111111111111111111111111111111',),
      data: Uint8List.fromList((data['data'] is List<int>)
          ? data['data'] as List<int>
          : (data['data'] is List)
              ? List<int>.from(data['data'] as List)
              : [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],),
      executable: (data['executable'] is bool)
          ? data['executable'] as bool
          : (data['executable']?.toString() == 'true'),
      rentEpoch: (data['rentEpoch'] is int)
          ? data['rentEpoch'] as int
          : int.tryParse(data['rentEpoch']?.toString() ?? '') ?? 0,
    );
  }

  Future<String> onAccountChange(
    PublicKey address,
    void Function(AccountInfo?) callback, {
    CommitmentConfig? commitment,
  }) async => 'subscription_id_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> removeAccountChangeListener(String subscriptionId) async {
    // Mock implementation
  }
}

void main() {
  group('Account Management System', () {
    late MockConnection mockConnection;
    late AccountSubscriptionManager subscriptionManager;
    late AccountCacheManager<dynamic> cacheManager;

    setUp(() {
      mockConnection = MockConnection();
      subscriptionManager = AccountSubscriptionManager(
        connection: mockConnection,
      );
      cacheManager = AccountCacheManager();
    });

    tearDown(() async {
      cacheManager.clear();
    });

    group('AccountSubscriptionManager', () {
      test('should create subscription stream', () {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final stream = subscriptionManager.subscribe(address);
        expect(stream, isA<Stream<AccountChangeNotification>>());
      });

      test('should handle subscription', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final stream = await subscriptionManager.subscribe(address);
        expect(stream, isNotNull);

        // Test that we can listen to the stream
        final subscription = stream.listen((notification) {
          // Handle notification
        });

        await subscription.cancel();
      });
    });

    group('AccountCacheManager', () {
      test('should cache and retrieve account data', () {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final accountData = {'value': 42, 'name': 'test'};

        cacheManager.put(address, accountData);
        final cached = cacheManager.get(address);

        expect(cached, equals(accountData));
      });

      test('should handle cache invalidation', () {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final accountData = {'value': 42, 'name': 'test'};

        cacheManager.put(address, accountData);
        expect(cacheManager.get(address), equals(accountData));

        cacheManager.remove(address);
        expect(cacheManager.get(address), isNull);
      });

      test('should clear all cache', () {
        final addr1 = PublicKey.fromBase58('11111111111111111111111111111111');
        final addr2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

        cacheManager.put(addr1, {'value': 1});
        cacheManager.put(addr2, {'value': 2});
        expect(cacheManager.getStatistics().currentSize, greaterThan(0));

        cacheManager.clear();
        expect(cacheManager.getStatistics().currentSize, equals(0));
      });

      test('should handle cache operations', () {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final accountData = {'value': 42, 'name': 'test'};

        // Put data in cache
        cacheManager.put(address, accountData);
        expect(cacheManager.get(address), equals(accountData));

        // Verify cache statistics
        final stats = cacheManager.getStatistics();
        expect(stats.currentSize, equals(1));
      });
    });

    group('Integration Tests', () {
      test('should handle account fetching with caching', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        // Set up mock data
        mockConnection.setAccountData(address.toBase58(), {
          'lamports': 1000000,
          'owner': '11111111111111111111111111111111',
          'data': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        });

        // Fetch account info
        final accountInfo = await mockConnection.getAccountInfo(address);
        expect(accountInfo, isNotNull);

        // Cache the account data
        cacheManager.put(address, {'decoded': 'data'});

        // Verify caching
        final cached = cacheManager.get(address);
        expect(cached, equals({'decoded': 'data'}));
      });

      test('should handle subscription lifecycle', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        // Create subscription
        final stream = await subscriptionManager.subscribe(address);
        expect(stream, isNotNull);

        // Listen to the stream
        final subscription = stream.listen((notification) {
          // Handle notification
        });

        // Clean up
        await subscription.cancel();
      });

      test('should handle cache invalidation on account changes', () async {
        final address =
            PublicKey.fromBase58('11111111111111111111111111111111');

        // Cache some data
        cacheManager.put(address, {'value': 42});
        expect(cacheManager.get(address), isNotNull);

        // Subscribe to account changes
        final stream = await subscriptionManager.subscribe(address);
        final subscription = stream.listen((notification) {
          // Remove cache entry on account change
          cacheManager.remove(address);
        });

        // Manually remove cache entry to simulate account change
        cacheManager.remove(address);
        expect(cacheManager.get(address), isNull);

        await subscription.cancel();
      });
    });
  });
}
