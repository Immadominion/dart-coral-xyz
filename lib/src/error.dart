/// Comprehensive error handling for Anchor programs
///
/// This module provides robust error parsing and representation matching
/// the TypeScript Anchor SDK error handling capabilities.
library;

import 'types/public_key.dart';
import 'idl/idl.dart';

/// Base exception class for IDL-related errors
class IdlError extends Error {
  final String message;

  IdlError(this.message);

  @override
  String toString() => 'IdlError: $message';
}

/// Represents an error code with both string and numeric representations
class ErrorCode {
  final String code;
  final int number;

  const ErrorCode({
    required this.code,
    required this.number,
  });

  @override
  String toString() => '$code ($number)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorCode && other.code == code && other.number == number;
  }

  @override
  int get hashCode => code.hashCode ^ number.hashCode;
}

/// Represents a file and line location for error reporting
class FileLine {
  final String file;
  final int line;

  const FileLine({
    required this.file,
    required this.line,
  });

  @override
  String toString() => '$file:$line';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileLine && other.file == file && other.line == line;
  }

  @override
  int get hashCode => file.hashCode ^ line.hashCode;
}

/// Union type for error origin (either string account name or file location)
class ErrorOrigin {
  final String? accountName;
  final FileLine? fileLine;

  const ErrorOrigin.accountName(String this.accountName) : fileLine = null;
  const ErrorOrigin.fileLine(FileLine this.fileLine) : accountName = null;

  @override
  String toString() {
    if (accountName != null) return accountName!;
    if (fileLine != null) return fileLine.toString();
    return 'unknown';
  }
}

/// Union type for compared values in error messages
class ComparedValues {
  final List<PublicKey>? publicKeys;
  final List<String>? accountNames;

  const ComparedValues.publicKeys(List<PublicKey> this.publicKeys)
      : accountNames = null;
  const ComparedValues.accountNames(List<String> this.accountNames)
      : publicKeys = null;

  @override
  String toString() {
    if (publicKeys != null) {
      return 'Left: ${publicKeys![0]}, Right: ${publicKeys![1]}';
    }
    if (accountNames != null) {
      return 'Left: ${accountNames![0]}, Right: ${accountNames![1]}';
    }
    return '';
  }
}

/// Stack of programs being executed, used for tracking CPI calls
class ProgramErrorStack {
  final List<PublicKey> stack;

  const ProgramErrorStack(this.stack);

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

  /// Get the currently executing program
  PublicKey? get currentProgram => stack.isNotEmpty ? stack.last : null;

  @override
  String toString() => stack.map((p) => p.toBase58()).join(' -> ');
}

/// Detailed Anchor error with full context
class AnchorError extends Error {
  final ErrorCode errorCode;
  final String errorMessage;
  final List<String> errorLogs;
  final List<String> logs;
  final ErrorOrigin? origin;
  final ComparedValues? comparedValues;
  final ProgramErrorStack _programErrorStack;

  AnchorError({
    required this.errorCode,
    required this.errorMessage,
    required this.errorLogs,
    required this.logs,
    this.origin,
    this.comparedValues,
  }) : _programErrorStack = ProgramErrorStack.parse(logs);

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
      // Pattern: Left: / Right: with pubkeys
      if (logs[anchorErrorLogIndex + 1] == 'Program log: Left:') {
        final pubkeyRegex = RegExp(r'^Program log: (.*)$');
        final leftMatch = pubkeyRegex.firstMatch(logs[anchorErrorLogIndex + 2]);
        final rightMatch =
            pubkeyRegex.firstMatch(logs[anchorErrorLogIndex + 4]);

        if (leftMatch != null && rightMatch != null) {
          try {
            final leftPubkey = PublicKey.fromBase58(leftMatch.group(1)!);
            final rightPubkey = PublicKey.fromBase58(rightMatch.group(1)!);
            comparedValues =
                ComparedValues.publicKeys([leftPubkey, rightPubkey]);
            errorLogs.addAll(logs.sublist(
              anchorErrorLogIndex + 1,
              anchorErrorLogIndex + 5,
            ));
          } catch (e) {
            // Not valid pubkeys, ignore
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
          comparedValues = ComparedValues.accountNames([leftValue, rightValue]);
          errorLogs.addAll(logs.sublist(
            anchorErrorLogIndex + 1,
            anchorErrorLogIndex + 3,
          ));
        }
      }
    }

