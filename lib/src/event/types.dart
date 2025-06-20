/// Core types and interfaces for the event system
///
/// This module defines the fundamental types, interfaces, and data structures
/// used throughout the event system.

import '../types/commitment.dart';
import '../types/public_key.dart';
import '../idl/idl.dart';

/// Callback function type for event listeners
typedef EventCallback<T> = void Function(T event, int slot, String signature);

/// Generic event callback for any event type
typedef GenericEventCallback = void Function(
    dynamic event, int slot, String signature);

/// Callback for raw log events (before parsing)
typedef LogCallback = void Function(LogsNotification notification);

/// Context information for an event emission
class EventContext {
  /// The slot number where the event was emitted
  final int slot;

  /// The transaction signature that emitted the event
  final String signature;

  /// Block time (if available)
  final DateTime? blockTime;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const EventContext({
    required this.slot,
    required this.signature,
    this.blockTime,
    this.metadata,
  });

  @override
  String toString() => 'EventContext(slot: $slot, signature: $signature)';
}

/// Parsed event with context and metadata
class ParsedEvent<T> {
  /// The event name
  final String name;

  /// The decoded event data
  final T data;

  /// Context information about when/where the event was emitted
  final EventContext context;

  /// The IDL event definition
  final IdlEvent eventDef;

  const ParsedEvent({
    required this.name,
    required this.data,
    required this.context,
    required this.eventDef,
  });

  @override
  String toString() => 'ParsedEvent(name: $name, context: $context)';
}

/// Log notification from the WebSocket subscription
class LogsNotification {
  /// Transaction signature
  final String signature;

  /// Transaction log messages
  final List<String> logs;

  /// Error message if transaction failed
  final String? err;

  /// Slot number
  final int slot;

  /// Block time (if available)
  final DateTime? blockTime;

  const LogsNotification({
    required this.signature,
    required this.logs,
    this.err,
    required this.slot,
    this.blockTime,
  });

  /// Whether the transaction succeeded
  bool get isSuccess => err == null;

  @override
  String toString() =>
      'LogsNotification(signature: $signature, slot: $slot, success: $isSuccess)';
}

/// Configuration for event subscriptions
class EventSubscriptionConfig {
  /// Commitment level for the subscription
  final CommitmentConfig commitment;

  /// Whether to include failed transactions
  final bool includeFailed;

  /// Maximum number of events to buffer
  final int? maxBufferSize;

  /// Timeout for reconnection attempts
  final Duration reconnectTimeout;

  /// Maximum number of reconnection attempts
  final int maxReconnectAttempts;

  const EventSubscriptionConfig({
    this.commitment = CommitmentConfigs.confirmed,
    this.includeFailed = false,
    this.maxBufferSize,
    this.reconnectTimeout = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  });
}

/// Filter criteria for events
class EventFilter {
  /// Event names to listen for (null = all events)
  final Set<String>? eventNames;

  /// Program IDs to filter by (null = any program)
  final Set<PublicKey>? programIds;

  /// Minimum slot number (null = no minimum)
  final int? minSlot;

  /// Maximum slot number (null = no maximum)
  final int? maxSlot;

  /// Whether to include failed transactions
  final bool includeFailed;

  const EventFilter({
    this.eventNames,
    this.programIds,
    this.minSlot,
    this.maxSlot,
    this.includeFailed = false,
  });

  /// Create a filter for specific event names
  factory EventFilter.byEventNames(Set<String> eventNames) {
    return EventFilter(eventNames: eventNames);
  }

  /// Create a filter for specific program IDs
  factory EventFilter.byProgramIds(Set<PublicKey> programIds) {
    return EventFilter(programIds: programIds);
  }

  /// Create a filter for a slot range
  factory EventFilter.bySlotRange(int minSlot, int? maxSlot) {
    return EventFilter(minSlot: minSlot, maxSlot: maxSlot);
  }

  /// Check if an event matches this filter
  bool matches(ParsedEvent event, PublicKey programId) {
    // Check event name filter
    if (eventNames != null && !eventNames!.contains(event.name)) {
      return false;
    }

    // Check program ID filter
    if (programIds != null && !programIds!.contains(programId)) {
      return false;
    }

    // Check slot range filter
    if (minSlot != null && event.context.slot < minSlot!) {
      return false;
    }

    if (maxSlot != null && event.context.slot > maxSlot!) {
      return false;
    }

    return true;
  }
}

/// Statistics about event processing
class EventStats {
  /// Total number of events processed
  final int totalEvents;

  /// Number of successfully parsed events
  final int parsedEvents;

  /// Number of failed parse attempts
  final int parseErrors;

  /// Number of filtered out events
  final int filteredEvents;

  /// Last processing timestamp
  final DateTime lastProcessed;

  /// Events per second (recent average)
  final double eventsPerSecond;

  const EventStats({
    required this.totalEvents,
    required this.parsedEvents,
    required this.parseErrors,
    required this.filteredEvents,
    required this.lastProcessed,
    required this.eventsPerSecond,
  });

  @override
  String toString() =>
      'EventStats(total: $totalEvents, parsed: $parsedEvents, errors: $parseErrors)';
}

/// Event replay configuration
class EventReplayConfig {
  /// Starting slot for replay
  final int fromSlot;

  /// Ending slot for replay (null = up to latest)
  final int? toSlot;

  /// Maximum number of events to replay
  final int? maxEvents;

  /// Event filter for replay
  final EventFilter? filter;

  /// Whether to include failed transactions
  final bool includeFailed;

  const EventReplayConfig({
    required this.fromSlot,
    this.toSlot,
    this.maxEvents,
    this.filter,
    this.includeFailed = false,
  });
}

/// WebSocket connection state
enum WebSocketState {
  /// Not connected
  disconnected,

  /// Attempting to connect
  connecting,

  /// Connected and ready
  connected,

  /// Temporarily disconnected, attempting to reconnect
  reconnecting,

  /// Permanently closed
  closed,
}

/// Exception thrown by event system operations
class EventException implements Exception {
  final String message;
  final dynamic cause;

  const EventException(this.message, [this.cause]);

  @override
  String toString() =>
      'EventException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Exception thrown during event parsing
class EventParseException extends EventException {
  const EventParseException(String message, [dynamic cause])
      : super(message, cause);
}

/// Exception thrown during subscription operations
class EventSubscriptionException extends EventException {
  const EventSubscriptionException(String message, [dynamic cause])
      : super(message, cause);
}
