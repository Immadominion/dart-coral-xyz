/// RPC and Network Utilities for Solana Anchor programs
///
/// This module provides enhanced RPC utilities including custom method implementations,
/// network detection, request/response logging, timeout/retry mechanisms, and performance monitoring.
/// These utilities extend the basic connection functionality with additional features
/// for production use and debugging.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/connection_config.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/utils/rpc_errors.dart';

/// Network types supported by the RPC utilities
enum SolanaNetwork {
  mainnet,
  testnet,
  devnet,
  localhost,
  custom,
}

/// Performance monitoring statistics for RPC requests
class RpcPerformanceStats {
  /// Total number of requests made
  int totalRequests = 0;

  /// Total number of successful requests
  int successfulRequests = 0;

  /// Total number of failed requests
  int failedRequests = 0;

  /// Total request time in milliseconds
  int totalRequestTime = 0;

  /// Minimum request time in milliseconds
  int minRequestTime = 0;

  /// Maximum request time in milliseconds
  int maxRequestTime = 0;

  /// Average request time in milliseconds
  double get averageRequestTime =>
      totalRequests > 0 ? totalRequestTime / totalRequests : 0.0;

  /// Success rate as a percentage
  double get successRate =>
      totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0.0;

  /// Record a successful request
  void recordSuccess(int responseTimeMs) {
    totalRequests++;
    successfulRequests++;
    totalRequestTime += responseTimeMs;

    if (minRequestTime == 0 || responseTimeMs < minRequestTime) {
      minRequestTime = responseTimeMs;
    }
    if (responseTimeMs > maxRequestTime) {
      maxRequestTime = responseTimeMs;
    }
  }

  /// Record a failed request
  void recordFailure(int responseTimeMs) {
    totalRequests++;
    failedRequests++;
    totalRequestTime += responseTimeMs;

    if (minRequestTime == 0 || responseTimeMs < minRequestTime) {
      minRequestTime = responseTimeMs;
    }
    if (responseTimeMs > maxRequestTime) {
      maxRequestTime = responseTimeMs;
    }
  }

  /// Reset all statistics
  void reset() {
    totalRequests = 0;
    successfulRequests = 0;
    failedRequests = 0;
    totalRequestTime = 0;
    minRequestTime = 0;
    maxRequestTime = 0;
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() => {
        'totalRequests': totalRequests,
        'successfulRequests': successfulRequests,
        'failedRequests': failedRequests,
        'totalRequestTimeMs': totalRequestTime,
        'minRequestTimeMs': minRequestTime,
        'maxRequestTimeMs': maxRequestTime,
        'averageRequestTimeMs': averageRequestTime,
        'successRate': successRate,
      };
}

/// Configuration for RPC request/response logging
class RpcLoggingConfig {

  const RpcLoggingConfig({
    this.logRequests = true,
    this.logResponses = true,
    this.logErrors = true,
    this.logTiming = true,
    this.logBodies = false,
    this.logPrefix = '[RPC]',
  });
  /// Whether to log requests
  final bool logRequests;

  /// Whether to log responses
  final bool logResponses;

  /// Whether to log errors
  final bool logErrors;

  /// Whether to log timing information
  final bool logTiming;

  /// Whether to log request/response bodies (can be verbose)
  final bool logBodies;

  /// Custom log prefix
  final String logPrefix;

  /// Configuration for debugging (logs everything)
  static const debug = RpcLoggingConfig(
    logResponses: true,
    logBodies: true,
    logPrefix: '[RPC-DEBUG]',
  );

  /// Configuration for production (minimal logging)
  static const production = RpcLoggingConfig(
    logRequests: false,
    logResponses: false,
    logTiming: false,
  );
}

/// Enhanced RPC client with logging, monitoring, and network utilities
class EnhancedRpcClient {

  /// Create an enhanced RPC client
  EnhancedRpcClient(
    this._connection, {
    RpcLoggingConfig loggingConfig = const RpcLoggingConfig(),
  }) : _loggingConfig = loggingConfig;
  final Connection _connection;
  final RpcLoggingConfig _loggingConfig;
  final RpcPerformanceStats _stats = RpcPerformanceStats();
  final http.Client _httpClient = http.Client();

  /// Internal counter for request IDs
  int _requestIdCounter = 1;

  /// Get the connection instance
  Connection get connection => _connection;

  /// Get performance statistics
  RpcPerformanceStats get stats => _stats;

  /// Get the current network type
  SolanaNetwork get networkType => detectNetwork(_connection.endpoint);

  /// Reset performance statistics
  void resetStats() => _stats.reset();

