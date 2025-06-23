/// Platform integration module for the Coral XYZ Anchor client
///
/// This module provides a unified interface for all platform-specific
/// optimizations and integrations, making it easy to configure the SDK
/// for different deployment environments.

library;

// Platform detection and optimization
export 'platform_optimization.dart';

// Flutter-specific widgets and integrations
export 'flutter_widgets.dart';

// Web platform optimizations
export 'web_optimization.dart' hide CacheEntry;

// Mobile platform optimizations
export 'mobile_optimization.dart' hide TransactionStatus, MobileWalletSession;

import 'dart:async';
import '../provider/anchor_provider.dart';
import '../provider/connection.dart';
import '../provider/wallet.dart';
import '../types/public_key.dart';
import 'platform_optimization.dart';
import 'web_optimization.dart';
import 'mobile_optimization.dart';

/// Unified platform manager for the Coral XYZ Anchor client
class PlatformManager {
  static PlatformManager? _instance;

  /// Platform-specific configuration
  final PlatformConfiguration _configuration;

  /// Storage manager
  PlatformStorage? _storage;

  /// Connection manager (mobile-specific)
  MobileConnectionManager? _connectionManager;

  /// Transaction manager (mobile-specific)
  MobileTransactionManager? _transactionManager;

  /// Wallet session manager (mobile-specific)
  MobileWalletSession? _walletSession;

  /// Background sync manager (mobile-specific)
  MobileBackgroundSync? _backgroundSync;

  /// Deep link handler (mobile-specific)
  bool _deepLinkInitialized = false;

  PlatformManager._(this._configuration);

  /// Get singleton instance
  static PlatformManager get instance {
    _instance ??= PlatformManager._(PlatformConfiguration.current);
    return _instance!;
  }

  /// Initialize platform manager with custom configuration
  static void initialize(PlatformConfiguration configuration) {
    _instance = PlatformManager._(configuration);
  }

  /// Get current platform configuration
  PlatformConfiguration get configuration => _configuration;

  /// Get platform-appropriate storage
  PlatformStorage get storage {
    if (_storage != null) return _storage!;

    switch (PlatformOptimization.currentPlatform) {
      case PlatformType.mobile:
        _storage = MobileSecureStorage.instance;
        break;
      case PlatformType.web:
        _storage = WebStorage.instance;
        break;
      case PlatformType.desktop:
      case PlatformType.unknown:
        _storage = PlatformStorageFactory.instance;
        break;
    }

    return _storage!;
  }

  /// Initialize platform-specific features
  Future<void> initializePlatformFeatures() async {
    switch (PlatformOptimization.currentPlatform) {
      case PlatformType.mobile:
        await _initializeMobileFeatures();
        break;
      case PlatformType.web:
        await _initializeWebFeatures();
        break;
      case PlatformType.desktop:
        await _initializeDesktopFeatures();
        break;
      case PlatformType.unknown:
        // No platform-specific initialization
        break;
    }
  }

  /// Initialize mobile-specific features
  Future<void> _initializeMobileFeatures() async {
    // Initialize deep links
    if (!_deepLinkInitialized) {
      await MobileDeepLinkHandler.initialize();
      _deepLinkInitialized = true;
    }

    // Initialize wallet session
    _walletSession = MobileWalletSession(storage: storage);
  }

  /// Initialize web-specific features
  Future<void> _initializeWebFeatures() async {
    // Web-specific initialization would go here
    // For now, just ensure storage is initialized
    final _ = storage;
  }

  /// Initialize desktop-specific features
  Future<void> _initializeDesktopFeatures() async {
    // Desktop-specific initialization would go here
    // For now, just ensure storage is initialized
    final _ = storage;
  }

  /// Create optimized connection
  Connection createOptimizedConnection(String rpcUrl) {
    final connection = Connection(rpcUrl);

    if (PlatformOptimization.isMobile) {
      _connectionManager = MobileConnectionManager(connection);
      _connectionManager!.startHealthMonitoring();
    }

    return connection;
  }

