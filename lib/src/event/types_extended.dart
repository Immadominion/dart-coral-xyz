/// Extended event types to support the Program class event system
///
/// This file provides additional types needed for the event system integration
/// in the Program class.
library;

/// Event statistics data
class EventStats {

  const EventStats({
    required this.totalEvents,
    required this.parseErrors,
    required this.lastEventSlot,
    this.lastEventTime,
  });
  /// Total number of events received
  final int totalEvents;

  /// Number of events that had parsing errors
  final int parseErrors;

  /// Slot of the last event received
  final int lastEventSlot;

  /// Time of the last event received
  final DateTime? lastEventTime;
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

  const EventPersistenceConfig({
    this.storageDirectory,
    this.enableCompression = true,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB default
  });
  /// Directory to store events
  final String? storageDirectory;

  /// Whether to compress stored events
  final bool enableCompression;

  /// Maximum file size in bytes before rotation
  final int maxFileSize;
}

/// Configuration for event monitoring
class EventMonitorConfig {

  const EventMonitorConfig({
    this.logLevel = 'info',
    this.captureHistory = true,
  });
  /// Log level for event monitoring
  final String logLevel;

  /// Whether to capture event history
  final bool captureHistory;
}

/// Configuration for event aggregation
class EventAggregationConfig {

  const EventAggregationConfig({
    this.maxEvents = 1000,
    this.enablePruning = true,
  });
  /// Maximum number of events to aggregate
  final int maxEvents;

  /// Whether to enable automatic pruning
  final bool enablePruning;
}

/// Statistics from event persistence
class EventPersistenceStats {

  const EventPersistenceStats({
    required this.eventsStored,
    required this.eventsRetrieved,
    required this.storageSizeBytes,
  });
  /// Number of events stored
  final int eventsStored;

  /// Number of events retrieved
  final int eventsRetrieved;

  /// Total storage size in bytes
  final int storageSizeBytes;
}

/// Statistics from event monitoring
class EventMonitoringStats {

  const EventMonitoringStats({
    required this.eventsMonitored,
    required this.alertsTriggered,
    this.mostCommonEvent,
  });
  /// Number of events monitored
  final int eventsMonitored;

  /// Number of alerts triggered
  final int alertsTriggered;

  /// Most common event type
  final String? mostCommonEvent;
}

/// Aggregated event data
class AggregatedEvent {

  const AggregatedEvent({
    required this.name,
    required this.count,
    required this.data,
  });
  /// Event name
  final String name;

  /// Count of occurrences
  final int count;

  /// Aggregated data
  final Map<String, dynamic> data;
}

/// Event processing pipeline
class EventProcessingPipeline {

  const EventProcessingPipeline({
    required this.id,
    required this.processors,
    required this.isActive,
  });
  /// Pipeline ID
  final String id;

  /// List of processor IDs
  final List<String> processors;

  /// Whether the pipeline is active
  final bool isActive;
}
