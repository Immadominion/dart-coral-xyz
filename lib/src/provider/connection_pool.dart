/// Connection Pool manager for efficient resource utilization
///
/// This module provides connection pooling capabilities for high-performance
/// applications, with automatic cleanup, health checks, and load balancing.

library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:coral_xyz_anchor/src/utils/rpc_errors.dart';
import 'package:coral_xyz_anchor/src/provider/enhanced_connection.dart';

/// Connection pool configuration
class ConnectionPoolConfig {

  const ConnectionPoolConfig({
    this.minConnections = 2,
    this.maxConnections = 10,
    this.maxIdleTime = const Duration(minutes: 5),
    this.healthCheckInterval = const Duration(seconds: 30),
    this.connectionTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 30),
    this.loadBalancingStrategy = LoadBalancingStrategy.roundRobin,
    this.validateOnBorrow = true,
    this.validateOnReturn = false,
  });
  /// Minimum number of connections to maintain
  final int minConnections;

  /// Maximum number of connections in the pool
  final int maxConnections;

  /// Maximum idle time before connection is closed
  final Duration maxIdleTime;

  /// Health check interval
  final Duration healthCheckInterval;

  /// Connection timeout
  final Duration connectionTimeout;

  /// Request timeout for individual operations
  final Duration requestTimeout;

  /// Load balancing strategy
  final LoadBalancingStrategy loadBalancingStrategy;

  /// Whether to validate connections before use
  final bool validateOnBorrow;

  /// Whether to validate connections on return
  final bool validateOnReturn;
}

/// Load balancing strategies
enum LoadBalancingStrategy {
  roundRobin,
  leastConnections,
  random,
  weighted,
}

/// Connection wrapper with metadata
class PooledConnection {

  PooledConnection(this.connection)
      : createdAt = DateTime.now(),
        lastUsedAt = DateTime.now(),
        usageCount = 0,
        isHealthy = true,
        isInUse = false;
  final EnhancedConnection connection;
  final DateTime createdAt;
  DateTime lastUsedAt;
  int usageCount;
  bool isHealthy;
  bool isInUse;

  /// Mark connection as used
  void markUsed() {
    lastUsedAt = DateTime.now();
    usageCount++;
    isInUse = true;
  }

  /// Mark connection as returned
  void markReturned() {
    isInUse = false;
  }

  /// Check if connection is idle
  bool isIdle(Duration maxIdleTime) => !isInUse && DateTime.now().difference(lastUsedAt) > maxIdleTime;

  /// Get connection age
  Duration get age => DateTime.now().difference(createdAt);
}

/// Connection pool metrics
class ConnectionPoolMetrics {

  const ConnectionPoolMetrics({
    required this.totalConnections,
    required this.availableConnections,
    required this.activeConnections,
    required this.healthyConnections,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageRequestTime,
    required this.hitRate,
  });
  final int totalConnections;
  final int availableConnections;
  final int activeConnections;
  final int healthyConnections;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final Duration averageRequestTime;
  final double hitRate;

  Map<String, dynamic> toJson() => {
        'totalConnections': totalConnections,
        'availableConnections': availableConnections,
        'activeConnections': activeConnections,
        'healthyConnections': healthyConnections,
        'totalRequests': totalRequests,
        'successfulRequests': successfulRequests,
        'failedRequests': failedRequests,
        'averageRequestTime': averageRequestTime.inMilliseconds,
        'hitRate': hitRate,
      };
}

/// Connection pool for managing multiple connections efficiently
class ConnectionPool {

  /// Create connection pool
  ConnectionPool(
    this._endpoints, {
    ConnectionPoolConfig? config,
    RetryConfig? retryConfig,
    CircuitBreakerConfig? circuitBreakerConfig,
  })  : _config = config ?? const ConnectionPoolConfig(),
        _retryConfig = retryConfig,
        _circuitBreakerConfig = circuitBreakerConfig {
    _initializePool();
    _startHealthChecks();
    _startCleanupTimer();
  }
  final List<String> _endpoints;
  final ConnectionPoolConfig _config;
  final RetryConfig? _retryConfig;
  final CircuitBreakerConfig? _circuitBreakerConfig;

