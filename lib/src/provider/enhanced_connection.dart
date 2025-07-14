/// Enhanced Connection class with retry and recovery mechanisms
///
/// This module provides robust connection management matching TypeScript's
/// sophisticated RPC handling with retry mechanisms, connection pooling,
/// and failure recovery capabilities.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/utils/rpc_errors.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';

/// Configuration for retry strategies
class RetryConfig {

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.backoffMultiplier = 2.0,
    this.enableJitter = true,
    this.jitterFactor = 0.1,
    this.retryableMethods = const {
      'getBalance',
      'getAccountInfo',
      'getLatestBlockhash',
      'getMultipleAccounts',
      'getProgramAccounts',
      'getMinimumBalanceForRentExemption',
      'getHealth',
      'getSlot',
      'getBlockHeight',
      'getEpochInfo',
      'getTokenAccountsByOwner',
      'simulateTransaction',
    },
    this.retryableStatusCodes = const {429, 500, 502, 503, 504},
  });
  /// Maximum number of retry attempts
  final int maxRetries;

  /// Base delay in milliseconds
  final int baseDelayMs;

  /// Maximum delay in milliseconds
  final int maxDelayMs;

  /// Exponential backoff multiplier
  final double backoffMultiplier;

  /// Whether to add jitter to delays
  final bool enableJitter;

  /// Jitter factor (0.0 to 1.0)
  final double jitterFactor;

  /// Methods that should be retried
  final Set<String> retryableMethods;

  /// HTTP status codes that should trigger retries
  final Set<int> retryableStatusCodes;
}

/// Circuit breaker states
enum CircuitBreakerState {
  closed, // Normal operation
  open, // Blocking requests
  halfOpen, // Testing if service is back
}

/// Circuit breaker configuration
class CircuitBreakerConfig {

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.recoveryTimeoutMs = 60000,
    this.successThreshold = 3,
    this.timeWindowMs = 60000,
  });
  /// Failure threshold to open circuit
  final int failureThreshold;

  /// Recovery timeout in milliseconds
  final int recoveryTimeoutMs;

  /// Number of successful calls to close circuit
  final int successThreshold;

  /// Time window for failure tracking in milliseconds
  final int timeWindowMs;
}

/// Circuit breaker for preventing cascading failures
class CircuitBreaker {

  CircuitBreaker(this._config);
  final CircuitBreakerConfig _config;
  CircuitBreakerState _state = CircuitBreakerState.closed;
  DateTime? _lastFailureTime;
  int _failureCount = 0;
  int _successCount = 0;
  final List<DateTime> _recentFailures = [];

  /// Current circuit breaker state
  CircuitBreakerState get state => _state;

  /// Set state for testing
  set stateForTesting(CircuitBreakerState state) => _state = state;

  /// Check if request should be allowed
  bool shouldAllowRequest() {
    _cleanupOldFailures();

    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        final now = DateTime.now();
        if (_lastFailureTime != null &&
            now.difference(_lastFailureTime!).inMilliseconds >=
                _config.recoveryTimeoutMs) {
          _state = CircuitBreakerState.halfOpen;
          _successCount = 0;
          return true;
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  /// Record successful request
  void recordSuccess() {
    _successCount++;
    if (_state == CircuitBreakerState.halfOpen &&
        _successCount >= _config.successThreshold) {
      _state = CircuitBreakerState.closed;
      _failureCount = 0;
      _recentFailures.clear();
    }
  }

  /// Record failed request
  void recordFailure() {
    final now = DateTime.now();
    _recentFailures.add(now);
    _lastFailureTime = now;
    _failureCount++;

    if (_state == CircuitBreakerState.closed &&
        _failureCount >= _config.failureThreshold) {
      _state = CircuitBreakerState.open;
    } else if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.open;
      _successCount = 0;
    }
  }

  /// Clean up old failures outside the time window
  void _cleanupOldFailures() {
    final cutoff =
        DateTime.now().subtract(Duration(milliseconds: _config.timeWindowMs));
    _recentFailures.removeWhere((failure) => failure.isBefore(cutoff));
    _failureCount = _recentFailures.length;
  }
}

/// Request deduplication and batching
class RequestDeduplicator {
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final Map<String, Timer> _timeouts = {};
  static const int _dedupTimeoutMs = 5000;

