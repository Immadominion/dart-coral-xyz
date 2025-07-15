/// Tests for Enhanced Connection with retry and recovery mechanisms
///
/// This module provides comprehensive tests for the enhanced connection
/// functionality including retry logic, circuit breaker, and performance metrics.
library;

import 'dart:async';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

import 'package:coral_xyz_anchor/src/provider/enhanced_connection.dart';
import 'package:coral_xyz_anchor/src/provider/connection_pool.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/utils/rpc_errors.dart';

/// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  MockHttpClient({this.delay});
  final List<http.Response> responses = [];
  final List<Exception> exceptions = [];
  int requestCount = 0;
  final Duration? delay;

  void addResponse(http.Response response) {
    responses.add(response);
  }

  void addException(Exception exception) {
    exceptions.add(exception);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }

    requestCount++;

    if (exceptions.isNotEmpty) {
      final exception = exceptions.removeAt(0);
      throw exception;
    }

    if (responses.isNotEmpty) {
      final response = responses.removeAt(0);
      return http.StreamedResponse(
        Stream.fromIterable([response.bodyBytes]),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
      );
    }

    // Default successful response
    return http.StreamedResponse(
      Stream.fromIterable([]),
      200,
    );
  }
}

void main() {
  group('RetryConfig', () {
    test('should have sensible defaults', () {
      const config = RetryConfig();

      expect(config.maxRetries, equals(3));
      expect(config.baseDelayMs, equals(1000));
      expect(config.maxDelayMs, equals(30000));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.enableJitter, isTrue);
      expect(config.jitterFactor, equals(0.1));
      expect(config.retryableMethods.contains('getBalance'), isTrue);
      expect(config.retryableStatusCodes.contains(500), isTrue);
    });

    test('should allow custom configuration', () {
      const config = RetryConfig(
        maxRetries: 5,
        baseDelayMs: 500,
        enableJitter: false,
      );

      expect(config.maxRetries, equals(5));
      expect(config.baseDelayMs, equals(500));
      expect(config.enableJitter, isFalse);
    });
  });

  group('CircuitBreaker', () {
    test('should start in closed state', () {
      final breaker = CircuitBreaker(const CircuitBreakerConfig());
      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.shouldAllowRequest(), isTrue);
    });

    test('should open after failure threshold', () {
      const config = CircuitBreakerConfig(failureThreshold: 2);
      final breaker = CircuitBreaker(config);

      expect(breaker.state, equals(CircuitBreakerState.closed));

      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.closed));

      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.open));
      expect(breaker.shouldAllowRequest(), isFalse);
    });

    test('should transition to half-open after recovery timeout', () async {
      const config = CircuitBreakerConfig(
        failureThreshold: 1,
        recoveryTimeoutMs: 100,
      );
      final breaker = CircuitBreaker(config);

      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.open));

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(breaker.shouldAllowRequest(), isTrue);
      expect(breaker.state, equals(CircuitBreakerState.halfOpen));
    });

    test('should close after success threshold in half-open state', () {
      const config = CircuitBreakerConfig(
        failureThreshold: 1,
        successThreshold: 2,
      );
      final breaker = CircuitBreaker(config);

      breaker.recordFailure();
      breaker.stateForTesting = CircuitBreakerState.halfOpen;

      breaker.recordSuccess();
      expect(breaker.state, equals(CircuitBreakerState.halfOpen));

      breaker.recordSuccess();
      expect(breaker.state, equals(CircuitBreakerState.closed));
    });
  });

  group('RequestDeduplicator', () {
    test('should deduplicate identical requests', () async {
      final deduplicator = RequestDeduplicator();
      int callCount = 0;

      Future<Map<String, dynamic>> requestFactory() async {
        callCount++;
        return {'result': 'success'};
      }

      // Make two identical requests
      final future1 =
          deduplicator.getOrCreateRequest('test-key', requestFactory);
      final future2 =
          deduplicator.getOrCreateRequest('test-key', requestFactory);

      final results = await Future.wait([future1, future2]);

      expect(callCount, equals(1)); // Should only call once
      expect(results[0], equals(results[1]));
    });

    test('should generate consistent keys', () {
      final key1 =
          RequestDeduplicator.generateKey('getBalance', ['arg1', 'arg2']);
      final key2 =
          RequestDeduplicator.generateKey('getBalance', ['arg1', 'arg2']);
      final key3 =
          RequestDeduplicator.generateKey('getBalance', ['arg1', 'arg3']);

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });
  });

  group('EnhancedConnection', () {
    late MockHttpClient mockClient;
    late EnhancedConnection connection;

    setUp(() {
      mockClient = MockHttpClient();
      connection = EnhancedConnection(
        'https://api.devnet.solana.com',
        retryConfig: const RetryConfig(maxRetries: 2, baseDelayMs: 10),
      );
    });

    test('should create with default configuration', () {
      final conn = EnhancedConnection('https://api.devnet.solana.com');
      expect(conn.endpoint, equals('https://api.devnet.solana.com'));
      expect(conn.metrics['totalRequests'], equals(0));
    });

    test('should retry on retryable errors', () async {
      // First call fails, second succeeds
      mockClient.addException(http.ClientException('Network error'));
      mockClient.addResponse(http.Response('{"result": {"value": 1000}}', 200));

      final publicKey =
          PublicKey.fromBase58('11111111111111111111111111111112');
      final balance = await connection.getBalance(publicKey);

      expect(balance, equals(1000));
      expect(mockClient.requestCount, equals(2)); // One retry
      expect(connection.metrics['retriedRequests'], equals(1));
    });

    test('should not retry non-retryable errors', () async {
      mockClient.addResponse(
        http.Response(
          '{"error": {"code": -32600, "message": "Invalid request"}}',
          200,
        ),
      );

      final publicKey =
          PublicKey.fromBase58('11111111111111111111111111111112');

      expect(
        () async => connection.getBalance(publicKey),
        throwsA(isA<RpcException>()),
      );

      expect(mockClient.requestCount, equals(1)); // No retry
      expect(connection.metrics['retriedRequests'], equals(0));
    });

    test('should respect circuit breaker', () async {
      const config = CircuitBreakerConfig(failureThreshold: 1);
      final conn = EnhancedConnection(
        'https://api.devnet.solana.com',
        circuitBreakerConfig: config,
      );

      // First request fails to trigger circuit breaker
      mockClient.addException(http.ClientException('Network error'));

      final publicKey =
          PublicKey.fromBase58('11111111111111111111111111111112');

      expect(
        () async => conn.getBalance(publicKey),
        throwsA(isA<Exception>()),
      );

      // Second request should be blocked by circuit breaker
      expect(
        () async => conn.getBalance(publicKey),
        throwsA(
          predicate((e) => e.toString().contains('Circuit breaker is open')),
        ),
      );
    });

    test('should calculate exponential backoff with jitter', () {
      final retryConfig = const RetryConfig(
        backoffMultiplier: 2,
      );

      final conn = EnhancedConnection(
        'https://api.devnet.solana.com',
        retryConfig: retryConfig,
      );

      final delay1 = conn.calculateDelayForTesting(0);
      final delay2 = conn.calculateDelayForTesting(1);
      final delay3 = conn.calculateDelayForTesting(2);

      // Base delays should follow exponential pattern (with jitter variation)
      expect(delay1, closeTo(1000, 100)); // ~1000ms ± jitter
      expect(delay2, closeTo(2000, 200)); // ~2000ms ± jitter
      expect(delay3, closeTo(4000, 400)); // ~4000ms ± jitter
    });

    test('should track connection metrics', () async {
      mockClient.addResponse(http.Response('{"result": {"value": 1000}}', 200));
      mockClient.addException(http.ClientException('Network error'));

      final publicKey =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Successful request
      await connection.getBalance(publicKey);

      // Failed request
      try {
        await connection.getBalance(publicKey);
      } catch (e) {
        // Expected to fail
      }

      final metrics = connection.metrics;
      expect(metrics['totalRequests'], equals(2));
      expect(metrics['successfulRequests'], equals(1));
      expect(metrics['failedRequests'], equals(1));
      expect(metrics['successRate'], equals(0.5));
    });

    test('should check health status', () async {
      // Healthy response
      mockClient.addResponse(http.Response('"ok"', 200));
      expect(await connection.isHealthy(), isTrue);

      // Unhealthy response
      mockClient.addException(http.ClientException('Connection failed'));
      expect(await connection.isHealthy(), isFalse);
    });

    test('should reset circuit breaker', () {
      const config = CircuitBreakerConfig(failureThreshold: 1);
      final conn = EnhancedConnection(
        'https://api.devnet.solana.com',
        circuitBreakerConfig: config,
      );

      // Trigger circuit breaker
      conn.circuitBreakerForTesting.recordFailure();
      expect(
        conn.circuitBreakerForTesting.state,
        equals(CircuitBreakerState.open),
      );

      // Reset circuit breaker
      conn.resetCircuitBreaker();
      expect(
        conn.circuitBreakerForTesting.state,
        equals(CircuitBreakerState.closed),
      );
    });
  });

  group('ConnectionPool', () {
    test('should create pool with minimum connections', () async {
      final pool = ConnectionPool(['https://api.devnet.solana.com']);

      // Allow time for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final metrics = pool.metrics;
      expect(
        metrics.totalConnections,
        greaterThanOrEqualTo(2),
      ); // Default minimum

      await pool.dispose();
    });

    test('should execute operations with pooled connections', () async {
      final pool = ConnectionPool(
        ['https://api.devnet.solana.com'],
        config:
            const ConnectionPoolConfig(minConnections: 1, maxConnections: 2),
      );

      // Allow time for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = await pool.execute((connection) async => 'test-result');

      expect(result, equals('test-result'));
      await pool.dispose();
    });

    test('should track pool metrics', () async {
      final pool = ConnectionPool(['https://api.devnet.solana.com']);

      // Allow time for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await pool.execute((connection) async => 'success');

      final metrics = pool.metrics;
      expect(metrics.totalRequests, equals(1));
      expect(metrics.successfulRequests, equals(1));
      expect(metrics.hitRate, equals(1.0));

      await pool.dispose();
    });

    test('should handle multiple endpoints', () async {
      final endpoints = [
        'https://api.devnet.solana.com',
        'https://api.mainnet-beta.solana.com',
      ];

      final pool = ConnectionPool(
        endpoints,
        config: const ConnectionPoolConfig(),
      );

      // Allow time for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final metrics = pool.metrics;
      expect(metrics.totalConnections, greaterThanOrEqualTo(2));

      await pool.dispose();
    });

    test('should respect connection limits', () async {
      final pool = ConnectionPool(
        ['https://api.devnet.solana.com'],
        config:
            const ConnectionPoolConfig(minConnections: 1, maxConnections: 2),
      );

      // Allow time for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final metrics = pool.metrics;
      expect(metrics.totalConnections, lessThanOrEqualTo(2));

      await pool.dispose();
    });

    test('should dispose cleanly', () async {
      final pool = ConnectionPool(['https://api.devnet.solana.com']);

      // Allow time for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await pool.dispose();

      // Should not accept new operations after disposal
      expect(
        () async => pool.execute((connection) async => 'test'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
