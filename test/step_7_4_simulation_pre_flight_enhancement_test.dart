import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart'
    show TransactionSimulationResult;

void main() {
  group('Step 7.4: Simulation and Pre-flight Enhancement', () {
    late EnhancedSimulationAnalyzer analyzer;
    late SimulationCacheManager cacheManager;
    late SimulationDebugger debugger;

    setUp(() {
      analyzer = EnhancedSimulationAnalyzer();
      cacheManager = SimulationCacheManager();
      debugger = SimulationDebugger(cacheManager: cacheManager);
    });

    group('Enhanced Simulation Analysis', () {
      test('should analyze simulation with comprehensive results', () async {
        // Create a mock simulation result with high compute usage
        final simulation = const TransactionSimulationResult(
          success: true,
          logs: [
            'Program 11111111111111111111111111111111 invoke [1]',
            'Program log: Hello, World!',
            'Program 11111111111111111111111111111111 success',
          ],
          unitsConsumed:
              800000, // High compute usage to trigger recommendations
          accounts: {
            'account1': {
              'pubkey': '11111111111111111111111111111111',
              'writable': true,
              'signer': false,
              'data': [1, 2, 3, 4, 5],
            },
            'account2': {
              'pubkey': '22222222222222222222222222222222',
              'writable': false,
              'signer': true,
              'data': [6, 7, 8],
            },
          },
        );

        final analysis = await analyzer.analyzeSimulation(simulation);

        expect(analysis.simulationId, isNotEmpty);
        expect(analysis.computeAnalysis.unitsConsumed, equals(800000));
        expect(analysis.accountAnalysis.totalAccounts, equals(2));
        expect(analysis.accountAnalysis.writableAccounts, equals(1));
        expect(analysis.accountAnalysis.signerAccounts, equals(1));
        expect(analysis.performanceMetrics.computeUnitsUsed, equals(800000));
        expect(analysis.optimizationRecommendations, isNotEmpty);
      });

      test(
          'should generate optimization recommendations for high compute usage',
          () async {
        // Create simulation with high compute usage
        final simulation = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Heavy computation'],
          unitsConsumed: 1200000, // High usage
        );

        final analysis = await analyzer.analyzeSimulation(simulation);

        expect(analysis.optimizationRecommendations, isNotEmpty);
        final computeRec = analysis.optimizationRecommendations
            .where((r) => r.title.contains('Compute'));
        expect(computeRec, isNotEmpty);
      });

      test('should detect issues and warnings for failed simulations',
          () async {
        // Create simulation with error
        final simulation = const TransactionSimulationResult(
          success: false,
          logs: ['Program error: Something went wrong'],
          error: TransactionSimulationError(
            type: 'InstructionError',
            instructionIndex: 0,
            details: 'Custom error',
          ),
        );

        final analysis = await analyzer.analyzeSimulation(simulation);

        expect(analysis.issueAnalysis.issues, isNotEmpty);
        expect(
            analysis.issueAnalysis.overallRisk, isNot(equals(RiskLevel.low)),);
      });

      test('should compare multiple simulations', () async {
        final simulation1 = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: First'],
          unitsConsumed: 5000,
        );

        final simulation2 = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Second'],
          unitsConsumed: 7000,
        );

        final comparison =
            await analyzer.compareSimulations([simulation1, simulation2]);

        expect(comparison.baseline, isNotNull);
        expect(comparison.comparisons, hasLength(1));
        expect(
            comparison.comparisons.first.computeUnitsDifference, equals(2000),);
        expect(comparison.summary.bestPerforming, isA<int>());
      });

      test('should export analysis results in different formats', () async {
        final simulation = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Export test'],
          unitsConsumed: 5000,
        );

        final analysis = await analyzer.analyzeSimulation(simulation);

        // Test JSON export
        final jsonExport = await analyzer.exportAnalysis(
          analysis,
          format: ExportFormat.json,
        );
        expect(jsonExport.format, equals(ExportFormat.json));
        expect(jsonExport.data, isNotEmpty);
        expect(jsonExport.data, contains('simulation'));

        // Test CSV export
        final csvExport = await analyzer.exportAnalysis(
          analysis,
          format: ExportFormat.csv,
        );
        expect(csvExport.format, equals(ExportFormat.csv));
        expect(csvExport.data, contains('Property,Value'));
      });
    });

    group('Simulation Caching and Replay', () {
      test('should cache and retrieve simulation results', () {
        final simulation = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Cache test'],
          unitsConsumed: 5000,
        );

        final key = cacheManager.cacheSimulation(simulation);

        expect(key, isNotEmpty);

        final cached = cacheManager.getSimulation(key);
        expect(cached, isNotNull);
        expect(cached!.simulation.logs, equals(simulation.logs));
        expect(cached.accessCount, equals(1));
      });

      test('should create and replay sessions', () async {
        // Cache some simulations
        final simulations = List.generate(
            3,
            (i) => TransactionSimulationResult(
                  success: true,
                  logs: ['Program log: Replay $i'],
                  unitsConsumed: 5000 + i * 1000,
                ),);

        final keys =
            simulations.map((s) => cacheManager.cacheSimulation(s)).toList();

        // Create replay session
        final session = cacheManager.createReplaySession(
          name: 'Test Replay',
          simulationKeys: keys,
        );

        expect(session.name, equals('Test Replay'));
        expect(session.simulations, hasLength(3));
        expect(session.missingKeys, isEmpty);

        // Replay the session
        final replayResult = await cacheManager.replaySession(session.id);

        expect(replayResult.results, hasLength(3));
        expect(replayResult.summary.totalSteps, equals(3));
        expect(replayResult.summary.successfulSteps, equals(3));
        expect(replayResult.summary.failedSteps, equals(0));
      });

      test('should provide cache performance metrics', () {
        final simulation = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Metrics test'],
          unitsConsumed: 5000,
        );

        // Cache and access simulation
        final key = cacheManager.cacheSimulation(simulation);
        cacheManager.getSimulation(key); // Hit
        cacheManager.getSimulation('nonexistent'); // Miss

        final metrics = cacheManager.getPerformanceMetrics();

        expect(metrics.simulationCacheSize, equals(1));
        expect(metrics.simulationHitRate, equals(0.5)); // 1 hit, 1 miss
        expect(metrics.totalSimulationsCached, equals(1));
      });
    });

    group('Simulation Debugging and Development Tools', () {
      test('should create and manage debug sessions', () {
        final session = debugger.startDebugSession(name: 'Test Debug Session');

        expect(session.name, equals('Test Debug Session'));
        expect(session.steps, isEmpty);
        expect(session.startTime, isNotNull);

        final activeSessions = debugger.getActiveSessions();
        expect(activeSessions, contains(session));
      });

      test('should add simulation steps to debug session', () async {
        final session = debugger.startDebugSession(name: 'Step Test');

        final simulation = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Debug step'],
          unitsConsumed: 5000,
        );

        final stepResult = await debugger.addSimulationStep(
          session.id,
          simulation,
          stepName: 'First Step',
        );

        expect(stepResult.success, isTrue);
        expect(stepResult.step.name, equals('First Step'));
        expect(stepResult.step.analysis, isNotNull);
        expect(session.steps, hasLength(1));
      });

      test('should generate debug reports', () async {
        final session = debugger.startDebugSession(name: 'Report Test');

        // Add multiple steps
        for (int i = 0; i < 3; i++) {
          final simulation = TransactionSimulationResult(
            success: true,
            logs: ['Program log: Step $i'],
            unitsConsumed: 5000 + i * 1000,
          );

          await debugger.addSimulationStep(
            session.id,
            simulation,
            stepName: 'Step $i',
          );
        }

        final report = await debugger.generateDebugReport(session.id);

        expect(report.session.steps, hasLength(3));
        expect(report.flowAnalysis.steps, hasLength(3));
        expect(report.flowAnalysis.successRate, equals(1.0));
        expect(report.patterns, isNotNull);
        expect(report.optimizations, isNotNull);
      });

      test('should export debug session data', () async {
        final session = debugger.startDebugSession(name: 'Export Test');

        final simulation = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Export step'],
          unitsConsumed: 5000,
        );

        await debugger.addSimulationStep(
          session.id,
          simulation,
          stepName: 'Export Step',
        );

        // Test JSON export
        final jsonExport = await debugger.exportSession(
          session.id,
          format: DebugExportFormat.json,
        );

        expect(jsonExport.format, equals(DebugExportFormat.json));
        expect(jsonExport.data, isNotEmpty);
        expect(jsonExport.itemCount, equals(1));
      });
    });

    group('Integration Tests', () {
      test('should integrate all simulation enhancement features', () async {
        // Start debug session
        final session = debugger.startDebugSession(name: 'Integration Test');

        // Create test simulations with varying characteristics
        final simulations = [
          const TransactionSimulationResult(
            success: true,
            logs: ['Program log: Baseline'],
            unitsConsumed: 700000, // High usage to trigger recommendations
          ),
          const TransactionSimulationResult(
            success: true,
            logs: ['Program log: Optimized'],
            unitsConsumed: 600000, // High usage to trigger recommendations
          ),
          const TransactionSimulationResult(
            success: true, // Changed to successful to get analysis
            logs: ['Program log: Another test'],
            unitsConsumed: 400000, // Still high enough
          ),
        ];

        // Add steps to debug session
        for (int i = 0; i < simulations.length; i++) {
          await debugger.addSimulationStep(
            session.id,
            simulations[i],
            stepName: 'Integration Step $i',
          );
        }

        // Generate comprehensive report
        final report = await debugger.generateDebugReport(session.id);

        expect(report.session.steps, hasLength(3));
        expect(
            report.flowAnalysis.successRate, closeTo(1.0, 0.01),); // 3/3 success
        expect(report.optimizations, isNotEmpty);

        // Test batch analysis
        final successfulSimulations =
            simulations.where((s) => s.success).toList();
        final batchResult = await analyzer.analyzeBatch(successfulSimulations);

        expect(batchResult.analyses, hasLength(3)); // All 3 are successful now

        // Test comparison
        final comparison =
            await analyzer.compareSimulations(successfulSimulations);

        expect(comparison.comparisons,
            hasLength(2),); // 3 simulations = 2 comparisons
        expect(comparison.comparisons.first.computeUnitsDifference,
            equals(-100000),); // 700000 - 600000
      });

      test('should handle error conditions gracefully', () async {
        // Test with invalid session ID
        expect(
          () => debugger.generateDebugReport('invalid_session'),
          throwsArgumentError,
        );

        // Test with empty simulation list
        final emptyBatch = await analyzer.analyzeBatch([]);
        expect(emptyBatch.analyses, isEmpty);
        expect(emptyBatch.errors, isEmpty);

        // Test cache with missing simulation
        final nonExistent = cacheManager.getSimulation('missing');
        expect(nonExistent, isNull);

        // Test comparison with single simulation
        final singleSim = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Single'],
          unitsConsumed: 5000,
        );

        final singleComparison = await analyzer.compareSimulations([singleSim]);
        expect(singleComparison.comparisons, isEmpty);
      });
    });

    tearDown(() {
      // Clean up cache and close debug sessions
      cacheManager.clearCache();
      for (final session in debugger.getActiveSessions()) {
        debugger.closeSession(session.id);
      }
    });
  });
}
