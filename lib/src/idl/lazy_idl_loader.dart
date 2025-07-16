/// Lazy loading system for large IDL files
///
/// This module provides lazy loading capabilities for IDL files, enabling
/// efficient memory usage and faster startup times for applications
/// working with large or multiple IDL files.

library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

/// Configuration for lazy IDL loading
class LazyIdlConfig {
  const LazyIdlConfig({
    this.cacheSize = 10,
    this.preloadInstructions = true,
    this.preloadAccounts = false,
    this.preloadEvents = false,
    this.enableCompression = true,
    this.cacheDuration = const Duration(hours: 1),
    this.maxConcurrentLoads = 3,
    this.enableMetrics = true,
  });

  /// Maximum number of IDLs to cache in memory
  final int cacheSize;

  /// Whether to preload instruction definitions
  final bool preloadInstructions;

  /// Whether to preload account definitions
  final bool preloadAccounts;

  /// Whether to preload event definitions
  final bool preloadEvents;

  /// Whether to enable compression for cached IDLs
  final bool enableCompression;

  /// Duration to cache IDLs in memory
  final Duration cacheDuration;

  /// Maximum number of concurrent IDL loads
  final int maxConcurrentLoads;

  /// Whether to enable loading metrics
  final bool enableMetrics;

  /// Default configuration for most use cases
  static const LazyIdlConfig defaultConfig = LazyIdlConfig();

  /// Configuration optimized for mobile devices
  static const LazyIdlConfig mobileConfig = LazyIdlConfig(
    cacheSize: 5,
    preloadInstructions: true,
    preloadAccounts: false,
    preloadEvents: false,
    enableCompression: true,
    cacheDuration: Duration(minutes: 30),
    maxConcurrentLoads: 2,
  );

  /// Configuration optimized for desktop applications
  static const LazyIdlConfig desktopConfig = LazyIdlConfig(
    cacheSize: 20,
    preloadInstructions: true,
    preloadAccounts: true,
    preloadEvents: true,
    enableCompression: false,
    cacheDuration: Duration(hours: 2),
    maxConcurrentLoads: 5,
  );
}

/// Lazy-loaded IDL wrapper
class LazyIdl {
  LazyIdl({
    required this.programId,
    required this.idlPath,
    required this.loader,
    this.priority = 0,
  });

  /// Program ID this IDL belongs to
  final String programId;

  /// Path to the IDL file
  final String idlPath;

  /// Reference to the loader
  final LazyIdlLoader loader;

  /// Loading priority (higher numbers load first)
  final int priority;

  /// Cached IDL instance
  Idl? _cachedIdl;

  /// Loading future to prevent duplicate loads
  Future<Idl>? _loadingFuture;

  /// Load status
  bool _isLoaded = false;
  bool _isLoading = false;

  /// Load the IDL asynchronously
  Future<Idl> load() async {
    if (_isLoaded && _cachedIdl != null) {
      return _cachedIdl!;
    }

    if (_isLoading && _loadingFuture != null) {
      return _loadingFuture!;
    }

    _isLoading = true;
    _loadingFuture = _loadIdl();

    try {
      final idl = await _loadingFuture!;
      _cachedIdl = idl;
      _isLoaded = true;
      return idl;
    } finally {
      _isLoading = false;
    }
  }

  /// Load IDL synchronously if already cached
  Idl? get cached => _cachedIdl;

  /// Check if IDL is loaded
  bool get isLoaded => _isLoaded;

  /// Check if IDL is currently loading
  bool get isLoading => _isLoading;

  /// Get specific instruction by name (lazy loaded)
  Future<IdlInstruction?> getInstruction(String name) async {
    final idl = await load();
    return idl.instructions.cast<IdlInstruction?>().firstWhere(
          (inst) => inst?.name == name,
          orElse: () => null,
        );
  }

  /// Get specific account by name (lazy loaded)
  Future<IdlAccount?> getAccount(String name) async {
    final idl = await load();
    return idl.accounts?.cast<IdlAccount?>().firstWhere(
          (acc) => acc?.name == name,
          orElse: () => null,
        );
  }

  /// Get specific event by name (lazy loaded)
  Future<IdlEvent?> getEvent(String name) async {
    final idl = await load();
    return idl.events?.cast<IdlEvent?>().firstWhere(
          (event) => event?.name == name,
          orElse: () => null,
        );
  }

  /// Unload IDL from memory
  void unload() {
    _cachedIdl = null;
    _isLoaded = false;
    _loadingFuture = null;
  }

