/// Error Validation and Testing Utilities for Production-Ready Error Handling
///
/// This module provides comprehensive error validation, testing utilities,
/// and debugging tools for the error handling system.
library;

import 'dart:math';
import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/error/error_context.dart';
import 'package:coral_xyz_anchor/src/error/error_constants.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/utils/logger.dart';

/// Error validation result
class ErrorValidationResult {
  /// Create error validation result
  const ErrorValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });

  /// Whether the error is valid
  final bool isValid;

  /// Validation errors
  final List<String> errors;

  /// Validation warnings
  final List<String> warnings;

  /// Improvement suggestions
  final List<String> suggestions;

  /// Check if there are any issues
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Error Validation Result:');
    buffer.writeln('  Valid: $isValid');

    if (errors.isNotEmpty) {
      buffer.writeln('  Errors:');
      for (final error in errors) {
        buffer.writeln('    - $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('  Warnings:');
      for (final warning in warnings) {
        buffer.writeln('    - $warning');
      }
    }

    if (suggestions.isNotEmpty) {
      buffer.writeln('  Suggestions:');
      for (final suggestion in suggestions) {
        buffer.writeln('    - $suggestion');
      }
    }

    return buffer.toString();
  }
}

/// Error validator for comprehensive error validation
class ErrorValidator {
  /// Create error validator
  const ErrorValidator({
    this.logger,
  });

  /// Logger instance
  final AnchorLogger? logger;

  /// Validate an AnchorError
  ErrorValidationResult validateAnchorError(AnchorError error) {
    final errors = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];

    // Validate error code
    final errorCode = error.error.errorCode;
    if (errorCode.number < 0) {
      errors.add('Error code number cannot be negative: ${errorCode.number}');
    }

    if (errorCode.code.isEmpty) {
      errors.add('Error code string cannot be empty');
    }

    // Validate error message
    if (error.error.errorMessage.isEmpty) {
      errors.add('Error message cannot be empty');
    } else if (error.error.errorMessage.length < 10) {
      warnings
          .add('Error message is very short: "${error.error.errorMessage}"');
      suggestions.add('Consider providing more descriptive error messages');
    }

    // Validate error code ranges
    _validateErrorCodeRange(errorCode.number, errors, warnings, suggestions);

    // Validate logs
    if (error.logs.isEmpty) {
      warnings.add('No transaction logs provided');
      suggestions.add('Include transaction logs for better debugging');
    }

    // Validate program error stack
    if (error.programErrorStack.isEmpty) {
      warnings.add('No program error stack found');
      suggestions.add(
          'Ensure transaction logs contain program invocation information');
    }

    // Check for compared values consistency
    if (error.error.comparedValues != null) {
      _validateComparedValues(error.error.comparedValues!, errors, warnings);
    }

    return ErrorValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Validate error context
  ErrorValidationResult validateErrorContext(ErrorContext context) {
    final errors = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];

    // Validate operation
    if (context.operation.isEmpty) {
      errors.add('Operation name cannot be empty');
    }

    // Validate timestamp
    final now = DateTime.now();
    if (context.timestamp.isAfter(now)) {
      errors.add('Error timestamp cannot be in the future');
    }

    if (now.difference(context.timestamp).inDays > 30) {
      warnings.add(
          'Error timestamp is very old (${now.difference(context.timestamp).inDays} days)');
    }

    // Validate account addresses
    if (context.accountAddresses != null) {
      for (final address in context.accountAddresses!) {
        if (!_isValidPublicKey(address)) {
          errors.add('Invalid account address: ${address.toBase58()}');
        }
      }
    }

    // Validate instruction index
    if (context.instructionIndex != null && context.instructionIndex! < 0) {
      errors.add(
          'Instruction index cannot be negative: ${context.instructionIndex}');
    }

    return ErrorValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Validate error code range
  void _validateErrorCodeRange(
    int errorCode,
    List<String> errors,
    List<String> warnings,
    List<String> suggestions,
  ) {
    if (errorCode >= 100 && errorCode < 1000) {
      // Instruction errors - validate against known codes
      if (!_isKnownInstructionError(errorCode)) {
        warnings.add('Unknown instruction error code: $errorCode');
        suggestions.add('Verify error code matches Anchor framework constants');
      }
    } else if (errorCode >= 1000 && errorCode < 2000) {
      // IDL errors
      if (!_isKnownIdlError(errorCode)) {
        warnings.add('Unknown IDL error code: $errorCode');
      }
    } else if (errorCode >= 2000 && errorCode < 3000) {
      // Constraint errors
      if (!_isKnownConstraintError(errorCode)) {
        warnings.add('Unknown constraint error code: $errorCode');
      }
    } else if (errorCode >= 3000 && errorCode < 4000) {
      // Account errors
      if (!_isKnownAccountError(errorCode)) {
        warnings.add('Unknown account error code: $errorCode');
      }
    } else if (errorCode >= 6000) {
      // Custom program errors - no validation needed
    } else {
      warnings.add('Error code $errorCode does not follow Anchor conventions');
      suggestions.add(
          'Use error codes in standard ranges: 100-999 (instruction), 1000-1999 (IDL), 2000-2999 (constraint), 3000-3999 (account), 6000+ (custom)');
    }
  }

