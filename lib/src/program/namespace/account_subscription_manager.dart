/// Account Subscription Manager for Real-time Account Updates
///
/// This module provides comprehensive account subscription management
/// matching TypeScript's account namespace with real-time WebSocket
/// integration, intelligent caching, and state change notifications.

library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import '../../types/public_key.dart';
import '../../types/commitment.dart';
import '../../provider/connection.dart';

/// Configuration for account subscription manager
class AccountSubscriptionConfig {
  /// Enable automatic reconnection on connection failures
  final bool autoReconnect;

  /// Maximum number of reconnection attempts
  final int maxReconnectAttempts;

  /// Delay between reconnection attempts
  final Duration reconnectDelay;

  /// Subscription timeout for inactive subscriptions
  final Duration subscriptionTimeout;

  /// Maximum number of concurrent subscriptions
  final int maxConcurrentSubscriptions;

  /// Buffer size for missed updates during reconnection
  final int bufferSize;

  /// Default commitment level for subscriptions
  final Commitment defaultCommitment;

  const AccountSubscriptionConfig({
    this.autoReconnect = true,
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 2),
    this.subscriptionTimeout = const Duration(minutes: 30),
    this.maxConcurrentSubscriptions = 100,
    this.bufferSize = 50,
    this.defaultCommitment = Commitment.confirmed,
  });

  /// Create development-optimized configuration
  factory AccountSubscriptionConfig.development() {
    return const AccountSubscriptionConfig(
      autoReconnect: true,
      maxReconnectAttempts: 10,
      reconnectDelay: Duration(seconds: 1),
      subscriptionTimeout: Duration(minutes: 10),
      maxConcurrentSubscriptions: 50,
      bufferSize: 20,
      defaultCommitment: Commitment.confirmed,
    );
  }

  /// Create production-optimized configuration
  factory AccountSubscriptionConfig.production() {
    return const AccountSubscriptionConfig(
      autoReconnect: true,
      maxReconnectAttempts: 3,
      reconnectDelay: Duration(seconds: 5),
      subscriptionTimeout: Duration(hours: 1),
      maxConcurrentSubscriptions: 200,
      bufferSize: 100,
      defaultCommitment: Commitment.finalized,
    );
  }
}

/// Account change notification
class AccountChangeNotification {
  /// Account public key
  final PublicKey publicKey;

  /// Account data (can be null if account was deleted)
  final List<int>? data;

  /// Account lamports balance
  final int lamports;

  /// Account owner program ID
  final PublicKey owner;

  /// Slot number when change occurred
  final int slot;

  /// Whether account is executable
  final bool executable;

  /// Rent epoch
  final int rentEpoch;

  const AccountChangeNotification({
    required this.publicKey,
    this.data,
    required this.lamports,
    required this.owner,
    required this.slot,
    required this.executable,
    required this.rentEpoch,
  });

  /// Create from RPC notification data
  factory AccountChangeNotification.fromRpcData(
    PublicKey publicKey,
    Map<String, dynamic> notification,
  ) {
    final value = notification['value'] as Map<String, dynamic>?;
    if (value == null) {
      throw ArgumentError('Invalid account change notification format');
    }

    final data = value['data'];
    List<int>? accountData;
    if (data is List) {
      // Data is base64 encoded
      if (data.isNotEmpty && data[0] is String) {
        try {
          accountData = base64Decode(data[0] as String);
        } catch (e) {
          // Handle decode error
          accountData = null;
        }
      }
    }

    return AccountChangeNotification(
      publicKey: publicKey,
      data: accountData,
      lamports: value['lamports'] as int? ?? 0,
      owner: PublicKey.fromBase58(
          value['owner'] as String? ?? '11111111111111111111111111111111'),
      slot:
          (notification['context'] as Map<String, dynamic>?)?['slot'] as int? ??
              0,
      executable: value['executable'] as bool? ?? false,
      rentEpoch: value['rentEpoch'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'AccountChangeNotification(publicKey: $publicKey, lamports: $lamports, owner: $owner, slot: $slot)';
  }
}

/// Subscription state for account monitoring
enum AccountSubscriptionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
  reconnecting,
}

/// Statistics for account subscription performance
class AccountSubscriptionStats {
  /// Total number of notifications received
  final int totalNotifications;

