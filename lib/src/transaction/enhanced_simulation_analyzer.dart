import 'dart:convert';
import 'dart:math' as math;

import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart';

/// Enhanced simulation analyzer providing comprehensive analysis,
/// optimization recommendations, and debugging capabilities
class EnhancedSimulationAnalyzer {

  EnhancedSimulationAnalyzer({
    this.config = const AnalysisConfig(),
  });
  /// Cache for analysis results
  final Map<String, AnalysisResult> _analysisCache = {};

  /// Configuration for analysis
  final AnalysisConfig config;

  /// Statistics for analysis operations
  final AnalysisStatistics statistics = AnalysisStatistics();

  /// Perform comprehensive analysis on simulation result
  Future<AnalysisResult> analyzeSimulation(
    TransactionSimulationResult simulation, {
    String? cacheKey,
    AnalysisOptions? options,
  }) async {
    options ??= AnalysisOptions.defaultOptions();

    // Check cache if key provided
    if (cacheKey != null && _analysisCache.containsKey(cacheKey)) {
      statistics.cacheHits++;
      return _analysisCache[cacheKey]!;
    }

    statistics.analysisCount++;
    final startTime = DateTime.now();

    try {
      // Analyze compute units and fees
      final computeAnalysis = await _analyzeComputeUnits(simulation);

      // Analyze account access patterns
      final accountAnalysis = await _analyzeAccountAccess(simulation);

      // Generate optimization recommendations
      final optimizations = await _generateOptimizations(
          simulation, computeAnalysis, accountAnalysis,);

      // Analyze potential issues and risks
      final issueAnalysis = await _analyzeIssues(simulation);

      // Calculate performance metrics
      final performance = await _analyzePerformance(simulation);

      // Analyze cross-program invocations
      final cpiAnalysis = await _analyzeCpiPatterns(simulation);

      final result = AnalysisResult(
        simulationId: _generateSimulationId(simulation),
        timestamp: DateTime.now(),
        computeAnalysis: computeAnalysis,
        accountAnalysis: accountAnalysis,
        optimizationRecommendations: optimizations,
        issueAnalysis: issueAnalysis,
        performanceMetrics: performance,
        cpiAnalysis: cpiAnalysis,
        analysisOptions: options,
        processingTime: DateTime.now().difference(startTime),
      );

      // Cache the result if key provided
      if (cacheKey != null) {
        _analysisCache[cacheKey] = result;
      }

      statistics.successfulAnalyses++;
      return result;
    } catch (e) {
      statistics.failedAnalyses++;
      rethrow;
    }
  }

  /// Compare multiple simulation results for benchmarking
  Future<ComparisonResult> compareSimulations(
    List<TransactionSimulationResult> simulations, {
    String? baselineIndex,
    ComparisonOptions? options,
  }) async {
    if (simulations.isEmpty) {
      throw ArgumentError('At least one simulation required for comparison');
    }

    options ??= ComparisonOptions.defaultOptions();
    final analyses = <AnalysisResult>[];

    // Analyze each simulation
    for (int i = 0; i < simulations.length; i++) {
      final analysis = await analyzeSimulation(
        simulations[i],
        cacheKey: 'comparison_${i}_${DateTime.now().millisecondsSinceEpoch}',
      );
      analyses.add(analysis);
    }

    // Determine baseline (first by default, or specified index)
    final baselineIdx =
        baselineIndex != null ? int.tryParse(baselineIndex) ?? 0 : 0;

    if (baselineIdx >= analyses.length) {
      throw ArgumentError('Baseline index out of range');
    }

    final baseline = analyses[baselineIdx];
    final comparisons = <SimulationComparison>[];

    // Compare each simulation against baseline
    for (int i = 0; i < analyses.length; i++) {
      if (i == baselineIdx) continue;

      final comparison = _compareAnalyses(baseline, analyses[i], i);
      comparisons.add(comparison);
    }

    return ComparisonResult(
      baseline: baseline,
      comparisons: comparisons,
      summary: _generateComparisonSummary(baseline, comparisons),
      timestamp: DateTime.now(),
    );
  }

