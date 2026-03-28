/// Account-Specific Error Types
///
/// This module implements specific account-related error types with exact error code
/// and message matching to TypeScript implementation, providing detailed context
/// and debugging information for account validation failures.
library;

import 'package:coral_xyz/src/error/anchor_error.dart';
import 'package:coral_xyz/src/error/error_constants.dart';
import 'package:coral_xyz/src/types/public_key.dart';

/// Base class for all account-specific errors
abstract class AccountError extends AnchorError {
  AccountError({
    required ErrorCode errorCode,
    required String errorMessage,
    required super.errorLogs,
    required super.logs,
    this.accountAddress,
    this.accountName,
    Origin? origin,
    ComparedValues? comparedValues,
  }) : super(
         error: ErrorInfo(
           errorCode: errorCode,
           errorMessage: errorMessage,
           origin: origin,
           comparedValues: comparedValues,
         ),
       );

  /// The account address associated with the error
  final PublicKey? accountAddress;

  /// The account name from IDL (if known)
  final String? accountName;

  /// Get formatted account context for error messages
  String get accountContext {
    if (accountName != null && accountAddress != null) {
      return 'account $accountName ($accountAddress)';
    } else if (accountName != null) {
      return 'account $accountName';
    } else if (accountAddress != null) {
      return 'account $accountAddress';
    } else {
      return 'account';
    }
  }
}

/// Account discriminator mismatch error (3002)
class AccountDiscriminatorMismatchError extends AccountError {
  AccountDiscriminatorMismatchError({
    required this.expectedDiscriminator,
    required this.actualDiscriminator,
    required super.errorLogs,
    required super.logs,
    super.accountAddress,
    super.accountName,
    super.origin,
  }) : super(
         errorCode: const ErrorCode(
           code: 'AccountDiscriminatorMismatch',
           number: LangErrorCode.accountDiscriminatorMismatch,
         ),
         errorMessage: getErrorMessage(
           LangErrorCode.accountDiscriminatorMismatch,
         ),
       );

  /// Create from discriminator comparison
  factory AccountDiscriminatorMismatchError.fromComparison({
    required List<int> expected,
    required List<int> actual,
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) => AccountDiscriminatorMismatchError(
    expectedDiscriminator: expected,
    actualDiscriminator: actual,
    errorLogs: errorLogs,
    logs: logs,
    accountAddress: accountAddress,
    accountName: accountName,
    origin: origin,
  );

  /// Expected discriminator bytes
  final List<int> expectedDiscriminator;

  /// Actual discriminator bytes found
  final List<int> actualDiscriminator;

  /// Get hex representation of discriminators for debugging
  String get expectedHex => expectedDiscriminator
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();

  String get actualHex => actualDiscriminator
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();

  @override
  String toString() {
    final buffer = StringBuffer();

    if (accountName != null) {
      buffer.write('AnchorError caused by account: $accountName. ');
    } else if (error.origin is AccountNameOrigin) {
      final accountName = (error.origin as AccountNameOrigin).accountName;
      buffer.write('AnchorError caused by account: $accountName. ');
    } else {
      buffer.write('AnchorError occurred. ');
    }

    buffer.write('Error Code: ${error.errorCode.code}. ');
    buffer.write('Error Number: ${error.errorCode.number}. ');
    buffer.write('Error Message: ${error.errorMessage}. ');
    buffer.write('Expected discriminator: $expectedHex, ');
    buffer.write('Actual discriminator: $actualHex');

    return buffer.toString();
  }
}

/// Account not initialized error (3012)
class AccountNotInitializedError extends AccountError {
  AccountNotInitializedError({
    required super.errorLogs,
    required super.logs,
    super.accountAddress,
    super.accountName,
    super.origin,
  }) : super(
         errorCode: const ErrorCode(
           code: 'AccountNotInitialized',
           number: LangErrorCode.accountNotInitialized,
         ),
         errorMessage: getErrorMessage(LangErrorCode.accountNotInitialized),
       );

  /// Create from account validation
  factory AccountNotInitializedError.fromAddress({
    required PublicKey accountAddress,
    required List<String> errorLogs,
    required List<String> logs,
    String? accountName,
    Origin? origin,
  }) => AccountNotInitializedError(
    errorLogs: errorLogs,
    logs: logs,
    accountAddress: accountAddress,
    accountName: accountName,
    origin: origin,
  );

  @override
  String toString() {
    final buffer = StringBuffer();

    if (error.origin is AccountNameOrigin) {
      final accountName = (error.origin as AccountNameOrigin).accountName;
      buffer.write('AnchorError caused by account: $accountName. ');
    } else {
      buffer.write('AnchorError occurred. ');
    }

    buffer.write('Error Code: ${error.errorCode.code}. ');
    buffer.write('Error Number: ${error.errorCode.number}. ');
    buffer.write('Error Message: ${error.errorMessage}');

    if (accountAddress != null) {
      buffer.write(' (Address: $accountAddress)');
    }

    return buffer.toString();
  }
}

/// Account did not deserialize error (3003)
class AccountDidNotDeserializeError extends AccountError {
  AccountDidNotDeserializeError({
    required super.errorLogs,
    required super.logs,
    super.accountAddress,
    super.accountName,
    this.accountDataSize,
    this.expectedStructure,
    super.origin,
  }) : super(
         errorCode: const ErrorCode(
           code: 'AccountDidNotDeserialize',
           number: LangErrorCode.accountDidNotDeserialize,
         ),
         errorMessage: getErrorMessage(LangErrorCode.accountDidNotDeserialize),
       );

  /// Create from deserialization failure
  factory AccountDidNotDeserializeError.fromFailure({
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    int? dataSize,
    String? structure,
    Origin? origin,
  }) => AccountDidNotDeserializeError(
    errorLogs: errorLogs,
    logs: logs,
    accountAddress: accountAddress,
    accountName: accountName,
    accountDataSize: dataSize,
    expectedStructure: structure,
    origin: origin,
  );

  /// Size of the account data
  final int? accountDataSize;

  /// Expected structure information
  final String? expectedStructure;

  @override
  String toString() {
    final buffer = StringBuffer();

    if (error.origin is AccountNameOrigin) {
      final accountName = (error.origin as AccountNameOrigin).accountName;
      buffer.write('AnchorError caused by account: $accountName. ');
    } else {
      buffer.write('AnchorError occurred. ');
    }

    buffer.write('Error Code: ${error.errorCode.code}. ');
    buffer.write('Error Number: ${error.errorCode.number}. ');
    buffer.write('Error Message: ${error.errorMessage}');

    if (accountDataSize != null) {
      buffer.write(' (Data size: $accountDataSize bytes)');
    }

    if (expectedStructure != null) {
      buffer.write(' (Expected: $expectedStructure)');
    }

    return buffer.toString();
  }
}
