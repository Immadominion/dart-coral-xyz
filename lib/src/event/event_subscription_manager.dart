import 'dart:async';

import '../provider/connection.dart' show Connection, LogsNotification;
import '../types/public_key.dart';
import 'event_definition.dart';
import 'event_log_parser.dart' show EventLogParser, ParsedEvent;
import 'types.dart' show EventSubscriptionConfig;

/// Event subscription manager for real-time event monitoring
/// Uses Connection.onLogs for TypeScript-compatible event subscription
class EventSubscriptionManager {
  /// Connection for RPC calls and subscriptions
  final Connection _connection;

  /// Program ID to monitor
  final PublicKey _programId;

  /// Event definitions for parsing
  final List<EventDefinition> _eventDefinitions;

  /// Configuration for the subscription
  final EventSubscriptionConfig _config;

  /// Current connection state
  ConnectionState _connectionState = ConnectionState.disconnected;

  /// Event log parser
  late final EventLogParser _parser;

  /// Active subscriptions
  final Map<String, EventSubscription> _subscriptions = {};

  /// Event stream controller
  final StreamController<ParsedEvent> _eventController =
      StreamController.broadcast();

  /// Subscription metrics
  final EventSubscriptionMetrics _metrics = EventSubscriptionMetrics();

  /// WebSocket logs subscription ID
  String? _logsSubscriptionId;

  /// Event buffer for when disconnected
  final List<ParsedEvent> _eventBuffer = [];

  /// Subscription counter for unique IDs
  int _subscriptionCounter = 0;

  EventSubscriptionManager({
    required Connection connection,
    required PublicKey programId,
    required List<EventDefinition> eventDefinitions,
    EventSubscriptionConfig? config,
  })  : _connection = connection,
        _programId = programId,
        _eventDefinitions = eventDefinitions,
        _config = config ?? const EventSubscriptionConfig() {
    _parser = EventLogParser.fromEvents(_programId, _eventDefinitions);
  }

  /// Current connection state
  ConnectionState get connectionState => _connectionState;

  /// Event stream for listening to all events
  Stream<ParsedEvent> get eventStream => _eventController.stream;

  /// Current metrics
  EventSubscriptionMetrics get metrics => _metrics;

  /// Connect to the event source
  Future<void> connect() async {
    if (_connectionState == ConnectionState.connected) return;

    _connectionState = ConnectionState.connecting;

    try {
      // Use Connection's onLogs method (TypeScript pattern)
      _logsSubscriptionId = await _connection.onLogs(
        _programId,
        _handleLogsNotification,
        commitment: _config.commitment,
      );

      _connectionState = ConnectionState.connected;
      _metrics.connectionCount++;
    } catch (e) {
      _connectionState = ConnectionState.error;
      _metrics.errorCount++;
      rethrow;
    }
  }

  /// Disconnect from the event source
  Future<void> disconnect() async {
    if (_connectionState == ConnectionState.disconnected) return;

    _connectionState = ConnectionState.disconnecting;

    try {
      if (_logsSubscriptionId != null) {
        await _connection.removeOnLogsListener(_logsSubscriptionId!);
        _logsSubscriptionId = null;
      }
    } finally {
      _connectionState = ConnectionState.disconnected;
    }
  }

  /// Handle logs notification from Connection.onLogs
  void _handleLogsNotification(LogsNotification notification) {
    _metrics.messagesReceived++;

    // Only process successful transactions (or if config allows failed)
    if (!notification.isSuccess && !_config.includeFailed) {
      return;
    }

    // Parse events from logs using the parseLogs method
    try {
      final events = _parser.parseLogs(notification.logs);

      for (final event in events) {
        _processEvent(event);
      }
    } catch (e) {
      _metrics.errorCount++;
      // Continue processing other events even if one fails
    }
  }

  /// Process a parsed event
  void _processEvent(ParsedEvent event) {
    _metrics.eventsProcessed++;

    // Buffer events if configured and disconnected
    if (_config.maxBufferSize != null &&
        _connectionState != ConnectionState.connected) {
      _bufferEvent(event);
      return;
    }

    // Deliver to subscriptions
    _deliverEvent(event);

    // Add to event stream
    _eventController.add(event);
  }