    // Parse different error formats
    final regexNoInfo = RegExp(
      r'^Program log: AnchorError occurred\. Error Code: (.*)\. Error Number: (\d+)\. Error Message: (.*)\.?$',
    );
    final regexFileLine = RegExp(
      r'^Program log: AnchorError thrown in (.*):(\d+)\. Error Code: (.*)\. Error Number: (\d+)\. Error Message: (.*)\.?$',
    );
    final regexAccountName = RegExp(
      r'^Program log: AnchorError caused by account: (.*)\. Error Code: (.*)\. Error Number: (\d+)\. Error Message: (.*)\.?$',
    );

    final noInfoMatch = regexNoInfo.firstMatch(anchorErrorLog);
    final fileLineMatch = regexFileLine.firstMatch(anchorErrorLog);
    final accountNameMatch = regexAccountName.firstMatch(anchorErrorLog);

    if (noInfoMatch != null) {
      final errorCodeString = noInfoMatch.group(1)!;
      final errorNumber = int.parse(noInfoMatch.group(2)!);
      final errorMessage = noInfoMatch.group(3)!;

      return AnchorError(
        errorCode: ErrorCode(code: errorCodeString, number: errorNumber),
        errorMessage: errorMessage,
        errorLogs: errorLogs,
        logs: logs,
        comparedValues: comparedValues,
      );
    } else if (fileLineMatch != null) {
      final file = fileLineMatch.group(1)!;
      final line = int.parse(fileLineMatch.group(2)!);
      final errorCodeString = fileLineMatch.group(3)!;
      final errorNumber = int.parse(fileLineMatch.group(4)!);
      final errorMessage = fileLineMatch.group(5)!;

      return AnchorError(
        errorCode: ErrorCode(code: errorCodeString, number: errorNumber),
        errorMessage: errorMessage,
        errorLogs: errorLogs,
        logs: logs,
        origin: ErrorOrigin.fileLine(FileLine(file: file, line: line)),
        comparedValues: comparedValues,
      );
    } else if (accountNameMatch != null) {
      final accountName = accountNameMatch.group(1)!;
      final errorCodeString = accountNameMatch.group(2)!;
      final errorNumber = int.parse(accountNameMatch.group(3)!);
      final errorMessage = accountNameMatch.group(4)!;

      return AnchorError(
        errorCode: ErrorCode(code: errorCodeString, number: errorNumber),
        errorMessage: errorMessage,
        errorLogs: errorLogs,
        logs: logs,
        origin: ErrorOrigin.accountName(accountName),
        comparedValues: comparedValues,
      );
    }

    return null;
  }

  /// Get the program that threw this error
  PublicKey? get program => _programErrorStack.currentProgram;

  /// Get the full program execution stack
  List<PublicKey> get programErrorStack => _programErrorStack.stack;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('AnchorError: $errorMessage');

    if (origin != null) {
      buffer.write(' (Origin: $origin)');
    }

    if (comparedValues != null) {
      buffer.write(' ($comparedValues)');
    }

    buffer.write(' [${errorCode.code}:${errorCode.number}]');

    return buffer.toString();
  }
}

/// User-defined or framework program error
class ProgramError extends Error {
  final int code;
  final String message;
  final List<String>? logs;
  final ProgramErrorStack? _programErrorStack;

  ProgramError({
    required this.code,
    required this.message,
    this.logs,
  }) : _programErrorStack = logs != null ? ProgramErrorStack.parse(logs) : null;

  /// Parse ProgramError from exception and IDL error definitions
  static ProgramError? parse(
    dynamic err,
    Map<int, String> idlErrors,
  ) {
    final errString = err.toString();
    String? unparsedErrorCode;

    // Parse custom program error format
    if (errString.contains('custom program error:')) {
      final components = errString.split('custom program error: ');
      if (components.length == 2) {
        unparsedErrorCode = components[1].trim();
      }
    } else {
      // Parse JSON format: {"Custom":123}
      final regex = RegExp(r'"Custom":(\d+)');
      final match = regex.firstMatch(errString);
      if (match != null) {
        unparsedErrorCode = match.group(1);
      }
    }

    if (unparsedErrorCode == null) return null;

    int errorCode;
    try {
      errorCode = int.parse(unparsedErrorCode);
    } catch (e) {
      return null;
    }

    // Look up error message in IDL errors first
    String? errorMsg = idlErrors[errorCode];
    if (errorMsg != null) {
      return ProgramError(
        code: errorCode,
        message: errorMsg,
        logs: err.logs as List<String>?,
      );
    }

    // Fall back to framework error messages
    errorMsg = LangErrorMessage.langErrorMessages[errorCode];
    if (errorMsg != null) {
      return ProgramError(
        code: errorCode,
        message: errorMsg,
        logs: err.logs as List<String>?,
      );
    }

    return null;
  }