  /// Make an enhanced RPC request with logging and monitoring
  Future<dynamic> makeRequest(
    String method,
    List<dynamic> params, {
    Duration? timeout,
    int? maxRetries,
  }) async {
    final requestId = _requestIdCounter++;
    final startTime = DateTime.now();

    if (_loggingConfig.logRequests) {
      _log('Request #$requestId: $method');
      if (_loggingConfig.logBodies) {
        _log('Request params: ${json.encode(params)}');
      }
    }

    final actualTimeout = timeout ??
        Duration(
            milliseconds:
                _connection.endpoint.contains('localhost') ? 10000 : 30000,);
    final actualMaxRetries = maxRetries ?? 3;

    dynamic result;
    Exception? lastException;

    for (int attempt = 0; attempt < actualMaxRetries; attempt++) {
      try {
        final requestBody = {
          'jsonrpc': '2.0',
          'id': requestId,
          'method': method,
          'params': params,
        };

        final response = await _httpClient
            .post(
              Uri.parse(_connection.endpoint),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'dart-coral-xyz-anchor/1.0.0',
              },
              body: json.encode(requestBody),
            )
            .timeout(actualTimeout);

        final responseTime =
            DateTime.now().difference(startTime).inMilliseconds;

        if (response.statusCode != 200) {
          throw RpcException('HTTP ${response.statusCode}: ${response.body}');
        }

        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

        if (jsonResponse.containsKey('error')) {
          final error = jsonResponse['error'] as Map<String, dynamic>;
          throw RpcException(
            'RPC Error ${error['code']}: ${error['message']}',
            code: error['code'] as int?,
            data: error['data'],
          );
        }

        result = jsonResponse['result'];
        _stats.recordSuccess(responseTime);

        if (_loggingConfig.logResponses) {
          _log('Response #$requestId received');
          if (_loggingConfig.logTiming) {
            _log('Response time: ${responseTime}ms');
          }
          if (_loggingConfig.logBodies) {
            _log('Response body: ${json.encode(result)}');
          }
        }

        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        final responseTime =
            DateTime.now().difference(startTime).inMilliseconds;

        if (_loggingConfig.logErrors) {
          _log(
              'Request #$requestId failed (attempt ${attempt + 1}/$actualMaxRetries): $e',);
        }

        if (attempt == actualMaxRetries - 1) {
          _stats.recordFailure(responseTime);
        } else {
          // Exponential backoff
          final delay =
              Duration(milliseconds: 1000 * math.pow(2, attempt).toInt());
          await Future.delayed(delay);
        }
      }
    }

    throw lastException ??
        RpcException('Request failed after $actualMaxRetries attempts');
  }

  /// Get multiple accounts with batching and performance monitoring
  Future<List<AccountInfo?>> getMultipleAccounts(
    List<PublicKey> publicKeys, {
    CommitmentConfig? commitment,
    int batchSize = 99,
  }) async {
    if (publicKeys.isEmpty) return [];

    // Split into batches to avoid RPC limits
    final batches = <List<PublicKey>>[];
    for (int i = 0; i < publicKeys.length; i += batchSize) {
      final end = math.min(i + batchSize, publicKeys.length);
      batches.add(publicKeys.sublist(i, end));
    }

    final results = <AccountInfo?>[];

    for (final batch in batches) {
      final batchResult = await makeRequest('getMultipleAccounts', [
        batch.map((pk) => pk.toBase58()).toList(),
        {
          'encoding': 'base64',
          'commitment':
              (commitment ?? _connection.config.commitment).commitment.value,
        }
      ]);

      final accounts = (batchResult['value'] as List<dynamic>?)
              ?.map((account) => account != null
                  ? AccountInfo.fromJson(account as Map<String, dynamic>)
                  : null,)
              .toList() ??
          <AccountInfo?>[];

      results.addAll(accounts);
    }

    return results;
  }

  /// Enhanced transaction simulation with detailed error reporting
  Future<RpcSimulationResult> simulateTransaction(
    Uint8List transaction, {
    CommitmentConfig? commitment,
    bool verifySignatures = false,
    List<PublicKey>? accountsToReturn,
  }) async {
    final params = [
      base64.encode(transaction),
      {
        'encoding': 'base64',
        'sigVerify': verifySignatures,
        'commitment':
            (commitment ?? _connection.config.commitment).commitment.value,
        if (accountsToReturn != null)
          'accounts': {
            'encoding': 'base64',
            'addresses': accountsToReturn.map((pk) => pk.toBase58()).toList(),
          },
      }
    ];

    final result = await makeRequest('simulateTransaction', params);
    return RpcSimulationResult.fromJson(
        result['value'] as Map<String, dynamic>,);
  }

