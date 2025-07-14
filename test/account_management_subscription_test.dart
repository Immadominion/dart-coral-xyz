/// Test suite for Account Management and Subscription System
///
/// This test validates Step 7.2 implementation including real-time
/// account subscriptions, intelligent caching, and comprehensive
/// account management operations.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Test helper classes
class MockAccountData {

  const MockAccountData({
    required this.value,
    required this.name,
    required this.owner,
  });
  final int value;
  final String name;
  final PublicKey owner;

  Map<String, dynamic> toJson() => {
        'value': value,
        'name': name,
        'owner': owner.toBase58(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MockAccountData &&
        other.value == value &&
        other.name == name &&
        other.owner == owner;
  }

  @override
  int get hashCode => Object.hash(value, name, owner);
}

void main() {
  group('Account Management and Subscription System', () {
    late PublicKey programId;
    late PublicKey accountAddress;
    late Connection connection;
    late AnchorProvider provider;
    late Idl idl;

    setUp(() {
      programId = PublicKey.fromBase58('11111111111111111111111111111111');
      accountAddress = PublicKey.fromBase58('22222222222222222222222222222222');
      connection = Connection('https://api.devnet.solana.com');
      provider = AnchorProvider.defaultProvider();

      // Create test IDL
      idl = Idl(
        address: programId.toBase58(),
        metadata: const IdlMetadata(
          name: 'TestProgram',
          version: '0.1.0',
          spec: 'anchor-idl/0.1.0',
        ),
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'value', type: IdlType.u64()),
                IdlField(name: 'name', type: IdlType.string()),
                IdlField(name: 'owner', type: IdlType.publicKey()),
              ],
            ),
          ),
        ],
        instructions: [],
      );
    });

    group('AccountSubscriptionConfig', () {
      test('creates default configuration', () {
        const config = AccountSubscriptionConfig();

        expect(config.autoReconnect, isTrue);
        expect(config.maxReconnectAttempts, equals(5));
        expect(config.reconnectDelay, equals(const Duration(seconds: 2)));
        expect(config.subscriptionTimeout, equals(const Duration(minutes: 30)));
        expect(config.maxConcurrentSubscriptions, equals(100));
        expect(config.bufferSize, equals(50));
        expect(config.defaultCommitment, equals(Commitment.confirmed));
      });

      test('creates development configuration', () {
        final config = AccountSubscriptionConfig.development();

        expect(config.autoReconnect, isTrue);
        expect(config.maxReconnectAttempts, equals(10));
        expect(config.reconnectDelay, equals(const Duration(seconds: 1)));
        expect(config.subscriptionTimeout, equals(const Duration(minutes: 10)));
        expect(config.maxConcurrentSubscriptions, equals(50));
        expect(config.bufferSize, equals(20));
        expect(config.defaultCommitment, equals(Commitment.confirmed));
      });

      test('creates production configuration', () {
        final config = AccountSubscriptionConfig.production();

        expect(config.autoReconnect, isTrue);
        expect(config.maxReconnectAttempts, equals(3));
        expect(config.reconnectDelay, equals(const Duration(seconds: 5)));
        expect(config.subscriptionTimeout, equals(const Duration(hours: 1)));
        expect(config.maxConcurrentSubscriptions, equals(200));
        expect(config.bufferSize, equals(100));
        expect(config.defaultCommitment, equals(Commitment.finalized));
      });
    });

    group('AccountChangeNotification', () {
      test('creates from RPC data', () {
        final rpcData = {
          'value': {
            'lamports': 2039280,
            'owner': '11111111111111111111111111111111',
            'data': ['dGVzdCBkYXRh', 'base64'], // "test data" in base64
            'executable': false,
            'rentEpoch': 361,
          },
          'context': {
            'slot': 12345,
          },
        };

        final notification = AccountChangeNotification.fromRpcData(
          accountAddress,
          rpcData,
        );

        expect(notification.publicKey, equals(accountAddress));
        expect(notification.lamports, equals(2039280));
        expect(notification.owner, equals(programId));
        expect(notification.slot, equals(12345));
        expect(notification.executable, isFalse);
        expect(notification.rentEpoch, equals(361));
        expect(notification.data, isNotNull);
      });

      test('handles null data in RPC notification', () {
        final rpcData = {
          'value': {
            'lamports': 0,
            'owner': '11111111111111111111111111111111',
            'data': null,
            'executable': false,
            'rentEpoch': 361,
          },
          'context': {
            'slot': 12345,
          },
        };

        final notification = AccountChangeNotification.fromRpcData(
          accountAddress,
          rpcData,
        );

        expect(notification.publicKey, equals(accountAddress));
        expect(notification.data, isNull);
      });
    });

    group('AccountCacheConfig', () {
      test('creates default configuration', () {
        const config = AccountCacheConfig();

        expect(config.maxEntries, equals(1000));
        expect(config.ttl, equals(const Duration(minutes: 5)));
        expect(config.strategy, equals(CacheInvalidationStrategy.hybrid));
        expect(config.maxMemoryBytes, equals(50 * 1024 * 1024));
        expect(config.cleanupInterval, equals(const Duration(minutes: 1)));
        expect(config.enableStatistics, isTrue);
        expect(config.enableAutoCleanup, isTrue);
        expect(config.memoryPressureThreshold, equals(0.8));
        expect(config.evictionBatchSize, equals(50));
      });

      test('creates high-performance configuration', () {
        final config = AccountCacheConfig.highPerformance();

        expect(config.maxEntries, equals(10000));
        expect(config.ttl, equals(const Duration(minutes: 10)));
        expect(config.strategy,
            equals(CacheInvalidationStrategy.slotBasedInvalidation),);
        expect(config.maxMemoryBytes, equals(200 * 1024 * 1024));
        expect(config.memoryPressureThreshold, equals(0.9));
        expect(config.evictionBatchSize, equals(100));
      });

      test('creates memory-constrained configuration', () {
        final config = AccountCacheConfig.memoryConstrained();

        expect(config.maxEntries, equals(100));
        expect(config.ttl, equals(const Duration(minutes: 1)));
        expect(config.strategy,
            equals(CacheInvalidationStrategy.timeBasedExpiration),);
        expect(config.maxMemoryBytes, equals(5 * 1024 * 1024));
        expect(config.cleanupInterval, equals(const Duration(seconds: 30)));
        expect(config.enableStatistics, isFalse);
        expect(config.memoryPressureThreshold, equals(0.7));
        expect(config.evictionBatchSize, equals(20));
      });

      test('creates development configuration', () {
        final config = AccountCacheConfig.development();

        expect(config.maxEntries, equals(500));
        expect(config.ttl, equals(const Duration(seconds: 30)));
        expect(config.strategy, equals(CacheInvalidationStrategy.writeThrough));
        expect(config.maxMemoryBytes, equals(10 * 1024 * 1024));
        expect(config.cleanupInterval, equals(const Duration(seconds: 15)));
        expect(config.enableStatistics, isTrue);
        expect(config.memoryPressureThreshold, equals(0.8));
        expect(config.evictionBatchSize, equals(25));
      });
    });

    group('CacheEntry', () {
      test('creates cache entry with metadata', () {
        final testData = MockAccountData(
          value: 42,
          name: 'test',
          owner: programId,
        );

        final entry = CacheEntry<MockAccountData>(
          data: testData,
          timestamp: DateTime.now(),
          slot: 12345,
        );

        expect(entry.data, equals(testData));
        expect(entry.slot, equals(12345));
        expect(entry.isPinned, isFalse);
        expect(entry.sizeEstimate, equals(1024));
        expect(entry.accessCount, equals(1));
      });

      test('checks expiration based on TTL', () {
        final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 10));
        final entry = CacheEntry<String>(
          data: 'test',
          timestamp: oldTimestamp,
        );

        expect(entry.isExpired(const Duration(minutes: 5)), isTrue);
        expect(entry.isExpired(const Duration(minutes: 15)), isFalse);
      });

      test('checks staleness based on slot', () {
        final entry = CacheEntry<String>(
          data: 'test',
          timestamp: DateTime.now(),
          slot: 100,
        );

        expect(entry.isStaleBySlot(150), isTrue);
        expect(entry.isStaleBySlot(50), isFalse);
        expect(entry.isStaleBySlot(null), isFalse);
      });

      test('tracks access count and last access time', () {
        final entry = CacheEntry<String>(
          data: 'test',
          timestamp: DateTime.now(),
        );

        final initialAccessCount = entry.accessCount;
        final initialLastAccess = entry.lastAccess;

        // Wait a small amount to ensure timestamp difference
        Future.delayed(const Duration(milliseconds: 1), () {
          entry.recordAccess();

          expect(entry.accessCount, equals(initialAccessCount + 1));
          expect(entry.lastAccess.isAfter(initialLastAccess), isTrue);
        });
      });
    });

    group('AccountCacheManager', () {
      late AccountCacheManager<MockAccountData> cacheManager;

      setUp(() {
        final config = const AccountCacheConfig(
          maxEntries: 10,
          ttl: Duration(seconds: 5),
          enableAutoCleanup: false, // Disable for testing
        );
        cacheManager = AccountCacheManager<MockAccountData>(config: config);
      });

      tearDown(() {
        cacheManager.shutdown();
      });

      test('stores and retrieves data', () {
        final testData = MockAccountData(
          value: 42,
          name: 'test',
          owner: programId,
        );

        cacheManager.put(accountAddress, testData);
        final retrieved = cacheManager.get(accountAddress);

        expect(retrieved, equals(testData));
        expect(cacheManager.containsKey(accountAddress), isTrue);
      });

      test('returns null for non-existent keys', () {
        final retrieved = cacheManager.get(accountAddress);
        expect(retrieved, isNull);
        expect(cacheManager.containsKey(accountAddress), isFalse);
      });

      test('handles cache eviction when full', () {
        // Fill cache to capacity
        for (int i = 0; i < 10; i++) {
          final address =
              PublicKey.fromBase58(i.toString().padLeft(44, '1'));
          final data =
              MockAccountData(value: i, name: 'test$i', owner: programId);
          cacheManager.put(address, data);
        }

        // Add one more to trigger eviction
        final extraAddress = PublicKey.fromBase58(
            '99999999999999999999999999999999999999999999',);
        final extraData =
            MockAccountData(value: 99, name: 'extra', owner: programId);
        cacheManager.put(extraAddress, extraData);

        // Should have evicted the least recently used
        final stats = cacheManager.getStatistics();
        expect(stats.currentSize, equals(10));
        expect(stats.evictions, greaterThan(0));
      });

      test('invalidates expired entries', () {
        final testData = MockAccountData(
          value: 42,
          name: 'test',
          owner: programId,
        );

        cacheManager.put(accountAddress, testData);

        // Wait for expiration (TTL is 5 seconds)
        Future.delayed(const Duration(seconds: 6), () {
          cacheManager.cleanup();
          final retrieved = cacheManager.get(accountAddress);
          expect(retrieved, isNull);
        });
      });

      test('provides cache statistics', () {
        final testData = MockAccountData(
          value: 42,
          name: 'test',
          owner: programId,
        );

        cacheManager.put(accountAddress, testData);
        cacheManager.get(accountAddress); // Hit
        cacheManager.get(
            PublicKey.fromBase58('33333333333333333333333333333333'),); // Miss

        final stats = cacheManager.getStatistics();
        expect(stats.currentSize, equals(1));
        expect(stats.hits, equals(1));
        expect(stats.misses, equals(1));
        expect(stats.hitRate, equals(50.0));
      });

      test('clears all entries', () {
        final testData = MockAccountData(
          value: 42,
          name: 'test',
          owner: programId,
        );

        cacheManager.put(accountAddress, testData);
        expect(cacheManager.containsKey(accountAddress), isTrue);

        cacheManager.clear();
        expect(cacheManager.containsKey(accountAddress), isFalse);

        final stats = cacheManager.getStatistics();
        expect(stats.currentSize, equals(0));
      });
    });

    group('AccountRelationship', () {
      test('creates relationship with required properties', () {
        final relationship = AccountRelationship(
          publicKey: accountAddress,
          type: AccountRelationshipType.owner,
          description: 'Test relationship',
          isVerified: true,
        );

        expect(relationship.publicKey, equals(accountAddress));
        expect(relationship.type, equals(AccountRelationshipType.owner));
        expect(relationship.description, equals('Test relationship'));
        expect(relationship.isVerified, isTrue);
      });

      test('creates relationship with minimal properties', () {
        final relationship = AccountRelationship(
          publicKey: accountAddress,
          type: AccountRelationshipType.delegate,
        );

        expect(relationship.publicKey, equals(accountAddress));
        expect(relationship.type, equals(AccountRelationshipType.delegate));
        expect(relationship.description, isNull);
        expect(relationship.isVerified, isFalse);
      });
    });

    group('AccountCreationParams', () {
      test('creates with required space parameter', () {
        const params = AccountCreationParams(space: 1024);

        expect(params.space, equals(1024));
        expect(params.lamports, isNull);
        expect(params.owner, isNull);
        expect(params.keypair, isNull);
        expect(params.executable, isFalse);
        expect(params.initData, isNull);
      });

      test('creates with all parameters', () async {
        final keypair = await Keypair.generate();
        final params = AccountCreationParams(
          space: 2048,
          lamports: 1000000,
          owner: programId,
          keypair: keypair,
          executable: true,
          initData: {'value': 42},
        );

        expect(params.space, equals(2048));
        expect(params.lamports, equals(1000000));
        expect(params.owner, equals(programId));
        expect(params.keypair, equals(keypair));
        expect(params.executable, isTrue);
        expect(params.initData, equals({'value': 42}));
      });
    });

    group('Integration Tests', () {
      test('account management system integration', () {
        // This test would integrate all components but requires mock RPC setup
        // For now, we test that components can be created together
        final subscriptionConfig = AccountSubscriptionConfig.development();
        final cacheConfig = AccountCacheConfig.development();

        expect(subscriptionConfig.maxReconnectAttempts, equals(10));
        expect(cacheConfig.strategy,
            equals(CacheInvalidationStrategy.writeThrough),);

        // Test that configurations work together
        expect(subscriptionConfig.defaultCommitment, isA<Commitment>());
        expect(cacheConfig.enableStatistics, isTrue);
      });
    });
  });
}