  /// Validate compared values
  void _validateComparedValues(
    ComparedValues comparedValues,
    List<String> errors,
    List<String> warnings,
  ) {
    if (comparedValues is ComparedPublicKeys) {
      final publicKeys = comparedValues.publicKeys;
      if (publicKeys != null && publicKeys.length >= 2) {
        if (!_isValidPublicKey(publicKeys[0])) {
          errors.add('Invalid left public key in comparison');
        }
        if (!_isValidPublicKey(publicKeys[1])) {
          errors.add('Invalid right public key in comparison');
        }
        if (publicKeys[0] == publicKeys[1]) {
          warnings.add('Compared public keys are identical');
        }
      }
    }
  }

  /// Check if public key is valid
  bool _isValidPublicKey(PublicKey key) {
    try {
      // Basic validation - check if it can be converted to base58
      final base58 = key.toBase58();
      return base58.length == 44; // Standard Solana address length
    } catch (e) {
      return false;
    }
  }

  /// Check if error code is a known instruction error
  bool _isKnownInstructionError(int code) {
    return code == InstructionErrorCode.instructionMissing ||
        code == InstructionErrorCode.instructionFallbackNotFound ||
        code == InstructionErrorCode.instructionDidNotDeserialize ||
        code == InstructionErrorCode.instructionDidNotSerialize;
  }

  /// Check if error code is a known IDL error
  bool _isKnownIdlError(int code) {
    return code >= IdlInstructionErrorCode.idlInstructionMissing &&
        code <= IdlInstructionErrorCode.idlInstructionInvalidData;
  }

  /// Check if error code is a known constraint error
  bool _isKnownConstraintError(int code) {
    return code >= ConstraintErrorCode.constraintMut &&
        code <= ConstraintErrorCode.constraintTokenOwner;
  }

  /// Check if error code is a known account error
  bool _isKnownAccountError(int code) {
    return code >= AccountErrorCode.accountDiscriminatorAlreadySet &&
        code <= AccountErrorCode.accountNotAssociatedTokenAccount;
  }
}

/// Error testing utilities
class ErrorTestUtils {
  /// Create a mock AnchorError for testing
  static AnchorError createMockAnchorError({
    String errorCode = 'TestError',
    int errorNumber = 6000,
    String message = 'Test error message',
    List<String>? logs,
    PublicKey? programId,
  }) {
    final testLogs = logs ??
        [
          'Program ${programId?.toBase58() ?? '11111111111111111111111111111111'} invoke [1]',
          'Program log: AnchorError occurred. Error Code: $errorCode. Error Number: $errorNumber. Error Message: $message.',
          'Program ${programId?.toBase58() ?? '11111111111111111111111111111111'} failed: custom program error: 0x${errorNumber.toRadixString(16)}',
        ];

    return AnchorError(
      error: ErrorInfo(
        errorCode: ErrorCode(code: errorCode, number: errorNumber),
        errorMessage: message,
      ),
      errorLogs: [testLogs[1]],
      logs: testLogs,
    );
  }

  /// Create a mock ErrorContext for testing
  static ErrorContext createMockErrorContext({
    String operation = 'test_operation',
    DateTime? timestamp,
    PublicKey? programId,
    List<PublicKey>? accountAddresses,
  }) {
    return ErrorContext(
      operation: operation,
      timestamp: timestamp ?? DateTime.now(),
      programId: programId,
      accountAddresses: accountAddresses,
      environment: 'test',
    );
  }

  /// Create a random PublicKey for testing
  static PublicKey createRandomPublicKey() {
    final random = Random();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return PublicKey.fromBytes(bytes);
  }

  /// Create a test error with specific error code
  static AnchorError createErrorWithCode(int errorCode) {
    String errorCodeString;
    String message;

    if (errorCode >= 100 && errorCode < 1000) {
      errorCodeString = 'InstructionError';
      message = 'Test instruction error';
    } else if (errorCode >= 1000 && errorCode < 2000) {
      errorCodeString = 'IdlError';
      message = 'Test IDL error';
    } else if (errorCode >= 2000 && errorCode < 3000) {
      errorCodeString = 'ConstraintError';
      message = 'Test constraint error';
    } else if (errorCode >= 3000 && errorCode < 4000) {
      errorCodeString = 'AccountError';
      message = 'Test account error';
    } else {
      errorCodeString = 'CustomError';
      message = 'Test custom error';
    }

    return createMockAnchorError(
      errorCode: errorCodeString,
      errorNumber: errorCode,
      message: message,
    );
  }

