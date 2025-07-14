/// Mobile platform optimizations for the Coral XYZ Anchor client
///
/// This module provides mobile-specific enhancements including deep linking,
/// background processing, secure storage, and mobile wallet integrations
/// optimized for iOS and Android platforms.

library;

import 'dart:async';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/platform/platform_optimization.dart';

/// Mobile-specific secure storage implementation
class MobileSecureStorage implements PlatformStorage {

  MobileSecureStorage._();
  static MobileSecureStorage? _instance;

  /// Get singleton instance
  static MobileSecureStorage get instance {
    _instance ??= MobileSecureStorage._();
    return _instance!;
  }

  /// In-memory fallback storage (would use secure storage APIs in real mobile environment)
  final Map<String, String> _secureStorage = {};

  @override
  Future<void> store(String key, String value) async {
    try {
      // In a real mobile environment, this would use:
      // - Keychain on iOS (flutter_secure_storage)
      // - Keystore on Android (flutter_secure_storage)
      _secureStorage[key] = value;
    } catch (e) {
      throw Exception('Failed to store secure data: $e');
    }
  }

  @override
  Future<String?> retrieve(String key) async {
    try {
      // In real implementation, would use secure storage APIs
      return _secureStorage[key];
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      _secureStorage.remove(key);
    } catch (e) {
      throw Exception('Failed to remove secure data: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      _secureStorage.clear();
    } catch (e) {
      throw Exception('Failed to clear secure storage: $e');
    }
  }

  @override
  bool get isAvailable => true;
}

/// Deep link handler for mobile wallet integrations
class MobileDeepLinkHandler {
  static final StreamController<DeepLinkData> _deepLinkController =
      StreamController<DeepLinkData>.broadcast();

  /// Stream of incoming deep links
  static Stream<DeepLinkData> get deepLinkStream => _deepLinkController.stream;

  /// Initialize deep link handling
  static Future<void> initialize() async {
    // In real implementation, this would set up platform-specific listeners
    // - iOS: URL schemes and Universal Links
    // - Android: Intent filters and App Links
  }

  /// Handle incoming deep link
  static void handleDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      final deepLinkData = DeepLinkData.fromUri(uri);
      _deepLinkController.add(deepLinkData);
    } catch (e) {
      // Invalid deep link, ignore
    }
  }

  /// Generate deep link for wallet interaction
  static String generateWalletDeepLink({
    required String action,
    Map<String, String>? parameters,
  }) {
    final uri = Uri(
      scheme: 'solana',
      host: 'wallet',
      path: '/$action',
      queryParameters: parameters,
    );
    return uri.toString();
  }

  /// Dispose resources
  static void dispose() {
    _deepLinkController.close();
  }
}

/// Deep link data structure
class DeepLinkData {

  const DeepLinkData({
    required this.scheme,
    required this.host,
    required this.path,
    required this.parameters,
  });

  /// Create from URI
  factory DeepLinkData.fromUri(Uri uri) {
    return DeepLinkData(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path,
      parameters: uri.queryParameters,
    );
  }
  final String scheme;
  final String host;
  final String path;
  final Map<String, String> parameters;

  /// Check if this is a wallet-related deep link
  bool get isWalletLink => scheme == 'solana' && host == 'wallet';

  /// Get action from path
  String? get action => path.startsWith('/') ? path.substring(1) : path;

  @override
  String toString() => 'DeepLinkData($scheme://$host$path)';
}

/// Mobile-optimized connection manager
class MobileConnectionManager {

  MobileConnectionManager(
    this._connection, {
    Duration healthCheckInterval = const Duration(seconds: 30),
  }) : _healthCheckInterval = healthCheckInterval;
  final Connection _connection;
  final Duration _healthCheckInterval;
  final StreamController<ConnectionHealth> _healthController =
      StreamController<ConnectionHealth>.broadcast();

  Timer? _healthCheckTimer;
  ConnectionHealth _currentHealth = ConnectionHealth.unknown;

  /// Current connection health
  ConnectionHealth get health => _currentHealth;

  /// Stream of connection health updates
  Stream<ConnectionHealth> get healthStream => _healthController.stream;

