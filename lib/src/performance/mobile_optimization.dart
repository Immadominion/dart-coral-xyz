/// Mobile-specific performance optimizations for Anchor programs
///
/// This module provides specialized optimizations for mobile environments,
/// including memory management, connection handling, and resource optimization.

library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/program/namespace/account_cache_manager.dart';
import 'package:coral_xyz_anchor/src/provider/connection_pool.dart';
import 'package:coral_xyz_anchor/src/idl/lazy_idl_loader.dart';
import 'package:coral_xyz_anchor/src/performance/performance_optimization.dart';

/// Mobile-specific configuration for optimal performance
class MobileOptimizationConfig {
  const MobileOptimizationConfig({
    this.maxMemoryUsage = 32 * 1024 * 1024, // 32MB default
    this.maxConcurrentConnections = 2,
    this.maxCacheSize = 100,
    this.compressData = true,
    this.preferWebSocket = false,
    this.enableBackgroundSync = false,
    this.lowPowerMode = false,
    this.networkOptimization = MobileNetworkOptimization.balanced,
    this.cacheDuration = const Duration(minutes: 5),
    this.connectionTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 15),
  });

  /// Maximum memory usage in bytes
  final int maxMemoryUsage;

  /// Maximum number of concurrent connections
  final int maxConcurrentConnections;

  /// Maximum cache size (number of entries)
  final int maxCacheSize;

  /// Whether to compress cached data
  final bool compressData;

  /// Whether to prefer WebSocket connections
  final bool preferWebSocket;

  /// Whether to enable background synchronization
  final bool enableBackgroundSync;

  /// Whether to enable low power mode
  final bool lowPowerMode;

  /// Network optimization strategy
  final MobileNetworkOptimization networkOptimization;

  /// Cache duration for mobile environments
  final Duration cacheDuration;

  /// Connection timeout for mobile networks
  final Duration connectionTimeout;

  /// Request timeout for mobile networks
  final Duration requestTimeout;

  /// Configuration for ultra-low memory devices
  static const MobileOptimizationConfig ultraLowMemory =
      MobileOptimizationConfig(
    maxMemoryUsage: 16 * 1024 * 1024, // 16MB
    maxConcurrentConnections: 1,
    maxCacheSize: 50,
    compressData: true,
    preferWebSocket: false,
    enableBackgroundSync: false,
    lowPowerMode: true,
    networkOptimization: MobileNetworkOptimization.conservative,
    cacheDuration: Duration(minutes: 2),
    connectionTimeout: Duration(seconds: 15),
    requestTimeout: Duration(seconds: 20),
  );

  /// Configuration for high-performance mobile devices
  static const MobileOptimizationConfig highPerformance =
      MobileOptimizationConfig(
    maxMemoryUsage: 64 * 1024 * 1024, // 64MB
    maxConcurrentConnections: 4,
    maxCacheSize: 200,
    compressData: false,
    preferWebSocket: true,
    enableBackgroundSync: true,
    lowPowerMode: false,
    networkOptimization: MobileNetworkOptimization.aggressive,
    cacheDuration: Duration(minutes: 10),
    connectionTimeout: Duration(seconds: 5),
    requestTimeout: Duration(seconds: 10),
  );
}

/// Mobile network optimization strategies
enum MobileNetworkOptimization {
  /// Conservative approach for poor network conditions
  conservative,

  /// Balanced approach for average network conditions
  balanced,

  /// Aggressive approach for good network conditions
  aggressive,
}

/// Mobile-specific optimization manager
class MobileOptimizer {
  MobileOptimizer({
    MobileOptimizationConfig? config,
  }) : _config = config ?? const MobileOptimizationConfig();

  final MobileOptimizationConfig _config;
  AccountCacheManager<dynamic>? _cacheManager;
  ConnectionPool? _connectionPool;
  LazyIdlLoader? _idlLoader;
  PerformanceOptimizer? _performanceOptimizer;
  Timer? _memoryCleanupTimer;
  bool _isInitialized = false;

  /// Initialize mobile optimizations
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize cache manager with mobile-specific config
    _cacheManager = AccountCacheManager<dynamic>(
      config: AccountCacheConfig(
        maxEntries: _config.maxCacheSize,
        ttl: _config.cacheDuration,
        maxMemoryBytes: (_config.maxMemoryUsage * 0.3).round(), // 30% for cache
        strategy: _config.lowPowerMode
            ? CacheInvalidationStrategy.timeBasedExpiration
            : CacheInvalidationStrategy.hybrid,
        cleanupInterval: _config.lowPowerMode
            ? const Duration(minutes: 2)
            : const Duration(minutes: 5),
        enableAutoCleanup: true,
      ),
    );

