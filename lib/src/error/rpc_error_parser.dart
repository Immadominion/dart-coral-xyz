/// RPC Error Parsing Engine
///
/// Comprehensive RPC error parsing matching TypeScript Anchor's
/// AnchorError.parse() sophisticated log analysis capabilities.
///
/// This provides structured error parsing from transaction logs,
/// program error extraction, and detailed error context.
library;

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/error/program_error.dart' as programErrorLib;

/// Result of RPC error parsing
class RpcErrorParseResult {

  const RpcErrorParseResult({
    this.anchorError,
    this.programError,
    required this.originalError,
  });
  /// Parsed AnchorError if found
  final AnchorError? anchorError;

  /// Parsed ProgramError if found
  final programErrorLib.ProgramError? programError;

  /// Original error if no parsing was possible
  final dynamic originalError;

  /// Whether any parsing was successful
  bool get hasParsedError => anchorError != null || programError != null;

  /// Get the best available error (parsed or original)
  dynamic get bestError => anchorError ?? programError ?? originalError;
}

/// Enhanced error parsing context
class ErrorParsingContext {

  const ErrorParsingContext({
    required this.error,
    required this.logs,
    this.idlErrors = const {},
    this.debugMode = false,
  });
  /// Original error object
  final dynamic error;

  /// Transaction logs
  final List<String> logs;

  /// IDL error mappings
  final Map<int, String> idlErrors;

  /// Debug mode flag
  final bool debugMode;
}

/// RPC Error Parser - main parsing engine
class RpcErrorParser {
  /// Parse RPC error using comprehensive strategies
  static RpcErrorParseResult parse(
    dynamic error, {
    Map<int, String> idlErrors = const {},
    bool debugMode = false,
  }) {
    if (error == null) {
      return RpcErrorParseResult(originalError: error);
    }

    // Extract logs from error
    final logs = _extractLogs(error);
    if (logs.isEmpty) {
      return RpcErrorParseResult(originalError: error);
    }

    final context = ErrorParsingContext(
      error: error,
      logs: logs,
      idlErrors: idlErrors,
      debugMode: debugMode,
    );

    if (debugMode) {
      print('RpcErrorParser: Parsing error with ${logs.length} log lines');
    }

    // Try to parse as AnchorError first
    final anchorError = _parseAnchorError(context);
    if (anchorError != null) {
      return RpcErrorParseResult(
        anchorError: anchorError,
        originalError: error,
      );
    }

    // Try to parse as ProgramError
    final programError = _parseProgramError(context);
    if (programError != null) {
      return RpcErrorParseResult(
        programError: programError,
        originalError: error,
      );
    }

    // If we have logs but couldn't parse, enhance the original error
    final enhancedError = _enhanceErrorWithLogs(error, logs);
    return RpcErrorParseResult(originalError: enhancedError);
  }

  /// Extract transaction logs from error object
  static List<String> _extractLogs(dynamic error) {
    try {
      if (error is Map) {
        final logs = error['logs'];
        if (logs is List) {
          return logs.cast<String>();
        }
      }

      // Try to access logs property dynamically
      if (_hasProperty(error, 'logs')) {
        final logs = _getProperty(error, 'logs');
        if (logs is List) {
          return logs.cast<String>();
        }
      }
    } catch (e) {
      // Ignore extraction errors
    }

    return [];
  }

  /// Parse AnchorError from transaction logs
  static AnchorError? _parseAnchorError(ErrorParsingContext context) {
    final logs = context.logs;

    // Find AnchorError log line
    final anchorErrorLogIndex = logs.indexWhere(
      (log) => log.startsWith('Program log: AnchorError'),
    );

    if (anchorErrorLogIndex == -1) {
      return null;
    }

    final anchorErrorLog = logs[anchorErrorLogIndex];
    final errorLogs = <String>[anchorErrorLog];

    // Extract compared values if present
    ComparedValues? comparedValues;

    if (anchorErrorLogIndex + 1 < logs.length) {
      comparedValues = _extractComparedValues(
        logs,
        anchorErrorLogIndex,
        errorLogs,
        context.debugMode,
      );
    }

    // Parse error using regex patterns
    return _parseErrorWithRegex(
      anchorErrorLog,
      errorLogs,
      logs,
      comparedValues,
      context.debugMode,
    );
  }

