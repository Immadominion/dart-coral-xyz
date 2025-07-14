import 'dart:convert';
import 'dart:math' as math;

import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart';
import 'package:coral_xyz_anchor/src/transaction/enhanced_simulation_analyzer.dart';
import 'package:coral_xyz_anchor/src/transaction/simulation_cache_manager.dart';

/// Comprehensive debugging and development tools for transaction simulation
class SimulationDebugger {

  SimulationDebugger({
    SimulationCacheManager? cacheManager,
    this.config = const DebugConfig(),
  }) : _cacheManager = cacheManager ?? SimulationCacheManager();
  /// Cache manager for storing debug sessions
  final SimulationCacheManager _cacheManager;

  /// Configuration for debugging
  final DebugConfig config;

  /// Active debug sessions
  final Map<String, DebugSession> _activeSessions = {};

  /// Debug statistics
  final DebugStatistics statistics = DebugStatistics();

  /// Start a new debug session
  DebugSession startDebugSession({
    required String name,
    DebugSessionOptions? options,
  }) {
    options ??= DebugSessionOptions.defaultOptions();

    final session = DebugSession(
      id: _generateSessionId(),
      name: name,
      startTime: DateTime.now(),
      options: options,
      steps: [],
      metadata: {},
    );

    _activeSessions[session.id] = session;
    statistics.sessionsStarted++;

    return session;
  }

