/// Account Cache Manager with Intelligent Invalidation Strategies
///
/// This module provides advanced account caching capabilities with multiple
/// invalidation strategies, performance optimization, and memory management
/// matching TypeScript's sophisticated caching patterns.

library;

import 'dart:async';
import 'dart:collection';

import '../../types/public_key.dart';

/// Cache invalidation strategy
enum CacheInvalidationStrategy {
  /// Time-based expiration (LRU with TTL)
  timeBasedExpiration,

  /// Slot-based invalidation (invalidate when slot changes)
  slotBasedInvalidation,

  /// Manual invalidation only
  manualInvalidation,

  /// Hybrid approach using both time and slot
  hybrid,

  /// Write-through cache (always fetch fresh data)
  writeThrough,
}

/// Cache entry metadata
class CacheEntry<T> {
  /// Cached data
  final T data;

  /// Timestamp when data was cached
  final DateTime timestamp;

  /// Slot number when data was cached
  final int? slot;

  /// Number of times this entry has been accessed
  int accessCount = 1;

  /// Last access timestamp
  DateTime lastAccess;

  /// Whether this entry is pinned (never evicted)
  final bool isPinned;

  /// Size estimate in bytes (for memory management)
  final int sizeEstimate;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.slot,
    this.isPinned = false,
    this.sizeEstimate = 1024, // Default 1KB estimate
  }) : lastAccess = DateTime.now();

  /// Check if entry is expired based on TTL
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  /// Check if entry is stale based on slot
  bool isStaleBySlot(int? currentSlot) {
    if (slot == null || currentSlot == null) return false;
    return currentSlot > slot!;
  }

  /// Update access tracking
  void recordAccess() {
    accessCount++;
    lastAccess = DateTime.now();
  }

  @override
  String toString() {
    return 'CacheEntry(timestamp: $timestamp, slot: $slot, accessCount: $accessCount, isPinned: $isPinned)';
  }
}

/// Cache statistics for monitoring
class CacheStatistics {
  /// Total number of cache operations
  final int totalOperations;

  /// Number of cache hits
  final int hits;

  /// Number of cache misses
  final int misses;

  /// Number of cache invalidations
  final int invalidations;

  /// Number of cache evictions
  final int evictions;

  /// Current cache size (number of entries)
  final int currentSize;

  /// Maximum cache size
  final int maxSize;

  /// Total memory usage estimate (bytes)
  final int memoryUsage;

  /// Last cleanup timestamp
  final DateTime? lastCleanup;

  /// Average access time in microseconds
  final double averageAccessTime;

  const CacheStatistics({
    required this.totalOperations,
    required this.hits,
    required this.misses,
    required this.invalidations,
    required this.evictions,
    required this.currentSize,
    required this.maxSize,
    required this.memoryUsage,
    this.lastCleanup,
    required this.averageAccessTime,
  });

  /// Cache hit rate as percentage
  double get hitRate {
    if (totalOperations == 0) return 0.0;
    return (hits / totalOperations) * 100.0;
  }

  /// Memory utilization as percentage
  double get memoryUtilization {
    return (currentSize / maxSize) * 100.0;
  }

  @override
  String toString() {
    return 'CacheStatistics(hitRate: ${hitRate.toStringAsFixed(1)}%, size: $currentSize/$maxSize, memory: ${(memoryUsage / 1024).toStringAsFixed(1)}KB)';
  }
}

/// Configuration for account cache manager
class AccountCacheConfig {
  /// Maximum number of entries in cache
  final int maxEntries;

  /// Time-to-live for cache entries
  final Duration ttl;

  /// Cache invalidation strategy
  final CacheInvalidationStrategy strategy;

  /// Maximum memory usage in bytes
  final int maxMemoryBytes;

  /// Cleanup interval for expired entries
  final Duration cleanupInterval;

  /// Whether to enable cache statistics
  final bool enableStatistics;

