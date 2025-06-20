/// Event management system for handling program event subscriptions
///
/// This module provides the EventManager class which handles WebSocket-based
/// event subscriptions, manages multiple event listeners, and provides
/// automatic reconnection and error handling.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../types/public_key.dart';
import '../types/commitment.dart';
import '../provider/anchor_provider.dart';
import '../coder/main_coder.dart';
import 'types.dart';
import 'event_parser.dart';
import 'event_subscription.dart';

/// Manages event subscriptions and WebSocket connections
///
/// The EventManager is responsible for:
/// - Managing WebSocket connections to Solana RPC
/// - Handling multiple event subscriptions
/// - Parsing and distributing events to listeners
/// - Providing automatic reconnection and error handling
class EventManager {
  /// The program ID for event subscriptions
  final PublicKey programId;

  /// The provider for network and wallet context
  final AnchorProvider provider;

  /// The event parser for decoding events
  final EventParser eventParser;

  /// Configuration for event subscriptions
  final EventSubscriptionConfig config;

  /// Active event subscriptions mapped by subscription ID
  final Map<String, _EventSubscription> _subscriptions = {};

  /// Event callbacks mapped by listener ID
  final Map<String, _EventListener> _listeners = {};

  /// Current WebSocket channel
  WebSocketChannel? _webSocketChannel;

  /// Current WebSocket state
  WebSocketState _state = WebSocketState.disconnected;

  /// Stream controller for connection state changes
  final StreamController<WebSocketState> _stateController =
      StreamController.broadcast();

  /// Next listener ID counter
  int _nextListenerId = 1;

  /// Next subscription ID counter
  int _nextSubscriptionId = 1;

  /// Reconnection attempt counter
  int _reconnectAttempts = 0;

  /// Timer for reconnection attempts
  Timer? _reconnectTimer;

  /// Event processing statistics
  final _EventStatistics _stats = _EventStatistics();

  EventManager({
    required this.programId,
    required this.provider,
    required BorshCoder coder,
    this.config = const EventSubscriptionConfig(),
  }) : eventParser = EventParser(programId: programId, coder: coder);

  /// Current WebSocket connection state
  WebSocketState get state => _state;

  /// Stream of connection state changes
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// Current event processing statistics
  EventStats get stats => _stats.toEventStats();

  /// Whether the manager has any active subscriptions
  bool get hasActiveSubscriptions => _subscriptions.isNotEmpty;

  /// Add an event listener for a specific event
  ///
  /// [eventName] - Name of the event to listen for
  /// [callback] - Function to call when the event is received
  /// [filter] - Optional filter for the events
  /// [commitment] - Optional commitment level override
  ///
  /// Returns a subscription that can be used to cancel the listener
  Future<EventSubscription> addEventListener<T>(
    String eventName,
    EventCallback<T> callback, {
    EventFilter? filter,
    CommitmentConfig? commitment,
  }) async {
    final listenerId = 'listener_${_nextListenerId++}';
    final listener = _TypedEventListener<T>(
      id: listenerId,
      eventName: eventName,
      callback: callback,
      filter: filter,
    );

    _listeners[listenerId] = listener;

    // Start WebSocket connection if this is the first listener
    if (_listeners.length == 1) {
      await _ensureConnection(commitment ?? config.commitment);
    }

    return _EventListenerSubscription(
      id: listenerId,
      manager: this,
      filter: filter,
    );
  }

  /// Add a generic event listener for all events
  ///
  /// [callback] - Function to call when any event is received
  /// [filter] - Optional filter for the events
  /// [commitment] - Optional commitment level override
  ///
  /// Returns a subscription that can be used to cancel the listener
  Future<EventSubscription> addGenericEventListener(
    GenericEventCallback callback, {
    EventFilter? filter,
    CommitmentConfig? commitment,
  }) async {
    final listenerId = 'generic_listener_${_nextListenerId++}';
    final listener = _GenericEventListener(
      id: listenerId,
      callback: callback,
      filter: filter,
    );

    _listeners[listenerId] = listener;

    // Start WebSocket connection if this is the first listener
    if (_listeners.length == 1) {
      await _ensureConnection(commitment ?? config.commitment);
    }

    return _EventListenerSubscription(
      id: listenerId,
      manager: this,
      filter: filter,
    );
  }

  /// Remove an event listener
  ///
  /// [listenerId] - ID of the listener to remove
  Future<void> removeEventListener(String listenerId) async {
    _listeners.remove(listenerId);

    // Close WebSocket connection if no listeners remain
    if (_listeners.isEmpty) {
      await _closeConnection();
    }
  }