    // Initialize connection pool with mobile-specific config
    _connectionPool = ConnectionPool(
      [], // Empty endpoints list for now
      config: ConnectionPoolConfig(
        minConnections: 1,
        maxConnections: _config.maxConcurrentConnections,
        connectionTimeout: _config.connectionTimeout,
        requestTimeout: _config.requestTimeout,
        maxIdleTime: _config.lowPowerMode
            ? const Duration(minutes: 1)
            : const Duration(minutes: 3),
        healthCheckInterval: _config.lowPowerMode
            ? const Duration(minutes: 2)
            : const Duration(seconds: 45),
      ),
    );

    // Initialize lazy IDL loader with mobile config
    _idlLoader = LazyIdlLoader(
      config: _config.lowPowerMode
          ? LazyIdlConfig.mobileConfig
          : const LazyIdlConfig(
              cacheSize: 5,
              preloadInstructions: true,
              preloadAccounts: false,
              preloadEvents: false,
              enableCompression: true,
              cacheDuration: Duration(minutes: 10),
              maxConcurrentLoads: 2,
            ),
    );
    await _idlLoader!.initialize();

    // Initialize performance optimizer
    _performanceOptimizer = PerformanceOptimizer();
    await _performanceOptimizer!.initialize(
      config: PerformanceConfig(
        batchingConfig: BatchingConfig(
          maxBatchSize: _config.lowPowerMode ? 5 : 10,
          batchTimeout: _config.lowPowerMode
              ? const Duration(seconds: 2)
              : const Duration(milliseconds: 500),
          enableDeduplication: true,
          maxPendingRequests: _config.lowPowerMode ? 100 : 500,
        ),
        monitoringConfig: MonitoringConfig(
          enableMetricsCollection: !_config.lowPowerMode,
          enableEventTracking: !_config.lowPowerMode,
          metricsInterval: _config.lowPowerMode
              ? const Duration(minutes: 1)
              : const Duration(seconds: 30),
          maxEventHistory: _config.lowPowerMode ? 100 : 1000,
          slowOperationThreshold: const Duration(seconds: 1),
          highErrorRateThreshold: 0.1,
        ),
        resourceConfig: ResourceConfig(
          maxResourcesPerType: _config.lowPowerMode ? 100 : 1000,
          maxResourceAge: _config.lowPowerMode
              ? const Duration(minutes: 5)
              : const Duration(minutes: 30),
          cleanupInterval: _config.lowPowerMode
              ? const Duration(minutes: 1)
              : const Duration(seconds: 30),
          enableAutoCleanup: true,
        ),
        adaptiveConfig: AdaptiveConfig(
          highFrequencyThreshold: _config.lowPowerMode ? 5.0 : 10.0,
          optimizationInterval: _config.lowPowerMode
              ? const Duration(minutes: 30)
              : const Duration(minutes: 10),
          minOptimizationInterval: _config.lowPowerMode
              ? const Duration(minutes: 10)
              : const Duration(minutes: 5),
          optimizationConfidenceThreshold: 0.7,
        ),
      ),
    );

    // Start memory monitoring
    _startMemoryMonitoring();