  /// Get the program that threw this error
  PublicKey? get program => _programErrorStack?.currentProgram;

  /// Get the full program execution stack
  List<PublicKey>? get programErrorStack => _programErrorStack?.stack;

  @override
  String toString() => '$message [Error Code: $code]';
}

/// Main error translation function
dynamic translateError(dynamic err, Map<int, String> idlErrors) {
  // Try to parse as AnchorError first
  if (err.logs != null) {
    final anchorError = AnchorError.parse(err.logs as List<String>);
    if (anchorError != null) {
      return anchorError;
    }
  }

  // Try to parse as ProgramError
  final programError = ProgramError.parse(err, idlErrors);
  if (programError != null) {
    return programError;
  }

  // If the error has logs, add program error stack information
  if (err.logs != null) {
    final programErrorStack = ProgramErrorStack.parse(err.logs as List<String>);
    // Add program error stack as additional context
    err.programErrorStack = programErrorStack;
    err.program = programErrorStack.currentProgram;
  }

  return err;
}

/// Anchor framework error codes and messages
class LangErrorMessage {
  // Framework error codes (matching TypeScript SDK)
  static const int instructionMissing = 100;
  static const int instructionFallbackNotFound = 101;
  static const int instructionDidNotDeserialize = 102;
  static const int instructionDidNotSerialize = 103;

  static const int idlInstructionStub = 1000;
  static const int idlInstructionInvalidProgram = 1001;
  static const int idlAccountNotEmpty = 1002;

  static const int eventInstructionStub = 1500;

  static const int constraintMut = 2000;
  static const int constraintHasOne = 2001;
  static const int constraintSigner = 2002;
  static const int constraintRaw = 2003;
  static const int constraintOwner = 2004;
  static const int constraintRentExempt = 2005;
  static const int constraintSeeds = 2006;
  static const int constraintExecutable = 2007;
  static const int constraintState = 2008;
  static const int constraintAssociated = 2009;
  static const int constraintAssociatedInit = 2010;
  static const int constraintClose = 2011;
  static const int constraintAddress = 2012;
  static const int constraintZero = 2013;
  static const int constraintTokenMint = 2014;
  static const int constraintTokenOwner = 2015;
  static const int constraintMintMintAuthority = 2016;
  static const int constraintMintFreezeAuthority = 2017;
  static const int constraintMintDecimals = 2018;
  static const int constraintSpace = 2019;

  static const int requireViolated = 2500;
  static const int requireEqViolated = 2501;
  static const int requireKeysEqViolated = 2502;
  static const int requireNeqViolated = 2503;
  static const int requireKeysNeqViolated = 2504;
  static const int requireGtViolated = 2505;
  static const int requireGteViolated = 2506;

  static const int accountDiscriminatorAlreadySet = 3000;
  static const int accountDiscriminatorNotFound = 3001;
  static const int accountDiscriminatorMismatch = 3002;
  static const int accountDidNotDeserialize = 3003;
  static const int accountDidNotSerialize = 3004;
  static const int accountNotEnoughKeys = 3005;
  static const int accountNotMutable = 3006;
  static const int accountOwnedByWrongProgram = 3007;
  static const int invalidProgramId = 3008;
  static const int invalidProgramExecutable = 3009;
  static const int accountNotSigner = 3010;
  static const int accountNotSystemOwned = 3011;
  static const int accountNotInitialized = 3012;
  static const int accountNotProgramData = 3013;
  static const int accountNotAssociatedTokenAccount = 3014;
  static const int accountSysvarMismatch = 3015;
  static const int accountReallocExceedsLimit = 3016;
  static const int accountDuplicateReallocs = 3017;

  static const int declaredProgramIdMismatch = 4100;
  static const int tryingToInitPayerAsProgramAccount = 4101;
  static const int invalidNumericConversion = 4102;

  static const int deprecated = 5000;

