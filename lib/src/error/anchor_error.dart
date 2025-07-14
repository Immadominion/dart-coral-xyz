/// Core Anchor Error Foundation
///
/// This module provides the base error type system matching TypeScript's AnchorError
/// hierarchy with exact error code compatibility and comprehensive error handling.
library;

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

/// Represents an error code with both string and numeric representations
class ErrorCode {

  const ErrorCode({
    required this.code,
    required this.number,
  });

  /// Create ErrorCode from JSON representation
  factory ErrorCode.fromJson(Map<String, dynamic> json) {
    return ErrorCode(
      code: json['code'] as String,
      number: json['number'] as int,
    );
  }
  /// String representation of the error code
  final String code;

  /// Numeric error code value
  final int number;

  @override
  String toString() => '$code ($number)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorCode && other.code == code && other.number == number;
  }

  @override
  int get hashCode => code.hashCode ^ number.hashCode;

  /// Convert ErrorCode to JSON representation
  Map<String, dynamic> toJson() => {
      'code': code,
      'number': number,
    };
}

/// Represents a file and line location for error reporting
class FileLine {

  const FileLine({
    required this.file,
    required this.line,
  });

  /// Create FileLine from JSON representation
  factory FileLine.fromJson(Map<String, dynamic> json) {
    return FileLine(
      file: json['file'] as String,
      line: json['line'] as int,
    );
  }
  /// Source file path
  final String file;

  /// Line number in the file
  final int line;

  @override
  String toString() => '$file:$line';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileLine && other.file == file && other.line == line;
  }

  @override
  int get hashCode => file.hashCode ^ line.hashCode;

  /// Convert FileLine to JSON representation
  Map<String, dynamic> toJson() => {
      'file': file,
      'line': line,
    };
}

/// Union type for error origin (either string account name or file location)
abstract class Origin {

  /// Create origin from JSON representation
  factory Origin.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('accountName')) {
      return AccountNameOrigin(json['accountName'] as String);
    } else if (json.containsKey('file') && json.containsKey('line')) {
      return FileLineOrigin(FileLine.fromJson(json));
    } else {
      throw ArgumentError('Invalid origin JSON format');
    }
  }
  const Origin();

  /// Create origin from account name
  factory Origin.accountName(String accountName) = AccountNameOrigin;

  /// Create origin from file location
  factory Origin.fileLine(FileLine fileLine) = FileLineOrigin;

  /// Get the account name if this is an account name origin, null otherwise
  String? get accountName => null;

  /// Get the file line if this is a file line origin, null otherwise
  FileLine? get fileLine => null;

  /// Convert origin to JSON representation
  Map<String, dynamic> toJson();
}

/// Account name origin implementation
class AccountNameOrigin extends Origin {

  const AccountNameOrigin(this._accountName);
  final String _accountName;

  @override
  String? get accountName => _accountName;

  @override
  String toString() => _accountName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountNameOrigin && other._accountName == _accountName;
  }

  @override
  int get hashCode => _accountName.hashCode;

  @override
  Map<String, dynamic> toJson() => {'accountName': _accountName};
}

/// File line origin implementation
class FileLineOrigin extends Origin {

  const FileLineOrigin(this._fileLine);
  final FileLine _fileLine;

  @override
  FileLine? get fileLine => _fileLine;

  @override
  String toString() => _fileLine.toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileLineOrigin && other._fileLine == _fileLine;
  }

  @override
  int get hashCode => _fileLine.hashCode;

  @override
  Map<String, dynamic> toJson() => _fileLine.toJson();
}

/// Union type for compared values in error messages
abstract class ComparedValues {

  /// Create compared values from JSON representation
  factory ComparedValues.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('accountNames')) {
      final accountNames =
          (json['accountNames'] as List).map((e) => e as String).toList();
      return ComparedAccountNames(accountNames);
    } else if (json.containsKey('publicKeys')) {
      final publicKeys = (json['publicKeys'] as List)
          .map((e) => PublicKey.fromBase58(e as String))
          .toList();
      return ComparedPublicKeys(publicKeys);
    } else {
      throw ArgumentError('Invalid compared values JSON format');
    }
  }
  const ComparedValues();

  /// Create compared values from account names
  factory ComparedValues.accountNames(List<String> accountNames) {
    if (accountNames.length != 2) {
      throw ArgumentError('Account names must contain exactly 2 elements');
    }
    return ComparedAccountNames(accountNames);
  }

  /// Create compared values from public keys
  factory ComparedValues.publicKeys(List<PublicKey> publicKeys) {
    if (publicKeys.length != 2) {
      throw ArgumentError('Public keys must contain exactly 2 elements');
    }
    return ComparedPublicKeys(publicKeys);
  }

  /// Get the account names if this contains account names, null otherwise
  List<String>? get accountNames => null;

  /// Get the public keys if this contains public keys, null otherwise
  List<PublicKey>? get publicKeys => null;

  /// Convert compared values to JSON representation
  Map<String, dynamic> toJson();

  /// Get the compared values as a list of strings for display
  List<String> get values;
}

