/// Web platform optimizations for the Coral XYZ Anchor client
///
/// This module provides web-specific enhancements and optimizations for
/// browser environments, including WebWorker support, IndexedDB storage,
/// and browser wallet integrations.

library;

import 'dart:async';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/platform/platform_optimization.dart';

/// Web-specific storage implementation using browser APIs
class WebStorage implements PlatformStorage {

  WebStorage._();
  static WebStorage? _instance;

  /// Get singleton instance
  static WebStorage get instance {
    _instance ??= WebStorage._();
    return _instance!;
  }

  /// In-memory fallback storage (would use localStorage in real web environment)
  final Map<String, String> _memoryStorage = {};

  @override
  Future<void> store(String key, String value) async {
    try {
      // In a real web environment, this would use:
      // window.localStorage[key] = value;
      _memoryStorage[key] = value;
    } catch (e) {
      throw Exception('Failed to store data: $e');
    }
  }

  @override
  Future<String?> retrieve(String key) async {
    try {
      // In a real web environment, this would use:
      // return window.localStorage[key];
      return _memoryStorage[key];
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      // In a real web environment, this would use:
      // window.localStorage.remove(key);
      _memoryStorage.remove(key);
    } catch (e) {
      throw Exception('Failed to remove data: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      // In a real web environment, this would use:
      // window.localStorage.clear();
      _memoryStorage.clear();
    } catch (e) {
      throw Exception('Failed to clear storage: $e');
    }
  }

  @override
  bool get isAvailable => true; // Always available in fallback mode
}

/// Web-specific connection optimizations
class WebConnectionOptimizer {
  /// Optimize connection for web environment
  static Map<String, dynamic> getWebOptimizedConfig() => {
      'keepAlive': true,
      'timeout': PlatformOptimization.connectionTimeout.inMilliseconds,
      'maxConcurrentRequests': PlatformOptimization.maxConcurrentConnections,
      'enableCompression': true,
      'userAgent': 'Coral-XYZ-Anchor-Dart-Web/1.0',
      'headers': {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    };

  /// Get web-specific retry configuration
  static Map<String, dynamic> getRetryConfig() => {
      'maxRetries': 3,
      'retryDelay': PlatformOptimization.retryDelay.inMilliseconds,
      'exponentialBackoff': true,
      'retryOn': ['timeout', 'network_error', '5xx'],
    };
}

/// Browser wallet adapter interface
abstract class BrowserWalletAdapter extends WalletAdapter {
  /// Whether the wallet extension is installed
  bool get isInstalled;

  /// URL to install the wallet extension
  String get installUrl;

  /// Request connection to the wallet
  Future<void> requestConnection();

  /// Check if the wallet is ready for connection
  Future<bool> isReady();
}

/// Phantom wallet adapter (placeholder implementation)
class PhantomWalletAdapter implements BrowserWalletAdapter {
  bool _connected = false;
  PublicKey? _publicKey;

  final StreamController<bool> _connectController =
      StreamController<bool>.broadcast();
  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();
  final StreamController<PublicKey?> _accountChangeController =
      StreamController<PublicKey?>.broadcast();

  @override
  String get name => 'Phantom';

  @override
  String? get icon => 'https://phantom.app/img/logo.png';

  @override
  String? get url => 'https://phantom.app';

  @override
  String get installUrl => 'https://phantom.app';

  @override
  bool get readyState => isInstalled;

  @override
  bool get isInstalled {
    // In a real implementation, this would check:
    // return window.phantom?.solana != null;
    return true; // Mock implementation
  }

  @override
  PublicKey? get publicKey => _publicKey;

  @override
  bool get connected => _connected;

  @override
  Future<bool> isReady() async => isInstalled;

  @override
  Future<void> requestConnection() async {
    if (!isInstalled) {
      throw Exception(
          'Phantom wallet is not installed. Install from: $installUrl',);
    }

    // Mock connection request
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // In real implementation, this would call phantom.solana.connect()
  }

  @override
  Future<void> connect() async {
    if (_connected) return;

    await requestConnection();

    // Mock successful connection
    _connected = true;
    _publicKey =
        PublicKey.fromBase58('11111111111111111111111111111112'); // Mock key
    _connectController.add(true);
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;

    _connected = false;
    _publicKey = null;
    _disconnectController.add(null);
  }

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (!_connected || _publicKey == null) {
      throw const WalletNotConnectedException();
    }

