/// Event aggregation and processing pipeline system
///
/// This module provides advanced event aggregation capabilities,
/// processing pipelines, and event-driven programming patterns.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

/// Event aggregation service
class EventAggregationService {
  final EventAggregationConfig config;
  final Map<String, EventAggregator> _aggregators = {};
  final Map<String, StreamController<AggregatedEvent>> _aggregationStreams = {};
  final Queue<ProcessedEvent> _eventBuffer = Queue();

  Timer? _processingTimer;
  Timer? _flushTimer;

  EventAggregationService({this.config = const EventAggregationConfig()}) {
    _startProcessing();
  }

  /// Register an aggregator for specific event types
  void registerAggregator(String eventPattern, EventAggregator aggregator) {
    _aggregators[eventPattern] = aggregator;
    _aggregationStreams[eventPattern] = StreamController.broadcast();
  }

  /// Get aggregated events stream for a pattern
  Stream<AggregatedEvent> getAggregatedEvents(String eventPattern) {
    final controller = _aggregationStreams[eventPattern];
    if (controller == null) {
      throw ArgumentError(
          'No aggregator registered for pattern: $eventPattern');
    }
    return controller.stream;
  }

  /// Process an incoming event
  void processEvent(String eventName, dynamic eventData, DateTime timestamp) {
    final processedEvent = ProcessedEvent(
      eventName: eventName,
      data: eventData,
      timestamp: timestamp,
    );

    _eventBuffer.addLast(processedEvent);

    // If buffer is full, force processing
    if (_eventBuffer.length >= config.maxBufferSize) {
      _processBufferedEvents();
    }
  }

  /// Create a time-based aggregation window
  StreamTransformer<ProcessedEvent, List<ProcessedEvent>> timeWindow(
      Duration window) {
    return StreamTransformer.fromHandlers(
      handleData: (event, sink) {
        // Implementation of time-based windowing
        // This would collect events over the specified time window
      },
    );
  }

  /// Create a count-based aggregation window
  StreamTransformer<ProcessedEvent, List<ProcessedEvent>> countWindow(
      int count) {
    var buffer = <ProcessedEvent>[];

    return StreamTransformer.fromHandlers(
      handleData: (event, sink) {
        buffer.add(event);
        if (buffer.length >= count) {
          sink.add(List.from(buffer));
          buffer.clear();
        }
      },
    );
  }

  /// Process buffered events
  void _processBufferedEvents() {
    final eventsToProcess = List<ProcessedEvent>.from(_eventBuffer);
    _eventBuffer.clear();

    for (final aggregatorEntry in _aggregators.entries) {
      final pattern = aggregatorEntry.key;
      final aggregator = aggregatorEntry.value;
      final controller = _aggregationStreams[pattern];

      if (controller == null) continue;

      // Filter events matching the pattern
      final matchingEvents = eventsToProcess
          .where((event) => _matchesPattern(event.eventName, pattern))
          .toList();

      if (matchingEvents.isNotEmpty) {
        final aggregatedEvent = aggregator.aggregate(matchingEvents);
        if (aggregatedEvent != null) {
          controller.add(aggregatedEvent);
        }
      }
    }
  }