  /// Generate batch analysis for multiple simulations
  Future<BatchAnalysisResult> analyzeBatch(
    List<TransactionSimulationResult> simulations, {
    BatchAnalysisOptions? options,
  }) async {
    options ??= BatchAnalysisOptions.defaultOptions();
    final analyses = <AnalysisResult>[];
    final errors = <BatchAnalysisError>[];

    // Process simulations (potentially in parallel)
    if (options.parallel && simulations.length > 1) {
      final futures = simulations.asMap().entries.map((entry) async {
        try {
          return await analyzeSimulation(
            entry.value,
            cacheKey:
                'batch_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          );
        } catch (e) {
          errors.add(BatchAnalysisError(
            index: entry.key,
            simulation: entry.value,
            error: e.toString(),
          ),);
          return null;
        }
      });

      final results = await Future.wait(futures);
      analyses.addAll(results.whereType<AnalysisResult>());
    } else {
      // Sequential processing
      for (int i = 0; i < simulations.length; i++) {
        try {
          final analysis = await analyzeSimulation(
            simulations[i],
            cacheKey: 'batch_${i}_${DateTime.now().millisecondsSinceEpoch}',
          );
          analyses.add(analysis);
        } catch (e) {
          errors.add(BatchAnalysisError(
            index: i,
            simulation: simulations[i],
            error: e.toString(),
          ),);
        }
      }
    }

    return BatchAnalysisResult(
      analyses: analyses,
      errors: errors,
      aggregatedMetrics: _aggregateMetrics(analyses),
      patterns: _identifyPatterns(analyses),
      timestamp: DateTime.now(),
    );
  }

  /// Export analysis result in various formats
  Future<ExportResult> exportAnalysis(
    AnalysisResult analysis, {
    required ExportFormat format,
    ExportOptions? options,
  }) async {
    options ??= ExportOptions.defaultOptions();

    switch (format) {
      case ExportFormat.json:
        return _exportToJson(analysis, options);
      case ExportFormat.csv:
        return _exportToCsv(analysis, options);
      case ExportFormat.markdown:
        return _exportToMarkdown(analysis, options);
      case ExportFormat.html:
        return _exportToHtml(analysis, options);
    }
  }

  /// Clear analysis cache
  void clearCache() {
    _analysisCache.clear();
    statistics.cacheClears++;
  }

  /// Get cache statistics
  CacheStatistics getCacheStatistics() => CacheStatistics(
      size: _analysisCache.length,
      hits: statistics.cacheHits,
      misses: statistics.analysisCount - statistics.cacheHits,
      hitRate: statistics.cacheHits / math.max(1, statistics.analysisCount),
    );

  // Private analysis methods

  Future<ComputeAnalysis> _analyzeComputeUnits(
      TransactionSimulationResult simulation,) async {
    final consumedUnits = simulation.unitsConsumed ?? 0;
    final efficiency = _calculateComputeEfficiency(consumedUnits, simulation);

    return ComputeAnalysis(
      unitsConsumed: consumedUnits,
      estimatedFee: _estimateFee(consumedUnits),
      efficiency: efficiency,
      breakdown: await _getComputeBreakdown(simulation),
      recommendations: _getComputeRecommendations(consumedUnits, efficiency),
    );
  }

  Future<AccountAnalysis> _analyzeAccountAccess(
      TransactionSimulationResult simulation,) async {
    final accountsData = simulation.accounts ?? <String, dynamic>{};
    final accountsList = accountsData.values.toList();
    final accessPatterns = <AccountAccessPattern>[];

    for (final accountData in accountsList) {
      if (accountData is Map<String, dynamic>) {
        final pattern = AccountAccessPattern(
          publicKey: accountData['pubkey']?.toString() ?? 'unknown',
          isWritable: accountData['writable'] == true,
          isSigner: accountData['signer'] == true,
          dataSize: accountData['data'] is List
              ? (accountData['data'] as List).length
              : null,
          accessType: _determineAccessType(accountData),
          recommendations: _getAccountRecommendations(accountData),
        );
        accessPatterns.add(pattern);
      }
    }

    final writableCount = accessPatterns.where((p) => p.isWritable).length;
    final signerCount = accessPatterns.where((p) => p.isSigner).length;

    return AccountAnalysis(
      totalAccounts: accessPatterns.length,
      writableAccounts: writableCount,
      signerAccounts: signerCount,
      accessPatterns: accessPatterns,
      potentialOptimizations: _identifyAccountOptimizations(accessPatterns),
    );
  }

  Future<List<OptimizationRecommendation>> _generateOptimizations(
    TransactionSimulationResult simulation,
    ComputeAnalysis computeAnalysis,
    AccountAnalysis accountAnalysis,
  ) async {
    final recommendations = <OptimizationRecommendation>[];

    // Compute unit optimizations
    if (computeAnalysis.efficiency < 0.7) {
      recommendations.add(OptimizationRecommendation(
        type: OptimizationType.computeUnits,
        priority: Priority.high,
        title: 'High Compute Unit Usage',
        description:
            'Transaction uses ${computeAnalysis.unitsConsumed} compute units. Consider optimizing instruction logic.',
        impact: OptimizationImpact.medium,
        effort: OptimizationEffort.medium,
        suggestedActions: [
          'Review instruction complexity',
          'Consider breaking into smaller transactions',
          'Optimize account access patterns',
        ],
      ),);
    }

    // Account optimization
    if (accountAnalysis.totalAccounts > 20) {
      recommendations.add(OptimizationRecommendation(
        type: OptimizationType.accounts,
        priority: Priority.medium,
        title: 'Many Account Accesses',
        description:
            'Transaction accesses ${accountAnalysis.totalAccounts} accounts. Consider reducing account dependencies.',
        impact: OptimizationImpact.low,
        effort: OptimizationEffort.high,
        suggestedActions: [
          'Combine related accounts',
          'Use PDAs to reduce account count',
          'Consider account lookup tables',
        ],
      ),);
    }

    // Add more optimization logic based on simulation analysis
    recommendations.addAll(await _analyzeTransactionStructure(simulation));
    recommendations.addAll(await _analyzeFeeOptimizations(simulation));

    return recommendations;
  }

  Future<IssueAnalysis> _analyzeIssues(
      TransactionSimulationResult simulation,) async {
    final issues = <SimulationIssue>[];
    final warnings = <SimulationWarning>[];

    // Check for common issues
    if (simulation.error != null) {
      issues.add(SimulationIssue(
        type: IssueType.simulationError,
        severity: IssueSeverity.critical,
        message: simulation.error!.type,
        details: simulation.error!.details?.toString(),
        suggestedFix: 'Review transaction parameters and account states',
      ),);
    }

    // Check for high compute usage
    final computeUnits = simulation.unitsConsumed ?? 0;
    if (computeUnits > 1000000) {
      warnings.add(SimulationWarning(
        type: WarningType.highComputeUsage,
        message: 'High compute unit usage: $computeUnits units',
        recommendation: 'Consider optimizing transaction complexity',
      ),);
    }

    // Check for potential account conflicts
    final accountsData = simulation.accounts ?? <String, dynamic>{};
    final accountsList = accountsData.values.toList();
    final writableAccounts = accountsList.where((a) {
      if (a is Map<String, dynamic>) {
        return a['writable'] == true;
      }
      return false;
    }).toList();
    if (writableAccounts.length > 10) {
      warnings.add(SimulationWarning(
        type: WarningType.manyWritableAccounts,
        message:
            '${writableAccounts.length} writable accounts may cause conflicts',
        recommendation: 'Review if all writable access is necessary',
      ),);
    }

    return IssueAnalysis(
      issues: issues,
      warnings: warnings,
      overallRisk: _calculateOverallRisk(issues, warnings),
    );
  }

  Future<PerformanceMetrics> _analyzePerformance(
      TransactionSimulationResult simulation,) async {
    final logs = simulation.logs;
    final accountsData = simulation.accounts ?? <String, dynamic>{};

    return PerformanceMetrics(
      computeUnitsUsed: simulation.unitsConsumed ?? 0,
      logCount: logs.length,
      accountCount: accountsData.length,
      estimatedNetworkLatency: _estimateNetworkLatency(simulation),
      throughputScore: _calculateThroughputScore(simulation),
      resourceUtilization: _calculateResourceUtilization(simulation),
    );
  }

  Future<CpiAnalysis> _analyzeCpiPatterns(
      TransactionSimulationResult simulation,) async {
    final logs = simulation.logs;
    final cpiCalls = <CpiCall>[];
    final programStack = <String>[];

    for (final log in logs) {
      if (log.contains('invoke [')) {
        final match =
            RegExp(r'Program ([1-9A-HJ-NP-Za-km-z]+) invoke \[(\d+)\]')
                .firstMatch(log);
        if (match != null) {
          final programId = match.group(1)!;
          final depth = int.parse(match.group(2)!);

          cpiCalls.add(CpiCall(
            programId: programId,
            depth: depth,
            timestamp: DateTime.now(),
            callType: CpiCallType.invoke,
          ),);

          if (depth <= programStack.length) {
            programStack.removeRange(depth, programStack.length);
          }
          programStack.add(programId);
        }
      }
    }

    return CpiAnalysis(
      totalCpiCalls: cpiCalls.length,
      maxDepth: cpiCalls.isNotEmpty
          ? cpiCalls.map((c) => c.depth).reduce(math.max)
          : 0,
      uniquePrograms: cpiCalls.map((c) => c.programId).toSet().toList(),
      callPattern: cpiCalls,
      complexity: _calculateCpiComplexity(cpiCalls),
    );
  }

  // Helper methods for analysis

  double _calculateComputeEfficiency(
      int unitsConsumed, TransactionSimulationResult simulation,) {
    // Simple efficiency calculation - can be enhanced based on transaction complexity
    const maxUnits = 1400000; // Current transaction limit
    return 1.0 - (unitsConsumed / maxUnits);
  }

  int _estimateFee(int computeUnits) {
    // Simple fee estimation - can be enhanced with current fee rates
    const lamportsPerComputeUnit = 1;
    return computeUnits * lamportsPerComputeUnit;
  }

  Future<ComputeBreakdown> _getComputeBreakdown(
      TransactionSimulationResult simulation,) async {
    // Analyze logs to break down compute unit usage
    // This is a simplified implementation
    return ComputeBreakdown(
      instructionCost: (simulation.unitsConsumed ?? 0) * 0.7,
      accountAccess: (simulation.unitsConsumed ?? 0) * 0.2,
      systemOverhead: (simulation.unitsConsumed ?? 0) * 0.1,
    );
  }

  List<String> _getComputeRecommendations(
      int unitsConsumed, double efficiency,) {
    final recommendations = <String>[];

    if (efficiency < 0.5) {
      recommendations
          .add('Consider breaking transaction into smaller operations');
    }
    if (unitsConsumed > 800000) {
      recommendations.add('Review instruction complexity and data processing');
    }

    return recommendations;
  }

  AccountAccessType _determineAccessType(Map<String, dynamic> account) {
    final isWritable = account['writable'] == true;
    final isSigner = account['signer'] == true;

    if (isWritable && isSigner) {
      return AccountAccessType.writableSigner;
    } else if (isWritable) {
      return AccountAccessType.writable;
    } else if (isSigner) {
      return AccountAccessType.signer;
    }
    return AccountAccessType.readonly;
  }

  List<String> _getAccountRecommendations(Map<String, dynamic> account) {
    final recommendations = <String>[];

    final isWritable = account['writable'] == true;
    final dataLength =
        account['data'] is List ? (account['data'] as List).length : 0;

    if (isWritable && dataLength > 10240) {
      recommendations.add('Large writable account may impact performance');
    }

    return recommendations;
  }

  List<AccountOptimization> _identifyAccountOptimizations(
      List<AccountAccessPattern> patterns,) {
    final optimizations = <AccountOptimization>[];

    // Check for redundant readonly accounts
    final readonlyAccounts = patterns
        .where((p) => p.accessType == AccountAccessType.readonly)
        .toList();
    if (readonlyAccounts.length > 15) {
      optimizations.add(const AccountOptimization(
        type: 'reduce_readonly_accounts',
        description:
            'Consider using account lookup tables for readonly accounts',
        impact: 'Reduces transaction size and improves processing speed',
      ),);
    }

    return optimizations;
  }

  Future<List<OptimizationRecommendation>> _analyzeTransactionStructure(
      TransactionSimulationResult simulation,) async {
    // Analyze transaction structure for optimization opportunities
    return [];
  }

  Future<List<OptimizationRecommendation>> _analyzeFeeOptimizations(
      TransactionSimulationResult simulation,) async {
    // Analyze fee optimization opportunities
    return [];
  }

  RiskLevel _calculateOverallRisk(
      List<SimulationIssue> issues, List<SimulationWarning> warnings,) {
    if (issues.any((i) => i.severity == IssueSeverity.critical)) {
      return RiskLevel.high;
    } else if (issues.isNotEmpty || warnings.length > 3) {
      return RiskLevel.medium;
    }
    return RiskLevel.low;
  }

  Duration _estimateNetworkLatency(TransactionSimulationResult simulation) {
    // Estimate network latency based on transaction complexity
    final baseLatency = const Duration(milliseconds: 100);
    final accountFactor = (simulation.accounts?.length ?? 0) * 2;
    return baseLatency + Duration(milliseconds: accountFactor);
  }

  double _calculateThroughputScore(TransactionSimulationResult simulation) {
    // Calculate a throughput score (0-1, higher is better)
    final computeUnits = simulation.unitsConsumed ?? 0;
    final accountsData = simulation.accounts ?? <String, dynamic>{};
    final accounts = accountsData.length;

    // Simple scoring based on resource usage
    final computeScore = 1.0 - (computeUnits / 1400000);
    final accountScore = 1.0 - (accounts / 64); // Max accounts in transaction

    return (computeScore + accountScore) / 2;
  }

  double _calculateResourceUtilization(TransactionSimulationResult simulation) {
    // Calculate overall resource utilization
    final computeUnits = simulation.unitsConsumed ?? 0;
    return computeUnits / 1400000; // As ratio of max compute units
  }

  double _calculateCpiComplexity(List<CpiCall> cpiCalls) {
    if (cpiCalls.isEmpty) return 0;

    final maxDepth = cpiCalls.map((c) => c.depth).reduce(math.max);
    final uniquePrograms = cpiCalls.map((c) => c.programId).toSet().length;

    // Complexity based on depth and program diversity
    return (maxDepth + uniquePrograms) / 10.0;
  }

  String _generateSimulationId(TransactionSimulationResult simulation) {
    // Generate a unique ID for the simulation result
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = simulation.logs.join().hashCode.abs();
    final id = 'sim_${timestamp}_$hash';
    return id.isNotEmpty
        ? id
        : 'sim_${DateTime.now().millisecondsSinceEpoch}_fallback';
  }

  SimulationComparison _compareAnalyses(
      AnalysisResult baseline, AnalysisResult comparison, int index,) {
    final computeDiff = comparison.computeAnalysis.unitsConsumed -
        baseline.computeAnalysis.unitsConsumed;
    final accountDiff = comparison.accountAnalysis.totalAccounts -
        baseline.accountAnalysis.totalAccounts;

    return SimulationComparison(
      index: index,
      analysis: comparison,
      computeUnitsDifference: computeDiff,
      accountCountDifference: accountDiff,
      performanceImprovement:
          _calculatePerformanceImprovement(baseline, comparison),
      significantChanges: _identifySignificantChanges(baseline, comparison),
    );
  }

  ComparisonSummary _generateComparisonSummary(
      AnalysisResult baseline, List<SimulationComparison> comparisons,) {
    if (comparisons.isEmpty) {
      return const ComparisonSummary(
        bestPerforming: 0,
        worstPerforming: 0,
        averageImprovement: 0,
        recommendedOption: 0,
      );
    }

    final improvements =
        comparisons.map((c) => c.performanceImprovement).toList();
    final bestIndex = improvements.indexOf(improvements.reduce(math.max));
    final worstIndex = improvements.indexOf(improvements.reduce(math.min));
    final avgImprovement =
        improvements.reduce((a, b) => a + b) / improvements.length;

    return ComparisonSummary(
      bestPerforming: bestIndex,
      worstPerforming: worstIndex,
      averageImprovement: avgImprovement,
      recommendedOption: improvements[bestIndex] > 0 ? bestIndex : 0,
    );
  }

  double _calculatePerformanceImprovement(
      AnalysisResult baseline, AnalysisResult comparison,) {
    // Calculate improvement as a percentage
    final baselineScore = baseline.performanceMetrics.throughputScore;
    final comparisonScore = comparison.performanceMetrics.throughputScore;

    if (baselineScore == 0) return 0;
    return ((comparisonScore - baselineScore) / baselineScore) * 100;
  }

  List<String> _identifySignificantChanges(
      AnalysisResult baseline, AnalysisResult comparison,) {
    final changes = <String>[];

    final computeDiff = comparison.computeAnalysis.unitsConsumed -
        baseline.computeAnalysis.unitsConsumed;
    if (computeDiff.abs() > 10000) {
      changes.add(
          'Compute units ${computeDiff > 0 ? 'increased' : 'decreased'} by ${computeDiff.abs()}',);
    }

    final accountDiff = comparison.accountAnalysis.totalAccounts -
        baseline.accountAnalysis.totalAccounts;
    if (accountDiff != 0) {
      changes.add(
          'Account count ${accountDiff > 0 ? 'increased' : 'decreased'} by ${accountDiff.abs()}',);
    }

    return changes;
  }

  AggregatedMetrics _aggregateMetrics(List<AnalysisResult> analyses) {
    if (analyses.isEmpty) {
      return const AggregatedMetrics(
        averageComputeUnits: 0,
        averageAccountCount: 0,
        totalIssues: 0,
        commonOptimizations: [],
      );
    }

    final avgCompute = analyses
            .map((a) => a.computeAnalysis.unitsConsumed)
            .reduce((a, b) => a + b) /
        analyses.length;
    final avgAccounts = analyses
            .map((a) => a.accountAnalysis.totalAccounts)
            .reduce((a, b) => a + b) /
        analyses.length;
    final totalIssues = analyses
        .map((a) => a.issueAnalysis.issues.length)
        .reduce((a, b) => a + b);

    // Find common optimizations
    final allOptimizations =
        analyses.expand((a) => a.optimizationRecommendations).toList();
    final optimizationCounts = <String, int>{};

    for (final opt in allOptimizations) {
      optimizationCounts[opt.title] = (optimizationCounts[opt.title] ?? 0) + 1;
    }

    final commonOptimizations = optimizationCounts.entries
        .where((e) =>
            e.value > analyses.length * 0.5,) // Appears in >50% of analyses
        .map((e) => e.key)
        .toList();

    return AggregatedMetrics(
      averageComputeUnits: avgCompute,
      averageAccountCount: avgAccounts,
      totalIssues: totalIssues,
      commonOptimizations: commonOptimizations,
    );
  }

  List<AnalysisPattern> _identifyPatterns(List<AnalysisResult> analyses) {
    final patterns = <AnalysisPattern>[];

    // Pattern: Consistently high compute usage
    final highComputeAnalyses =
        analyses.where((a) => a.computeAnalysis.unitsConsumed > 800000).length;
    if (highComputeAnalyses > analyses.length * 0.7) {
      patterns.add(AnalysisPattern(
        type: 'high_compute_usage',
        description: 'Consistently high compute unit usage across transactions',
        frequency: highComputeAnalyses / analyses.length,
        recommendation:
            'Review transaction complexity and consider optimization',
      ),);
    }

    return patterns;
  }

  // Export methods

  ExportResult _exportToJson(AnalysisResult analysis, ExportOptions options) {
    final jsonData = {
      'simulationId': analysis.simulationId,
      'timestamp': analysis.timestamp.toIso8601String(),
      'computeAnalysis': {
        'unitsConsumed': analysis.computeAnalysis.unitsConsumed,
        'estimatedFee': analysis.computeAnalysis.estimatedFee,
        'efficiency': analysis.computeAnalysis.efficiency,
      },
      'accountAnalysis': {
        'totalAccounts': analysis.accountAnalysis.totalAccounts,
        'writableAccounts': analysis.accountAnalysis.writableAccounts,
        'signerAccounts': analysis.accountAnalysis.signerAccounts,
      },
      'optimizationRecommendations': analysis.optimizationRecommendations
          .map((r) => {
                'type': r.type.toString(),
                'priority': r.priority.toString(),
                'title': r.title,
                'description': r.description,
              },)
          .toList(),
      'issueAnalysis': {
        'issues': analysis.issueAnalysis.issues.length,
        'warnings': analysis.issueAnalysis.warnings.length,
        'overallRisk': analysis.issueAnalysis.overallRisk.toString(),
      },
    };

    return ExportResult(
      format: ExportFormat.json,
      data: json.encode(jsonData),
      filename: 'simulation_analysis_${analysis.simulationId}.json',
      size: json.encode(jsonData).length,
    );
  }

  ExportResult _exportToCsv(AnalysisResult analysis, ExportOptions options) {
    final csv = StringBuffer();
    csv.writeln('Property,Value');
    csv.writeln('Simulation ID,${analysis.simulationId}');
    csv.writeln('Timestamp,${analysis.timestamp.toIso8601String()}');
    csv.writeln('Compute Units,${analysis.computeAnalysis.unitsConsumed}');
    csv.writeln('Estimated Fee,${analysis.computeAnalysis.estimatedFee}');
    csv.writeln('Efficiency,${analysis.computeAnalysis.efficiency}');
    csv.writeln('Total Accounts,${analysis.accountAnalysis.totalAccounts}');
    csv.writeln('Issues Count,${analysis.issueAnalysis.issues.length}');
    csv.writeln('Warnings Count,${analysis.issueAnalysis.warnings.length}');

    return ExportResult(
      format: ExportFormat.csv,
      data: csv.toString(),
      filename: 'simulation_analysis_${analysis.simulationId}.csv',
      size: csv.toString().length,
    );
  }

  ExportResult _exportToMarkdown(
      AnalysisResult analysis, ExportOptions options,) {
    final md = StringBuffer();
    md.writeln('# Simulation Analysis Report');
    md.writeln();
    md.writeln('**Simulation ID:** ${analysis.simulationId}');
    md.writeln('**Timestamp:** ${analysis.timestamp.toIso8601String()}');
    md.writeln();
    md.writeln('## Compute Analysis');
    md.writeln(
        '- **Units Consumed:** ${analysis.computeAnalysis.unitsConsumed}',);
    md.writeln(
        '- **Estimated Fee:** ${analysis.computeAnalysis.estimatedFee} lamports',);
    md.writeln(
        '- **Efficiency:** ${(analysis.computeAnalysis.efficiency * 100).toStringAsFixed(1)}%',);
    md.writeln();
    md.writeln('## Account Analysis');
    md.writeln(
        '- **Total Accounts:** ${analysis.accountAnalysis.totalAccounts}',);
    md.writeln(
        '- **Writable Accounts:** ${analysis.accountAnalysis.writableAccounts}',);
    md.writeln(
        '- **Signer Accounts:** ${analysis.accountAnalysis.signerAccounts}',);
    md.writeln();

    if (analysis.optimizationRecommendations.isNotEmpty) {
      md.writeln('## Optimization Recommendations');
      for (final rec in analysis.optimizationRecommendations) {
        md.writeln('### ${rec.title}');
        md.writeln('**Priority:** ${rec.priority.toString().split('.').last}');
        md.writeln('**Description:** ${rec.description}');
        md.writeln();
      }
    }

    return ExportResult(
      format: ExportFormat.markdown,
      data: md.toString(),
      filename: 'simulation_analysis_${analysis.simulationId}.md',
      size: md.toString().length,
    );
  }

  ExportResult _exportToHtml(AnalysisResult analysis, ExportOptions options) {
    final html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln(
        '<html><head><title>Simulation Analysis Report</title></head><body>',);
    html.writeln('<h1>Simulation Analysis Report</h1>');
    html.writeln(
        '<p><strong>Simulation ID:</strong> ${analysis.simulationId}</p>',);
    html.writeln(
        '<p><strong>Timestamp:</strong> ${analysis.timestamp.toIso8601String()}</p>',);
    html.writeln('<h2>Compute Analysis</h2>');
    html.writeln('<ul>');
    html.writeln(
        '<li><strong>Units Consumed:</strong> ${analysis.computeAnalysis.unitsConsumed}</li>',);
    html.writeln(
        '<li><strong>Estimated Fee:</strong> ${analysis.computeAnalysis.estimatedFee} lamports</li>',);
    html.writeln(
        '<li><strong>Efficiency:</strong> ${(analysis.computeAnalysis.efficiency * 100).toStringAsFixed(1)}%</li>',);
    html.writeln('</ul>');
    html.writeln('</body></html>');

    return ExportResult(
      format: ExportFormat.html,
      data: html.toString(),
      filename: 'simulation_analysis_${analysis.simulationId}.html',
      size: html.toString().length,
    );
  }
}

// Configuration and options classes

/// Configuration for enhanced simulation analysis
class AnalysisConfig {

