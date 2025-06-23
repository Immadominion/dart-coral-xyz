/// Standardized Error Handling Framework for Coral XYZ Anchor Dart SDK
///
/// This module provides a comprehensive error handling system that ensures
/// consistent error patterns, helpful error messages, and proper error
/// propagation throughout the SDK.
library;

import 'dart:async';
import 'dart:io';

/// Base exception for all Anchor-related errors.
///
/// All SDK exceptions should extend this base class to provide consistent
/// error handling and debugging information.
abstract class AnchorException implements Exception {
  /// Creates an [AnchorException] with the given [message] and optional
  /// [cause].
  const AnchorException(
    this.message, {
    this.cause,
    this.stackTrace,
    this.context,
  });

  /// Human-readable error message.
  final String message;

  /// The underlying cause of this exception, if any.
  final Object? cause;

  /// Stack trace from where this exception was created.
  final StackTrace? stackTrace;

  /// Additional context information for debugging.
  final Map<String, dynamic>? context;

  /// Error code for programmatic error handling.
  String get errorCode => runtimeType.toString();

  /// Whether this error indicates a retryable condition.
  bool get isRetryable => false;

  /// User-friendly error message suitable for display.
  String get userMessage => message;

  @override
  String toString() {
    final buffer = StringBuffer('$errorCode: $message');
    if (context != null && context!.isNotEmpty) {
      buffer.write('\nContext: $context');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }

  /// Creates a detailed error report for debugging.
  String toDetailedString() {
    final buffer = StringBuffer(toString());
    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when provider operations fail.
class ProviderException extends AnchorException {
  /// Creates a [ProviderException] with the given parameters.
  const ProviderException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.provider,
  });

  /// The provider that caused this exception.
  final String? provider;

  @override
  String get errorCode => 'PROVIDER_ERROR';

  @override
  bool get isRetryable => cause is SocketException || cause is TimeoutException;
}

/// Exception thrown when connection operations fail.
class ConnectionException extends AnchorException {
  /// Creates a [ConnectionException] with the given parameters.
  const ConnectionException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.endpoint,
    this.statusCode,
  });

  /// The endpoint that caused this exception.
  final String? endpoint;

  /// HTTP status code, if applicable.
  final int? statusCode;

  @override
  String get errorCode => 'CONNECTION_ERROR';

  @override
  bool get isRetryable => _isRetryableStatusCode(statusCode);

  bool _isRetryableStatusCode(int? code) {
    if (code == null) return true; // Network errors are generally retryable
    return code >= 500 || code == 429; // Server errors and rate limiting
  }

  @override
  String get userMessage {
    if (statusCode == 429) {
      return 'Service is temporarily busy. Please try again in a moment.';
    }
    if (statusCode != null && statusCode! >= 500) {
      return 'Service is temporarily unavailable. Please try again later.';
    }
    return 'Connection failed. Please check your internet connection.';
  }
}

/// Exception thrown when program operations fail.
class ProgramException extends AnchorException {
  /// Creates a [ProgramException] with the given parameters.
  const ProgramException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.programId,
    this.instructionName,
    this.anchorErrorCode,
  });

  /// The program ID that caused this exception.
  final String? programId;

  /// The instruction name that failed, if applicable.
  final String? instructionName;

  /// Anchor-specific error code from the program.
  final int? anchorErrorCode;

  @override
  String get errorCode => 'PROGRAM_ERROR';

  @override
  String get userMessage {
    if (anchorErrorCode != null) {
      return 'Program operation failed with code $anchorErrorCode';
    }
    return 'Program operation failed';
  }
}

/// Exception thrown when transaction operations fail.
class TransactionException extends AnchorException {
  /// Creates a [TransactionException] with the given parameters.
  const TransactionException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.signature,
    this.logs,
  });

  /// The transaction signature, if available.
  final String? signature;

  /// Transaction logs for debugging.
  final List<String>? logs;

  @override
  String get errorCode => 'TRANSACTION_ERROR';

  @override
  String get userMessage => 'Transaction failed to execute';
}

