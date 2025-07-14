/// Comprehensive Debug Logging System for Coral XYZ Anchor Dart SDK
///
/// This module provides a production-ready logging system with proper
/// log levels, context management, and debugging capabilities.
library;

import 'dart:io';

/// Log level enumeration
enum LogLevel {
  /// Detailed debug information
  debug(0),

  /// General information
  info(1),

  /// Warning messages
  warn(2),

  /// Error messages
  error(3),

  /// Critical errors only
  fatal(4);

  /// Create log level from integer value
  static LogLevel fromInt(int value) {
    switch (value) {
      case 0:
        return LogLevel.debug;
      case 1:
        return LogLevel.info;
      case 2:
        return LogLevel.warn;
      case 3:
        return LogLevel.error;
      case 4:
        return LogLevel.fatal;
      default:
        return LogLevel.info;
    }
  }

  const LogLevel(this.value);

  /// Numeric value for comparison
  final int value;
}

/// Log entry structure
class LogEntry {
  /// Create a log entry
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.logger,
    this.context,
    this.error,
    this.stackTrace,
  });

  /// Timestamp when the log entry was created
  final DateTime timestamp;

  /// Log level
  final LogLevel level;

  /// Log message
  final String message;

  /// Logger name that created this entry
  final String logger;

  /// Additional context information
  final Map<String, dynamic>? context;

  /// Error object if this is an error log
  final Object? error;

  /// Stack trace if this is an error log
  final StackTrace? stackTrace;

  /// Format the log entry as a string
  String format() {
    final buffer = StringBuffer();

    // Timestamp
    buffer.write('[${timestamp.toIso8601String()}] ');

    // Level
    buffer.write('[${level.name.toUpperCase()}] ');

    // Logger name
    buffer.write('[$logger] ');

    // Message
    buffer.write(message);

    // Context
    if (context != null && context!.isNotEmpty) {
      buffer.write(' | Context: ');
      buffer
          .write(context!.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }

    // Error
    if (error != null) {
      buffer.write(' | Error: $error');
    }

    // Stack trace
    if (stackTrace != null) {
      buffer.write(
          ' | Stack: ${stackTrace.toString().split('\n').take(3).join(' -> ')}');
    }

    return buffer.toString();
  }
}

/// Log output interface
abstract class LogOutput {
  /// Write a log entry
  void write(LogEntry entry);

  /// Flush any pending logs
  void flush();

  /// Close the output
  void close();
}

/// Console log output
class ConsoleLogOutput implements LogOutput {
  /// Create console output with optional color support
  ConsoleLogOutput({this.useColors = true});

  /// Whether to use ANSI color codes
  final bool useColors;

  static const _colorReset = '\x1B[0m';
  static const _colorRed = '\x1B[31m';
  static const _colorYellow = '\x1B[33m';
  static const _colorBlue = '\x1B[34m';
  static const _colorGray = '\x1B[90m';

  @override
  void write(LogEntry entry) {
    final formatted = entry.format();

    if (useColors) {
      final color = switch (entry.level) {
        LogLevel.debug => _colorGray,
        LogLevel.info => _colorBlue,
        LogLevel.warn => _colorYellow,
        LogLevel.error => _colorRed,
        LogLevel.fatal => _colorRed,
      };

      print('$color$formatted$_colorReset');
    } else {
      print(formatted);
    }
  }

  @override
  void flush() {
    // Console output is immediate
  }

  @override
  void close() {
    // Nothing to close for console
  }
}

/// File log output
class FileLogOutput implements LogOutput {
  /// Create file output
  FileLogOutput(this.filePath) : _file = File(filePath);

  /// Path to the log file
  final String filePath;

  /// File handle
  final File _file;

  /// Cached IOSink for writing
  IOSink? _sink;

  /// Get or create the IOSink
  IOSink get _output {
    _sink ??= _file.openWrite(mode: FileMode.append);
    return _sink!;
  }

  @override
  void write(LogEntry entry) {
    _output.writeln(entry.format());
  }

  @override
  void flush() {
    _sink?.flush();
  }

