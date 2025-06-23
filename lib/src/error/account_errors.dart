/// Account-Specific Error Types
///
/// This module implements specific account-related error types with exact error code
/// and message matching to TypeScript implementation, providing detailed context
/// and debugging information for account validation failures.

import 'anchor_error.dart';
import 'error_constants.dart';
import '../types/public_key.dart';

/// Base class for all account-specific errors
abstract class AccountError extends AnchorError {
  /// The account address associated with the error
  final PublicKey? accountAddress;

  /// The account name from IDL (if known)
  final String? accountName;

  AccountError({
    required ErrorCode errorCode,
    required String errorMessage,
    required List<String> errorLogs,
    required List<String> logs,
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
          errorLogs: errorLogs,
          logs: logs,
        );

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
  /// Expected discriminator bytes
  final List<int> expectedDiscriminator;

  /// Actual discriminator bytes found
  final List<int> actualDiscriminator;

  AccountDiscriminatorMismatchError({
    required this.expectedDiscriminator,
    required this.actualDiscriminator,
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountDiscriminatorMismatch',
            number: LangErrorCode.accountDiscriminatorMismatch,
          ),
          errorMessage:
              getErrorMessage(LangErrorCode.accountDiscriminatorMismatch),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
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
  }) {
    return AccountDiscriminatorMismatchError(
      expectedDiscriminator: expected,
      actualDiscriminator: actual,
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

  /// Get hex representation of discriminators for debugging
  String get expectedHex => expectedDiscriminator
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join('');

  String get actualHex => actualDiscriminator
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join('');

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

/// Account owned by wrong program error (3007)
class AccountOwnedByWrongProgramError extends AccountError {
  /// Expected owner program ID
  final PublicKey expectedOwner;

  /// Actual owner program ID
  final PublicKey actualOwner;

  AccountOwnedByWrongProgramError({
    required this.expectedOwner,
    required this.actualOwner,
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountOwnedByWrongProgram',
            number: LangErrorCode.accountOwnedByWrongProgram,
          ),
          errorMessage:
              getErrorMessage(LangErrorCode.accountOwnedByWrongProgram),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
          comparedValues:
              ComparedValues.publicKeys([expectedOwner, actualOwner]),
        );

  /// Create from ownership validation
  factory AccountOwnedByWrongProgramError.fromValidation({
    required PublicKey expected,
    required PublicKey actual,
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) {
    return AccountOwnedByWrongProgramError(
      expectedOwner: expected,
      actualOwner: actual,
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

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
    buffer.write('Error Message: ${error.errorMessage}. ');
    buffer.write('Expected owner: $expectedOwner, ');
    buffer.write('Actual owner: $actualOwner');

    return buffer.toString();
  }
}

/// Account not initialized error (3012)
class AccountNotInitializedError extends AccountError {
  AccountNotInitializedError({
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountNotInitialized',
            number: LangErrorCode.accountNotInitialized,
          ),
          errorMessage: getErrorMessage(LangErrorCode.accountNotInitialized),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
        );

  /// Create from account validation
  factory AccountNotInitializedError.fromAddress({
    required PublicKey accountAddress,
    required List<String> errorLogs,
    required List<String> logs,
    String? accountName,
    Origin? origin,
  }) {
    return AccountNotInitializedError(
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

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
  /// Size of the account data
  final int? accountDataSize;

  /// Expected structure information
  final String? expectedStructure;

  AccountDidNotDeserializeError({
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    this.accountDataSize,
    this.expectedStructure,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountDidNotDeserialize',
            number: LangErrorCode.accountDidNotDeserialize,
          ),
          errorMessage: getErrorMessage(LangErrorCode.accountDidNotDeserialize),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
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
  }) {
    return AccountDidNotDeserializeError(
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      accountDataSize: dataSize,
      expectedStructure: structure,
      origin: origin,
    );
  }

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

/// Account not system owned error (3011)
class AccountNotSystemOwnedError extends AccountError {
  /// The actual owner of the account
  final PublicKey actualOwner;

  AccountNotSystemOwnedError({
    required this.actualOwner,
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountNotSystemOwned',
            number: LangErrorCode.accountNotSystemOwned,
          ),
          errorMessage: getErrorMessage(LangErrorCode.accountNotSystemOwned),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
        );

  /// Create from system ownership validation
  factory AccountNotSystemOwnedError.fromValidation({
    required PublicKey actualOwner,
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) {
    return AccountNotSystemOwnedError(
      actualOwner: actualOwner,
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

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
    buffer.write('Error Message: ${error.errorMessage}. ');
    buffer.write('Actual owner: $actualOwner');

    return buffer.toString();
  }
}

/// Account not signer error (3010)
class AccountNotSignerError extends AccountError {
  AccountNotSignerError({
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountNotSigner',
            number: LangErrorCode.accountNotSigner,
          ),
          errorMessage: getErrorMessage(LangErrorCode.accountNotSigner),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
        );

  /// Create from signer validation
  factory AccountNotSignerError.fromValidation({
    required PublicKey accountAddress,
    required List<String> errorLogs,
    required List<String> logs,
    String? accountName,
    Origin? origin,
  }) {
    return AccountNotSignerError(
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

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

/// Account not mutable error (3006)
class AccountNotMutableError extends AccountError {
  AccountNotMutableError({
    required List<String> errorLogs,
    required List<String> logs,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) : super(
          errorCode: ErrorCode(
            code: 'AccountNotMutable',
            number: LangErrorCode.accountNotMutable,
          ),
          errorMessage: getErrorMessage(LangErrorCode.accountNotMutable),
          errorLogs: errorLogs,
          logs: logs,
          accountAddress: accountAddress,
          accountName: accountName,
          origin: origin,
        );

  /// Create from mutability validation
  factory AccountNotMutableError.fromValidation({
    required PublicKey accountAddress,
    required List<String> errorLogs,
    required List<String> logs,
    String? accountName,
    Origin? origin,
  }) {
    return AccountNotMutableError(
      errorLogs: errorLogs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

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

/// Utility class for creating account errors from validation failures
class AccountErrorFactory {
  /// Create discriminator mismatch error
  static AccountDiscriminatorMismatchError discriminatorMismatch({
    required List<int> expected,
    required List<int> actual,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) {
    final logs = [
      'Program log: Account discriminator mismatch',
      'Program log: Expected: ${expected.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join('')}',
      'Program log: Actual: ${actual.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join('')}',
    ];

    return AccountDiscriminatorMismatchError(
      expectedDiscriminator: expected,
      actualDiscriminator: actual,
      errorLogs: logs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

  /// Create wrong program owner error
  static AccountOwnedByWrongProgramError wrongProgramOwner({
    required PublicKey expectedOwner,
    required PublicKey actualOwner,
    PublicKey? accountAddress,
    String? accountName,
    Origin? origin,
  }) {
    final logs = [
      'Program log: Account owned by wrong program',
      'Program log: Expected: $expectedOwner',
      'Program log: Actual: $actualOwner',
    ];

    return AccountOwnedByWrongProgramError(
      expectedOwner: expectedOwner,
      actualOwner: actualOwner,
      errorLogs: logs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

  /// Create account not initialized error
  static AccountNotInitializedError notInitialized({
    required PublicKey accountAddress,
    String? accountName,
    Origin? origin,
  }) {
    final logs = [
      'Program log: Account not initialized',
      'Program log: Address: $accountAddress',
    ];

    return AccountNotInitializedError(
      errorLogs: logs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      origin: origin,
    );
  }

  /// Create deserialization error
  static AccountDidNotDeserializeError deserializationFailed({
    PublicKey? accountAddress,
    String? accountName,
    int? dataSize,
    String? expectedStructure,
    Origin? origin,
  }) {
    final logs = [
      'Program log: Failed to deserialize account',
      if (accountAddress != null) 'Program log: Address: $accountAddress',
      if (dataSize != null) 'Program log: Data size: $dataSize bytes',
      if (expectedStructure != null)
        'Program log: Expected: $expectedStructure',
    ];

    return AccountDidNotDeserializeError(
      errorLogs: logs,
      logs: logs,
      accountAddress: accountAddress,
      accountName: accountName,
      accountDataSize: dataSize,
      expectedStructure: expectedStructure,
      origin: origin,
    );
  }
}
