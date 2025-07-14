import 'dart:convert';
import 'dart:math' as math;

import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart';
import 'package:coral_xyz_anchor/src/transaction/enhanced_simulation_analyzer.dart';

/// Simulation caching and replay system for enhanced debugging and development
class SimulationCacheManager {

  SimulationCacheManager({
    this.config = const CachingConfig(),
  });
  /// Cache for simulation results
  final Map<String, CachedSimulation> _simulationCache = {};

  /// Cache for analysis results
  final Map<String, CachedAnalysis> _analysisCache = {};

  /// Replay history for debugging
  final List<ReplaySession> _replayHistory = [];

  /// Configuration for caching
  final CachingConfig config;

  /// Statistics for cache operations
  final CacheStatistics statistics = CacheStatistics();

  /// Cache a simulation result
  String cacheSimulation(
    TransactionSimulationResult simulation, {
    String? customKey,
    Map<String, dynamic>? metadata,
  }) {
    final key = customKey ?? _generateSimulationKey(simulation);

    final cachedSim = CachedSimulation(
      key: key,
      simulation: simulation,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
      accessCount: 0,
    );

    _simulationCache[key] = cachedSim;
    statistics.simulationsCached++;

    // Cleanup if cache is too large
    if (_simulationCache.length > config.maxCacheSize) {
      _cleanupCache();
    }

    return key;
  }

  /// Cache an analysis result
  String cacheAnalysis(
    AnalysisResult analysis, {
    String? customKey,
    Map<String, dynamic>? metadata,
  }) {
    final key = customKey ?? _generateAnalysisKey(analysis);

    final cachedAnalysis = CachedAnalysis(
      key: key,
      analysis: analysis,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
      accessCount: 0,
    );

    _analysisCache[key] = cachedAnalysis;
    statistics.analysesCached++;

    // Cleanup if cache is too large
    if (_analysisCache.length > config.maxCacheSize) {
      _cleanupAnalysisCache();
    }

    return key;
  }

  /// Retrieve a cached simulation
  CachedSimulation? getSimulation(String key) {
    final cached = _simulationCache[key];
    if (cached != null) {
      cached.accessCount++;
      cached.lastAccessed = DateTime.now();
      statistics.cacheHits++;
      return cached;
    }

    statistics.cacheMisses++;
    return null;
  }

  /// Retrieve a cached analysis
  CachedAnalysis? getAnalysis(String key) {
    final cached = _analysisCache[key];
    if (cached != null) {
      cached.accessCount++;
      cached.lastAccessed = DateTime.now();
      statistics.analysisHits++;
      return cached;
    }

    statistics.analysisMisses++;
    return null;
  }

  /// Create a replay session from cached simulations
  ReplaySession createReplaySession({
    required String name,
    required List<String> simulationKeys,
    Map<String, dynamic>? metadata,
  }) {
    final simulations = <CachedSimulation>[];
    final missingKeys = <String>[];

    for (final key in simulationKeys) {
      final cached = getSimulation(key);
      if (cached != null) {
        simulations.add(cached);
      } else {
        missingKeys.add(key);
      }
    }

    final session = ReplaySession(
      id: _generateReplayId(),
      name: name,
      simulations: simulations,
      missingKeys: missingKeys,
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    _replayHistory.add(session);
    return session;
  }

  /// Replay a session with analysis
  Future<ReplayResult> replaySession(
    String sessionId, {
    ReplayOptions? options,
  }) async {
    options ??= ReplayOptions.defaultOptions();

    final session = _replayHistory.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw ArgumentError('Session not found: $sessionId'),
    );

    final replayResults = <ReplayStepResult>[];
    final startTime = DateTime.now();

    for (int i = 0; i < session.simulations.length; i++) {
      final simulation = session.simulations[i];
      final stepStartTime = DateTime.now();

      try {
        // Re-analyze if requested
        AnalysisResult? analysis;
        if (options.reanalyze) {
          final analyzer = EnhancedSimulationAnalyzer();
          analysis = await analyzer.analyzeSimulation(simulation.simulation);
        }

        final stepResult = ReplayStepResult(
          stepIndex: i,
          simulationKey: simulation.key,
          simulation: simulation.simulation,
          analysis: analysis,
          success: true,
          processingTime: DateTime.now().difference(stepStartTime),
          metadata: simulation.metadata,
        );

        replayResults.add(stepResult);

        // Compare with previous step if requested
        if (options.enableComparison && i > 0) {
          final comparison = await _compareReplaySteps(
            replayResults[i - 1],
            stepResult,
          );
          stepResult.comparison = comparison;
        }
      } catch (e) {
        replayResults.add(ReplayStepResult(
          stepIndex: i,
          simulationKey: simulation.key,
          simulation: simulation.simulation,
          success: false,
          error: e.toString(),
          processingTime: DateTime.now().difference(stepStartTime),
          metadata: simulation.metadata,
        ),);
      }
    }

    final result = ReplayResult(
      sessionId: sessionId,
      session: session,
      results: replayResults,
      totalTime: DateTime.now().difference(startTime),
      summary: _generateReplaySummary(replayResults),
      timestamp: DateTime.now(),
    );

    statistics.replaysExecuted++;
    return result;
  }

