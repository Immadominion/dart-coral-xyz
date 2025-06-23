/// Event listener implementations and utilities
///
/// This module provides concrete implementations of event listeners
/// and utilities for managing event subscriptions with different
/// patterns and requirements.

import 'dart:async';
import 'types.dart';
import 'event_subscription.dart';

/// Event listener that can be paused and resumed
class PausableEventListener {
  final EventSubscription _subscription;
  bool _isPaused = false;
  final List<ParsedEvent> _bufferedEvents = [];
  final int? _maxBufferSize;

  PausableEventListener(this._subscription, {int? maxBufferSize})
      : _maxBufferSize = maxBufferSize;

  /// Whether the listener is currently paused
  bool get isPaused => _isPaused;

  /// Whether the subscription is still active
  bool get isActive => _subscription.isActive;

  /// Current buffer size
  int get bufferSize => _bufferedEvents.length;

  /// Pause the listener and start buffering events
  void pause() {
    _isPaused = true;
  }

  /// Resume the listener and process any buffered events
  void resume({void Function(ParsedEvent)? eventHandler}) {
    if (!_isPaused) return;

    _isPaused = false;

    if (eventHandler != null) {
      // Process buffered events
      for (final event in _bufferedEvents) {
        eventHandler(event);
      }
    }

    _bufferedEvents.clear();
  }

  /// Cancel the underlying subscription
  Future<void> cancel() => _subscription.cancel();

  /// Get subscription statistics
  EventStats get stats => _subscription.stats;
}

/// Event listener that batches events for processing
class BatchedEventListener {
  final EventSubscription _subscription;
  final Duration _batchInterval;
  final int _maxBatchSize;
  final void Function(List<ParsedEvent>) _batchHandler;

  final List<ParsedEvent> _currentBatch = [];
  Timer? _batchTimer;

  BatchedEventListener({
    required EventSubscription subscription,
    required Duration batchInterval,
    required void Function(List<ParsedEvent>) batchHandler,
    int maxBatchSize = 100,
  })  : _subscription = subscription,
        _batchInterval = batchInterval,
        _maxBatchSize = maxBatchSize,
        _batchHandler = batchHandler {
    _startBatchTimer();
  }

  /// Add an event to the current batch
  void addEvent(ParsedEvent event) {
    _currentBatch.add(event);

    // Process batch immediately if it reaches max size
    if (_currentBatch.length >= _maxBatchSize) {
      _processBatch();
    }
  }

  /// Start the batch timer
  void _startBatchTimer() {
    _batchTimer = Timer.periodic(_batchInterval, (_) {
      if (_currentBatch.isNotEmpty) {
        _processBatch();
      }
    });
  }

  /// Process the current batch
  void _processBatch() {
    if (_currentBatch.isEmpty) return;

    final batch = List<ParsedEvent>.from(_currentBatch);
    _currentBatch.clear();
    _batchHandler(batch);
  }

  /// Cancel the listener and process any remaining events
  Future<void> cancel() async {
    _batchTimer?.cancel();

    // Process any remaining events in the batch
    if (_currentBatch.isNotEmpty) {
      _processBatch();
    }

    await _subscription.cancel();
  }

  /// Whether the subscription is still active
  bool get isActive => _subscription.isActive;

  /// Get subscription statistics
  EventStats get stats => _subscription.stats;
}

/// Event listener that filters events based on custom criteria
class FilteredEventListener {
  final EventSubscription _subscription;
  final bool Function(ParsedEvent) _filter;
  final void Function(ParsedEvent) _eventHandler;

  int _filteredCount = 0;
  int _passedCount = 0;

  FilteredEventListener({
    required EventSubscription subscription,
    required bool Function(ParsedEvent) filter,
    required void Function(ParsedEvent) eventHandler,
  })  : _subscription = subscription,
        _filter = filter,
        _eventHandler = eventHandler;

  /// Process an event through the filter
  void processEvent(ParsedEvent event) {
    if (_filter(event)) {
      _passedCount++;
      _eventHandler(event);
    } else {
      _filteredCount++;
    }
  }

  /// Number of events that passed the filter
  int get passedCount => _passedCount;

  /// Number of events that were filtered out
  int get filteredCount => _filteredCount;

  /// Total number of events processed
  int get totalProcessed => _passedCount + _filteredCount;

