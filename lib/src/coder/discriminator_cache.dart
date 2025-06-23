/// Discriminator Caching and Performance Layer
///
/// This module provides high-performance caching system for discriminator
/// lookups, implementing TypeScript Anchor client's caching strategy with
/// intelligent cache invalidation and memory management.

library;

import 'dart:typed_data';

/// High-performance discriminator cache with intelligent invalidation and
/// memory management.
///
/// This class provides thread-safe caching for discriminators to avoid
/// recomputation, using configurable size limits and LRU eviction policy.
/// Matches TypeScript Anchor client's caching strategy for optimal performance.
class DiscriminatorCache {
  /// Default maximum cache size (number of entries)
  static const int defaultMaxSize = 1000;

  /// Default cache enabled flag
  static const bool defaultEnabled = true;

  /// Internal cache storage
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Cache access order for LRU eviction
  final List<String> _accessOrder = <String>[];

  /// Maximum number of cached entries
  final int maxSize;

  /// Whether caching is enabled
  final bool enabled;

  /// Cache statistics
  int _hits = 0;
  int _misses = 0;

  /// Create a new discriminator cache.
  ///
  /// [maxSize] Maximum number of entries to cache (default: 1000)
  /// [enabled] Whether caching is enabled (default: true)
  DiscriminatorCache({
    this.maxSize = defaultMaxSize,
    this.enabled = defaultEnabled,
  }) {
    if (maxSize <= 0) {
      throw ArgumentError('Cache max size must be positive, got $maxSize');
    }
  }

  /// Get a discriminator from cache.
  ///
  /// [key] The cache key to look up
  ///
  /// Returns the cached discriminator or null if not found
  Uint8List? get(String key) {
    if (!enabled) {
      return null;
    }

    final discriminator = _cache[key];
    if (discriminator != null) {
      _hits++;
      _updateAccessOrder(key);
      return Uint8List.fromList(discriminator); // Return a copy for safety
    }

    _misses++;
    return null;
  }

  /// Store a discriminator in cache.
  ///
  /// [key] The cache key
  /// [discriminator] The discriminator to cache
  void put(String key, Uint8List discriminator) {
    if (!enabled) {
      return;
    }

    // Validate discriminator size
    if (discriminator.length != 8) {
      throw ArgumentError(
        'Discriminator must be exactly 8 bytes, got ${discriminator.length}',
      );
    }

    // Store a copy to prevent external modification
    _cache[key] = Uint8List.fromList(discriminator);
    _updateAccessOrder(key);

    // Evict oldest entries if cache is full
    _evictIfNecessary();
  }

  /// Check if a key exists in cache.
  ///
  /// [key] The cache key to check
  ///
  /// Returns true if key exists in cache
  bool containsKey(String key) {
    if (!enabled) {
      return false;
    }
    return _cache.containsKey(key);
  }

  /// Remove a specific entry from cache.
  ///
  /// [key] The cache key to remove
  ///
  /// Returns true if entry was removed, false if not found
  bool remove(String key) {
    if (!enabled) {
      return false;
    }

    final removed = _cache.remove(key) != null;
    if (removed) {
      _accessOrder.remove(key);
    }
    return removed;
  }

  /// Clear all cached entries.
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Get cache size (number of entries).
  int get size => _cache.length;

  /// Check if cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is at maximum capacity.
  bool get isFull => _cache.length >= maxSize;

  /// Get cache hit count.
  int get hits => _hits;

  /// Get cache miss count.
  int get misses => _misses;

  /// Get total cache access count.
  int get totalAccesses => _hits + _misses;

  /// Get cache hit ratio (0.0 to 1.0).
  double get hitRatio {
    final total = totalAccesses;
    return total > 0 ? _hits / total : 0.0;
  }

  /// Get cache miss ratio (0.0 to 1.0).
  double get missRatio {
    final total = totalAccesses;
    return total > 0 ? _misses / total : 0.0;
  }

  /// Get cache statistics as a map.
  Map<String, dynamic> get statistics => {
        'size': size,
        'maxSize': maxSize,
        'enabled': enabled,
        'hits': hits,
        'misses': misses,
        'totalAccesses': totalAccesses,
        'hitRatio': hitRatio,
        'missRatio': missRatio,
        'isEmpty': isEmpty,
        'isFull': isFull,
      };

  /// Warm cache with known discriminator entries.
  ///
  /// [entries] Map of cache keys to discriminators
  void warm(Map<String, Uint8List> entries) {
    if (!enabled) {
      return;
    }

    for (final entry in entries.entries) {
      put(entry.key, entry.value);
    }
  }

  /// Update access order for LRU eviction.
  void _updateAccessOrder(String key) {
    // Remove from current position if exists
    _accessOrder.remove(key);
    // Add to end (most recently used)
    _accessOrder.add(key);
  }

  /// Evict least recently used entries if cache is full.
  void _evictIfNecessary() {
    while (_cache.length > maxSize) {
      if (_accessOrder.isNotEmpty) {
        final oldestKey = _accessOrder.removeAt(0);
        _cache.remove(oldestKey);
      } else {
        // Fallback: remove arbitrary entry
        final keyToRemove = _cache.keys.first;
        _cache.remove(keyToRemove);
      }
    }
  }

  /// Create cache key for account discriminator.
  ///
  /// [name] The account name
  ///
  /// Returns the cache key
  static String accountKey(String name) => 'account:$name';

  /// Create cache key for instruction discriminator.
  ///
  /// [name] The instruction name
  ///
  /// Returns the cache key
  static String instructionKey(String name) => 'global:$name';

  /// Create cache key for event discriminator.
  ///
  /// [name] The event name
  ///
  /// Returns the cache key
  static String eventKey(String name) => 'event:$name';
}