/// Account names compared values implementation
class ComparedAccountNames extends ComparedValues {

  const ComparedAccountNames(this._accountNames);
  final List<String> _accountNames;

  @override
  List<String>? get accountNames => _accountNames;

  @override
  String toString() => 'Left: ${_accountNames[0]}, Right: ${_accountNames[1]}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComparedAccountNames &&
        _listEquals(other._accountNames, _accountNames);
  }

  @override
  int get hashCode => _accountNames.fold(0, (h, v) => h ^ v.hashCode);

  @override
  Map<String, dynamic> toJson() => {'accountNames': _accountNames};

  @override
  List<String> get values => _accountNames;
}

/// Public keys compared values implementation
class ComparedPublicKeys extends ComparedValues {

  const ComparedPublicKeys(this._publicKeys);
  final List<PublicKey> _publicKeys;

  @override
  List<PublicKey>? get publicKeys => _publicKeys;

  @override
  String toString() => 'Left: ${_publicKeys[0]}, Right: ${_publicKeys[1]}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComparedPublicKeys &&
        _listEquals(other._publicKeys, _publicKeys);
  }

  @override
  int get hashCode => _publicKeys.fold(0, (h, v) => h ^ v.hashCode);

  @override
  Map<String, dynamic> toJson() =>
      {'publicKeys': _publicKeys.map((pk) => pk.toBase58()).toList()};

  @override
  List<String> get values => _publicKeys.map((pk) => pk.toBase58()).toList();
}

/// Stack of programs being executed, used for tracking CPI calls
class ProgramErrorStack {

  const ProgramErrorStack(this.stack);

  /// Create from JSON representation
  factory ProgramErrorStack.fromJson(Map<String, dynamic> json) {
    final stackList = (json['stack'] as List)
        .map((e) => PublicKey.fromBase58(e as String))
        .toList();
    return ProgramErrorStack(stackList);
  }
  /// List of program public keys in execution order
  final List<PublicKey> stack;

  /// Parse program execution stack from transaction logs
  static ProgramErrorStack parse(List<String> logs) {
    final programKeyRegex = RegExp(r'^Program (\w+) invoke');
    final successRegex = RegExp(r'^Program \w+ success$');

    final programStack = <PublicKey>[];

    for (final log in logs) {
      if (successRegex.hasMatch(log)) {
        if (programStack.isNotEmpty) {
          programStack.removeLast();
        }
        continue;
      }

      final match = programKeyRegex.firstMatch(log);
      if (match != null) {
        try {
          final programKey = PublicKey.fromBase58(match.group(1)!);
          programStack.add(programKey);
        } catch (e) {
          // Invalid public key, skip
          continue;
        }
      }
    }

    return ProgramErrorStack(programStack);
  }

  /// Get the currently executing program (last in stack)
  PublicKey? get currentProgram => stack.isNotEmpty ? stack.last : null;

  /// Check if stack is empty
  bool get isEmpty => stack.isEmpty;

  /// Check if stack is not empty
  bool get isNotEmpty => stack.isNotEmpty;

  /// Get stack length
  int get length => stack.length;

  @override
  String toString() => stack.map((p) => p.toBase58()).join(' -> ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProgramErrorStack && _listEquals(other.stack, stack);
  }

  @override
  int get hashCode => stack.fold(0, (h, v) => h ^ v.hashCode);

  /// Convert to JSON representation
  Map<String, dynamic> toJson() =>
      {'stack': stack.map((pk) => pk.toBase58()).toList()};
}

/// Base Anchor error class matching TypeScript AnchorError
class AnchorError extends Error {

  /// Create AnchorError with comprehensive error information
  AnchorError({
    required this.error,
    required this.errorLogs,
    required this.logs,
  }) : _programErrorStack = ProgramErrorStack.parse(logs);

  /// Create from JSON representation
  factory AnchorError.fromJson(Map<String, dynamic> json) {
    return AnchorError(
      error: ErrorInfo.fromJson(json['error'] as Map<String, dynamic>),
      errorLogs: (json['errorLogs'] as List).cast<String>(),
      logs: (json['logs'] as List).cast<String>(),
    );
  }
  /// Error information containing code and message
  final ErrorInfo error;

