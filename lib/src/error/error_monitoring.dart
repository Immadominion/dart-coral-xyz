/// Error Monitoring and Metrics System for Production-Ready Error Handling
///
/// This module provides comprehensive error monitoring, metrics collection,
/// and alerting capabilities for production systems.
library;

import 'dart:async';
import 'package:coral_xyz_anchor/src/error/error_context.dart';
import 'package:coral_xyz_anchor/src/utils/logger.dart';

/// Error metrics data point
class ErrorMetric {
  /// Create error metric
  const ErrorMetric({
    required this.timestamp,
    required this.errorType,
    required this.severity,
    required this.category,
    this.context,
    this.count = 1,
  });

  /// When the error occurred
  final DateTime timestamp;

  /// Type of error
  final String errorType;

  /// Error severity
  final ErrorSeverity severity;

  /// Error category
  final ErrorCategory category;

  /// Error context
  final ErrorContext? context;

  /// Number of occurrences
  final int count;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'errorType': errorType,
        'severity': severity.name,
        'category': category.name,
        'context': context?.toJson(),
        'count': count,
      };
}

/// Error rate threshold configuration
class ErrorRateThreshold {
  /// Create error rate threshold
  const ErrorRateThreshold({
    required this.windowDuration,
    required this.threshold,
    required this.severity,
  });

  /// Time window for rate calculation
  final Duration windowDuration;

  /// Maximum error rate (errors per second)
  final double threshold;

  /// Severity level for this threshold
  final ErrorSeverity severity;
}

/// Error monitoring configuration
class ErrorMonitoringConfig {
  /// Create error monitoring configuration
  const ErrorMonitoringConfig({
    this.enableMetrics = true,
    this.enableAlerting = true,
    this.metricRetentionDuration = const Duration(hours: 24),
    this.alertCooldownDuration = const Duration(minutes: 10),
    this.errorRateThresholds = const [
      ErrorRateThreshold(
        windowDuration: Duration(minutes: 1),
        threshold: 0.1, // 0.1 errors per second
        severity: ErrorSeverity.medium,
      ),
      ErrorRateThreshold(
        windowDuration: Duration(minutes: 5),
        threshold: 0.05, // 0.05 errors per second
        severity: ErrorSeverity.high,
      ),
      ErrorRateThreshold(
        windowDuration: Duration(minutes: 15),
        threshold: 0.02, // 0.02 errors per second
        severity: ErrorSeverity.critical,
      ),
    ],
  });

  /// Whether to collect error metrics
  final bool enableMetrics;

  /// Whether to send alerts
  final bool enableAlerting;

  /// How long to retain metrics
  final Duration metricRetentionDuration;

  /// Cooldown between alerts of same type
  final Duration alertCooldownDuration;

  /// Error rate thresholds for alerting
  final List<ErrorRateThreshold> errorRateThresholds;
}

/// Error alert
class ErrorAlert {
  /// Create error alert
  const ErrorAlert({
    required this.severity,
    required this.message,
    required this.errorType,
    required this.timestamp,
    this.context,
    this.metadata,
  });

  /// Alert severity
  final ErrorSeverity severity;

  /// Alert message
  final String message;

  /// Type of error that triggered alert
  final String errorType;

  /// When alert was triggered
  final DateTime timestamp;

  /// Error context
  final ErrorContext? context;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'message': message,
        'errorType': errorType,
        'timestamp': timestamp.toIso8601String(),
        'context': context?.toJson(),
        'metadata': metadata,
      };
}

/// Error monitoring system
class ErrorMonitor {
  /// Create error monitor
  ErrorMonitor({
    ErrorMonitoringConfig? config,
    AnchorLogger? logger,
  })  : _config = config ?? const ErrorMonitoringConfig(),
        _logger = logger ?? AnchorLoggers.error;

  /// Configuration
  final ErrorMonitoringConfig _config;

  /// Logger instance
  final AnchorLogger _logger;

  /// Error metrics storage
  final List<ErrorMetric> _metrics = [];

  /// Alert cooldown tracker
  final Map<String, DateTime> _alertCooldowns = {};

  /// Start monitoring
  void start() {
    if (_config.enableMetrics) {
      _startMetricsCleanup();
    }
    _logger.info('Error monitoring started');
  }

  /// Stop monitoring
  void stop() {
    _metricsCleanupTimer?.cancel();
    _logger.info('Error monitoring stopped');
  }

  /// Record an error
  void recordError(Object error, ErrorContext? context) {
    if (!_config.enableMetrics) return;

    final severity = ErrorHandlingUtils.determineSeverity(error, context);
    final category = ErrorHandlingUtils.categorizeError(error);

    final metric = ErrorMetric(
      timestamp: DateTime.now(),
      errorType: error.runtimeType.toString(),
      severity: severity,
      category: category,
      context: context,
    );

    _metrics.add(metric);

    _logger.debug('Error recorded', context: {
      'errorType': metric.errorType,
      'severity': metric.severity.name,
      'category': metric.category.name,
    });

    // Check for alerting
    if (_config.enableAlerting) {
      _checkAlertThresholds(metric);
    }
  }