  const AnalysisConfig({
    this.enableCaching = true,
    this.maxCacheSize = 100,
    this.cacheExpiry = const Duration(hours: 1),
    this.enableDetailedBreakdown = true,
  });
  final bool enableCaching;
  final int maxCacheSize;
  final Duration cacheExpiry;
  final bool enableDetailedBreakdown;
}

/// Options for analysis operations
class AnalysisOptions {

  const AnalysisOptions({
    this.includeOptimizations = true,
    this.includeIssueAnalysis = true,
    this.includePerformanceMetrics = true,
    this.includeCpiAnalysis = true,
  });
  final bool includeOptimizations;
  final bool includeIssueAnalysis;
  final bool includePerformanceMetrics;
  final bool includeCpiAnalysis;

  static AnalysisOptions defaultOptions() => const AnalysisOptions();
}

/// Options for comparison operations
class ComparisonOptions {

  const ComparisonOptions({
    this.includeDetailedDiff = true,
    this.highlightSignificantChanges = true,
    this.significanceThreshold = 0.1, // 10% change threshold
  });
  final bool includeDetailedDiff;
  final bool highlightSignificantChanges;
  final double significanceThreshold;

  static ComparisonOptions defaultOptions() => const ComparisonOptions();
}

/// Options for batch analysis
class BatchAnalysisOptions {

