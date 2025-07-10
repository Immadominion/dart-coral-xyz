import 'dart:convert';
import 'dart:typed_data';

import '../types/public_key.dart';
import 'transaction_simulator.dart';

/// Comprehensive simulation result processing and analysis
class SimulationResultProcessor {
  /// Cache for processed results
  final Map<String, ProcessedSimulationResult> _resultCache = {};

  /// Configuration for result processing
  final SimulationProcessingConfig config;

  /// Statistics for processing operations
  final ProcessingStatistics statistics = ProcessingStatistics();

  SimulationResultProcessor({
    this.config = const SimulationProcessingConfig(),
  });

  /// Process a simulation result with comprehensive analysis
  Future<ProcessedSimulationResult> processResult(
    TransactionSimulationResult simulationResult, {
    String? cacheKey,
    ProcessingOptions? options,
  }) async {
    options ??= ProcessingOptions.defaultOptions();

    // Check cache if key provided
    if (cacheKey != null && _resultCache.containsKey(cacheKey)) {
      statistics.cacheHits++;
      return _resultCache[cacheKey]!;
    }

    statistics.processedResults++;
    final startTime = DateTime.now();

    try {
      // Extract events from logs
      final events = await _extractEvents(simulationResult.logs, options);

      // Analyze account state changes
      final accountChanges = await _analyzeAccountChanges(
        simulationResult.accounts,
        options,
      );

      // Process return data and CPI results
      final returnDataAnalysis = _processReturnData(
        simulationResult.returnData,
        options,
      );

      // Extract debugging information
      final debugInfo = _extractDebugInfo(simulationResult, options);

      // Analyze errors and warnings
      final errorAnalysis = _analyzeErrors(simulationResult, options);

      // Create comprehensive result
      final result = ProcessedSimulationResult(
        originalResult: simulationResult,
        events: events,
        accountChanges: accountChanges,
        returnDataAnalysis: returnDataAnalysis,
        debugInfo: debugInfo,
        errorAnalysis: errorAnalysis,
        processingTime: DateTime.now().difference(startTime),
        processedAt: DateTime.now(),
      );

      // Cache result if key provided
      if (cacheKey != null) {
        _cacheResult(cacheKey, result);
      }

      statistics.successfulProcesses++;
      return result;
    } catch (e) {
      statistics.failedProcesses++;
      rethrow;
    }
  }

  /// Extract events from simulation logs
  Future<List<ExtractedEvent>> _extractEvents(
    List<String> logs,
    ProcessingOptions options,
  ) async {
    final events = <ExtractedEvent>[];

    if (!options.extractEvents) return events;

    final programLogPrefix = 'Program log: ';
    final programDataPrefix = 'Program data: ';

    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];

      // Handle program logs
      if (log.startsWith(programLogPrefix)) {
        final eventData = log.substring(programLogPrefix.length);
        final event = _parseEventFromLog(eventData, i, EventSource.programLog);
        if (event != null) events.add(event);
      }

      // Handle program data logs
      else if (log.startsWith(programDataPrefix)) {
        final eventData = log.substring(programDataPrefix.length);
        final event = _parseEventFromLog(eventData, i, EventSource.programData);
        if (event != null) events.add(event);
      }

