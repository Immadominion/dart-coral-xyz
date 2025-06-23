/// Debug utilities for Anchor program development
///
/// This module provides comprehensive debugging tools including
/// transaction inspection, account analysis, and development utilities.

import 'dart:convert';
import '../idl/idl.dart';
import '../program/program_class.dart';

/// Configuration for debug utilities
class DebugConfig {
  /// Whether to enable verbose logging
  final bool verbose;

  /// Whether to capture transaction logs
  final bool captureTransactionLogs;

  /// Whether to analyze account changes
  final bool analyzeAccountChanges;

  /// Whether to track performance metrics
  final bool trackPerformance;

  /// Maximum number of logs to capture
  final int maxLogEntries;

  const DebugConfig({
    this.verbose = true,
    this.captureTransactionLogs = true,
    this.analyzeAccountChanges = true,
    this.trackPerformance = true,
    this.maxLogEntries = 1000,
  });

  /// Create development-friendly configuration
  factory DebugConfig.development() {
    return const DebugConfig(
      verbose: true,
      captureTransactionLogs: true,
      analyzeAccountChanges: true,
      trackPerformance: true,
      maxLogEntries: 1000,
    );
  }

  /// Create production-safe configuration
  factory DebugConfig.production() {
    return const DebugConfig(
      verbose: false,
      captureTransactionLogs: false,
      analyzeAccountChanges: false,
      trackPerformance: false,
      maxLogEntries: 100,
    );
  }
}

/// Debug log entry
class DebugLogEntry {
  /// Timestamp of the log entry
  final DateTime timestamp;

  /// Log level (info, warning, error, debug)
  final String level;

  /// Log message
  final String message;

  /// Additional context data
  final Map<String, dynamic>? context;

  /// Source location (file, line, function)
  final String? source;

  const DebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
    this.source,
  });

  /// Create info log entry
  factory DebugLogEntry.info(String message,
      {Map<String, dynamic>? context, String? source}) {
    return DebugLogEntry(
      timestamp: DateTime.now(),
      level: 'info',
      message: message,
      context: context,
      source: source,
    );
  }

  /// Create warning log entry
  factory DebugLogEntry.warning(String message,
      {Map<String, dynamic>? context, String? source}) {
    return DebugLogEntry(
      timestamp: DateTime.now(),
      level: 'warning',
      message: message,
      context: context,
      source: source,
    );
  }

  /// Create error log entry
  factory DebugLogEntry.error(String message,
      {Map<String, dynamic>? context, String? source}) {
    return DebugLogEntry(
      timestamp: DateTime.now(),
      level: 'error',
      message: message,
      context: context,
      source: source,
    );
  }

  /// Create debug log entry
  factory DebugLogEntry.debug(String message,
      {Map<String, dynamic>? context, String? source}) {
    return DebugLogEntry(
      timestamp: DateTime.now(),
      level: 'debug',
      message: message,
      context: context,
      source: source,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'message': message,
      'context': context,
      'source': source,
    };
  }

  /// Create from JSON
  factory DebugLogEntry.fromJson(Map<String, dynamic> json) {
    return DebugLogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: json['level'],
      message: json['message'],
      context: json['context'],
      source: json['source'],
    );
  }

  @override
  String toString() {
    final sourceStr = source != null ? ' [$source]' : '';
    final contextStr = context != null ? ' ${jsonEncode(context)}' : '';
    return '${timestamp.toIso8601String()} [${level.toUpperCase()}]$sourceStr $message$contextStr';
  }
}

/// Transaction debug information
class TransactionDebugInfo {
  /// Transaction signature
  final String signature;

  /// Transaction status
  final String status;

  /// Compute units consumed
  final int? computeUnitsConsumed;

  /// Transaction logs
  final List<String> logs;

  /// Account changes detected
  final List<AccountChange> accountChanges;

  /// Error information (if any)
  final String? error;

  /// Performance metrics
  final Map<String, dynamic> metrics;

  const TransactionDebugInfo({
    required this.signature,
    required this.status,
    this.computeUnitsConsumed,
    required this.logs,
    required this.accountChanges,
    this.error,
    required this.metrics,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'signature': signature,
      'status': status,
      'computeUnitsConsumed': computeUnitsConsumed,
      'logs': logs,
      'accountChanges':
          accountChanges.map((change) => change.toJson()).toList(),
      'error': error,
      'metrics': metrics,
    };
  }
}

/// Account change information
class AccountChange {
  /// Account address
  final String address;

  /// Account owner
  final String owner;

  /// Data before change
  final String? dataBefore;

  /// Data after change
  final String? dataAfter;