  final Queue<PooledConnection> _availableConnections =
      Queue<PooledConnection>();
  final Set<PooledConnection> _allConnections = <PooledConnection>{};
  final math.Random _random = math.Random();

  Timer? _healthCheckTimer;
  Timer? _cleanupTimer;

  int _roundRobinIndex = 0;
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  Duration _totalRequestTime = Duration.zero;

  bool _isDisposed = false;

  /// Get connection pool metrics
  ConnectionPoolMetrics get metrics {
    final availableCount = _availableConnections.length;
    final activeCount = _allConnections.where((c) => c.isInUse).length;
    final healthyCount = _allConnections.where((c) => c.isHealthy).length;

    return ConnectionPoolMetrics(
      totalConnections: _allConnections.length,
      availableConnections: availableCount,
      activeConnections: activeCount,
      healthyConnections: healthyCount,
      totalRequests: _totalRequests,
      successfulRequests: _successfulRequests,
      failedRequests: _failedRequests,
      averageRequestTime: _totalRequests > 0
          ? Duration(
              milliseconds: _totalRequestTime.inMilliseconds ~/ _totalRequests,)
          : Duration.zero,
      hitRate: _totalRequests > 0 ? _successfulRequests / _totalRequests : 0.0,
    );
  }

  /// Execute operation with pooled connection
  Future<T> execute<T>(
      Future<T> Function(EnhancedConnection connection) operation,) async {
    if (_isDisposed) {
      throw StateError('Connection pool has been disposed');
    }

    _totalRequests++;
    final stopwatch = Stopwatch()..start();

    PooledConnection? pooledConnection;
    try {
      pooledConnection = await _borrowConnection();
      final result = await operation(pooledConnection.connection);

      _successfulRequests++;
      _totalRequestTime += stopwatch.elapsed;

      return result;
    } catch (e) {
      _failedRequests++;
      _totalRequestTime += stopwatch.elapsed;

      // Mark connection as unhealthy if it's a connection-related error
      if (pooledConnection != null && _isConnectionError(e)) {
        pooledConnection.isHealthy = false;
      }

      rethrow;
    } finally {
      if (pooledConnection != null) {
        _returnConnection(pooledConnection);
      }
    }
  }

  /// Borrow connection from pool
  Future<PooledConnection> _borrowConnection() async {
    // Try to get available connection
    PooledConnection? connection = _getAvailableConnection();

    if (connection != null) {
      if (_config.validateOnBorrow && !await _validateConnection(connection)) {
        connection.isHealthy = false;
        // Try to get another connection
        connection = _getAvailableConnection();
      }
    }

    // Create new connection if needed and allowed
    if (connection == null && _allConnections.length < _config.maxConnections) {
      connection = await _createConnection();
    }

    // Wait for available connection if pool is full
    if (connection == null) {
      // Simple wait and retry mechanism
      await Future.delayed(const Duration(milliseconds: 100));
      return _borrowConnection();
    }

    connection.markUsed();
    return connection;
  }

  /// Get available connection using load balancing strategy
  PooledConnection? _getAvailableConnection() {
    final available =
        _availableConnections.where((c) => c.isHealthy && !c.isInUse).toList();

    if (available.isEmpty) return null;

    switch (_config.loadBalancingStrategy) {
      case LoadBalancingStrategy.roundRobin:
        final index = _roundRobinIndex % available.length;
        _roundRobinIndex++;
        return available[index];

      case LoadBalancingStrategy.leastConnections:
        available.sort((a, b) => a.usageCount.compareTo(b.usageCount));
        return available.first;

      case LoadBalancingStrategy.random:
        return available[_random.nextInt(available.length)];

      case LoadBalancingStrategy.weighted:
        // Simple weighted by inverse of usage count
        available.sort((a, b) => a.usageCount.compareTo(b.usageCount));
        return available.first;
    }
  }

