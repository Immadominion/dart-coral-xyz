/// Enhanced Logging Integration for Anchor Operations
///
/// This module provides specialized logging for Anchor operations with
/// structured logging, performance monitoring, and debug information.
library;

import 'package:coral_xyz_anchor/src/utils/logger.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Enhanced Anchor-specific logging system
class AnchorLogging {
  /// Private constructor
  AnchorLogging._();

  /// Global logging configuration
  static bool _enabled = true;
  static LogLevel _globalLevel = LogLevel.info;
  static bool _includeStackTraces = false;
  static bool _includePerformanceMetrics = false;

  /// Configure Anchor logging globally
  static void configure({
    bool enabled = true,
    LogLevel level = LogLevel.info,
    bool includeStackTraces = false,
    bool includePerformanceMetrics = false,
    int maxLogSize = 1000,
  }) {
    _enabled = enabled;
    _globalLevel = level;
    _includeStackTraces = includeStackTraces;
    _includePerformanceMetrics = includePerformanceMetrics;

    // Configure underlying logger
    AnchorLogger.configure(LoggerConfig(
      level: level,
      includeStackTrace: includeStackTraces,
      maxContextLength: maxLogSize,
    ));
  }

  /// Enable debug logging for development
  static void enableDebug() {
    configure(
      level: LogLevel.debug,
      includeStackTraces: true,
      includePerformanceMetrics: true,
    );
  }

  /// Enable production logging
  static void enableProduction() {
    configure(
      level: LogLevel.warn,
      includeStackTraces: false,
      includePerformanceMetrics: false,
    );
  }

  /// Disable all logging
  static void disable() {
    _enabled = false;
  }

  /// Check if logging is enabled for a given level
  static bool isEnabled(LogLevel level) {
    return _enabled && level.value >= _globalLevel.value;
  }

  /// Log program initialization
  static void logProgramInit({
    required PublicKey programId,
    String? programName,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.info)) return;

