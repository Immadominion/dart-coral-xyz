/// Core types for the event system
library;

/// Callback function type for event listeners
typedef EventCallback<T> = void Function(T event, int slot, String signature);

/// Statistics about event processing
class EventStats {
  const EventStats({
    required this.totalEvents,
    required this.parsedEvents,
    required this.parseErrors,
    required this.filteredEvents,
    required this.lastProcessed,
    required this.eventsPerSecond,
  });

  final int totalEvents;
  final int parsedEvents;
  final int parseErrors;
  final int filteredEvents;
  final DateTime lastProcessed;
  final double eventsPerSecond;

  @override
  String toString() =>
      'EventStats(total: $totalEvents, parsed: $parsedEvents, errors: $parseErrors)';
}

/// WebSocket connection state
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  closed,
}

/// Exception thrown by event system operations
class EventException implements Exception {
  const EventException(this.message, [this.cause]);
  final String message;
  final dynamic cause;

  @override
  String toString() =>
      'EventException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Exception thrown during event parsing
class EventParseException extends EventException {
  const EventParseException(super.message, [super.cause]);
}