  /// Private method to load IDL from file
  Future<Idl> _loadIdl() async {
    return await loader._loadIdlFromFile(idlPath);
  }

  @override
  String toString() => 'LazyIdl(programId: $programId, loaded: $_isLoaded)';
}

/// Lazy loading metrics
class LazyIdlMetrics {
  LazyIdlMetrics({
    required this.totalLoads,
    required this.cacheHits,
    required this.cacheMisses,
    required this.averageLoadTime,
    required this.memoryUsage,
    required this.activeIdls,
  });

  /// Total number of IDL loads
  final int totalLoads;

  /// Number of cache hits
  final int cacheHits;

  /// Number of cache misses
  final int cacheMisses;

  /// Average load time in milliseconds
  final double averageLoadTime;

  /// Estimated memory usage in bytes
  final int memoryUsage;

  /// Number of currently active IDLs
  final int activeIdls;

  /// Calculate cache hit rate
  double get cacheHitRate => totalLoads > 0 ? cacheHits / totalLoads : 0.0;

  @override
  String toString() => 'LazyIdlMetrics('
      'loads: $totalLoads, '
      'hitRate: ${(cacheHitRate * 100).toStringAsFixed(1)}%, '
      'avgTime: ${averageLoadTime.toStringAsFixed(1)}ms, '
      'memory: ${(memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB'
      ')';
}

/// Lazy IDL loader with caching and optimization
class LazyIdlLoader {
  LazyIdlLoader({
    LazyIdlConfig? config,
  }) : _config = config ?? LazyIdlConfig.defaultConfig;

  /// Configuration
  final LazyIdlConfig _config;

  /// Cache of loaded IDLs
  final Map<String, LazyIdl> _idlCache = {};

  /// LRU cache for managing memory
  final LinkedHashMap<String, Idl> _memoryCache = LinkedHashMap();

  /// Currently loading IDLs
  final Set<String> _loadingIdls = {};

  /// Semaphore for limiting concurrent loads
  late final Semaphore _loadSemaphore = Semaphore(_config.maxConcurrentLoads);

  /// Metrics tracking
  int _totalLoads = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Load times for averaging
  final List<double> _loadTimes = [];

  /// Initialize the loader
  Future<void> initialize() async {
    // Clean up old cache entries periodically
    Timer.periodic(const Duration(minutes: 5), (_) => _cleanupCache());
  }

  /// Register an IDL for lazy loading
  LazyIdl register({
    required String programId,
    required String idlPath,
    int priority = 0,
  }) {
    final lazyIdl = LazyIdl(
      programId: programId,
      idlPath: idlPath,
      loader: this,
      priority: priority,
    );

    _idlCache[programId] = lazyIdl;
    return lazyIdl;
  }

  /// Get a lazy IDL by program ID
  LazyIdl? get(String programId) => _idlCache[programId];

  /// Preload specific IDLs
  Future<void> preload(List<String> programIds) async {
    // Sort by priority
    final sortedIds = programIds.toList()
      ..sort((a, b) {
        final aIdl = _idlCache[a];
        final bIdl = _idlCache[b];
        if (aIdl == null || bIdl == null) return 0;
        return bIdl.priority.compareTo(aIdl.priority);
      });

    // Load high-priority IDLs first
    for (final programId in sortedIds) {
      final lazyIdl = _idlCache[programId];
      if (lazyIdl != null) {
        await lazyIdl.load();
      }
    }
  }

  /// Load IDL by program ID
  Future<Idl> load(String programId) async {
    final lazyIdl = _idlCache[programId];
    if (lazyIdl == null) {
      throw Exception('IDL not registered for program: $programId');
    }

    return await lazyIdl.load();
  }

  /// Check if IDL is loaded
  bool isLoaded(String programId) {
    final lazyIdl = _idlCache[programId];
    return lazyIdl?.isLoaded ?? false;
  }

  /// Unload specific IDL
  void unload(String programId) {
    final lazyIdl = _idlCache[programId];
    if (lazyIdl != null) {
      lazyIdl.unload();
      _memoryCache.remove(programId);
    }
  }

  /// Unload all IDLs
  void unloadAll() {
    for (final lazyIdl in _idlCache.values) {
      lazyIdl.unload();
    }
    _memoryCache.clear();
  }

  /// Get loading metrics
  LazyIdlMetrics getMetrics() {
    final avgLoadTime = _loadTimes.isNotEmpty
        ? _loadTimes.reduce((a, b) => a + b) / _loadTimes.length
        : 0.0;

    // Rough memory usage estimation
    final memoryUsage = _memoryCache.values.fold<int>(
      0,
      (total, idl) => total + _estimateIdlSize(idl),
    );

    return LazyIdlMetrics(
      totalLoads: _totalLoads,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      averageLoadTime: avgLoadTime,
      memoryUsage: memoryUsage,
      activeIdls: _memoryCache.length,
    );
  }