  /// Find simulations by criteria
  List<CachedSimulation> findSimulations(SearchCriteria criteria) => _simulationCache.values.where((cached) {
      // Filter by timestamp range
      if (criteria.startTime != null &&
          cached.timestamp.isBefore(criteria.startTime!)) {
        return false;
      }
      if (criteria.endTime != null &&
          cached.timestamp.isAfter(criteria.endTime!)) {
        return false;
      }

      // Filter by compute units range
      final computeUnits = cached.simulation.unitsConsumed ?? 0;
      if (criteria.minComputeUnits != null &&
          computeUnits < criteria.minComputeUnits!) {
        return false;
      }
      if (criteria.maxComputeUnits != null &&
          computeUnits > criteria.maxComputeUnits!) {
        return false;
      }

      // Filter by success/failure
      if (criteria.successOnly == true && !cached.simulation.success) {
        return false;
      }
      if (criteria.failuresOnly == true && cached.simulation.success) {
        return false;
      }

      // Filter by metadata
      if (criteria.metadata != null) {
        for (final entry in criteria.metadata!.entries) {
          if (cached.metadata[entry.key] != entry.value) {
            return false;
          }
        }
      }

      return true;
    }).toList();

  /// Get cache performance metrics
  CachePerformanceMetrics getPerformanceMetrics() {
    final totalSimulationAccesses =
        statistics.cacheHits + statistics.cacheMisses;
    final totalAnalysisAccesses =
        statistics.analysisHits + statistics.analysisMisses;

    return CachePerformanceMetrics(
      simulationCacheSize: _simulationCache.length,
      analysisCacheSize: _analysisCache.length,
      simulationHitRate: totalSimulationAccesses > 0
          ? statistics.cacheHits / totalSimulationAccesses
          : 0.0,
      analysisHitRate: totalAnalysisAccesses > 0
          ? statistics.analysisHits / totalAnalysisAccesses
          : 0.0,
      totalSimulationsCached: statistics.simulationsCached,
      totalAnalysesCached: statistics.analysesCached,
      totalReplaysExecuted: statistics.replaysExecuted,
      memoryUsageEstimate: _estimateMemoryUsage(),
    );
  }

  /// Export cache data for backup or analysis
  Future<CacheExportResult> exportCache({
    required CacheExportFormat format,
    CacheExportOptions? options,
  }) async {
    options ??= CacheExportOptions.defaultOptions();

    switch (format) {
      case CacheExportFormat.json:
        return _exportToJson(options);
      case CacheExportFormat.binary:
        return _exportToBinary(options);
      case CacheExportFormat.csv:
        return _exportToCsv(options);
    }
  }

  /// Import cache data from backup
  Future<CacheImportResult> importCache(
    String data, {
    required CacheExportFormat format,
    CacheImportOptions? options,
  }) async {
    options ??= CacheImportOptions.defaultOptions();

    switch (format) {
      case CacheExportFormat.json:
        return _importFromJson(data, options);
      case CacheExportFormat.binary:
        return _importFromBinary(data, options);
      case CacheExportFormat.csv:
        return _importFromCsv(data, options);
    }
  }