  /// Subscribe to logs for the program
  ///
  /// [callback] - Function to call when logs are received
  /// [commitment] - Optional commitment level override
  ///
  /// Returns a subscription that can be used to cancel the log listener
  Future<EventSubscription> subscribeToLogs(
    LogCallback callback, {
    CommitmentConfig? commitment,
  }) async {
    final subscriptionId = 'logs_${_nextSubscriptionId++}';
    final subscription = _LogSubscription(
      id: subscriptionId,
      callback: callback,
      manager: this,
    );

    _subscriptions[subscriptionId] = subscription;

    // Start WebSocket connection if needed
    await _ensureConnection(commitment ?? config.commitment);

    return subscription;
  }

  /// Close all subscriptions and connections
  Future<void> dispose() async {
    _listeners.clear();
    _subscriptions.clear();

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _closeConnection();
    await _stateController.close();
  }

  /// Ensure WebSocket connection is established
  Future<void> _ensureConnection(CommitmentConfig commitment) async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting) {
      return;
    }

    await _connect(commitment);
  }

  /// Establish WebSocket connection
  Future<void> _connect(CommitmentConfig commitment) async {
    if (_state == WebSocketState.connecting ||
        _state == WebSocketState.connected) {
      return;
    }

    _setState(WebSocketState.connecting);

    try {
      final wsUrl = _getWebSocketUrl();
      _webSocketChannel = IOWebSocketChannel.connect(wsUrl);

      // Subscribe to logs for our program
      final subscribeRequest = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'logsSubscribe',
        'params': [
          programId.toBase58(),
          {
            'commitment': commitment.commitment.value,
            'encoding': 'jsonParsed',
          }
        ]
      };

      _webSocketChannel!.sink.add(jsonEncode(subscribeRequest));

      // Listen for messages
      _webSocketChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClosed,
      );

      _setState(WebSocketState.connected);
      _reconnectAttempts = 0;
    } catch (e) {
      _setState(WebSocketState.disconnected);
      await _handleConnectionError(e, commitment);
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      if (data.containsKey('method') && data['method'] == 'logsNotification') {
        _handleLogsNotification(data['params'] as Map<String, dynamic>);
      }
    } catch (e) {
      _stats.incrementError();
      // Log error but continue processing
    }
  }

  /// Handle logs notification from WebSocket
  void _handleLogsNotification(Map<String, dynamic> params) {
    try {
      final result = params['result'] as Map<String, dynamic>;
      final context = result['context'] as Map<String, dynamic>;
      final value = result['value'] as Map<String, dynamic>;

      final notification = LogsNotification(
        signature: value['signature'] as String,
        logs: (value['logs'] as List<dynamic>).cast<String>(),
        err: value['err'] as String?,
        slot: context['slot'] as int,
      );

      _stats.incrementTotal();

      // Skip failed transactions if not configured to include them
      if (!config.includeFailed && !notification.isSuccess) {
        _stats.incrementFiltered();
        return;
      }

      // Notify log subscribers
      for (final subscription in _subscriptions.values) {
        if (subscription is _LogSubscription) {
          subscription.callback(notification);
        }
      }

      // Parse and distribute events
      _processLogsForEvents(notification);
    } catch (e) {
      _stats.incrementError();
      // Log error but continue processing
    }
  }

  /// Process logs to extract and distribute events
  void _processLogsForEvents(LogsNotification notification) {
    try {
      final eventContext = EventContext(
        slot: notification.slot,
        signature: notification.signature,
        blockTime: notification.blockTime,
      );

      final events = eventParser.parseLogs(
        notification.logs,
        context: eventContext,
      );

      for (final event in events) {
        _stats.incrementParsed();
        _distributeEvent(event);
      }
    } catch (e) {
      _stats.incrementError();
      // Log error but continue processing
    }
  }

  /// Distribute an event to all matching listeners
  void _distributeEvent(ParsedEvent event) {
    for (final listener in _listeners.values) {
      try {
        if (listener.matches(event, programId)) {
          listener.handleEvent(event);
        } else {
          _stats.incrementFiltered();
        }
      } catch (e) {
        _stats.incrementError();
        // Log error but continue processing other listeners
      }
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(dynamic error) {
    _stats.incrementError();
    _setState(WebSocketState.disconnected);

    // Attempt reconnection if we have active listeners/subscriptions
    if (hasActiveSubscriptions || _listeners.isNotEmpty) {
      _scheduleReconnection();
    }
  }

  /// Handle WebSocket connection closed
  void _handleWebSocketClosed() {
    _setState(WebSocketState.disconnected);

    // Attempt reconnection if we have active listeners/subscriptions
    if (hasActiveSubscriptions || _listeners.isNotEmpty) {
      _scheduleReconnection();
    }
  }

  /// Handle connection errors and retry logic
  Future<void> _handleConnectionError(
      dynamic error, CommitmentConfig commitment) async {
    _stats.incrementError();

    if (_reconnectAttempts < config.maxReconnectAttempts) {
      _scheduleReconnection(commitment);
    } else {
      _setState(WebSocketState.closed);
    }
  }

  /// Schedule a reconnection attempt
  void _scheduleReconnection([CommitmentConfig? commitment]) {
    if (_state == WebSocketState.closed) return;

    _setState(WebSocketState.reconnecting);
    _reconnectAttempts++;

    final delay = Duration(
      milliseconds: math.min(
        1000 * math.pow(2, _reconnectAttempts).toInt(),
        config.reconnectTimeout.inMilliseconds,
      ),
    );

    _reconnectTimer = Timer(delay, () async {
      await _connect(commitment ?? config.commitment);
    });
  }

  /// Close the WebSocket connection
  Future<void> _closeConnection() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _webSocketChannel?.sink.close();
    _webSocketChannel = null;

    _setState(WebSocketState.disconnected);
  }

  /// Update connection state and notify listeners
  void _setState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Get WebSocket URL from provider
  String _getWebSocketUrl() {
    final rpcUrl = provider.connection.endpoint;

    // Convert HTTP(S) URL to WebSocket URL
    if (rpcUrl.startsWith('https://')) {
      return rpcUrl.replaceFirst('https://', 'wss://');
    } else if (rpcUrl.startsWith('http://')) {
      return rpcUrl.replaceFirst('http://', 'ws://');
    } else {
      return rpcUrl; // Assume it's already a WebSocket URL
    }
  }
}