  /// Check if the network is healthy
  Future<NetworkHealthStatus> checkNetworkHealth() async {
    final startTime = DateTime.now();

    try {
      // Test basic connectivity
      final slot = await makeRequest('getSlot', []);
      await makeRequest('getHealth', []);
      final version = await makeRequest('getVersion', []);

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      return NetworkHealthStatus(
        isHealthy: true,
        responseTimeMs: responseTime,
        currentSlot: slot as int,
        version: version['solana-core'] as String?,
        details: 'Network is healthy',
      );
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      return NetworkHealthStatus(
        isHealthy: false,
        responseTimeMs: responseTime,
        details: 'Network health check failed: $e',
      );
    }
  }

  /// Get detailed network information
  Future<NetworkInfo> getNetworkInfo() async {
    try {
      final [versionResult, epochInfoResult, supplyResult] = await Future.wait([
        makeRequest('getVersion', []),
        makeRequest('getEpochInfo', []),
        makeRequest('getSupply', []),
      ]);

      return NetworkInfo(
        networkType: networkType,
        rpcUrl: _connection.endpoint,
        version: versionResult['solana-core'] as String?,
        epoch: epochInfoResult['epoch'] as int,
        slot: epochInfoResult['slot'] as int,
        totalSupply: supplyResult['value']['total'] as int,
        circulatingSupply: supplyResult['value']['circulating'] as int,
      );
    } catch (e) {
      throw RpcException('Failed to get network info: $e');
    }
  }

  /// Log a message with the configured prefix
  void _log(String message) {
    print('${_loggingConfig.logPrefix} $message');
  }

  /// Close the client and cleanup resources
  void close() {
    _httpClient.close();
  }
}

/// Result of a transaction simulation from RPC calls
class RpcSimulationResult {

  const RpcSimulationResult({
    required this.success,
    this.error,
    required this.logs,
    this.computeUnits,
    this.accounts,
  });

  /// Create from JSON response
  factory RpcSimulationResult.fromJson(Map<String, dynamic> json) {
    return RpcSimulationResult(
      success: json['err'] == null,
      error: json['err']?.toString(),
      logs: (json['logs'] as List<dynamic>?)
              ?.map((log) => log.toString())
              .toList() ??
          [],
      computeUnits: json['unitsConsumed'] as int?,
      accounts: (json['accounts'] as List<dynamic>?)
          ?.map((account) => account != null
              ? AccountInfo.fromJson(account as Map<String, dynamic>)
              : null)
          .toList(),
    );
  }
  /// Whether the simulation was successful
  final bool success;

  /// Error message if simulation failed
  final String? error;

  /// Program logs from the simulation
  final List<String> logs;

  /// Compute units consumed
  final int? computeUnits;

  /// Account data returned (if requested)
  final List<AccountInfo?>? accounts;
}

/// Network health status information
class NetworkHealthStatus {

  const NetworkHealthStatus({
    required this.isHealthy,
    required this.responseTimeMs,
    this.currentSlot,
    this.version,
    this.details,
  });
  /// Whether the network is healthy
  final bool isHealthy;

  /// Response time in milliseconds
  final int responseTimeMs;

  /// Current slot (if available)
  final int? currentSlot;

  /// Solana version (if available)
  final String? version;

  /// Additional details
  final String? details;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'isHealthy': isHealthy,
        'responseTimeMs': responseTimeMs,
        if (currentSlot != null) 'currentSlot': currentSlot,
        if (version != null) 'version': version,
        if (details != null) 'details': details,
      };
}

/// Comprehensive network information
class NetworkInfo {

  const NetworkInfo({
    required this.networkType,
    required this.rpcUrl,
    this.version,
    required this.epoch,
    required this.slot,
    required this.totalSupply,
    required this.circulatingSupply,
  });
  /// Network type
  final SolanaNetwork networkType;

  /// RPC URL
  final String rpcUrl;

  /// Solana version
  final String? version;

  /// Current epoch
  final int epoch;

  /// Current slot
  final int slot;

  /// Total SOL supply
  final int totalSupply;

  /// Circulating SOL supply
  final int circulatingSupply;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'networkType': networkType.name,
        'rpcUrl': rpcUrl,
        if (version != null) 'version': version,
        'epoch': epoch,
        'slot': slot,
        'totalSupply': totalSupply,
        'circulatingSupply': circulatingSupply,
      };
}

/// Utility functions for network detection and configuration

/// Detect the network type from an RPC URL
SolanaNetwork detectNetwork(String rpcUrl) {
  final url = rpcUrl.toLowerCase();

  if (url.contains('mainnet') || url.contains('api.mainnet-beta.solana.com')) {
    return SolanaNetwork.mainnet;
  } else if (url.contains('testnet') ||
      url.contains('api.testnet.solana.com')) {
    return SolanaNetwork.testnet;
  } else if (url.contains('devnet') || url.contains('api.devnet.solana.com')) {
    return SolanaNetwork.devnet;
  } else if (url.contains('localhost') || url.contains('127.0.0.1')) {
    return SolanaNetwork.localhost;
  } else {
    return SolanaNetwork.custom;
  }
}