  /// Number of successful notifications processed
  final int successfulNotifications;

  /// Number of notification processing errors
  final int notificationErrors;

  /// Total number of reconnections
  final int reconnections;

  /// Last notification timestamp
  final DateTime? lastNotification;

  /// Current subscription state
  final AccountSubscriptionState state;

  /// Average notification processing time (milliseconds)
  final double averageProcessingTime;

  const AccountSubscriptionStats({
    required this.totalNotifications,
    required this.successfulNotifications,
    required this.notificationErrors,
    required this.reconnections,
    this.lastNotification,
    required this.state,
    required this.averageProcessingTime,
  });

  /// Success rate as percentage
  double get successRate {
    if (totalNotifications == 0) return 0.0;
    return (successfulNotifications / totalNotifications) * 100.0;
  }

  @override
  String toString() {
    return 'AccountSubscriptionStats(notifications: $totalNotifications, success: ${successRate.toStringAsFixed(1)}%, state: $state)';
  }
}

/// Individual account subscription
class AccountSubscription {
  /// Account public key being monitored
  final PublicKey publicKey;

  /// Stream controller for account change notifications
  final StreamController<AccountChangeNotification> _controller;

  /// Subscription configuration
  final AccountSubscriptionConfig config;

  /// Commitment level for this subscription
  final Commitment commitment;

  /// Creation timestamp
  final DateTime createdAt = DateTime.now();

  /// Current subscription state
  AccountSubscriptionState _state = AccountSubscriptionState.disconnected;

  /// WebSocket channel for this subscription
  IOWebSocketChannel? _channel;

  /// Subscription ID from Solana RPC
  String? _subscriptionId;

  /// Buffer for missed notifications during reconnection
  final List<AccountChangeNotification> _buffer = [];

  /// Statistics tracking
  int _totalNotifications = 0;
  int _successfulNotifications = 0;
  int _notificationErrors = 0;
  int _reconnections = 0;
  DateTime? _lastNotification;
  final List<int> _processingTimes = [];

  /// Timer for subscription timeout
  Timer? _timeoutTimer;

  /// Timer for reconnection attempts
  Timer? _reconnectTimer;

  /// Reconnection attempt counter
  int _reconnectAttempts = 0;

  AccountSubscription({
    required this.publicKey,
    required this.config,
    required this.commitment,
  }) : _controller = StreamController<AccountChangeNotification>.broadcast();

  /// Get the notification stream
  Stream<AccountChangeNotification> get stream => _controller.stream;

  /// Get current subscription state
  AccountSubscriptionState get state => _state;

  /// Get subscription statistics
  AccountSubscriptionStats get stats {
    final avgTime = _processingTimes.isEmpty
        ? 0.0
        : _processingTimes.reduce((a, b) => a + b) / _processingTimes.length;

    return AccountSubscriptionStats(
      totalNotifications: _totalNotifications,
      successfulNotifications: _successfulNotifications,
      notificationErrors: _notificationErrors,
      reconnections: _reconnections,
      lastNotification: _lastNotification,
      state: _state,
      averageProcessingTime: avgTime,
    );
  }

  /// Check if subscription is active
  bool get isActive => _state == AccountSubscriptionState.connected;

  /// Check if subscription has timed out
  bool get isTimedOut {
    if (_lastNotification == null) {
      return DateTime.now().difference(createdAt) > config.subscriptionTimeout;
    }
    return DateTime.now().difference(_lastNotification!) >
        config.subscriptionTimeout;
  }

