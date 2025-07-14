/// Program error handling for user-defined and framework errors
///
/// This module provides program error parsing and representation matching
/// the TypeScript Anchor SDK's ProgramError functionality.
library;

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/error/error_constants.dart';

/// Error from a user-defined program
class ProgramError extends Error {

  /// Create ProgramError with code, message and optional logs
  ProgramError({
    required this.code,
    required this.msg,
    this.logs,
  }) : _programErrorStack = logs != null ? ProgramErrorStack.parse(logs) : null;

  /// Create from JSON representation
  factory ProgramError.fromJson(Map<String, dynamic> json) {
    return ProgramError(
      code: json['code'] as int,
      msg: json['msg'] as String,
      logs: (json['logs'] as List?)?.cast<String>(),
    );
  }
  /// Error code number
  final int code;

  /// Error message
  final String msg;

  /// Get error message (alias for compatibility with TypeScript API)
  String get message => msg;

  /// Transaction logs (optional)
  final List<String>? logs;

  /// Program error stack for tracking CPI calls
  final ProgramErrorStack? _programErrorStack;

  /// Get the program that threw the error (last in stack)
  PublicKey? get program {
    if (_programErrorStack == null || _programErrorStack!.isEmpty) {
      return null;
    }
    return _programErrorStack!.currentProgram;
  }

  /// Get the complete program error stack
  List<PublicKey>? get programErrorStack => _programErrorStack?.stack;

  /// Parse ProgramError from error object and IDL errors
  static ProgramError? parse(
    dynamic err,
    Map<int, String> idlErrors,
  ) {
    String errString;

    // Extract error string from different error formats
    if (err is String) {
      errString = err;
    } else if (err is Map) {
      // Try to get message from error object
      errString = err['message']?.toString() ?? err.toString();
    } else {
      errString = err.toString();
    }

    // Parse error code from error string
    String? unparsedErrorCode;

    if (errString.contains('custom program error:')) {
      final components = errString.split('custom program error: ');
      if (components.length == 2) {
        unparsedErrorCode = components[1].trim();
      }
    } else {
      // Try to match JSON format: "Custom":12345}
      final customMatch = RegExp(r'"Custom":(\d+)').firstMatch(errString);
      if (customMatch != null) {
        unparsedErrorCode = customMatch.group(1);
      }
    }

    if (unparsedErrorCode == null) {
      return null;
    }

    // Parse the error code as integer
    int errorCode;
    try {
      // Handle hex format (0x prefix)
      if (unparsedErrorCode.startsWith('0x')) {
        errorCode = int.parse(unparsedErrorCode.substring(2), radix: 16);
      } else {
        errorCode = int.parse(unparsedErrorCode);
      }
    } catch (parseErr) {
      return null;
    }

    // Look up error message
    String? errorMsg;

    // First check user-defined IDL errors
    errorMsg = idlErrors[errorCode];
    if (errorMsg != null) {
      return ProgramError(
        code: errorCode,
        msg: errorMsg,
        logs: _extractLogsFromError(err),
      );
    }

    // Then check framework internal errors
    errorMsg = langErrorMessage[errorCode];
    if (errorMsg != null) {
      return ProgramError(
        code: errorCode,
        msg: errorMsg,
        logs: _extractLogsFromError(err),
      );
    }

    // Return ProgramError with default message if no specific message found
    return ProgramError(
      code: errorCode,
      msg: 'Unknown program error: $errorCode',
      logs: _extractLogsFromError(err),
    );
  }

  /// Extract logs from error object if available
  static List<String>? _extractLogsFromError(dynamic err) {
    try {
      // Handle different error object formats
      if (err is Map && err.containsKey('logs')) {
        return (err['logs'] as List?)?.cast<String>();
      }

      // Try to access logs property dynamically
      final logs = _getProperty(err, 'logs');
      if (logs is List) {
        return logs.cast<String>();
      }
    } catch (e) {
      // Ignore errors in log extraction
    }

    return null;
  }

  /// Helper to safely get property from dynamic object
  static dynamic _getProperty(dynamic obj, String property) {
    try {
      if (obj is Map) {
        return obj[property];
      }

      // For other object types, we can't safely access properties
      // without knowing the exact type, so return null
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() => msg;

  /// Get detailed error information as string
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.write('ProgramError: $msg (code: $code)');

    if (program != null) {
      buffer.write(' - Program: ${program!.toBase58()}');
    }

    if (programErrorStack != null && programErrorStack!.isNotEmpty) {
      buffer.write(' - Call stack: ');
      buffer.write(programErrorStack!.map((p) => p.toBase58()).join(' -> '));
    }

    return buffer.toString();
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'code': code,
      'msg': msg,
    };

    if (logs != null) {
      json['logs'] = logs;
    }

    if (_programErrorStack != null) {
      json['programErrorStack'] = _programErrorStack!.toJson();
    }

    return json;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProgramError &&
        other.code == code &&
        other.msg == msg &&
        _listEquals(other.logs, logs);
  }

  @override
  int get hashCode => code.hashCode ^ msg.hashCode ^ logs.hashCode;
}

/// Error translation function matching TypeScript translateError
dynamic translateError(dynamic err, Map<int, String> idlErrors) {
  // First try to parse as AnchorError
  if (err is Map && err.containsKey('logs')) {
    final logs = (err['logs'] as List?)?.cast<String>();
    if (logs != null) {
      final anchorError = AnchorError.parse(logs);
      if (anchorError != null) {
        return anchorError;
      }
    }
  }

  // Then try to parse as ProgramError
  final programError = ProgramError.parse(err, idlErrors);
  if (programError != null) {
    return programError;
  }

  // For other errors with logs, attach program error stack
  if (err is Map && err.containsKey('logs')) {
    final logs = (err['logs'] as List?)?.cast<String>();
    if (logs != null) {
      final programErrorStack = ProgramErrorStack.parse(logs);

      // Create a wrapper that adds program and programErrorStack properties
      return _ErrorWithStack(err, programErrorStack);
    }
  }

  // Return original error if no transformation possible
  return err;
}

/// Wrapper class to add program error stack to existing errors
class _ErrorWithStack {

  _ErrorWithStack(this.originalError, this.programErrorStack);
  final dynamic originalError;
  final ProgramErrorStack programErrorStack;

  /// Get the program that caused the error
  PublicKey? get program => programErrorStack.currentProgram;

  /// Get the program error stack
  List<PublicKey> get stack => programErrorStack.stack;

  @override
  String toString() => originalError.toString();

  /// Forward all other property access to original error
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final name = invocation.memberName.toString();
      if (name == 'Symbol("program")') {
        return program;
      } else if (name == 'Symbol("programErrorStack")') {
        return stack;
      }
    }

    // Forward to original error
    return originalError;
  }
}

/// Helper function to compare lists for equality
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