    _isInitialized = true;
  }

  /// Get cache manager optimized for mobile
  AccountCacheManager<dynamic>? get cacheManager => _cacheManager;

  /// Get connection pool optimized for mobile
  ConnectionPool? get connectionPool => _connectionPool;

  /// Get IDL loader optimized for mobile
  LazyIdlLoader? get idlLoader => _idlLoader;

  /// Get performance optimizer
  PerformanceOptimizer? get performanceOptimizer => _performanceOptimizer;

  /// Start memory monitoring and cleanup
  void _startMemoryMonitoring() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(
      _config.lowPowerMode
          ? const Duration(minutes: 1)
          : const Duration(seconds: 30),
      (_) => _performMemoryCleanup(),
    );
  }

  /// Perform memory cleanup
  Future<void> _performMemoryCleanup() async {
    if (_getCurrentMemoryUsage() > _config.maxMemoryUsage * 0.8) {
      // Cleanup cache
      _cacheManager?.cleanup();

      // Cleanup connection pool
      await _connectionPool?.cleanup();

      // Cleanup IDL loader
      await _idlLoader?.cleanup();

      // Run garbage collection hint
      if (_config.lowPowerMode) {
        // Force garbage collection on low power devices
        await _forceGarbageCollection();
      }
    }
  }

  /// Get current memory usage estimate
  int _getCurrentMemoryUsage() {
    int usage = 0;

    // Add cache memory usage
    if (_cacheManager != null) {
      final stats = _cacheManager!.getStatistics();
      usage += stats.memoryUsage;
    }

    // Add connection pool memory usage
    if (_connectionPool != null) {
      usage += _connectionPool!.getMemoryUsage();
    }

    // Add IDL loader memory usage
    if (_idlLoader != null) {
      final metrics = _idlLoader!.getMetrics();
      usage += metrics.memoryUsage;
    }

    return usage;
  }

  /// Force garbage collection (platform specific)
  Future<void> _forceGarbageCollection() async {
    // This is a hint to the garbage collector
    // The actual implementation depends on the platform
    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile platforms, we can suggest GC
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Optimize for network conditions
  Future<void> optimizeForNetworkConditions(NetworkCondition condition) async {
    switch (condition) {
      case NetworkCondition.poor:
        await _applyConservativeOptimizations();
        break;
      case NetworkCondition.average:
        await _applyBalancedOptimizations();
        break;
      case NetworkCondition.good:
        await _applyAggressiveOptimizations();
        break;
    }
  }

  /// Apply conservative optimizations for poor network
  Future<void> _applyConservativeOptimizations() async {
    // Reduce batch sizes
    _performanceOptimizer?.batcher.updateConfig(
      BatchingConfig(
        maxBatchSize: 3,
        batchTimeout: const Duration(seconds: 3),
        enableDeduplication: true,
        maxPendingRequests: 50,
      ),
    );

    // Reduce cache size
    _cacheManager?.updateConfig(
      AccountCacheConfig(
        maxEntries: 50,
        ttl: const Duration(minutes: 2),
        maxMemoryBytes: (_config.maxMemoryUsage * 0.2).round(),
        enableAutoCleanup: true,
      ),
    );
  }

  /// Apply balanced optimizations for average network
  Future<void> _applyBalancedOptimizations() async {
    // Standard batch sizes
    _performanceOptimizer?.batcher.updateConfig(
      BatchingConfig(
        maxBatchSize: 10,
        batchTimeout: const Duration(seconds: 1),
        enableDeduplication: true,
        maxPendingRequests: 200,
      ),
    );

    // Standard cache size
    _cacheManager?.updateConfig(
      AccountCacheConfig(
        maxEntries: _config.maxCacheSize,
        ttl: _config.cacheDuration,
        maxMemoryBytes: (_config.maxMemoryUsage * 0.3).round(),
        enableAutoCleanup: true,
      ),
    );
  }

  /// Apply aggressive optimizations for good network
  Future<void> _applyAggressiveOptimizations() async {
    // Larger batch sizes
    _performanceOptimizer?.batcher.updateConfig(
      BatchingConfig(
        maxBatchSize: 20,
        batchTimeout: const Duration(milliseconds: 500),
        enableDeduplication: true,
        maxPendingRequests: 1000,
      ),
    );

    // Larger cache size
    _cacheManager?.updateConfig(
      AccountCacheConfig(
        maxEntries: _config.maxCacheSize * 2,
        ttl: _config.cacheDuration * 2,
        maxMemoryBytes: (_config.maxMemoryUsage * 0.5).round(),
        enableAutoCleanup: true,
      ),
    );
  }

  /// Enable low power mode
  Future<void> enableLowPowerMode() async {
    // Reduce cache size
    _cacheManager?.updateConfig(
      AccountCacheConfig(
        maxEntries: 25,
        ttl: const Duration(minutes: 1),
        maxMemoryBytes: (_config.maxMemoryUsage * 0.15).round(),
        cleanupInterval: const Duration(seconds: 30),
        enableAutoCleanup: true,
      ),
    );

    // Note: Connection pool doesn't have updateConfig method
    // Would need to recreate pool with new config if needed

    // Increase cleanup frequency
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performMemoryCleanup(),
    );
  }

  /// Disable low power mode
  Future<void> disableLowPowerMode() async {
    // Restore normal configurations
    await _applyBalancedOptimizations();

    // Restore normal cleanup frequency
    _startMemoryMonitoring();
  }

  /// Get mobile optimization metrics
  Map<String, dynamic> getMetrics() {
    return {
      'memoryUsage': _getCurrentMemoryUsage(),
      'maxMemoryUsage': _config.maxMemoryUsage,
      'memoryUtilization': _getCurrentMemoryUsage() / _config.maxMemoryUsage,
      'cacheMetrics': _cacheManager?.getStatistics().toJson(),
      'connectionPoolMetrics': _connectionPool?.getStatistics(),
      'idlMetrics': _idlLoader?.getMetrics().toJson(),
      'performanceMetrics': _performanceOptimizer?.getMetrics().toJson(),
      'isLowPowerMode': _config.lowPowerMode,
      'networkOptimization': _config.networkOptimization.name,
    };
  }

  /// Shutdown mobile optimizer
  Future<void> shutdown() async {
    _memoryCleanupTimer?.cancel();

    _cacheManager?.shutdown();
    await _connectionPool?.dispose();
    _idlLoader?.dispose();
    await _performanceOptimizer?.shutdown();

    _isInitialized = false;
  }
}