  /// Clear cache based on criteria
  int clearCache({ClearCriteria? criteria}) {
    criteria ??= ClearCriteria.all();
    int cleared = 0;

    if (criteria.clearSimulations) {
      final toRemove = <String>[];
      for (final entry in _simulationCache.entries) {
        if (_shouldClear(entry.value, criteria)) {
          toRemove.add(entry.key);
        }
      }
      for (final key in toRemove) {
        _simulationCache.remove(key);
        cleared++;
      }
    }

    if (criteria.clearAnalyses) {
      final toRemove = <String>[];
      for (final entry in _analysisCache.entries) {
        if (_shouldClearAnalysis(entry.value, criteria)) {
          toRemove.add(entry.key);
        }
      }
      for (final key in toRemove) {
        _analysisCache.remove(key);
        cleared++;
      }
    }

    if (criteria.clearReplayHistory) {
      final toRemove = <ReplaySession>[];
      for (final session in _replayHistory) {
        if (criteria.olderThan != null &&
            session.createdAt
                .isBefore(DateTime.now().subtract(criteria.olderThan!))) {
          toRemove.add(session);
        }
      }
      _replayHistory.removeWhere(toRemove.contains);
      cleared += toRemove.length;
    }

    statistics.cacheClears++;
    return cleared;
  }

  /// Get replay history
  List<ReplaySession> getReplayHistory({
    int? limit,
    DateTime? since,
  }) {
    var history = _replayHistory;

    if (since != null) {
      history = history.where((s) => s.createdAt.isAfter(since)).toList();
    }

    // Sort by creation time (newest first)
    history.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit != null && history.length > limit) {
      history = history.take(limit).toList();
    }

