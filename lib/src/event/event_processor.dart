import 'dart:async';
import 'dart:collection';

import 'package:coral_xyz_anchor/src/event/event_definition.dart';
import 'package:coral_xyz_anchor/src/event/event_log_parser.dart';

/// Event processing framework for handling events with middleware and pipelines
/// Matches TypeScript's event processing capabilities with handler management
class EventProcessor {

  EventProcessor({
    required List<EventDefinition> eventDefinitions,
    EventProcessingConfig? config,
  }) : _config = config ?? EventProcessingConfig.defaultConfig();
  /// Event handlers mapped by event name
  final Map<String, List<EventHandler>> _handlers = {};

  /// Global middleware pipeline
  final List<EventMiddleware> _middleware = [];

  /// Event queue for batching
  final Queue<ProcessingEvent> _eventQueue = Queue();

  /// Processing configuration
  final EventProcessingConfig _config;

  /// Performance metrics
  final EventProcessingMetrics _metrics = EventProcessingMetrics();

  /// Stream controller for processed events
  final StreamController<ProcessedEventResult> _resultController =
      StreamController.broadcast();

  /// Timer for batch processing
  Timer? _batchTimer;

  /// Whether the processor is currently running
  bool _isRunning = false;

  /// Get processing metrics
  EventProcessingMetrics get metrics => _metrics;

  /// Get processed events stream
  Stream<ProcessedEventResult> get processedEvents => _resultController.stream;

  /// Register an event handler
  void registerHandler(String eventName, EventHandler handler) {
    _handlers.putIfAbsent(eventName, () => []).add(handler);
    _metrics.handlersRegistered++;
  }

  /// Remove an event handler
  void removeHandler(String eventName, EventHandler handler) {
    final handlers = _handlers[eventName];
    if (handlers != null) {
      handlers.remove(handler);
      if (handlers.isEmpty) {
        _handlers.remove(eventName);
      }
      _metrics.handlersRegistered--;
    }
  }

  /// Remove all handlers for an event
  void removeAllHandlers(String eventName) {
    final handlers = _handlers.remove(eventName);
    if (handlers != null) {
      _metrics.handlersRegistered -= handlers.length;
    }
  }

  /// Register multiple handlers
  void registerHandlers(Map<String, List<EventHandler>> handlers) {
    for (final entry in handlers.entries) {
      for (final handler in entry.value) {
        registerHandler(entry.key, handler);
      }
    }
  }

  /// Register a global middleware
  void registerMiddleware(EventMiddleware middleware) {
    _middleware.add(middleware);
    _metrics.middlewareRegistered++;
  }

  /// Remove middleware from processing pipeline
  bool removeMiddleware(EventMiddleware middleware) {
    final removed = _middleware.remove(middleware);
    if (removed) {
      _metrics.middlewareRegistered--;
    }
    return removed;
  }

  /// Process a single event
  Future<ProcessedEventResult> processEvent(ParsedEvent event) async {
    final processingEvent = ProcessingEvent(
      event: event,
      receivedAt: DateTime.now(),
      context: EventProcessingContext(),
    );

    if (_config.enableBatching) {
      _enqueueEvent(processingEvent);
      return ProcessedEventResult.queued(processingEvent);
    } else {
      return _processEventInternal(processingEvent);
    }
  }

  /// Start the event processor
  void start() {
    if (_isRunning) return;

    _isRunning = true;

    if (_config.enableBatching) {
      _startBatchTimer();
    }

    _metrics.processorStarted++;
  }

  /// Stop the event processor
  void stop() {
    if (!_isRunning) return;

    _isRunning = false;
    _batchTimer?.cancel();
    _batchTimer = null;

    // Process remaining events in queue
    if (_eventQueue.isNotEmpty) {
      _processBatchFromQueue();
    }

    _metrics.processorStopped++;
  }

  /// Enqueue event for batch processing
  void _enqueueEvent(ProcessingEvent event) {
    _eventQueue.add(event);
    _metrics.eventsQueued++;

    if (_eventQueue.length >= _config.maxBatchSize) {
      _processBatchFromQueue();
    }
  }

  /// Start batch processing timer
  void _startBatchTimer() {
    _batchTimer = Timer.periodic(
      Duration(milliseconds: _config.batchTimeout),
      (_) => _processBatchFromQueue(),
    );
  }

  /// Process batch from queue
  Future<void> _processBatchFromQueue() async {
    if (_eventQueue.isEmpty) return;

    final batch = <ProcessingEvent>[];
    while (_eventQueue.isNotEmpty && batch.length < _config.maxBatchSize) {
      batch.add(_eventQueue.removeFirst());
    }

    await _processBatch(batch);
  }

  /// Process a batch of events
  Future<List<ProcessedEventResult>> _processBatch(
      List<ProcessingEvent> events,) async {
    _metrics.batchesProcessed++;

    final results = <ProcessedEventResult>[];

    for (final event in events) {
      final result = await _processEventInternal(event);
      results.add(result);
    }

    return results;
  }