  /// Whether to enable automatic cleanup
  final bool enableAutoCleanup;

  /// Threshold for memory pressure cleanup (percentage)
  final double memoryPressureThreshold;

  /// Number of entries to evict during memory pressure
  final int evictionBatchSize;

  const AccountCacheConfig({
    this.maxEntries = 1000,
    this.ttl = const Duration(minutes: 5),
    this.strategy = CacheInvalidationStrategy.hybrid,
    this.maxMemoryBytes = 50 * 1024 * 1024, // 50MB
    this.cleanupInterval = const Duration(minutes: 1),
    this.enableStatistics = true,
    this.enableAutoCleanup = true,
    this.memoryPressureThreshold = 0.8, // 80%
    this.evictionBatchSize = 50,
  });

  /// Create high-performance configuration
  factory AccountCacheConfig.highPerformance() {
    return const AccountCacheConfig(
      maxEntries: 10000,
      ttl: Duration(minutes: 10),
      strategy: CacheInvalidationStrategy.slotBasedInvalidation,
      maxMemoryBytes: 200 * 1024 * 1024, // 200MB
      cleanupInterval: Duration(minutes: 2),
      enableStatistics: true,
      enableAutoCleanup: true,
      memoryPressureThreshold: 0.9,
      evictionBatchSize: 100,
    );
  }

  /// Create memory-constrained configuration
  factory AccountCacheConfig.memoryConstrained() {
    return const AccountCacheConfig(
      maxEntries: 100,
      ttl: Duration(minutes: 1),
      strategy: CacheInvalidationStrategy.timeBasedExpiration,
      maxMemoryBytes: 5 * 1024 * 1024, // 5MB
      cleanupInterval: Duration(seconds: 30),
      enableStatistics: false,
      enableAutoCleanup: true,
      memoryPressureThreshold: 0.7,
      evictionBatchSize: 20,
    );
  }

  /// Create development configuration
  factory AccountCacheConfig.development() {
    return const AccountCacheConfig(
      maxEntries: 500,
      ttl: Duration(seconds: 30),
      strategy: CacheInvalidationStrategy.writeThrough,
      maxMemoryBytes: 10 * 1024 * 1024, // 10MB
      cleanupInterval: Duration(seconds: 15),
      enableStatistics: true,
      enableAutoCleanup: true,
      memoryPressureThreshold: 0.8,
      evictionBatchSize: 25,
    );
  }
}

/// Intelligent account cache manager
class AccountCacheManager<T> {
  /// Cache configuration
  final AccountCacheConfig _config;

  /// Cache storage using LinkedHashMap for LRU behavior
  final LinkedHashMap<String, CacheEntry<T>> _cache =
      LinkedHashMap<String, CacheEntry<T>>();

  /// Current slot number for slot-based invalidation
  int? _currentSlot;

  /// Statistics tracking
  int _totalOperations = 0;
  int _hits = 0;
  int _misses = 0;
  int _invalidations = 0;
  int _evictions = 0;
  int _memoryUsage = 0;
  DateTime? _lastCleanup;
  final List<int> _accessTimes = [];

  /// Cleanup timer
  Timer? _cleanupTimer;

  /// Whether cache is active
  bool _isActive = true;

  AccountCacheManager({
    AccountCacheConfig? config,
  }) : _config = config ?? const AccountCacheConfig() {
    if (_config.enableAutoCleanup) {
      _startCleanupTimer();
    }
  }

  /// Get cached data for account
  T? get(PublicKey publicKey, {int? slot}) {
    if (!_isActive) return null;

    final stopwatch = Stopwatch()..start();
    _totalOperations++;

    try {
      final key = publicKey.toBase58();
      final entry = _cache[key];

      if (entry == null) {
        _misses++;
        return null;
      }

      // Check if entry is valid based on strategy
      if (!_isEntryValid(entry, slot)) {
        _cache.remove(key);
        _memoryUsage -= entry.sizeEstimate;
        _invalidations++;
        _misses++;
        return null;
      }

      // Update access tracking
      entry.recordAccess();

      // Move to end (most recently used)
      _cache.remove(key);
      _cache[key] = entry;

      _hits++;
      return entry.data;
    } finally {
      stopwatch.stop();
      _recordAccessTime(stopwatch.elapsedMicroseconds);
    }
  }