/// Internal event listener implementation
abstract class _EventListener {
  final String id;
  final EventFilter? filter;

  const _EventListener({
    required this.id,
    this.filter,
  });

  bool matches(ParsedEvent event, PublicKey programId) {
    return filter?.matches(event, programId) ?? true;
  }

  void handleEvent(ParsedEvent event);
}

/// Typed event listener
class _TypedEventListener<T> extends _EventListener {
  final String eventName;
  final EventCallback<T> callback;

  const _TypedEventListener({
    required String id,
    required this.eventName,
    required this.callback,
    EventFilter? filter,
  }) : super(id: id, filter: filter);

  @override
  bool matches(ParsedEvent event, PublicKey programId) {
    return event.name == eventName && super.matches(event, programId);
  }

  @override
  void handleEvent(ParsedEvent event) {
    callback(event.data as T, event.context.slot, event.context.signature);
  }
}

/// Generic event listener for all events
class _GenericEventListener extends _EventListener {
  final GenericEventCallback callback;

  const _GenericEventListener({
    required String id,
    required this.callback,
    EventFilter? filter,
  }) : super(id: id, filter: filter);

  @override
  void handleEvent(ParsedEvent event) {
    callback(event.data, event.context.slot, event.context.signature);
  }
}

/// Internal event subscription implementation
abstract class _EventSubscription implements EventSubscription {
  final String id;
  final EventManager manager;
  final DateTime createdAt = DateTime.now();

  _EventSubscription({
    required this.id,
    required this.manager,
  });

  @override
  bool get isActive => manager._subscriptions.containsKey(id);

  @override
  Future<void> cancel() async {
    manager._subscriptions.remove(id);
  }

  @override
  EventStats get stats => manager.stats;
}

/// Event listener subscription implementation
class _EventListenerSubscription extends _EventSubscription {
  final EventFilter? filter;

  _EventListenerSubscription({
    required String id,
    required EventManager manager,
    this.filter,
  }) : super(id: id, manager: manager);

  @override
  Future<void> cancel() async {
    await manager.removeEventListener(id);
  }
}

/// Log subscription implementation
class _LogSubscription extends _EventSubscription {
  final LogCallback callback;

  _LogSubscription({
    required String id,
    required this.callback,
    required EventManager manager,
  }) : super(id: id, manager: manager);

  @override
  EventFilter? get filter => null;
}

/// Event statistics tracker
class _EventStatistics {
  int _totalEvents = 0;
  int _parsedEvents = 0;
  int _parseErrors = 0;
  int _filteredEvents = 0;
  DateTime _lastProcessed = DateTime.now();
  final List<int> _recentEvents = [];

  void incrementTotal() {
    _totalEvents++;
    _lastProcessed = DateTime.now();
    _addRecentEvent();
  }

  void incrementParsed() {
    _parsedEvents++;
  }

  void incrementError() {
    _parseErrors++;
  }

  void incrementFiltered() {
    _filteredEvents++;
  }

  void _addRecentEvent() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentEvents.add(now);

    // Keep only events from the last 60 seconds
    final cutoff = now - 60000;
    _recentEvents.removeWhere((timestamp) => timestamp < cutoff);
  }

  double get _eventsPerSecond {
    if (_recentEvents.isEmpty) return 0.0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = (now - _recentEvents.first) / 1000.0;

    return duration > 0 ? _recentEvents.length / duration : 0.0;
  }

  EventStats toEventStats() {
    return EventStats(
      totalEvents: _totalEvents,
      parsedEvents: _parsedEvents,
      parseErrors: _parseErrors,
      filteredEvents: _filteredEvents,
      lastProcessed: _lastProcessed,
      eventsPerSecond: _eventsPerSecond,
    );
  }
}