    // Mock signing
    final signature = Uint8List.fromList(List.filled(64, 1));
    transaction.addSignature(_publicKey!, signature);
    return transaction;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions,) async {
    final signed = <Transaction>[];
    for (final tx in transactions) {
      signed.add(await signTransaction(tx));
    }
    return signed;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (!_connected) {
      throw const WalletNotConnectedException();
    }

    // Mock message signing
    return Uint8List.fromList(List.filled(64, 2));
  }

  @override
  Stream<bool> get onConnect => _connectController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<PublicKey?> get onAccountChange => _accountChangeController.stream;
}

/// Solflare wallet adapter (placeholder implementation)
class SolflareWalletAdapter implements BrowserWalletAdapter {
  bool _connected = false;
  PublicKey? _publicKey;

  final StreamController<bool> _connectController =
      StreamController<bool>.broadcast();
  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();
  final StreamController<PublicKey?> _accountChangeController =
      StreamController<PublicKey?>.broadcast();

  @override
  String get name => 'Solflare';

  @override
  String? get icon => 'https://solflare.com/img/logo.png';

  @override
  String? get url => 'https://solflare.com';

  @override
  String get installUrl => 'https://solflare.com';

  @override
  bool get readyState => isInstalled;

  @override
  bool get isInstalled {
    // In a real implementation, this would check:
    // return window.solflare?.isSolflare != null;
    return true; // Mock implementation
  }

  @override
  PublicKey? get publicKey => _publicKey;

  @override
  bool get connected => _connected;

  @override
  Future<bool> isReady() async => isInstalled;

  @override
  Future<void> requestConnection() async {
    if (!isInstalled) {
      throw Exception(
          'Solflare wallet is not installed. Install from: $installUrl',);
    }

    // Mock connection request
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> connect() async {
    if (_connected) return;

    await requestConnection();

    _connected = true;
    _publicKey =
        PublicKey.fromBase58('11111111111111111111111111111113'); // Mock key
    _connectController.add(true);
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;

    _connected = false;
    _publicKey = null;
    _disconnectController.add(null);
  }

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (!_connected || _publicKey == null) {
      throw const WalletNotConnectedException();
    }

    final signature = Uint8List.fromList(List.filled(64, 3));
    transaction.addSignature(_publicKey!, signature);
    return transaction;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions,) async {
    final signed = <Transaction>[];
    for (final tx in transactions) {
      signed.add(await signTransaction(tx));
    }
    return signed;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (!_connected) {
      throw const WalletNotConnectedException();
    }

    return Uint8List.fromList(List.filled(64, 4));
  }

  @override
  Stream<bool> get onConnect => _connectController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<PublicKey?> get onAccountChange => _accountChangeController.stream;
}

/// Web wallet discovery and management
class WebWalletDiscovery {
  static final List<BrowserWalletAdapter> _availableWallets = [
    PhantomWalletAdapter(),
    SolflareWalletAdapter(),
  ];

  /// Get list of available browser wallet adapters
  static List<BrowserWalletAdapter> get availableWallets => _availableWallets;

  /// Get list of installed wallet adapters
  static List<BrowserWalletAdapter> get installedWallets =>
      _availableWallets.where((wallet) => wallet.isInstalled).toList();