  /// Map of error codes to their human-readable messages
  static const Map<int, String> langErrorMessages = {
    // Instructions
    instructionMissing: 'Instruction discriminator not provided',
    instructionFallbackNotFound: 'Fallback functions are not supported',
    instructionDidNotDeserialize:
        'The program could not deserialize the given instruction',
    instructionDidNotSerialize:
        'The program could not serialize the given instruction',

    // IDL instructions
    idlInstructionStub: 'The program was compiled without idl instructions',
    idlInstructionInvalidProgram:
        'The transaction was given an invalid program for the IDL instruction',
    idlAccountNotEmpty:
        'IDL account must be empty in order to resize, try closing first',

    // Event instructions
    eventInstructionStub:
        'The program was compiled without `event-cpi` feature',

    // Constraints
    constraintMut: 'A mut constraint was violated',
    constraintHasOne: 'A has one constraint was violated',
    constraintSigner: 'A signer constraint was violated',
    constraintRaw: 'A raw constraint was violated',
    constraintOwner: 'An owner constraint was violated',
    constraintRentExempt: 'A rent exemption constraint was violated',
    constraintSeeds: 'A seeds constraint was violated',
    constraintExecutable: 'An executable constraint was violated',
    constraintState:
        'Deprecated Error, feel free to replace with something else',
    constraintAssociated: 'An associated constraint was violated',
    constraintAssociatedInit: 'An associated init constraint was violated',
    constraintClose: 'A close constraint was violated',
    constraintAddress: 'An address constraint was violated',
    constraintZero: 'Expected zero account discriminant',
    constraintTokenMint: 'A token mint constraint was violated',
    constraintTokenOwner: 'A token owner constraint was violated',
    constraintMintMintAuthority:
        'A mint mint authority constraint was violated',
    constraintMintFreezeAuthority:
        'A mint freeze authority constraint was violated',
    constraintMintDecimals: 'A mint decimals constraint was violated',
    constraintSpace: 'A space constraint was violated',

    // Require
    requireViolated: 'A require expression was violated',
    requireEqViolated: 'A require_eq expression was violated',
    requireKeysEqViolated: 'A require_keys_eq expression was violated',
    requireNeqViolated: 'A require_neq expression was violated',
    requireKeysNeqViolated: 'A require_keys_neq expression was violated',
    requireGtViolated: 'A require_gt expression was violated',
    requireGteViolated: 'A require_gte expression was violated',

    // Accounts
    accountDiscriminatorAlreadySet:
        'The account discriminator was already set on this account',
    accountDiscriminatorNotFound: 'No discriminator was found on the account',
    accountDiscriminatorMismatch:
        'Account discriminator did not match what was expected',
    accountDidNotDeserialize: 'Failed to deserialize the account',
    accountDidNotSerialize: 'Failed to serialize the account',
    accountNotEnoughKeys: 'Not enough account keys given to the instruction',
    accountNotMutable: 'The given account is not mutable',
    accountOwnedByWrongProgram:
        'The given account is owned by a different program than expected',
    invalidProgramId: 'Program ID was not as expected',
    invalidProgramExecutable: 'Program account is not executable',
    accountNotSigner: 'The given account did not sign',
    accountNotSystemOwned:
        'The given account is not owned by the system program',
    accountNotInitialized:
        'The program expected this account to be already initialized',
    accountNotProgramData: 'The given account is not a program data account',
    accountNotAssociatedTokenAccount:
        'The given account is not the associated token account',
    accountSysvarMismatch:
        'The given public key does not match the required sysvar',
    accountReallocExceedsLimit:
        'The account reallocation exceeds the MAX_PERMITTED_DATA_INCREASE limit',
    accountDuplicateReallocs:
        'The account was duplicated for more than one reallocation',

    // Miscellaneous
    declaredProgramIdMismatch:
        'The declared program id does not match the actual program id',
    tryingToInitPayerAsProgramAccount:
        'You cannot/should not initialize the payer account as a program account',
    invalidNumericConversion:
        'The program could not perform the numeric conversion, out of range integral type conversion attempted',

    // Deprecated
    deprecated: 'The API being used is deprecated and should no longer be used',
  };
}

/// Helper function to create IDL error map from IDL
Map<int, String> createIdlErrorMap(Idl idl) {
  final errorMap = <int, String>{};

  if (idl.errors != null) {
    for (final error in idl.errors!) {
      if (error.msg != null) {
        errorMap[error.code] = error.msg!;
      }
    }
  }

  return errorMap;
}