/// Exception thrown when serialization/deserialization fails.
class SerializationException extends AnchorException {
  /// Creates a [SerializationException] with the given parameters.
  const SerializationException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.dataType,
    this.operation,
  });

  /// The data type being serialized/deserialized.
  final String? dataType;

  /// The operation that failed (encode/decode).
  final String? operation;

  @override
  String get errorCode => 'SERIALIZATION_ERROR';

  @override
  String get userMessage => 'Data processing failed';
}

/// Exception thrown when validation fails.
class ValidationException extends AnchorException {
  /// Creates a [ValidationException] with the given parameters.
  const ValidationException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.field,
    this.value,
  });

  /// The field that failed validation.
  final String? field;

  /// The value that failed validation.
  final Object? value;

  @override
  String get errorCode => 'VALIDATION_ERROR';

  @override
  String get userMessage {
    if (field != null) {
      return 'Invalid value for $field';
    }
    return 'Validation failed';
  }
}

/// Generic network exception for compatibility.
class NetworkException implements Exception {
  /// Creates a [NetworkException] with the given [message].
  const NetworkException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Generic Anchor exception for cases that don't fit specific categories.
class GenericAnchorException extends AnchorException {
  /// Creates a [GenericAnchorException] with the given parameters.
  const GenericAnchorException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
  });

  @override
  String get errorCode => 'ANCHOR_ERROR';
}

/// Exception thrown when configuration is invalid.
class ConfigurationException extends AnchorException {
  /// Creates a [ConfigurationException] with the given parameters.
  const ConfigurationException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
    this.configKey,
  });

  /// The configuration key that is invalid.
  final String? configKey;

  @override
  String get errorCode => 'CONFIGURATION_ERROR';

  @override
  String get userMessage => 'Configuration error';
}

/// Error handler that provides consistent error processing.
class ErrorHandler {
  /// Creates an [ErrorHandler] with optional configuration.
  const ErrorHandler({
    this.enableDebugInfo = false,
    this.logErrors = true,
  });

  /// Whether to include debug information in error messages.
  final bool enableDebugInfo;

  /// Whether to log errors automatically.
  final bool logErrors;

  /// Handles an error and returns a processed error result.
  ErrorResult handleError(Object error, [StackTrace? stackTrace]) {
    if (logErrors) {
      _logError(error, stackTrace);
    }

    if (error is AnchorException) {
      return ErrorResult._(
        error: error,
        isRetryable: error.isRetryable,
        userMessage: error.userMessage,
        debugInfo: enableDebugInfo ? error.toDetailedString() : null,
      );
    }

    // Handle standard Dart exceptions
    if (error is ArgumentError) {
      return ErrorResult._(
        error: ValidationException(
          (error.message ?? 'Invalid argument').toString(),
          cause: error,
          stackTrace: stackTrace,
          context: {'invalidValue': error.invalidValue, 'name': error.name},
        ),
        isRetryable: false,
        userMessage: 'Invalid input provided',
        debugInfo: enableDebugInfo ? error.toString() : null,
      );
    }

    if (error is TimeoutException) {
      return ErrorResult._(
        error: ConnectionException(
          'Operation timed out',
          cause: error,
          stackTrace: stackTrace,
        ),
        isRetryable: true,
        userMessage: 'Request timed out. Please try again.',
        debugInfo: enableDebugInfo ? error.toString() : null,
      );
    }

    // Default handling for unknown errors
    return ErrorResult._(
      error: GenericAnchorException(
        'Unexpected error occurred',
        cause: error,
        stackTrace: stackTrace,
      ),
      isRetryable: false,
      userMessage: 'An unexpected error occurred',
      debugInfo: enableDebugInfo ? error.toString() : null,
    );
  }

