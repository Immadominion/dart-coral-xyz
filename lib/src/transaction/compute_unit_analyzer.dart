import '../provider/anchor_provider.dart';
import 'transaction_simulator.dart';

/// Compute unit analysis and fee estimation for transactions
class ComputeUnitAnalyzer {
  final AnchorProvider _provider;
  final ComputeUnitAnalysisConfig _config;
  final Map<String, ComputeUnitAnalysisResult> _analysisCache = {};

  ComputeUnitAnalyzer({
    required AnchorProvider provider,
    ComputeUnitAnalysisConfig? config,
  })  : _provider = provider,
        _config = config ?? ComputeUnitAnalysisConfig();

  /// Analyze compute unit consumption from simulation results
  Future<ComputeUnitAnalysisResult> analyzeComputeUnits({
    required TransactionSimulationResult simulationResult,
    required int instructionCount,
    List<String>? accountKeys,
    Map<String, dynamic>? transactionContext,
  }) async {
    // Calculate cache key for result caching
    final cacheKey = _generateCacheKey(
      simulationResult,
      instructionCount,
      accountKeys,
    );

    // Check cache first
    if (_config.enableCaching && _analysisCache.containsKey(cacheKey)) {
      final cached = _analysisCache[cacheKey]!;
      if (!_isCacheExpired(cached)) {
        return cached;
      }
    }

    final consumedUnits = simulationResult.unitsConsumed ?? 0;

    // Analyze compute unit breakdown
    final breakdown = _analyzeComputeUnitBreakdown(
      consumedUnits,
      instructionCount,
      accountKeys?.length ?? 0,
      simulationResult.logs,
    );

    // Get current priority fee recommendations
    final priorityFeeAnalysis = await _analyzePriorityFees();

    // Calculate fee estimates
    final feeEstimates = _calculateFeeEstimates(
      consumedUnits,
      priorityFeeAnalysis,
    );

    // Generate optimization recommendations
    final optimizationRecommendations = _generateOptimizationRecommendations(
      breakdown,
      consumedUnits,
      instructionCount,
    );

    final result = ComputeUnitAnalysisResult(
      totalComputeUnits: consumedUnits,
      breakdown: breakdown,
      priorityFeeAnalysis: priorityFeeAnalysis,
      feeEstimates: feeEstimates,
      optimizationRecommendations: optimizationRecommendations,
      analysisTimestamp: DateTime.now(),
      networkConditions: await _getNetworkConditions(),
      transactionComplexity: _calculateTransactionComplexity(
        instructionCount,
        accountKeys?.length ?? 0,
        consumedUnits,
      ),
    );

    // Cache the result
    if (_config.enableCaching) {
      _analysisCache[cacheKey] = result;
      _cleanupExpiredCache();
    }

    return result;
  }

  /// Estimate fees for a transaction before execution
  Future<FeeEstimationResult> estimateFees({
    required int estimatedComputeUnits,
    required int instructionCount,
    List<String>? accountKeys,
    FeeEstimationStrategy strategy = FeeEstimationStrategy.balanced,
  }) async {
    final priorityFeeAnalysis = await _analyzePriorityFees();
    final networkConditions = await _getNetworkConditions();

    // Base transaction fee (5000 lamports per signature)
    final baseTransactionFee = 5000;

    // Calculate priority fee based on strategy
    final priorityFeePerComputeUnit = _selectPriorityFeeForStrategy(
      strategy,
      priorityFeeAnalysis,
      networkConditions,
    );

    final priorityFee =
        (estimatedComputeUnits * priorityFeePerComputeUnit / 1000000).round();
    final totalFee = baseTransactionFee + priorityFee;

    return FeeEstimationResult(
      baseTransactionFee: baseTransactionFee,
      priorityFee: priorityFee,
      totalFee: totalFee,
      priorityFeePerComputeUnit: priorityFeePerComputeUnit,
      estimatedComputeUnits: estimatedComputeUnits,
      strategy: strategy,
      networkConditions: networkConditions,
      confidence: _calculateEstimationConfidence(
        networkConditions,
        priorityFeeAnalysis,
      ),
      estimationTimestamp: DateTime.now(),
    );
  }