  /// Create optimized provider
  AnchorProvider createOptimizedProvider(
      Connection connection, Wallet? wallet) {
    final provider = AnchorProvider(connection, wallet);

    if (PlatformOptimization.isMobile) {
      _transactionManager = MobileTransactionManager(provider);
      _backgroundSync = MobileBackgroundSync(provider, storage: storage);
    }

    return provider;
  }

  /// Get connection health (mobile only)
  ConnectionHealth? get connectionHealth => _connectionManager?.health;

  /// Get connection health stream (mobile only)
  Stream<ConnectionHealth>? get connectionHealthStream =>
      _connectionManager?.healthStream;

  /// Start wallet session (mobile only)
  Future<void> startWalletSession(PublicKey walletAddress) async {
    if (PlatformOptimization.isMobile && _walletSession != null) {
      await _walletSession!.startSession(walletAddress);
    }
  }

  /// End wallet session (mobile only)
  Future<void> endWalletSession() async {
    if (PlatformOptimization.isMobile && _walletSession != null) {
      await _walletSession!.endSession();
    }
  }

  /// Check if wallet session is active (mobile only)
  Future<bool> isWalletSessionActive() async {
    if (PlatformOptimization.isMobile && _walletSession != null) {
      return await _walletSession!.isSessionActive();
    }
    return false;
  }

  /// Add background sync task (mobile only)
  void addBackgroundSyncTask(BackgroundSyncTask task) {
    if (PlatformOptimization.isMobile && _backgroundSync != null) {
      _backgroundSync!.addSyncTask(task);
    }
  }

  /// Start background sync (mobile only)
  void startBackgroundSync() {
    if (PlatformOptimization.isMobile && _backgroundSync != null) {
      _backgroundSync!.startSync();
    }
  }

  /// Stop background sync (mobile only)
  void stopBackgroundSync() {
    if (PlatformOptimization.isMobile && _backgroundSync != null) {
      _backgroundSync!.stopSync();
    }
  }

  /// Get available web wallets (web only)
  List<BrowserWalletAdapter> getAvailableWebWallets() {
    if (PlatformOptimization.isWeb) {
      return WebWalletDiscovery.availableWallets;
    }
    return [];
  }

  /// Auto-connect to web wallet (web only)
  Future<BrowserWalletAdapter?> autoConnectWebWallet() async {
    if (PlatformOptimization.isWeb) {
      return await WebWalletDiscovery.autoConnect();
    }
    return null;
  }

  /// Get web performance stats (web only)
  Map<String, Map<String, dynamic>> getWebPerformanceStats() {
    if (PlatformOptimization.isWeb) {
      return WebPerformanceMonitor.getPerformanceStats();
    }
    return {};
  }

  /// Clear web performance stats (web only)
  void clearWebPerformanceStats() {
    if (PlatformOptimization.isWeb) {
      WebPerformanceMonitor.clearStats();
    }
  }

  /// Dispose platform manager resources
  void dispose() {
    _connectionManager?.dispose();
    _transactionManager?.dispose();
    _walletSession?.dispose();
    _backgroundSync?.dispose();

    if (_deepLinkInitialized) {
      MobileDeepLinkHandler.dispose();
      _deepLinkInitialized = false;
    }
  }
}

/// Platform configuration for the Coral XYZ Anchor client
class PlatformConfiguration {
  /// Whether to enable platform-specific optimizations
  final bool enableOptimizations;

  /// Whether to enable background processing (mobile)
  final bool enableBackgroundProcessing;

  /// Whether to enable secure storage (mobile)
  final bool enableSecureStorage;

  /// Whether to enable deep links (mobile)
  final bool enableDeepLinks;

  /// Whether to enable web wallet auto-discovery (web)
  final bool enableWebWalletDiscovery;

  /// Whether to enable performance monitoring (web)
  final bool enablePerformanceMonitoring;

  /// Custom performance configuration
  final PlatformPerformanceConfig? performanceConfig;

  /// Custom storage configuration
  final Map<String, dynamic> storageConfig;

