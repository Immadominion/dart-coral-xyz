/// Tests for RPC and Network Utilities
///
/// This file contains comprehensive tests for the RPC utilities including
/// custom method implementations, network detection, request/response logging,
/// performance monitoring, and batching functionality.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('RPC and Network Utilities', () {
    group('Network Detection', () {
      test('should detect mainnet network', () {
        expect(
          detectNetwork('https://api.mainnet-beta.solana.com'),
          equals(SolanaNetwork.mainnet),
        );
        expect(
          detectNetwork('https://mainnet.solana.com'),
          equals(SolanaNetwork.mainnet),
        );
      });

      test('should detect testnet network', () {
        expect(
          detectNetwork('https://api.testnet.solana.com'),
          equals(SolanaNetwork.testnet),
        );
        expect(
          detectNetwork('https://testnet.solana.com'),
          equals(SolanaNetwork.testnet),
        );
      });

      test('should detect devnet network', () {
        expect(
          detectNetwork('https://api.devnet.solana.com'),
          equals(SolanaNetwork.devnet),
        );
        expect(
          detectNetwork('https://devnet.solana.com'),
          equals(SolanaNetwork.devnet),
        );
      });

      test('should detect localhost network', () {
        expect(
          detectNetwork('http://localhost:8899'),
          equals(SolanaNetwork.localhost),
        );
        expect(
          detectNetwork('http://127.0.0.1:8899'),
          equals(SolanaNetwork.localhost),
        );
      });

      test('should detect custom network', () {
        expect(
          detectNetwork('https://custom-rpc.example.com'),
          equals(SolanaNetwork.custom),
        );
        expect(
          detectNetwork('https://my-private-node.com:8899'),
          equals(SolanaNetwork.custom),
        );
      });
    });

    group('Network Configuration', () {
      test('should get default RPC URLs', () {
        expect(
          getDefaultRpcUrl(SolanaNetwork.mainnet),
          equals('https://api.mainnet-beta.solana.com'),
        );
        expect(
          getDefaultRpcUrl(SolanaNetwork.testnet),
          equals('https://api.testnet.solana.com'),
        );
        expect(
          getDefaultRpcUrl(SolanaNetwork.devnet),
          equals('https://api.devnet.solana.com'),
        );
        expect(
          getDefaultRpcUrl(SolanaNetwork.localhost),
          equals('http://localhost:8899'),
        );
      });

      test('should get default WebSocket URLs', () {
        expect(
          getDefaultWebSocketUrl(SolanaNetwork.mainnet),
          equals('wss://api.mainnet-beta.solana.com'),
        );
        expect(
          getDefaultWebSocketUrl(SolanaNetwork.testnet),
          equals('wss://api.testnet.solana.com'),
        );
        expect(
          getDefaultWebSocketUrl(SolanaNetwork.devnet),
          equals('wss://api.devnet.solana.com'),
        );
        expect(
          getDefaultWebSocketUrl(SolanaNetwork.localhost),
          equals('ws://localhost:8900'),
        );
      });

      test('should throw for custom network without URL', () {
        expect(
          () => getDefaultRpcUrl(SolanaNetwork.custom),
          throwsArgumentError,
        );
        expect(
          () => getDefaultWebSocketUrl(SolanaNetwork.custom),
          throwsArgumentError,
        );
      });

      test('should create network configurations', () {
        final config = createNetworkConfig(SolanaNetwork.devnet);

        expect(config.rpcUrl, equals('https://api.devnet.solana.com'));
        expect(config.websocketUrl, equals('wss://api.devnet.solana.com'));
        expect(config.commitment, equals(CommitmentConfigs.confirmed));
        expect(config.timeoutMs, equals(30000));
        expect(config.retryAttempts, equals(3));
      });

      test('should create localhost configuration with shorter timeout', () {
        final config = createNetworkConfig(SolanaNetwork.localhost);

        expect(config.rpcUrl, equals('http://localhost:8899'));
        expect(config.websocketUrl, equals('ws://localhost:8900'));
        expect(config.timeoutMs, equals(10000));
      });

      test('should create mainnet configuration with finalized commitment', () {
        final config = createNetworkConfig(SolanaNetwork.mainnet);

        expect(config.commitment, equals(CommitmentConfigs.finalized));
      });

      test('should allow custom configuration parameters', () {
        final config = createNetworkConfig(
          SolanaNetwork.devnet,
          commitment: CommitmentConfigs.processed,
          timeoutMs: 15000,
          retryAttempts: 5,
          headers: {'Custom-Header': 'test-value'},
        );

        expect(config.commitment, equals(CommitmentConfigs.processed));
        expect(config.timeoutMs, equals(15000));
        expect(config.retryAttempts, equals(5));
        expect(config.headers['Custom-Header'], equals('test-value'));
      });
    });

    group('RPC Performance Stats', () {
      late RpcPerformanceStats stats;

      setUp(() {
        stats = RpcPerformanceStats();
      });

      test('should start with zero values', () {
        expect(stats.totalRequests, equals(0));
        expect(stats.successfulRequests, equals(0));
        expect(stats.failedRequests, equals(0));
        expect(stats.totalRequestTime, equals(0));
        expect(stats.averageRequestTime, equals(0.0));
        expect(stats.successRate, equals(0.0));
      });

      test('should record successful requests', () {
        stats.recordSuccess(100);
        stats.recordSuccess(200);

        expect(stats.totalRequests, equals(2));
        expect(stats.successfulRequests, equals(2));
        expect(stats.failedRequests, equals(0));
        expect(stats.totalRequestTime, equals(300));
        expect(stats.averageRequestTime, equals(150.0));
        expect(stats.successRate, equals(100.0));
        expect(stats.minRequestTime, equals(100));
        expect(stats.maxRequestTime, equals(200));
      });

      test('should record failed requests', () {
        stats.recordFailure(500);
        stats.recordSuccess(100);

        expect(stats.totalRequests, equals(2));
        expect(stats.successfulRequests, equals(1));
        expect(stats.failedRequests, equals(1));
        expect(stats.averageRequestTime, equals(300.0));
        expect(stats.successRate, equals(50.0));
        expect(stats.minRequestTime, equals(100));
        expect(stats.maxRequestTime, equals(500));
      });

      test('should handle single request for min/max times', () {
        stats.recordSuccess(150);

        expect(stats.minRequestTime, equals(150));
        expect(stats.maxRequestTime, equals(150));
      });

      test('should reset all statistics', () {
        stats.recordSuccess(100);
        stats.recordFailure(200);

        stats.reset();

        expect(stats.totalRequests, equals(0));
        expect(stats.successfulRequests, equals(0));
        expect(stats.failedRequests, equals(0));
        expect(stats.totalRequestTime, equals(0));
        expect(stats.minRequestTime, equals(0));
        expect(stats.maxRequestTime, equals(0));
        expect(stats.averageRequestTime, equals(0.0));
        expect(stats.successRate, equals(0.0));
      });

      test('should convert to JSON', () {
        stats.recordSuccess(100);
        stats.recordFailure(200);

        final json = stats.toJson();

        expect(json['totalRequests'], equals(2));
        expect(json['successfulRequests'], equals(1));
        expect(json['failedRequests'], equals(1));
        expect(json['totalRequestTimeMs'], equals(300));
        expect(json['averageRequestTimeMs'], equals(150.0));
        expect(json['successRate'], equals(50.0));
        expect(json['minRequestTimeMs'], equals(100));
        expect(json['maxRequestTimeMs'], equals(200));
      });
    });

    group('RPC Logging Configuration', () {
      test('should create default configuration', () {
        const config = RpcLoggingConfig();

        expect(config.logRequests, isTrue);
        expect(config.logResponses, isTrue);
        expect(config.logErrors, isTrue);
        expect(config.logTiming, isTrue);
        expect(config.logBodies, isFalse);
        expect(config.logPrefix, equals('[RPC]'));
      });

      test('should create debug configuration', () {
        const config = RpcLoggingConfig.debug;

        expect(config.logRequests, isTrue);
        expect(config.logResponses, isTrue);
        expect(config.logErrors, isTrue);
        expect(config.logTiming, isTrue);
        expect(config.logBodies, isTrue);
        expect(config.logPrefix, equals('[RPC-DEBUG]'));
      });

      test('should create production configuration', () {
        const config = RpcLoggingConfig.production;

        expect(config.logRequests, isFalse);
        expect(config.logResponses, isFalse);
        expect(config.logErrors, isTrue);
        expect(config.logTiming, isFalse);
        expect(config.logBodies, isFalse);
        expect(config.logPrefix, equals('[RPC]'));
      });

      test('should create custom configuration', () {
        const config = RpcLoggingConfig(
          logRequests: false,
          logResponses: true,
          logBodies: true,
          logPrefix: '[CUSTOM]',
        );

        expect(config.logRequests, isFalse);
        expect(config.logResponses, isTrue);
        expect(config.logBodies, isTrue);
        expect(config.logPrefix, equals('[CUSTOM]'));
      });
    });

    group('Enhanced RPC Client', () {
      late Connection connection;
      late EnhancedRpcClient client;

      setUp(() {
        connection = Connection('http://localhost:8899');
        client = EnhancedRpcClient(connection);
      });

      tearDown(() {
        client.close();
        connection.close();
      });

      test('should create client with connection', () {
        expect(client.connection, equals(connection));
        expect(client.networkType, equals(SolanaNetwork.localhost));
        expect(client.stats.totalRequests, equals(0));
      });

      test('should create client with custom logging config', () {
        const loggingConfig = RpcLoggingConfig.debug;
        final customClient =
            EnhancedRpcClient(connection, loggingConfig: loggingConfig);

        expect(customClient.connection, equals(connection));

        customClient.close();
      });

      test('should reset statistics', () {
        // Simulate some stats
        client.stats.recordSuccess(100);
        client.stats.recordFailure(200);

        expect(client.stats.totalRequests, equals(2));

        client.resetStats();

        expect(client.stats.totalRequests, equals(0));
      });

      test('should handle empty public keys list for getMultipleAccounts',
          () async {
        final result = await client.getMultipleAccounts([]);
        expect(result, isEmpty);
      });

      // Note: The following tests would require a real Solana RPC endpoint
      // In a real test environment, you might want to use a test validator
      // or mock the HTTP responses
    });

    group('Simulation Result', () {
      test('should create from JSON with success', () {
        final json = {
          'err': null,
          'logs': ['log1', 'log2'],
          'unitsConsumed': 1000,
        };

        final result = RpcSimulationResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.logs, equals(['log1', 'log2']));
        expect(result.computeUnits, equals(1000));
        expect(result.accounts, isNull);
      });

      test('should create from JSON with error', () {
        final json = {
          'err': 'Transaction failed',
          'logs': ['error log'],
          'unitsConsumed': 500,
        };

        final result = RpcSimulationResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, equals('Transaction failed'));
        expect(result.logs, equals(['error log']));
        expect(result.computeUnits, equals(500));
      });

      test('should handle missing fields in JSON', () {
        final json = <String, dynamic>{
          'err': null,
        };

        final result = RpcSimulationResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.logs, isEmpty);
        expect(result.computeUnits, isNull);
        expect(result.accounts, isNull);
      });
    });

    group('Network Health Status', () {
      test('should create healthy status', () {
        const status = NetworkHealthStatus(
          isHealthy: true,
          responseTimeMs: 150,
          currentSlot: 123456,
          version: '1.14.0',
          details: 'All systems operational',
        );

        expect(status.isHealthy, isTrue);
        expect(status.responseTimeMs, equals(150));
        expect(status.currentSlot, equals(123456));
        expect(status.version, equals('1.14.0'));
        expect(status.details, equals('All systems operational'));
      });

      test('should create unhealthy status', () {
        const status = NetworkHealthStatus(
          isHealthy: false,
          responseTimeMs: 5000,
          details: 'Connection timeout',
        );

        expect(status.isHealthy, isFalse);
        expect(status.responseTimeMs, equals(5000));
        expect(status.currentSlot, isNull);
        expect(status.version, isNull);
        expect(status.details, equals('Connection timeout'));
      });

      test('should convert to JSON', () {
        const status = NetworkHealthStatus(
          isHealthy: true,
          responseTimeMs: 150,
          currentSlot: 123456,
          version: '1.14.0',
          details: 'All good',
        );

        final json = status.toJson();

        expect(json['isHealthy'], isTrue);
        expect(json['responseTimeMs'], equals(150));
        expect(json['currentSlot'], equals(123456));
        expect(json['version'], equals('1.14.0'));
        expect(json['details'], equals('All good'));
      });

      test('should handle null fields in JSON', () {
        const status = NetworkHealthStatus(
          isHealthy: false,
          responseTimeMs: 1000,
        );

        final json = status.toJson();

        expect(json['isHealthy'], isFalse);
        expect(json['responseTimeMs'], equals(1000));
        expect(json.containsKey('currentSlot'), isFalse);
        expect(json.containsKey('version'), isFalse);
        expect(json.containsKey('details'), isFalse);
      });
    });

    group('Network Info', () {
      test('should create network info', () {
        const info = NetworkInfo(
          networkType: SolanaNetwork.devnet,
          rpcUrl: 'https://api.devnet.solana.com',
          version: '1.14.0',
          epoch: 500,
          slot: 123456789,
          totalSupply: 1000000000,
          circulatingSupply: 900000000,
        );

        expect(info.networkType, equals(SolanaNetwork.devnet));
        expect(info.rpcUrl, equals('https://api.devnet.solana.com'));
        expect(info.version, equals('1.14.0'));
        expect(info.epoch, equals(500));
        expect(info.slot, equals(123456789));
        expect(info.totalSupply, equals(1000000000));
        expect(info.circulatingSupply, equals(900000000));
      });

      test('should convert to JSON', () {
        const info = NetworkInfo(
          networkType: SolanaNetwork.mainnet,
          rpcUrl: 'https://api.mainnet-beta.solana.com',
          version: '1.14.0',
          epoch: 400,
          slot: 987654321,
          totalSupply: 500000000,
          circulatingSupply: 450000000,
        );

        final json = info.toJson();

        expect(json['networkType'], equals('mainnet'));
        expect(json['rpcUrl'], equals('https://api.mainnet-beta.solana.com'));
        expect(json['version'], equals('1.14.0'));
        expect(json['epoch'], equals(400));
        expect(json['slot'], equals(987654321));
        expect(json['totalSupply'], equals(500000000));
        expect(json['circulatingSupply'], equals(450000000));
      });

      test('should handle null version in JSON', () {
        const info = NetworkInfo(
          networkType: SolanaNetwork.localhost,
          rpcUrl: 'http://localhost:8899',
          epoch: 0,
          slot: 100,
          totalSupply: 0,
          circulatingSupply: 0,
        );

        final json = info.toJson();

        expect(json['networkType'], equals('localhost'));
        expect(json.containsKey('version'), isFalse);
      });
    });

    group('RPC Batcher', () {
      late Connection connection;
      late EnhancedRpcClient client;
      late RpcBatcher batcher;

      setUp(() {
        connection = Connection('http://localhost:8899');
        client = EnhancedRpcClient(connection);
        batcher = RpcBatcher(client,
            batchSize: 3, batchDelay: Duration(milliseconds: 50));
      });

      tearDown(() {
        batcher.close();
        client.close();
        connection.close();
      });

      test('should create batcher with client', () {
        expect(batcher, isNotNull);
      });

      test('should handle closing with no pending requests', () {
        expect(() => batcher.close(), returnsNormally);
      });

      // Note: Testing actual batching would require mocking HTTP responses
      // or using a real Solana RPC endpoint
    });

    group('Edge Cases and Error Handling', () {
      test('should handle malformed JSON in simulation result', () {
        final json = <String, dynamic>{
          'err': {'code': 123, 'message': 'error'},
          'logs': null,
        };

        final result = RpcSimulationResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, equals('{code: 123, message: error}'));
        expect(result.logs, isEmpty);
      });

      test('should handle very large response times in stats', () {
        final stats = RpcPerformanceStats();

        stats.recordSuccess(999999);
        stats.recordFailure(1000000);

        expect(stats.maxRequestTime, equals(1000000));
        expect(stats.minRequestTime, equals(999999));
        expect(stats.averageRequestTime, equals(999999.5));
      });

      test('should handle zero request time', () {
        final stats = RpcPerformanceStats();

        stats.recordSuccess(0);

        expect(stats.minRequestTime, equals(0));
        expect(stats.maxRequestTime, equals(0));
        expect(stats.averageRequestTime, equals(0.0));
      });
    });

    group('Integration Tests', () {
      test('should properly export all classes and functions', () {
        // Test that all expected exports are available
        expect(SolanaNetwork.values, isNotEmpty);
        expect(RpcPerformanceStats, isNotNull);
        expect(RpcLoggingConfig, isNotNull);
        expect(EnhancedRpcClient, isNotNull);
        expect(RpcSimulationResult, isNotNull);
        expect(NetworkHealthStatus, isNotNull);
        expect(NetworkInfo, isNotNull);
        expect(RpcBatcher, isNotNull);

        // Test utility functions
        expect(detectNetwork, isNotNull);
        expect(getDefaultRpcUrl, isNotNull);
        expect(getDefaultWebSocketUrl, isNotNull);
        expect(createNetworkConfig, isNotNull);
      });

      test('should maintain consistent network type detection', () {
        final networks = [
          'https://api.mainnet-beta.solana.com',
          'https://api.testnet.solana.com',
          'https://api.devnet.solana.com',
          'http://localhost:8899',
          'https://custom.example.com',
        ];

        final expected = [
          SolanaNetwork.mainnet,
          SolanaNetwork.testnet,
          SolanaNetwork.devnet,
          SolanaNetwork.localhost,
          SolanaNetwork.custom,
        ];

        for (int i = 0; i < networks.length; i++) {
          expect(detectNetwork(networks[i]), equals(expected[i]));
        }
      });

      test('should create valid configurations for all network types', () {
        for (final network in [
          SolanaNetwork.mainnet,
          SolanaNetwork.testnet,
          SolanaNetwork.devnet,
          SolanaNetwork.localhost
        ]) {
          final config = createNetworkConfig(network);

          expect(config.rpcUrl, isNotEmpty);
          expect(config.websocketUrl, isNotNull);
          expect(config.timeoutMs, greaterThan(0));
          expect(config.retryAttempts, greaterThan(0));
        }
      });
    });
  });
}