  /// Analyze historical compute unit consumption patterns
  Future<ComputeUnitHistoricalAnalysis> analyzeHistoricalPatterns({
    required String programId,
    String? instructionName,
    Duration period = const Duration(hours: 24),
  }) async {
    // For now, return mock historical analysis
    // In a real implementation, this would query historical transaction data
    return ComputeUnitHistoricalAnalysis(
      programId: programId,
      instructionName: instructionName,
      period: period,
      averageComputeUnits: 150000,
      medianComputeUnits: 145000,
      minComputeUnits: 95000,
      maxComputeUnits: 250000,
      standardDeviation: 25000.0,
      sampleSize: 1000,
      trends: ComputeUnitTrends(
        isIncreasing: false,
        percentageChange: -2.5,
        volatility: 0.15,
      ),
      analysisTimestamp: DateTime.now(),
    );
  }

  /// Generate compute unit budget recommendations
  ComputeUnitBudgetRecommendation generateBudgetRecommendation({
    required int estimatedComputeUnits,
    required ComputeUnitAnalysisResult? analysisResult,
    double safetyMargin = 0.2, // 20% safety margin
  }) {
    final baseUnits =
        analysisResult?.totalComputeUnits ?? estimatedComputeUnits;
    final recommendedBudget = (baseUnits * (1 + safetyMargin)).round();

    // Ensure budget is within Solana limits
    final maxComputeUnits = 1400000; // Current Solana limit
    final finalBudget = recommendedBudget.clamp(0, maxComputeUnits);

    return ComputeUnitBudgetRecommendation(
      recommendedBudget: finalBudget,
      estimatedUsage: baseUnits,
      safetyMargin: safetyMargin,
      utilizationPercentage: (baseUnits / finalBudget * 100),
      isWithinLimits: finalBudget <= maxComputeUnits,
      maxAllowedUnits: maxComputeUnits,
      recommendations: _generateBudgetRecommendations(
        baseUnits,
        finalBudget,
        maxComputeUnits,
      ),
    );
  }

  /// Clear analysis cache
  void clearCache() {
    _analysisCache.clear();
  }

  /// Get analysis statistics
  ComputeUnitAnalysisStatistics getAnalysisStatistics() {
    return ComputeUnitAnalysisStatistics(
      totalAnalyses: _analysisCache.length,
      cacheHitRate: 0.0, // Would track this in real implementation
      averageAnalysisTime:
          Duration.zero, // Would track this in real implementation
      lastAnalysisTime: _analysisCache.values.isNotEmpty
          ? _analysisCache.values.last.analysisTimestamp
          : null,
    );
  }

  // Private helper methods

  String _generateCacheKey(
    TransactionSimulationResult simulationResult,
    int instructionCount,
    List<String>? accountKeys,
  ) {
    final accountKeysStr = accountKeys?.join(',') ?? '';
    return '${simulationResult.unitsConsumed}_${instructionCount}_${accountKeysStr.hashCode}';
  }

  bool _isCacheExpired(ComputeUnitAnalysisResult result) {
    return DateTime.now().difference(result.analysisTimestamp) >
        _config.cacheTimeout;
  }

  ComputeUnitBreakdown _analyzeComputeUnitBreakdown(
    int totalUnits,
    int instructionCount,
    int accountCount,
    List<String> logs,
  ) {
    // Estimate compute unit distribution
    final baseTransactionOverhead = 5000;
    final perInstructionCost = instructionCount > 0
        ? ((totalUnits - baseTransactionOverhead) / instructionCount).round()
        : 0;
    final accountAccessCost =
        accountCount * 100; // Estimated cost per account access

    return ComputeUnitBreakdown(
      totalUnits: totalUnits,
      baseTransactionOverhead: baseTransactionOverhead,
      instructionExecutionCost:
          totalUnits - baseTransactionOverhead - accountAccessCost,
      accountAccessCost: accountAccessCost,
      perInstructionAverage: perInstructionCost,
      instructionCount: instructionCount,
      accountCount: accountCount,
      breakdown: _parseComputeUnitLogsForBreakdown(logs),
    );
  }

  Map<String, int> _parseComputeUnitLogsForBreakdown(List<String> logs) {
    final breakdown = <String, int>{};

    for (final log in logs) {
      // Parse compute unit consumption from logs
      // Example: "Program consumed 50000 of 200000 compute units"
      final match = RegExp(r'Program .* consumed (\d+) of (\d+) compute units')
          .firstMatch(log);
      if (match != null) {
        final consumed = int.parse(match.group(1)!);
        breakdown['program_execution'] =
            (breakdown['program_execution'] ?? 0) + consumed;
      }
    }

    return breakdown;
  }