  const PlatformConfiguration({
    this.enableOptimizations = true,
    this.enableBackgroundProcessing = true,
    this.enableSecureStorage = true,
    this.enableDeepLinks = true,
    this.enableWebWalletDiscovery = true,
    this.enablePerformanceMonitoring = true,
    this.performanceConfig,
    this.storageConfig = const {},
  });

  /// Get current platform configuration based on detected platform
  static PlatformConfiguration get current {
    return PlatformConfiguration.forPlatform(
        PlatformOptimization.currentPlatform);
  }

  /// Create configuration for specific platform
  static PlatformConfiguration forPlatform(PlatformType platform) {
    switch (platform) {
      case PlatformType.mobile:
        return const PlatformConfiguration(
          enableOptimizations: true,
          enableBackgroundProcessing: true,
          enableSecureStorage: true,
          enableDeepLinks: true,
          enableWebWalletDiscovery: false,
          enablePerformanceMonitoring: false,
        );

      case PlatformType.web:
        return const PlatformConfiguration(
          enableOptimizations: true,
          enableBackgroundProcessing: false,
          enableSecureStorage: false,
          enableDeepLinks: false,
          enableWebWalletDiscovery: true,
          enablePerformanceMonitoring: true,
        );

      case PlatformType.desktop:
        return const PlatformConfiguration(
          enableOptimizations: true,
          enableBackgroundProcessing: true,
          enableSecureStorage: false,
          enableDeepLinks: false,
          enableWebWalletDiscovery: false,
          enablePerformanceMonitoring: false,
        );

      case PlatformType.unknown:
        return const PlatformConfiguration(
          enableOptimizations: false,
          enableBackgroundProcessing: false,
          enableSecureStorage: false,
          enableDeepLinks: false,
          enableWebWalletDiscovery: false,
          enablePerformanceMonitoring: false,
        );
    }
  }

  /// Create development configuration with all features enabled
  static PlatformConfiguration get development {
    return const PlatformConfiguration(
      enableOptimizations: true,
      enableBackgroundProcessing: true,
      enableSecureStorage: true,
      enableDeepLinks: true,
      enableWebWalletDiscovery: true,
      enablePerformanceMonitoring: true,
    );
  }

  /// Create production configuration with conservative settings
  static PlatformConfiguration get production {
    return PlatformConfiguration.forPlatform(
        PlatformOptimization.currentPlatform);
  }
}

/// Convenience class for quick platform-specific operations
class PlatformUtils {
  /// Get user-friendly error message for current platform
  static String getErrorMessage(Exception error) {
    return PlatformErrorHandler.getErrorMessage(
        error, PlatformOptimization.currentPlatform);
  }

  /// Check if feature is supported on current platform
  static bool isFeatureSupported(PlatformFeature feature) {
    switch (feature) {
      case PlatformFeature.backgroundProcessing:
        return PlatformOptimization.supportsBackgroundProcessing;
      case PlatformFeature.localStorage:
        return PlatformOptimization.supportsLocalStorage;
      case PlatformFeature.deepLinks:
        return PlatformOptimization.isMobile;
      case PlatformFeature.webWallets:
        return PlatformOptimization.isWeb;
    }
  }

  /// Get platform-specific configuration recommendations
  static Map<String, dynamic> getConfigurationRecommendations() {
    final platform = PlatformOptimization.currentPlatform;
    final perfConfig = PlatformPerformanceConfig.forPlatform(platform);

    return {
      'platform': platform.toString(),
      'connectionTimeout': perfConfig.requestTimeout.inSeconds,
      'maxConnections': perfConfig.connectionPoolSize,
      'enableCaching': perfConfig.enableCaching,
      'cacheSize': perfConfig.cacheSizeLimitMB,
      'enableBackgroundSync': perfConfig.enableBackgroundSync,
      'memoryOptimization': perfConfig.enableMemoryOptimization,
    };
  }
}

/// Platform features enumeration
enum PlatformFeature {
  backgroundProcessing,
  localStorage,
  deepLinks,
  webWallets,
}