  /// Get or create request
  Future<Map<String, dynamic>> getOrCreateRequest(
    String key,
    Future<Map<String, dynamic>> Function() requestFactory,
  ) async {
    // Check if request is already pending
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!.future;
    }

    // Create new request
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[key] = completer;

    // Set timeout to clean up stale requests
    _timeouts[key] = Timer(const Duration(milliseconds: _dedupTimeoutMs), () {
      _pendingRequests.remove(key);
      _timeouts.remove(key);
      if (!completer.isCompleted) {
        completer
            .completeError(const TimeoutException('Request deduplication timeout'));
      }
    });

    try {
      final result = await requestFactory();
      _cleanup(key);
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    } catch (error) {
      _cleanup(key);
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      rethrow;
    }
  }

  void _cleanup(String key) {
    _pendingRequests.remove(key);
    _timeouts[key]?.cancel();
    _timeouts.remove(key);
  }

  /// Generate deduplication key for request
  static String generateKey(String method, List<dynamic> params) => '$method:${jsonEncode(params)}';
}

/// Enhanced Connection with retry, recovery, and health monitoring
class EnhancedConnection extends Connection {

  /// Create enhanced connection
  EnhancedConnection(
    super.endpoint, {
    super.config,
    RetryConfig? retryConfig,
    CircuitBreakerConfig? circuitBreakerConfig,
  })  : _retryConfig = retryConfig ?? const RetryConfig(),
        _circuitBreaker = CircuitBreaker(
            circuitBreakerConfig ?? const CircuitBreakerConfig()),
        _deduplicator = RequestDeduplicator();
  final RetryConfig _retryConfig;
  final CircuitBreaker _circuitBreaker;
  final RequestDeduplicator _deduplicator;
  final math.Random _random = math.Random();

  /// Connection metrics
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  int _retriedRequests = 0;
  Duration _totalResponseTime = Duration.zero;

  /// Connection metrics
  Map<String, dynamic> get metrics => {
        'totalRequests': _totalRequests,
        'successfulRequests': _successfulRequests,
        'failedRequests': _failedRequests,
        'retriedRequests': _retriedRequests,
        'successRate':
            _totalRequests > 0 ? _successfulRequests / _totalRequests : 0.0,
        'averageResponseTime': _totalRequests > 0
            ? _totalResponseTime.inMilliseconds / _totalRequests
            : 0.0,
        'circuitBreakerState': _circuitBreaker.state.toString(),
      };

  /// Enhanced account balance fetching with retry
  @override
  Future<int> getBalance(
    PublicKey publicKey, {
    CommitmentConfig? commitment,
  }) async => _executeWithRetry(
        () => super.getBalance(publicKey, commitment: commitment));

  /// Enhanced account info fetching with retry
  @override
  Future<AccountInfo?> getAccountInfo(
    PublicKey publicKey, {
    CommitmentConfig? commitment,
  }) async => _executeWithRetry(
        () => super.getAccountInfo(publicKey, commitment: commitment));

  /// Enhanced latest blockhash fetching with retry
  @override
  Future<LatestBlockhash> getLatestBlockhash({
    CommitmentConfig? commitment,
  }) async => _executeWithRetry(
        () => super.getLatestBlockhash(commitment: commitment));

  /// Enhanced multiple accounts fetching with retry
  @override
  Future<List<AccountInfo?>> getMultipleAccountsInfo(
    List<PublicKey> publicKeys, {
    CommitmentConfig? commitment,
  }) async => _executeWithRetry(() =>
        super.getMultipleAccountsInfo(publicKeys, commitment: commitment));