      // Handle invoke logs for CPI tracking (anything that starts with "Program" but isn't log/data)
      else if (log.startsWith('Program ') &&
          !log.startsWith(programLogPrefix) &&
          !log.startsWith(programDataPrefix)) {
        final cpiEvent = _parseCpiEvent(log, i);
        if (cpiEvent != null) events.add(cpiEvent);
      }
    }

    return events;
  }

  /// Parse event from log data
  ExtractedEvent? _parseEventFromLog(
    String eventData,
    int logIndex,
    EventSource source,
  ) {
    try {
      // Try to decode as base64 first (common for structured data)
      try {
        final decodedBytes = base64.decode(eventData);
        return ExtractedEvent(
          source: source,
          logIndex: logIndex,
          rawData: eventData,
          decodedData: decodedBytes,
          eventType: EventType.structured,
          timestamp: DateTime.now(),
        );
      } catch (_) {
        // If base64 decode fails, treat as text event
        return ExtractedEvent(
          source: source,
          logIndex: logIndex,
          rawData: eventData,
          textData: eventData,
          eventType: EventType.text,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      // Return error event for debugging
      return ExtractedEvent(
        source: source,
        logIndex: logIndex,
        rawData: eventData,
        eventType: EventType.error,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Parse CPI (Cross-Program Invocation) events
  ExtractedEvent? _parseCpiEvent(String log, int logIndex) {
    final invokePattern =
        RegExp(r'Program ([1-9A-HJ-NP-Za-km-z]+) invoke \[(\d+)\]');
    final successPattern = RegExp(r'Program ([1-9A-HJ-NP-Za-km-z]+) success');
    final failedPattern = RegExp(r'Program ([1-9A-HJ-NP-Za-km-z]+) failed');

    if (invokePattern.hasMatch(log)) {
      final match = invokePattern.firstMatch(log)!;
      return ExtractedEvent(
        source: EventSource.systemLog,
        logIndex: logIndex,
        rawData: log,
        eventType: EventType.cpiInvoke,
        cpiInfo: CpiInfo(
          programId: match.group(1)!,
          depth: int.parse(match.group(2)!),
          status: CpiStatus.invoked,
        ),
        timestamp: DateTime.now(),
      );
    } else if (successPattern.hasMatch(log)) {
      final match = successPattern.firstMatch(log)!;
      return ExtractedEvent(
        source: EventSource.systemLog,
        logIndex: logIndex,
        rawData: log,
        eventType: EventType.cpiResult,
        cpiInfo: CpiInfo(
          programId: match.group(1)!,
          status: CpiStatus.success,
        ),
        timestamp: DateTime.now(),
      );
    } else if (failedPattern.hasMatch(log)) {
      final match = failedPattern.firstMatch(log)!;
      return ExtractedEvent(
        source: EventSource.systemLog,
        logIndex: logIndex,
        rawData: log,
        eventType: EventType.cpiResult,
        cpiInfo: CpiInfo(
          programId: match.group(1)!,
          status: CpiStatus.failed,
        ),
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Analyze account state changes from simulation
  Future<AccountStateAnalysis> _analyzeAccountChanges(
    Map<String, dynamic>? accounts,
    ProcessingOptions options,
  ) async {
    if (!options.analyzeAccountChanges || accounts == null) {
      return const AccountStateAnalysis(
        hasChanges: false,
        changedAccounts: [],
        totalAccounts: 0,
      );
    }

    final changedAccounts = <AccountChange>[];

    for (final entry in accounts.entries) {
      final accountKey = entry.key;
      final accountData = entry.value as Map<String, dynamic>;

      final change = AccountChange(
        publicKey: PublicKey.fromBase58(accountKey),
        lamports: accountData['lamports'] as int?,
        owner: accountData['owner'] != null
            ? PublicKey.fromBase58(accountData['owner'] as String)
            : null,
        executable: accountData['executable'] as bool? ?? false,
        rentEpoch: accountData['rentEpoch'] as int?,
        dataLength: accountData['data'] != null
            ? (accountData['data'] as List).length
            : 0,
        changeType: AccountChangeType.modified,
      );

      changedAccounts.add(change);
    }

    return AccountStateAnalysis(
      hasChanges: changedAccounts.isNotEmpty,
      changedAccounts: changedAccounts,
      totalAccounts: changedAccounts.length,
      analysis: _generateAccountAnalysis(changedAccounts),
    );
  }

  /// Generate detailed account analysis
  String _generateAccountAnalysis(List<AccountChange> changes) {
    if (changes.isEmpty) return 'No account changes detected';

    final lamportChanges = changes.where((c) => c.lamports != null).length;
    final dataChanges = changes.where((c) => c.dataLength > 0).length;
    final newAccounts =
        changes.where((c) => c.changeType == AccountChangeType.created).length;

    return 'Account Changes Summary:\n'
        '- Total affected accounts: ${changes.length}\n'
        '- Lamport changes: $lamportChanges\n'
        '- Data changes: $dataChanges\n'
        '- New accounts: $newAccounts';
  }

  /// Process return data and CPI results
  ReturnDataAnalysis _processReturnData(
    TransactionReturnData? returnData,
    ProcessingOptions options,
  ) {
    if (!options.processReturnData || returnData == null) {
      return const ReturnDataAnalysis(hasReturnData: false);
    }

    try {
      // Decode return data if it's base64 encoded
      Uint8List? decodedData;
      if (returnData.data.isNotEmpty) {
        try {
          decodedData = base64.decode(returnData.data);
        } catch (_) {
          // Data might not be base64, keep as string
        }
      }

      return ReturnDataAnalysis(
        hasReturnData: true,
        programId: returnData.programId,
        rawData: returnData.data,
        decodedData: decodedData,
        dataLength: returnData.data.length,
        analysis: _analyzeReturnData(returnData.data, decodedData),
      );
    } catch (e) {
      return ReturnDataAnalysis(
        hasReturnData: true,
        programId: returnData.programId,
        rawData: returnData.data,
        errorMessage: e.toString(),
      );
    }
  }

  /// Analyze return data content
  String _analyzeReturnData(String rawData, Uint8List? decodedData) {
    final analysis = StringBuffer();
    analysis.writeln('Return Data Analysis:');
    analysis.writeln('- Raw data length: ${rawData.length}');

    if (decodedData != null) {
      analysis.writeln('- Decoded data length: ${decodedData.length} bytes');
      analysis.writeln('- Data type: Binary/Base64');

      // Basic pattern analysis
      if (decodedData.length >= 8) {
        analysis.writeln('- First 8 bytes: ${decodedData.take(8).join(', ')}');
      }
    } else {
      analysis.writeln('- Data type: String/Text');
      if (rawData.length <= 100) {
        analysis.writeln('- Content preview: $rawData');
      } else {
        analysis.writeln('- Content preview: ${rawData.substring(0, 100)}...');
      }
    }

    return analysis.toString();
  }

  /// Extract comprehensive debugging information
  DebugInfo _extractDebugInfo(
    TransactionSimulationResult result,
    ProcessingOptions options,
  ) {
    if (!options.extractDebugInfo) {
      return const DebugInfo(hasDebugInfo: false);
    }

    final debugLogs = <String>[];
    final warnings = <String>[];
    final performanceMetrics = <String, dynamic>{};

    // Extract debug and warning logs
    for (final log in result.logs) {
      if (log.toLowerCase().contains('debug') ||
          log.toLowerCase().contains('trace')) {
        debugLogs.add(log);
      } else if (log.toLowerCase().contains('warning') ||
          log.toLowerCase().contains('warn')) {
        warnings.add(log);
      }
    }

    // Extract performance metrics
    if (result.unitsConsumed != null) {
      performanceMetrics['computeUnitsConsumed'] = result.unitsConsumed;
      performanceMetrics['computeEfficiency'] =
          result.unitsConsumed! < 200000 ? 'Good' : 'Needs Optimization';
    }

    performanceMetrics['totalLogs'] = result.logs.length;
    performanceMetrics['errorPresent'] = result.error != null;

    return DebugInfo(
      hasDebugInfo: true,
      debugLogs: debugLogs,
      warnings: warnings,
      performanceMetrics: performanceMetrics,
      recommendations: _generateDebugRecommendations(result),
    );
  }

  /// Generate debugging recommendations
  List<String> _generateDebugRecommendations(
      TransactionSimulationResult result) {
    final recommendations = <String>[];

    if (result.unitsConsumed != null && result.unitsConsumed! > 800000) {
      recommendations.add(
          'Consider optimizing compute unit usage (${result.unitsConsumed} units used)');
    }

    if (result.logs.length > 50) {
      recommendations.add(
          'High number of logs detected (${result.logs.length}), consider reducing verbosity in production');
    }

    if (result.error != null) {
      recommendations.add(
          'Transaction failed: ${result.error!.type} - Review error details for optimization');
    }

    if (recommendations.isEmpty) {
      recommendations.add(
          'Transaction simulation completed successfully with no optimization suggestions');
    }

    return recommendations;
  }

  /// Analyze errors and provide detailed context
  ErrorAnalysis _analyzeErrors(
    TransactionSimulationResult result,
    ProcessingOptions options,
  ) {
    if (!options.analyzeErrors) {
      return const ErrorAnalysis(hasErrors: false);
    }

    if (result.error == null) {
      return const ErrorAnalysis(
        hasErrors: false,
        errorSummary: 'No errors detected in simulation',
      );
    }

    final error = result.error!;
    final errorContext = _buildErrorContext(error, result.logs);
    final suggestions = _generateErrorSuggestions(error);

    return ErrorAnalysis(
      hasErrors: true,
      errorType: error.type,
      errorCode: error.customErrorCode,
      instructionIndex: error.instructionIndex,
      errorSummary: _buildErrorSummary(error),
      errorContext: errorContext,
      suggestions: suggestions,
      relatedLogs: _extractRelatedLogs(error, result.logs),
    );
  }

  /// Build error context from logs and error information
  String _buildErrorContext(
      TransactionSimulationError error, List<String> logs) {
    final context = StringBuffer();
    context.writeln('Error Context:');
    context.writeln('- Error Type: ${error.type}');

    if (error.instructionIndex != null) {
      context.writeln('- Failed at instruction: ${error.instructionIndex}');
    }

    if (error.customErrorCode != null) {
      context.writeln('- Custom error code: ${error.customErrorCode}');
    }

    // Find relevant logs around the error
    if (error.instructionIndex != null) {
      final relevantLogs = logs
          .where((log) =>
              log.contains('instruction') ||
              log.contains('error') ||
              log.contains('failed'))
          .take(5);

      if (relevantLogs.isNotEmpty) {
        context.writeln('- Relevant logs:');
        for (final log in relevantLogs) {
          context.writeln('  $log');
        }
      }
    }

    return context.toString();
  }

  /// Generate error-specific suggestions
  List<String> _generateErrorSuggestions(TransactionSimulationError error) {
    final suggestions = <String>[];

    switch (error.type) {
      case 'InsufficientFundsForRent':
        suggestions
            .add('Ensure account has sufficient lamports for rent exemption');
        suggestions.add(
            'Consider increasing transaction funding or reducing account size');
        break;
      case 'InstructionError':
        suggestions
            .add('Review instruction parameters and account permissions');
        if (error.customErrorCode != null) {
          suggestions.add(
              'Check program documentation for custom error code ${error.customErrorCode}');
        }
        break;
      case 'InvalidAccountData':
        suggestions
            .add('Verify account data format matches program expectations');
        suggestions.add('Check account initialization and data serialization');
        break;
      case 'ProgramFailedToComplete':
        suggestions.add('Program exceeded compute budget or encountered panic');
        suggestions.add(
            'Consider optimizing program logic or increasing compute budget');
        break;
      default:
        suggestions.add('Review transaction structure and account states');
        suggestions.add('Check program logs for additional error context');
    }

    return suggestions;
  }

  /// Build comprehensive error summary
  String _buildErrorSummary(TransactionSimulationError error) {
    final summary = StringBuffer();
    summary.write('Transaction failed with ${error.type}');

    if (error.instructionIndex != null) {
      summary.write(' at instruction ${error.instructionIndex}');
    }

    if (error.customErrorCode != null) {
      summary.write(' (custom error: ${error.customErrorCode})');
    }

    return summary.toString();
  }

  /// Extract logs related to the error
  List<String> _extractRelatedLogs(
      TransactionSimulationError error, List<String> logs) {
    return logs
        .where((log) =>
            log.toLowerCase().contains('error') ||
            log.toLowerCase().contains('failed') ||
            log.toLowerCase().contains('panic') ||
            (error.instructionIndex != null && log.contains('instruction')))
        .toList();
  }

  /// Cache processed result
  void _cacheResult(String key, ProcessedSimulationResult result) {
    if (_resultCache.length >= config.maxCacheSize) {
      // Remove oldest entry (simple FIFO strategy)
      final oldestKey = _resultCache.keys.first;
      _resultCache.remove(oldestKey);
    }

    _resultCache[key] = result;
  }

  /// Compare two simulation results
  ComparisonResult compareResults(
    ProcessedSimulationResult result1,
    ProcessedSimulationResult result2,
  ) {
    final differences = <String>[];
    final similarities = <String>[];

    // Compare success status
    if (result1.originalResult.success != result2.originalResult.success) {
      differences.add(
          'Success status differs: ${result1.originalResult.success} vs ${result2.originalResult.success}');
    } else {
      similarities.add('Both results have same success status');
    }

    // Compare compute units
    final units1 = result1.originalResult.unitsConsumed;
    final units2 = result2.originalResult.unitsConsumed;
    if (units1 != null && units2 != null) {
      final diff = (units1 - units2).abs();
      if (diff > 1000) {
        differences.add(
            'Compute units differ significantly: $units1 vs $units2 (diff: $diff)');
      } else {
        similarities.add('Compute units are similar: $units1 vs $units2');
      }
    }

    // Compare events
    if (result1.events.length != result2.events.length) {
      differences.add(
          'Event count differs: ${result1.events.length} vs ${result2.events.length}');
    } else {
      similarities.add('Same number of events: ${result1.events.length}');
    }

    // Compare account changes
    if (result1.accountChanges.changedAccounts.length !=
        result2.accountChanges.changedAccounts.length) {
      differences.add(
          'Account changes differ: ${result1.accountChanges.changedAccounts.length} vs ${result2.accountChanges.changedAccounts.length}');
    } else {
      similarities.add(
          'Same number of account changes: ${result1.accountChanges.changedAccounts.length}');
    }

    return ComparisonResult(
      differences: differences,
      similarities: similarities,
      overallSimilarity: differences.isEmpty
          ? 1.0
          : similarities.length / (similarities.length + differences.length),
    );
  }

  /// Clear cache
  void clearCache() {
    _resultCache.clear();
    statistics.cacheClears++;
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _resultCache.length,
      'maxCacheSize': config.maxCacheSize,
      'cacheHitRate': statistics.cacheHits /
          (statistics.cacheHits + statistics.processedResults),
      'statistics': statistics.toMap(),
    };
  }
}

/// Configuration for simulation result processing
class SimulationProcessingConfig {
  /// Maximum number of results to cache
  final int maxCacheSize;

  /// Enable detailed logging
  final bool enableDetailedLogging;

  /// Timeout for processing operations
  final Duration processingTimeout;

  const SimulationProcessingConfig({
    this.maxCacheSize = 100,
    this.enableDetailedLogging = false,
    this.processingTimeout = const Duration(seconds: 30),
  });
}

/// Options for processing simulation results
class ProcessingOptions {
  /// Whether to extract events from logs
  final bool extractEvents;

  /// Whether to analyze account state changes
  final bool analyzeAccountChanges;

  /// Whether to process return data
  final bool processReturnData;

  /// Whether to extract debugging information
  final bool extractDebugInfo;

  /// Whether to analyze errors
  final bool analyzeErrors;

  const ProcessingOptions({
    this.extractEvents = true,
    this.analyzeAccountChanges = true,
    this.processReturnData = true,
    this.extractDebugInfo = true,
    this.analyzeErrors = true,
  });

  /// Create default processing options
  factory ProcessingOptions.defaultOptions() {
    return const ProcessingOptions();
  }

  /// Create minimal processing options
  factory ProcessingOptions.minimal() {
    return const ProcessingOptions(
      extractEvents: false,
      analyzeAccountChanges: false,
      processReturnData: false,
      extractDebugInfo: false,
      analyzeErrors: true, // Always analyze errors
    );
  }
}

/// Comprehensive processed simulation result
class ProcessedSimulationResult {
  /// Original simulation result
  final TransactionSimulationResult originalResult;

  /// Extracted events from logs
  final List<ExtractedEvent> events;

  /// Account state change analysis
  final AccountStateAnalysis accountChanges;

  /// Return data analysis
  final ReturnDataAnalysis returnDataAnalysis;

  /// Debugging information
  final DebugInfo debugInfo;

  /// Error analysis
  final ErrorAnalysis errorAnalysis;

  /// Time taken to process the result
  final Duration processingTime;

  /// When the result was processed
  final DateTime processedAt;

  const ProcessedSimulationResult({
    required this.originalResult,
    required this.events,
    required this.accountChanges,
    required this.returnDataAnalysis,
    required this.debugInfo,
    required this.errorAnalysis,
    required this.processingTime,
    required this.processedAt,
  });

  /// Check if the simulation was successful
  bool get isSuccess => originalResult.success;

  /// Get total number of events extracted
  int get eventCount => events.length;

  /// Get events by type
  List<ExtractedEvent> getEventsByType(EventType type) {
    return events.where((e) => e.eventType == type).toList();
  }

  /// Get CPI events
  List<ExtractedEvent> getCpiEvents() {
    return events
        .where((e) =>
            e.eventType == EventType.cpiInvoke ||
            e.eventType == EventType.cpiResult)
        .toList();
  }

  /// Generate comprehensive summary
  String generateSummary() {
    final summary = StringBuffer();
    summary.writeln('Simulation Result Summary:');
    summary.writeln('- Status: ${isSuccess ? 'Success' : 'Failed'}');
    summary.writeln('- Events extracted: $eventCount');
    summary
        .writeln('- Account changes: ${accountChanges.changedAccounts.length}');
    summary.writeln('- Processing time: ${processingTime.inMilliseconds}ms');

    if (originalResult.unitsConsumed != null) {
      summary.writeln('- Compute units: ${originalResult.unitsConsumed}');
    }

    if (returnDataAnalysis.hasReturnData) {
      summary.writeln('- Return data: ${returnDataAnalysis.dataLength} bytes');
    }

    if (errorAnalysis.hasErrors) {
      summary.writeln('- Error: ${errorAnalysis.errorSummary}');
    }

    return summary.toString();
  }
}

/// Event extracted from simulation logs
class ExtractedEvent {
  /// Source of the event (program log, program data, system log)
  final EventSource source;

  /// Index in the log array
  final int logIndex;

  /// Raw log data
  final String rawData;

  /// Decoded binary data (if applicable)
  final Uint8List? decodedData;

  /// Text data (if applicable)
  final String? textData;

  /// Type of event
  final EventType eventType;

  /// CPI information (if applicable)
  final CpiInfo? cpiInfo;

  /// Error message (if event parsing failed)
  final String? errorMessage;

  /// When the event was extracted
  final DateTime timestamp;

  const ExtractedEvent({
    required this.source,
    required this.logIndex,
    required this.rawData,
    this.decodedData,
    this.textData,
    required this.eventType,
    this.cpiInfo,
    this.errorMessage,
    required this.timestamp,
  });

  /// Check if event has binary data
  bool get hasBinaryData => decodedData != null;

  /// Check if event has text data
  bool get hasTextData => textData != null;

  /// Check if event is a CPI event
  bool get isCpiEvent => cpiInfo != null;

  /// Get event size in bytes
  int get sizeInBytes {
    if (decodedData != null) return decodedData!.length;
    if (textData != null) return textData!.length;
    return rawData.length;
  }

  @override
  String toString() {
    return 'ExtractedEvent(type: $eventType, source: $source, index: $logIndex)';
  }
}

/// Source of an event
enum EventSource {
  programLog,
  programData,
  systemLog,
}

/// Type of extracted event
enum EventType {
  structured,
  text,
  cpiInvoke,
  cpiResult,
  error,
}

/// Cross-Program Invocation information
class CpiInfo {
  /// Program ID being invoked
  final String programId;

  /// Invocation depth
  final int? depth;

  /// CPI status
  final CpiStatus status;

  const CpiInfo({
    required this.programId,
    this.depth,
    required this.status,
  });
}

/// CPI status
enum CpiStatus {
  invoked,
  success,
  failed,
}

/// Account state change analysis
class AccountStateAnalysis {
  /// Whether any account changes were detected
  final bool hasChanges;

  /// List of changed accounts
  final List<AccountChange> changedAccounts;

  /// Total number of accounts analyzed
  final int totalAccounts;

  /// Detailed analysis text
  final String? analysis;

  const AccountStateAnalysis({
    required this.hasChanges,
    required this.changedAccounts,
    required this.totalAccounts,
    this.analysis,
  });
}

/// Individual account change
class AccountChange {
  /// Account public key
  final PublicKey publicKey;

  /// Lamports balance
  final int? lamports;

  /// Account owner
  final PublicKey? owner;

  /// Whether account is executable
  final bool executable;

  /// Rent epoch
  final int? rentEpoch;

  /// Data length in bytes
  final int dataLength;

  /// Type of change
  final AccountChangeType changeType;

  const AccountChange({
    required this.publicKey,
    this.lamports,
    this.owner,
    required this.executable,
    this.rentEpoch,
    required this.dataLength,
    required this.changeType,
  });
}

/// Type of account change
enum AccountChangeType {
  created,
  modified,
  deleted,
}

/// Return data analysis
class ReturnDataAnalysis {
  /// Whether return data is present
  final bool hasReturnData;

  /// Program ID that returned the data
  final String? programId;

  /// Raw return data
  final String? rawData;

  /// Decoded binary data
  final Uint8List? decodedData;

  /// Data length
  final int? dataLength;

  /// Analysis text
  final String? analysis;

  /// Error message if processing failed
  final String? errorMessage;

  const ReturnDataAnalysis({
    required this.hasReturnData,
    this.programId,
    this.rawData,
    this.decodedData,
    this.dataLength,
    this.analysis,
    this.errorMessage,
  });
}

/// Debugging information extracted from simulation
class DebugInfo {
  /// Whether debug information is available
  final bool hasDebugInfo;

  /// Debug-specific logs
  final List<String>? debugLogs;

  /// Warning logs
  final List<String>? warnings;

  /// Performance metrics
  final Map<String, dynamic>? performanceMetrics;

  /// Optimization recommendations
  final List<String>? recommendations;

  const DebugInfo({
    required this.hasDebugInfo,
    this.debugLogs,
    this.warnings,
    this.performanceMetrics,
    this.recommendations,
  });
}

/// Error analysis from simulation
class ErrorAnalysis {
  /// Whether errors were found
  final bool hasErrors;

  /// Type of error
  final String? errorType;

  /// Custom error code
  final int? errorCode;

  /// Instruction index where error occurred
  final int? instructionIndex;

  /// Error summary
  final String? errorSummary;

  /// Detailed error context
  final String? errorContext;

  /// Suggestions for fixing the error
  final List<String>? suggestions;

  /// Logs related to the error
  final List<String>? relatedLogs;

  const ErrorAnalysis({
    required this.hasErrors,
    this.errorType,
    this.errorCode,
    this.instructionIndex,
    this.errorSummary,
    this.errorContext,
    this.suggestions,
    this.relatedLogs,
  });
}

/// Result of comparing two simulation results
class ComparisonResult {
  /// Differences found between results
  final List<String> differences;

  /// Similarities between results
  final List<String> similarities;

  /// Overall similarity score (0.0 to 1.0)
  final double overallSimilarity;

  const ComparisonResult({
    required this.differences,
    required this.similarities,
    required this.overallSimilarity,
  });

  /// Check if results are identical
  bool get areIdentical => differences.isEmpty;

  /// Check if results are similar (> 80% similarity)
  bool get areSimilar => overallSimilarity > 0.8;
}

/// Statistics for processing operations
class ProcessingStatistics {
  /// Number of results processed
  int processedResults = 0;

  /// Number of successful processes
  int successfulProcesses = 0;

  /// Number of failed processes
  int failedProcesses = 0;

  /// Number of cache hits
  int cacheHits = 0;

  /// Number of cache clears
  int cacheClears = 0;

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'processedResults': processedResults,
      'successfulProcesses': successfulProcesses,
      'failedProcesses': failedProcesses,
      'cacheHits': cacheHits,
      'cacheClears': cacheClears,
      'successRate':
          successfulProcesses / (processedResults > 0 ? processedResults : 1),
    };
  }
}