  @override
  void close() {
    _sink?.close();
    _sink = null;
  }
}

/// Combined log output that writes to multiple outputs
class MultiLogOutput implements LogOutput {
  /// Create multi-output with list of outputs
  MultiLogOutput(this.outputs);

  /// List of outputs to write to
  final List<LogOutput> outputs;

  @override
  void write(LogEntry entry) {
    for (final output in outputs) {
      output.write(entry);
    }
  }

  @override
  void flush() {
    for (final output in outputs) {
      output.flush();
    }
  }

  @override
  void close() {
    for (final output in outputs) {
      output.close();
    }
  }
}

/// Logger configuration
class LoggerConfig {
  /// Create logger configuration
  const LoggerConfig({
    this.level = LogLevel.info,
    this.output,
    this.includeContext = true,
    this.includeStackTrace = true,
    this.maxContextLength = 1000,
  });

  /// Default configuration
  static const LoggerConfig defaultConfig = LoggerConfig();

  /// Minimum log level to output
  final LogLevel level;

  /// Log output destination
  final LogOutput? output;

  /// Whether to include context in logs
  final bool includeContext;

  /// Whether to include stack traces in error logs
  final bool includeStackTrace;

  /// Maximum length of context strings
  final int maxContextLength;
}

/// Main logger class
class AnchorLogger {
  /// Create logger with name and configuration
  AnchorLogger(this.name, {LoggerConfig? config});

  /// Logger name
  final String name;

  /// Default console output
  static final _defaultOutput = ConsoleLogOutput();

  /// Global logger configuration
  static LoggerConfig _globalConfig = LoggerConfig.defaultConfig;

  /// Global logger registry
  static final Map<String, AnchorLogger> _loggers = {};

  /// Get logger by name
  static AnchorLogger getLogger(String name) {
    return _loggers.putIfAbsent(name, () => AnchorLogger(name));
  }

  /// Configure global logging
  static void configure(LoggerConfig config) {
    _globalConfig = config;

    // Update existing loggers
    for (final logger in _loggers.values) {
      logger._updateConfig(config);
    }
  }

  /// Disable all logging
  static void disable() {
    configure(const LoggerConfig(level: LogLevel.fatal));
  }

  /// Enable debug logging
  static void enableDebug() {
    configure(const LoggerConfig(level: LogLevel.debug));
  }

  /// Set log level
  static void setLevel(LogLevel level) {
    configure(LoggerConfig(level: level));
  }

  /// Update configuration
  void _updateConfig(LoggerConfig config) {
    // Configuration is immutable, so we use the global config
  }

  /// Get effective configuration
  LoggerConfig get _effectiveConfig => _globalConfig;

  /// Get effective output
  LogOutput get _effectiveOutput => _effectiveConfig.output ?? _defaultOutput;

  /// Check if level is enabled
  bool isEnabled(LogLevel level) {
    return level.value >= _effectiveConfig.level.value;
  }