  /// Filter efficiency (ratio of passed to total)
  double get filterEfficiency =>
      totalProcessed > 0 ? _passedCount / totalProcessed : 0.0;

  /// Cancel the underlying subscription
  Future<void> cancel() => _subscription.cancel();

  /// Whether the subscription is still active
  bool get isActive => _subscription.isActive;

  /// Get subscription statistics
  EventStats get stats => _subscription.stats;
}

/// Event listener that maintains a history of recent events
class HistoryEventListener {
  final EventSubscription _subscription;
  final int _maxHistorySize;
  final List<ParsedEvent> _history = [];

  HistoryEventListener({
    required EventSubscription subscription,
    int maxHistorySize = 1000,
  })  : _subscription = subscription,
        _maxHistorySize = maxHistorySize;

  /// Add an event to the history
  void addEvent(ParsedEvent event) {
    _history.add(event);

    // Remove oldest events if history is full
    while (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// Get the complete event history
  List<ParsedEvent> get history => List.unmodifiable(_history);

  /// Get events from a specific time range
  List<ParsedEvent> getEventsInRange(DateTime start, DateTime end) {
    return _history
        .where((event) =>
            !event.context.blockTime!.isBefore(start) &&
            !event.context.blockTime!.isAfter(end))
        .toList();
  }

  /// Get the last N events
  List<ParsedEvent> getLastEvents(int count) {
    final startIndex = _history.length - count;
    return startIndex > 0 ? _history.sublist(startIndex) : List.from(_history);
  }

  /// Search events by name
  List<ParsedEvent> findEventsByName(String eventName) {
    return _history.where((event) => event.name == eventName).toList();
  }

  /// Clear the event history
  void clearHistory() {
    _history.clear();
  }

  /// Current history size
  int get historySize => _history.length;

  /// Maximum history size
  int get maxHistorySize => _maxHistorySize;

  /// Cancel the underlying subscription
  Future<void> cancel() => _subscription.cancel();

  /// Whether the subscription is still active
  bool get isActive => _subscription.isActive;

  /// Get subscription statistics
  EventStats get stats => _subscription.stats;
}

/// Event listener builder for creating complex listeners
class EventListenerBuilder {
  EventSubscription? _subscription;
  Duration? _batchInterval;
  int? _maxBatchSize;
  int? _maxHistorySize;
  bool Function(ParsedEvent)? _filter;
  void Function(ParsedEvent)? _eventHandler;
  void Function(List<ParsedEvent>)? _batchHandler;

  /// Set the base subscription
  EventListenerBuilder subscription(EventSubscription subscription) {
    _subscription = subscription;
    return this;
  }

  /// Enable batching with specified interval
  EventListenerBuilder batched(
      Duration interval, void Function(List<ParsedEvent>) handler,
      {int maxBatchSize = 100}) {
    _batchInterval = interval;
    _batchHandler = handler;
    _maxBatchSize = maxBatchSize;
    return this;
  }

  /// Enable event filtering
  EventListenerBuilder filtered(bool Function(ParsedEvent) filter) {
    _filter = filter;
    return this;
  }

  /// Set the event handler
  EventListenerBuilder onEvent(void Function(ParsedEvent) handler) {
    _eventHandler = handler;
    return this;
  }

  /// Enable event history
  EventListenerBuilder withHistory({int maxSize = 1000}) {
    _maxHistorySize = maxSize;
    return this;
  }

  /// Build the configured listener
  dynamic build() {
    if (_subscription == null) {
      throw ArgumentError('Subscription is required');
    }

    // Wrap with batching if configured
    if (_batchInterval != null && _batchHandler != null) {
      return BatchedEventListener(
        subscription: _subscription!,
        batchInterval: _batchInterval!,
        batchHandler: _batchHandler!,
        maxBatchSize: _maxBatchSize ?? 100,
      );
    }

    // Wrap with filtering if configured
    if (_filter != null && _eventHandler != null) {
      return FilteredEventListener(
        subscription: _subscription!,
        filter: _filter!,
        eventHandler: _eventHandler!,
      );
    }

    // Wrap with history if configured
    if (_maxHistorySize != null) {
      return HistoryEventListener(
        subscription: _subscription!,
        maxHistorySize: _maxHistorySize!,
      );
    }

    // Return pausable listener by default
    return PausableEventListener(_subscription!);
  }
}