  /// Start health monitoring
  void startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer =
        Timer.periodic(_healthCheckInterval, (_) => _checkHealth());
    _checkHealth(); // Initial check
  }

  /// Stop health monitoring
  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
  }

  /// Check connection health
  Future<void> _checkHealth() async {
    try {
      final healthy = await _connection.checkHealth();
      ConnectionHealth newHealth;
      if (healthy == true) {
        newHealth = ConnectionHealth.healthy;
      } else {
        newHealth = ConnectionHealth.unhealthy;
      }

      if (newHealth != _currentHealth) {
        _currentHealth = newHealth;
        _healthController.add(_currentHealth);
      }
    } catch (e) {
      if (_currentHealth != ConnectionHealth.error) {
        _currentHealth = ConnectionHealth.error;
        _healthController.add(_currentHealth);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    stopHealthMonitoring();
    _healthController.close();
  }
}

/// Connection health status
enum ConnectionHealth {
  unknown,
  healthy,
  unhealthy,
  error,
}

/// Mobile-optimized transaction manager
class MobileTransactionManager {

  MobileTransactionManager(this._provider);
  final AnchorProvider _provider;
  final List<PendingTransaction> _pendingTransactions = [];
  final StreamController<TransactionUpdate> _updateController =
      StreamController<TransactionUpdate>.broadcast();

  /// Stream of transaction updates
  Stream<TransactionUpdate> get transactionUpdates => _updateController.stream;

  /// Get pending transactions
  List<PendingTransaction> get pendingTransactions =>
      List.unmodifiable(_pendingTransactions);

  /// Submit transaction with mobile optimizations
  Future<String> submitTransaction(
    Transaction transaction, {
    bool enableRetry = true,
    Duration timeout = const Duration(seconds: 30),
    void Function(TransactionStatus)? onStatusChange,
  }) async {
    final pendingTx = PendingTransaction(
      transaction: transaction,
      timestamp: DateTime.now(),
      timeout: timeout,
    );

    _pendingTransactions.add(pendingTx);
    _updateController.add(TransactionUpdate(
      transaction: pendingTx,
      status: TransactionStatus.submitting,
    ),);

    try {
      onStatusChange?.call(TransactionStatus.submitting);

      // Submit transaction
      final signature = await _provider.sendAndConfirm(transaction);

      pendingTx.signature = signature;
      pendingTx.status = TransactionStatus.confirmed;

      _updateController.add(TransactionUpdate(
        transaction: pendingTx,
        status: TransactionStatus.confirmed,
      ),);

      onStatusChange?.call(TransactionStatus.confirmed);

      return signature;
    } catch (e) {
      pendingTx.status = TransactionStatus.failed;
      pendingTx.error = e.toString();

      _updateController.add(TransactionUpdate(
        transaction: pendingTx,
        status: TransactionStatus.failed,
        error: e.toString(),
      ),);

      onStatusChange?.call(TransactionStatus.failed);

      if (enableRetry && e.toString().contains('timeout')) {
        // Implement retry logic for mobile networks
        return _retryTransaction(pendingTx, onStatusChange);
      }

      rethrow;
    } finally {
      _pendingTransactions.remove(pendingTx);
    }
  }

  /// Retry failed transaction
  Future<String> _retryTransaction(
    PendingTransaction pendingTx,
    void Function(TransactionStatus)? onStatusChange,
  ) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Future<void>.delayed(retryDelay * attempt);

        pendingTx.status = TransactionStatus.retrying;
        _updateController.add(TransactionUpdate(
          transaction: pendingTx,
          status: TransactionStatus.retrying,
        ),);

        onStatusChange?.call(TransactionStatus.retrying);

        final signature = await _provider.sendAndConfirm(pendingTx.transaction);

        pendingTx.signature = signature;
        pendingTx.status = TransactionStatus.confirmed;

        _updateController.add(TransactionUpdate(
          transaction: pendingTx,
          status: TransactionStatus.confirmed,
        ),);

        onStatusChange?.call(TransactionStatus.confirmed);

        return signature;
      } catch (e) {
        if (attempt == maxRetries) {
          pendingTx.status = TransactionStatus.failed;
          pendingTx.error =
              'Failed after $maxRetries attempts: ${e.toString()}';

          _updateController.add(TransactionUpdate(
            transaction: pendingTx,
            status: TransactionStatus.failed,
            error: pendingTx.error,
          ),);

          onStatusChange?.call(TransactionStatus.failed);
          rethrow;
        }
      }
    }

    throw Exception('Retry loop completed without success');
  }

  /// Clear completed transactions
  void clearCompleted() {
    _pendingTransactions.removeWhere((tx) =>
        tx.status == TransactionStatus.confirmed ||
        tx.status == TransactionStatus.failed,);
  }

  /// Dispose resources
  void dispose() {
    _updateController.close();
  }
}

/// Pending transaction tracking
class PendingTransaction {

  PendingTransaction({
    required this.transaction,
    required this.timestamp,
    required this.timeout,
  });
  final Transaction transaction;
  final DateTime timestamp;
  final Duration timeout;

  String? signature;
  TransactionStatus status = TransactionStatus.pending;
  String? error;

  /// Check if transaction has timed out
  bool get isTimedOut => DateTime.now().difference(timestamp) > timeout;

  /// Get elapsed time
  Duration get elapsed => DateTime.now().difference(timestamp);
}

/// Transaction status for mobile tracking
enum TransactionStatus {
  pending,
  submitting,
  confirmed,
  failed,
  retrying,
}

/// Transaction update event
class TransactionUpdate {

  const TransactionUpdate({
    required this.transaction,
    required this.status,
    this.error,
  });
  final PendingTransaction transaction;
  final TransactionStatus status;
  final String? error;
}