  /// Wraps a function call with error handling.
  Future<T> wrapAsync<T>(
    Future<T> Function() operation, {
    String? operationName,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await operation();
    } on Exception catch (error, stackTrace) {
      final errorResult = handleError(error, stackTrace);

      // Add operation context if provided
      if (operationName != null || context != null) {
        final errorContext = <String, dynamic>{
          if (operationName != null) 'operation': operationName,
          if (context != null) ...context,
        };

        final anchorError = errorResult.error;
        throw GenericAnchorException(
          anchorError.message,
          cause: anchorError.cause,
          stackTrace: anchorError.stackTrace,
          context: {...?anchorError.context, ...errorContext},
        );
      }

      throw errorResult.error;
    }
  }

  /// Wraps a synchronous function call with error handling.
  T wrap<T>(
    T Function() operation, {
    String? operationName,
    Map<String, dynamic>? context,
  }) {
    try {
      return operation();
    } on Exception catch (error, stackTrace) {
      final errorResult = handleError(error, stackTrace);

      // Add operation context if provided
      if (operationName != null || context != null) {
        final errorContext = <String, dynamic>{
          if (operationName != null) 'operation': operationName,
          if (context != null) ...context,
        };

        final anchorError = errorResult.error;
        throw GenericAnchorException(
          anchorError.message,
          cause: anchorError.cause,
          stackTrace: anchorError.stackTrace,
          context: {...?anchorError.context, ...errorContext},
        );
      }

      throw errorResult.error;
    }
  }

  void _logError(Object error, StackTrace? stackTrace) {
    // In a real implementation, this would use a proper logging framework
    // For now, we'll use a simple approach that can be easily replaced
    // ignore: avoid_print
    print('ERROR: $error');
    if (stackTrace != null && enableDebugInfo) {
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
    }
  }
}

/// Result of error processing.
class ErrorResult {
  const ErrorResult._({
    required this.error,
    required this.isRetryable,
    required this.userMessage,
    this.debugInfo,
  });

  /// The processed error.
  final AnchorException error;

  /// Whether the operation can be retried.
  final bool isRetryable;

  /// User-friendly error message.
  final String userMessage;

  /// Debug information, if available.
  final String? debugInfo;
}

/// Utility functions for error handling.
class ErrorUtils {
  /// Validates that a value is not null.
  static void requireNonNull(Object? value, String name) {
    if (value == null) {
      throw ValidationException(
        'Required parameter $name cannot be null',
        field: name,
        value: value,
      );
    }
  }

  /// Validates that a string is not empty.
  static void requireNonEmpty(String? value, String name) {
    requireNonNull(value, name);
    if (value!.isEmpty) {
      throw ValidationException(
        'Required parameter $name cannot be empty',
        field: name,
        value: value,
      );
    }
  }

  /// Validates that a number is within a specified range.
  static void requireInRange(
    num value,
    num min,
    num max,
    String name,
  ) {
    if (value < min || value > max) {
      throw ValidationException(
        'Parameter $name must be between $min and $max, got $value',
        field: name,
        value: value,
        context: {'min': min, 'max': max},
      );
    }
  }

  /// Validates that a list is not empty.
  static void requireNonEmptyList<T>(List<T>? list, String name) {
    requireNonNull(list, name);
    if (list!.isEmpty) {
      throw ValidationException(
        'Required parameter $name cannot be empty',
        field: name,
        value: list,
      );
    }
  }

  /// Creates a retry policy for retryable errors.
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
    double backoffMultiplier = 2.0,
    bool Function(Object error)? isRetryable,
  }) async {
    var attempt = 0;
    var delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (error) {
        attempt++;

        final shouldRetry = isRetryable?.call(error) ??
            (error is AnchorException && error.isRetryable);

        if (!shouldRetry || attempt >= maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
  }
}

/// Global error handler instance.
const errorHandler = ErrorHandler();