  /// Store data in cache
  void put(
    PublicKey publicKey,
    T data, {
    int? slot,
    bool isPinned = false,
    int? sizeEstimate,
  }) {
    if (!_isActive) return;

    final key = publicKey.toBase58();
    final estimate = sizeEstimate ?? _estimateSize(data);

    // Remove existing entry if present
    final existing = _cache.remove(key);
    if (existing != null) {
      _memoryUsage -= existing.sizeEstimate;
    }

    // Create new entry
    final entry = CacheEntry<T>(
      data: data,
      timestamp: DateTime.now(),
      slot: slot,
      isPinned: isPinned,
      sizeEstimate: estimate,
    );

    // Check memory pressure and evict if necessary
    _ensureCapacity(estimate);

    // Add new entry
    _cache[key] = entry;
    _memoryUsage += estimate;

    // Update current slot for strategy
    if (slot != null && (slot > (_currentSlot ?? 0))) {
      _currentSlot = slot;
    }
  }

  /// Remove entry from cache
  bool remove(PublicKey publicKey) {
    if (!_isActive) return false;

    final key = publicKey.toBase58();
    final entry = _cache.remove(key);

    if (entry != null) {
      _memoryUsage -= entry.sizeEstimate;
      return true;
    }

    return false;
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
    _memoryUsage = 0;
    _invalidations += _cache.length;
  }

  /// Invalidate entries based on strategy
  void invalidate({int? slot, List<PublicKey>? specificKeys}) {
    if (!_isActive) return;

    if (specificKeys != null) {
      // Invalidate specific keys
      for (final key in specificKeys) {
        final removed = remove(key);
        if (removed) _invalidations++;
      }
      return;
    }

    // Invalidate based on strategy
    switch (_config.strategy) {
      case CacheInvalidationStrategy.slotBasedInvalidation:
      case CacheInvalidationStrategy.hybrid:
        if (slot != null) {
          _invalidateBySlot(slot);
        }
        break;
      case CacheInvalidationStrategy.timeBasedExpiration:
        _invalidateExpired();
        break;
      case CacheInvalidationStrategy.writeThrough:
        clear();
        break;
      case CacheInvalidationStrategy.manualInvalidation:
        // Only manual invalidation allowed
        break;
    }
  }

  /// Check if key exists in cache
  bool containsKey(PublicKey publicKey) {
    final key = publicKey.toBase58();
    final entry = _cache[key];
    return entry != null && _isEntryValid(entry, _currentSlot);
  }

  /// Get cache statistics
  CacheStatistics getStatistics() {
    final avgTime = _accessTimes.isEmpty
        ? 0.0
        : _accessTimes.reduce((a, b) => a + b) / _accessTimes.length;

    return CacheStatistics(
      totalOperations: _totalOperations,
      hits: _hits,
      misses: _misses,
      invalidations: _invalidations,
      evictions: _evictions,
      currentSize: _cache.length,
      maxSize: _config.maxEntries,
      memoryUsage: _memoryUsage,
      lastCleanup: _lastCleanup,
      averageAccessTime: avgTime,
    );
  }

  /// Get all cached keys
  List<String> getCachedKeys() {
    return _cache.keys.toList();
  }

