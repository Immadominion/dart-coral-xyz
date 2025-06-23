import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('PDA Cache System', () {
    late PublicKey programId;
    late PdaCache cache;

    setUp(() {
      programId = PublicKey.fromBase58('11111111111111111111111111111112');
      cache = PdaCache(maxSize: 10, maxAge: Duration(seconds: 30));
    });

    group('Cache Key Generation', () {
      test('should generate consistent keys for same seeds', () {
        final seeds1 = [StringSeed('test'), NumberSeed(42, byteLength: 8)];
        final seeds2 = [StringSeed('test'), NumberSeed(42, byteLength: 8)];

        final key1 = PdaCacheKey.fromSeeds(seeds1, programId);
        final key2 = PdaCacheKey.fromSeeds(seeds2, programId);

        expect(key1.key, equals(key2.key));
        expect(key1, equals(key2));
      });

      test('should generate different keys for different seeds', () {
        final seeds1 = [StringSeed('test1')];
        final seeds2 = [StringSeed('test2')];

        final key1 = PdaCacheKey.fromSeeds(seeds1, programId);
        final key2 = PdaCacheKey.fromSeeds(seeds2, programId);

        expect(key1.key, isNot(equals(key2.key)));
        expect(key1, isNot(equals(key2)));
      });

      test('should handle complex seed combinations', () {
        final publicKey =
            PublicKey.fromBase58('11111111111111111111111111111113');
        final seeds = [
          StringSeed('metadata'),
          PublicKeySeed(publicKey),
          NumberSeed(1, byteLength: 4),
          BytesSeed(Uint8List.fromList([1, 2, 3, 4])),
        ];

        final key = PdaCacheKey.fromSeeds(seeds, programId);
        expect(key.key, isNotEmpty);
        expect(key.programId, equals(programId));
      });
    });

    group('Basic Cache Operations', () {
      test('should store and retrieve PDA results', () {
        final seeds = [StringSeed('test')];
        final key = PdaCacheKey.fromSeeds(seeds, programId);
        final result = PdaDerivationEngine.findProgramAddress(seeds, programId);

        // Cache miss initially
        expect(cache.get(key), isNull);

        // Store result
        cache.put(key, result);

        // Cache hit
        final cachedResult = cache.get(key);
        expect(cachedResult, isNotNull);
        expect(cachedResult!.address, equals(result.address));
        expect(cachedResult.bump, equals(result.bump));
      });

      test('should return null for non-existent keys', () {
        final seeds = [StringSeed('nonexistent')];
        final key = PdaCacheKey.fromSeeds(seeds, programId);

        expect(cache.get(key), isNull);
      });

      test('should update access time on cache hits', () async {
        final seeds = [StringSeed('test')];
        final key = PdaCacheKey.fromSeeds(seeds, programId);
        final result = PdaDerivationEngine.findProgramAddress(seeds, programId);

        cache.put(key, result);

        // First access
        final firstAccess = DateTime.now();
        cache.get(key);

        // Wait a bit
        await Future.delayed(Duration(milliseconds: 10));

        // Second access
        cache.get(key);

        // Access time should have been updated
        final entry = cache.getEntryForTesting(key.key)!;
        expect(entry.lastAccessed.isAfter(firstAccess), isTrue);
        expect(entry.accessCount, equals(3)); // put + 2 gets
      });
    });

    group('LRU Eviction', () {
      test('should evict oldest entries when size limit reached', () {
        final cache = PdaCache(maxSize: 3);

        // Fill cache to capacity
        for (int i = 0; i < 3; i++) {
          final seeds = [StringSeed('test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
        }

        expect(cache.size, equals(3));

        // Add one more - should evict oldest
        final newSeeds = [StringSeed('test_new')];
        final newKey = PdaCacheKey.fromSeeds(newSeeds, programId);
        final newResult =
            PdaDerivationEngine.findProgramAddress(newSeeds, programId);
        cache.put(newKey, newResult);

        expect(cache.size, equals(3));

        // First entry should be evicted
        final oldKey = PdaCacheKey.fromSeeds([StringSeed('test_0')], programId);
        expect(cache.get(oldKey), isNull);

        // New entry should be present
        expect(cache.get(newKey), isNotNull);
      });

      test('should move accessed entries to end', () {
        final cache = PdaCache(maxSize: 3);

        // Fill cache
        final keys = <PdaCacheKey>[];
        for (int i = 0; i < 3; i++) {
          final seeds = [StringSeed('test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
          keys.add(key);
        }

        // Access first entry (makes it most recent)
        cache.get(keys[0]);

        // Add new entry - should evict second entry, not first
        final newSeeds = [StringSeed('test_new')];
        final newKey = PdaCacheKey.fromSeeds(newSeeds, programId);
        final newResult =
            PdaDerivationEngine.findProgramAddress(newSeeds, programId);
        cache.put(newKey, newResult);

        // First entry should still be present (was accessed recently)
        expect(cache.get(keys[0]), isNotNull);

        // Second entry should be evicted
        expect(cache.get(keys[1]), isNull);

        // Third entry and new entry should be present
        expect(cache.get(keys[2]), isNotNull);
        expect(cache.get(newKey), isNotNull);
      });
    });

    group('Cache Expiration', () {
      test('should expire entries after max age', () async {
        final cache = PdaCache(maxAge: Duration(milliseconds: 50));

        final seeds = [StringSeed('test')];
        final key = PdaCacheKey.fromSeeds(seeds, programId);
        final result = PdaDerivationEngine.findProgramAddress(seeds, programId);

        cache.put(key, result);
        expect(cache.get(key), isNotNull);

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 60));

        // Should be expired
        expect(cache.get(key), isNull);
      });

      test('should cleanup expired entries manually', () async {
        final cache = PdaCache(maxAge: Duration(milliseconds: 50));

        // Add multiple entries
        for (int i = 0; i < 3; i++) {
          final seeds = [StringSeed('test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
        }

        expect(cache.size, equals(3));

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 60));

        // Manual cleanup
        final expiredCount = cache.cleanupExpired();
        expect(expiredCount, equals(3));
        expect(cache.size, equals(0));
      });
    });

    group('Cache Statistics', () {
      test('should track hits and misses', () {
        final cache = PdaCache(enableStats: true);
        final seeds = [StringSeed('test')];
        final key = PdaCacheKey.fromSeeds(seeds, programId);
        final result = PdaDerivationEngine.findProgramAddress(seeds, programId);

        // Initial stats
        expect(cache.stats.hits, equals(0));
        expect(cache.stats.misses, equals(0));
        expect(cache.stats.hitRate, equals(0.0));

        // Cache miss
        cache.get(key);
        expect(cache.stats.misses, equals(1));
        expect(cache.stats.hitRate, equals(0.0));

        // Store and hit
        cache.put(key, result);
        cache.get(key);
        expect(cache.stats.hits, equals(1));
        expect(cache.stats.misses, equals(1));
        expect(cache.stats.hitRate, equals(50.0));

        // Another hit
        cache.get(key);
        expect(cache.stats.hits, equals(2));
        expect(cache.stats.hitRate, closeTo(66.67, 0.01));
      });

      test('should track evictions', () {
        final cache = PdaCache(maxSize: 2, enableStats: true);

        // Fill beyond capacity
        for (int i = 0; i < 3; i++) {
          final seeds = [StringSeed('test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
        }

        expect(cache.stats.evictions, equals(1));
      });

      test('should provide efficiency report', () {
        final cache = PdaCache(enableStats: true);
        final report = cache.efficiencyReport;

        expect(report, contains('PDA Cache Efficiency Report'));
        expect(report, contains('Hit Rate'));
        expect(report, contains('Miss Rate'));
      });
    });

    group('Cache Management', () {
      test('should clear all entries', () {
        // Add entries
        for (int i = 0; i < 3; i++) {
          final seeds = [StringSeed('test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
        }

        expect(cache.size, equals(3));
        expect(cache.isEmpty, isFalse);

        cache.clear();
        expect(cache.size, equals(0));
        expect(cache.isEmpty, isTrue);
      });

      test('should check capacity status', () {
        final cache = PdaCache(maxSize: 2);
        expect(cache.isAtCapacity, isFalse);

        // Fill to capacity
        for (int i = 0; i < 2; i++) {
          final seeds = [StringSeed('test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
        }

        expect(cache.isAtCapacity, isTrue);
      });

      test('should evict entries older than cutoff', () async {
        final cache = PdaCache();

        // Add first entry
        final seeds1 = [StringSeed('test1')];
        final key1 = PdaCacheKey.fromSeeds(seeds1, programId);
        final result1 =
            PdaDerivationEngine.findProgramAddress(seeds1, programId);
        cache.put(key1, result1);

        // Wait a bit
        await Future.delayed(Duration(milliseconds: 20));
        final cutoff = DateTime.now();

        // Add second entry
        final seeds2 = [StringSeed('test2')];
        final key2 = PdaCacheKey.fromSeeds(seeds2, programId);
        final result2 =
            PdaDerivationEngine.findProgramAddress(seeds2, programId);
        cache.put(key2, result2);

        expect(cache.size, equals(2));

        // Evict entries older than cutoff
        final evictedCount = cache.evictOlderThan(cutoff);
        expect(evictedCount, equals(1));
        expect(cache.size, equals(1));

        // Newer entry should remain
        expect(cache.get(key2), isNotNull);
        expect(cache.get(key1), isNull);
      });
    });

    group('Global Cache', () {
      test('should provide global cache instance', () {
        final global1 = getGlobalPdaCache();
        final global2 = getGlobalPdaCache();

        expect(identical(global1, global2), isTrue);
      });

      test('should allow setting custom global cache', () {
        final customCache = PdaCache(maxSize: 500);
        setGlobalPdaCache(customCache);

        final globalCache = getGlobalPdaCache();
        expect(identical(globalCache, customCache), isTrue);
      });

      test('should clear global cache', () {
        final globalCache = getGlobalPdaCache();

        // Add entry to global cache
        final seeds = [StringSeed('global_test')];
        final key = PdaCacheKey.fromSeeds(seeds, programId);
        final result = PdaDerivationEngine.findProgramAddress(seeds, programId);
        globalCache.put(key, result);

        expect(globalCache.size, equals(1));

        clearGlobalPdaCache();
        expect(globalCache.size, equals(0));
      });
    });

    group('Cache Performance', () {
      test('should handle large number of entries efficiently', () {
        final cache = PdaCache(maxSize: 1000);
        final stopwatch = Stopwatch()..start();

        // Add many entries
        for (int i = 0; i < 500; i++) {
          final seeds = [StringSeed('perf_test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
        }

        stopwatch.stop();
        expect(cache.size, equals(500));

        // Should complete reasonably quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('should maintain O(1) access performance', () {
        final cache = PdaCache(maxSize: 1000);

        // Fill cache with many entries
        final keys = <PdaCacheKey>[];
        for (int i = 0; i < 500; i++) {
          final seeds = [StringSeed('access_test_$i')];
          final key = PdaCacheKey.fromSeeds(seeds, programId);
          final result =
              PdaDerivationEngine.findProgramAddress(seeds, programId);
          cache.put(key, result);
          keys.add(key);
        }

        // Time random access
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final randomKey = keys[i % keys.length];
          cache.get(randomKey);
        }
        stopwatch.stop();

        // Should be very fast
        expect(stopwatch.elapsedMicroseconds, lessThan(10000));
      });
    });
  });
}