  /// Lamports before change
  final int? lamportsBefore;

  /// Lamports after change
  final int? lamportsAfter;

  /// Type of change
  final String changeType;

  const AccountChange({
    required this.address,
    required this.owner,
    this.dataBefore,
    this.dataAfter,
    this.lamportsBefore,
    this.lamportsAfter,
    required this.changeType,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'owner': owner,
      'dataBefore': dataBefore,
      'dataAfter': dataAfter,
      'lamportsBefore': lamportsBefore,
      'lamportsAfter': lamportsAfter,
      'changeType': changeType,
    };
  }

  /// Create from JSON
  factory AccountChange.fromJson(Map<String, dynamic> json) {
    return AccountChange(
      address: json['address'],
      owner: json['owner'],
      dataBefore: json['dataBefore'],
      dataAfter: json['dataAfter'],
      lamportsBefore: json['lamportsBefore'],
      lamportsAfter: json['lamportsAfter'],
      changeType: json['changeType'],
    );
  }
}

/// Debug session for tracking development activities
class DebugSession {
  /// Session ID
  final String sessionId;

  /// Session start time
  final DateTime startTime;

  /// Configuration
  final DebugConfig config;

  /// Collected logs
  final List<DebugLogEntry> _logs = [];

  /// Transaction debug information
  final List<TransactionDebugInfo> _transactions = [];

  /// Performance metrics
  final Map<String, dynamic> _metrics = {};

  DebugSession({
    required this.sessionId,
    required this.config,
  }) : startTime = DateTime.now();

  /// Add log entry
  void addLog(DebugLogEntry entry) {
    if (_logs.length >= config.maxLogEntries) {
      _logs.removeAt(0); // Remove oldest entry
    }
    _logs.add(entry);
  }

  /// Add transaction debug info
  void addTransaction(TransactionDebugInfo info) {
    if (config.captureTransactionLogs) {
      _transactions.add(info);
    }
  }

  /// Update metrics
  void updateMetrics(String key, dynamic value) {
    if (config.trackPerformance) {
      _metrics[key] = value;
    }
  }

  /// Get all logs
  List<DebugLogEntry> get logs => List.unmodifiable(_logs);

  /// Get all transactions
  List<TransactionDebugInfo> get transactions =>
      List.unmodifiable(_transactions);

  /// Get metrics
  Map<String, dynamic> get metrics => Map.unmodifiable(_metrics);

  /// Export session data
  Map<String, dynamic> export() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'config': {
        'verbose': config.verbose,
        'captureTransactionLogs': config.captureTransactionLogs,
        'analyzeAccountChanges': config.analyzeAccountChanges,
        'trackPerformance': config.trackPerformance,
        'maxLogEntries': config.maxLogEntries,
      },
      'logs': _logs.map((log) => log.toJson()).toList(),
      'transactions': _transactions.map((tx) => tx.toJson()).toList(),
      'metrics': _metrics,
    };
  }

  /// Clear session data
  void clear() {
    _logs.clear();
    _transactions.clear();
    _metrics.clear();
  }
}

/// Main debug utility class
class AnchorDebugger {
  final DebugConfig config;
  final Map<String, DebugSession> _sessions = {};
  DebugSession? _currentSession;

  AnchorDebugger(this.config);

  /// Create a new debug session
  DebugSession createSession({String? sessionId}) {
    sessionId ??= 'session_${DateTime.now().millisecondsSinceEpoch}';
    final session = DebugSession(sessionId: sessionId, config: config);
    _sessions[sessionId] = session;
    _currentSession = session;
    return session;
  }

  /// Get current session
  DebugSession? get currentSession => _currentSession;

  /// Set current session
  void setCurrentSession(String sessionId) {
    _currentSession = _sessions[sessionId];
  }