  const BatchAnalysisOptions({
    this.parallel = true,
    this.maxConcurrency = 4,
    this.continueOnError = true,
    this.includePatternAnalysis = true,
  });
  final bool parallel;
  final int maxConcurrency;
  final bool continueOnError;
  final bool includePatternAnalysis;

  static BatchAnalysisOptions defaultOptions() => const BatchAnalysisOptions();
}

/// Options for export operations
class ExportOptions {

  const ExportOptions({
    this.includeRawData = false,
    this.prettyFormat = true,
    this.includeMetadata = true,
  });
  final bool includeRawData;
  final bool prettyFormat;
  final bool includeMetadata;

  static ExportOptions defaultOptions() => const ExportOptions();
}

// Data classes for analysis results

/// Complete analysis result
class AnalysisResult {

  const AnalysisResult({
    required this.simulationId,
    required this.timestamp,
    required this.computeAnalysis,
    required this.accountAnalysis,
    required this.optimizationRecommendations,
    required this.issueAnalysis,
    required this.performanceMetrics,
    required this.cpiAnalysis,
    required this.analysisOptions,
    required this.processingTime,
  });
  final String simulationId;
  final DateTime timestamp;
  final ComputeAnalysis computeAnalysis;
  final AccountAnalysis accountAnalysis;
  final List<OptimizationRecommendation> optimizationRecommendations;
  final IssueAnalysis issueAnalysis;
  final PerformanceMetrics performanceMetrics;
  final CpiAnalysis cpiAnalysis;
  final AnalysisOptions analysisOptions;
  final Duration processingTime;
}

/// Compute unit analysis
class ComputeAnalysis {