    AnchorLoggers.account.info(
      'Program initialized',
      context: {
        'programId': programId.toBase58(),
        'programName': programName ?? 'unknown',
        'operation': 'program_init',
        ...?context,
      },
    );
  }

  /// Log method invocation
  static void logMethodCall({
    required String methodName,
    required PublicKey programId,
    List<dynamic>? args,
    Map<String, PublicKey>? accounts,
    Duration? duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'methodName': methodName,
      'programId': programId.toBase58(),
      'operation': 'method_call',
      ...?context,
    };

    if (accounts != null) {
      logContext['accounts'] = accounts.map(
        (key, value) => MapEntry(key, value.toBase58()),
      );
    }

    if (args != null) {
      logContext['args'] = _sanitizeArgs(args);
    }

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
    }

    AnchorLoggers.transaction.debug(
      'Method call: $methodName',
      context: logContext,
    );
  }

  /// Log account fetching
  static void logAccountFetch({
    required PublicKey accountAddress,
    String? accountType,
    bool? found,
    Duration? duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'accountAddress': accountAddress.toBase58(),
      'accountType': accountType ?? 'unknown',
      'found': found,
      'operation': 'account_fetch',
      ...?context,
    };

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
    }

    AnchorLoggers.account.debug(
      'Account fetch: ${accountType ?? 'unknown'}',
      context: logContext,
    );
  }

  /// Log batch account fetching
  static void logBatchAccountFetch({
    required List<PublicKey> accountAddresses,
    int? successCount,
    Duration? duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'accountCount': accountAddresses.length,
      'successCount': successCount,
      'operation': 'batch_account_fetch',
      ...?context,
    };

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
      logContext['avg_duration_per_account'] =
          (duration.inMilliseconds / accountAddresses.length).round();
    }

    AnchorLoggers.performance.debug(
      'Batch account fetch completed',
      context: logContext,
    );
  }

  /// Log transaction building
  static void logTransactionBuild({
    required String instructionName,
    required PublicKey programId,
    int? accountCount,
    int? instructionDataSize,
    Duration? duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'instructionName': instructionName,
      'programId': programId.toBase58(),
      'accountCount': accountCount,
      'instructionDataSize': instructionDataSize,
      'operation': 'transaction_build',
      ...?context,
    };

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
    }

    AnchorLoggers.transaction.debug(
      'Transaction built: $instructionName',
      context: logContext,
    );
  }

  /// Log transaction sending
  static void logTransactionSend({
    required String transactionSignature,
    required PublicKey programId,
    String? instructionName,
    Duration? duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.info)) return;

    final logContext = <String, dynamic>{
      'transactionSignature': transactionSignature,
      'programId': programId.toBase58(),
      'instructionName': instructionName,
      'operation': 'transaction_send',
      ...?context,
    };

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
    }

    AnchorLoggers.transaction.info(
      'Transaction sent: $transactionSignature',
      context: logContext,
    );
  }

  /// Log RPC call
  static void logRpcCall({
    required String method,
    required String endpoint,
    Duration? duration,
    bool? success,
    int? statusCode,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'method': method,
      'endpoint': endpoint,
      'success': success,
      'statusCode': statusCode,
      'operation': 'rpc_call',
      ...?context,
    };

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
    }

    final level = success == false ? LogLevel.warn : LogLevel.debug;
    final logger = AnchorLoggers.rpc;

    if (level == LogLevel.warn) {
      logger.warn('RPC call failed: $method', context: logContext);
    } else {
      logger.debug('RPC call: $method', context: logContext);
    }
  }

  /// Log event parsing
  static void logEventParse({
    required String eventName,
    required PublicKey programId,
    bool? success,
    String? errorMessage,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'eventName': eventName,
      'programId': programId.toBase58(),
      'success': success,
      'errorMessage': errorMessage,
      'operation': 'event_parse',
      ...?context,
    };

    if (success == false) {
      AnchorLoggers.event.warn(
        'Event parse failed: $eventName',
        context: logContext,
      );
    } else {
      AnchorLoggers.event.debug(
        'Event parsed: $eventName',
        context: logContext,
      );
    }
  }

  /// Log IDL processing
  static void logIdlProcess({
    required String operation,
    String? programName,
    PublicKey? programId,
    bool? success,
    String? errorMessage,
    Duration? duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug)) return;

    final logContext = <String, dynamic>{
      'operation': 'idl_$operation',
      'programName': programName,
      'programId': programId?.toBase58(),
      'success': success,
      'errorMessage': errorMessage,
      ...?context,
    };

    if (duration != null && _includePerformanceMetrics) {
      logContext['duration_ms'] = duration.inMilliseconds;
    }

    if (success == false) {
      AnchorLoggers.idl.warn(
        'IDL $operation failed',
        context: logContext,
      );
    } else {
      AnchorLoggers.idl.debug(
        'IDL $operation completed',
        context: logContext,
      );
    }
  }

  /// Log performance metrics
  static void logPerformanceMetric({
    required String operation,
    required Duration duration,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.debug) || !_includePerformanceMetrics) return;

    final logContext = <String, dynamic>{
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'duration_readable': '${duration.inMilliseconds}ms',
      'metric_type': 'performance',
      ...?context,
    };

    // Log slow operations as warnings
    if (duration.inMilliseconds > 5000) {
      AnchorLoggers.performance.warn(
        'Slow operation detected: $operation',
        context: logContext,
      );
    } else {
      AnchorLoggers.performance.debug(
        'Performance: $operation',
        context: logContext,
      );
    }
  }

  /// Log error with enhanced context
  static void logError({
    required Object error,
    required String operation,
    PublicKey? programId,
    String? transactionSignature,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    if (!isEnabled(LogLevel.error)) return;

    final logContext = <String, dynamic>{
      'operation': operation,
      'errorType': error.runtimeType.toString(),
      'programId': programId?.toBase58(),
      'transactionSignature': transactionSignature,
      'timestamp': DateTime.now().toIso8601String(),
      ...?context,
    };

    AnchorLoggers.error.error(
      'Error in $operation: $error',
      context: logContext,
      error: error,
      stackTrace: _includeStackTraces ? stackTrace : null,
    );
  }

  /// Sanitize arguments for logging (remove sensitive data)
  static List<dynamic> _sanitizeArgs(List<dynamic> args) {
    return args.map((arg) {
      if (arg is String && arg.length > 100) {
        return '${arg.substring(0, 100)}...[truncated]';
      } else if (arg is List && arg.length > 10) {
        return '[${arg.length} items]';
      } else if (arg is Map && arg.length > 10) {
        return '{${arg.length} entries}';
      }
      return arg;
    }).toList();
  }
}