  /// Log message to current session
  void log(String level, String message,
      {Map<String, dynamic>? context, String? source}) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      context: context,
      source: source,
    );

    _currentSession?.addLog(entry);

    if (config.verbose) {
      print(entry.toString());
    }
  }

  /// Log info message
  void info(String message, {Map<String, dynamic>? context, String? source}) {
    log('info', message, context: context, source: source);
  }

  /// Log warning message
  void warning(String message,
      {Map<String, dynamic>? context, String? source}) {
    log('warning', message, context: context, source: source);
  }

  /// Log error message
  void error(String message, {Map<String, dynamic>? context, String? source}) {
    log('error', message, context: context, source: source);
  }

  /// Log debug message
  void debug(String message, {Map<String, dynamic>? context, String? source}) {
    log('debug', message, context: context, source: source);
  }

  /// Analyze IDL for potential issues
  List<String> analyzeIdl(Idl idl) {
    final issues = <String>[];

    // Check for missing documentation
    if (idl.docs?.isEmpty ?? true) {
      issues.add('Program lacks documentation');
    }

    // Check instructions
    for (final instruction in idl.instructions) {
      if (instruction.docs?.isEmpty ?? true) {
        issues.add('Instruction "${instruction.name}" lacks documentation');
      }

      // Check for potentially expensive operations
      if (instruction.accounts.length > 10) {
        issues.add(
            'Instruction "${instruction.name}" has ${instruction.accounts.length} accounts - consider optimization');
      }
    }

    // Check accounts
    final accounts = idl.accounts ?? [];
    for (final account in accounts) {
      final fields = account.type.fields ?? [];
      if (fields.length > 20) {
        issues.add(
            'Account "${account.name}" has ${fields.length} fields - consider optimization');
      }
    }

    // Check errors
    final errors = idl.errors ?? [];
    if (errors.isEmpty && idl.instructions.isNotEmpty) {
      issues.add('Program has instructions but no custom error definitions');
    }

    info('IDL analysis completed', context: {'issues': issues.length});

    return issues;
  }

  /// Inspect program for debugging
  Future<Map<String, dynamic>> inspectProgram(Program program) async {
    final inspection = <String, dynamic>{};

    try {
      // Basic program info
      inspection['programId'] = program.programId.toBase58();
      inspection['provider'] = program.provider.connection.rpcUrl;

      // IDL information
      final idl = program.idl;
      inspection['idl'] = {
        'name': idl.name,
        'version': idl.version,
        'instructionCount': idl.instructions.length,
        'accountCount': idl.accounts?.length ?? 0,
        'errorCount': idl.errors?.length ?? 0,
      };

      // Connection status
      final connection = program.provider.connection;
      inspection['connection'] = {
        'url': connection.rpcUrl,
        'commitment': connection.commitment.toString(),
      };

      info('Program inspection completed', context: inspection);
    } catch (e) {
      error('Program inspection failed', context: {'error': e.toString()});
      inspection['error'] = e.toString();
    }

    return inspection;
  }

  /// Generate debug report
  String generateReport({String? sessionId}) {
    final session = sessionId != null ? _sessions[sessionId] : _currentSession;
    if (session == null) {
      return 'No debug session available';
    }

    final buffer = StringBuffer();

    buffer.writeln('# Debug Report');
    buffer.writeln('');
    buffer.writeln('**Session ID:** ${session.sessionId}');
    buffer.writeln('**Start Time:** ${session.startTime.toIso8601String()}');
    buffer.writeln(
        '**Duration:** ${DateTime.now().difference(session.startTime).inSeconds}s');
    buffer.writeln('');

    // Logs summary
    buffer.writeln('## Logs Summary');
    buffer.writeln('');
    buffer.writeln('Total logs: ${session.logs.length}');

    final logsByLevel = <String, int>{};
    for (final log in session.logs) {
      logsByLevel[log.level] = (logsByLevel[log.level] ?? 0) + 1;
    }

    for (final entry in logsByLevel.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
    buffer.writeln('');

    // Recent logs
    if (session.logs.isNotEmpty) {
      buffer.writeln('## Recent Logs');
      buffer.writeln('');
      final recentLogs = session.logs.take(10);
      for (final log in recentLogs) {
        buffer.writeln('- ${log.toString()}');
      }
      buffer.writeln('');
    }

    // Transactions
    if (session.transactions.isNotEmpty) {
      buffer.writeln('## Transactions');
      buffer.writeln('');
      for (final tx in session.transactions) {
        buffer.writeln('### ${tx.signature}');
        buffer.writeln('- Status: ${tx.status}');
        if (tx.computeUnitsConsumed != null) {
          buffer.writeln('- Compute Units: ${tx.computeUnitsConsumed}');
        }
        if (tx.error != null) {
          buffer.writeln('- Error: ${tx.error}');
        }
        buffer.writeln('');
      }
    }

    // Metrics
    if (session.metrics.isNotEmpty) {
      buffer.writeln('## Metrics');
      buffer.writeln('');
      for (final entry in session.metrics.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Export all session data
  Map<String, dynamic> exportAllSessions() {
    return {
      'sessions':
          _sessions.map((id, session) => MapEntry(id, session.export())),
      'currentSessionId': _currentSession?.sessionId,
    };
  }

  /// Clear all sessions
  void clearAllSessions() {
    _sessions.clear();
    _currentSession = null;
  }

  /// Get session by ID
  DebugSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  /// List all session IDs
  List<String> get sessionIds => _sessions.keys.toList();
}