  const ComputeAnalysis({
    required this.unitsConsumed,
    required this.estimatedFee,
    required this.efficiency,
    required this.breakdown,
    required this.recommendations,
  });
  final int unitsConsumed;
  final int estimatedFee;
  final double efficiency;
  final ComputeBreakdown breakdown;
  final List<String> recommendations;
}

/// Detailed compute unit breakdown
class ComputeBreakdown {

  const ComputeBreakdown({
    required this.instructionCost,
    required this.accountAccess,
    required this.systemOverhead,
  });
  final double instructionCost;
  final double accountAccess;
  final double systemOverhead;
}

/// Account access analysis
class AccountAnalysis {

  const AccountAnalysis({
    required this.totalAccounts,
    required this.writableAccounts,
    required this.signerAccounts,
    required this.accessPatterns,
    required this.potentialOptimizations,
  });
  final int totalAccounts;
  final int writableAccounts;
  final int signerAccounts;
  final List<AccountAccessPattern> accessPatterns;
  final List<AccountOptimization> potentialOptimizations;
}

/// Account access pattern
class AccountAccessPattern {

  const AccountAccessPattern({
    required this.publicKey,
    required this.isWritable,
    required this.isSigner,
    this.dataSize,
    required this.accessType,
    required this.recommendations,
  });
  final String publicKey;
  final bool isWritable;
  final bool isSigner;
  final int? dataSize;
  final AccountAccessType accessType;
  final List<String> recommendations;
}

/// Account optimization suggestion
class AccountOptimization {

