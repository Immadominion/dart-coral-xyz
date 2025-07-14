/// Enhanced Error Context System for Production-Ready Error Handling
///
/// This module provides comprehensive error context management with detailed
/// debugging information, error categorization, and logging integration.
library;

import 'dart:convert';
import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/utils/logger.dart';

/// Enhanced error context for comprehensive error reporting
class ErrorContext {
  /// Create enhanced error context
  const ErrorContext({
    required this.operation,
    required this.timestamp,
    this.transactionSignature,
    this.programId,
    this.accountAddresses,
    this.instructionIndex,
    this.stackTrace,
    this.userAgent,
    this.environment,
    this.networkEndpoint,
    this.commitmentLevel,
    this.additionalContext,
  });

  /// The operation being performed when the error occurred
  final String operation;

  /// When the error occurred
  final DateTime timestamp;

  /// Transaction signature if available
  final String? transactionSignature;

  /// Program ID involved in the error
  final PublicKey? programId;

  /// List of account addresses involved
  final List<PublicKey>? accountAddresses;

  /// Instruction index if this is an instruction error
  final int? instructionIndex;

  /// Stack trace at the time of error
  final String? stackTrace;

  /// User agent information
  final String? userAgent;

  /// Environment information (devnet, testnet, mainnet-beta)
  final String? environment;

  /// Network endpoint being used
  final String? networkEndpoint;

  /// Commitment level being used
  final String? commitmentLevel;

  /// Additional context information
  final Map<String, dynamic>? additionalContext;

  /// Convert to JSON for logging and debugging
  Map<String, dynamic> toJson() => {
        'operation': operation,
        'timestamp': timestamp.toIso8601String(),
        'transactionSignature': transactionSignature,
        'programId': programId?.toBase58(),
        'accountAddresses': accountAddresses?.map((a) => a.toBase58()).toList(),
        'instructionIndex': instructionIndex,
        'stackTrace': stackTrace,
        'userAgent': userAgent,
        'environment': environment,
        'networkEndpoint': networkEndpoint,
        'commitmentLevel': commitmentLevel,
        'additionalContext': additionalContext,
      };