  /// Buffer an event
  void _bufferEvent(ParsedEvent event) {
    if (_config.maxBufferSize == null) return;

    _eventBuffer.add(event);

    // Remove oldest events if buffer is full
    while (_eventBuffer.length > _config.maxBufferSize!) {
      _eventBuffer.removeAt(0);
    }
  }

  /// Deliver event to matching subscriptions
  void _deliverEvent(ParsedEvent event) {
    for (final subscription in _subscriptions.values) {
      try {
        // Check if subscription matches
        if (_subscriptionMatches(subscription, event)) {
          subscription.onEvent?.call(event);
          _metrics.notificationsDelivered++;
        }
      } catch (e) {
        _metrics.errorCount++;
        subscription.onError?.call(
          EventSubscriptionError(
            type: EventSubscriptionErrorType.handlerError,
            message: 'Event handler threw exception: $e',
          ),
        );
      }
    }
  }

  /// Check if subscription matches event
  bool _subscriptionMatches(EventSubscription subscription, ParsedEvent event) {
    // Check event name filter
    if (subscription.eventName != null &&
        subscription.eventName != event.name) {
      return false;
    }

    // Check event filter
    if (subscription.filter != null) {
      return subscription.filter!.matches(event);
    }

    return true;
  }

  /// Subscribe to events by name
  EventSubscription subscribe({
    required String eventName,
    void Function(ParsedEvent)? onEvent,
    void Function(EventSubscriptionError)? onError,
  }) {
    final subscription = EventSubscription(
      id: 'sub_${_subscriptionCounter++}',
      eventName: eventName,
      onEvent: onEvent,
      onError: onError,
      createdAt: DateTime.now(),
    );

    _subscriptions[subscription.id] = subscription;
    _metrics.subscriptionCount++;

    return subscription;
  }

  /// Subscribe with filter
  EventSubscription subscribeFiltered({
    required List<String> eventNames,
    Map<String, dynamic>? dataFilters,
    bool Function(ParsedEvent)? customFilter,
    void Function(ParsedEvent)? onEvent,
    void Function(EventSubscriptionError)? onError,
  }) {
    final filter = EventFilter(
      eventNames: eventNames.toSet(),
      dataFilters: dataFilters,
      customFilter: customFilter,
    );

    final subscription = EventSubscription(
      id: 'sub_${_subscriptionCounter++}',
      filter: filter,
      onEvent: onEvent,
      onError: onError,
      createdAt: DateTime.now(),
    );

    _subscriptions[subscription.id] = subscription;
    _metrics.subscriptionCount++;

    return subscription;
  }

  /// Unsubscribe from events
  Future<void> unsubscribe(String subscriptionId) async {
    final subscription = _subscriptions.remove(subscriptionId);
    if (subscription != null) {
      _metrics.subscriptionCount--;
    }
  }

  /// Get active subscriptions
  List<EventSubscription> getActiveSubscriptions() {
    return _subscriptions.values.toList();
  }

  /// Get subscription by ID
  EventSubscription? getSubscription(String id) {
    return _subscriptions[id];
  }

  /// Get buffered events
  List<ParsedEvent> getBufferedEvents() {
    return List.from(_eventBuffer);
  }

  /// Clear event buffer
  void clearEventBuffer() {
    _eventBuffer.clear();
  }

  /// Close and dispose resources
  void dispose() {
    _eventController.close();
    disconnect();
  }
}

/// Event subscription configuration compatible with both old and new APIs
class LegacyEventSubscriptionConfig {
  /// Whether to automatically reconnect on connection loss
  final bool autoReconnect;

  /// Maximum reconnection attempts
  final int maxReconnectionAttempts;

  /// Reconnection delay in milliseconds
  final int reconnectionDelay;

  /// Whether to buffer events during disconnection
  final bool bufferEvents;

  /// Maximum event buffer size
  final int maxBufferSize;

  /// Connection timeout in milliseconds
  final int connectionTimeout;

  const LegacyEventSubscriptionConfig({
    this.autoReconnect = true,
    this.maxReconnectionAttempts = 5,
    this.reconnectionDelay = 1000,
    this.bufferEvents = true,
    this.maxBufferSize = 1000,
    this.connectionTimeout = 30000,
  });