  const AccountOptimization({
    required this.type,
    required this.description,
    required this.impact,
  });
  final String type;
  final String description;
  final String impact;
}

/// Optimization recommendation
class OptimizationRecommendation {

  const OptimizationRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.impact,
    required this.effort,
    required this.suggestedActions,
  });
  final OptimizationType type;
  final Priority priority;
  final String title;
  final String description;
  final OptimizationImpact impact;
  final OptimizationEffort effort;
  final List<String> suggestedActions;
}

/// Issue analysis
class IssueAnalysis {

  const IssueAnalysis({
    required this.issues,
    required this.warnings,
    required this.overallRisk,
  });
  final List<SimulationIssue> issues;
  final List<SimulationWarning> warnings;
  final RiskLevel overallRisk;
}

/// Simulation issue
class SimulationIssue {

  const SimulationIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.details,
    this.suggestedFix,
  });
  final IssueType type;
  final IssueSeverity severity;
  final String message;
  final String? details;
  final String? suggestedFix;
}

/// Simulation warning
class SimulationWarning {

  const SimulationWarning({
    required this.type,
    required this.message,
    this.recommendation,
  });
  final WarningType type;
  final String message;
  final String? recommendation;
}

/// Performance metrics
class PerformanceMetrics {

  const PerformanceMetrics({
    required this.computeUnitsUsed,
    required this.logCount,
    required this.accountCount,
    required this.estimatedNetworkLatency,
    required this.throughputScore,
    required this.resourceUtilization,
  });
  final int computeUnitsUsed;
  final int logCount;
  final int accountCount;
  final Duration estimatedNetworkLatency;
  final double throughputScore;
  final double resourceUtilization;
}