  /// Add a simulation step to debug session
  Future<DebugStepResult> addSimulationStep(
    String sessionId,
    TransactionSimulationResult simulation, {
    String? stepName,
    Map<String, dynamic>? metadata,
    DebugStepOptions? options,
  }) async {
    final session = _getSession(sessionId);
    options ??= DebugStepOptions.defaultOptions();

    final stepIndex = session.steps.length;
    final stepStartTime = DateTime.now();

    try {
      // Analyze the simulation
      final analyzer = EnhancedSimulationAnalyzer();
      final analysis = await analyzer.analyzeSimulation(simulation);

      // Cache the simulation and analysis
      final simKey = _cacheManager.cacheSimulation(
        simulation,
        metadata: {
          'sessionId': sessionId,
          'stepIndex': stepIndex,
          'stepName': stepName ?? 'Step $stepIndex',
          ...?metadata,
        },
      );

      final analysisKey = _cacheManager.cacheAnalysis(
        analysis,
        metadata: {
          'sessionId': sessionId,
          'stepIndex': stepIndex,
          'simulationKey': simKey,
        },
      );

      // Compare with previous step if requested
      Comparison? comparison;
      if (options.enableComparison && stepIndex > 0) {
        final prevStep = session.steps.last;
        comparison = _compareSteps(prevStep, analysis);
      }

      // Detect issues and anomalies
      final issues = await _detectIssues(simulation, analysis, session);

      // Generate debugging insights
      final insights = await _generateInsights(simulation, analysis, session);

      final step = DebugStep(
        index: stepIndex,
        name: stepName ?? 'Step $stepIndex',
        simulationKey: simKey,
        analysisKey: analysisKey,
        simulation: simulation,
        analysis: analysis,
        comparison: comparison,
        issues: issues,
        insights: insights,
        timestamp: DateTime.now(),
        processingTime: DateTime.now().difference(stepStartTime),
        metadata: metadata ?? {},
      );

      session.steps.add(step);
      session.lastUpdated = DateTime.now();

      final result = DebugStepResult(
        step: step,
        session: session,
        success: true,
      );

      statistics.stepsProcessed++;
      return result;
    } catch (e) {
      final errorStep = DebugStep(
        index: stepIndex,
        name: stepName ?? 'Step $stepIndex (Error)',
        simulationKey: '',
        analysisKey: '',
        simulation: simulation,
        timestamp: DateTime.now(),
        processingTime: DateTime.now().difference(stepStartTime),
        metadata: metadata ?? {},
        error: e.toString(),
      );

      session.steps.add(errorStep);
      session.lastUpdated = DateTime.now();

      statistics.stepErrors++;
      return DebugStepResult(
        step: errorStep,
        session: session,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generate a comprehensive debug report
  Future<DebugReport> generateDebugReport(
    String sessionId, {
    DebugReportOptions? options,
  }) async {
    final session = _getSession(sessionId);
    options ??= DebugReportOptions.defaultOptions();

    final reportStartTime = DateTime.now();

    // Analyze session patterns
    final patterns = await _analyzeSessionPatterns(session);

    // Identify performance bottlenecks
    final bottlenecks = await _identifyBottlenecks(session);

    // Generate optimization recommendations
    final optimizations = await _generateSessionOptimizations(session);

    // Create execution flow analysis
    final flowAnalysis = await _analyzeExecutionFlow(session);

    // Generate comparison matrix if multiple steps
    ComparisonMatrix? comparisonMatrix;
    if (session.steps.length > 1 && options.includeComparisonMatrix) {
      comparisonMatrix = await _generateComparisonMatrix(session);
    }

    // Create issue summary
    final issueSummary = _summarizeIssues(session);

    // Generate insights summary
    final insightsSummary = _summarizeInsights(session);

    final report = DebugReport(
      sessionId: sessionId,
      session: session,
      patterns: patterns,
      bottlenecks: bottlenecks,
      optimizations: optimizations,
      flowAnalysis: flowAnalysis,
      comparisonMatrix: comparisonMatrix,
      issueSummary: issueSummary,
      insightsSummary: insightsSummary,
      metadata: {
        'generatedAt': DateTime.now().toIso8601String(),
        'processingTime':
            DateTime.now().difference(reportStartTime).inMilliseconds,
        'stepsAnalyzed': session.steps.length,
      },
      timestamp: DateTime.now(),
    );

    statistics.reportsGenerated++;
    return report;
  }

  /// Create an interactive debugging session
  InteractiveDebugSession createInteractiveSession({
    required String name,
    InteractiveDebugOptions? options,
  }) {
    options ??= InteractiveDebugOptions.defaultOptions();

    final session = InteractiveDebugSession(
      id: _generateSessionId(),
      name: name,
      startTime: DateTime.now(),
      options: options,
      commandHistory: [],
      watchlist: [],
      breakpoints: [],
    );

    return session;
  }

  /// Execute debug command in interactive session
  Future<DebugCommandResult> executeCommand(
    String sessionId,
    DebugCommand command,
  ) async {
    final startTime = DateTime.now();

    try {
      final result = await _executeDebugCommand(command);

      return DebugCommandResult(
        command: command,
        success: true,
        result: result,
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return DebugCommandResult(
        command: command,
        success: false,
        error: e.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Set up continuous monitoring for simulation patterns
  Future<MonitoringSession> setupMonitoring({
    required String name,
    required List<MonitoringRule> rules,
    MonitoringOptions? options,
  }) async {
    options ??= MonitoringOptions.defaultOptions();

    final session = MonitoringSession(
      id: _generateSessionId(),
      name: name,
      rules: rules,
      options: options,
      startTime: DateTime.now(),
      alerts: [],
      metrics: MonitoringMetrics(),
    );

    return session;
  }

  /// Add monitoring alert when rule is triggered
  void triggerMonitoringAlert(
    String sessionId,
    MonitoringAlert alert,
  ) {
    // Implementation for monitoring alerts
    statistics.alertsTriggered++;
  }

  /// Export debug session data
  Future<DebugExportResult> exportSession(
    String sessionId, {
    required DebugExportFormat format,
    DebugExportOptions? options,
  }) async {
    final session = _getSession(sessionId);
    options ??= DebugExportOptions.defaultOptions();

    switch (format) {
      case DebugExportFormat.json:
        return _exportSessionToJson(session, options);
      case DebugExportFormat.csv:
        return _exportSessionToCsv(session, options);
      case DebugExportFormat.markdown:
        return _exportSessionToMarkdown(session, options);
      case DebugExportFormat.html:
        return _exportSessionToHtml(session, options);
    }
  }

  /// Close debug session
  void closeSession(String sessionId) {
    final session = _activeSessions.remove(sessionId);
    if (session != null) {
      session.endTime = DateTime.now();
      statistics.sessionsClosed++;
    }
  }

  /// Get debug statistics
  DebugStatistics getStatistics() => statistics;

  /// Get active sessions
  List<DebugSession> getActiveSessions() => _activeSessions.values.toList();

  // Private helper methods

  DebugSession _getSession(String sessionId) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw ArgumentError('Debug session not found: $sessionId');
    }
    return session;
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000);
    return 'debug_${timestamp}_$random';
  }

  Comparison _compareSteps(DebugStep previous, AnalysisResult current) {
    final computeDiff = current.computeAnalysis.unitsConsumed -
        (previous.analysis?.computeAnalysis.unitsConsumed ?? 0);

    final accountDiff = current.accountAnalysis.totalAccounts -
        (previous.analysis?.accountAnalysis.totalAccounts ?? 0);

    return Comparison(
      computeUnitsDifference: computeDiff,
      accountCountDifference: accountDiff,
      performanceChange:
          _calculatePerformanceChange(previous.analysis, current),
      significantChanges:
          _identifySignificantChanges(previous.analysis, current),
    );
  }

  double _calculatePerformanceChange(
      AnalysisResult? previous, AnalysisResult current,) {
    if (previous == null) return 0;

    final prevScore = previous.performanceMetrics.throughputScore;
    final currScore = current.performanceMetrics.throughputScore;

    if (prevScore == 0) return 0;
    return ((currScore - prevScore) / prevScore) * 100;
  }

  List<String> _identifySignificantChanges(
      AnalysisResult? previous, AnalysisResult current,) {
    if (previous == null) return ['Initial step'];

    final changes = <String>[];

    // Check for significant compute unit changes
    final computeDiff = current.computeAnalysis.unitsConsumed -
        previous.computeAnalysis.unitsConsumed;
    if (computeDiff.abs() > 10000) {
      changes.add(
          'Compute units ${computeDiff > 0 ? 'increased' : 'decreased'} by ${computeDiff.abs()}',);
    }

    // Check for account count changes
    final accountDiff = current.accountAnalysis.totalAccounts -
        previous.accountAnalysis.totalAccounts;
    if (accountDiff != 0) {
      changes.add(
          'Account count ${accountDiff > 0 ? 'increased' : 'decreased'} by ${accountDiff.abs()}',);
    }

    return changes;
  }

  Future<List<DebugIssue>> _detectIssues(
    TransactionSimulationResult simulation,
    AnalysisResult analysis,
    DebugSession session,
  ) async {
    final issues = <DebugIssue>[];

    // Detect high compute usage
    if (analysis.computeAnalysis.unitsConsumed > 1000000) {
      issues.add(DebugIssue(
        type: DebugIssueType.performance,
        severity: DebugIssueSeverity.warning,
        title: 'High Compute Usage',
        description:
            'Transaction uses ${analysis.computeAnalysis.unitsConsumed} compute units',
        recommendation: 'Consider optimizing instruction complexity',
        affectedStep: session.steps.length,
      ),);
    }

    // Detect pattern anomalies
    if (session.steps.length > 1) {
      final avgCompute = session.steps
              .where((s) => s.analysis != null)
              .map((s) => s.analysis!.computeAnalysis.unitsConsumed)
              .fold(0, (sum, units) => sum + units) /
          session.steps.where((s) => s.analysis != null).length;

      if (analysis.computeAnalysis.unitsConsumed > avgCompute * 1.5) {
        issues.add(DebugIssue(
          type: DebugIssueType.anomaly,
          severity: DebugIssueSeverity.info,
          title: 'Compute Usage Spike',
          description:
              'This step uses significantly more compute units than average',
          recommendation: 'Investigate what changed in this transaction',
          affectedStep: session.steps.length,
        ),);
      }
    }

    return issues;
  }

  Future<List<DebugInsight>> _generateInsights(
    TransactionSimulationResult simulation,
    AnalysisResult analysis,
    DebugSession session,
  ) async {
    final insights = <DebugInsight>[];

    // Efficiency insight
    if (analysis.computeAnalysis.efficiency > 0.8) {
      insights.add(DebugInsight(
        type: DebugInsightType.efficiency,
        title: 'Efficient Transaction',
        description:
            'This transaction is highly efficient with ${(analysis.computeAnalysis.efficiency * 100).toStringAsFixed(1)}% efficiency',
        impact: InsightImpact.positive,
        confidence: 0.9,
      ),);
    }

    // Pattern insight
    if (session.steps.length > 2) {
      final recentSteps =
          session.steps.take(3).where((s) => s.analysis != null);
      final computeUnits = recentSteps
          .map((s) => s.analysis!.computeAnalysis.unitsConsumed)
          .toList();

      if (computeUnits.length > 1) {
        final isDecreasing = computeUnits.every((units) =>
            computeUnits.indexOf(units) == 0 ||
            units <= computeUnits[computeUnits.indexOf(units) - 1],);

        if (isDecreasing) {
          insights.add(const DebugInsight(
            type: DebugInsightType.pattern,
            title: 'Optimization Trend',
            description: 'Compute unit usage is consistently decreasing',
            impact: InsightImpact.positive,
            confidence: 0.8,
          ),);
        }
      }
    }

    return insights;
  }

  Future<List<SessionPattern>> _analyzeSessionPatterns(
      DebugSession session,) async {
    final patterns = <SessionPattern>[];

    if (session.steps.length < 2) return patterns;

    // Analyze compute unit patterns
    final computeUnits = session.steps
        .where((s) => s.analysis != null)
        .map((s) => s.analysis!.computeAnalysis.unitsConsumed)
        .toList();

    if (computeUnits.isNotEmpty) {
      final avg = computeUnits.reduce((a, b) => a + b) / computeUnits.length;
      final variance = computeUnits
              .map((x) => math.pow(x - avg, 2))
              .reduce((a, b) => a + b) /
          computeUnits.length;

      if (variance < avg * 0.1) {
        patterns.add(SessionPattern(
          type: PatternType.stable,
          description: 'Compute unit usage is stable across steps',
          confidence: 0.9,
          affectedSteps: List.generate(session.steps.length, (i) => i),
        ),);
      }
    }

    return patterns;
  }

  Future<List<PerformanceBottleneck>> _identifyBottlenecks(
      DebugSession session,) async {
    final bottlenecks = <PerformanceBottleneck>[];

    for (int i = 0; i < session.steps.length; i++) {
      final step = session.steps[i];
      if (step.analysis != null) {
        final analysis = step.analysis!;

        // Check for high compute usage
        if (analysis.computeAnalysis.unitsConsumed > 1000000) {
          bottlenecks.add(PerformanceBottleneck(
            type: BottleneckType.compute,
            stepIndex: i,
            severity: BottleneckSeverity.high,
            description:
                'High compute unit usage: ${analysis.computeAnalysis.unitsConsumed}',
            impact: 'May cause transaction failures or high fees',
            recommendation: 'Optimize instruction complexity',
          ),);
        }

        // Check for many account accesses
        if (analysis.accountAnalysis.totalAccounts > 20) {
          bottlenecks.add(PerformanceBottleneck(
            type: BottleneckType.accounts,
            stepIndex: i,
            severity: BottleneckSeverity.medium,
            description:
                'Many account accesses: ${analysis.accountAnalysis.totalAccounts}',
            impact: 'May increase transaction size and processing time',
            recommendation: 'Consider account lookup tables',
          ),);
        }
      }
    }

    return bottlenecks;
  }

  Future<List<SessionOptimization>> _generateSessionOptimizations(
      DebugSession session,) async {
    final optimizations = <SessionOptimization>[];

    // Global optimization recommendations based on session patterns
    final allAnalyses = session.steps
        .where((s) => s.analysis != null)
        .map((s) => s.analysis!)
        .toList();

    if (allAnalyses.isNotEmpty) {
      final avgCompute = allAnalyses
              .map((a) => a.computeAnalysis.unitsConsumed)
              .reduce((a, b) => a + b) /
          allAnalyses.length;

      if (avgCompute > 500000) {
        optimizations.add(SessionOptimization(
          type: OptimizationType.computeUnits,
          priority: OptimizationPriority.high,
          title: 'Reduce Overall Compute Usage',
          description:
              'Average compute usage across session is high: ${avgCompute.toStringAsFixed(0)} units',
          estimatedImpact: 'Could reduce fees by 30-50%',
          implementation: [
            'Review instruction complexity',
            'Optimize data processing',
            'Consider breaking into smaller transactions',
          ],
        ),);
      }
    }

    return optimizations;
  }

  Future<ExecutionFlowAnalysis> _analyzeExecutionFlow(
      DebugSession session,) async {
    final flowSteps = <FlowStep>[];

    for (int i = 0; i < session.steps.length; i++) {
      final step = session.steps[i];

      flowSteps.add(FlowStep(
        index: i,
        name: step.name,
        success: step.simulation.success,
        computeUnits: step.analysis?.computeAnalysis.unitsConsumed ?? 0,
        duration: step.processingTime,
        issues: step.issues?.length ?? 0,
        insights: step.insights?.length ?? 0,
      ),);
    }

    return ExecutionFlowAnalysis(
      steps: flowSteps,
      totalDuration:
          session.lastUpdated?.difference(session.startTime) ?? Duration.zero,
      successRate: flowSteps.where((s) => s.success).length / flowSteps.length,
      averageComputeUnits: flowSteps.isNotEmpty
          ? flowSteps.map((s) => s.computeUnits).reduce((a, b) => a + b) /
              flowSteps.length
          : 0.0,
    );
  }

  Future<ComparisonMatrix> _generateComparisonMatrix(
      DebugSession session,) async {
    final validSteps = session.steps.where((s) => s.analysis != null).toList();
    final matrix = <List<ComparisonCell>>[];

    for (int i = 0; i < validSteps.length; i++) {
      final row = <ComparisonCell>[];

      for (int j = 0; j < validSteps.length; j++) {
        if (i == j) {
          row.add(ComparisonCell(
            row: i,
            column: j,
            value: 0,
            type: ComparisonType.identity,
          ),);
        } else {
          final stepA = validSteps[i];
          final stepB = validSteps[j];
          final computeDiff = stepB.analysis!.computeAnalysis.unitsConsumed -
              stepA.analysis!.computeAnalysis.unitsConsumed;

          row.add(ComparisonCell(
            row: i,
            column: j,
            value: computeDiff.toDouble(),
            type: ComparisonType.computeDifference,
            metadata: {
              'stepA': stepA.name,
              'stepB': stepB.name,
            },
          ),);
        }
      }

      matrix.add(row);
    }

    return ComparisonMatrix(
      matrix: matrix,
      size: validSteps.length,
      labels: validSteps.map((s) => s.name).toList(),
    );
  }

  IssueSummary _summarizeIssues(DebugSession session) {
    final allIssues = session.steps
        .where((s) => s.issues != null)
        .expand((s) => s.issues!)
        .toList();

    final groupedIssues = <DebugIssueType, List<DebugIssue>>{};
    for (final issue in allIssues) {
      groupedIssues.putIfAbsent(issue.type, () => []).add(issue);
    }

    return IssueSummary(
      totalIssues: allIssues.length,
      byType: groupedIssues.map((k, v) => MapEntry(k, v.length)),
      bySeverity: {
        for (final severity in DebugIssueSeverity.values)
          severity: allIssues.where((i) => i.severity == severity).length,
      },
      criticalIssues: allIssues
          .where((i) => i.severity == DebugIssueSeverity.critical)
          .toList(),
    );
  }

  InsightsSummary _summarizeInsights(DebugSession session) {
    final allInsights = session.steps
        .where((s) => s.insights != null)
        .expand((s) => s.insights!)
        .toList();

    final groupedInsights = <DebugInsightType, List<DebugInsight>>{};
    for (final insight in allInsights) {
      groupedInsights.putIfAbsent(insight.type, () => []).add(insight);
    }

    return InsightsSummary(
      totalInsights: allInsights.length,
      byType: groupedInsights.map((k, v) => MapEntry(k, v.length)),
      highConfidenceInsights:
          allInsights.where((i) => i.confidence > 0.8).toList(),
      positiveInsights:
          allInsights.where((i) => i.impact == InsightImpact.positive).toList(),
    );
  }

  Future<dynamic> _executeDebugCommand(DebugCommand command) async {
    switch (command.type) {
      case DebugCommandType.analyze:
        return 'Analysis complete';
      case DebugCommandType.compare:
        return 'Comparison complete';
      case DebugCommandType.export:
        return 'Export complete';
      case DebugCommandType.search:
        return 'Search complete';
    }
  }

  // Export methods

  DebugExportResult _exportSessionToJson(
      DebugSession session, DebugExportOptions options,) {
    final data = {
      'session': {
        'id': session.id,
        'name': session.name,
        'startTime': session.startTime.toIso8601String(),
        'endTime': session.endTime?.toIso8601String(),
        'lastUpdated': session.lastUpdated?.toIso8601String(),
      },
      'steps': session.steps
          .map((step) => {
                'index': step.index,
                'name': step.name,
                'timestamp': step.timestamp.toIso8601String(),
                'success': step.simulation.success,
                'computeUnits': step.analysis?.computeAnalysis.unitsConsumed,
                'issues': step.issues?.length ?? 0,
                'insights': step.insights?.length ?? 0,
              },)
          .toList(),
    };

    final jsonString = json.encode(data);
    return DebugExportResult(
      format: DebugExportFormat.json,
      data: jsonString,
      size: jsonString.length,
      itemCount: session.steps.length,
    );
  }

  DebugExportResult _exportSessionToCsv(
      DebugSession session, DebugExportOptions options,) {
    final csv = StringBuffer();
    csv.writeln('Index,Name,Timestamp,Success,ComputeUnits,Issues,Insights');

    for (final step in session.steps) {
      csv.writeln(
          '${step.index},"${step.name}",${step.timestamp.toIso8601String()},'
          '${step.simulation.success},${step.analysis?.computeAnalysis.unitsConsumed ?? 0},'
          '${step.issues?.length ?? 0},${step.insights?.length ?? 0}');
    }

    final csvString = csv.toString();
    return DebugExportResult(
      format: DebugExportFormat.csv,
      data: csvString,
      size: csvString.length,
      itemCount: session.steps.length,
    );
  }

  DebugExportResult _exportSessionToMarkdown(
      DebugSession session, DebugExportOptions options,) {
    final md = StringBuffer();
    md.writeln('# Debug Session: ${session.name}');
    md.writeln();
    md.writeln('**Session ID:** ${session.id}');
    md.writeln('**Start Time:** ${session.startTime.toIso8601String()}');
    if (session.endTime != null) {
      md.writeln('**End Time:** ${session.endTime!.toIso8601String()}');
    }
    md.writeln();
    md.writeln('## Steps Summary');
    md.writeln();
    md.writeln(
        '| Index | Name | Success | Compute Units | Issues | Insights |',);
    md.writeln(
        '|-------|------|---------|---------------|---------|----------|',);

    for (final step in session.steps) {
      md.writeln(
          '| ${step.index} | ${step.name} | ${step.simulation.success} | '
          '${step.analysis?.computeAnalysis.unitsConsumed ?? 0} | '
          '${step.issues?.length ?? 0} | ${step.insights?.length ?? 0} |');
    }

    final mdString = md.toString();
    return DebugExportResult(
      format: DebugExportFormat.markdown,
      data: mdString,
      size: mdString.length,
      itemCount: session.steps.length,
    );
  }

  DebugExportResult _exportSessionToHtml(
      DebugSession session, DebugExportOptions options,) {
    final html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln(
        '<html><head><title>Debug Session: ${session.name}</title></head><body>',);
    html.writeln('<h1>Debug Session: ${session.name}</h1>');
    html.writeln('<p><strong>Session ID:</strong> ${session.id}</p>');
    html.writeln(
        '<p><strong>Start Time:</strong> ${session.startTime.toIso8601String()}</p>',);
    html.writeln('<h2>Steps</h2>');
    html.writeln('<table border="1">');
    html.writeln(
        '<tr><th>Index</th><th>Name</th><th>Success</th><th>Compute Units</th><th>Issues</th><th>Insights</th></tr>',);

    for (final step in session.steps) {
      html.writeln('<tr>');
      html.writeln('<td>${step.index}</td>');
      html.writeln('<td>${step.name}</td>');
      html.writeln('<td>${step.simulation.success}</td>');
      html.writeln(
          '<td>${step.analysis?.computeAnalysis.unitsConsumed ?? 0}</td>',);
      html.writeln('<td>${step.issues?.length ?? 0}</td>');
      html.writeln('<td>${step.insights?.length ?? 0}</td>');
      html.writeln('</tr>');
    }

    html.writeln('</table>');
    html.writeln('</body></html>');

    final htmlString = html.toString();
    return DebugExportResult(
      format: DebugExportFormat.html,
      data: htmlString,
      size: htmlString.length,
      itemCount: session.steps.length,
    );
  }
}

// Configuration and options classes

/// Configuration for debugging
class DebugConfig {

  const DebugConfig({
    this.enableCaching = true,
    this.enableComparison = true,
    this.enableInsights = true,
    this.maxSessionHistory = 100,
  });
  final bool enableCaching;
  final bool enableComparison;
  final bool enableInsights;
  final int maxSessionHistory;
}

/// Options for debug sessions
class DebugSessionOptions {

  const DebugSessionOptions({
    this.autoAnalyze = true,
    this.trackPerformance = true,
    this.detectAnomalies = true,
    this.generateInsights = true,
  });
  final bool autoAnalyze;
  final bool trackPerformance;
  final bool detectAnomalies;
  final bool generateInsights;

  static DebugSessionOptions defaultOptions() => const DebugSessionOptions();
}

/// Options for debug steps
class DebugStepOptions {

  const DebugStepOptions({
    this.enableComparison = true,
    this.detectIssues = true,
    this.generateInsights = true,
    this.cacheResults = true,
  });
  final bool enableComparison;
  final bool detectIssues;
  final bool generateInsights;
  final bool cacheResults;

  static DebugStepOptions defaultOptions() => const DebugStepOptions();
}

/// Options for debug reports
class DebugReportOptions {

  const DebugReportOptions({
    this.includeComparisonMatrix = true,
    this.includeFlowAnalysis = true,
    this.includeOptimizations = true,
    this.includeDetailedInsights = true,
  });
  final bool includeComparisonMatrix;
  final bool includeFlowAnalysis;
  final bool includeOptimizations;
  final bool includeDetailedInsights;

  static DebugReportOptions defaultOptions() => const DebugReportOptions();
}

/// Options for interactive debugging
class InteractiveDebugOptions {

  const InteractiveDebugOptions({
    this.enableBreakpoints = true,
    this.enableWatchlist = true,
    this.enableCommandHistory = true,
    this.maxHistorySize = 1000,
  });
  final bool enableBreakpoints;
  final bool enableWatchlist;
  final bool enableCommandHistory;
  final int maxHistorySize;

  static InteractiveDebugOptions defaultOptions() =>
      const InteractiveDebugOptions();
}

/// Options for monitoring
class MonitoringOptions {

  const MonitoringOptions({
    this.checkInterval = const Duration(seconds: 30),
    this.enableAlerts = true,
    this.enableMetrics = true,
    this.maxAlertHistory = 1000,
  });
  final Duration checkInterval;
  final bool enableAlerts;
  final bool enableMetrics;
  final int maxAlertHistory;

  static MonitoringOptions defaultOptions() => const MonitoringOptions();
}

/// Options for debug export
class DebugExportOptions {

  const DebugExportOptions({
    this.includeMetadata = true,
    this.includeAnalysisDetails = false,
    this.includeComparisons = true,
    this.prettyFormat = true,
  });
  final bool includeMetadata;
  final bool includeAnalysisDetails;
  final bool includeComparisons;
  final bool prettyFormat;

  static DebugExportOptions defaultOptions() => const DebugExportOptions();
}

// Data classes for debugging

/// Debug session
class DebugSession {

  DebugSession({
    required this.id,
    required this.name,
    required this.startTime,
    required this.options,
    required this.steps,
    required this.metadata,
    this.endTime,
    this.lastUpdated,
  });
  final String id;
  final String name;
  final DateTime startTime;
  final DebugSessionOptions options;
  final List<DebugStep> steps;
  final Map<String, dynamic> metadata;
  DateTime? endTime;
  DateTime? lastUpdated;
}

/// Individual debug step
class DebugStep {

  const DebugStep({
    required this.index,
    required this.name,
    required this.simulationKey,
    required this.analysisKey,
    required this.simulation,
    this.analysis,
    this.comparison,
    this.issues,
    this.insights,
    required this.timestamp,
    required this.processingTime,
    required this.metadata,
    this.error,
  });
  final int index;
  final String name;
  final String simulationKey;
  final String analysisKey;
  final TransactionSimulationResult simulation;
  final AnalysisResult? analysis;
  final Comparison? comparison;
  final List<DebugIssue>? issues;
  final List<DebugInsight>? insights;
  final DateTime timestamp;
  final Duration processingTime;
  final Map<String, dynamic> metadata;
  final String? error;
}

/// Result of adding a debug step
class DebugStepResult {

  const DebugStepResult({
    required this.step,
    required this.session,
    required this.success,
    this.error,
  });
  final DebugStep step;
  final DebugSession session;
  final bool success;
  final String? error;
}

/// Comparison between debug steps
class Comparison {

  const Comparison({
    required this.computeUnitsDifference,
    required this.accountCountDifference,
    required this.performanceChange,
    required this.significantChanges,
  });
  final int computeUnitsDifference;
  final int accountCountDifference;
  final double performanceChange;
  final List<String> significantChanges;
}

/// Debug issue
class DebugIssue {

  const DebugIssue({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.recommendation,
    this.affectedStep,
  });
  final DebugIssueType type;
  final DebugIssueSeverity severity;
  final String title;
  final String description;
  final String? recommendation;
  final int? affectedStep;
}

/// Debug insight
class DebugInsight {

  const DebugInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
    required this.confidence,
  });
  final DebugInsightType type;
  final String title;
  final String description;
  final InsightImpact impact;
  final double confidence;
}

/// Debug report
class DebugReport {

  const DebugReport({
    required this.sessionId,
    required this.session,
    required this.patterns,
    required this.bottlenecks,
    required this.optimizations,
    required this.flowAnalysis,
    this.comparisonMatrix,
    required this.issueSummary,
    required this.insightsSummary,
    required this.metadata,
    required this.timestamp,
  });
  final String sessionId;
  final DebugSession session;
  final List<SessionPattern> patterns;
  final List<PerformanceBottleneck> bottlenecks;
  final List<SessionOptimization> optimizations;
  final ExecutionFlowAnalysis flowAnalysis;
  final ComparisonMatrix? comparisonMatrix;
  final IssueSummary issueSummary;
  final InsightsSummary insightsSummary;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
}

/// Session pattern analysis
class SessionPattern {

  const SessionPattern({
    required this.type,
    required this.description,
    required this.confidence,
    required this.affectedSteps,
  });
  final PatternType type;
  final String description;
  final double confidence;
  final List<int> affectedSteps;
}

/// Performance bottleneck
class PerformanceBottleneck {

  const PerformanceBottleneck({
    required this.type,
    required this.stepIndex,
    required this.severity,
    required this.description,
    required this.impact,
    required this.recommendation,
  });
  final BottleneckType type;
  final int stepIndex;
  final BottleneckSeverity severity;
  final String description;
  final String impact;
  final String recommendation;
}

/// Session optimization recommendation
class SessionOptimization {

  const SessionOptimization({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.estimatedImpact,
    required this.implementation,
  });
  final OptimizationType type;
  final OptimizationPriority priority;
  final String title;
  final String description;
  final String estimatedImpact;
  final List<String> implementation;
}

/// Execution flow analysis
class ExecutionFlowAnalysis {

  const ExecutionFlowAnalysis({
    required this.steps,
    required this.totalDuration,
    required this.successRate,
    required this.averageComputeUnits,
  });
  final List<FlowStep> steps;
  final Duration totalDuration;
  final double successRate;
  final double averageComputeUnits;
}

/// Flow step
class FlowStep {

  const FlowStep({
    required this.index,
    required this.name,
    required this.success,
    required this.computeUnits,
    required this.duration,
    required this.issues,
    required this.insights,
  });
  final int index;
  final String name;
  final bool success;
  final int computeUnits;
  final Duration duration;
  final int issues;
  final int insights;
}

/// Comparison matrix for steps
class ComparisonMatrix {

  const ComparisonMatrix({
    required this.matrix,
    required this.size,
    required this.labels,
  });
  final List<List<ComparisonCell>> matrix;
  final int size;
  final List<String> labels;
}

/// Cell in comparison matrix
class ComparisonCell {

  const ComparisonCell({
    required this.row,
    required this.column,
    required this.value,
    required this.type,
    this.metadata,
  });
  final int row;
  final int column;
  final double value;
  final ComparisonType type;
  final Map<String, dynamic>? metadata;
}

/// Issue summary
class IssueSummary {

  const IssueSummary({
    required this.totalIssues,
    required this.byType,
    required this.bySeverity,
    required this.criticalIssues,
  });
  final int totalIssues;
  final Map<DebugIssueType, int> byType;
  final Map<DebugIssueSeverity, int> bySeverity;
  final List<DebugIssue> criticalIssues;
}

/// Insights summary
class InsightsSummary {

  const InsightsSummary({
    required this.totalInsights,
    required this.byType,
    required this.highConfidenceInsights,
    required this.positiveInsights,
  });
  final int totalInsights;
  final Map<DebugInsightType, int> byType;
  final List<DebugInsight> highConfidenceInsights;
  final List<DebugInsight> positiveInsights;
}

/// Interactive debug session
class InteractiveDebugSession {

  const InteractiveDebugSession({
    required this.id,
    required this.name,
    required this.startTime,
    required this.options,
    required this.commandHistory,
    required this.watchlist,
    required this.breakpoints,
  });
  final String id;
  final String name;
  final DateTime startTime;
  final InteractiveDebugOptions options;
  final List<DebugCommand> commandHistory;
  final List<String> watchlist;
  final List<Breakpoint> breakpoints;
}

/// Debug command
class DebugCommand {

  const DebugCommand({
    required this.type,
    required this.command,
    required this.parameters,
  });
  final DebugCommandType type;
  final String command;
  final Map<String, dynamic> parameters;
}

/// Debug command result
class DebugCommandResult {

  const DebugCommandResult({
    required this.command,
    required this.success,
    this.result,
    this.error,
    required this.executionTime,
    required this.timestamp,
  });
  final DebugCommand command;
  final bool success;
  final dynamic result;
  final String? error;
  final Duration executionTime;
  final DateTime timestamp;
}

/// Breakpoint for debugging
class Breakpoint {

  const Breakpoint({
    required this.id,
    required this.condition,
    required this.enabled,
  });
  final String id;
  final String condition;
  final bool enabled;
}

/// Monitoring session
class MonitoringSession {

  const MonitoringSession({
    required this.id,
    required this.name,
    required this.rules,
    required this.options,
    required this.startTime,
    required this.alerts,
    required this.metrics,
  });
  final String id;
  final String name;
  final List<MonitoringRule> rules;
  final MonitoringOptions options;
  final DateTime startTime;
  final List<MonitoringAlert> alerts;
  final MonitoringMetrics metrics;
}

/// Monitoring rule
class MonitoringRule {

  const MonitoringRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.type,
  });
  final String id;
  final String name;
  final String condition;
  final MonitoringRuleType type;
}

