/// Platform-specific optimizations for mobile and web deployments
///
/// This module provides platform-specific enhancements for the Coral XYZ
/// Anchor client, optimizing performance and user experience for mobile
/// and web environments.

library;

import 'dart:async';
import 'dart:io' show Platform;

/// Type alias for callback functions
typedef VoidCallback = void Function();

/// Platform types supported by the SDK
enum PlatformType {
  /// Mobile platforms (iOS, Android)
  mobile,

  /// Web platform (browser)
  web,

  /// Desktop platforms (Windows, macOS, Linux)
  desktop,

  /// Unknown or unsupported platform
  unknown,
}

/// Platform detection and optimization utilities
class PlatformOptimization {
  static PlatformType? _currentPlatform;

  /// Get the current platform type
  static PlatformType get currentPlatform {
    if (_currentPlatform != null) return _currentPlatform!;

    _currentPlatform = _detectPlatform();
    return _currentPlatform!;
  }

  /// Detect the current platform
  static PlatformType _detectPlatform() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return PlatformType.mobile;
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return PlatformType.desktop;
      } else {
        return PlatformType.unknown;
      }
    } catch (e) {
      // Platform detection failed, likely running on web
      return PlatformType.web;
    }
  }

  /// Check if running on mobile
  static bool get isMobile => currentPlatform == PlatformType.mobile;

  /// Check if running on web
  static bool get isWeb => currentPlatform == PlatformType.web;

  /// Check if running on desktop
  static bool get isDesktop => currentPlatform == PlatformType.desktop;

  /// Get platform-specific connection timeout
  static Duration get connectionTimeout {
    switch (currentPlatform) {
      case PlatformType.mobile:
        return const Duration(
            seconds: 15); // Longer timeout for mobile networks
      case PlatformType.web:
        return const Duration(seconds: 10); // Standard web timeout
      case PlatformType.desktop:
        return const Duration(seconds: 8); // Faster desktop networks
      case PlatformType.unknown:
        return const Duration(seconds: 10); // Safe default
    }
  }

  /// Get platform-specific retry delay
  static Duration get retryDelay {
    switch (currentPlatform) {
      case PlatformType.mobile:
        return const Duration(
            seconds: 2); // Account for mobile network variability
      case PlatformType.web:
        return const Duration(milliseconds: 1500);
      case PlatformType.desktop:
        return const Duration(seconds: 1);
      case PlatformType.unknown:
        return const Duration(milliseconds: 1500);
    }
  }

  /// Get platform-specific max concurrent connections
  static int get maxConcurrentConnections {
    switch (currentPlatform) {
      case PlatformType.mobile:
        return 3; // Limit connections on mobile to preserve battery
      case PlatformType.web:
        return 6; // Browser default limit
      case PlatformType.desktop:
        return 10; // More connections for desktop
      case PlatformType.unknown:
        return 6; // Safe default
    }
  }

  /// Get platform-specific cache size limit (in MB)
  static int get cacheSizeLimitMB {
    switch (currentPlatform) {
      case PlatformType.mobile:
        return 50; // Limited cache on mobile
      case PlatformType.web:
        return 100; // Moderate cache for web
      case PlatformType.desktop:
        return 200; // Larger cache for desktop
      case PlatformType.unknown:
        return 100; // Safe default
    }
  }

  /// Check if background processing is supported
  static bool get supportsBackgroundProcessing {
    switch (currentPlatform) {
      case PlatformType.mobile:
        return true; // Mobile has background app refresh
      case PlatformType.web:
        return false; // Web has limited background processing
      case PlatformType.desktop:
        return true; // Desktop can run background tasks
      case PlatformType.unknown:
        return false; // Safe default
    }
  }

  /// Check if local storage is available
  static bool get supportsLocalStorage {
    switch (currentPlatform) {
      case PlatformType.mobile:
        return true; // Mobile apps have secure storage
      case PlatformType.web:
        return true; // Web has localStorage
      case PlatformType.desktop:
        return true; // Desktop has file system
      case PlatformType.unknown:
        return false; // Safe default
    }
  }
}

/// Platform-specific performance optimization configuration
class PlatformPerformanceConfig {
  /// Connection pool size
  final int connectionPoolSize;