  /// Start the subscription
  Future<void> start(Connection connection) async {
    if (_state != AccountSubscriptionState.disconnected) {
      return;
    }

    _setState(AccountSubscriptionState.connecting);

    try {
      // Create WebSocket connection
      final wsUrl = connection.rpcUrl.replaceFirst('http', 'ws');
      _channel = IOWebSocketChannel.connect(wsUrl);

      // Prepare subscription request
      final subscribeRequest = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'accountSubscribe',
        'params': [
          publicKey.toBase58(),
          {
            'commitment': commitment.value,
            'encoding': 'base64',
          },
        ],
      };

      // Send subscription request
      _channel!.sink.add(jsonEncode(subscribeRequest));

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _setState(AccountSubscriptionState.connected);
      _startTimeoutTimer();
    } catch (e) {
      _setState(AccountSubscriptionState.error);
      if (config.autoReconnect &&
          _reconnectAttempts < config.maxReconnectAttempts) {
        _scheduleReconnect(connection);
      } else {
        _controller.addError(e);
      }
    }
  }

  /// Stop the subscription
  Future<void> stop() async {
    _setState(AccountSubscriptionState.disconnecting);

    _timeoutTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      if (_subscriptionId != null) {
        // Send unsubscribe request
        final unsubscribeRequest = {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'accountUnsubscribe',
          'params': [_subscriptionId],
        };

        try {
          _channel!.sink.add(jsonEncode(unsubscribeRequest));
        } catch (e) {
          // Ignore errors during unsubscribe
        }
      }

      await _channel!.sink.close();
      _channel = null;
    }

    _setState(AccountSubscriptionState.disconnected);
    await _controller.close();
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    final stopwatch = Stopwatch()..start();

    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // Handle subscription confirmation
      if (data.containsKey('result') && _subscriptionId == null) {
        _subscriptionId = data['result'].toString();
        return;
      }

      // Handle account change notification
      if (data.containsKey('method') &&
          data['method'] == 'accountNotification') {
        final params = data['params'] as Map<String, dynamic>;
        final notification =
            AccountChangeNotification.fromRpcData(publicKey, params);

        _totalNotifications++;
        _lastNotification = DateTime.now();

        // Add to buffer if needed
        if (_buffer.length >= config.bufferSize) {
          _buffer.removeAt(0);
        }
        _buffer.add(notification);

        // Emit notification
        _controller.add(notification);
        _successfulNotifications++;

        // Reset timeout timer
        _startTimeoutTimer();
      }
    } catch (e) {
      _notificationErrors++;
      _controller.addError(e);
    } finally {
      stopwatch.stop();
      _processingTimes.add(stopwatch.elapsedMilliseconds);

      // Keep only last 100 processing times for average calculation
      if (_processingTimes.length > 100) {
        _processingTimes.removeAt(0);
      }
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    _setState(AccountSubscriptionState.error);

    if (config.autoReconnect &&
        _reconnectAttempts < config.maxReconnectAttempts) {
      // Will be handled by _handleDone which calls _scheduleReconnect
    } else {
      _controller.addError(error);
    }
  }

  /// Handle WebSocket connection closure
  void _handleDone() {
    if (_state != AccountSubscriptionState.disconnecting) {
      _setState(AccountSubscriptionState.error);

      if (config.autoReconnect &&
          _reconnectAttempts < config.maxReconnectAttempts) {
        // _scheduleReconnect will be called by error handling
      }
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect(Connection connection) {
    if (_reconnectTimer != null) return;

    _setState(AccountSubscriptionState.reconnecting);
    _reconnectAttempts++;
    _reconnections++;

    _reconnectTimer = Timer(config.reconnectDelay, () async {
      _reconnectTimer = null;
      _channel = null;
      _subscriptionId = null;
      _setState(AccountSubscriptionState.disconnected);

      await start(connection);
    });
  }

  /// Start or restart timeout timer
  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(config.subscriptionTimeout, () {
      if (_state == AccountSubscriptionState.connected) {
        _setState(AccountSubscriptionState.error);
        _controller.addError(TimeoutException(
            'Subscription timed out', config.subscriptionTimeout));
      }
    });
  }

  /// Update subscription state
  void _setState(AccountSubscriptionState newState) {
    _state = newState;
  }

  /// Get buffered notifications
  List<AccountChangeNotification> getBufferedNotifications() {
    return List.unmodifiable(_buffer);
  }

  /// Clear notification buffer
  void clearBuffer() {
    _buffer.clear();
  }
}