  /// Raw error logs from the transaction
  final List<String> errorLogs;

  /// Complete transaction logs
  final List<String> logs;

  /// Program error stack for tracking CPI calls
  final ProgramErrorStack _programErrorStack;

  /// Get the program that threw the error (last in stack)
  PublicKey get program {
    if (_programErrorStack.isEmpty) {
      throw StateError('No program in error stack');
    }
    return _programErrorStack.currentProgram!;
  }

  /// Get the complete program error stack
  List<PublicKey> get programErrorStack => _programErrorStack.stack;

  /// Get detailed error message
  String get message => error.errorMessage;

  /// Get error message (alias for compatibility with TypeScript API)
  String get errorMessage => error.errorMessage;

  /// Get error code
  ErrorCode get errorCode => error.errorCode;

  /// Get error origin if available
  Origin? get origin => error.origin;

  /// Get compared values if available
  ComparedValues? get comparedValues => error.comparedValues;

  @override
  String toString() {
    final buffer = StringBuffer();

    if (error.origin is FileLineOrigin) {
      final fileLine = (error.origin as FileLineOrigin).fileLine!;
      buffer.write('AnchorError thrown in ${fileLine.file}:${fileLine.line}. ');
    } else if (error.origin is AccountNameOrigin) {
      final accountName = (error.origin as AccountNameOrigin).accountName!;
      buffer.write('AnchorError caused by account: $accountName. ');
    } else {
      buffer.write('AnchorError occurred. ');
    }

    buffer.write('Error Code: ${error.errorCode.code}. ');
    buffer.write('Error Number: ${error.errorCode.number}. ');
    buffer.write('Error Message: ${error.errorMessage}.');

    return buffer.toString();
  }

  /// Parse AnchorError from transaction logs
  static AnchorError? parse(List<String>? logs) {
    if (logs == null || logs.isEmpty) return null;

    final anchorErrorLogIndex = logs.indexWhere(
      (log) => log.startsWith('Program log: AnchorError'),
    );

    if (anchorErrorLogIndex == -1) return null;

    final anchorErrorLog = logs[anchorErrorLogIndex];
    final errorLogs = [anchorErrorLog];
    ComparedValues? comparedValues;

    // Check for compared values in following logs
    if (anchorErrorLogIndex + 1 < logs.length) {
      comparedValues =
          _parseComparedValues(logs, anchorErrorLogIndex, errorLogs);
    }

    // Parse different error formats
    final errorInfo = _parseErrorInfo(anchorErrorLog, comparedValues);
    if (errorInfo == null) return null;

    return AnchorError(
      error: errorInfo,
      errorLogs: errorLogs,
      logs: logs,
    );
  }

  /// Parse compared values from logs
  static ComparedValues? _parseComparedValues(
      List<String> logs, int anchorErrorLogIndex, List<String> errorLogs,) {
    // Pattern: Left: / Right: with pubkeys
    if (logs[anchorErrorLogIndex + 1] == 'Program log: Left:') {
      final pubkeyRegex = RegExp(r'^Program log: (.*)$');
      final leftMatch = pubkeyRegex.firstMatch(logs[anchorErrorLogIndex + 2]);
      final rightMatch = pubkeyRegex.firstMatch(logs[anchorErrorLogIndex + 4]);

      if (leftMatch != null && rightMatch != null) {
        try {
          final leftPubkey = PublicKey.fromBase58(leftMatch.group(1)!);
          final rightPubkey = PublicKey.fromBase58(rightMatch.group(1)!);
          errorLogs.addAll(logs.sublist(
            anchorErrorLogIndex + 1,
            anchorErrorLogIndex + 5,
          ),);
          return ComparedValues.publicKeys([leftPubkey, rightPubkey]);
        } catch (e) {
          // Not valid pubkeys, continue to next pattern
        }
      }
    }
    // Pattern: Left: <value> / Right: <value>
    else if (logs[anchorErrorLogIndex + 1].startsWith('Program log: Left:')) {
      final valueRegex = RegExp(r'^Program log: (Left|Right): (.*)$');
      final leftMatch = valueRegex.firstMatch(logs[anchorErrorLogIndex + 1]);
      final rightMatch = valueRegex.firstMatch(logs[anchorErrorLogIndex + 2]);

      if (leftMatch != null && rightMatch != null) {
        final leftValue = leftMatch.group(2)!;
        final rightValue = rightMatch.group(2)!;
        errorLogs.addAll(logs.sublist(
          anchorErrorLogIndex + 1,
          anchorErrorLogIndex + 3,
        ),);
        return ComparedValues.accountNames([leftValue, rightValue]);
      }
    }

    return null;
  }