  Future<PriorityFeeAnalysis> _analyzePriorityFees() async {
    try {
      // Get recent priority fee statistics
      // In a real implementation, this would call getRecentPrioritizationFees RPC
      return PriorityFeeAnalysis(
        currentRecommended: 1000, // microlamports per compute unit
        averageFee: 800,
        medianFee: 500,
        percentile75Fee: 1200,
        percentile90Fee: 2000,
        percentile95Fee: 3000,
        minFee: 0,
        maxFee: 50000,
        samples: 100,
        analysisTimestamp: DateTime.now(),
      );
    } catch (e) {
      // Return conservative defaults on error
      return PriorityFeeAnalysis(
        currentRecommended: 1000,
        averageFee: 1000,
        medianFee: 1000,
        percentile75Fee: 1000,
        percentile90Fee: 1000,
        percentile95Fee: 1000,
        minFee: 0,
        maxFee: 1000,
        samples: 0,
        analysisTimestamp: DateTime.now(),
      );
    }
  }

  FeeEstimates _calculateFeeEstimates(
    int computeUnits,
    PriorityFeeAnalysis priorityFeeAnalysis,
  ) {
    final baseTransactionFee = 5000; // lamports

    return FeeEstimates(
      baseTransactionFee: baseTransactionFee,
      economyPriorityFee:
          _calculatePriorityFee(computeUnits, priorityFeeAnalysis.minFee),
      standardPriorityFee:
          _calculatePriorityFee(computeUnits, priorityFeeAnalysis.medianFee),
      fastPriorityFee: _calculatePriorityFee(
          computeUnits, priorityFeeAnalysis.percentile75Fee),
      urgentPriorityFee: _calculatePriorityFee(
          computeUnits, priorityFeeAnalysis.percentile95Fee),
      economyTotalFee: baseTransactionFee +
          _calculatePriorityFee(computeUnits, priorityFeeAnalysis.minFee),
      standardTotalFee: baseTransactionFee +
          _calculatePriorityFee(computeUnits, priorityFeeAnalysis.medianFee),
      fastTotalFee: baseTransactionFee +
          _calculatePriorityFee(
              computeUnits, priorityFeeAnalysis.percentile75Fee),
      urgentTotalFee: baseTransactionFee +
          _calculatePriorityFee(
              computeUnits, priorityFeeAnalysis.percentile95Fee),
    );
  }

  int _calculatePriorityFee(int computeUnits, int microlamportsPerComputeUnit) {
    return (computeUnits * microlamportsPerComputeUnit / 1000000).round();
  }

  List<OptimizationRecommendation> _generateOptimizationRecommendations(
    ComputeUnitBreakdown breakdown,
    int totalUnits,
    int instructionCount,
  ) {
    final recommendations = <OptimizationRecommendation>[];

    // High compute unit usage recommendation
    if (totalUnits > 800000) {
      recommendations.add(OptimizationRecommendation(
        type: OptimizationType.computeUnitReduction,
        impact: RecommendationImpact.high,
        title: 'High Compute Unit Usage Detected',
        description:
            'Transaction uses ${totalUnits} compute units. Consider optimizing instructions.',
        estimatedSavings: (totalUnits * 0.2).round(),
        actionItems: [
          'Review instruction complexity',
          'Consider batching operations',
          'Optimize account access patterns',
        ],
      ));
    }

    // Many instructions recommendation
    if (instructionCount > 10) {
      recommendations.add(OptimizationRecommendation(
        type: OptimizationType.instructionOptimization,
        impact: RecommendationImpact.medium,
        title: 'High Instruction Count',
        description:
            'Transaction contains ${instructionCount} instructions. Consider consolidation.',
        estimatedSavings:
            (breakdown.perInstructionAverage * 0.3 * (instructionCount - 10))
                .round(),
        actionItems: [
          'Combine related instructions',
          'Use bulk operations where possible',
          'Review instruction necessity',
        ],
      ));
    }

    // Account access optimization
    if (breakdown.accountCount > 20) {
      recommendations.add(OptimizationRecommendation(
        type: OptimizationType.accountOptimization,
        impact: RecommendationImpact.low,
        title: 'High Account Access Count',
        description: 'Transaction accesses ${breakdown.accountCount} accounts.',
        estimatedSavings: (breakdown.accountCount * 50).round(),
        actionItems: [
          'Minimize account dependencies',
          'Use program derived addresses efficiently',
          'Consider account consolidation',
        ],
      ));
    }

    return recommendations;
  }