  /// Log a message at the specified level
  void log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isEnabled(level)) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      logger: name,
      context: _effectiveConfig.includeContext ? context : null,
      error: error,
      stackTrace: _effectiveConfig.includeStackTrace ? stackTrace : null,
    );

    _effectiveOutput.write(entry);
  }

  /// Log debug message
  void debug(String message, {Map<String, dynamic>? context}) {
    log(LogLevel.debug, message, context: context);
  }

  /// Log info message
  void info(String message, {Map<String, dynamic>? context}) {
    log(LogLevel.info, message, context: context);
  }

  /// Log warning message
  void warn(String message, {Map<String, dynamic>? context}) {
    log(LogLevel.warn, message, context: context);
  }

  /// Log error message
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(LogLevel.error, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Log fatal message
  void fatal(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(LogLevel.fatal, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Log transaction details
  void logTransaction(
    String txSignature, {
    String? programId,
    String? instruction,
    Map<String, dynamic>? accounts,
    Duration? duration,
    bool success = true,
  }) {
    final context = <String, dynamic>{
      'transaction': txSignature,
      'success': success,
    };

    if (programId != null) context['programId'] = programId;
    if (instruction != null) context['instruction'] = instruction;
    if (accounts != null) context['accounts'] = accounts;
    if (duration != null) context['duration'] = '${duration.inMilliseconds}ms';

    if (success) {
      info('Transaction completed', context: context);
    } else {
      error('Transaction failed', context: context);
    }
  }

  /// Log RPC call details
  void logRpcCall(
    String method, {
    Map<String, dynamic>? params,
    Duration? duration,
    bool success = true,
    String? error,
  }) {
    final context = <String, dynamic>{
      'method': method,
      'success': success,
    };

    if (params != null) context['params'] = params;
    if (duration != null) context['duration'] = '${duration.inMilliseconds}ms';
    if (error != null) context['error'] = error;

    if (success) {
      debug('RPC call completed', context: context);
    } else {
      warn('RPC call failed', context: context);
    }
  }

  /// Log account operation
  void logAccountOperation(
    String operation,
    String accountAddress, {
    String? programId,
    Map<String, dynamic>? metadata,
    bool success = true,
  }) {
    final context = <String, dynamic>{
      'operation': operation,
      'account': accountAddress,
      'success': success,
    };

    if (programId != null) context['programId'] = programId;
    if (metadata != null) context.addAll(metadata);

    if (success) {
      info('Account operation completed', context: context);
    } else {
      error('Account operation failed', context: context);
    }
  }

  /// Log program error with enhanced context
  void logProgramError(
    String programId,
    int errorCode,
    String message, {
    String? instruction,
    List<String>? logs,
    Map<String, dynamic>? accounts,
  }) {
    final context = <String, dynamic>{
      'programId': programId,
      'errorCode': errorCode,
    };

    if (instruction != null) context['instruction'] = instruction;
    if (logs != null) context['logs'] = logs;
    if (accounts != null) context['accounts'] = accounts;

    error('Program error: $message', context: context);
  }

  /// Log performance metrics
  void logPerformance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metrics,
  }) {
    final context = <String, dynamic>{
      'operation': operation,
      'duration': '${duration.inMilliseconds}ms',
    };

    if (metrics != null) context.addAll(metrics);

    info('Performance metric', context: context);
  }
}

/// Specialized loggers for different components
class AnchorLoggers {
  /// Program logger
  static final AnchorLogger program = AnchorLogger.getLogger('program');

  /// Account logger
  static final AnchorLogger account = AnchorLogger.getLogger('account');

  /// Transaction logger
  static final AnchorLogger transaction = AnchorLogger.getLogger('transaction');

  /// RPC logger
  static final AnchorLogger rpc = AnchorLogger.getLogger('rpc');

  /// Error logger
  static final AnchorLogger error = AnchorLogger.getLogger('error');

  /// Performance logger
  static final AnchorLogger performance = AnchorLogger.getLogger('performance');

  /// Event logger
  static final AnchorLogger event = AnchorLogger.getLogger('event');

  /// IDL logger
  static final AnchorLogger idl = AnchorLogger.getLogger('idl');
}

/// Logging utilities
class LoggingUtils {
  /// Sanitize sensitive data from context
  static Map<String, dynamic> sanitizeContext(Map<String, dynamic> context) {
    final sanitized = <String, dynamic>{};

    for (final entry in context.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // Sanitize sensitive keys
      if (key.contains('private') ||
          key.contains('secret') ||
          key.contains('key') ||
          key.contains('password') ||
          key.contains('token')) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }

  /// Truncate long strings in context
  static Map<String, dynamic> truncateContext(
    Map<String, dynamic> context, {
    int maxLength = 1000,
  }) {
    final truncated = <String, dynamic>{};

    for (final entry in context.entries) {
      final value = entry.value;

      if (value is String && value.length > maxLength) {
        truncated[entry.key] = '${value.substring(0, maxLength)}...';
      } else {
        truncated[entry.key] = value;
      }
    }

    return truncated;
  }

  /// Format duration for logging
  static String formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inSeconds < 60) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
    } else {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
  }

  /// Format bytes for logging
  static String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}
