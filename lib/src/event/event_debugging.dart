/// Advanced event debugging and monitoring capabilities
///
/// This module provides comprehensive debugging tools, performance monitoring,
/// and diagnostic capabilities for the event system.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

/// Event debugging and monitoring service
class EventDebugMonitor {

  EventDebugMonitor({this.config = const EventMonitorConfig()}) {
    _statsCollector = EventStatisticsCollector(config);
    _startTime = DateTime.now();
    _startMonitoring();
  }
  final EventMonitorConfig config;

  // Performance tracking
  final Map<String, EventPerformanceTracker> _performanceTrackers = {};
  final Queue<EventDebugEntry> _debugHistory = Queue();
  final Map<String, int> _eventCounts = {};
  final Map<String, List<Duration>> _processingTimes = {};

  // Real-time monitoring
  final StreamController<EventDebugInfo> _debugInfoController =
      StreamController.broadcast();
  final StreamController<EventAlert> _alertController =
      StreamController.broadcast();

  // Statistics
  late final EventStatisticsCollector _statsCollector;
  Timer? _monitoringTimer;
  DateTime? _startTime;

  /// Stream of debug information
  Stream<EventDebugInfo> get debugInfo => _debugInfoController.stream;

  /// Stream of performance alerts
  Stream<EventAlert> get alerts => _alertController.stream;

  /// Current statistics
  EventMonitoringStats get currentStats => _statsCollector.getStats();

  /// Record event processing start
  String startEventProcessing(String eventName, Map<String, dynamic> metadata) {
    final id = _generateId();
    final tracker = EventPerformanceTracker(
      id: id,
      eventName: eventName,
      startTime: DateTime.now(),
      metadata: metadata,
    );

    _performanceTrackers[id] = tracker;
    _eventCounts[eventName] = (_eventCounts[eventName] ?? 0) + 1;

    if (config.enableDetailedLogging) {
      _addDebugEntry(EventDebugEntry(
        timestamp: DateTime.now(),
        level: DebugLevel.info,
        eventName: eventName,
        message: 'Event processing started',
        metadata: metadata,
      ),);
    }

    return id;
  }

  /// Record event processing completion
  void completeEventProcessing(
    String id, {
    bool success = true,
    String? error,
    Map<String, dynamic>? resultMetadata,
  }) {
    final tracker = _performanceTrackers.remove(id);
    if (tracker == null) return;

    final duration = DateTime.now().difference(tracker.startTime);
    tracker.complete(duration, success, error);

    // Track processing times
    _processingTimes.putIfAbsent(tracker.eventName, () => []).add(duration);

    // Emit debug info
    final debugInfo = EventDebugInfo(
      eventName: tracker.eventName,
      processingTime: duration,
      success: success,
      error: error,
      metadata: {...tracker.metadata, ...?resultMetadata},
    );
    _debugInfoController.add(debugInfo);

    // Check for performance alerts
    _checkPerformanceAlerts(tracker.eventName, duration);

    // Update statistics
    _statsCollector.recordEventProcessing(tracker.eventName, duration, success);

    if (config.enableDetailedLogging) {
      _addDebugEntry(EventDebugEntry(
        timestamp: DateTime.now(),
        level: success ? DebugLevel.info : DebugLevel.error,
        eventName: tracker.eventName,
        message:
            success ? 'Event processing completed' : 'Event processing failed',
        metadata: {'duration': duration.inMicroseconds, 'error': error},
      ),);
    }
  }

  /// Record event parsing performance
  void recordEventParsingPerformance(
      String eventName, Duration parseTime, bool success,) {
    _statsCollector.recordEventParsing(eventName, parseTime, success);

    if (!success || parseTime > config.parseTimeAlertThreshold) {
      _alertController.add(EventAlert(
        type: success ? AlertType.performance : AlertType.error,
        severity: success ? AlertSeverity.warning : AlertSeverity.error,
        message: success
            ? 'Slow event parsing detected for $eventName: ${parseTime.inMilliseconds}ms'
            : 'Event parsing failed for $eventName',
        eventName: eventName,
        timestamp: DateTime.now(),
        metadata: {'parseTime': parseTime.inMicroseconds, 'success': success},
      ),);
    }
  }