  /// Test error serialization and deserialization
  static bool testErrorSerialization(AnchorError error) {
    try {
      final json = error.toJson();
      final restored = AnchorError.fromJson(json);

      return error.error.errorCode == restored.error.errorCode &&
          error.error.errorMessage == restored.error.errorMessage &&
          error.errorLogs.length == restored.errorLogs.length &&
          error.logs.length == restored.logs.length;
    } catch (e) {
      return false;
    }
  }
}

/// Error debugging utilities
class ErrorDebugUtils {
  /// Create error debug utilities
  const ErrorDebugUtils({
    this.logger,
  });

  /// Logger instance
  final AnchorLogger? logger;

  /// Debug an AnchorError with comprehensive analysis
  void debugError(AnchorError error) {
    final logger = this.logger ?? AnchorLoggers.error;

    logger.debug('=== ERROR DEBUG ANALYSIS ===');
    logger.debug(
        'Error Code: ${error.error.errorCode.code} (${error.error.errorCode.number})');
    logger.debug('Error Message: ${error.error.errorMessage}');

    // Analyze error category
    final category = ErrorHandlingUtils.categorizeError(error);
    logger.debug('Error Category: ${category.name}');

    // Analyze severity
    final severity = ErrorHandlingUtils.determineSeverity(error, null);
    logger.debug('Error Severity: ${severity.name}');

    // Analyze program stack
    if (error.programErrorStack.isNotEmpty) {
      logger.debug('Program Stack:');
      for (int i = 0; i < error.programErrorStack.length; i++) {
        logger.debug('  [$i] ${error.programErrorStack[i].toBase58()}');
      }
    } else {
      logger.debug('No program stack available');
    }

    // Analyze logs
    logger.debug('Transaction Logs (${error.logs.length} entries):');
    for (int i = 0; i < error.logs.length; i++) {
      logger.debug('  [$i] ${error.logs[i]}');
    }

    // Analyze compared values
    if (error.error.comparedValues != null) {
      logger.debug('Compared Values: ${error.error.comparedValues}');
    }

    // Suggest fixes
    final suggestions = _generateErrorSuggestions(error);
    if (suggestions.isNotEmpty) {
      logger.debug('Suggestions:');
      for (final suggestion in suggestions) {
        logger.debug('  - $suggestion');
      }
    }

    logger.debug('=== END ERROR DEBUG ===');
  }

  /// Generate suggestions for fixing errors
  List<String> _generateErrorSuggestions(AnchorError error) {
    final suggestions = <String>[];
    final errorCode = error.error.errorCode.number;

    if (errorCode >= 3000 && errorCode < 4000) {
      // Account errors
      suggestions.add('Check account initialization and ownership');
      suggestions.add('Verify account discriminators match expected types');
      suggestions.add('Ensure accounts are properly funded');
    } else if (errorCode >= 2000 && errorCode < 3000) {
      // Constraint errors
      suggestions.add('Review account constraints in your program');
      suggestions.add('Check account mutability requirements');
      suggestions.add('Verify signer requirements');
    } else if (errorCode >= 1000 && errorCode < 2000) {
      // IDL errors
      suggestions.add('Verify IDL matches deployed program');
      suggestions.add('Check instruction serialization format');
    } else if (errorCode >= 100 && errorCode < 1000) {
      // Instruction errors
      suggestions.add('Check instruction discriminator');
      suggestions.add('Verify instruction data format');
    }

    // Generic suggestions
    if (error.logs.isEmpty) {
      suggestions.add('Include transaction logs for better debugging');
    }

    if (error.programErrorStack.isEmpty) {
      suggestions.add('Ensure program invocation logs are captured');
    }

    return suggestions;
  }

  /// Format error for console output
  String formatErrorForConsole(AnchorError error) {
    final buffer = StringBuffer();
    buffer.writeln('┌─ Anchor Error ─────────────────────────────────────────');
    buffer.writeln(
        '│ Code: ${error.error.errorCode.code} (${error.error.errorCode.number})');
    buffer.writeln('│ Message: ${error.error.errorMessage}');

    if (error.programErrorStack.isNotEmpty) {
      buffer.writeln('│ Program: ${error.program.toBase58()}');
    }

    if (error.error.origin != null) {
      buffer.writeln('│ Origin: ${error.error.origin}');
    }

    buffer.writeln('├─ Logs ─────────────────────────────────────────────────');
    for (int i = 0; i < error.logs.length && i < 10; i++) {
      buffer.writeln('│ $i: ${error.logs[i]}');
    }

    if (error.logs.length > 10) {
      buffer.writeln('│ ... ${error.logs.length - 10} more logs');
    }

    buffer
        .writeln('└─────────────────────────────────────────────────────────');

    return buffer.toString();
  }
}

/// Global error validator instance
const globalErrorValidator = ErrorValidator();

/// Global error debug utilities
const globalErrorDebugUtils = ErrorDebugUtils();