  /// Process a single event internally
  Future<ProcessedEventResult> _processEventInternal(
      ProcessingEvent processingEvent,) async {
    final event = processingEvent.event;
    final context = processingEvent.context;

    _metrics.eventsProcessed++;
    final startTime = DateTime.now();

    try {
      // Apply middleware pipeline
      var processedEvent = event;
      for (final middleware in _middleware) {
        processedEvent = await middleware.process(processedEvent, context);
        if (context.shouldStop) {
          return ProcessedEventResult.stopped(processingEvent);
        }
      }

      // Find and execute handlers
      final handlers = _handlers[event.name] ?? [];
      final handlerResults = <EventHandlerResult>[];

      for (final handler in handlers) {
        try {
          final result = await handler.handle(processedEvent, context);
          handlerResults.add(result);
          _metrics.handlersExecuted++;

          if (result.shouldStopPropagation) {
            break;
          }
        } catch (e) {
          _metrics.handlerErrors++;

          final errorResult = EventHandlerResult.error(
            'Handler execution failed: $e',
            originalError: e,
          );
          handlerResults.add(errorResult);

          if (!_config.continueOnHandlerError) {
            break;
          }
        }
      }

      final duration = DateTime.now().difference(startTime);

      final result = ProcessedEventResult.success(
        processingEvent,
        handlerResults,
        duration,
      );

      _resultController.add(result);
      return result;
    } catch (e) {
      _metrics.processingErrors++;

      final result = ProcessedEventResult.error(
        processingEvent,
        ProcessingError(
          type: ProcessingErrorType.processingError,
          message: 'Event processing failed: $e',
          originalError: e,
        ),
      );

      _resultController.add(result);
      return result;
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
    _resultController.close();
  }
}

/// Configuration for event processing
class EventProcessingConfig {

  const EventProcessingConfig({
    this.enableBatching = false,
    this.maxBatchSize = 100,
    this.batchTimeout = 1000,
    this.continueOnHandlerError = true,
    this.continueOnMiddlewareError = true,
    this.maxConcurrency = 1,
    this.enableMetrics = true,
  });

  /// Default configuration
  factory EventProcessingConfig.defaultConfig() {
    return const EventProcessingConfig();
  }

  /// High-performance configuration
  factory EventProcessingConfig.highPerformance() {
    return const EventProcessingConfig(
      enableBatching: true,
      maxBatchSize: 1000,
      batchTimeout: 100,
      maxConcurrency: 4,
    );
  }

  /// Safe configuration with error handling
  factory EventProcessingConfig.safe() {
    return const EventProcessingConfig(
      continueOnHandlerError: false,
      continueOnMiddlewareError: false,
      maxConcurrency: 1,
    );
  }
  /// Whether to enable batch processing
  final bool enableBatching;

  /// Maximum batch size
  final int maxBatchSize;

  /// Batch timeout in milliseconds
  final int batchTimeout;

  /// Whether to continue processing on handler errors
  final bool continueOnHandlerError;

  /// Whether to continue processing on middleware errors
  final bool continueOnMiddlewareError;

  /// Maximum concurrent processing
  final int maxConcurrency;

  /// Whether to enable performance metrics
  final bool enableMetrics;
}

/// Abstract base class for event handlers
abstract class EventHandler {
  /// Handle an event
  Future<EventHandlerResult> handle(
      ParsedEvent event, EventProcessingContext context,);
}

/// Abstract base class for batch event handlers
abstract class BatchEventHandler implements EventHandler {
  /// Handle a batch of events
  Future<List<EventHandlerResult>> handleBatch(
      List<ParsedEvent> events, EventProcessingContext context,);
}

/// Abstract base class for event middleware
abstract class EventMiddleware {
  /// Process an event through middleware
  Future<ParsedEvent> process(
      ParsedEvent event, EventProcessingContext context,);
}

/// Event processing context
class EventProcessingContext {

  EventProcessingContext({
    String? processingId,
  }) : processingId = processingId ?? _generateId() {
    startTime = DateTime.now();
  }
  /// Additional metadata
  final Map<String, dynamic> metadata = {};

  /// Whether processing should stop
  bool shouldStop = false;

  /// Processing start time
  late final DateTime startTime;

  /// Processing ID for tracking
  final String processingId;

  /// Add metadata
  void addMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  /// Get metadata
  T? getMetadata<T>(String key) => metadata[key] as T?;

  /// Signal to stop processing
  void stop() {
    shouldStop = true;
  }

  static String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}

/// Result of processing an event
class ProcessedEventResult {

  const ProcessedEventResult({
    required this.processingEvent,
    this.handlerResults = const [],
    this.duration,
    this.error,
    required this.status,
  });

  /// Create successful result
  factory ProcessedEventResult.success(
    ProcessingEvent processingEvent,
    List<EventHandlerResult> handlerResults,
    Duration duration,
  ) {
    return ProcessedEventResult(
      processingEvent: processingEvent,
      handlerResults: handlerResults,
      duration: duration,
      status: ProcessingStatus.success,
    );
  }