  int _selectPriorityFeeForStrategy(
    FeeEstimationStrategy strategy,
    PriorityFeeAnalysis analysis,
    NetworkConditions conditions,
  ) {
    switch (strategy) {
      case FeeEstimationStrategy.economy:
        return analysis.minFee;
      case FeeEstimationStrategy.standard:
        return analysis.medianFee;
      case FeeEstimationStrategy.fast:
        return analysis.percentile75Fee;
      case FeeEstimationStrategy.urgent:
        return analysis.percentile95Fee;
      case FeeEstimationStrategy.balanced:
        // Adjust based on network conditions
        if (conditions.congestionLevel == NetworkCongestionLevel.high) {
          return analysis.percentile75Fee;
        } else if (conditions.congestionLevel == NetworkCongestionLevel.low) {
          return analysis.medianFee;
        } else {
          return analysis.currentRecommended;
        }
    }
  }

  Future<NetworkConditions> _getNetworkConditions() async {
    try {
      // In a real implementation, this would analyze recent block data
      // and slot times to determine network congestion
      return NetworkConditions(
        congestionLevel: NetworkCongestionLevel.medium,
        averageSlotTime: Duration(milliseconds: 400),
        recentTps: 2500,
        queueLength: 150,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return NetworkConditions(
        congestionLevel: NetworkCongestionLevel.medium,
        averageSlotTime: Duration(milliseconds: 400),
        recentTps: 2000,
        queueLength: 100,
        timestamp: DateTime.now(),
      );
    }
  }

  TransactionComplexity _calculateTransactionComplexity(
    int instructionCount,
    int accountCount,
    int computeUnits,
  ) {
    final complexityScore = (instructionCount * 10) +
        (accountCount * 2) +
        (computeUnits / 10000).round();

    if (complexityScore < 50) {
      return TransactionComplexity.simple;
    } else if (complexityScore < 150) {
      return TransactionComplexity.moderate;
    } else if (complexityScore < 300) {
      return TransactionComplexity.complex;
    } else {
      return TransactionComplexity.veryComplex;
    }
  }

  double _calculateEstimationConfidence(
    NetworkConditions conditions,
    PriorityFeeAnalysis analysis,
  ) {
    double confidence = 0.8; // Base confidence

    // Adjust based on sample size
    if (analysis.samples > 50) {
      confidence += 0.1;
    }

    // Adjust based on network stability
    if (conditions.congestionLevel == NetworkCongestionLevel.low) {
      confidence += 0.1;
    } else if (conditions.congestionLevel == NetworkCongestionLevel.high) {
      confidence -= 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

  List<String> _generateBudgetRecommendations(
    int estimatedUsage,
    int recommendedBudget,
    int maxAllowed,
  ) {
    final recommendations = <String>[];

    if (estimatedUsage > maxAllowed * 0.9) {
      recommendations.add(
          'Transaction is very complex, consider splitting into multiple transactions');
    }

    if (recommendedBudget > estimatedUsage * 1.5) {
      recommendations
          .add('Consider reducing safety margin for more efficient fee usage');
    }

    if (estimatedUsage > 500000) {
      recommendations
          .add('Review instruction efficiency and account access patterns');
    }

    return recommendations;
  }

  void _cleanupExpiredCache() {
    final now = DateTime.now();
    _analysisCache.removeWhere((key, value) =>
        now.difference(value.analysisTimestamp) > _config.cacheTimeout);
  }
}

/// Configuration for compute unit analysis
class ComputeUnitAnalysisConfig {
  final bool enableCaching;
  final Duration cacheTimeout;
  final int maxCacheSize;

  const ComputeUnitAnalysisConfig({
    this.enableCaching = true,
    this.cacheTimeout = const Duration(minutes: 5),
    this.maxCacheSize = 100,
  });
}

/// Result of compute unit analysis
class ComputeUnitAnalysisResult {
  final int totalComputeUnits;
  final ComputeUnitBreakdown breakdown;
  final PriorityFeeAnalysis priorityFeeAnalysis;
  final FeeEstimates feeEstimates;
  final List<OptimizationRecommendation> optimizationRecommendations;
  final DateTime analysisTimestamp;
  final NetworkConditions networkConditions;
  final TransactionComplexity transactionComplexity;

  const ComputeUnitAnalysisResult({
    required this.totalComputeUnits,
    required this.breakdown,
    required this.priorityFeeAnalysis,
    required this.feeEstimates,
    required this.optimizationRecommendations,
    required this.analysisTimestamp,
    required this.networkConditions,
    required this.transactionComplexity,
  });

  @override
  String toString() {
    return 'ComputeUnitAnalysisResult(totalUnits: $totalComputeUnits, '
        'complexity: $transactionComplexity, optimizations: ${optimizationRecommendations.length})';
  }
}

/// Breakdown of compute unit usage
class ComputeUnitBreakdown {
  final int totalUnits;
  final int baseTransactionOverhead;
  final int instructionExecutionCost;
  final int accountAccessCost;
  final int perInstructionAverage;
  final int instructionCount;
  final int accountCount;
  final Map<String, int> breakdown;

  const ComputeUnitBreakdown({
    required this.totalUnits,
    required this.baseTransactionOverhead,
    required this.instructionExecutionCost,
    required this.accountAccessCost,
    required this.perInstructionAverage,
    required this.instructionCount,
    required this.accountCount,
    required this.breakdown,
  });

  @override
  String toString() {
    return 'ComputeUnitBreakdown(total: $totalUnits, instructions: $instructionExecutionCost, '
        'accounts: $accountAccessCost, overhead: $baseTransactionOverhead)';
  }
}

/// Priority fee analysis from network data
class PriorityFeeAnalysis {
  final int currentRecommended; // microlamports per compute unit
  final int averageFee;
  final int medianFee;
  final int percentile75Fee;
  final int percentile90Fee;
  final int percentile95Fee;
  final int minFee;
  final int maxFee;
  final int samples;
  final DateTime analysisTimestamp;

  const PriorityFeeAnalysis({
    required this.currentRecommended,
    required this.averageFee,
    required this.medianFee,
    required this.percentile75Fee,
    required this.percentile90Fee,
    required this.percentile95Fee,
    required this.minFee,
    required this.maxFee,
    required this.samples,
    required this.analysisTimestamp,
  });

  @override
  String toString() {
    return 'PriorityFeeAnalysis(recommended: $currentRecommended, median: $medianFee, '
        'p95: $percentile95Fee, samples: $samples)';
  }
}

/// Fee estimates for different priority levels
class FeeEstimates {
  final int baseTransactionFee;
  final int economyPriorityFee;
  final int standardPriorityFee;
  final int fastPriorityFee;
  final int urgentPriorityFee;
  final int economyTotalFee;
  final int standardTotalFee;
  final int fastTotalFee;
  final int urgentTotalFee;

  const FeeEstimates({
    required this.baseTransactionFee,
    required this.economyPriorityFee,
    required this.standardPriorityFee,
    required this.fastPriorityFee,
    required this.urgentPriorityFee,
    required this.economyTotalFee,
    required this.standardTotalFee,
    required this.fastTotalFee,
    required this.urgentTotalFee,
  });

  @override
  String toString() {
    return 'FeeEstimates(economy: $economyTotalFee, standard: $standardTotalFee, '
        'fast: $fastTotalFee, urgent: $urgentTotalFee)';
  }
}

/// Optimization recommendation
class OptimizationRecommendation {
  final OptimizationType type;
  final RecommendationImpact impact;
  final String title;
  final String description;
  final int estimatedSavings; // compute units
  final List<String> actionItems;

  const OptimizationRecommendation({
    required this.type,
    required this.impact,
    required this.title,
    required this.description,
    required this.estimatedSavings,
    required this.actionItems,
  });

  @override
  String toString() {
    return 'OptimizationRecommendation($title: $estimatedSavings CU savings, $impact impact)';
  }
}

/// Result of fee estimation
class FeeEstimationResult {
  final int baseTransactionFee;
  final int priorityFee;
  final int totalFee;
  final int priorityFeePerComputeUnit;
  final int estimatedComputeUnits;
  final FeeEstimationStrategy strategy;
  final NetworkConditions networkConditions;
  final double confidence; // 0.0 to 1.0
  final DateTime estimationTimestamp;

  const FeeEstimationResult({
    required this.baseTransactionFee,
    required this.priorityFee,
    required this.totalFee,
    required this.priorityFeePerComputeUnit,
    required this.estimatedComputeUnits,
    required this.strategy,
    required this.networkConditions,
    required this.confidence,
    required this.estimationTimestamp,
  });

  @override
  String toString() {
    return 'FeeEstimationResult(total: $totalFee lamports, strategy: $strategy, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Historical compute unit analysis
class ComputeUnitHistoricalAnalysis {
  final String programId;
  final String? instructionName;
  final Duration period;
  final int averageComputeUnits;
  final int medianComputeUnits;
  final int minComputeUnits;
  final int maxComputeUnits;
  final double standardDeviation;
  final int sampleSize;
  final ComputeUnitTrends trends;
  final DateTime analysisTimestamp;

  const ComputeUnitHistoricalAnalysis({
    required this.programId,
    this.instructionName,
    required this.period,
    required this.averageComputeUnits,
    required this.medianComputeUnits,
    required this.minComputeUnits,
    required this.maxComputeUnits,
    required this.standardDeviation,
    required this.sampleSize,
    required this.trends,
    required this.analysisTimestamp,
  });

  @override
  String toString() {
    return 'ComputeUnitHistoricalAnalysis(program: $programId, avg: $averageComputeUnits, '
        'samples: $sampleSize, trend: ${trends.percentageChange}%)';
  }
}

/// Compute unit trends analysis
class ComputeUnitTrends {
  final bool isIncreasing;
  final double percentageChange;
  final double volatility;

  const ComputeUnitTrends({
    required this.isIncreasing,
    required this.percentageChange,
    required this.volatility,
  });

  @override
  String toString() {
    return 'ComputeUnitTrends(${isIncreasing ? "↗" : "↘"} ${percentageChange.toStringAsFixed(1)}%, volatility: ${volatility.toStringAsFixed(2)})';
  }
}

/// Compute unit budget recommendation
class ComputeUnitBudgetRecommendation {
  final int recommendedBudget;
  final int estimatedUsage;
  final double safetyMargin;
  final double utilizationPercentage;
  final bool isWithinLimits;
  final int maxAllowedUnits;
  final List<String> recommendations;

  const ComputeUnitBudgetRecommendation({
    required this.recommendedBudget,
    required this.estimatedUsage,
    required this.safetyMargin,
    required this.utilizationPercentage,
    required this.isWithinLimits,
    required this.maxAllowedUnits,
    required this.recommendations,
  });

  @override
  String toString() {
    return 'ComputeUnitBudgetRecommendation(budget: $recommendedBudget, '
        'usage: $estimatedUsage, utilization: ${utilizationPercentage.toStringAsFixed(1)}%)';
  }
}

/// Network conditions analysis
class NetworkConditions {
  final NetworkCongestionLevel congestionLevel;
  final Duration averageSlotTime;
  final int recentTps;
  final int queueLength;
  final DateTime timestamp;

  const NetworkConditions({
    required this.congestionLevel,
    required this.averageSlotTime,
    required this.recentTps,
    required this.queueLength,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NetworkConditions($congestionLevel, TPS: $recentTps, queue: $queueLength)';
  }
}

/// Analysis statistics
class ComputeUnitAnalysisStatistics {
  final int totalAnalyses;
  final double cacheHitRate;
  final Duration averageAnalysisTime;
  final DateTime? lastAnalysisTime;

  const ComputeUnitAnalysisStatistics({
    required this.totalAnalyses,
    required this.cacheHitRate,
    required this.averageAnalysisTime,
    this.lastAnalysisTime,
  });

  @override
  String toString() {
    return 'ComputeUnitAnalysisStatistics(analyses: $totalAnalyses, '
        'cache hit rate: ${(cacheHitRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Fee estimation strategy
enum FeeEstimationStrategy {
  economy, // Minimum fee for inclusion
  standard, // Median network fee
  fast, // 75th percentile fee
  urgent, // 95th percentile fee
  balanced, // Adaptive based on conditions
}

/// Transaction complexity levels
enum TransactionComplexity {
  simple, // Few instructions, low compute units
  moderate, // Moderate complexity
  complex, // High complexity
  veryComplex, // Very high complexity
}

/// Network congestion levels
enum NetworkCongestionLevel {
  low, // Fast confirmation times
  medium, // Normal confirmation times
  high, // Slow confirmation times
}

/// Optimization recommendation types
enum OptimizationType {
  computeUnitReduction,
  instructionOptimization,
  accountOptimization,
  feeOptimization,
}

/// Recommendation impact levels
enum RecommendationImpact {
  low, // Minor improvement
  medium, // Moderate improvement
  high, // Significant improvement
}
