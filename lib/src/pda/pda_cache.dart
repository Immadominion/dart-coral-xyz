/// High-performance PDA caching system with intelligent invalidation
///
/// This module provides comprehensive caching capabilities for Program Derived Addresses,
/// matching and exceeding TypeScript Anchor client caching strategies with advanced
/// optimization features.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:meta/meta.dart';

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/pda/pda_derivation_engine.dart' as pda;

/// Cache entry for storing PDA derivation results with metadata
class PdaCacheEntry {

  PdaCacheEntry({
    required this.address,
    required this.bump,
    required this.createdAt,
    required this.lastAccessed,
    this.accessCount = 1,
  });
  final PublicKey address;
  final int bump;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final int accessCount;

  /// Create a copy with updated access information
  PdaCacheEntry copyWithAccess() => PdaCacheEntry(
      address: address,
      bump: bump,
      createdAt: createdAt,
      lastAccessed: DateTime.now(),
      accessCount: accessCount + 1,
    );

  /// Get the age of this cache entry in milliseconds
  int get ageMs => DateTime.now().difference(createdAt).inMilliseconds;

  /// Get time since last access in milliseconds
  int get timeSinceLastAccessMs =>
      DateTime.now().difference(lastAccessed).inMilliseconds;
}

/// Cache key for PDA derivation results
class PdaCacheKey {

  PdaCacheKey({
    required this.programId,
    required this.seedBytes,
  });

  /// Generate cache key from seeds and program ID
  factory PdaCacheKey.fromSeeds(
    List<pda.PdaSeed> seeds,
    PublicKey programId,
  ) {
    final seedBytes = seeds.map((seed) => seed.toBytes()).toList();
    return PdaCacheKey(
      programId: programId,
      seedBytes: seedBytes,
    );
  }
  final PublicKey programId;
  final List<List<int>> seedBytes;

  /// Generate deterministic string key for HashMap usage
  String get key {
    final buffer = StringBuffer();
    buffer.write(programId.toBase58());
    for (final seed in seedBytes) {
      buffer.write(':');
      buffer
          .write(seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdaCacheKey) return false;

    if (programId != other.programId) return false;
    if (seedBytes.length != other.seedBytes.length) return false;

    for (int i = 0; i < seedBytes.length; i++) {
      if (seedBytes[i].length != other.seedBytes[i].length) return false;
      for (int j = 0; j < seedBytes[i].length; j++) {
        if (seedBytes[i][j] != other.seedBytes[i][j]) return false;
      }
    }

    return true;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'PdaCacheKey($key)';
}

/// Cache statistics for monitoring and optimization
class PdaCacheStats {
  int hits = 0;
  int misses = 0;
  int evictions = 0;
  int totalEntries = 0;
  int maxEntries = 0;
  DateTime? lastHit;
  DateTime? lastMiss;
  DateTime? lastEviction;

  /// Calculate cache hit rate as a percentage
  double get hitRate {
    final total = hits + misses;
    return total > 0 ? (hits / total) * 100.0 : 0.0;
  }

  /// Calculate cache miss rate as a percentage
  double get missRate => 100.0 - hitRate;

  /// Get total cache operations
  int get totalOperations => hits + misses;

  /// Reset all statistics
  void reset() {
    hits = 0;
    misses = 0;
    evictions = 0;
    totalEntries = 0;
    maxEntries = 0;
    lastHit = null;
    lastMiss = null;
    lastEviction = null;
  }

  @override
  String toString() => 'PdaCacheStats('
        'hits: $hits, '
        'misses: $misses, '
        'hitRate: ${hitRate.toStringAsFixed(2)}%, '
        'evictions: $evictions, '
        'entries: $totalEntries'
        ')';
}

/// High-performance LRU cache for PDA derivation results
class PdaCache {

  PdaCache({
    this.maxSize = 1000,
    this.maxAge = const Duration(minutes: 30),
    this.enableStats = true,
  });
  final int maxSize;
  final Duration maxAge;
  final bool enableStats;

  final LinkedHashMap<String, PdaCacheEntry> _cache = LinkedHashMap();
  final PdaCacheStats _stats = PdaCacheStats();

  /// Get PDA from cache, returning null if not found or expired
  pda.PdaResult? get(PdaCacheKey key) {
    final keyStr = key.key;
    final entry = _cache[keyStr];

    if (entry == null) {
      if (enableStats) {
        _stats.misses++;
        _stats.lastMiss = DateTime.now();
      }
      return null;
    }

    // Check if entry has expired
    if (entry.ageMs > maxAge.inMilliseconds) {
      _cache.remove(keyStr);
      if (enableStats) {
        _stats.misses++;
        _stats.lastMiss = DateTime.now();
        _stats.evictions++;
        _stats.lastEviction = DateTime.now();
      }
      return null;
    }

    // Move to end (most recently used) and update access info
    _cache.remove(keyStr);
    _cache[keyStr] = entry.copyWithAccess();

    if (enableStats) {
      _stats.hits++;
      _stats.lastHit = DateTime.now();
    }

    return pda.PdaResult(
      entry.address,
      entry.bump,
    );
  }

  /// Put PDA result in cache with LRU eviction
  void put(PdaCacheKey key, pda.PdaResult result) {
    final keyStr = key.key;
    final now = DateTime.now();

    // Remove existing entry if present
    final existingEntry = _cache.remove(keyStr);

    // Create new entry
    final entry = PdaCacheEntry(
      address: result.address,
      bump: result.bump,
      createdAt: now,
      lastAccessed: now,
    );

    // Add to end (most recently used)
    _cache[keyStr] = entry;

    // Evict oldest entries if over size limit
    while (_cache.length > maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      if (enableStats) {
        _stats.evictions++;
        _stats.lastEviction = now;
      }
    }

    // Update stats
    if (enableStats) {
      if (existingEntry == null) {
        _stats.totalEntries++;
      }
      _stats.maxEntries = math.max(_stats.maxEntries, _cache.length);
    }
  }

  /// Check if cache contains key (without updating access time)
  bool containsKey(PdaCacheKey key) {
    final entry = _cache[key.key];
    if (entry == null) return false;

    // Check expiration
    if (entry.ageMs > maxAge.inMilliseconds) {
      _cache.remove(key.key);
      return false;
    }

    return true;
  }

  /// Get cache size
  int get size => _cache.length;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is at capacity
  bool get isAtCapacity => _cache.length >= maxSize;

  /// Clear all cache entries
  void clear() {
    _cache.clear();
    if (enableStats) {
      _stats.totalEntries = 0;
    }
  }

  /// Remove expired entries
  int cleanupExpired() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.ageMs > maxAge.inMilliseconds) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (enableStats && expiredKeys.isNotEmpty) {
      _stats.evictions += expiredKeys.length;
      _stats.lastEviction = now;
    }

    return expiredKeys.length;
  }