  /// Check if event name matches pattern
  bool _matchesPattern(String eventName, String pattern) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      return eventName.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return eventName == pattern;
  }

  /// Start processing timers
  void _startProcessing() {
    _processingTimer = Timer.periodic(config.processingInterval, (_) {
      _processBufferedEvents();
    });

    _flushTimer = Timer.periodic(config.flushInterval, (_) {
      _forceFlushAggregators();
    });
  }

  /// Force flush all aggregators
  void _forceFlushAggregators() {
    for (final aggregatorEntry in _aggregators.entries) {
      final pattern = aggregatorEntry.key;
      final aggregator = aggregatorEntry.value;
      final controller = _aggregationStreams[pattern];

      if (controller == null) continue;

      final flushedEvent = aggregator.flush();
      if (flushedEvent != null) {
        controller.add(flushedEvent);
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _processingTimer?.cancel();
    _flushTimer?.cancel();

    for (final controller in _aggregationStreams.values) {
      await controller.close();
    }
    _aggregationStreams.clear();
    _aggregators.clear();
  }
}

/// Event processing pipeline
class EventProcessingPipeline {
  final List<EventPipelineProcessor> _processors = [];
  final StreamController<ProcessedEvent> _inputController = StreamController();
  final StreamController<ProcessedEvent> _outputController =
      StreamController.broadcast();
  late final StreamSubscription _subscription;

  EventProcessingPipeline() {
    _subscription = _inputController.stream.listen(_processEvent);
  }

  /// Add a processor to the pipeline
  void addProcessor(EventPipelineProcessor processor) {
    _processors.add(processor);
  }

  /// Remove a processor from the pipeline
  void removeProcessor(EventPipelineProcessor processor) {
    _processors.remove(processor);
  }

  /// Input stream for events
  Sink<ProcessedEvent> get input => _inputController.sink;

  /// Output stream for processed events
  Stream<ProcessedEvent> get output => _outputController.stream;

  /// Process an event through the pipeline
  Future<void> _processEvent(ProcessedEvent event) async {
    var currentEvent = event;

    for (final processor in _processors) {
      try {
        final result = await processor.process(currentEvent);
        if (result == null) {
          // Event was filtered out
          return;
        }
        currentEvent = result;
      } catch (e) {
        // Handle processor error
        currentEvent = ProcessedEvent(
          eventName: currentEvent.eventName,
          data: {
            'error': e.toString(),
            'originalData': currentEvent.data,
          },
          timestamp: currentEvent.timestamp,
          metadata: {
            ...currentEvent.metadata,
            'processingError': true,
            'failedProcessor': processor.runtimeType.toString(),
          },
        );
      }
    }

    _outputController.add(currentEvent);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _subscription.cancel();
    await _inputController.close();
    await _outputController.close();
  }
}

/// Base class for event aggregators
abstract class EventAggregator {
  /// Aggregate a list of events into a single aggregated event
  AggregatedEvent? aggregate(List<ProcessedEvent> events);

  /// Flush any pending aggregations
  AggregatedEvent? flush() => null;
}

/// Count-based event aggregator
class CountAggregator extends EventAggregator {
  final Map<String, int> _counts = {};

  @override
  AggregatedEvent? aggregate(List<ProcessedEvent> events) {
    for (final event in events) {
      _counts[event.eventName] = (_counts[event.eventName] ?? 0) + 1;
    }

    if (_counts.isNotEmpty) {
      final result = AggregatedEvent(
        type: AggregationType.count,
        data: Map.from(_counts),
        eventCount: events.length,
        timeWindow: _calculateTimeWindow(events),
        timestamp: DateTime.now(),
      );
      _counts.clear();
      return result;
    }

    return null;
  }

  Duration _calculateTimeWindow(List<ProcessedEvent> events) {
    if (events.isEmpty) return Duration.zero;

    final timestamps = events.map((e) => e.timestamp).toList()..sort();
    return timestamps.last.difference(timestamps.first);
  }
}

/// Sum-based event aggregator
class SumAggregator extends EventAggregator {
  final String fieldName;
  double _sum = 0.0;

  SumAggregator({required this.fieldName});

  @override
  AggregatedEvent? aggregate(List<ProcessedEvent> events) {
    for (final event in events) {
      final value = _extractNumericValue(event.data, fieldName);
      if (value != null) {
        _sum += value;
      }
    }

    if (_sum != 0.0) {
      final result = AggregatedEvent(
        type: AggregationType.sum,
        data: {fieldName: _sum},
        eventCount: events.length,
        timeWindow: _calculateTimeWindow(events),
        timestamp: DateTime.now(),
      );
      _sum = 0.0;
      return result;
    }

    return null;
  }

  double? _extractNumericValue(dynamic data, String fieldName) {
    if (data is Map<String, dynamic>) {
      final value = data[fieldName];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  Duration _calculateTimeWindow(List<ProcessedEvent> events) {
    if (events.isEmpty) return Duration.zero;

    final timestamps = events.map((e) => e.timestamp).toList()..sort();
    return timestamps.last.difference(timestamps.first);
  }
}

/// Average-based event aggregator
class AverageAggregator extends EventAggregator {
  final String fieldName;
  final List<double> _values = [];

  AverageAggregator({required this.fieldName});

  @override
  AggregatedEvent? aggregate(List<ProcessedEvent> events) {
    for (final event in events) {
      final value = _extractNumericValue(event.data, fieldName);
      if (value != null) {
        _values.add(value);
      }
    }

    if (_values.isNotEmpty) {
      final average = _values.reduce((a, b) => a + b) / _values.length;
      final result = AggregatedEvent(
        type: AggregationType.average,
        data: {
          '${fieldName}_average': average,
          '${fieldName}_count': _values.length,
          '${fieldName}_min': _values.reduce(math.min),
          '${fieldName}_max': _values.reduce(math.max),
        },
        eventCount: events.length,
        timeWindow: _calculateTimeWindow(events),
        timestamp: DateTime.now(),
      );
      _values.clear();
      return result;
    }

    return null;
  }

  double? _extractNumericValue(dynamic data, String fieldName) {
    if (data is Map<String, dynamic>) {
      final value = data[fieldName];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  Duration _calculateTimeWindow(List<ProcessedEvent> events) {
    if (events.isEmpty) return Duration.zero;

    final timestamps = events.map((e) => e.timestamp).toList()..sort();
    return timestamps.last.difference(timestamps.first);
  }
}

/// Base class for event pipeline processors
abstract class EventPipelineProcessor {
  /// Process an event and return the modified event or null to filter it out
  Future<ProcessedEvent?> process(ProcessedEvent event);
}

/// Filter processor that removes events based on criteria
class FilterProcessor extends EventPipelineProcessor {
  final bool Function(ProcessedEvent) predicate;

  FilterProcessor(this.predicate);

  @override
  Future<ProcessedEvent?> process(ProcessedEvent event) async {
    return predicate(event) ? event : null;
  }
}

/// Transform processor that modifies event data
class TransformProcessor extends EventPipelineProcessor {
  final ProcessedEvent Function(ProcessedEvent) transformer;

  TransformProcessor(this.transformer);

  @override
  Future<ProcessedEvent?> process(ProcessedEvent event) async {
    return transformer(event);
  }
}

/// Enrichment processor that adds metadata to events
class EnrichmentProcessor extends EventPipelineProcessor {
  final Map<String, dynamic> Function(ProcessedEvent) enricher;

  EnrichmentProcessor(this.enricher);

  @override
  Future<ProcessedEvent?> process(ProcessedEvent event) async {
    final enrichment = enricher(event);
    return ProcessedEvent(
      eventName: event.eventName,
      data: event.data,
      timestamp: event.timestamp,
      metadata: {...event.metadata, ...enrichment},
    );
  }
}

/// Processed event with metadata
class ProcessedEvent {
  final String eventName;
  final dynamic data;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ProcessedEvent({
    required this.eventName,
    required this.data,
    required this.timestamp,
    this.metadata = const {},
  });

  ProcessedEvent copyWith({
    String? eventName,
    dynamic data,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ProcessedEvent(
      eventName: eventName ?? this.eventName,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Aggregated event result
class AggregatedEvent {
  final AggregationType type;
  final Map<String, dynamic> data;
  final int eventCount;
  final Duration timeWindow;
  final DateTime timestamp;

  const AggregatedEvent({
    required this.type,
    required this.data,
    required this.eventCount,
    required this.timeWindow,
    required this.timestamp,
  });
}

/// Event aggregation configuration
class EventAggregationConfig {
  final Duration processingInterval;
  final Duration flushInterval;
  final int maxBufferSize;
  final bool enableTimeWindows;
  final bool enableCountWindows;

  const EventAggregationConfig({
    this.processingInterval = const Duration(seconds: 1),
    this.flushInterval = const Duration(seconds: 10),
    this.maxBufferSize = 1000,
    this.enableTimeWindows = true,
    this.enableCountWindows = true,
  });

  factory EventAggregationConfig.realTime() => const EventAggregationConfig(
        processingInterval: Duration(milliseconds: 100),
        flushInterval: Duration(seconds: 1),
        maxBufferSize: 100,
      );

  factory EventAggregationConfig.batch() => const EventAggregationConfig(
        processingInterval: Duration(seconds: 10),
        flushInterval: Duration(minutes: 1),
        maxBufferSize: 10000,
      );
}

/// Aggregation types
enum AggregationType { count, sum, average, min, max, custom }