/// Get the default RPC URL for a network
String getDefaultRpcUrl(SolanaNetwork network) {
  switch (network) {
    case SolanaNetwork.mainnet:
      return 'https://api.mainnet-beta.solana.com';
    case SolanaNetwork.testnet:
      return 'https://api.testnet.solana.com';
    case SolanaNetwork.devnet:
      return 'https://api.devnet.solana.com';
    case SolanaNetwork.localhost:
      return 'http://localhost:8899';
    case SolanaNetwork.custom:
      throw ArgumentError('Custom network requires explicit URL');
  }
}

/// Get the default WebSocket URL for a network
String getDefaultWebSocketUrl(SolanaNetwork network) {
  switch (network) {
    case SolanaNetwork.mainnet:
      return 'wss://api.mainnet-beta.solana.com';
    case SolanaNetwork.testnet:
      return 'wss://api.testnet.solana.com';
    case SolanaNetwork.devnet:
      return 'wss://api.devnet.solana.com';
    case SolanaNetwork.localhost:
      return 'ws://localhost:8900';
    case SolanaNetwork.custom:
      throw ArgumentError('Custom network requires explicit WebSocket URL');
  }
}

/// Create a connection configuration for a specific network
ConnectionConfig createNetworkConfig(
  SolanaNetwork network, {
  CommitmentConfig? commitment,
  int? timeoutMs,
  int? retryAttempts,
  Map<String, String>? headers,
}) => ConnectionConfig(
    rpcUrl: getDefaultRpcUrl(network),
    websocketUrl: getDefaultWebSocketUrl(network),
    commitment: commitment ??
        (network == SolanaNetwork.mainnet
            ? CommitmentConfigs.finalized
            : CommitmentConfigs.confirmed),
    timeoutMs:
        timeoutMs ?? (network == SolanaNetwork.localhost ? 10000 : 30000),
    retryAttempts: retryAttempts ?? 3,
    headers: headers ?? {},
  );

/// Batch RPC requests to improve performance
class RpcBatcher {

  RpcBatcher(
    this._client, {
    int batchSize = 10,
    Duration batchDelay = const Duration(milliseconds: 100),
  })  : _batchSize = batchSize,
        _batchDelay = batchDelay;
  final EnhancedRpcClient _client;
  final List<_BatchedRequest> _pendingRequests = [];
  final int _batchSize;
  final Duration _batchDelay;
  Timer? _batchTimer;

  /// Add a request to the batch
  Future<dynamic> addRequest(String method, List<dynamic> params) {
    final completer = Completer<dynamic>();
    final request = _BatchedRequest(method, params, completer);

    _pendingRequests.add(request);

    if (_pendingRequests.length >= _batchSize) {
      _flushBatch();
    } else {
      _scheduleBatch();
    }

    return completer.future;
  }

  /// Schedule a batch to be sent after the delay
  void _scheduleBatch() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchDelay, _flushBatch);
  }

  /// Send all pending requests as a batch
  void _flushBatch() {
    if (_pendingRequests.isEmpty) return;

    _batchTimer?.cancel();
    final requests = List<_BatchedRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    _processBatch(requests);
  }

  /// Process a batch of requests
  Future<void> _processBatch(List<_BatchedRequest> requests) async {
    try {
      final batchRequest = requests
          .map((req) => {
                'jsonrpc': '2.0',
                'id': req.hashCode,
                'method': req.method,
                'params': req.params,
              },)
          .toList();

      final result = await _client.makeRequest('batch', [batchRequest]);

      if (result is List) {
        for (int i = 0; i < result.length && i < requests.length; i++) {
          final response = result[i] as Map<String, dynamic>;
          final request = requests[i];

          if (response.containsKey('error')) {
            final error = response['error'] as Map<String, dynamic>;
            request.completer.completeError(RpcException(
              'RPC Error ${error['code']}: ${error['message']}',
              code: error['code'] as int?,
              data: error['data'],
            ),);
          } else {
            request.completer.complete(response['result']);
          }
        }
      } else {
        // Fallback: send requests individually
        for (final request in requests) {
          try {
            final result =
                await _client.makeRequest(request.method, request.params);
            request.completer.complete(result);
          } catch (e) {
            request.completer.completeError(e);
          }
        }
      }
    } catch (e) {
      // Complete all requests with the error
      for (final request in requests) {
        request.completer.completeError(e);
      }
    }
  }

  /// Close the batcher and flush any pending requests
  void close() {
    _batchTimer?.cancel();
    _flushBatch();
  }
}

/// Internal class for batched requests
class _BatchedRequest {

  _BatchedRequest(this.method, this.params, this.completer);
  final String method;
  final List<dynamic> params;
  final Completer<dynamic> completer;
}