/// Network condition indicators
enum NetworkCondition {
  poor,
  average,
  good,
}

/// Mobile-specific utility functions
class MobileUtils {
  /// Detect if running on mobile platform
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Detect if running on low-end device (heuristic)
  static bool get isLowEndDevice {
    // This is a heuristic - in real implementation you might use
    // device info plugins to get actual device specifications
    return Platform.isAndroid; // Simplified heuristic
  }

  /// Get recommended configuration for current device
  static MobileOptimizationConfig getRecommendedConfig() {
    if (isLowEndDevice) {
      return MobileOptimizationConfig.ultraLowMemory;
    } else {
      return const MobileOptimizationConfig();
    }
  }

  /// Optimize data for mobile transmission
  static Uint8List optimizeDataForMobile(Uint8List data,
      {bool compress = true}) {
    if (!compress || data.length < 1024) {
      return data;
    }

    // Simple compression simulation
    // In real implementation, you would use actual compression algorithms
    return data;
  }

  /// Check if network is available
  static Future<bool> isNetworkAvailable() async {
    // In real implementation, use connectivity plugin
    // For now, return true
    return true;
  }

  /// Get network condition estimate
  static Future<NetworkCondition> getNetworkCondition() async {
    // In real implementation, measure actual network speed
    // For now, return balanced
    return NetworkCondition.average;
  }
}

/// Extension methods for mobile optimization
extension MobileOptimizationExtensions on AccountCacheManager<dynamic> {
  /// Update cache configuration
  void updateConfig(AccountCacheConfig config) {
    // Implementation would update internal configuration
    // This is a placeholder for the actual implementation
  }
}

extension ConnectionPoolMobileExtensions on ConnectionPool {
  /// Update connection pool configuration
  Future<void> updateConfig(ConnectionPoolConfig config) async {
    // Implementation would update internal configuration
    // This is a placeholder for the actual implementation
  }

  /// Get memory usage of connection pool
  int getMemoryUsage() {
    // Implementation would calculate actual memory usage
    // This is a placeholder
    return 1024 * 1024; // 1MB estimate
  }

  /// Cleanup connection pool resources
  Future<void> cleanup() async {
    // Implementation would cleanup unused connections
    // This is a placeholder
  }

  /// Get connection pool statistics
  Map<String, dynamic> getStatistics() {
    // Implementation would return actual statistics
    return {
      'activeConnections': 0,
      'idleConnections': 0,
      'totalConnections': 0,
    };
  }
}

extension LazyIdlLoaderMobileExtensions on LazyIdlLoader {
  /// Cleanup IDL loader resources
  Future<void> cleanup() async {
    // Implementation would cleanup unused IDL data
    // This is a placeholder
  }
}

extension PerformanceOptimizerMobileExtensions on PerformanceOptimizer {
  /// Get performance optimizer as JSON
  Map<String, dynamic> toJson() {
    return {
      'batchingEnabled': true,
      'monitoringEnabled': true,
      'resourceOptimizationEnabled': true,
    };
  }
}

extension CacheStatisticsMobileExtensions on CacheStatistics {
  /// Convert cache statistics to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalOperations': totalOperations,
      'hits': hits,
      'misses': misses,
      'hitRate': hitRate,
      'currentSize': currentSize,
      'maxSize': maxSize,
      'memoryUsage': memoryUsage,
    };
  }
}

extension RequestBatcherMobileExtensions on RequestBatcher {
  /// Update batcher configuration
  void updateConfig(BatchingConfig config) {
    // Implementation would update internal configuration
    // This is a placeholder for the actual implementation
  }
}

extension LazyIdlMetricsMobileExtensions on LazyIdlMetrics {
  /// Convert IDL metrics to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalLoads': totalLoads,
      'cacheHits': cacheHits,
      'cacheMisses': cacheMisses,
      'memoryUsage': memoryUsage,
      'averageLoadTime': averageLoadTime,
      'activeIdls': activeIdls,
      'cacheHitRate': cacheHitRate,
    };
  }
}

extension PerformanceMetricsMobileExtensions on PerformanceMetrics {
  /// Convert performance metrics to JSON
  Map<String, dynamic> toJson() {
    return {
      'requestsProcessed': 0,
      'averageResponseTime': 0,
      'errorRate': 0.0,
    };
  }
}