  /// Create error result
  factory ProcessedEventResult.error(
    ProcessingEvent processingEvent,
    ProcessingError error,
  ) {
    return ProcessedEventResult(
      processingEvent: processingEvent,
      error: error,
      status: ProcessingStatus.error,
    );
  }

  /// Create queued result
  factory ProcessedEventResult.queued(ProcessingEvent processingEvent) {
    return ProcessedEventResult(
      processingEvent: processingEvent,
      status: ProcessingStatus.queued,
    );
  }

  /// Create stopped result
  factory ProcessedEventResult.stopped(ProcessingEvent processingEvent) {
    return ProcessedEventResult(
      processingEvent: processingEvent,
      status: ProcessingStatus.stopped,
    );
  }
  /// The original processing event
  final ProcessingEvent processingEvent;

  /// Handler results
  final List<EventHandlerResult> handlerResults;

  /// Processing duration
  final Duration? duration;

  /// Processing error (if any)
  final ProcessingError? error;

  /// Result status
  final ProcessingStatus status;

  /// Whether the processing was successful
  bool get isSuccess => status == ProcessingStatus.success;

  /// Whether there was an error
  bool get hasError => error != null;
}

/// Event handler result
class EventHandlerResult {

  const EventHandlerResult({
    required this.isSuccess,
    this.data = const {},
    this.error,
    this.originalError,
    this.shouldStopPropagation = false,
    this.duration,
  });

  /// Create successful result
  factory EventHandlerResult.success({
    Map<String, dynamic>? data,
    bool shouldStopPropagation = false,
    Duration? duration,
  }) {
    return EventHandlerResult(
      isSuccess: true,
      data: data ?? {},
      shouldStopPropagation: shouldStopPropagation,
      duration: duration,
    );
  }

  /// Create error result
  factory EventHandlerResult.error(
    String message, {
    dynamic originalError,
    bool shouldStopPropagation = false,
    Duration? duration,
  }) {
    return EventHandlerResult(
      isSuccess: false,
      error: message,
      originalError: originalError,
      shouldStopPropagation: shouldStopPropagation,
      duration: duration,
    );
  }
  /// Whether the handler was successful
  final bool isSuccess;

  /// Handler output data
  final Map<String, dynamic> data;

  /// Error message (if any)
  final String? error;

  /// Original error object
  final dynamic originalError;

  /// Whether to stop propagation to other handlers
  final bool shouldStopPropagation;

  /// Processing duration
  final Duration? duration;
}

/// Processing event wrapper
class ProcessingEvent {

  const ProcessingEvent({
    required this.event,
    required this.receivedAt,
    required this.context,
    this.priority = EventPriority.normal,
  });
  /// The parsed event
  final ParsedEvent event;

  /// When the event was received
  final DateTime receivedAt;

  /// Processing context
  final EventProcessingContext context;

  /// Event priority
  final EventPriority priority;

  /// Processing age
  Duration get age => DateTime.now().difference(receivedAt);
}

/// Processing error details
class ProcessingError {

  ProcessingError({
    required this.type,
    required this.message,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  /// Error type
  final ProcessingErrorType type;

  /// Error message
  final String message;

  /// Original error object
  final dynamic originalError;

  /// Error timestamp
  final DateTime timestamp;
}

/// Event processing metrics
class EventProcessingMetrics {
  /// Number of events processed
  int eventsProcessed = 0;

  /// Number of events queued
  int eventsQueued = 0;

  /// Number of middleware registered
  int middlewareRegistered = 0;

  /// Number of times processor was started
  int processorStarted = 0;

  /// Number of times processor was stopped
  int processorStopped = 0;

  /// Number of handlers registered
  int handlersRegistered = 0;

  /// Number of handlers executed
  int handlersExecuted = 0;

  /// Number of handler errors
  int handlerErrors = 0;

  /// Number of processing errors
  int processingErrors = 0;

  /// Number of batches processed
  int batchesProcessed = 0;

  /// Number of batch errors
  int batchErrors = 0;

  /// Reset all metrics
  void reset() {
    eventsProcessed = 0;
    eventsQueued = 0;
    middlewareRegistered = 0;
    processorStarted = 0;
    processorStopped = 0;
    handlersRegistered = 0;
    handlersExecuted = 0;
    handlerErrors = 0;
    processingErrors = 0;
    batchesProcessed = 0;
    batchErrors = 0;
  }

  @override
  String toString() => 'EventProcessingMetrics('
        'events: $eventsProcessed, '
        'handlers: $handlersExecuted/$handlersRegistered, '
        'errors: $handlerErrors/$processingErrors, '
        'batches: $batchesProcessed'
        ')';
}

/// Processing status enumeration
enum ProcessingStatus {
  success,
  error,
  queued,
  stopped,
  timeout,
}

/// Processing error type enumeration
enum ProcessingErrorType {
  processingError,
  handlerError,
  middlewareError,
  validationError,
  timeoutError,
}

/// Event priority enumeration
enum EventPriority {
  low,
  normal,
  high,
  critical,
}