  /// Record subscription activity
  void recordSubscriptionActivity(
      String eventName, SubscriptionActivity activity,) {
    _statsCollector.recordSubscriptionActivity(eventName, activity);

    if (config.enableDetailedLogging) {
      _addDebugEntry(EventDebugEntry(
        timestamp: DateTime.now(),
        level: DebugLevel.debug,
        eventName: eventName,
        message: 'Subscription activity: ${activity.name}',
        metadata: {'activity': activity.name},
      ),);
    }
  }

  /// Get performance metrics for an event
  EventPerformanceMetrics? getEventMetrics(String eventName) {
    final times = _processingTimes[eventName];
    if (times == null || times.isEmpty) return null;

    times.sort();
    final count = times.length;
    final sum = times.fold(Duration.zero, (a, b) => a + b);
    final average = Duration(microseconds: sum.inMicroseconds ~/ count);

    return EventPerformanceMetrics(
      eventName: eventName,
      totalProcessed: count,
      averageProcessingTime: average,
      minProcessingTime: times.first,
      maxProcessingTime: times.last,
      p50ProcessingTime: times[count ~/ 2],
      p95ProcessingTime: times[(count * 0.95).floor()],
      p99ProcessingTime: times[(count * 0.99).floor()],
    );
  }

  /// Get debug history
  List<EventDebugEntry> getDebugHistory({
    int? limit,
    DebugLevel? minLevel,
    String? eventName,
  }) {
    var entries = _debugHistory.toList();

    if (eventName != null) {
      entries = entries.where((e) => e.eventName == eventName).toList();
    }

    if (minLevel != null) {
      entries = entries.where((e) => e.level.index >= minLevel.index).toList();
    }

    if (limit != null && limit < entries.length) {
      entries = entries.take(limit).toList();
    }

    return entries;
  }

  /// Get active performance trackers
  Map<String, EventPerformanceTracker> getActiveTrackers() => Map.unmodifiable(_performanceTrackers);

  /// Generate performance report
  EventPerformanceReport generatePerformanceReport() {
    final now = DateTime.now();
    final uptime =
        _startTime != null ? now.difference(_startTime!) : Duration.zero;

    final eventMetrics = <String, EventPerformanceMetrics>{};
    for (final eventName in _processingTimes.keys) {
      final metrics = getEventMetrics(eventName);
      if (metrics != null) {
        eventMetrics[eventName] = metrics;
      }
    }

    return EventPerformanceReport(
      generatedAt: now,
      uptime: uptime,
      totalEventsProcessed: _eventCounts.values.fold(0, (a, b) => a + b),
      eventMetrics: eventMetrics,
      activeTrackers: _performanceTrackers.length,
      debugHistorySize: _debugHistory.length,
      overallStats: currentStats,
    );
  }

  /// Clear debug history
  void clearDebugHistory() {
    _debugHistory.clear();
  }

  /// Clear performance data
  void clearPerformanceData() {
    _processingTimes.clear();
    _eventCounts.clear();
    _performanceTrackers.clear();
    _statsCollector.reset();
  }

  /// Start monitoring timer
  void _startMonitoring() {
    if (config.enablePeriodicReporting) {
      _monitoringTimer = Timer.periodic(config.reportingInterval, (_) {
        final report = generatePerformanceReport();
        _debugInfoController.add(EventDebugInfo.fromReport(report));
      });
    }
  }

  /// Check for performance alerts
  void _checkPerformanceAlerts(String eventName, Duration processingTime) {
    if (processingTime > config.slowProcessingThreshold) {
      _alertController.add(EventAlert(
        type: AlertType.performance,
        severity: processingTime > config.slowProcessingThreshold * 2
            ? AlertSeverity.error
            : AlertSeverity.warning,
        message:
            'Slow event processing detected for $eventName: ${processingTime.inMilliseconds}ms',
        eventName: eventName,
        timestamp: DateTime.now(),
        metadata: {'processingTime': processingTime.inMicroseconds},
      ),);
    }

    // Check error rate
    final recentFailures = _statsCollector.getRecentFailureRate(eventName);
    if (recentFailures > config.errorRateThreshold) {
      _alertController.add(EventAlert(
        type: AlertType.error,
        severity: AlertSeverity.error,
        message:
            'High error rate detected for $eventName: ${(recentFailures * 100).toStringAsFixed(1)}%',
        eventName: eventName,
        timestamp: DateTime.now(),
        metadata: {'errorRate': recentFailures},
      ),);
    }
  }

