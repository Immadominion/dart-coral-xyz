/// Error Recovery and Retry System for Production-Ready Error Handling
///
/// This module provides sophisticated error recovery mechanisms including
/// retry strategies, circuit breakers, and fallback handling.
library;

import 'dart:async';
import 'dart:math';
import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/error/error_context.dart';
import 'package:coral_xyz_anchor/src/error/anchor_logging.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Retry strategy interface
abstract class RetryStrategy {
  /// Calculate delay before next retry
  Duration calculateDelay(int attemptNumber);

  /// Check if retry should be attempted
  bool shouldRetry(int attemptNumber, Object error);

  /// Maximum number of retry attempts
  int get maxAttempts;
}

/// Exponential backoff retry strategy
class ExponentialBackoffStrategy implements RetryStrategy {
  /// Create exponential backoff strategy
  const ExponentialBackoffStrategy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitter = true,
  });

  @override
  final int maxAttempts;

  /// Base delay for first retry
  final Duration baseDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Delay multiplier for each retry
  final double multiplier;

  /// Whether to add random jitter
  final bool jitter;

  @override
  Duration calculateDelay(int attemptNumber) {
    var delay = baseDelay.inMilliseconds * pow(multiplier, attemptNumber - 1);

    if (jitter) {
      // Add ±25% jitter
      final jitterAmount = delay * 0.25;
      final random = Random();
      delay += (random.nextDouble() - 0.5) * 2 * jitterAmount;
    }

    return Duration(
      milliseconds: min(delay.round(), maxDelay.inMilliseconds),
    );
  }

  @override
  bool shouldRetry(int attemptNumber, Object error) {
    if (attemptNumber >= maxAttempts) return false;

    // Don't retry certain error types
    if (error is AnchorError) {
      final errorCode = error.error.errorCode.number;
      // Don't retry validation errors (3000-3999)
      if (errorCode >= 3000 && errorCode < 4000) return false;
      // Don't retry constraint errors (2000-2999)
      if (errorCode >= 2000 && errorCode < 3000) return false;
    }

    return true;
  }
}

/// Linear backoff retry strategy
class LinearBackoffStrategy implements RetryStrategy {
  /// Create linear backoff strategy
  const LinearBackoffStrategy({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
  });

  @override
  final int maxAttempts;

  /// Fixed delay between retries
  final Duration delay;

  @override
  Duration calculateDelay(int attemptNumber) => delay;

  @override
  bool shouldRetry(int attemptNumber, Object error) {
    return attemptNumber < maxAttempts;
  }
}

/// Immediate retry strategy (no delay)
class ImmediateRetryStrategy implements RetryStrategy {
  /// Create immediate retry strategy
  const ImmediateRetryStrategy({this.maxAttempts = 3});

  @override
  final int maxAttempts;

  @override
  Duration calculateDelay(int attemptNumber) => Duration.zero;

  @override
  bool shouldRetry(int attemptNumber, Object error) {
    return attemptNumber < maxAttempts;
  }
}

/// Circuit breaker states
enum CircuitBreakerState {
  /// Circuit is closed, allowing all requests
  closed,

  /// Circuit is open, rejecting all requests
  open,

  /// Circuit is half-open, allowing limited requests
  halfOpen,
}

/// Circuit breaker for preventing cascading failures
class CircuitBreaker {
  /// Create circuit breaker
  CircuitBreaker({
    this.failureThreshold = 5,
    this.recoveryTimeout = const Duration(minutes: 1),
    this.halfOpenMaxCalls = 3,
  });

  /// Number of failures before opening circuit
  final int failureThreshold;

  /// Time to wait before trying to recover
  final Duration recoveryTimeout;

  /// Maximum calls allowed in half-open state
  final int halfOpenMaxCalls;

  /// Current state
  CircuitBreakerState _state = CircuitBreakerState.closed;

  /// Failure count
  int _failureCount = 0;

  /// Last failure time
  DateTime? _lastFailureTime;

  /// Half-open call count
  int _halfOpenCalls = 0;

  /// Get current state
  CircuitBreakerState get state => _state;