  /// Get wallet adapter by name
  static BrowserWalletAdapter? getWalletByName(String name) {
    try {
      return _availableWallets.firstWhere(
        (wallet) => wallet.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Auto-detect and connect to the best available wallet
  static Future<BrowserWalletAdapter?> autoConnect() async {
    final installedWallets = WebWalletDiscovery.installedWallets;

    if (installedWallets.isEmpty) {
      return null;
    }

    // Try to connect to the first available wallet
    final wallet = installedWallets.first;

    try {
      await wallet.connect();
      return wallet;
    } catch (e) {
      return null;
    }
  }

  /// Check wallet installation status
  static Map<String, bool> getInstallationStatus() {
    final status = <String, bool>{};
    for (final wallet in _availableWallets) {
      status[wallet.name] = wallet.isInstalled;
    }
    return status;
  }
}

/// Web-specific performance monitor
class WebPerformanceMonitor {
  static final Map<String, List<Duration>> _requestTimes = {};
  static final Map<String, int> _requestCounts = {};
  static final Map<String, int> _errorCounts = {};

  /// Record request performance
  static void recordRequest(String endpoint, Duration duration,
      {bool success = true,}) {
    _requestTimes.putIfAbsent(endpoint, () => []).add(duration);
    _requestCounts[endpoint] = (_requestCounts[endpoint] ?? 0) + 1;

    if (!success) {
      _errorCounts[endpoint] = (_errorCounts[endpoint] ?? 0) + 1;
    }
  }

  /// Get average request time for endpoint
  static Duration? getAverageRequestTime(String endpoint) {
    final times = _requestTimes[endpoint];
    if (times == null || times.isEmpty) return null;

    final totalMs = times.map((t) => t.inMilliseconds).reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ times.length);
  }

  /// Get error rate for endpoint
  static double getErrorRate(String endpoint) {
    final total = _requestCounts[endpoint] ?? 0;
    final errors = _errorCounts[endpoint] ?? 0;

    if (total == 0) return 0;
    return errors / total;
  }

  /// Get performance statistics
  static Map<String, Map<String, dynamic>> getPerformanceStats() {
    final stats = <String, Map<String, dynamic>>{};

    for (final endpoint in _requestCounts.keys) {
      stats[endpoint] = {
        'requestCount': _requestCounts[endpoint] ?? 0,
        'errorCount': _errorCounts[endpoint] ?? 0,
        'errorRate': getErrorRate(endpoint),
        'averageTime': getAverageRequestTime(endpoint)?.inMilliseconds,
      };
    }

    return stats;
  }

  /// Clear performance data
  static void clearStats() {
    _requestTimes.clear();
    _requestCounts.clear();
    _errorCounts.clear();
  }
}

/// Web-specific caching using IndexedDB concepts
class WebCacheManager {
  static final Map<String, CacheEntry> _cache = {};
  static final int _maxCacheSize =
      PlatformOptimization.cacheSizeLimitMB * 1024 * 1024; // Convert to bytes
  static int _currentCacheSize = 0;

  /// Store data in cache
  static Future<void> store(String key, dynamic data,
      {Duration? expiration,}) async {
    final entry = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      expiration: expiration,
    );

    final dataSize = _estimateSize(data);

    // Check if we need to evict entries
    if (_currentCacheSize + dataSize > _maxCacheSize) {
      await _evictOldEntries();
    }

    _cache[key] = entry;
    _currentCacheSize += dataSize;
  }

  /// Retrieve data from cache
  static Future<T?> retrieve<T>(String key) async {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check if expired
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  /// Remove entry from cache
  static Future<void> remove(String key) async {
    _cache.remove(key);
  }

  /// Clear all cache
  static Future<void> clear() async {
    _cache.clear();
    _currentCacheSize = 0;
  }

  /// Get cache statistics
  static Map<String, dynamic> getStats() {
    final expiredCount = _cache.values.where((e) => e.isExpired).length;

    return {
      'totalEntries': _cache.length,
      'expiredEntries': expiredCount,
      'cacheSize': _currentCacheSize,
      'maxCacheSize': _maxCacheSize,
      'utilization': _currentCacheSize / _maxCacheSize,
    };
  }

  /// Evict old and expired entries
  static Future<void> _evictOldEntries() async {
    final entries = _cache.entries.toList();

    // Sort by timestamp (oldest first)
    entries.sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    // Remove expired entries first
    for (final entry in entries) {
      if (entry.value.isExpired) {
        _cache.remove(entry.key);
      }
    }

    // If still over limit, remove oldest entries
    final remainingEntries = _cache.entries.toList();
    remainingEntries
        .sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    while (_currentCacheSize > _maxCacheSize * 0.8 &&
        remainingEntries.isNotEmpty) {
      final entry = remainingEntries.removeAt(0);
      _cache.remove(entry.key);
      _currentCacheSize -= _estimateSize(entry.value.data);
    }
  }

  /// Estimate size of data in bytes (rough approximation)
  static int _estimateSize(dynamic data) {
    if (data is String) {
      return data.length * 2; // Rough UTF-16 estimation
    } else if (data is List) {
      return data.length * 8; // Rough estimation
    } else if (data is Map) {
      return data.keys.length * 16; // Very rough estimation
    } else {
      return 64; // Default size
    }
  }
}

/// Cache entry for web storage
class CacheEntry {

  const CacheEntry({
    required this.data,
    required this.timestamp,
    this.expiration,
  });
  final dynamic data;
  final DateTime timestamp;
  final Duration? expiration;

  /// Check if entry is expired
  bool get isExpired {
    if (expiration == null) return false;
    return DateTime.now().difference(timestamp) > expiration!;
  }
}