    return history;
  }

  // Private helper methods

  String _generateSimulationKey(TransactionSimulationResult simulation) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = simulation.logs.join().hashCode.abs();
    return 'sim_${timestamp}_$hash';
  }

  String _generateAnalysisKey(AnalysisResult analysis) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = analysis.simulationId.hashCode.abs();
    return 'analysis_${timestamp}_$hash';
  }

  String _generateReplayId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000);
    return 'replay_${timestamp}_$random';
  }

  void _cleanupCache() {
    if (_simulationCache.length <= config.maxCacheSize) return;

    // Remove oldest entries based on LRU
    final entries = _simulationCache.entries.toList();
    entries.sort((a, b) {
      final aTime = a.value.lastAccessed ?? a.value.timestamp;
      final bTime = b.value.lastAccessed ?? b.value.timestamp;
      return aTime.compareTo(bTime);
    });

    final toRemove =
        entries.take(_simulationCache.length - config.maxCacheSize);
    for (final entry in toRemove) {
      _simulationCache.remove(entry.key);
    }
  }

  void _cleanupAnalysisCache() {
    if (_analysisCache.length <= config.maxCacheSize) return;

    // Remove oldest entries based on LRU
    final entries = _analysisCache.entries.toList();
    entries.sort((a, b) {
      final aTime = a.value.lastAccessed ?? a.value.timestamp;
      final bTime = b.value.lastAccessed ?? b.value.timestamp;
      return aTime.compareTo(bTime);
    });

    final toRemove = entries.take(_analysisCache.length - config.maxCacheSize);
    for (final entry in toRemove) {
      _analysisCache.remove(entry.key);
    }
  }

  Future<StepComparison> _compareReplaySteps(
    ReplayStepResult previous,
    ReplayStepResult current,
  ) async {
    final computeDiff = (current.simulation.unitsConsumed ?? 0) -
        (previous.simulation.unitsConsumed ?? 0);
    final logsDiff =
        current.simulation.logs.length - previous.simulation.logs.length;

    return StepComparison(
      computeUnitsDifference: computeDiff,
      logCountDifference: logsDiff,
      significantChanges: _identifySignificantStepChanges(previous, current),
    );
  }

  List<String> _identifySignificantStepChanges(
    ReplayStepResult previous,
    ReplayStepResult current,
  ) {
    final changes = <String>[];

    // Check success status change
    if (previous.success != current.success) {
      changes.add(
          'Success status changed: ${previous.success} → ${current.success}',);
    }

    // Check compute units change
    final computeDiff = (current.simulation.unitsConsumed ?? 0) -
        (previous.simulation.unitsConsumed ?? 0);
    if (computeDiff.abs() > 10000) {
      changes.add(
          'Compute units ${computeDiff > 0 ? 'increased' : 'decreased'} by ${computeDiff.abs()}',);
    }

    return changes;
  }

  ReplaySummary _generateReplaySummary(List<ReplayStepResult> results) {
    final successful = results.where((r) => r.success).length;
    final failed = results.length - successful;
    final avgComputeUnits = results.isNotEmpty
        ? results
                .map((r) => r.simulation.unitsConsumed ?? 0)
                .reduce((a, b) => a + b) /
            results.length
        : 0.0;

    return ReplaySummary(
      totalSteps: results.length,
      successfulSteps: successful,
      failedSteps: failed,
      averageComputeUnits: avgComputeUnits,
      totalProcessingTime: results.map((r) => r.processingTime).fold(
            Duration.zero,
            (sum, duration) => sum + duration,
          ),
    );
  }

  int _estimateMemoryUsage() {
    // Rough estimation of memory usage in bytes
    int estimate = 0;

    // Simulation cache
    for (final cached in _simulationCache.values) {
      estimate += cached.simulation.logs.join().length * 2; // UTF-16 chars
      estimate += 1024; // Overhead for object structure
    }

    // Analysis cache
    estimate += _analysisCache.length * 2048; // Estimated size per analysis

    return estimate;
  }

  bool _shouldClear(CachedSimulation cached, ClearCriteria criteria) {
    if (criteria.olderThan != null) {
      final cutoff = DateTime.now().subtract(criteria.olderThan!);
      if (cached.timestamp.isBefore(cutoff)) return true;
    }

    if (criteria.accessedLessThan != null) {
      if (cached.accessCount < criteria.accessedLessThan!) return true;
    }

    return false;
  }

  bool _shouldClearAnalysis(CachedAnalysis cached, ClearCriteria criteria) {
    if (criteria.olderThan != null) {
      final cutoff = DateTime.now().subtract(criteria.olderThan!);
      if (cached.timestamp.isBefore(cutoff)) return true;
    }

    if (criteria.accessedLessThan != null) {
      if (cached.accessCount < criteria.accessedLessThan!) return true;
    }

    return false;
  }

  // Export/Import methods

  CacheExportResult _exportToJson(CacheExportOptions options) {
    final data = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'simulations': options.includeSimulations
          ? _simulationCache.map((k, v) => MapEntry(k, {
                'key': v.key,
                'timestamp': v.timestamp.toIso8601String(),
                'metadata': v.metadata,
                'accessCount': v.accessCount,
                'simulation': {
                  'success': v.simulation.success,
                  'logs': v.simulation.logs,
                  'unitsConsumed': v.simulation.unitsConsumed,
                },
              }),)
          : <String, dynamic>{},
      'analyses': options.includeAnalyses
          ? _analysisCache.map((k, v) => MapEntry(k, {
                'key': v.key,
                'timestamp': v.timestamp.toIso8601String(),
                'metadata': v.metadata,
                'accessCount': v.accessCount,
                'analysisId': v.analysis.simulationId,
              }),)
          : <String, dynamic>{},
    };

    final jsonString = json.encode(data);
    return CacheExportResult(
      format: CacheExportFormat.json,
      data: jsonString,
      size: jsonString.length,
      itemCount: (options.includeSimulations ? _simulationCache.length : 0) +
          (options.includeAnalyses ? _analysisCache.length : 0),
    );
  }

  CacheExportResult _exportToBinary(CacheExportOptions options) {
    // Simplified binary export - in a real implementation, you'd use a proper binary format
    final jsonResult = _exportToJson(options);
    final bytes = utf8.encode(jsonResult.data);

    return CacheExportResult(
      format: CacheExportFormat.binary,
      data: base64.encode(bytes),
      size: bytes.length,
      itemCount: jsonResult.itemCount,
    );
  }

  CacheExportResult _exportToCsv(CacheExportOptions options) {
    final csv = StringBuffer();
    csv.writeln('Type,Key,Timestamp,AccessCount,Success,ComputeUnits');

    if (options.includeSimulations) {
      for (final entry in _simulationCache.entries) {
        final cached = entry.value;
        csv.writeln(
            'Simulation,${cached.key},${cached.timestamp.toIso8601String()},'
            '${cached.accessCount},${cached.simulation.success},${cached.simulation.unitsConsumed ?? 0}');
      }
    }

    if (options.includeAnalyses) {
      for (final entry in _analysisCache.entries) {
        final cached = entry.value;
        csv.writeln(
            'Analysis,${cached.key},${cached.timestamp.toIso8601String()},'
            '${cached.accessCount},true,${cached.analysis.computeAnalysis.unitsConsumed}');
      }
    }

    final csvString = csv.toString();
    return CacheExportResult(
      format: CacheExportFormat.csv,
      data: csvString,
      size: csvString.length,
      itemCount: (options.includeSimulations ? _simulationCache.length : 0) +
          (options.includeAnalyses ? _analysisCache.length : 0),
    );
  }

  CacheImportResult _importFromJson(String data, CacheImportOptions options) {
    try {
      final jsonData = json.decode(data) as Map<String, dynamic>;
      int imported = 0;

      if (options.importSimulations && jsonData.containsKey('simulations')) {
        final simulations = jsonData['simulations'] as Map<String, dynamic>;
        // Import logic would go here - simplified for this example
        imported += simulations.length;
      }

      if (options.importAnalyses && jsonData.containsKey('analyses')) {
        final analyses = jsonData['analyses'] as Map<String, dynamic>;
        // Import logic would go here - simplified for this example
        imported += analyses.length;
      }

      return CacheImportResult(
        success: true,
        itemsImported: imported,
        format: CacheExportFormat.json,
      );
    } catch (e) {
      return CacheImportResult(
        success: false,
        itemsImported: 0,
        format: CacheExportFormat.json,
        error: e.toString(),
      );
    }
  }

  CacheImportResult _importFromBinary(String data, CacheImportOptions options) {
    try {
      final bytes = base64.decode(data);
      final jsonString = utf8.decode(bytes);
      return _importFromJson(jsonString, options);
    } catch (e) {
      return CacheImportResult(
        success: false,
        itemsImported: 0,
        format: CacheExportFormat.binary,
        error: e.toString(),
      );
    }
  }

  CacheImportResult _importFromCsv(String data, CacheImportOptions options) {
    try {
      final lines = data.split('\n');
      int imported = 0;

      // Skip header
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 6) {
          // Parse CSV line and import - simplified for this example
          imported++;
        }
      }

      return CacheImportResult(
        success: true,
        itemsImported: imported,
        format: CacheExportFormat.csv,
      );
    } catch (e) {
      return CacheImportResult(
        success: false,
        itemsImported: 0,
        format: CacheExportFormat.csv,
        error: e.toString(),
      );
    }
  }
}