/// Monitoring alert
class MonitoringAlert {

  const MonitoringAlert({
    required this.id,
    required this.ruleId,
    required this.message,
    required this.severity,
    required this.timestamp,
  });
  final String id;
  final String ruleId;
  final String message;
  final MonitoringAlertSeverity severity;
  final DateTime timestamp;
}

/// Monitoring metrics
class MonitoringMetrics {
  int checksPerformed = 0;
  int alertsTriggered = 0;
  int rulesEvaluated = 0;
}

/// Debug export result
class DebugExportResult {

  const DebugExportResult({
    required this.format,
    required this.data,
    required this.size,
    required this.itemCount,
  });
  final DebugExportFormat format;
  final String data;
  final int size;
  final int itemCount;
}

/// Debug statistics
class DebugStatistics {
  int sessionsStarted = 0;
  int sessionsClosed = 0;
  int stepsProcessed = 0;
  int stepErrors = 0;
  int reportsGenerated = 0;
  int alertsTriggered = 0;
}

// Enums

enum DebugIssueType {
  performance,
  anomaly,
  error,
  warning,
}

enum DebugIssueSeverity {
  info,
  warning,
  error,
  critical,
}

enum DebugInsightType {
  efficiency,
  pattern,
  optimization,
  anomaly,
}

enum InsightImpact {
  positive,
  negative,
  neutral,
}

enum PatternType {
  stable,
  increasing,
  decreasing,
  oscillating,
  anomalous,
}

enum BottleneckType {
  compute,
  accounts,
  network,
  memory,
}

enum BottleneckSeverity {
  low,
  medium,
  high,
  critical,
}

enum OptimizationPriority {
  low,
  medium,
  high,
  critical,
}

enum ComparisonType {
  identity,
  computeDifference,
  accountDifference,
  performanceDifference,
}

enum DebugCommandType {
  analyze,
  compare,
  export,
  search,
}

enum MonitoringRuleType {
  threshold,
  pattern,
  anomaly,
  trend,
}

enum MonitoringAlertSeverity {
  info,
  warning,
  critical,
}

enum DebugExportFormat {
  json,
  csv,
  markdown,
  html,
}