  /// Extract compared values from logs
  static ComparedValues? _extractComparedValues(
    List<String> logs,
    int anchorErrorLogIndex,
    List<String> errorLogs,
    bool debugMode,
  ) {
    if (anchorErrorLogIndex + 1 >= logs.length) {
      return null;
    }

    final nextLog = logs[anchorErrorLogIndex + 1];

    // Check for separated public key format:
    // Left:
    // <Pubkey>
    // Right:
    // <Pubkey>
    if (nextLog == 'Program log: Left:') {
      if (anchorErrorLogIndex + 4 < logs.length) {
        try {
          final pubkeyRegex = RegExp(r'^Program log: (.*)$');
          final leftMatch =
              pubkeyRegex.firstMatch(logs[anchorErrorLogIndex + 2]);
          final rightLog = logs[anchorErrorLogIndex + 3];
          final rightMatch =
              pubkeyRegex.firstMatch(logs[anchorErrorLogIndex + 4]);

          // Verify "Right:" log is present
          if (leftMatch != null &&
              rightLog == 'Program log: Right:' &&
              rightMatch != null) {
            final leftPubkey = PublicKey.fromBase58(leftMatch.group(1)!);
            final rightPubkey = PublicKey.fromBase58(rightMatch.group(1)!);

            errorLogs.addAll(logs.getRange(
              anchorErrorLogIndex + 1,
              anchorErrorLogIndex + 5,
            ),);

            return ComparedValues.publicKeys([leftPubkey, rightPubkey]);
          }
        } catch (e) {
          if (debugMode) {
            print('Failed to parse separated pubkeys: $e');
          }
        }
      }
    }
    // Check for inline value format:
    // Left: <value>
    // Right: <value>
    else if (nextLog.startsWith('Program log: Left:')) {
      if (anchorErrorLogIndex + 2 < logs.length) {
        try {
          final valueRegex = RegExp(r'^Program log: (Left|Right): (.*)$');
          final leftMatch =
              valueRegex.firstMatch(logs[anchorErrorLogIndex + 1]);
          final rightMatch =
              valueRegex.firstMatch(logs[anchorErrorLogIndex + 2]);

          if (leftMatch != null && rightMatch != null) {
            final leftValue = leftMatch.group(2)!;
            final rightValue = rightMatch.group(2)!;

            errorLogs.addAll(logs.getRange(
              anchorErrorLogIndex + 1,
              anchorErrorLogIndex + 3,
            ),);

            return ComparedValues.accountNames([leftValue, rightValue]);
          }
        } catch (e) {
          if (debugMode) {
            print('Failed to parse inline values: $e');
          }
        }
      }
    }

    return null;
  }