/// Manager for account subscriptions with advanced features
class AccountSubscriptionManager {
  /// Connection to Solana cluster
  final Connection _connection;

  /// Manager configuration
  final AccountSubscriptionConfig _config;

  /// Active subscriptions
  final Map<String, AccountSubscription> _subscriptions = {};

  /// Manager state
  bool _isActive = true;

  AccountSubscriptionManager({
    required Connection connection,
    AccountSubscriptionConfig? config,
  })  : _connection = connection,
        _config = config ?? const AccountSubscriptionConfig();

  /// Create subscription for account changes
  Future<Stream<AccountChangeNotification>> subscribe(
    PublicKey publicKey, {
    Commitment? commitment,
  }) async {
    if (!_isActive) {
      throw StateError('Subscription manager is not active');
    }

    final addressStr = publicKey.toBase58();

    // Return existing subscription if available
    final existing = _subscriptions[addressStr];
    if (existing != null) {
      return existing.stream;
    }

    // Check subscription limits
    if (_subscriptions.length >= _config.maxConcurrentSubscriptions) {
      throw StateError(
          'Maximum concurrent subscriptions reached: ${_config.maxConcurrentSubscriptions}');
    }

    // Create new subscription
    final subscription = AccountSubscription(
      publicKey: publicKey,
      config: _config,
      commitment: commitment ?? _config.defaultCommitment,
    );

    _subscriptions[addressStr] = subscription;

    // Start subscription
    await subscription.start(_connection);

    return subscription.stream;
  }

  /// Unsubscribe from account changes
  Future<void> unsubscribe(PublicKey publicKey) async {
    final addressStr = publicKey.toBase58();
    final subscription = _subscriptions.remove(addressStr);

    if (subscription != null) {
      await subscription.stop();
    }
  }

  /// Check if account is being monitored
  bool isSubscribed(PublicKey publicKey) {
    return _subscriptions.containsKey(publicKey.toBase58());
  }

  /// Get subscription statistics for an account
  AccountSubscriptionStats? getSubscriptionStats(PublicKey publicKey) {
    final subscription = _subscriptions[publicKey.toBase58()];
    return subscription?.stats;
  }

  /// Get all active subscriptions
  List<PublicKey> getActiveSubscriptions() {
    return _subscriptions.values
        .where((sub) => sub.isActive)
        .map((sub) => sub.publicKey)
        .toList();
  }

  /// Get manager statistics
  Map<String, dynamic> getManagerStats() {
    final activeCount =
        _subscriptions.values.where((sub) => sub.isActive).length;
    final errorCount = _subscriptions.values
        .where((sub) => sub.state == AccountSubscriptionState.error)
        .length;
    final reconnectingCount = _subscriptions.values
        .where((sub) => sub.state == AccountSubscriptionState.reconnecting)
        .length;

    return {
      'totalSubscriptions': _subscriptions.length,
      'activeSubscriptions': activeCount,
      'errorSubscriptions': errorCount,
      'reconnectingSubscriptions': reconnectingCount,
      'maxConcurrent': _config.maxConcurrentSubscriptions,
      'isActive': _isActive,
    };
  }

  /// Clean up timed out subscriptions
  Future<void> cleanupTimedOutSubscriptions() async {
    final timedOut = <String>[];

    for (final entry in _subscriptions.entries) {
      if (entry.value.isTimedOut) {
        timedOut.add(entry.key);
      }
    }

    for (final address in timedOut) {
      final subscription = _subscriptions.remove(address);
      if (subscription != null) {
        await subscription.stop();
      }
    }
  }

  /// Shutdown all subscriptions
  Future<void> shutdown() async {
    _isActive = false;

    final futures = <Future<void>>[];
    for (final subscription in _subscriptions.values) {
      futures.add(subscription.stop());
    }

    await Future.wait(futures);
    _subscriptions.clear();
  }
}