/// CPI analysis
class CpiAnalysis {

  const CpiAnalysis({
    required this.totalCpiCalls,
    required this.maxDepth,
    required this.uniquePrograms,
    required this.callPattern,
    required this.complexity,
  });
  final int totalCpiCalls;
  final int maxDepth;
  final List<String> uniquePrograms;
  final List<CpiCall> callPattern;
  final double complexity;
}

/// CPI call information
class CpiCall {

  const CpiCall({
    required this.programId,
    required this.depth,
    required this.timestamp,
    required this.callType,
  });
  final String programId;
  final int depth;
  final DateTime timestamp;
  final CpiCallType callType;
}

/// Comparison result
class ComparisonResult {

  const ComparisonResult({
    required this.baseline,
    required this.comparisons,
    required this.summary,
    required this.timestamp,
  });
  final AnalysisResult baseline;
  final List<SimulationComparison> comparisons;
  final ComparisonSummary summary;
  final DateTime timestamp;
}

/// Simulation comparison
class SimulationComparison {

  const SimulationComparison({
    required this.index,
    required this.analysis,
    required this.computeUnitsDifference,
    required this.accountCountDifference,
    required this.performanceImprovement,
    required this.significantChanges,
  });
  final int index;
  final AnalysisResult analysis;
  final int computeUnitsDifference;
  final int accountCountDifference;
  final double performanceImprovement;
  final List<String> significantChanges;
}