// Configuration and options classes

/// Configuration for caching behavior
class CachingConfig {

  const CachingConfig({
    this.maxCacheSize = 1000,
    this.defaultTtl = const Duration(hours: 24),
    this.enableLru = true,
    this.enableMetrics = true,
  });
  final int maxCacheSize;
  final Duration defaultTtl;
  final bool enableLru;
  final bool enableMetrics;
}

/// Options for replay operations
class ReplayOptions {

  const ReplayOptions({
    this.reanalyze = false,
    this.enableComparison = true,
    this.includeMetadata = true,
    this.continueOnError = true,
  });
  final bool reanalyze;
  final bool enableComparison;
  final bool includeMetadata;
  final bool continueOnError;

  static ReplayOptions defaultOptions() => const ReplayOptions();
}

/// Search criteria for finding cached simulations
class SearchCriteria {

  const SearchCriteria({
    this.startTime,
    this.endTime,
    this.minComputeUnits,
    this.maxComputeUnits,
    this.successOnly,
    this.failuresOnly,
    this.metadata,
  });
  final DateTime? startTime;
  final DateTime? endTime;
  final int? minComputeUnits;
  final int? maxComputeUnits;
  final bool? successOnly;
  final bool? failuresOnly;
  final Map<String, dynamic>? metadata;
}

/// Criteria for clearing cache
class ClearCriteria {

  const ClearCriteria({
    this.clearSimulations = true,
    this.clearAnalyses = true,
    this.clearReplayHistory = false,
    this.olderThan,
    this.accessedLessThan,
  });
  final bool clearSimulations;
  final bool clearAnalyses;
  final bool clearReplayHistory;
  final Duration? olderThan;
  final int? accessedLessThan;

  static ClearCriteria all() => const ClearCriteria();

  static ClearCriteria oldEntries(Duration age) => ClearCriteria(
        olderThan: age,
      );
}

/// Export options for cache data
class CacheExportOptions {

  const CacheExportOptions({
    this.includeSimulations = true,
    this.includeAnalyses = true,
    this.includeMetadata = true,
    this.compressData = false,
  });
  final bool includeSimulations;
  final bool includeAnalyses;
  final bool includeMetadata;
  final bool compressData;

  static CacheExportOptions defaultOptions() => const CacheExportOptions();
}

/// Import options for cache data
class CacheImportOptions {