  /// Return connection to pool
  void _returnConnection(PooledConnection connection) {
    connection.markReturned();

    if (_config.validateOnReturn && !_validateConnectionSync(connection)) {
      connection.isHealthy = false;
    }

    if (connection.isHealthy && !_availableConnections.contains(connection)) {
      _availableConnections.add(connection);
    }
  }

  /// Create new connection
  Future<PooledConnection> _createConnection() async {
    final endpoint = _selectEndpoint();
    final connection = EnhancedConnection(
      endpoint,
      retryConfig: _retryConfig,
      circuitBreakerConfig: _circuitBreakerConfig,
    );

    final pooledConnection = PooledConnection(connection);
    _allConnections.add(pooledConnection);

    return pooledConnection;
  }

  /// Select endpoint for new connection
  String _selectEndpoint() {
    if (_endpoints.length == 1) return _endpoints.first;

    // Simple round-robin selection
    final index = _allConnections.length % _endpoints.length;
    return _endpoints[index];
  }

  /// Initialize pool with minimum connections
  Future<void> _initializePool() async {
    for (int i = 0; i < _config.minConnections; i++) {
      try {
        final connection = await _createConnection();
        _availableConnections.add(connection);
      } catch (e) {
        // Log error but continue initialization
        print('Failed to create initial connection: $e');
      }
    }
  }

  /// Start health check timer
  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(_config.healthCheckInterval, (_) {
      _performHealthChecks();
    });
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    final cleanupInterval =
        Duration(milliseconds: _config.maxIdleTime.inMilliseconds ~/ 2);
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) {
      _cleanupIdleConnections();
    });
  }

  /// Perform health checks on all connections
  Future<void> _performHealthChecks() async {
    final connectionsToCheck =
        _allConnections.where((c) => !c.isInUse).toList();

    for (final connection in connectionsToCheck) {
      try {
        final isHealthy = await connection.connection.isHealthy();
        connection.isHealthy = isHealthy;
      } catch (e) {
        connection.isHealthy = false;
      }
    }
  }

  /// Clean up idle connections
  void _cleanupIdleConnections() {
    final toRemove = <PooledConnection>[];

    for (final connection in _allConnections) {
      if (!connection.isInUse &&
          (connection.isIdle(_config.maxIdleTime) || !connection.isHealthy)) {
        if (_allConnections.length > _config.minConnections) {
          toRemove.add(connection);
        }
      }
    }

    for (final connection in toRemove) {
      _removeConnection(connection);
    }
  }

  /// Remove connection from pool
  void _removeConnection(PooledConnection connection) {
    _allConnections.remove(connection);
    _availableConnections.remove(connection);
    connection.connection.close();
  }

  /// Validate connection asynchronously
  Future<bool> _validateConnection(PooledConnection connection) async {
    try {
      return await connection.connection.isHealthy();
    } catch (e) {
      return false;
    }
  }

  /// Validate connection synchronously (basic checks)
  bool _validateConnectionSync(PooledConnection connection) {
    // Basic checks without network calls
    return connection.isHealthy && !connection.isInUse;
  }

  /// Check if error is connection-related
  bool _isConnectionError(dynamic error) {
    if (error is RpcException) {
      final message = error.toString().toLowerCase();
      return message.contains('connection') ||
          message.contains('timeout') ||
          message.contains('network') ||
          message.contains('socket');
    }
    return error is SocketException || error is TimeoutException;
  }

  /// Dispose connection pool
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _healthCheckTimer?.cancel();
    _cleanupTimer?.cancel();

    // Close all connections
    for (final connection in _allConnections) {
      connection.connection.close();
    }

    _allConnections.clear();
    _availableConnections.clear();
  }
}