  /// Enhanced program accounts fetching with retry
  @override
  Future<List<ProgramAccountInfo>> getProgramAccounts(
    PublicKey programId, {
    List<AccountFilter>? filters,
    CommitmentConfig? commitment,
  }) async => _executeWithRetry(() => super.getProgramAccounts(programId,
        filters: filters, commitment: commitment));

  /// Enhanced minimum balance fetching with retry
  @override
  Future<int> getMinimumBalanceForRentExemption(
    int dataLength, {
    CommitmentConfig? commitment,
  }) async => _executeWithRetry(() => super
        .getMinimumBalanceForRentExemption(dataLength, commitment: commitment));

  /// Enhanced health check with retry
  @override
  Future<String> checkHealth() async => _executeWithRetry(() => super.checkHealth());

  /// Execute operation with retry logic
  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    _totalRequests++;
    final stopwatch = Stopwatch()..start();

    Exception? lastException;

    for (int attempt = 0; attempt <= _retryConfig.maxRetries; attempt++) {
      // Check circuit breaker
      if (!_circuitBreaker.shouldAllowRequest()) {
        throw const RpcException('Circuit breaker is open - service unavailable');
      }

      try {
        final result = await operation();

        // Record success
        _circuitBreaker.recordSuccess();
        _successfulRequests++;

        if (attempt > 0) {
          _retriedRequests++;
        }

        _totalResponseTime += stopwatch.elapsed;
        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // Check if error is retryable
        final isRetryable = _isRetryableError(e);

        if (!isRetryable || attempt == _retryConfig.maxRetries) {
          _circuitBreaker.recordFailure();
          _failedRequests++;
          _totalResponseTime += stopwatch.elapsed;
          throw lastException;
        }

        // Calculate delay with exponential backoff and jitter
        final delay = _calculateDelay(attempt);
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }

    _circuitBreaker.recordFailure();
    _failedRequests++;
    _totalResponseTime += stopwatch.elapsed;
    throw lastException!;
  }

  /// Check if error is retryable
  bool _isRetryableError(dynamic error) {
    if (error is RpcException) {
      // Check if it's a network/server error
      final message = error.toString().toLowerCase();
      if (message.contains('timeout') ||
          message.contains('connection') ||
          message.contains('network') ||
          message.contains('socket')) {
        return true;
      }

      // Check for retryable HTTP status codes
      final httpMatch = RegExp(r'http (\d+):').firstMatch(message);
      if (httpMatch != null) {
        final statusCode = int.tryParse(httpMatch.group(1) ?? '');
        if (statusCode != null &&
            _retryConfig.retryableStatusCodes.contains(statusCode)) {
          return true;
        }
      }
    }

    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  /// Calculate delay with exponential backoff and jitter
  int _calculateDelay(int attempt) {
    final baseDelay = (_retryConfig.baseDelayMs *
            math.pow(_retryConfig.backoffMultiplier, attempt))
        .round();

    var delay = math.min(baseDelay, _retryConfig.maxDelayMs);

    if (_retryConfig.enableJitter) {
      final jitter =
          (delay * _retryConfig.jitterFactor * (_random.nextDouble() * 2 - 1))
              .round();
      delay += jitter;
      delay = math.max(delay, 0);
    }

    return delay;
  }

  /// Reset circuit breaker (for testing/manual recovery)
  void resetCircuitBreaker() {
    _circuitBreaker._state = CircuitBreakerState.closed;
    _circuitBreaker._failureCount = 0;
    _circuitBreaker._successCount = 0;
    _circuitBreaker._recentFailures.clear();
    _circuitBreaker._lastFailureTime = null;
  }

  /// Calculate delay with exponential backoff and jitter (exposed for testing)
  int calculateDelayForTesting(int attempt) => _calculateDelay(attempt);

  /// Get circuit breaker for testing
  CircuitBreaker get circuitBreakerForTesting => _circuitBreaker;

  /// Get health status
  Future<bool> isHealthy() async {
    try {
      await checkHealth();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Close connection and cleanup resources
  @override
  void close() {
    super.close();
    // Clean up timers and resources
    for (final timer in _deduplicator._timeouts.values) {
      timer.cancel();
    }
  }
}