  /// Request timeout duration
  final Duration requestTimeout;

  /// Retry configuration
  final Duration retryDelay;
  final int maxRetries;

  /// Caching configuration
  final bool enableCaching;
  final int cacheSizeLimitMB;
  final Duration cacheExpiration;

  /// Background processing configuration
  final bool enableBackgroundSync;
  final Duration backgroundSyncInterval;

  /// Memory optimization settings
  final bool enableMemoryOptimization;
  final int maxCachedAccounts;
  final int maxCachedTransactions;

  const PlatformPerformanceConfig({
    required this.connectionPoolSize,
    required this.requestTimeout,
    required this.retryDelay,
    required this.maxRetries,
    required this.enableCaching,
    required this.cacheSizeLimitMB,
    required this.cacheExpiration,
    required this.enableBackgroundSync,
    required this.backgroundSyncInterval,
    required this.enableMemoryOptimization,
    required this.maxCachedAccounts,
    required this.maxCachedTransactions,
  });

  /// Create platform-specific configuration
  factory PlatformPerformanceConfig.forPlatform(PlatformType platform) {
    switch (platform) {
      case PlatformType.mobile:
        return const PlatformPerformanceConfig(
          connectionPoolSize: 3,
          requestTimeout: Duration(seconds: 15),
          retryDelay: Duration(seconds: 2),
          maxRetries: 3,
          enableCaching: true,
          cacheSizeLimitMB: 50,
          cacheExpiration: Duration(minutes: 10),
          enableBackgroundSync: true,
          backgroundSyncInterval: Duration(minutes: 5),
          enableMemoryOptimization: true,
          maxCachedAccounts: 100,
          maxCachedTransactions: 50,
        );

      case PlatformType.web:
        return const PlatformPerformanceConfig(
          connectionPoolSize: 6,
          requestTimeout: Duration(seconds: 10),
          retryDelay: Duration(milliseconds: 1500),
          maxRetries: 3,
          enableCaching: true,
          cacheSizeLimitMB: 100,
          cacheExpiration: Duration(minutes: 15),
          enableBackgroundSync: false,
          backgroundSyncInterval: Duration(minutes: 1),
          enableMemoryOptimization: true,
          maxCachedAccounts: 200,
          maxCachedTransactions: 100,
        );

      case PlatformType.desktop:
        return const PlatformPerformanceConfig(
          connectionPoolSize: 10,
          requestTimeout: Duration(seconds: 8),
          retryDelay: Duration(seconds: 1),
          maxRetries: 5,
          enableCaching: true,
          cacheSizeLimitMB: 200,
          cacheExpiration: Duration(minutes: 30),
          enableBackgroundSync: true,
          backgroundSyncInterval: Duration(minutes: 2),
          enableMemoryOptimization: false,
          maxCachedAccounts: 500,
          maxCachedTransactions: 250,
        );

      case PlatformType.unknown:
        return const PlatformPerformanceConfig(
          connectionPoolSize: 6,
          requestTimeout: Duration(seconds: 10),
          retryDelay: Duration(milliseconds: 1500),
          maxRetries: 3,
          enableCaching: true,
          cacheSizeLimitMB: 100,
          cacheExpiration: Duration(minutes: 15),
          enableBackgroundSync: false,
          backgroundSyncInterval: Duration(minutes: 1),
          enableMemoryOptimization: true,
          maxCachedAccounts: 200,
          maxCachedTransactions: 100,
        );
    }
  }

  /// Get current platform configuration
  static PlatformPerformanceConfig get current =>
      PlatformPerformanceConfig.forPlatform(
          PlatformOptimization.currentPlatform);
}

/// Platform-specific error handling utilities
class PlatformErrorHandler {
  /// Handle platform-specific errors with appropriate user messaging
  static String getErrorMessage(Exception error, PlatformType platform) {
    final String baseMessage = error.toString();

    switch (platform) {
      case PlatformType.mobile:
        return _getMobileErrorMessage(baseMessage);
      case PlatformType.web:
        return _getWebErrorMessage(baseMessage);
      case PlatformType.desktop:
        return _getDesktopErrorMessage(baseMessage);
      case PlatformType.unknown:
        return _getGenericErrorMessage(baseMessage);
    }
  }

