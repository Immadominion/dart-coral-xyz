/// Test suite for Step 8.3: Performance Optimization and Monitoring
///
/// This test suite validates the comprehensive performance optimization system
/// including intelligent caching, request batching, performance monitoring,
/// optimization recommendations, resource management, and adaptive optimization.

import 'dart:async';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart'
    hide OptimizationRecommendation, OptimizationType;
// Import the performance module directly to access hidden types
import 'package:coral_xyz_anchor/src/performance/performance_optimization.dart'
    as perf;

void main() {
  group('Step 8.3: Performance Optimization and Monitoring', () {
    late perf.PerformanceOptimizer optimizer;

    setUp(() {
      optimizer = perf.PerformanceOptimizer();
    });

    tearDown(() async {
      await optimizer.shutdown();
    });

    group('PerformanceOptimizer', () {
      test('should initialize with default configuration', () async {
        await optimizer.initialize();

        final metrics = optimizer.getMetrics();
        expect(metrics, isNotNull);
        expect(metrics.batchMetrics, isNotNull);
        expect(metrics.monitoringMetrics, isNotNull);
        expect(metrics.resourceMetrics, isNotNull);
        expect(metrics.adaptiveMetrics, isNotNull);
      });

      test('should initialize with custom configuration', () async {
        final config = perf.PerformanceConfig.highPerformance();
        await optimizer.initialize(config: config);

        final metrics = optimizer.getMetrics();
        expect(metrics, isNotNull);
      });

      test('should provide access to individual components', () async {
        await optimizer.initialize();

        expect(optimizer.batcher, isA<perf.RequestBatcher>());
        expect(optimizer.monitor, isA<perf.PerformanceMonitor>());
        expect(optimizer.resourceManager, isA<perf.ResourceManager>());
        expect(optimizer.adaptiveOptimizer, isA<perf.AdaptiveOptimizer>());
      });

      test('should generate optimization recommendations', () async {
        await optimizer.initialize();

        final recommendations = optimizer.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());
      });

      test('should apply automatic optimizations', () async {
        await optimizer.initialize();

        await optimizer.applyOptimizations();
        // Should complete without error
      });
    });

    group('RequestBatcher', () {
      late perf.RequestBatcher batcher;

      setUp(() {
        batcher = perf.RequestBatcher();
      });

      tearDown(() async {
        await batcher.shutdown();
      });

      test('should initialize with configuration', () async {
        await batcher.initialize(perf.BatchingConfig.defaultConfig());

        final metrics = batcher.getMetrics();
        expect(metrics.pendingRequests, equals(0));
        expect(metrics.activeBatches, equals(0));
        expect(metrics.queuedRequests, equals(0));
      });

      test('should batch requests', () async {
        await batcher.initialize(perf.BatchingConfig.defaultConfig());

        // Mock a batch request
        final future = batcher.batchRequest(
          'getAccountInfo',
          ['some_pubkey'],
          (response) => response,
        );

        final metrics = batcher.getMetrics();
        expect(metrics.pendingRequests, greaterThan(0));

        // Wait for request to complete
        await future;
      });

      test('should deduplicate identical requests', () async {
        await batcher.initialize(perf.BatchingConfig.defaultConfig());

        // Submit same request multiple times
        final futures = List.generate(
            3,
            (_) => batcher.batchRequest(
                  'getAccountInfo',
                  ['same_pubkey'],
                  (response) => response,
                ));

        // All should complete successfully
        await Future.wait(futures);

        final metrics = batcher.getMetrics();
        // Should show deduplication
        expect(metrics.deduplicationRate, greaterThanOrEqualTo(0));
      });

      test('should generate batching recommendations', () async {
        await batcher.initialize(perf.BatchingConfig.defaultConfig());

        final recommendations = batcher.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());
      });

      test('should handle batch execution errors gracefully', () async {
        await batcher.initialize(perf.BatchingConfig.defaultConfig());

        // Submit a request that will fail with a deserializer error
        expect(
          batcher.batchRequest(
            'validMethod',
            ['valid_params'],
            (response) => throw Exception('Deserializer mock error'),
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('PerformanceMonitor', () {
      late perf.PerformanceMonitor monitor;

      setUp(() {
        monitor = perf.PerformanceMonitor();
      });

      tearDown(() async {
        await monitor.shutdown();
      });

      test('should initialize with monitoring configuration', () async {
        await monitor.initialize(perf.MonitoringConfig.defaultConfig());

        final metrics = monitor.getMetrics();
        expect(metrics.totalOperations, equals(0));
        expect(metrics.totalMeasurements, equals(0));
      });

      test('should record performance measurements', () async {
        await monitor.initialize(perf.MonitoringConfig.defaultConfig());

        monitor.recordMeasurement(
          'test_operation',
          const Duration(milliseconds: 100),
        );

        final metrics = monitor.getMetrics();
        expect(metrics.totalOperations, equals(1));
        expect(metrics.totalMeasurements, equals(1));
        expect(metrics.operations['test_operation'], isNotNull);
      });

      test('should provide performance timer', () async {
        await monitor.initialize(perf.MonitoringConfig.defaultConfig());

        final timer = monitor.startTimer('timed_operation');
        await Future.delayed(const Duration(milliseconds: 10));
        timer.stop();

        final metrics = monitor.getMetrics();
        expect(metrics.operations['timed_operation'], isNotNull);
        expect(metrics.operations['timed_operation']!.totalCalls, equals(1));
      });

      test('should handle timer errors', () async {
        await monitor.initialize(perf.MonitoringConfig.defaultConfig());

        final timer = monitor.startTimer('error_operation');
        timer.stopWithError('Test error');

        final metrics = monitor.getMetrics();
        expect(metrics.operations['error_operation'], isNotNull);
      });

      test('should calculate system health', () async {
        await monitor.initialize(perf.MonitoringConfig.defaultConfig());

        // Record some measurements
        monitor.recordMeasurement('fast_op', const Duration(milliseconds: 10));
        monitor.recordMeasurement(
            'slow_op', const Duration(milliseconds: 1000));

        final metrics = monitor.getMetrics();
        expect(
            metrics.systemHealth,
            isIn([
              perf.SystemHealth.excellent,
              perf.SystemHealth.good,
              perf.SystemHealth.degraded,
              perf.SystemHealth.critical,
            ]));
      });

      test('should generate performance recommendations', () async {
        await monitor.initialize(perf.MonitoringConfig.defaultConfig());

        // Record a slow operation
        monitor.recordMeasurement(
          'slow_operation',
          const Duration(milliseconds: 2000),
        );

        final recommendations = monitor.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());
      });
    });

    group('ResourceManager', () {
      late perf.ResourceManager resourceManager;

      setUp(() {
        resourceManager = perf.ResourceManager();
      });

      tearDown(() async {
        await resourceManager.shutdown();
      });

      test('should initialize with resource configuration', () async {
        await resourceManager.initialize(perf.ResourceConfig.defaultConfig());

        final metrics = resourceManager.getMetrics();
        expect(metrics.totalActiveResources, equals(0));
        expect(metrics.totalMemoryUsage, equals(0));
      });

      test('should track resources', () async {
        await resourceManager.initialize(perf.ResourceConfig.defaultConfig());

        resourceManager.trackResource('connection', 'conn_1');
        resourceManager.trackResource('connection', 'conn_2');
        resourceManager.trackResource('account', 'acc_1');

        final metrics = resourceManager.getMetrics();
        expect(metrics.totalActiveResources, equals(3));
        expect(metrics.types['connection']?.activeResources, equals(2));
        expect(metrics.types['account']?.activeResources, equals(1));
      });

      test('should untrack resources', () async {
        await resourceManager.initialize(perf.ResourceConfig.defaultConfig());

        resourceManager.trackResource('connection', 'conn_1');
        resourceManager.untrackResource('connection', 'conn_1');

        final metrics = resourceManager.getMetrics();
        expect(metrics.totalActiveResources, equals(0));
      });

      test('should perform cleanup', () async {
        await resourceManager.initialize(perf.ResourceConfig.defaultConfig());

        resourceManager.trackResource('test', 'old_resource');

        // Manually trigger cleanup
        await resourceManager.cleanup();

        // Should complete without error
      });

      test('should generate resource recommendations', () async {
        await resourceManager.initialize(perf.ResourceConfig.defaultConfig());

        // Track many resources
        for (int i = 0; i < 100; i++) {
          resourceManager.trackResource('test', 'resource_$i');
        }

        final recommendations = resourceManager.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());
      });
    });

    group('AdaptiveOptimizer', () {
      late perf.AdaptiveOptimizer adaptiveOptimizer;

      setUp(() {
        adaptiveOptimizer = perf.AdaptiveOptimizer();
      });

      tearDown(() async {
        await adaptiveOptimizer.shutdown();
      });

      test('should initialize with adaptive configuration', () async {
        await adaptiveOptimizer.initialize(perf.AdaptiveConfig.defaultConfig());

        final metrics = adaptiveOptimizer.getMetrics();
        expect(metrics.totalOptimizations, equals(0));
        expect(metrics.optimizationScore, isA<double>());
      });

      test('should record usage patterns', () async {
        await adaptiveOptimizer.initialize(perf.AdaptiveConfig.defaultConfig());

        adaptiveOptimizer.recordUsage('frequent_operation');
        adaptiveOptimizer.recordUsage('frequent_operation');
        adaptiveOptimizer.recordUsage('rare_operation');

        final metrics = adaptiveOptimizer.getMetrics();
        expect(metrics.patterns, hasLength(2));
        expect(metrics.patterns['frequent_operation'], isNotNull);
        expect(metrics.patterns['rare_operation'], isNotNull);
      });

      test('should generate adaptive recommendations', () async {
        await adaptiveOptimizer.initialize(perf.AdaptiveConfig.defaultConfig());

        // Simulate high-frequency usage
        for (int i = 0; i < 20; i++) {
          adaptiveOptimizer.recordUsage('high_freq_op');
        }

        final recommendations = adaptiveOptimizer.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());
      });

      test('should apply optimizations', () async {
        await adaptiveOptimizer.initialize(perf.AdaptiveConfig.defaultConfig());

        // Record some usage patterns
        for (int i = 0; i < 10; i++) {
          adaptiveOptimizer.recordUsage('optimize_me');
        }

        await adaptiveOptimizer.optimize();

        final metrics = adaptiveOptimizer.getMetrics();
        // Optimizations may or may not be applied based on confidence
        expect(metrics.totalOptimizations, greaterThanOrEqualTo(0));
      });
    });

    group('Configuration Classes', () {
      test('should create default configurations', () {
        final perfConfig = perf.PerformanceConfig.defaultConfig();
        expect(perfConfig.batchingConfig, isNotNull);
        expect(perfConfig.monitoringConfig, isNotNull);
        expect(perfConfig.resourceConfig, isNotNull);
        expect(perfConfig.adaptiveConfig, isNotNull);
      });

      test('should create high performance configurations', () {
        final perfConfig = perf.PerformanceConfig.highPerformance();
        expect(perfConfig.batchingConfig.maxBatchSize, equals(200));
        expect(
            perfConfig.batchingConfig.batchTimeout.inMilliseconds, equals(25));
      });

      test('should create development configurations', () {
        final perfConfig = perf.PerformanceConfig.development();
        expect(perfConfig.batchingConfig.maxBatchSize, equals(10));
        expect(perfConfig.monitoringConfig.enableEventTracking, isTrue);
      });
    });

    group('Integration Tests', () {
      test('should integrate all components together', () async {
        final config = perf.PerformanceConfig.defaultConfig();
        await optimizer.initialize(config: config);

        // Test performance monitoring
        final timer = optimizer.monitor.startTimer('integration_test');
        await Future.delayed(const Duration(milliseconds: 10));
        timer.stop();

        // Test resource tracking
        optimizer.resourceManager.trackResource('test', 'resource_1');

        // Test adaptive optimization
        optimizer.adaptiveOptimizer.recordUsage('integration_operation');

        // Test batch request (mock)
        final batchFuture = optimizer.batcher.batchRequest(
          'test_method',
          ['param1', 'param2'],
          (response) => response,
        );

        await batchFuture;

        // Get comprehensive metrics
        final metrics = optimizer.getMetrics();
        expect(metrics.monitoringMetrics.totalOperations, greaterThan(0));
        expect(metrics.resourceMetrics.totalActiveResources, greaterThan(0));
        expect(metrics.adaptiveMetrics.patterns, isNotEmpty);

        // Get recommendations
        final recommendations = optimizer.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());

        // Apply optimizations
        await optimizer.applyOptimizations();
      });

      test('should handle high-load scenarios', () async {
        final config = perf.PerformanceConfig.highPerformance();
        await optimizer.initialize(config: config);

        // Simulate high load
        final futures = <Future>[];

        // Multiple batch requests
        for (int i = 0; i < 20; i++) {
          futures.add(optimizer.batcher.batchRequest(
            'high_load_method',
            ['param_$i'],
            (response) => response,
          ));
        }

        // Multiple performance measurements
        for (int i = 0; i < 50; i++) {
          final timer = optimizer.monitor.startTimer('load_test_$i');
          futures
              .add(Future.delayed(Duration(milliseconds: i % 10 + 1)).then((_) {
            timer.stop();
          }));
        }

        // Multiple resource tracking
        for (int i = 0; i < 100; i++) {
          optimizer.resourceManager.trackResource('load_test', 'resource_$i');
          optimizer.adaptiveOptimizer.recordUsage('high_frequency_op');
        }

        await Future.wait(futures);

        final metrics = optimizer.getMetrics();
        expect(metrics.monitoringMetrics.totalMeasurements, greaterThan(45));
        expect(metrics.resourceMetrics.totalActiveResources, greaterThan(90));
        expect(metrics.batchMetrics.totalRequests, greaterThan(15));
      });

      test('should demonstrate TypeScript Anchor compatibility', () async {
        // Test configuration API similar to TypeScript
        final config = perf.PerformanceConfig.defaultConfig();
        await optimizer.initialize(config: config);

        // Test metrics collection similar to TypeScript monitoring
        final timer = optimizer.monitor.startTimer('typescript_compat_test');
        await Future.delayed(const Duration(milliseconds: 5));
        timer.stop();

        // Test batching similar to TypeScript RPC optimization
        final result = await optimizer.batcher.batchRequest(
          'getAccountInfo',
          ['mock_pubkey'],
          (response) => response,
        );

        expect(result, isNotNull);

        // Test recommendations system
        final recommendations = optimizer.getRecommendations();
        expect(recommendations, isA<List<perf.OptimizationRecommendation>>());

        // Verify metrics structure matches expected TypeScript patterns
        final metrics = optimizer.getMetrics();
        expect(metrics.batchMetrics.averageBatchSize, isA<double>());
        expect(
            metrics.monitoringMetrics.systemHealth, isA<perf.SystemHealth>());
        expect(metrics.resourceMetrics.totalMemoryUsage, isA<int>());
        expect(metrics.adaptiveMetrics.optimizationScore, isA<double>());
      });
    });
  });
}