  /// Parse error using regex patterns matching TypeScript
  static AnchorError? _parseErrorWithRegex(
    String anchorErrorLog,
    List<String> errorLogs,
    List<String> logs,
    ComparedValues? comparedValues,
    bool debugMode,
  ) {
    // Pattern 1: No additional info
    final regexNoInfo = RegExp(
      r'^Program log: AnchorError occurred\. Error Code: (.*)\. Error Number: (\d*)\. Error Message: (.*)\.$',
    );
    final noInfoMatch = regexNoInfo.firstMatch(anchorErrorLog);

    if (noInfoMatch != null) {
      final errorCodeString = noInfoMatch.group(1)!;
      final errorNumber = int.parse(noInfoMatch.group(2)!);
      final errorMessage = noInfoMatch.group(3)!;

      final errorCode = ErrorCode(
        code: errorCodeString,
        number: errorNumber,
      );

      final errorInfo = ErrorInfo(
        errorCode: errorCode,
        errorMessage: errorMessage,
        comparedValues: comparedValues,
      );

      return AnchorError(
        error: errorInfo,
        errorLogs: errorLogs,
        logs: logs,
      );
    }

    // Pattern 2: File and line info
    final regexFileLine = RegExp(
      r'^Program log: AnchorError thrown in (.*):(\d*)\. Error Code: (.*)\. Error Number: (\d*)\. Error Message: (.*)\.$',
    );
    final fileLineMatch = regexFileLine.firstMatch(anchorErrorLog);

    if (fileLineMatch != null) {
      final file = fileLineMatch.group(1)!;
      final line = int.parse(fileLineMatch.group(2)!);
      final errorCodeString = fileLineMatch.group(3)!;
      final errorNumber = int.parse(fileLineMatch.group(4)!);
      final errorMessage = fileLineMatch.group(5)!;

      final errorCode = ErrorCode(
        code: errorCodeString,
        number: errorNumber,
      );

      final fileLine = FileLine(
        file: file,
        line: line,
      );

      final errorInfo = ErrorInfo(
        errorCode: errorCode,
        errorMessage: errorMessage,
        origin: Origin.fileLine(fileLine),
        comparedValues: comparedValues,
      );

      return AnchorError(
        error: errorInfo,
        errorLogs: errorLogs,
        logs: logs,
      );
    }

    // Pattern 3: Account name info
    final regexAccountName = RegExp(
      r'^Program log: AnchorError caused by account: (.*)\. Error Code: (.*)\. Error Number: (\d*)\. Error Message: (.*)\.$',
    );
    final accountNameMatch = regexAccountName.firstMatch(anchorErrorLog);

    if (accountNameMatch != null) {
      final accountName = accountNameMatch.group(1)!;
      final errorCodeString = accountNameMatch.group(2)!;
      final errorNumber = int.parse(accountNameMatch.group(3)!);
      final errorMessage = accountNameMatch.group(4)!;

      final errorCode = ErrorCode(
        code: errorCodeString,
        number: errorNumber,
      );

      final errorInfo = ErrorInfo(
        errorCode: errorCode,
        errorMessage: errorMessage,
        origin: Origin.accountName(accountName),
        comparedValues: comparedValues,
      );

      return AnchorError(
        error: errorInfo,
        errorLogs: errorLogs,
        logs: logs,
      );
    }

    if (debugMode) {
      print('Failed to parse AnchorError log: $anchorErrorLog');
    }

    return null;
  }

  /// Parse ProgramError from context
  static programErrorLib.ProgramError? _parseProgramError(
      ErrorParsingContext context,) => programErrorLib.ProgramError.parse(context.error, context.idlErrors);

  /// Enhance error with program error stack from logs
  static dynamic _enhanceErrorWithLogs(dynamic error, List<String> logs) {
    final programErrorStack = ProgramErrorStack.parse(logs);

    // Always create enhanced error when logs are present
    return EnhancedError(
      originalError: error,
      programErrorStack: programErrorStack,
      logs: logs,
    );
  }

  /// Helper to check if object has property
  static bool _hasProperty(dynamic obj, String property) {
    try {
      if (obj is Map) {
        return obj.containsKey(property);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Helper to get property from dynamic object
  static dynamic _getProperty(dynamic obj, String property) {
    try {
      if (obj is Map) {
        return obj[property];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Enhanced error wrapper for errors with program context
class EnhancedError extends Error {

  EnhancedError({
    required this.originalError,
    required this.programErrorStack,
    required this.logs,
  });
  /// Original error object
  final dynamic originalError;

  /// Program error stack
  final ProgramErrorStack programErrorStack;

  /// Transaction logs
  final List<String> logs;

  /// Get the program that caused the error
  PublicKey? get program {
    if (programErrorStack.isEmpty) {
      return null;
    }
    return programErrorStack.currentProgram;
  }

  /// Get the complete program stack
  List<PublicKey> get programStack => programErrorStack.stack;

  @override
  String toString() => originalError.toString();

  /// Convert to detailed string with program context
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.write('Enhanced Error: ${originalError.toString()}');

    if (programErrorStack.isNotEmpty) {
      buffer.write(
          '\nProgram Stack: ${programStack.map((p) => p.toBase58()).join(' -> ')}',);
    }

    buffer.write('\nLogs: ${logs.length} lines');

    return buffer.toString();
  }
}

/// Enhanced error translation function with comprehensive RPC parsing
dynamic translateRpcError(
  dynamic err, {
  Map<int, String> idlErrors = const {},
  bool debugMode = false,
}) {
  if (debugMode) {
    print('Translating RPC error: $err');
  }

  final result = RpcErrorParser.parse(
    err,
    idlErrors: idlErrors,
    debugMode: debugMode,
  );

  return result.bestError;
}