  /// Execute operation through circuit breaker
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitBreakerState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitBreakerState.halfOpen;
        _halfOpenCalls = 0;
        AnchorLogging.logPerformanceMetric(
          operation: 'circuit_breaker_half_open',
          duration: Duration.zero,
          context: {'previous_failures': _failureCount},
        );
      } else {
        throw CircuitBreakerOpenException(
          'Circuit breaker is open. Last failure: $_lastFailureTime',
        );
      }
    }

    if (_state == CircuitBreakerState.halfOpen) {
      if (_halfOpenCalls >= halfOpenMaxCalls) {
        throw CircuitBreakerOpenException(
          'Circuit breaker half-open limit exceeded',
        );
      }
      _halfOpenCalls++;
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure();
      rethrow;
    }
  }

  /// Check if should attempt reset
  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return false;
    return DateTime.now().difference(_lastFailureTime!) >= recoveryTimeout;
  }

  /// Handle successful operation
  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _halfOpenCalls = 0;

    AnchorLogging.logPerformanceMetric(
      operation: 'circuit_breaker_success',
      duration: Duration.zero,
    );
  }

  /// Handle failed operation
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.open;
      AnchorLogging.logPerformanceMetric(
        operation: 'circuit_breaker_reopen',
        duration: Duration.zero,
        context: {'failure_count': _failureCount},
      );
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      AnchorLogging.logPerformanceMetric(
        operation: 'circuit_breaker_open',
        duration: Duration.zero,
        context: {'failure_count': _failureCount},
      );
    }
  }

  /// Reset circuit breaker manually
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _halfOpenCalls = 0;
  }

  /// Get circuit breaker stats
  Map<String, dynamic> getStats() => {
        'state': _state.name,
        'failure_count': _failureCount,
        'last_failure_time': _lastFailureTime?.toIso8601String(),
        'half_open_calls': _halfOpenCalls,
      };
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException implements Exception {
  /// Create circuit breaker open exception
  const CircuitBreakerOpenException(this.message);

  /// Error message
  final String message;

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

/// Fallback handler interface
abstract class FallbackHandler<T> {
  /// Handle fallback when operation fails
  Future<T> handleFallback(Object error, StackTrace stackTrace);
}

/// Error recovery executor with comprehensive retry and fallback handling
class ErrorRecoveryExecutor {
  /// Create error recovery executor
  ErrorRecoveryExecutor({
    this.retryStrategy = const ExponentialBackoffStrategy(),
    this.circuitBreaker,
    this.timeout,
  });

  /// Retry strategy to use
  final RetryStrategy retryStrategy;

  /// Circuit breaker for preventing cascading failures
  final CircuitBreaker? circuitBreaker;

  /// Timeout for operations
  final Duration? timeout;

  /// Execute operation with error recovery
  Future<T> execute<T>({
    required Future<T> Function() operation,
    required String operationName,
    FallbackHandler<T>? fallbackHandler,
    ErrorContext? context,
    bool enableRetry = true,
    bool enableCircuitBreaker = true,
  }) async {
    final startTime = DateTime.now();
    Object? lastError;
    StackTrace? lastStackTrace;

    // Wrap operation with circuit breaker if enabled
    Future<T> wrappedOperation() async {
      if (enableCircuitBreaker && circuitBreaker != null) {
        return circuitBreaker!.execute(operation);
      } else {
        return operation();
      }
    }

    // Add timeout if specified
    Future<T> timedOperation() async {
      if (timeout != null) {
        return wrappedOperation().timeout(timeout!);
      } else {
        return wrappedOperation();
      }
    }

    int attemptNumber = 0;

    while (true) {
      attemptNumber++;

      try {
        AnchorLogging.logMethodCall(
          methodName: operationName,
          programId: context?.programId ??
              PublicKey.fromBase58('11111111111111111111111111111111'),
          context: {
            'attempt': attemptNumber,
            'max_attempts': retryStrategy.maxAttempts,
            'operation_type': 'error_recovery',
          },
        );

        final result = await timedOperation();

        // Log successful recovery if this wasn't the first attempt
        if (attemptNumber > 1) {
          final totalDuration = DateTime.now().difference(startTime);
          AnchorLogging.logPerformanceMetric(
            operation: 'error_recovery_success',
            duration: totalDuration,
            context: {
              'operation_name': operationName,
              'attempts': attemptNumber,
              'final_attempt': attemptNumber,
            },
          );
        }

        return result;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        // Log the error
        AnchorLogging.logError(
          error: error,
          operation: operationName,
          programId: context?.programId,
          transactionSignature: context?.transactionSignature,
          stackTrace: stackTrace,
          context: {
            'attempt': attemptNumber,
            'max_attempts': retryStrategy.maxAttempts,
            'operation_type': 'error_recovery',
          },
        );

        // Check if we should retry
        if (!enableRetry || !retryStrategy.shouldRetry(attemptNumber, error)) {
          break;
        }

        // Calculate delay and wait
        final delay = retryStrategy.calculateDelay(attemptNumber);
        if (delay > Duration.zero) {
          AnchorLogging.logPerformanceMetric(
            operation: 'retry_delay',
            duration: delay,
            context: {
              'operation_name': operationName,
              'attempt': attemptNumber,
            },
          );

          await Future<void>.delayed(delay);
        }
      }
    }

    // All retries failed, try fallback if available
    if (fallbackHandler != null) {
      try {
        AnchorLogging.logMethodCall(
          methodName: '${operationName}_fallback',
          programId: context?.programId ??
              PublicKey.fromBase58('11111111111111111111111111111111'),
          context: {
            'attempts': attemptNumber,
            'operation_type': 'fallback',
          },
        );

        final fallbackResult = await fallbackHandler.handleFallback(
          lastError,
          lastStackTrace,
        );

        final totalDuration = DateTime.now().difference(startTime);
        AnchorLogging.logPerformanceMetric(
          operation: 'fallback_success',
          duration: totalDuration,
          context: {
            'operation_name': operationName,
            'attempts': attemptNumber,
          },
        );

        return fallbackResult;
      } catch (fallbackError, fallbackStackTrace) {
        AnchorLogging.logError(
          error: fallbackError,
          operation: '${operationName}_fallback',
          programId: context?.programId,
          transactionSignature: context?.transactionSignature,
          stackTrace: fallbackStackTrace,
          context: {
            'original_error': lastError.toString(),
            'attempts': attemptNumber,
            'operation_type': 'fallback_failure',
          },
        );

        // Throw the fallback error as it's more recent
        throw fallbackError;
      }
    }

    // No fallback available, throw the last error
    final totalDuration = DateTime.now().difference(startTime);
    AnchorLogging.logPerformanceMetric(
      operation: 'error_recovery_failure',
      duration: totalDuration,
      context: {
        'operation_name': operationName,
        'attempts': attemptNumber,
      },
    );

    throw lastError;
  }
}

/// Utility class for creating common error recovery configurations
class ErrorRecoveryConfig {
  /// Default configuration for network operations
  static ErrorRecoveryExecutor networkOperations() {
    return ErrorRecoveryExecutor(
      retryStrategy: const ExponentialBackoffStrategy(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 10),
      ),
      circuitBreaker: CircuitBreaker(
        failureThreshold: 5,
        recoveryTimeout: const Duration(minutes: 1),
      ),
      timeout: const Duration(seconds: 30),
    );
  }

  /// Configuration for RPC operations
  static ErrorRecoveryExecutor rpcOperations() {
    return ErrorRecoveryExecutor(
      retryStrategy: const ExponentialBackoffStrategy(
        maxAttempts: 2,
        baseDelay: Duration(milliseconds: 200),
        maxDelay: Duration(seconds: 5),
      ),
      circuitBreaker: CircuitBreaker(
        failureThreshold: 3,
        recoveryTimeout: const Duration(seconds: 30),
      ),
      timeout: const Duration(seconds: 15),
    );
  }

  /// Configuration for account fetching operations
  static ErrorRecoveryExecutor accountFetching() {
    return ErrorRecoveryExecutor(
      retryStrategy: const LinearBackoffStrategy(
        maxAttempts: 2,
        delay: Duration(milliseconds: 100),
      ),
      timeout: const Duration(seconds: 10),
    );
  }

  /// Configuration for transaction operations
  static ErrorRecoveryExecutor transactionOperations() {
    return ErrorRecoveryExecutor(
      retryStrategy: const ExponentialBackoffStrategy(
        maxAttempts: 3,
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 30),
      ),
      timeout: const Duration(seconds: 60),
    );
  }

  /// Configuration for critical operations (no retries)
  static ErrorRecoveryExecutor criticalOperations() {
    return ErrorRecoveryExecutor(
      retryStrategy: const ImmediateRetryStrategy(maxAttempts: 1),
      timeout: const Duration(seconds: 5),
    );
  }
}
