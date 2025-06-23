/// Account ownership validation engine for Anchor programs
///
/// This module provides comprehensive account ownership validation matching
/// TypeScript's Program.account.fetch() pre-validation checks, including
/// support for complex ownership patterns, edge cases, and detailed error context.
library;

import '../types/public_key.dart';
import '../provider/connection.dart';

/// Result of account ownership validation
class AccountOwnershipValidationResult {
  /// Whether the account passes ownership validation
  final bool isValid;

  /// Detailed error message if validation fails
  final String? errorMessage;

  /// The expected program ID that should own the account
  final PublicKey? expectedOwner;

  /// The actual owner of the account
  final PublicKey? actualOwner;

  /// The account address being validated
  final PublicKey accountAddress;

  /// Whether the account exists on-chain
  final bool accountExists;

  /// Additional validation context
  final Map<String, dynamic>? context;

  const AccountOwnershipValidationResult({
    required this.isValid,
    required this.accountAddress,
    required this.accountExists,
    this.errorMessage,
    this.expectedOwner,
    this.actualOwner,
    this.context,
  });

  /// Create a successful validation result
  factory AccountOwnershipValidationResult.success({
    required PublicKey accountAddress,
    required PublicKey actualOwner,
    Map<String, dynamic>? context,
  }) {
    return AccountOwnershipValidationResult(
      isValid: true,
      accountAddress: accountAddress,
      accountExists: true,
      actualOwner: actualOwner,
      context: context,
    );
  }

  /// Create a failed validation result
  factory AccountOwnershipValidationResult.failure({
    required PublicKey accountAddress,
    required String errorMessage,
    PublicKey? expectedOwner,
    PublicKey? actualOwner,
    bool accountExists = true,
    Map<String, dynamic>? context,
  }) {
    return AccountOwnershipValidationResult(
      isValid: false,
      accountAddress: accountAddress,
      accountExists: accountExists,
      errorMessage: errorMessage,
      expectedOwner: expectedOwner,
      actualOwner: actualOwner,
      context: context,
    );
  }

  @override
  String toString() {
    if (isValid) {
      return 'AccountOwnershipValidationResult(isValid: true, '
          'account: ${accountAddress.toBase58()}, '
          'owner: ${actualOwner?.toBase58()})';
    } else {
      return 'AccountOwnershipValidationResult(isValid: false, '
          'account: ${accountAddress.toBase58()}, '
          'error: $errorMessage)';
    }
  }
}

/// Exception thrown when account ownership validation fails
class AccountOwnershipValidationException implements Exception {
  final AccountOwnershipValidationResult result;

  const AccountOwnershipValidationException(this.result);

  @override
  String toString() {
    return 'AccountOwnershipValidationException: ${result.errorMessage}';
  }
}

/// Configuration for account ownership validation
class AccountOwnershipValidationConfig {
  /// Whether to allow system-owned accounts (rare edge case)
  final bool allowSystemOwned;

  /// Whether to allow token program owned accounts
  final bool allowTokenProgramOwned;

  /// Custom allowed owners beyond the expected program ID
  final Set<PublicKey> customAllowedOwners;

  /// Whether to perform strict validation (fail on any mismatch)
  final bool strictValidation;

  /// Whether to bypass validation entirely (for testing)
  final bool bypassValidation;

  /// Whether to include detailed validation context
  final bool includeContext;

  const AccountOwnershipValidationConfig({
    this.allowSystemOwned = false,
    this.allowTokenProgramOwned = false,
    this.customAllowedOwners = const {},
    this.strictValidation = true,
    this.bypassValidation = false,
    this.includeContext = true,
  });

  /// Default configuration for strict validation
  static const AccountOwnershipValidationConfig strict =
      AccountOwnershipValidationConfig(
    strictValidation: true,
    bypassValidation: false,
  );

  /// Configuration allowing common edge cases
  static const AccountOwnershipValidationConfig permissive =
      AccountOwnershipValidationConfig(
    allowSystemOwned: true,
    allowTokenProgramOwned: true,
    strictValidation: false,
  );

  /// Configuration for testing (bypasses validation)
  static const AccountOwnershipValidationConfig testing =
      AccountOwnershipValidationConfig(
    bypassValidation: true,
    includeContext: false,
  );
}

/// Comprehensive account ownership validation engine
class AccountOwnershipValidator {
  /// Well-known program IDs for validation
  static final PublicKey systemProgramId =
      PublicKey.fromBase58('11111111111111111111111111111111');
  static final PublicKey tokenProgramId =
      PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
  static final PublicKey token2022ProgramId =
      PublicKey.fromBase58('TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb');

  /// Validation statistics
  static int _validationCount = 0;
  static int _successCount = 0;
  static int _failureCount = 0;

  /// Get validation statistics
  static Map<String, int> get statistics => {
        'totalValidations': _validationCount,
        'successes': _successCount,
        'failures': _failureCount,
      };