  /// Create from JSON
  factory ErrorContext.fromJson(Map<String, dynamic> json) {
    return ErrorContext(
      operation: json['operation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      transactionSignature: json['transactionSignature'] as String?,
      programId: json['programId'] != null
          ? PublicKey.fromBase58(json['programId'] as String)
          : null,
      accountAddresses: (json['accountAddresses'] as List<dynamic>?)
          ?.map((a) => PublicKey.fromBase58(a as String))
          .toList(),
      instructionIndex: json['instructionIndex'] as int?,
      stackTrace: json['stackTrace'] as String?,
      userAgent: json['userAgent'] as String?,
      environment: json['environment'] as String?,
      networkEndpoint: json['networkEndpoint'] as String?,
      commitmentLevel: json['commitmentLevel'] as String?,
      additionalContext: json['additionalContext'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Error Context:');
    buffer.writeln('  Operation: $operation');
    buffer.writeln('  Timestamp: ${timestamp.toIso8601String()}');

    if (transactionSignature != null) {
      buffer.writeln('  Transaction: $transactionSignature');
    }

    if (programId != null) {
      buffer.writeln('  Program ID: ${programId!.toBase58()}');
    }

    if (accountAddresses != null && accountAddresses!.isNotEmpty) {
      buffer.writeln('  Accounts:');
      for (final address in accountAddresses!) {
        buffer.writeln('    - ${address.toBase58()}');
      }
    }

    if (instructionIndex != null) {
      buffer.writeln('  Instruction Index: $instructionIndex');
    }

    if (environment != null) {
      buffer.writeln('  Environment: $environment');
    }

    if (networkEndpoint != null) {
      buffer.writeln('  Endpoint: $networkEndpoint');
    }

    if (commitmentLevel != null) {
      buffer.writeln('  Commitment: $commitmentLevel');
    }

    if (additionalContext != null && additionalContext!.isNotEmpty) {
      buffer.writeln('  Additional Context:');
      for (final entry in additionalContext!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    return buffer.toString();
  }
}

/// Error severity levels for categorization
enum ErrorSeverity {
  /// Low severity - informational errors
  low,

  /// Medium severity - warnings and recoverable errors
  medium,

  /// High severity - critical errors that need attention
  high,

  /// Critical severity - system-breaking errors
  critical,
}

/// Error category for better organization
enum ErrorCategory {
  /// Network and connectivity errors
  network,

  /// Account validation errors
  account,

  /// Instruction execution errors
  instruction,

  /// Program logic errors
  program,

  /// Constraint validation errors
  constraint,

  /// Serialization/deserialization errors
  serialization,

  /// IDL parsing errors
  idl,

  /// Event system errors
  event,

  /// Transaction processing errors
  transaction,

  /// Authentication/authorization errors
  auth,

  /// Configuration errors
  config,

  /// Unknown/unclassified errors
  unknown,
}

/// Enhanced error reporting with comprehensive context
class ErrorReporter {
  /// Create error reporter with configuration
  ErrorReporter({
    this.enableLogging = true,
    this.enableMetrics = false,
    this.enableStackTraces = true,
    this.maxContextSize = 10000,
    this.logger,
  });

  /// Whether to enable automatic logging
  final bool enableLogging;

  /// Whether to enable metrics collection
  final bool enableMetrics;

  /// Whether to include stack traces
  final bool enableStackTraces;

  /// Maximum size of context data (in characters)
  final int maxContextSize;

  /// Logger instance for error reporting
  final AnchorLogger? logger;

  /// Get default error reporter instance
  static ErrorReporter? _instance;
  static ErrorReporter get instance => _instance ??= ErrorReporter();

  /// Configure the global error reporter
  static void configure({
    bool enableLogging = true,
    bool enableMetrics = false,
    bool enableStackTraces = true,
    int maxContextSize = 10000,
    AnchorLogger? logger,
  }) {
    _instance = ErrorReporter(
      enableLogging: enableLogging,
      enableMetrics: enableMetrics,
      enableStackTraces: enableStackTraces,
      maxContextSize: maxContextSize,
      logger: logger,
    );
  }

  /// Report an error with comprehensive context
  void reportError({
    required Object error,
    required ErrorSeverity severity,
    required ErrorCategory category,
    ErrorContext? context,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    if (enableLogging) {
      _logError(error, severity, category, context, stackTrace, additionalData);
    }

    if (enableMetrics) {
      _collectMetrics(error, severity, category, context);
    }
  }

  /// Log error with structured information
  void _logError(
    Object error,
    ErrorSeverity severity,
    ErrorCategory category,
    ErrorContext? context,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  ) {
    final effectiveLogger = logger ?? AnchorLoggers.error;

    final logContext = <String, dynamic>{
      'severity': severity.name,
      'category': category.name,
      'errorType': error.runtimeType.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (context != null) {
      logContext['context'] = _truncateContext(context.toJson());
    }

    if (additionalData != null) {
      logContext['additionalData'] = _truncateContext(additionalData);
    }

    switch (severity) {
      case ErrorSeverity.low:
        effectiveLogger.debug('Error occurred: $error', context: logContext);
        break;
      case ErrorSeverity.medium:
        effectiveLogger.warn('Error occurred: $error', context: logContext);
        break;
      case ErrorSeverity.high:
        effectiveLogger.error('Error occurred: $error',
            context: logContext, error: error, stackTrace: stackTrace);
        break;
      case ErrorSeverity.critical:
        effectiveLogger.fatal('Critical error occurred: $error',
            context: logContext, error: error, stackTrace: stackTrace);
        break;
    }
  }

  /// Collect error metrics for monitoring
  void _collectMetrics(
    Object error,
    ErrorSeverity severity,
    ErrorCategory category,
    ErrorContext? context,
  ) {
    // This would integrate with your metrics system
    // For now, we'll just log metric information
    final metricsLogger = logger ?? AnchorLoggers.performance;

    metricsLogger.info('Error metric', context: {
      'metric_type': 'error_count',
      'error_type': error.runtimeType.toString(),
      'severity': severity.name,
      'category': category.name,
      'environment': context?.environment ?? 'unknown',
      'operation': context?.operation ?? 'unknown',
    });
  }

  /// Truncate context to prevent excessive logging
  Map<String, dynamic> _truncateContext(Map<String, dynamic> context) {
    final jsonStr = jsonEncode(context);
    if (jsonStr.length <= maxContextSize) {
      return context;
    }

    // If too large, provide a summary
    return {
      'truncated': true,
      'original_size': jsonStr.length,
      'max_size': maxContextSize,
      'summary': context.keys.take(10).join(', '),
    };
  }
}

/// Enhanced error builder for creating comprehensive error objects
class ErrorBuilder {
  /// Create error builder
  ErrorBuilder(this.errorType);

  /// Type of error being built
  final String errorType;

  /// Error context
  ErrorContext? _context;

  /// Error severity
  ErrorSeverity _severity = ErrorSeverity.medium;

  /// Error category
  ErrorCategory _category = ErrorCategory.unknown;

  /// Error message
  String? _message;

  /// Error code
  int? _code;

  /// Additional data
  Map<String, dynamic>? _additionalData;

  /// Set error context
  ErrorBuilder withContext(ErrorContext context) {
    _context = context;
    return this;
  }

  /// Set error severity
  ErrorBuilder withSeverity(ErrorSeverity severity) {
    _severity = severity;
    return this;
  }

  /// Set error category
  ErrorBuilder withCategory(ErrorCategory category) {
    _category = category;
    return this;
  }

  /// Set error message
  ErrorBuilder withMessage(String message) {
    _message = message;
    return this;
  }

  /// Set error code
  ErrorBuilder withCode(int code) {
    _code = code;
    return this;
  }

  /// Add additional data
  ErrorBuilder withData(Map<String, dynamic> data) {
    _additionalData = {...?_additionalData, ...data};
    return this;
  }

  /// Build the error and report it
  AnchorError build() {
    final error = AnchorError(
      error: ErrorInfo(
        errorCode: ErrorCode(
          code: errorType,
          number: _code ?? 0,
        ),
        errorMessage: _message ?? 'An error occurred',
        origin: _context?.programId != null
            ? Origin.accountName(_context!.programId!.toBase58())
            : null,
      ),
      errorLogs: [],
      logs: [],
    );

    // Report the error
    ErrorReporter.instance.reportError(
      error: error,
      severity: _severity,
      category: _category,
      context: _context,
      additionalData: _additionalData,
    );

    return error;
  }
}

/// Utility functions for error handling
class ErrorHandlingUtils {
  /// Categorize error by its type
  static ErrorCategory categorizeError(Object error) {
    if (error is AnchorError) {
      final errorCode = error.error.errorCode.number;

      // Categorize by error code ranges
      if (errorCode >= 100 && errorCode < 200) {
        return ErrorCategory.instruction;
      } else if (errorCode >= 1000 && errorCode < 2000) {
        return ErrorCategory.idl;
      } else if (errorCode >= 2000 && errorCode < 3000) {
        return ErrorCategory.constraint;
      } else if (errorCode >= 3000 && errorCode < 4000) {
        return ErrorCategory.account;
      } else if (errorCode >= 5000 && errorCode < 6000) {
        return ErrorCategory.network;
      }
    }

    // Categorize by error type
    final errorType = error.runtimeType.toString();
    if (errorType.contains('Network') || errorType.contains('Connection')) {
      return ErrorCategory.network;
    } else if (errorType.contains('Account')) {
      return ErrorCategory.account;
    } else if (errorType.contains('Instruction')) {
      return ErrorCategory.instruction;
    } else if (errorType.contains('Program')) {
      return ErrorCategory.program;
    } else if (errorType.contains('Constraint')) {
      return ErrorCategory.constraint;
    } else if (errorType.contains('Serialization')) {
      return ErrorCategory.serialization;
    } else if (errorType.contains('Idl') || errorType.contains('IDL')) {
      return ErrorCategory.idl;
    } else if (errorType.contains('Event')) {
      return ErrorCategory.event;
    } else if (errorType.contains('Transaction')) {
      return ErrorCategory.transaction;
    } else if (errorType.contains('Auth')) {
      return ErrorCategory.auth;
    } else if (errorType.contains('Config')) {
      return ErrorCategory.config;
    }

    return ErrorCategory.unknown;
  }

  /// Determine error severity based on error type and context
  static ErrorSeverity determineSeverity(Object error, ErrorContext? context) {
    if (error is AnchorError) {
      final errorCode = error.error.errorCode.number;

      // Critical errors
      if (errorCode >= 4000 && errorCode < 5000) {
        return ErrorSeverity.critical;
      }

      // High severity errors
      if (errorCode >= 3000 && errorCode < 4000) {
        return ErrorSeverity.high;
      }

      // Medium severity errors
      if (errorCode >= 2000 && errorCode < 3000) {
        return ErrorSeverity.medium;
      }
    }

    // Network errors are often high severity
    if (error.runtimeType.toString().contains('Network')) {
      return ErrorSeverity.high;
    }

    // Default to medium severity
    return ErrorSeverity.medium;
  }

  /// Create error context from current execution state
  static ErrorContext createContext({
    required String operation,
    String? transactionSignature,
    PublicKey? programId,
    List<PublicKey>? accountAddresses,
    int? instructionIndex,
    String? environment,
    String? networkEndpoint,
    String? commitmentLevel,
    Map<String, dynamic>? additionalContext,
  }) {
    return ErrorContext(
      operation: operation,
      timestamp: DateTime.now(),
      transactionSignature: transactionSignature,
      programId: programId,
      accountAddresses: accountAddresses,
      instructionIndex: instructionIndex,
      stackTrace: StackTrace.current.toString(),
      environment: environment,
      networkEndpoint: networkEndpoint,
      commitmentLevel: commitmentLevel,
      additionalContext: additionalContext,
    );
  }

  /// Extract program ID from error logs
  static PublicKey? extractProgramId(List<String> logs) {
    for (final log in logs) {
      final match = RegExp(r'Program ([A-Za-z0-9]{32,44})').firstMatch(log);
      if (match != null) {
        try {
          return PublicKey.fromBase58(match.group(1)!);
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  /// Extract transaction signature from error logs
  static String? extractTransactionSignature(List<String> logs) {
    for (final log in logs) {
      final match = RegExp(r'Transaction signature: ([A-Za-z0-9]{64,88})')
          .firstMatch(log);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Format error for user display
  static String formatUserError(Object error) {
    if (error is AnchorError) {
      return error.error.errorMessage;
    }

    return error.toString();
  }

  /// Format error for developer display
  static String formatDeveloperError(Object error) {
    if (error is AnchorError) {
      return error.toString();
    }

    return error.toString();
  }
}