/// Comparison summary
class ComparisonSummary {

  const ComparisonSummary({
    required this.bestPerforming,
    required this.worstPerforming,
    required this.averageImprovement,
    required this.recommendedOption,
  });
  final int bestPerforming;
  final int worstPerforming;
  final double averageImprovement;
  final int recommendedOption;
}

/// Batch analysis result
class BatchAnalysisResult {

  const BatchAnalysisResult({
    required this.analyses,
    required this.errors,
    required this.aggregatedMetrics,
    required this.patterns,
    required this.timestamp,
  });
  final List<AnalysisResult> analyses;
  final List<BatchAnalysisError> errors;
  final AggregatedMetrics aggregatedMetrics;
  final List<AnalysisPattern> patterns;
  final DateTime timestamp;
}

/// Batch analysis error
class BatchAnalysisError {

  const BatchAnalysisError({
    required this.index,
    required this.simulation,
    required this.error,
  });
  final int index;
  final TransactionSimulationResult simulation;
  final String error;
}

/// Aggregated metrics
class AggregatedMetrics {

  const AggregatedMetrics({
    required this.averageComputeUnits,
    required this.averageAccountCount,
    required this.totalIssues,
    required this.commonOptimizations,
  });
  final double averageComputeUnits;
  final double averageAccountCount;
  final int totalIssues;
  final List<String> commonOptimizations;
}

/// Analysis pattern
class AnalysisPattern {

  const AnalysisPattern({
    required this.type,
    required this.description,
    required this.frequency,
    required this.recommendation,
  });
  final String type;
  final String description;
  final double frequency;
  final String recommendation;
}

/// Export result
class ExportResult {

  const ExportResult({
    required this.format,
    required this.data,
    required this.filename,
    required this.size,
  });
  final ExportFormat format;
  final String data;
  final String filename;
  final int size;
}

/// Cache statistics
class CacheStatistics {

  const CacheStatistics({
    required this.size,
    required this.hits,
    required this.misses,
    required this.hitRate,
  });
  final int size;
  final int hits;
  final int misses;
  final double hitRate;
}

/// Analysis statistics
class AnalysisStatistics {
  int analysisCount = 0;
  int successfulAnalyses = 0;
  int failedAnalyses = 0;
  int cacheHits = 0;
  int cacheClears = 0;
}

// Enums

enum AccountAccessType {
  readonly,
  writable,
  signer,
  writableSigner,
}

enum OptimizationType {
  computeUnits,
  accounts,
  fees,
  structure,
  cpi,
}

enum Priority {
  low,
  medium,
  high,
  critical,
}

enum OptimizationImpact {
  low,
  medium,
  high,
}

enum OptimizationEffort {
  low,
  medium,
  high,
}

enum IssueType {
  simulationError,
  accountConflict,
  computeLimit,
  invalidAccount,
  insufficientFunds,
}

enum IssueSeverity {
  info,
  warning,
  error,
  critical,
}

enum WarningType {
  highComputeUsage,
  manyWritableAccounts,
  potentialConflict,
  suboptimalPattern,
}

enum RiskLevel {
  low,
  medium,
  high,
}

enum CpiCallType {
  invoke,
  success,
  failed,
}

enum ExportFormat {
  json,
  csv,
  markdown,
  html,
}