/// Mobile wallet session manager
class MobileWalletSession {

  MobileWalletSession({PlatformStorage? storage})
      : _storage = storage ?? MobileSecureStorage.instance;
  static const String _sessionKey = 'mobile_wallet_session';
  static const Duration _defaultSessionTimeout = Duration(hours: 24);

  final PlatformStorage _storage;
  Timer? _sessionTimer;

  /// Start wallet session
  Future<void> startSession(
    PublicKey walletAddress, {
    Duration? timeout,
  }) async {
    final sessionData = {
      'walletAddress': walletAddress.toBase58(),
      'startTime': DateTime.now().millisecondsSinceEpoch.toString(),
      'timeout': (timeout ?? _defaultSessionTimeout).inMilliseconds.toString(),
    };

    await _storage.store(_sessionKey, sessionData.toString());

    // Set up session timeout
    _sessionTimer?.cancel();
    _sessionTimer = Timer(timeout ?? _defaultSessionTimeout, endSession);
  }

  /// Check if session is active
  Future<bool> isSessionActive() async {
    try {
      final sessionDataStr = await _storage.retrieve(_sessionKey);
      if (sessionDataStr == null) return false;

      // In real implementation, would parse stored session data
      // For demo, assume session is active if data exists
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current session wallet address
  Future<PublicKey?> getSessionWallet() async {
    try {
      final sessionDataStr = await _storage.retrieve(_sessionKey);
      if (sessionDataStr == null) return null;

      // In real implementation, would parse stored session data
      // For demo, return null
      return null;
    } catch (e) {
      return null;
    }
  }

  /// End current session
  Future<void> endSession() async {
    _sessionTimer?.cancel();
    await _storage.remove(_sessionKey);
  }

  /// Extend session timeout
  Future<void> extendSession({Duration? additionalTime}) async {
    if (await isSessionActive()) {
      final currentWallet = await getSessionWallet();
      if (currentWallet != null) {
        await startSession(currentWallet,
            timeout: additionalTime ?? _defaultSessionTimeout,);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _sessionTimer?.cancel();
  }
}

/// Mobile-specific background sync manager
class MobileBackgroundSync {

  MobileBackgroundSync(
    this._provider, {
    PlatformStorage? storage,
  }) : _storage = storage ?? MobileSecureStorage.instance;
  static const Duration _defaultSyncInterval = Duration(minutes: 5);
  static const String _lastSyncKey = 'mobile_last_sync';

  final AnchorProvider _provider;
  final PlatformStorage _storage;
  final List<BackgroundSyncTask> _tasks = [];

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Add background sync task
  void addSyncTask(BackgroundSyncTask task) {
    _tasks.add(task);
  }

  /// Remove background sync task
  void removeSyncTask(String taskId) {
    _tasks.removeWhere((task) => task.id == taskId);
  }

  /// Start background sync
  void startSync({Duration? interval}) {
    if (!PlatformOptimization.supportsBackgroundProcessing) {
      return; // Skip on platforms that don't support background processing
    }

    _syncTimer?.cancel();
    _syncTimer =
        Timer.periodic(interval ?? _defaultSyncInterval, (_) => _performSync());
  }

  /// Stop background sync
  void stopSync() {
    _syncTimer?.cancel();
  }

  /// Perform sync operation
  Future<void> _performSync() async {
    if (_isSyncing || _tasks.isEmpty) return;

    _isSyncing = true;

    try {
      for (final task in _tasks) {
        try {
          await task.execute(_provider);
        } catch (e) {
          // Log error but continue with other tasks
          print('Background sync task ${task.id} failed: $e');
        }
      }

      await _storage.store(
          _lastSyncKey, DateTime.now().millisecondsSinceEpoch.toString(),);
    } catch (e) {
      print('Background sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final lastSyncStr = await _storage.retrieve(_lastSyncKey);
      if (lastSyncStr == null) return null;

      final timestamp = int.parse(lastSyncStr);
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Force immediate sync
  Future<void> forceSync() async {
    await _performSync();
  }

  /// Dispose resources
  void dispose() {
    stopSync();
  }
}

/// Background sync task interface
abstract class BackgroundSyncTask {
  /// Unique task identifier
  String get id;

  /// Execute the background task
  Future<void> execute(AnchorProvider provider);
}

/// Account balance sync task
class AccountBalanceSyncTask implements BackgroundSyncTask {

  const AccountBalanceSyncTask({
    required this.accountId,
    required this.accountAddress,
    required this.onBalanceUpdate,
  });
  final String accountId;
  final PublicKey accountAddress;
  final void Function(int balance) onBalanceUpdate;

  @override
  String get id => 'balance_sync_$accountId';

  @override
  Future<void> execute(AnchorProvider provider) async {
    try {
      final balance = await provider.connection.getBalance(accountAddress);
      onBalanceUpdate(balance);
    } catch (e) {
      // Sync failed, will retry on next cycle
    }
  }
}