  /// Add debug entry
  void _addDebugEntry(EventDebugEntry entry) {
    _debugHistory.addLast(entry);

    // Limit history size
    while (_debugHistory.length > config.maxDebugHistorySize) {
      _debugHistory.removeFirst();
    }
  }

  /// Generate unique ID
  String _generateId() => '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';

  /// Dispose resources
  Future<void> dispose() async {
    _monitoringTimer?.cancel();
    await _debugInfoController.close();
    await _alertController.close();
  }
}

/// Event performance tracker
class EventPerformanceTracker {

  EventPerformanceTracker({
    required this.id,
    required this.eventName,
    required this.startTime,
    this.metadata = const {},
  });
  final String id;
  final String eventName;
  final DateTime startTime;
  final Map<String, dynamic> metadata;

  Duration? _duration;
  bool? _success;
  String? _error;

  void complete(Duration duration, bool success, String? error) {
    _duration = duration;
    _success = success;
    _error = error;
  }

  Duration? get duration => _duration;
  bool? get success => _success;
  String? get error => _error;
  bool get isCompleted => _duration != null;
}

/// Debug entry for event processing
class EventDebugEntry {

  const EventDebugEntry({
    required this.timestamp,
    required this.level,
    required this.eventName,
    required this.message,
    this.metadata = const {},
  });
  final DateTime timestamp;
  final DebugLevel level;
  final String eventName;
  final String message;
  final Map<String, dynamic> metadata;
}

/// Event debug information
class EventDebugInfo {

  EventDebugInfo({
    required this.eventName,
    required this.processingTime,
    required this.success,
    this.error,
    this.metadata = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory EventDebugInfo.fromReport(EventPerformanceReport report) {
    return EventDebugInfo(
      eventName: 'SYSTEM',
      processingTime: Duration.zero,
      success: true,
      metadata: {
        'uptime': report.uptime.inSeconds,
        'totalEvents': report.totalEventsProcessed,
        'activeTrackers': report.activeTrackers,
      },
    );
  }
  final String eventName;
  final Duration processingTime;
  final bool success;
  final String? error;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
}

/// Event alert
class EventAlert {

  const EventAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.eventName,
    required this.timestamp,
    this.metadata = const {},
  });
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final String eventName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
}

/// Event performance metrics
class EventPerformanceMetrics {

  const EventPerformanceMetrics({
    required this.eventName,
    required this.totalProcessed,
    required this.averageProcessingTime,
    required this.minProcessingTime,
    required this.maxProcessingTime,
    required this.p50ProcessingTime,
    required this.p95ProcessingTime,
    required this.p99ProcessingTime,
  });
  final String eventName;
  final int totalProcessed;
  final Duration averageProcessingTime;
  final Duration minProcessingTime;
  final Duration maxProcessingTime;
  final Duration p50ProcessingTime;
  final Duration p95ProcessingTime;
  final Duration p99ProcessingTime;
}

/// Event performance report
class EventPerformanceReport {

  const EventPerformanceReport({
    required this.generatedAt,
    required this.uptime,
    required this.totalEventsProcessed,
    required this.eventMetrics,
    required this.activeTrackers,
    required this.debugHistorySize,
    required this.overallStats,
  });
  final DateTime generatedAt;
  final Duration uptime;
  final int totalEventsProcessed;
  final Map<String, EventPerformanceMetrics> eventMetrics;
  final int activeTrackers;
  final int debugHistorySize;
  final EventMonitoringStats overallStats;
}

/// Event monitoring configuration
class EventMonitorConfig {

  const EventMonitorConfig({
    this.enableDetailedLogging = true,
    this.enablePeriodicReporting = false,
    this.reportingInterval = const Duration(minutes: 5),
    this.slowProcessingThreshold = const Duration(milliseconds: 100),
    this.parseTimeAlertThreshold = const Duration(milliseconds: 10),
    this.errorRateThreshold = 0.1, // 10%
    this.maxDebugHistorySize = 1000,
  });

