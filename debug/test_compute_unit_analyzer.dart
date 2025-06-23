import 'package:test/test.dart';
import '../lib/src/transaction/compute_unit_analyzer.dart';
import '../lib/src/transaction/transaction_simulator.dart';
import '../lib/src/provider/anchor_provider.dart';
import '../lib/src/provider/connection.dart';
import '../lib/src/provider/wallet.dart';
import '../lib/src/types/keypair.dart';

void main() {
  group('ComputeUnitAnalyzer', () {
    late ComputeUnitAnalyzer analyzer;
    late AnchorProvider mockProvider;

    setUpAll(() async {
      final connection = Connection('https://api.devnet.solana.com');
      final keypair = await Keypair.generate();
      final wallet = KeypairWallet(keypair);
      mockProvider = AnchorProvider(connection, wallet);
      analyzer = ComputeUnitAnalyzer(provider: mockProvider);
    });

    group('Compute Unit Analysis', () {
      test('should analyze compute units from simulation results', () async {
        final simulationResult = TransactionSimulationResult(
          success: true,
          logs: [
            'Program ComputeBudget111111111111111111111111111111 invoke [1]',
            'Program ComputeBudget111111111111111111111111111111 success',
            'Program 11111111111111111111111111111111 invoke [1]',
            'Program 11111111111111111111111111111111 success',
            'Program consumed 150000 of 200000 compute units',
          ],
          error: null,
          unitsConsumed: 150000,
          returnData: null,
          accounts: null,
        );

        final result = await analyzer.analyzeComputeUnits(
          simulationResult: simulationResult,
          instructionCount: 2,
          accountKeys: ['account1', 'account2', 'account3'],
        );

        expect(result.totalComputeUnits, equals(150000));
        expect(result.breakdown.instructionCount, equals(2));
        expect(result.breakdown.accountCount, equals(3));
        expect(result.breakdown.totalUnits, equals(150000));
        expect(result.feeEstimates.baseTransactionFee, equals(5000));
        expect(result.transactionComplexity, isA<TransactionComplexity>());
        expect(result.optimizationRecommendations,
            isA<List<OptimizationRecommendation>>());
      });

      test(
          'should generate optimization recommendations for high compute usage',
          () async {
        final simulationResult = TransactionSimulationResult(
          success: true,
          logs: ['Program consumed 850000 of 1000000 compute units'],
          error: null,
          unitsConsumed: 850000,
          returnData: null,
          accounts: null,
        );

        final result = await analyzer.analyzeComputeUnits(
          simulationResult: simulationResult,
          instructionCount: 15,
          accountKeys: List.generate(25, (i) => 'account$i'),
        );

        expect(result.optimizationRecommendations.length, greaterThan(0));

        final hasComputeUnitRecommendation = result.optimizationRecommendations
            .any((r) => r.type == OptimizationType.computeUnitReduction);
        expect(hasComputeUnitRecommendation, isTrue);

        final hasInstructionRecommendation = result.optimizationRecommendations
            .any((r) => r.type == OptimizationType.instructionOptimization);
        expect(hasInstructionRecommendation, isTrue);

        final hasAccountRecommendation = result.optimizationRecommendations
            .any((r) => r.type == OptimizationType.accountOptimization);
        expect(hasAccountRecommendation, isTrue);
      });

      test('should calculate transaction complexity correctly', () async {
        final simpleResult = TransactionSimulationResult(
          success: true,
          logs: [],
          error: null,
          unitsConsumed: 30000,
          returnData: null,
          accounts: null,
        );

        final complexResult = TransactionSimulationResult(
          success: true,
          logs: [],
          error: null,
          unitsConsumed: 800000,
          returnData: null,
          accounts: null,
        );

        final simple = await analyzer.analyzeComputeUnits(
          simulationResult: simpleResult,
          instructionCount: 1,
          accountKeys: ['account1'],
        );

        final complex = await analyzer.analyzeComputeUnits(
          simulationResult: complexResult,
          instructionCount: 20,
          accountKeys: List.generate(30, (i) => 'account$i'),
        );

        expect(
            simple.transactionComplexity, equals(TransactionComplexity.simple));
        expect(complex.transactionComplexity,
            equals(TransactionComplexity.veryComplex));
      });
    });

    group('Fee Estimation', () {
      test('should estimate fees for different strategies', () async {
        final economyResult = await analyzer.estimateFees(
          estimatedComputeUnits: 100000,
          instructionCount: 2,
          strategy: FeeEstimationStrategy.economy,
        );

        final urgentResult = await analyzer.estimateFees(
          estimatedComputeUnits: 100000,
          instructionCount: 2,
          strategy: FeeEstimationStrategy.urgent,
        );

        expect(economyResult.strategy, equals(FeeEstimationStrategy.economy));
        expect(urgentResult.strategy, equals(FeeEstimationStrategy.urgent));
        expect(urgentResult.totalFee, greaterThan(economyResult.totalFee));
        expect(economyResult.baseTransactionFee, equals(5000));
        expect(urgentResult.baseTransactionFee, equals(5000));
      });

      test('should include base transaction fee in estimates', () async {
        final result = await analyzer.estimateFees(
          estimatedComputeUnits: 0,
          instructionCount: 1,
          strategy: FeeEstimationStrategy.economy,
        );

        expect(result.baseTransactionFee, equals(5000));
        expect(result.totalFee, greaterThanOrEqualTo(5000));
      });
    });

    group('Budget Recommendations', () {
      test('should generate budget recommendations', () {
        final recommendation = analyzer.generateBudgetRecommendation(
          estimatedComputeUnits: 100000,
          analysisResult: null,
          safetyMargin: 0.2,
        );

        expect(recommendation.estimatedUsage, equals(100000));
        expect(recommendation.recommendedBudget, equals(120000));
        expect(recommendation.safetyMargin, equals(0.2));
        expect(recommendation.utilizationPercentage, closeTo(83.33, 0.1));
        expect(recommendation.isWithinLimits, isTrue);
        expect(recommendation.maxAllowedUnits, equals(1400000));
      });
    });

    group('Error Handling', () {
      test('should handle failed simulations gracefully', () async {
        final failedResult = TransactionSimulationResult(
          success: false,
          logs: ['Program failed'],
          error: TransactionSimulationError(
            type: 'InstructionError',
            details: 'Simulation failed',
          ),
          unitsConsumed: null,
          returnData: null,
          accounts: null,
        );

        final result = await analyzer.analyzeComputeUnits(
          simulationResult: failedResult,
          instructionCount: 1,
        );

        expect(result.totalComputeUnits, equals(0));
        expect(result.breakdown.totalUnits, equals(0));
      });
    });

    group('Configuration', () {
      test('should respect cache configuration', () {
        final config = ComputeUnitAnalysisConfig(
          enableCaching: false,
          cacheTimeout: Duration(minutes: 10),
          maxCacheSize: 50,
        );

        final analyzerWithConfig = ComputeUnitAnalyzer(
          provider: mockProvider,
          config: config,
        );

        expect(analyzerWithConfig, isA<ComputeUnitAnalyzer>());
      });
    });
  });
}