  /// Reset validation statistics
  static void resetStatistics() {
    _validationCount = 0;
    _successCount = 0;
    _failureCount = 0;
  }

  /// Synchronous ownership validation for known owner
  ///
  /// This method performs simple ownership validation when the actual owner
  /// is already known, without requiring network calls.
  ///
  /// [accountKey] - The account address being validated
  /// [expectedOwner] - The expected program owner
  /// [actualOwner] - The actual owner of the account
  /// [accountName] - Name of the account type for error context
  static AccountOwnershipValidationResult validate({
    required PublicKey accountKey,
    required PublicKey expectedOwner,
    required PublicKey actualOwner,
    required dynamic accountName,
  }) {
    final isValid = expectedOwner.toBase58() == actualOwner.toBase58();

    if (isValid) {
      return AccountOwnershipValidationResult.success(
        accountAddress: accountKey,
        actualOwner: actualOwner,
      );
    } else {
      return AccountOwnershipValidationResult.failure(
        accountAddress: accountKey,
        expectedOwner: expectedOwner,
        actualOwner: actualOwner,
        errorMessage:
            'Account $accountName at ${accountKey.toBase58()} is owned by '
            '${actualOwner.toBase58()}, expected ${expectedOwner.toBase58()}',
      );
    }
  }

  /// Validate account ownership for a single account
  ///
  /// [accountAddress] - The address of the account to validate
  /// [expectedProgramId] - The program ID expected to own the account
  /// [connection] - Connection to fetch account info
  /// [config] - Validation configuration
  ///
  /// Returns validation result with detailed information
  static Future<AccountOwnershipValidationResult> validateSingle({
    required PublicKey accountAddress,
    required PublicKey expectedProgramId,
    required Connection connection,
    AccountOwnershipValidationConfig config =
        AccountOwnershipValidationConfig.strict,
  }) async {
    _validationCount++;

    try {
      // Bypass validation if configured
      if (config.bypassValidation) {
        _successCount++;
        return AccountOwnershipValidationResult.success(
          accountAddress: accountAddress,
          actualOwner: expectedProgramId, // Assume correct for bypass
          context: config.includeContext ? {'bypassed': true} : null,
        );
      }

      // Fetch account info
      final accountInfo = await connection.getAccountInfo(accountAddress);

      // Check if account exists
      if (accountInfo == null) {
        _failureCount++;
        return AccountOwnershipValidationResult.failure(
          accountAddress: accountAddress,
          errorMessage: 'Account does not exist or has no data: '
              '${accountAddress.toBase58()}',
          expectedOwner: expectedProgramId,
          accountExists: false,
          context: config.includeContext
              ? {
                  'validation_type': 'existence_check',
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      final actualOwner = accountInfo.owner;

      // Check for exact match first
      if (actualOwner == expectedProgramId) {
        _successCount++;
        return AccountOwnershipValidationResult.success(
          accountAddress: accountAddress,
          actualOwner: actualOwner,
          context: config.includeContext
              ? {
                  'validation_type': 'exact_match',
                  'account_data_length': accountInfo.data?.length ?? 0,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // Check custom allowed owners
      if (config.customAllowedOwners.any((owner) => actualOwner == owner)) {
        _successCount++;
        return AccountOwnershipValidationResult.success(
          accountAddress: accountAddress,
          actualOwner: actualOwner,
          context: config.includeContext
              ? {
                  'validation_type': 'custom_allowed_owner',
                  'matched_owner': actualOwner.toBase58(),
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // Check system program ownership (if allowed)
      if (config.allowSystemOwned && actualOwner == systemProgramId) {
        _successCount++;
        return AccountOwnershipValidationResult.success(
          accountAddress: accountAddress,
          actualOwner: actualOwner,
          context: config.includeContext
              ? {
                  'validation_type': 'system_owned_allowed',
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // Check token program ownership (if allowed)
      if (config.allowTokenProgramOwned &&
          (actualOwner == tokenProgramId ||
              actualOwner == token2022ProgramId)) {
        _successCount++;
        return AccountOwnershipValidationResult.success(
          accountAddress: accountAddress,
          actualOwner: actualOwner,
          context: config.includeContext
              ? {
                  'validation_type': 'token_program_owned_allowed',
                  'token_program_variant': actualOwner == tokenProgramId
                      ? 'spl_token'
                      : 'token_2022',
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // If strict validation is disabled, allow any ownership
      if (!config.strictValidation) {
        _successCount++;
        return AccountOwnershipValidationResult.success(
          accountAddress: accountAddress,
          actualOwner: actualOwner,
          context: config.includeContext
              ? {
                  'validation_type': 'permissive_allowed',
                  'actual_owner': actualOwner.toBase58(),
                  'expected_owner': expectedProgramId.toBase58(),
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // Validation failed - ownership mismatch
      _failureCount++;
      return AccountOwnershipValidationResult.failure(
        accountAddress: accountAddress,
        errorMessage: _formatOwnershipMismatchError(
          accountAddress,
          expectedProgramId,
          actualOwner,
        ),
        expectedOwner: expectedProgramId,
        actualOwner: actualOwner,
        context: config.includeContext
            ? {
                'validation_type': 'ownership_mismatch',
                'expected_owner': expectedProgramId.toBase58(),
                'actual_owner': actualOwner.toBase58(),
                'account_data_length': accountInfo.data?.length ?? 0,
                'timestamp': DateTime.now().toIso8601String(),
              }
            : null,
      );
    } catch (error) {
      _failureCount++;
      return AccountOwnershipValidationResult.failure(
        accountAddress: accountAddress,
        errorMessage: 'Account ownership validation failed: $error',
        expectedOwner: expectedProgramId,
        context: config.includeContext
            ? {
                'validation_type': 'error',
                'error': error.toString(),
                'timestamp': DateTime.now().toIso8601String(),
              }
            : null,
      );
    }
  }

  /// Validate ownership for multiple accounts in batch
  ///
  /// [accounts] - Map of account addresses to expected program IDs
  /// [connection] - Connection to fetch account info
  /// [config] - Validation configuration
  ///
  /// Returns list of validation results
  static Future<List<AccountOwnershipValidationResult>> validateBatch({
    required Map<PublicKey, PublicKey> accounts,
    required Connection connection,
    AccountOwnershipValidationConfig config =
        AccountOwnershipValidationConfig.strict,
  }) async {
    final results = <AccountOwnershipValidationResult>[];

    for (final entry in accounts.entries) {
      final accountAddress = entry.key;
      final expectedProgramId = entry.value;

      final result = await validateSingle(
        accountAddress: accountAddress,
        expectedProgramId: expectedProgramId,
        connection: connection,
        config: config,
      );

      results.add(result);
    }

    return results;
  }

  /// Validate ownership and throw exception on failure
  ///
  /// [accountAddress] - The address of the account to validate
  /// [expectedProgramId] - The program ID expected to own the account
  /// [connection] - Connection to fetch account info
  /// [config] - Validation configuration
  ///
  /// Throws AccountOwnershipValidationException on failure
  static Future<void> validateOrThrow({
    required PublicKey accountAddress,
    required PublicKey expectedProgramId,
    required Connection connection,
    AccountOwnershipValidationConfig config =
        AccountOwnershipValidationConfig.strict,
  }) async {
    final result = await validateSingle(
      accountAddress: accountAddress,
      expectedProgramId: expectedProgramId,
      connection: connection,
      config: config,
    );

    if (!result.isValid) {
      throw AccountOwnershipValidationException(result);
    }
  }

  /// Check if an account belongs to any of the specified programs
  ///
  /// [accountAddress] - The address of the account to check
  /// [programIds] - Set of acceptable program IDs
  /// [connection] - Connection to fetch account info
  ///
  /// Returns the matching program ID if found, null otherwise
  static Future<PublicKey?> findMatchingOwner({
    required PublicKey accountAddress,
    required Set<PublicKey> programIds,
    required Connection connection,
  }) async {
    try {
      final accountInfo = await connection.getAccountInfo(accountAddress);
      if (accountInfo == null) return null;

      final actualOwner = accountInfo.owner;
      for (final programId in programIds) {
        if (actualOwner == programId) {
          return programId;
        }
      }

      return null;
    } catch (error) {
      return null;
    }
  }

  /// Format a detailed ownership mismatch error message
  static String _formatOwnershipMismatchError(
    PublicKey accountAddress,
    PublicKey expectedOwner,
    PublicKey actualOwner,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Account ownership validation failed:');
    buffer.writeln('  Account: ${accountAddress.toBase58()}');
    buffer.writeln('  Expected Owner: ${expectedOwner.toBase58()}');
    buffer.writeln('  Actual Owner: ${actualOwner.toBase58()}');

    // Add helpful context for common ownership patterns
    if (actualOwner == systemProgramId) {
      buffer.writeln(
        '  Note: Account is owned by System Program (uninitialized or system account)',
      );
    } else if (actualOwner == tokenProgramId) {
      buffer.writeln('  Note: Account is owned by SPL Token Program');
    } else if (actualOwner == token2022ProgramId) {
      buffer.writeln('  Note: Account is owned by Token-2022 Program');
    }

    buffer.write('This account does not belong to the expected program.');

    return buffer.toString();
  }

  /// Check if a program ID represents a well-known system program
  static bool isWellKnownProgram(PublicKey programId) {
    return programId == systemProgramId ||
        programId == tokenProgramId ||
        programId == token2022ProgramId;
  }

  /// Get a human-readable name for well-known programs
  static String? getWellKnownProgramName(PublicKey programId) {
    if (programId == systemProgramId) return 'System Program';
    if (programId == tokenProgramId) return 'SPL Token Program';
    if (programId == token2022ProgramId) return 'Token-2022 Program';
    return null;
  }
}