/// Performance monitoring utilities for Anchor operations
class AnchorPerformanceMonitor {
  /// Active operation timers
  static final Map<String, DateTime> _timers = {};

  /// Start timing an operation
  static void startTimer(String operation) {
    _timers[operation] = DateTime.now();
  }

  /// End timing an operation and log the result
  static Duration? endTimer(String operation, {Map<String, dynamic>? context}) {
    final startTime = _timers.remove(operation);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);

    AnchorLogging.logPerformanceMetric(
      operation: operation,
      duration: duration,
      context: context,
    );

    return duration;
  }

  /// Time a synchronous operation
  static T timeOperation<T>(
    String operation,
    T Function() callback, {
    Map<String, dynamic>? context,
  }) {
    startTimer(operation);
    try {
      final result = callback();
      endTimer(operation, context: context);
      return result;
    } catch (e) {
      endTimer(operation, context: context);
      rethrow;
    }
  }

  /// Time an asynchronous operation
  static Future<T> timeAsyncOperation<T>(
    String operation,
    Future<T> Function() callback, {
    Map<String, dynamic>? context,
  }) async {
    startTimer(operation);
    try {
      final result = await callback();
      endTimer(operation, context: context);
      return result;
    } catch (e) {
      endTimer(operation, context: context);
      rethrow;
    }
  }

  /// Get statistics about operation timings
  static Map<String, dynamic> getStats() {
    return {
      'active_timers': _timers.length,
      'active_operations': _timers.keys.toList(),
    };
  }

  /// Clear all active timers
  static void clearTimers() {
    _timers.clear();
  }
}

/// Debug utilities for Anchor development
class AnchorDebugUtils {
  /// Enable comprehensive debug logging
  static void enableDebugMode() {
    AnchorLogging.enableDebug();

    AnchorLoggers.transaction.info('Debug mode enabled', context: {
      'timestamp': DateTime.now().toIso8601String(),
      'stack_traces': true,
      'performance_metrics': true,
    });
  }

  /// Log detailed account information
  static void logAccountDetails({
    required PublicKey address,
    String? accountType,
    int? dataLength,
    PublicKey? owner,
    int? lamports,
    Map<String, dynamic>? context,
  }) {
    AnchorLoggers.account.debug(
      'Account details',
      context: {
        'address': address.toBase58(),
        'accountType': accountType,
        'dataLength': dataLength,
        'owner': owner?.toBase58(),
        'lamports': lamports,
        'operation': 'account_debug',
        ...?context,
      },
    );
  }

  /// Log transaction details for debugging
  static void logTransactionDetails({
    required String signature,
    required List<String> instructionNames,
    required List<PublicKey> programIds,
    int? computeUnitsUsed,
    int? fee,
    Map<String, dynamic>? context,
  }) {
    AnchorLoggers.transaction.debug(
      'Transaction details',
      context: {
        'signature': signature,
        'instructionNames': instructionNames,
        'programIds': programIds.map((p) => p.toBase58()).toList(),
        'computeUnitsUsed': computeUnitsUsed,
        'fee': fee,
        'operation': 'transaction_debug',
        ...?context,
      },
    );
  }

  /// Log error with full context for debugging
  static void logDetailedError({
    required Object error,
    required String operation,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorDetails = <String, dynamic>{
      'operation': operation,
      'errorType': error.runtimeType.toString(),
      'errorString': error.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'stackTrace': stackTrace?.toString(),
      ...?context,
    };

    AnchorLoggers.error.error(
      'Detailed error information',
      context: errorDetails,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