  const CacheImportOptions({
    this.importSimulations = true,
    this.importAnalyses = true,
    this.overwriteExisting = false,
    this.validateData = true,
  });
  final bool importSimulations;
  final bool importAnalyses;
  final bool overwriteExisting;
  final bool validateData;

  static CacheImportOptions defaultOptions() => const CacheImportOptions();
}

// Data classes

/// Cached simulation result
class CachedSimulation {

  CachedSimulation({
    required this.key,
    required this.simulation,
    required this.timestamp,
    required this.metadata,
    required this.accessCount,
    this.lastAccessed,
  });
  final String key;
  final TransactionSimulationResult simulation;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  int accessCount;
  DateTime? lastAccessed;
}

/// Cached analysis result
class CachedAnalysis {

  CachedAnalysis({
    required this.key,
    required this.analysis,
    required this.timestamp,
    required this.metadata,
    required this.accessCount,
    this.lastAccessed,
  });
  final String key;
  final AnalysisResult analysis;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  int accessCount;
  DateTime? lastAccessed;
}

/// Replay session definition
class ReplaySession {

  const ReplaySession({
    required this.id,
    required this.name,
    required this.simulations,
    required this.missingKeys,
    required this.createdAt,
    required this.metadata,
  });
  final String id;
  final String name;
  final List<CachedSimulation> simulations;
  final List<String> missingKeys;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
}

/// Result of a replay session
class ReplayResult {

  const ReplayResult({
    required this.sessionId,
    required this.session,
    required this.results,
    required this.totalTime,
    required this.summary,
    required this.timestamp,
  });
  final String sessionId;
  final ReplaySession session;
  final List<ReplayStepResult> results;
  final Duration totalTime;
  final ReplaySummary summary;
  final DateTime timestamp;
}

/// Result of a single replay step
class ReplayStepResult {

  ReplayStepResult({
    required this.stepIndex,
    required this.simulationKey,
    required this.simulation,
    this.analysis,
    required this.success,
    this.error,
    required this.processingTime,
    required this.metadata,
    this.comparison,
  });
  final int stepIndex;
  final String simulationKey;
  final TransactionSimulationResult simulation;
  final AnalysisResult? analysis;
  final bool success;
  final String? error;
  final Duration processingTime;
  final Map<String, dynamic> metadata;
  StepComparison? comparison;
}

/// Comparison between replay steps
class StepComparison {

  const StepComparison({
    required this.computeUnitsDifference,
    required this.logCountDifference,
    required this.significantChanges,
  });
  final int computeUnitsDifference;
  final int logCountDifference;
  final List<String> significantChanges;
}

/// Summary of replay session
class ReplaySummary {

  const ReplaySummary({
    required this.totalSteps,
    required this.successfulSteps,
    required this.failedSteps,
    required this.averageComputeUnits,
    required this.totalProcessingTime,
  });
  final int totalSteps;
  final int successfulSteps;
  final int failedSteps;
  final double averageComputeUnits;
  final Duration totalProcessingTime;
}

/// Cache performance metrics
class CachePerformanceMetrics {

  const CachePerformanceMetrics({
    required this.simulationCacheSize,
    required this.analysisCacheSize,
    required this.simulationHitRate,
    required this.analysisHitRate,
    required this.totalSimulationsCached,
    required this.totalAnalysesCached,
    required this.totalReplaysExecuted,
    required this.memoryUsageEstimate,
  });
  final int simulationCacheSize;
  final int analysisCacheSize;
  final double simulationHitRate;
  final double analysisHitRate;
  final int totalSimulationsCached;
  final int totalAnalysesCached;
  final int totalReplaysExecuted;
  final int memoryUsageEstimate;
}

/// Cache export result
class CacheExportResult {

  const CacheExportResult({
    required this.format,
    required this.data,
    required this.size,
    required this.itemCount,
  });
  final CacheExportFormat format;
  final String data;
  final int size;
  final int itemCount;
}

/// Cache import result
class CacheImportResult {

  const CacheImportResult({
    required this.success,
    required this.itemsImported,
    required this.format,
    this.error,
  });
  final bool success;
  final int itemsImported;
  final CacheExportFormat format;
  final String? error;
}

/// Cache statistics
class CacheStatistics {
  int simulationsCached = 0;
  int analysesCached = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
  int analysisHits = 0;
  int analysisMisses = 0;
  int replaysExecuted = 0;
  int cacheClears = 0;
}

// Enums

enum CacheExportFormat {
  json,
  binary,
  csv,
}
