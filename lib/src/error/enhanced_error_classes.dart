/// Enhanced Error Classes for Production-Ready Error Handling
///
/// This module provides specialized error classes that match the TypeScript
/// Anchor client with comprehensive error context and debugging information.
library;

import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/error/error_constants.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Enhanced Account Discriminator Mismatch Error with detailed context
class AccountDiscriminatorMismatchError extends AnchorError {
  /// Expected discriminator bytes
  final List<int> expected;

  /// Actual discriminator bytes found
  final List<int> actual;

  /// The account address where the mismatch occurred
  final PublicKey accountAddress;

  /// The expected account type name
  final String? expectedAccountType;

  /// The program ID that owns the account
  final PublicKey? programId;

  AccountDiscriminatorMismatchError({
    required this.expected,
    required this.actual,
    required this.accountAddress,
    this.expectedAccountType,
    this.programId,
    String? customMessage,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(
              code: 'AccountDiscriminatorMismatch',
              number: LangErrorCode.accountDiscriminatorMismatch,
            ),
            errorMessage: customMessage ??
                'Account discriminator did not match what was expected',
            origin: Origin.accountName(expectedAccountType ?? 'unknown'),
            comparedValues: ComparedValues.accountNames([
              expected.map((b) => b.toRadixString(16)).join(' '),
              actual.map((b) => b.toRadixString(16)).join(' '),
            ]),
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('AccountDiscriminatorMismatchError:');
    buffer.writeln('  Account: ${accountAddress.toBase58()}');
    buffer.writeln(
        '  Expected: ${expected.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    buffer.writeln(
        '  Actual: ${actual.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

    if (expectedAccountType != null) {
      buffer.writeln('  Expected Type: $expectedAccountType');
    }

    if (programId != null) {
      buffer.writeln('  Program ID: ${programId!.toBase58()}');
    }

    buffer.writeln('  Message: ${error.errorMessage}');

    if (logs.isNotEmpty) {
      buffer.writeln('  Logs:');
      for (final log in logs) {
        buffer.writeln('    $log');
      }
    }

    return buffer.toString();
  }
}

/// Enhanced Constraint Error with detailed constraint information
class ConstraintError extends AnchorError {
  /// The specific constraint that was violated
  final String constraintType;

  /// The account that violated the constraint
  final PublicKey violatingAccount;

  /// Expected value for the constraint
  final dynamic expectedValue;

  /// Actual value found
  final dynamic actualValue;

  /// Additional context about the constraint violation
  final Map<String, dynamic>? context;

  ConstraintError({
    required this.constraintType,
    required this.violatingAccount,
    required int errorCode,
    this.expectedValue,
    this.actualValue,
    this.context,
    String? customMessage,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(
              code: constraintType,
              number: errorCode,
            ),
            errorMessage: customMessage ??
                langErrorMessage[errorCode] ??
                'A $constraintType constraint was violated',
            origin: Origin.accountName(violatingAccount.toBase58()),
            comparedValues: (expectedValue != null && actualValue != null)
                ? ComparedValues.accountNames([
                    expectedValue.toString(),
                    actualValue.toString(),
                  ])
                : null,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ConstraintError ($constraintType):');
    buffer.writeln('  Account: ${violatingAccount.toBase58()}');
    buffer.writeln('  Message: ${error.errorMessage}');

    if (expectedValue != null && actualValue != null) {
      buffer.writeln('  Expected: $expectedValue');
      buffer.writeln('  Actual: $actualValue');
    }

    if (context != null && context!.isNotEmpty) {
      buffer.writeln('  Context:');
      for (final entry in context!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    if (logs.isNotEmpty) {
      buffer.writeln('  Logs:');
      for (final log in logs) {
        buffer.writeln('    $log');
      }
    }

    return buffer.toString();
  }
}

/// Enhanced Instruction Error with detailed instruction information
class InstructionError extends AnchorError {
  /// The instruction name that caused the error
  final String? instructionName;

  /// The program ID that owns the instruction
  final PublicKey programId;

  /// The instruction data (if available)
  final List<int>? instructionData;

  /// The accounts involved in the instruction
  final List<PublicKey>? accounts;

  /// Additional context about the instruction error
  final Map<String, dynamic>? context;

  InstructionError({
    required this.programId,
    required int errorCode,
    this.instructionName,
    this.instructionData,
    this.accounts,
    this.context,
    String? customMessage,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(
              code: 'InstructionError',
              number: errorCode,
            ),
            errorMessage: customMessage ??
                langErrorMessage[errorCode] ??
                'An instruction error occurred',
            origin: Origin.accountName(programId.toBase58()),
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('InstructionError:');
    buffer.writeln('  Program ID: ${programId.toBase58()}');
    buffer.writeln('  Message: ${error.errorMessage}');

    if (instructionName != null) {
      buffer.writeln('  Instruction: $instructionName');
    }

    if (instructionData != null) {
      buffer.writeln(
          '  Data: ${instructionData!.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    }

    if (accounts != null && accounts!.isNotEmpty) {
      buffer.writeln('  Accounts:');
      for (int i = 0; i < accounts!.length; i++) {
        buffer.writeln('    [$i]: ${accounts![i].toBase58()}');
      }
    }

    if (context != null && context!.isNotEmpty) {
      buffer.writeln('  Context:');
      for (final entry in context!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    if (logs.isNotEmpty) {
      buffer.writeln('  Logs:');
      for (final log in logs) {
        buffer.writeln('    $log');
      }
    }

    return buffer.toString();
  }
}

/// Enhanced Program Error with detailed program information
class EnhancedProgramError extends AnchorError {
  /// The program ID that caused the error
  final PublicKey programId;

  /// The program name (if available)
  final String? programName;

  /// The instruction that caused the error
  final String? instruction;

  /// Custom error code from the program
  final int? customErrorCode;

  /// Additional context about the program error
  final Map<String, dynamic>? context;

  EnhancedProgramError({
    required this.programId,
    required int errorCode,
    this.programName,
    this.instruction,
    this.customErrorCode,
    this.context,
    String? customMessage,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(
              code: 'ProgramError',
              number: errorCode,
            ),
            errorMessage: customMessage ??
                langErrorMessage[errorCode] ??
                'A program error occurred',
            origin: Origin.accountName(programId.toBase58()),
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('EnhancedProgramError:');
    buffer.writeln('  Program ID: ${programId.toBase58()}');
    buffer.writeln('  Message: ${error.errorMessage}');

    if (programName != null) {
      buffer.writeln('  Program: $programName');
    }

    if (instruction != null) {
      buffer.writeln('  Instruction: $instruction');
    }

    if (customErrorCode != null) {
      buffer.writeln('  Custom Error Code: $customErrorCode');
    }

    if (context != null && context!.isNotEmpty) {
      buffer.writeln('  Context:');
      for (final entry in context!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    if (logs.isNotEmpty) {
      buffer.writeln('  Logs:');
      for (final log in logs) {
        buffer.writeln('    $log');
      }
    }

    return buffer.toString();
  }
}

/// Enhanced IDL Error with detailed IDL information
class EnhancedIdlError extends AnchorError {
  /// The IDL field that caused the error
  final String? idlField;

  /// The IDL account type
  final String? accountType;

  /// The IDL instruction name
  final String? instructionName;

  /// Additional context about the IDL error
  final Map<String, dynamic>? context;

  EnhancedIdlError({
    required int errorCode,
    this.idlField,
    this.accountType,
    this.instructionName,
    this.context,
    String? customMessage,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(
              code: 'IdlError',
              number: errorCode,
            ),
            errorMessage: customMessage ??
                langErrorMessage[errorCode] ??
                'An IDL error occurred',
            origin: idlField != null ? Origin.accountName(idlField) : null,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('EnhancedIdlError:');
    buffer.writeln('  Message: ${error.errorMessage}');

    if (idlField != null) {
      buffer.writeln('  IDL Field: $idlField');
    }

    if (accountType != null) {
      buffer.writeln('  Account Type: $accountType');
    }

    if (instructionName != null) {
      buffer.writeln('  Instruction: $instructionName');
    }

    if (context != null && context!.isNotEmpty) {
      buffer.writeln('  Context:');
      for (final entry in context!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    if (logs.isNotEmpty) {
      buffer.writeln('  Logs:');
      for (final log in logs) {
        buffer.writeln('    $log');
      }
    }

    return buffer.toString();
  }
}

/// Enhanced Event Error with detailed event information
class EnhancedEventError extends AnchorError {
  /// The event name that caused the error
  final String? eventName;

  /// The program ID that owns the event
  final PublicKey? programId;

  /// The event data (if available)
  final List<int>? eventData;

  /// Additional context about the event error
  final Map<String, dynamic>? context;

  EnhancedEventError({
    required int errorCode,
    this.eventName,
    this.programId,
    this.eventData,
    this.context,
    String? customMessage,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(
              code: 'EventError',
              number: errorCode,
            ),
            errorMessage: customMessage ??
                langErrorMessage[errorCode] ??
                'An event error occurred',
            origin: programId != null
                ? Origin.accountName(programId.toBase58())
                : null,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('EnhancedEventError:');
    buffer.writeln('  Message: ${error.errorMessage}');

    if (eventName != null) {
      buffer.writeln('  Event: $eventName');
    }

    if (programId != null) {
      buffer.writeln('  Program ID: ${programId!.toBase58()}');
    }

    if (eventData != null) {
      buffer.writeln(
          '  Data: ${eventData!.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    }

    if (context != null && context!.isNotEmpty) {
      buffer.writeln('  Context:');
      for (final entry in context!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    if (logs.isNotEmpty) {
      buffer.writeln('  Logs:');
      for (final log in logs) {
        buffer.writeln('    $log');
      }
    }

    return buffer.toString();
  }
}

/// Factory class for creating enhanced error instances
class EnhancedErrorFactory {
  /// Create an AccountDiscriminatorMismatchError with context
  static AccountDiscriminatorMismatchError createAccountDiscriminatorMismatch({
    required List<int> expected,
    required List<int> actual,
    required PublicKey accountAddress,
    String? expectedAccountType,
    PublicKey? programId,
    List<String>? logs,
  }) {
    return AccountDiscriminatorMismatchError(
      expected: expected,
      actual: actual,
      accountAddress: accountAddress,
      expectedAccountType: expectedAccountType,
      programId: programId,
      logs: logs,
    );
  }

  /// Create a ConstraintError with context
  static ConstraintError createConstraintError({
    required String constraintType,
    required PublicKey violatingAccount,
    required int errorCode,
    dynamic expectedValue,
    dynamic actualValue,
    Map<String, dynamic>? context,
    List<String>? logs,
  }) {
    return ConstraintError(
      constraintType: constraintType,
      violatingAccount: violatingAccount,
      errorCode: errorCode,
      expectedValue: expectedValue,
      actualValue: actualValue,
      context: context,
      logs: logs,
    );
  }

  /// Create an InstructionError with context
  static InstructionError createInstructionError({
    required PublicKey programId,
    required int errorCode,
    String? instructionName,
    List<int>? instructionData,
    List<PublicKey>? accounts,
    Map<String, dynamic>? context,
    List<String>? logs,
  }) {
    return InstructionError(
      programId: programId,
      errorCode: errorCode,
      instructionName: instructionName,
      instructionData: instructionData,
      accounts: accounts,
      context: context,
      logs: logs,
    );
  }

  /// Create an EnhancedProgramError with context
  static EnhancedProgramError createProgramError({
    required PublicKey programId,
    required int errorCode,
    String? programName,
    String? instruction,
    int? customErrorCode,
    Map<String, dynamic>? context,
    List<String>? logs,
  }) {
    return EnhancedProgramError(
      programId: programId,
      errorCode: errorCode,
      programName: programName,
      instruction: instruction,
      customErrorCode: customErrorCode,
      context: context,
      logs: logs,
    );
  }

  /// Create an EnhancedIdlError with context
  static EnhancedIdlError createIdlError({
    required int errorCode,
    String? idlField,
    String? accountType,
    String? instructionName,
    Map<String, dynamic>? context,
    List<String>? logs,
  }) {
    return EnhancedIdlError(
      errorCode: errorCode,
      idlField: idlField,
      accountType: accountType,
      instructionName: instructionName,
      context: context,
      logs: logs,
    );
  }

  /// Create an EnhancedEventError with context
  static EnhancedEventError createEventError({
    required int errorCode,
    String? eventName,
    PublicKey? programId,
    List<int>? eventData,
    Map<String, dynamic>? context,
    List<String>? logs,
  }) {
    return EnhancedEventError(
      errorCode: errorCode,
      eventName: eventName,
      programId: programId,
      eventData: eventData,
      context: context,
      logs: logs,
    );
  }
}