  /// Get error statistics for a time window
  ErrorStatistics getStatistics({Duration? window}) {
    final now = DateTime.now();
    final windowStart = window != null ? now.subtract(window) : null;

    final relevantMetrics = windowStart != null
        ? _metrics.where((m) => m.timestamp.isAfter(windowStart)).toList()
        : _metrics;

    final totalErrors = relevantMetrics.length;
    final errorsByType = <String, int>{};
    final errorsBySeverity = <ErrorSeverity, int>{};
    final errorsByCategory = <ErrorCategory, int>{};

    for (final metric in relevantMetrics) {
      errorsByType[metric.errorType] =
          (errorsByType[metric.errorType] ?? 0) + 1;
      errorsBySeverity[metric.severity] =
          (errorsBySeverity[metric.severity] ?? 0) + 1;
      errorsByCategory[metric.category] =
          (errorsByCategory[metric.category] ?? 0) + 1;
    }

    final errorRate = window != null && totalErrors > 0
        ? totalErrors / window.inSeconds
        : 0.0;

    return ErrorStatistics(
      totalErrors: totalErrors,
      errorRate: errorRate,
      errorsByType: errorsByType,
      errorsBySeverity: errorsBySeverity,
      errorsByCategory: errorsByCategory,
      timeWindow: window,
    );
  }

  /// Get recent errors
  List<ErrorMetric> getRecentErrors({
    Duration window = const Duration(hours: 1),
    int? limit,
  }) {
    final cutoff = DateTime.now().subtract(window);
    final recentErrors = _metrics
        .where((m) => m.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return limit != null && recentErrors.length > limit
        ? recentErrors.take(limit).toList()
        : recentErrors;
  }

  /// Timer for metrics cleanup
  Timer? _metricsCleanupTimer;

  /// Start metrics cleanup timer
  void _startMetricsCleanup() {
    _metricsCleanupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _cleanupMetrics(),
    );
  }

  /// Clean up old metrics
  void _cleanupMetrics() {
    final cutoff = DateTime.now().subtract(_config.metricRetentionDuration);
    _metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoff));

    _logger.debug('Cleaned up old metrics', context: {
      'retained': _metrics.length,
      'cutoff': cutoff.toIso8601String(),
    });
  }

  /// Check if error rate exceeds thresholds
  void _checkAlertThresholds(ErrorMetric metric) {
    for (final threshold in _config.errorRateThresholds) {
      final stats = getStatistics(window: threshold.windowDuration);

      if (stats.errorRate > threshold.threshold) {
        final alertKey = '${metric.errorType}_${threshold.severity.name}';
        final now = DateTime.now();

        // Check cooldown
        final lastAlert = _alertCooldowns[alertKey];
        if (lastAlert != null &&
            now.difference(lastAlert) < _config.alertCooldownDuration) {
          continue;
        }

        _alertCooldowns[alertKey] = now;

        final alert = ErrorAlert(
          severity: threshold.severity,
          message:
              'High error rate detected: ${stats.errorRate.toStringAsFixed(3)} '
              'errors/second for ${metric.errorType} '
              '(threshold: ${threshold.threshold})',
          errorType: metric.errorType,
          timestamp: now,
          context: metric.context,
          metadata: {
            'errorRate': stats.errorRate,
            'threshold': threshold.threshold,
            'windowDuration': threshold.windowDuration.inSeconds,
            'totalErrors': stats.totalErrors,
          },
        );

        _sendAlert(alert);
      }
    }
  }

  /// Send alert
  void _sendAlert(ErrorAlert alert) {
    _logger.error(
      'ERROR ALERT: ${alert.message}',
      context: alert.toJson(),
    );

    // In a real implementation, this would integrate with alerting systems
    // like PagerDuty, Slack, email, etc.
  }
}

/// Error statistics
class ErrorStatistics {
  /// Create error statistics
  const ErrorStatistics({
    required this.totalErrors,
    required this.errorRate,
    required this.errorsByType,
    required this.errorsBySeverity,
    required this.errorsByCategory,
    this.timeWindow,
  });

  /// Total number of errors
  final int totalErrors;

  /// Error rate (errors per second)
  final double errorRate;

  /// Errors grouped by type
  final Map<String, int> errorsByType;

  /// Errors grouped by severity
  final Map<ErrorSeverity, int> errorsBySeverity;

  /// Errors grouped by category
  final Map<ErrorCategory, int> errorsByCategory;

  /// Time window for statistics
  final Duration? timeWindow;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'totalErrors': totalErrors,
        'errorRate': errorRate,
        'errorsByType': errorsByType,
        'errorsBySeverity': errorsBySeverity.map(
          (k, v) => MapEntry(k.name, v),
        ),
        'errorsByCategory': errorsByCategory.map(
          (k, v) => MapEntry(k.name, v),
        ),
        'timeWindow': timeWindow?.inSeconds,
      };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Error Statistics:');
    buffer.writeln('  Total Errors: $totalErrors');
    buffer.writeln('  Error Rate: ${errorRate.toStringAsFixed(3)} errors/sec');

    if (timeWindow != null) {
      buffer.writeln('  Time Window: ${timeWindow!.inMinutes} minutes');
    }

    if (errorsByType.isNotEmpty) {
      buffer.writeln('  By Type:');
      for (final entry in errorsByType.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    if (errorsBySeverity.isNotEmpty) {
      buffer.writeln('  By Severity:');
      for (final entry in errorsBySeverity.entries) {
        buffer.writeln('    ${entry.key.name}: ${entry.value}');
      }
    }

    return buffer.toString();
  }
}

/// Global error monitor instance
ErrorMonitor? _globalErrorMonitor;

/// Get global error monitor
ErrorMonitor get globalErrorMonitor {
  return _globalErrorMonitor ??= ErrorMonitor();
}

/// Configure global error monitor
void configureErrorMonitor({
  ErrorMonitoringConfig? config,
  AnchorLogger? logger,
}) {
  _globalErrorMonitor = ErrorMonitor(
    config: config,
    logger: logger,
  );
}

/// Start global error monitoring
void startErrorMonitoring() {
  globalErrorMonitor.start();
}

/// Stop global error monitoring
void stopErrorMonitoring() {
  globalErrorMonitor.stop();
}