  /// Clear all caches and unload
  void dispose() {
    unloadAll();
    _idlCache.clear();
    _loadingIdls.clear();
    _loadTimes.clear();
  }

  /// Private method to load IDL from file
  Future<Idl> _loadIdlFromFile(String idlPath) async {
    return await _loadSemaphore.acquire(() async {
      final startTime = DateTime.now();
      _totalLoads++;

      try {
        // Check memory cache first
        final programId = _extractProgramIdFromPath(idlPath);
        if (_memoryCache.containsKey(programId)) {
          _cacheHits++;
          // Move to end (LRU)
          final idl = _memoryCache.remove(programId)!;
          _memoryCache[programId] = idl;
          return idl;
        }

        _cacheMisses++;

        // Load from file
        final file = File(idlPath);
        if (!await file.exists()) {
          throw Exception('IDL file not found: $idlPath');
        }

        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final idl = Idl.fromJson(json);

        // Cache in memory
        _addToMemoryCache(programId, idl);

        return idl;
      } finally {
        final loadTime =
            DateTime.now().difference(startTime).inMilliseconds.toDouble();
        _loadTimes.add(loadTime);

        // Keep only recent load times for averaging
        if (_loadTimes.length > 100) {
          _loadTimes.removeAt(0);
        }
      }
    });
  }

  /// Add IDL to memory cache with LRU eviction
  void _addToMemoryCache(String programId, Idl idl) {
    // Remove if already exists
    _memoryCache.remove(programId);

    // Add to end
    _memoryCache[programId] = idl;

    // Evict LRU if cache is full
    while (_memoryCache.length > _config.cacheSize) {
      final lruKey = _memoryCache.keys.first;
      _memoryCache.remove(lruKey);

      // Also unload from LazyIdl
      final lazyIdl = _idlCache[lruKey];
      if (lazyIdl != null) {
        lazyIdl.unload();
      }
    }
  }

  /// Extract program ID from IDL file path
  String _extractProgramIdFromPath(String idlPath) {
    // Extract filename without extension
    final filename = idlPath.split('/').last.split('.').first;
    return filename;
  }

  /// Estimate memory usage of IDL
  int _estimateIdlSize(Idl idl) {
    // Rough estimation based on content
    int size = 0;

    // Instructions
    size += idl.instructions.length * 1024; // ~1KB per instruction

    // Accounts
    size += (idl.accounts?.length ?? 0) * 512; // ~512B per account

    // Events
    size += (idl.events?.length ?? 0) * 256; // ~256B per event

    // Types
    size += (idl.types?.length ?? 0) * 256; // ~256B per type

    return size;
  }

  /// Cleanup expired cache entries
  void _cleanupCache() {
    final expiredKeys = <String>[];

    for (final entry in _memoryCache.entries) {
      // This is a simplified cleanup - in real implementation,
      // you'd track cache entry timestamps
      if (_memoryCache.length > _config.cacheSize) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      final lazyIdl = _idlCache[key];
      if (lazyIdl != null) {
        lazyIdl.unload();
      }
    }
  }
}

/// Semaphore for limiting concurrent operations
class Semaphore {
  Semaphore(this.maxCount) : _currentCount = maxCount;

  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue();

  /// Acquire the semaphore and execute the operation
  Future<T> acquire<T>(Future<T> Function() operation) async {
    if (_currentCount > 0) {
      _currentCount--;
      try {
        return await operation();
      } finally {
        _release();
      }
    } else {
      final completer = Completer<void>();
      _waitQueue.add(completer);
      await completer.future;
      return acquire(operation);
    }
  }

  /// Release the semaphore
  void _release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Global lazy IDL loader instance
LazyIdlLoader? _globalLoader;

/// Get the global lazy IDL loader
LazyIdlLoader getGlobalIdlLoader() {
  _globalLoader ??= LazyIdlLoader();
  return _globalLoader!;
}

/// Initialize the global lazy IDL loader
Future<void> initializeGlobalIdlLoader({LazyIdlConfig? config}) async {
  _globalLoader = LazyIdlLoader(config: config);
  await _globalLoader!.initialize();
}

/// Dispose the global lazy IDL loader
void disposeGlobalIdlLoader() {
  _globalLoader?.dispose();
  _globalLoader = null;
}