  static String _getMobileErrorMessage(String baseMessage) {
    if (baseMessage.contains('network') || baseMessage.contains('connection')) {
      return 'Check your internet connection and try again';
    } else if (baseMessage.contains('timeout')) {
      return 'Request timed out. Poor network connection?';
    } else if (baseMessage.contains('wallet')) {
      return 'Wallet operation failed. Check your wallet app';
    } else {
      return 'Something went wrong. Please try again';
    }
  }

  static String _getWebErrorMessage(String baseMessage) {
    if (baseMessage.contains('network') || baseMessage.contains('connection')) {
      return 'Network error. Please check your connection';
    } else if (baseMessage.contains('timeout')) {
      return 'Request timed out. Please try again';
    } else if (baseMessage.contains('wallet')) {
      return 'Wallet connection failed. Check browser wallet';
    } else {
      return 'An error occurred. Please refresh and try again';
    }
  }

  static String _getDesktopErrorMessage(String baseMessage) {
    if (baseMessage.contains('network') || baseMessage.contains('connection')) {
      return 'Network connection failed. Check your internet connection';
    } else if (baseMessage.contains('timeout')) {
      return 'Operation timed out. Server may be busy';
    } else if (baseMessage.contains('wallet')) {
      return 'Wallet operation failed. Check wallet application';
    } else {
      return 'Operation failed: $baseMessage';
    }
  }

  static String _getGenericErrorMessage(String baseMessage) {
    return 'Operation failed. Please try again';
  }
}

/// Background task management for mobile platforms
class BackgroundTaskManager {
  static final Map<String, Timer> _activeTasks = {};
  static final Map<String, VoidCallback> _taskCallbacks = {};

  /// Register a background task
  static void registerTask(
    String taskId,
    Duration interval,
    VoidCallback callback,
  ) {
    if (!PlatformOptimization.supportsBackgroundProcessing) {
      return; // Skip on unsupported platforms
    }

    // Cancel existing task if any
    cancelTask(taskId);

    _taskCallbacks[taskId] = callback;
    _activeTasks[taskId] = Timer.periodic(interval, (_) {
      try {
        callback();
      } catch (e) {
        // Log error but don't crash background task
        print('Background task $taskId failed: $e');
      }
    });
  }

  /// Cancel a background task
  static void cancelTask(String taskId) {
    _activeTasks[taskId]?.cancel();
    _activeTasks.remove(taskId);
    _taskCallbacks.remove(taskId);
  }

  /// Cancel all background tasks
  static void cancelAllTasks() {
    for (final timer in _activeTasks.values) {
      timer.cancel();
    }
    _activeTasks.clear();
    _taskCallbacks.clear();
  }

  /// Get list of active task IDs
  static List<String> get activeTaskIds => _activeTasks.keys.toList();

  /// Check if a task is active
  static bool isTaskActive(String taskId) => _activeTasks.containsKey(taskId);
}

/// Local storage abstraction for cross-platform compatibility
abstract class PlatformStorage {
  /// Store a value with a key
  Future<void> store(String key, String value);

  /// Retrieve a value by key
  Future<String?> retrieve(String key);

  /// Remove a value by key
  Future<void> remove(String key);

  /// Clear all stored values
  Future<void> clear();

  /// Check if storage is available
  bool get isAvailable;
}

/// Memory-based storage implementation (fallback)
class MemoryStorage implements PlatformStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> store(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> retrieve(String key) async {
    return _storage[key];
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  bool get isAvailable => true;
}

/// Storage factory for platform-specific implementations
class PlatformStorageFactory {
  static PlatformStorage? _instance;

  /// Get platform-appropriate storage implementation
  static PlatformStorage get instance {
    if (_instance != null) return _instance!;

    _instance = _createStorage();
    return _instance!;
  }

  static PlatformStorage _createStorage() {
    if (!PlatformOptimization.supportsLocalStorage) {
      return MemoryStorage();
    }

    // For now, use memory storage as fallback
    // In a real implementation, this would use:
    // - SharedPreferences for mobile
    // - localStorage for web
    // - file system for desktop
    return MemoryStorage();
  }
}