  /// Remove entries accessed before the given time
  int evictOlderThan(DateTime cutoff) {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.lastAccessed.isBefore(cutoff)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (enableStats && keysToRemove.isNotEmpty) {
      _stats.evictions += keysToRemove.length;
      _stats.lastEviction = DateTime.now();
    }

    return keysToRemove.length;
  }

  /// Get cache statistics
  PdaCacheStats get stats => _stats;

  /// Get internal cache entry for testing purposes
  @visibleForTesting
  PdaCacheEntry? getEntryForTesting(String key) => _cache[key];

  /// Get cache efficiency report
  String get efficiencyReport {
    final buffer = StringBuffer();
    buffer.writeln('=== PDA Cache Efficiency Report ===');
    buffer.writeln('Size: $size / $maxSize');
    buffer.writeln('Hit Rate: ${_stats.hitRate.toStringAsFixed(2)}%');
    buffer.writeln('Miss Rate: ${_stats.missRate.toStringAsFixed(2)}%');
    buffer.writeln('Total Operations: ${_stats.totalOperations}');
    buffer.writeln('Evictions: ${_stats.evictions}');

    if (_stats.totalOperations > 0) {
      buffer.writeln(
          'Operations/Eviction: ${(_stats.totalOperations / math.max(1, _stats.evictions)).toStringAsFixed(2)}',);
    }

    return buffer.toString();
  }

  /// Warmup cache with common PDA patterns
  Future<void> warmup(List<PdaCacheKey> commonKeys) async {
    for (final key in commonKeys) {
      if (!containsKey(key)) {
        try {
          final seeds = _reconstructSeeds(key);
          final result =
              pda.PdaDerivationEngine.findProgramAddress(seeds, key.programId);
          put(key, result);
        } catch (e) {
          // Skip invalid keys during warmup
          continue;
        }
      }
    }
  }

  /// Reconstruct seeds from cache key (basic implementation)
  List<pda.PdaSeed> _reconstructSeeds(PdaCacheKey key) {
    // This is a simplified reconstruction - in practice you'd need
    // to store seed type information with the cache key
    return key.seedBytes
        .map((bytes) => pda.BytesSeed(Uint8List.fromList(bytes)))
        .toList();
  }

  @override
  String toString() => 'PdaCache(size: $size/$maxSize, hitRate: ${_stats.hitRate.toStringAsFixed(1)}%)';
}

/// Global PDA cache instance for performance optimization
PdaCache? _globalCache;

/// Get or create the global PDA cache instance
PdaCache getGlobalPdaCache() => _globalCache ??= PdaCache();

/// Set a custom global PDA cache instance
void setGlobalPdaCache(PdaCache cache) {
  _globalCache = cache;
}

/// Clear the global PDA cache
void clearGlobalPdaCache() {
  _globalCache?.clear();
}
