/// Tests for DiscriminatorCache
///
/// Comprehensive test suite validating cache functionality, performance,
/// and thread safety for discriminator caching.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('DiscriminatorCache', () {
    late DiscriminatorCache cache;
    late Uint8List testDiscriminator1;
    late Uint8List testDiscriminator2;

    setUp(() {
      cache = DiscriminatorCache();
      testDiscriminator1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      testDiscriminator2 = Uint8List.fromList([8, 7, 6, 5, 4, 3, 2, 1]);
    });

    group('Basic Operations', () {
      test('creates cache with default settings', () {
        expect(cache.maxSize, equals(1000));
        expect(cache.enabled, isTrue);
        expect(cache.size, equals(0));
        expect(cache.isEmpty, isTrue);
        expect(cache.isFull, isFalse);
      });

      test('creates cache with custom settings', () {
        final customCache = DiscriminatorCache(maxSize: 50, enabled: false);
        expect(customCache.maxSize, equals(50));
        expect(customCache.enabled, isFalse);
      });

      test('throws error for invalid max size', () {
        expect(
          () => DiscriminatorCache(maxSize: 0),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DiscriminatorCache(maxSize: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('stores and retrieves discriminator', () {
        const key = 'test_key';
        cache.put(key, testDiscriminator1);

        expect(cache.containsKey(key), isTrue);
        expect(cache.size, equals(1));

        final retrieved = cache.get(key);
        expect(retrieved, isNotNull);
        expect(retrieved, equals(testDiscriminator1));
      });

      test('returns null for non-existent key', () {
        final retrieved = cache.get('non_existent');
        expect(retrieved, isNull);
      });

      test('removes entry from cache', () {
        const key = 'test_key';
        cache.put(key, testDiscriminator1);

        expect(cache.remove(key), isTrue);
        expect(cache.containsKey(key), isFalse);
        expect(cache.size, equals(0));
        expect(cache.remove(key), isFalse); // Already removed
      });

      test('clears all cache entries', () {
        cache.put('key1', testDiscriminator1);
        cache.put('key2', testDiscriminator2);

        expect(cache.size, equals(2));

        cache.clear();

        expect(cache.size, equals(0));
        expect(cache.isEmpty, isTrue);
        expect(cache.hits, equals(0));
        expect(cache.misses, equals(0));
      });
    });

    group('Data Validation', () {
      test('throws error for invalid discriminator size', () {
        const key = 'test_key';
        final invalidDiscriminator = Uint8List.fromList([1, 2, 3]); // Too short

        expect(
          () => cache.put(key, invalidDiscriminator),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('stores copy of discriminator data', () {
        const key = 'test_key';
        final original = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        cache.put(key, original);

        // Modify original
        original[0] = 99;

        // Retrieved should be unmodified
        final retrieved = cache.get(key);
        expect(retrieved![0], equals(1));
      });

      test('returns copy of discriminator data', () {
        const key = 'test_key';
        cache.put(key, testDiscriminator1);

        final retrieved1 = cache.get(key);
        final retrieved2 = cache.get(key);

        // Should be equal but not identical
        expect(retrieved1, equals(retrieved2));
        expect(identical(retrieved1, retrieved2), isFalse);

        // Modifying one should not affect the other
        retrieved1![0] = 99;
        expect(retrieved2![0], equals(1));
      });
    });

    group('Cache Statistics', () {
      test('tracks cache hits and misses', () {
        const key = 'test_key';

        // Initial state
        expect(cache.hits, equals(0));
        expect(cache.misses, equals(0));
        expect(cache.totalAccesses, equals(0));
        expect(cache.hitRatio, equals(0.0));
        expect(cache.missRatio, equals(0.0));

        // Miss
        cache.get(key);
        expect(cache.hits, equals(0));
        expect(cache.misses, equals(1));
        expect(cache.totalAccesses, equals(1));
        expect(cache.hitRatio, equals(0.0));
        expect(cache.missRatio, equals(1.0));

        // Store and hit
        cache.put(key, testDiscriminator1);
        cache.get(key);
        expect(cache.hits, equals(1));
        expect(cache.misses, equals(1));
        expect(cache.totalAccesses, equals(2));
        expect(cache.hitRatio, equals(0.5));
        expect(cache.missRatio, equals(0.5));
      });

      test('provides comprehensive statistics', () {
        cache.put('key1', testDiscriminator1);
        cache.get('key1'); // Hit
        cache.get('key2'); // Miss

        final stats = cache.statistics;
        expect(stats['size'], equals(1));
        expect(stats['maxSize'], equals(1000));
        expect(stats['enabled'], isTrue);
        expect(stats['hits'], equals(1));
        expect(stats['misses'], equals(1));
        expect(stats['totalAccesses'], equals(2));
        expect(stats['hitRatio'], equals(0.5));
        expect(stats['missRatio'], equals(0.5));
        expect(stats['isEmpty'], isFalse);
        expect(stats['isFull'], isFalse);
      });
    });

    group('LRU Eviction', () {
      test('evicts least recently used entries', () {
        final smallCache = DiscriminatorCache(maxSize: 2);

        // Fill cache
        smallCache.put('key1', testDiscriminator1);
        smallCache.put('key2', testDiscriminator2);
        expect(smallCache.size, equals(2));
        expect(smallCache.isFull, isTrue);

        // Access key1 to make it more recently used
        smallCache.get('key1');

        // Add new entry, should evict key2 (least recently used)
        final newDiscriminator = Uint8List.fromList([9, 8, 7, 6, 5, 4, 3, 2]);
        smallCache.put('key3', newDiscriminator);

        expect(smallCache.size, equals(2));
        expect(smallCache.containsKey('key1'), isTrue); // Should remain
        expect(smallCache.containsKey('key2'), isFalse); // Should be evicted
        expect(smallCache.containsKey('key3'), isTrue); // Should be added
      });

      test('handles access order correctly', () {
        final smallCache = DiscriminatorCache(maxSize: 3);

        // Add entries
        smallCache.put('key1', testDiscriminator1);
        smallCache.put('key2', testDiscriminator2);
        smallCache.put('key3', Uint8List.fromList([3, 3, 3, 3, 3, 3, 3, 3]));

        // Access in specific order
        smallCache.get('key1'); // Make key1 most recent
        smallCache.get('key2'); // Make key2 most recent

        // Add new entry, should evict key3 (least recently used)
        final newDiscriminator = Uint8List.fromList([4, 4, 4, 4, 4, 4, 4, 4]);
        smallCache.put('key4', newDiscriminator);

        expect(smallCache.containsKey('key1'), isTrue);
        expect(smallCache.containsKey('key2'), isTrue);
        expect(smallCache.containsKey('key3'), isFalse); // Evicted
        expect(smallCache.containsKey('key4'), isTrue);
      });
    });

    group('Disabled Cache', () {
      test('disabled cache does not store or retrieve', () {
        final disabledCache = DiscriminatorCache(enabled: false);

        disabledCache.put('key1', testDiscriminator1);
        expect(disabledCache.size, equals(0));
        expect(disabledCache.get('key1'), isNull);
        expect(disabledCache.containsKey('key1'), isFalse);
        expect(disabledCache.remove('key1'), isFalse);
      });

      test('disabled cache statistics remain zero', () {
        final disabledCache = DiscriminatorCache(enabled: false);

        disabledCache.put('key1', testDiscriminator1);
        disabledCache.get('key1');
        disabledCache.get('key2');

        expect(disabledCache.hits, equals(0));
        expect(disabledCache.misses, equals(0));
        expect(disabledCache.totalAccesses, equals(0));
      });
    });

    group('Cache Warming', () {
      test('warms cache with multiple entries', () {
        final entries = {
          'key1': testDiscriminator1,
          'key2': testDiscriminator2,
        };

        cache.warm(entries);

        expect(cache.size, equals(2));
        expect(cache.get('key1'), equals(testDiscriminator1));
        expect(cache.get('key2'), equals(testDiscriminator2));
      });

      test('warming respects cache size limits', () {
        final smallCache = DiscriminatorCache(maxSize: 1);
        final entries = {
          'key1': testDiscriminator1,
          'key2': testDiscriminator2,
        };

        smallCache.warm(entries);

        expect(smallCache.size, equals(1)); // Should only have 1 entry
      });

      test('warming disabled cache does nothing', () {
        final disabledCache = DiscriminatorCache(enabled: false);
        final entries = {
          'key1': testDiscriminator1,
          'key2': testDiscriminator2,
        };

        disabledCache.warm(entries);

        expect(disabledCache.size, equals(0));
      });
    });

    group('Cache Key Utilities', () {
      test('generates correct account cache keys', () {
        expect(DiscriminatorCache.accountKey('MyAccount'),
            equals('account:MyAccount'));
        expect(DiscriminatorCache.accountKey('Data'), equals('account:Data'));
      });

      test('generates correct instruction cache keys', () {
        expect(DiscriminatorCache.instructionKey('initialize'),
            equals('global:initialize'));
        expect(DiscriminatorCache.instructionKey('transfer'),
            equals('global:transfer'));
      });

      test('generates correct event cache keys', () {
        expect(DiscriminatorCache.eventKey('MyEvent'), equals('event:MyEvent'));
        expect(
            DiscriminatorCache.eventKey('Transfer'), equals('event:Transfer'));
      });
    });

    group('Performance and Memory', () {
      test('handles large number of entries efficiently', () {
        final largeCache = DiscriminatorCache(maxSize: 10000);

        // Add many entries
        for (int i = 0; i < 5000; i++) {
          final key = 'key_$i';
          final discriminator = Uint8List.fromList([
            i & 0xFF,
            (i >> 8) & 0xFF,
            (i >> 16) & 0xFF,
            (i >> 24) & 0xFF,
            i & 0xFF,
            (i >> 8) & 0xFF,
            (i >> 16) & 0xFF,
            (i >> 24) & 0xFF,
          ]);
          largeCache.put(key, discriminator);
        }

        expect(largeCache.size, equals(5000));

        // Verify random access works
        final retrieved = largeCache.get('key_2500');
        expect(retrieved, isNotNull);
        expect(retrieved![0], equals(2500 & 0xFF));
      });

      test('memory usage stays within bounds', () {
        final boundedCache = DiscriminatorCache(maxSize: 100);

        // Add more entries than max size
        for (int i = 0; i < 200; i++) {
          final key = 'key_$i';
          final discriminator = Uint8List.fromList([
            i & 0xFF,
            (i >> 8) & 0xFF,
            (i >> 16) & 0xFF,
            (i >> 24) & 0xFF,
            i & 0xFF,
            (i >> 8) & 0xFF,
            (i >> 16) & 0xFF,
            (i >> 24) & 0xFF,
          ]);
          boundedCache.put(key, discriminator);
        }

        // Size should not exceed max
        expect(boundedCache.size, lessThanOrEqualTo(100));

        // Recent entries should still be accessible
        expect(boundedCache.get('key_199'), isNotNull);
        expect(boundedCache.get('key_150'), isNotNull);

        // Very old entries should be evicted
        expect(boundedCache.get('key_0'), isNull);
        expect(boundedCache.get('key_50'), isNull);
      });
    });
  });
}