  /// Parse error information from log line
  static ErrorInfo? _parseErrorInfo(
      String anchorErrorLog, ComparedValues? comparedValues,) {
    // Pattern: AnchorError occurred. Error Code: <code>. Error Number: <number>. Error Message: <message>.
    final regexNoInfo = RegExp(
      r'^Program log: AnchorError occurred\. Error Code: (.*)\. Error Number: (\d+)\. Error Message: (.*)\.?$',
    );

    // Pattern: AnchorError thrown in <file>:<line>. Error Code: <code>. Error Number: <number>. Error Message: <message>.
    final regexFileLine = RegExp(
      r'^Program log: AnchorError thrown in (.*):(\d+)\. Error Code: (.*)\. Error Number: (\d+)\. Error Message: (.*)\.?$',
    );

    // Pattern: AnchorError caused by account: <account>. Error Code: <code>. Error Number: <number>. Error Message: <message>.
    final regexAccountName = RegExp(
      r'^Program log: AnchorError caused by account: (.*)\. Error Code: (.*)\. Error Number: (\d+)\. Error Message: (.*)\.?$',
    );

    final noInfoMatch = regexNoInfo.firstMatch(anchorErrorLog);
    final fileLineMatch = regexFileLine.firstMatch(anchorErrorLog);
    final accountNameMatch = regexAccountName.firstMatch(anchorErrorLog);

    if (noInfoMatch != null) {
      final errorCodeString = noInfoMatch.group(1)!;
      final errorNumber = int.parse(noInfoMatch.group(2)!);
      var errorMessage = noInfoMatch.group(3)!;

      // Remove trailing period if present
      if (errorMessage.endsWith('.')) {
        errorMessage = errorMessage.substring(0, errorMessage.length - 1);
      }

      return ErrorInfo(
        errorCode: ErrorCode(code: errorCodeString, number: errorNumber),
        errorMessage: errorMessage,
        comparedValues: comparedValues,
      );
    } else if (fileLineMatch != null) {
      final file = fileLineMatch.group(1)!;
      final line = int.parse(fileLineMatch.group(2)!);
      final errorCodeString = fileLineMatch.group(3)!;
      final errorNumber = int.parse(fileLineMatch.group(4)!);
      var errorMessage = fileLineMatch.group(5)!;

      // Remove trailing period if present
      if (errorMessage.endsWith('.')) {
        errorMessage = errorMessage.substring(0, errorMessage.length - 1);
      }

      return ErrorInfo(
        errorCode: ErrorCode(code: errorCodeString, number: errorNumber),
        errorMessage: errorMessage,
        origin: Origin.fileLine(FileLine(file: file, line: line)),
        comparedValues: comparedValues,
      );
    } else if (accountNameMatch != null) {
      final accountName = accountNameMatch.group(1)!;
      final errorCodeString = accountNameMatch.group(2)!;
      final errorNumber = int.parse(accountNameMatch.group(3)!);
      var errorMessage = accountNameMatch.group(4)!;

      // Remove trailing period if present
      if (errorMessage.endsWith('.')) {
        errorMessage = errorMessage.substring(0, errorMessage.length - 1);
      }

      return ErrorInfo(
        errorCode: ErrorCode(code: errorCodeString, number: errorNumber),
        errorMessage: errorMessage,
        origin: Origin.accountName(accountName),
        comparedValues: comparedValues,
      );
    }

    return null;
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() => {
      'error': error.toJson(),
      'errorLogs': errorLogs,
      'logs': logs,
    };
}

/// Error information container
class ErrorInfo {

  const ErrorInfo({
    required this.errorCode,
    required this.errorMessage,
    this.origin,
    this.comparedValues,
  });

  /// Create from JSON representation
  factory ErrorInfo.fromJson(Map<String, dynamic> json) {
    return ErrorInfo(
      errorCode: ErrorCode.fromJson(json['errorCode'] as Map<String, dynamic>),
      errorMessage: json['errorMessage'] as String,
      origin: json['origin'] != null
          ? Origin.fromJson(json['origin'] as Map<String, dynamic>)
          : null,
      comparedValues: json['comparedValues'] != null
          ? ComparedValues.fromJson(
              json['comparedValues'] as Map<String, dynamic>)
          : null,
    );
  }
  /// Error code with string and numeric representations
  final ErrorCode errorCode;

  /// Human-readable error message
  final String errorMessage;

  /// Optional error origin (file location or account name)
  final Origin? origin;

  /// Optional compared values for debugging
  final ComparedValues? comparedValues;

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'errorCode': errorCode.toJson(),
      'errorMessage': errorMessage,
    };