  factory EventMonitorConfig.development() => const EventMonitorConfig(
        enableDetailedLogging: true,
        enablePeriodicReporting: true,
        reportingInterval: Duration(minutes: 1),
        slowProcessingThreshold: Duration(milliseconds: 50),
        parseTimeAlertThreshold: Duration(milliseconds: 5),
        errorRateThreshold: 0.05, // 5%
        maxDebugHistorySize: 500,
      );

  factory EventMonitorConfig.production() => const EventMonitorConfig(
        enableDetailedLogging: false,
        enablePeriodicReporting: true,
        reportingInterval: Duration(minutes: 10),
        slowProcessingThreshold: Duration(milliseconds: 200),
        parseTimeAlertThreshold: Duration(milliseconds: 20),
        errorRateThreshold: 0.15, // 15%
        maxDebugHistorySize: 2000,
      );
  final bool enableDetailedLogging;
  final bool enablePeriodicReporting;
  final Duration reportingInterval;
  final Duration slowProcessingThreshold;
  final Duration parseTimeAlertThreshold;
  final double errorRateThreshold;
  final int maxDebugHistorySize;
}

/// Debug levels
enum DebugLevel { debug, info, warning, error }

/// Alert types
enum AlertType { performance, error, memory, network }

/// Alert severity
enum AlertSeverity { info, warning, error, critical }

/// Subscription activity types
enum SubscriptionActivity { subscribe, unsubscribe, reconnect, error }

/// Statistics collector
class EventStatisticsCollector {

  EventStatisticsCollector(this.config);
  final EventMonitorConfig config;
  final Map<String, List<bool>> _recentResults = {};
  final Map<String, List<Duration>> _recentProcessingTimes = {};
  final Map<String, int> _eventCounts = {};
  final Map<String, int> _errorCounts = {};

  void recordEventProcessing(
      String eventName, Duration duration, bool success,) {
    _eventCounts[eventName] = (_eventCounts[eventName] ?? 0) + 1;
    if (!success) {
      _errorCounts[eventName] = (_errorCounts[eventName] ?? 0) + 1;
    }

    // Track recent results for error rate calculation
    _recentResults.putIfAbsent(eventName, () => []).add(success);
    _recentProcessingTimes.putIfAbsent(eventName, () => []).add(duration);

    // Limit recent data
    final maxRecent = 100;
    if (_recentResults[eventName]!.length > maxRecent) {
      _recentResults[eventName]!.removeAt(0);
    }
    if (_recentProcessingTimes[eventName]!.length > maxRecent) {
      _recentProcessingTimes[eventName]!.removeAt(0);
    }
  }

  void recordEventParsing(String eventName, Duration duration, bool success) {
    // Similar tracking for parsing performance
  }

  void recordSubscriptionActivity(
      String eventName, SubscriptionActivity activity,) {
    // Track subscription activities
  }

  double getRecentFailureRate(String eventName) {
    final results = _recentResults[eventName];
    if (results == null || results.isEmpty) return 0;

    final failures = results.where((r) => !r).length;
    return failures / results.length;
  }

  EventMonitoringStats getStats() => EventMonitoringStats(
      totalEvents: _eventCounts.values.fold(0, (a, b) => a + b),
      totalErrors: _errorCounts.values.fold(0, (a, b) => a + b),
      eventBreakdown: Map.from(_eventCounts),
      errorBreakdown: Map.from(_errorCounts),
    );

  void reset() {
    _recentResults.clear();
    _recentProcessingTimes.clear();
    _eventCounts.clear();
    _errorCounts.clear();
  }
}

/// Event monitoring statistics
class EventMonitoringStats {

  const EventMonitoringStats({
    required this.totalEvents,
    required this.totalErrors,
    required this.eventBreakdown,
    required this.errorBreakdown,
  });
  final int totalEvents;
  final int totalErrors;
  final Map<String, int> eventBreakdown;
  final Map<String, int> errorBreakdown;

  double get errorRate => totalEvents > 0 ? totalErrors / totalEvents : 0.0;
}