  /// Default configuration
  factory LegacyEventSubscriptionConfig.defaultConfig() {
    return const LegacyEventSubscriptionConfig();
  }

  /// Production configuration with more conservative settings
  factory LegacyEventSubscriptionConfig.production() {
    return const LegacyEventSubscriptionConfig(
      autoReconnect: true,
      maxReconnectionAttempts: 10,
      reconnectionDelay: 2000,
      bufferEvents: true,
      maxBufferSize: 5000,
      connectionTimeout: 60000,
    );
  }

  /// Development configuration with aggressive reconnection
  factory LegacyEventSubscriptionConfig.development() {
    return const LegacyEventSubscriptionConfig(
      autoReconnect: true,
      maxReconnectionAttempts: 3,
      reconnectionDelay: 500,
      bufferEvents: false,
      maxBufferSize: 100,
      connectionTimeout: 10000,
    );
  }
}

/// Event subscription
class EventSubscription {
  /// Unique subscription ID
  final String id;

  /// Event name to filter (null for all events)
  final String? eventName;

  /// Event filter for complex filtering
  final EventFilter? filter;

  /// Event callback
  final void Function(ParsedEvent)? onEvent;

  /// Error callback
  final void Function(EventSubscriptionError)? onError;

  /// Creation timestamp
  final DateTime createdAt;

  const EventSubscription({
    required this.id,
    this.eventName,
    this.filter,
    this.onEvent,
    this.onError,
    required this.createdAt,
  });

  @override
  String toString() => 'EventSubscription(id: $id, eventName: $eventName)';
}

/// Event filter for complex event filtering
class EventFilter {
  /// Event names to include
  final Set<String>? eventNames;

  /// Data filters to apply
  final Map<String, dynamic>? dataFilters;

  /// Custom filter function
  final bool Function(ParsedEvent)? customFilter;

  const EventFilter({
    this.eventNames,
    this.dataFilters,
    this.customFilter,
  });

  /// Check if event matches filter
  bool matches(ParsedEvent event) {
    // Check event name filter
    if (eventNames != null && !eventNames!.contains(event.name)) {
      return false;
    }

    // Check data filters
    if (dataFilters != null) {
      for (final entry in dataFilters!.entries) {
        final key = entry.key;
        final expectedValue = entry.value;
        final actualValue = event.data[key];

        if (actualValue != expectedValue) {
          return false;
        }
      }
    }

    // Check custom filter
    if (customFilter != null) {
      return customFilter!(event);
    }

    return true;
  }
}

/// Connection state enumeration
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  error,
}

/// Event subscription error types
enum EventSubscriptionErrorType {
  connectionError,
  parseError,
  processingError,
  handlerError,
  subscriptionError,
}

/// Event subscription error
class EventSubscriptionError {
  /// Error type
  final EventSubscriptionErrorType type;

  /// Error message
  final String message;

  /// Additional error data
  final Map<String, dynamic>? data;

  /// Error timestamp
  final DateTime timestamp;

  EventSubscriptionError({
    required this.type,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'EventSubscriptionError('
        'type: $type, '
        'message: $message, '
        'timestamp: $timestamp'
        ')';
  }
}

/// Event subscription metrics
class EventSubscriptionMetrics {
  /// Number of connections made
  int connectionCount = 0;

  /// Number of messages received
  int messagesReceived = 0;

  /// Number of events processed
  int eventsProcessed = 0;

  /// Number of notifications delivered
  int notificationsDelivered = 0;

  /// Number of errors encountered
  int errorCount = 0;

  /// Number of active subscriptions
  int subscriptionCount = 0;

  /// Reset all metrics
  void reset() {
    connectionCount = 0;
    messagesReceived = 0;
    eventsProcessed = 0;
    notificationsDelivered = 0;
    errorCount = 0;
    subscriptionCount = 0;
  }

  @override
  String toString() {
    return 'EventSubscriptionMetrics('
        'connections: $connectionCount, '
        'messages: $messagesReceived, '
        'events: $eventsProcessed, '
        'notifications: $notificationsDelivered, '
        'errors: $errorCount, '
        'subscriptions: $subscriptionCount'
        ')';
  }
}