  /// Check if entry is valid based on cache strategy
  bool _isEntryValid(CacheEntry<T> entry, int? currentSlot) {
    switch (_config.strategy) {
      case CacheInvalidationStrategy.timeBasedExpiration:
        return !entry.isExpired(_config.ttl);

      case CacheInvalidationStrategy.slotBasedInvalidation:
        return !entry.isStaleBySlot(currentSlot);

      case CacheInvalidationStrategy.hybrid:
        return !entry.isExpired(_config.ttl) &&
            !entry.isStaleBySlot(currentSlot);

      case CacheInvalidationStrategy.writeThrough:
        return false; // Always invalid for write-through

      case CacheInvalidationStrategy.manualInvalidation:
        return true; // Valid until manually invalidated
    }
  }

  /// Invalidate entries by slot
  void _invalidateBySlot(int slot) {
    final toRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isStaleBySlot(slot)) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      final entry = _cache.remove(key);
      if (entry != null) {
        _memoryUsage -= entry.sizeEstimate;
        _invalidations++;
      }
    }
  }

  /// Invalidate expired entries
  void _invalidateExpired() {
    final toRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired(_config.ttl)) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      final entry = _cache.remove(key);
      if (entry != null) {
        _memoryUsage -= entry.sizeEstimate;
        _invalidations++;
      }
    }
  }

  /// Ensure cache has capacity for new entry
  void _ensureCapacity(int newEntrySize) {
    // Check entry count limit
    while (_cache.length >= _config.maxEntries) {
      _evictLeastRecentlyUsed();
    }

    // Check memory limit
    while (_memoryUsage + newEntrySize > _config.maxMemoryBytes) {
      if (!_evictLeastRecentlyUsed()) {
        break; // Cannot evict more (all pinned?)
      }
    }

    // Check memory pressure threshold
    final pressureRatio =
        (_memoryUsage + newEntrySize) / _config.maxMemoryBytes;
    if (pressureRatio > _config.memoryPressureThreshold) {
      _evictBatch(_config.evictionBatchSize);
    }
  }

  /// Evict least recently used entry
  bool _evictLeastRecentlyUsed() {
    if (_cache.isEmpty) return false;

    // Find least recently used entry that is not pinned
    String? keyToEvict;
    for (final entry in _cache.entries) {
      if (!entry.value.isPinned) {
        keyToEvict = entry.key;
        break;
      }
    }

    if (keyToEvict == null) return false;

    final entry = _cache.remove(keyToEvict);
    if (entry != null) {
      _memoryUsage -= entry.sizeEstimate;
      _evictions++;
      return true;
    }

    return false;
  }

  /// Evict a batch of entries
  void _evictBatch(int count) {
    for (int i = 0; i < count && _cache.isNotEmpty; i++) {
      if (!_evictLeastRecentlyUsed()) {
        break;
      }
    }
  }

  /// Estimate size of data object
  int _estimateSize(T data) {
    // Basic size estimation - could be made more sophisticated
    if (data is String) {
      return (data as String).length * 2; // UTF-16 encoding
    } else if (data is List) {
      return (data as List).length * 8; // Estimate 8 bytes per element
    } else if (data is Map) {
      return (data as Map).length * 32; // Estimate 32 bytes per entry
    }
    return 1024; // Default 1KB estimate
  }

  /// Record access time for statistics
  void _recordAccessTime(int microseconds) {
    if (!_config.enableStatistics) return;

    _accessTimes.add(microseconds);

    // Keep only last 1000 access times
    if (_accessTimes.length > 1000) {
      _accessTimes.removeAt(0);
    }
  }

  /// Start automatic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (_) {
      cleanup();
    });
  }

  /// Perform cache cleanup
  void cleanup() {
    if (!_isActive) return;

    _lastCleanup = DateTime.now();

    switch (_config.strategy) {
      case CacheInvalidationStrategy.timeBasedExpiration:
      case CacheInvalidationStrategy.hybrid:
        _invalidateExpired();
        break;
      default:
        // No automatic cleanup for other strategies
        break;
    }
  }

  /// Shutdown cache manager
  void shutdown() {
    _isActive = false;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    clear();
  }
}
