/// Extended event types to support the Program class event system
///
/// This file provides additional types needed for the event system integration
/// in the Program class.

/// Event statistics data
class EventStats {
  /// Total number of events received
  final int totalEvents;

  /// Number of events that had parsing errors
  final int parseErrors;

  /// Slot of the last event received
  final int lastEventSlot;

  /// Time of the last event received
  final DateTime? lastEventTime;

  const EventStats({
    required this.totalEvents,
    required this.parseErrors,
    required this.lastEventSlot,
    this.lastEventTime,
  });
}

/// WebSocket connection state
enum WebSocketState {
  /// Connection is connected and operational
  connected,

  /// Connection is disconnected
  disconnected,

  /// Connection is in the process of connecting
  connecting,

  /// Connection has an error
  error,
}

/// Configuration for event persistence
class EventPersistenceConfig {
  /// Directory to store events
  final String? storageDirectory;

  /// Whether to compress stored events
  final bool enableCompression;

  /// Maximum file size in bytes before rotation
  final int maxFileSize;

  const EventPersistenceConfig({
    this.storageDirectory,
    this.enableCompression = true,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB default
  });
}

/// Configuration for event monitoring
class EventMonitorConfig {
  /// Log level for event monitoring
  final String logLevel;

  /// Whether to capture event history
  final bool captureHistory;

  const EventMonitorConfig({
    this.logLevel = 'info',
    this.captureHistory = true,
  });
}

/// Configuration for event aggregation
class EventAggregationConfig {
  /// Maximum number of events to aggregate
  final int maxEvents;

  /// Whether to enable automatic pruning
  final bool enablePruning;

  const EventAggregationConfig({
    this.maxEvents = 1000,
    this.enablePruning = true,
  });
}

/// Statistics from event persistence
class EventPersistenceStats {
  /// Number of events stored
  final int eventsStored;

  /// Number of events retrieved
  final int eventsRetrieved;

  /// Total storage size in bytes
  final int storageSizeBytes;

  const EventPersistenceStats({
    required this.eventsStored,
    required this.eventsRetrieved,
    required this.storageSizeBytes,
  });
}

/// Statistics from event monitoring
class EventMonitoringStats {
  /// Number of events monitored
  final int eventsMonitored;

  /// Number of alerts triggered
  final int alertsTriggered;

  /// Most common event type
  final String? mostCommonEvent;

  const EventMonitoringStats({
    required this.eventsMonitored,
    required this.alertsTriggered,
    this.mostCommonEvent,
  });
}

/// Aggregated event data
class AggregatedEvent {
  /// Event name
  final String name;

  /// Count of occurrences
  final int count;

  /// Aggregated data
  final Map<String, dynamic> data;

  const AggregatedEvent({
    required this.name,
    required this.count,
    required this.data,
  });
}

/// Event processing pipeline
class EventProcessingPipeline {
  /// Pipeline ID
  final String id;

  /// List of processor IDs
  final List<String> processors;

  /// Whether the pipeline is active
  final bool isActive;

  const EventProcessingPipeline({
    required this.id,
    required this.processors,
    required this.isActive,
  });
}