    if (origin != null) {
      json['origin'] = origin!.toJson();
    }

    if (comparedValues != null) {
      json['comparedValues'] = comparedValues!.toJson();
    }

    return json;
  }

  @override
  String toString() => errorMessage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorInfo &&
        other.errorCode == errorCode &&
        other.errorMessage == errorMessage &&
        other.origin == origin &&
        other.comparedValues == comparedValues;
  }

  @override
  int get hashCode =>
      errorCode.hashCode ^
      errorMessage.hashCode ^
      origin.hashCode ^
      comparedValues.hashCode;
}

/// Base exception class for IDL-related errors
class IdlError extends Error {

  IdlError(this.message);
  final String message;

  @override
  String toString() => 'IdlError: $message';
}

/// Helper function to compare lists for equality
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Creates a map of error codes to error messages from an IDL
Map<int, String> createIdlErrorMap(Idl idl) {
  final errorMap = <int, String>{};

  // Extract errors from IDL and build map
  if (idl.errors != null) {
    for (final errorCode in idl.errors!) {
      if (errorCode.msg != null && errorCode.msg!.isNotEmpty) {
        errorMap[errorCode.code] = errorCode.msg!;
      }
    }
  }

  return errorMap;
}

/// Error origin type (placeholder for compatibility)
typedef ErrorOrigin = Origin;

/// Language error message mapping (placeholder for compatibility)
abstract class LangErrorMessage {
  /// Common Anchor framework error codes
  static const int instructionMissing = 100;
  static const int constraintMut = 2000;
  static const int accountDidNotDeserialize = 3000;
  static const int requireViolated = 2500;

  /// Map of error codes to error messages
  static const Map<int, String> langErrorMessages = {
    instructionMissing: 'Instruction discriminator not provided',
    constraintMut: 'A mut constraint was violated',
    accountDidNotDeserialize: 'Failed to deserialize the account',
    requireViolated: 'A require expression was violated',
  };

  /// Get error message for a given error code
  static String? getMessage(int code) => langErrorMessages[code];

  /// Check if an error code is a language error
  static bool isLangError(int code) => langErrorMessages.containsKey(code);
}

/// Enhanced error class for account discriminator mismatches
class AccountDiscriminatorMismatchError extends AnchorError {

  AccountDiscriminatorMismatchError({
    required this.expected,
    required this.actual,
    required this.accountAddress,
    required String message,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode:
                ErrorCode(code: 'AccountDiscriminatorMismatch', number: 3001),
            errorMessage: message,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );
  final List<int> expected;
  final List<int> actual;
  final PublicKey accountAddress;

  @override
  String toString() => 'AccountDiscriminatorMismatchError: $message\n'
        'Expected: ${expected.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}\n'
        'Actual: ${actual.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}\n'
        'Account: ${accountAddress.toBase58()}';
}

/// Enhanced error class for constraint violations
class ConstraintError extends AnchorError {

  ConstraintError({
    required this.constraintType,
    required String message,
    required int errorCode,
    this.accountAddress,
    this.context = const {},
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(code: constraintType, number: errorCode),
            errorMessage: message,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );
  final String constraintType;
  final PublicKey? accountAddress;
  final Map<String, dynamic> context;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ConstraintError ($constraintType): $message');
    if (accountAddress != null) {
      buffer.writeln('Account: ${accountAddress!.toBase58()}');
    }
    if (context.isNotEmpty) {
      buffer.writeln('Context: $context');
    }
    return buffer.toString();
  }
}

/// Enhanced error class for instruction errors
class InstructionError extends AnchorError {

  InstructionError({
    required this.instructionName,
    required this.instructionIndex,
    required String message,
    required int errorCode,
    this.instructionData = const {},
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(code: 'InstructionError', number: errorCode),
            errorMessage: message,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );
  final String instructionName;
  final int instructionIndex;
  final Map<String, dynamic> instructionData;

  @override
  String toString() => 'InstructionError ($instructionName at index $instructionIndex): $message\n'
        'Data: $instructionData';
}

/// Enhanced error class for program errors
class ProgramError extends AnchorError {

  ProgramError({
    required this.programId,
    required String message,
    required int errorCode,
    this.customErrorCode,
    this.programName,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(code: 'ProgramError', number: errorCode),
            errorMessage: message,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );
  final PublicKey programId;
  final int? customErrorCode;
  final String? programName;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ProgramError: $message');
    buffer.writeln('Program: ${programName ?? programId.toBase58()}');
    if (customErrorCode != null) {
      buffer.writeln('Custom Error Code: $customErrorCode');
    }
    return buffer.toString();
  }
}
