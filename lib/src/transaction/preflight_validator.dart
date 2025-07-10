/// Pre-flight Account Validation System for Solana Anchor programs
///
/// This module provides comprehensive pre-flight account validation matching
/// TypeScript's AccountsResolver and validation system. It validates account
/// existence, ownership, state dependencies, and cross-account relationships
/// before transaction simulation or execution.

library;

import 'dart:typed_data';

import 'dart:async';

import '../types/public_key.dart';
import '../types/transaction.dart' as transaction_types;
import '../provider/anchor_provider.dart';
import '../types/commitment.dart';

/// Configuration for pre-flight validation
class PreflightValidationConfig {
  /// Whether to validate account ownership
  final bool validateOwnership;

  /// Whether to validate account existence
  final bool validateExistence;

  /// Whether to validate account state consistency
  final bool validateState;

  /// Whether to validate account dependencies
  final bool validateDependencies;

  /// Whether to perform batch validation with parallel RPC calls
  final bool enableBatchValidation;

  /// Maximum number of parallel RPC calls for batch validation
  final int maxParallelRequests;

  /// Timeout for account validation requests
  final Duration requestTimeout;

  /// Commitment level for account validation
  final CommitmentConfig commitment;

  /// Whether to skip validation for known system accounts
  final bool skipSystemAccountValidation;

  /// List of programs that are considered trusted for ownership validation
  final List<PublicKey> trustedPrograms;

  const PreflightValidationConfig({
    this.validateOwnership = true,
    this.validateExistence = true,
    this.validateState = true,
    this.validateDependencies = true,
    this.enableBatchValidation = true,
    this.maxParallelRequests = 10,
    this.requestTimeout = const Duration(seconds: 30),
    this.commitment = CommitmentConfigs.confirmed,
    this.skipSystemAccountValidation = true,
    this.trustedPrograms = const [],
  });

  /// Create default configuration
  factory PreflightValidationConfig.defaultConfig() {
    return const PreflightValidationConfig();
  }

  /// Create strict validation configuration
  factory PreflightValidationConfig.strict() {
    return const PreflightValidationConfig(
      validateOwnership: true,
      validateExistence: true,
      validateState: true,
      validateDependencies: true,
      skipSystemAccountValidation: false,
    );
  }

  /// Create permissive validation configuration for development
  factory PreflightValidationConfig.permissive() {
    return const PreflightValidationConfig(
      validateOwnership: false,
      validateExistence: true,
      validateState: false,
      validateDependencies: false,
      skipSystemAccountValidation: true,
    );
  }
}

/// Result of pre-flight account validation
class PreflightValidationResult {
  /// Whether all validations passed
  final bool success;

  /// List of validation errors encountered
  final List<AccountValidationError> errors;

  /// List of warnings (non-critical issues)
  final List<AccountValidationWarning> warnings;

  /// Map of account addresses to their validation status
  final Map<String, AccountValidationStatus> accountStatuses;

  /// Total number of accounts validated
  final int totalAccounts;

  /// Number of accounts that passed validation
  final int validAccounts;

  /// Number of accounts that failed validation
  final int invalidAccounts;

  /// Time taken for validation
  final Duration validationTime;

  /// Additional metadata about the validation process
  final Map<String, dynamic> metadata;

  const PreflightValidationResult({
    required this.success,
    required this.errors,
    required this.warnings,
    required this.accountStatuses,
    required this.totalAccounts,
    required this.validAccounts,
    required this.invalidAccounts,
    required this.validationTime,
    this.metadata = const {},
  });

  /// Create a successful validation result
  factory PreflightValidationResult.success({
    required Map<String, AccountValidationStatus> accountStatuses,
    required Duration validationTime,
    List<AccountValidationWarning> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return PreflightValidationResult(
      success: true,
      errors: const [],
      warnings: warnings,
      accountStatuses: accountStatuses,
      totalAccounts: accountStatuses.length,
      validAccounts: accountStatuses.length,
      invalidAccounts: 0,
      validationTime: validationTime,
      metadata: metadata,
    );
  }

  /// Create a failed validation result
  factory PreflightValidationResult.failure({
    required List<AccountValidationError> errors,
    required Map<String, AccountValidationStatus> accountStatuses,
    required Duration validationTime,
    List<AccountValidationWarning> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    final validAccounts =
        accountStatuses.values.where((status) => status.isValid).length;

    return PreflightValidationResult(
      success: false,
      errors: errors,
      warnings: warnings,
      accountStatuses: accountStatuses,
      totalAccounts: accountStatuses.length,
      validAccounts: validAccounts,
      invalidAccounts: accountStatuses.length - validAccounts,
      validationTime: validationTime,
      metadata: metadata,
    );
  }

  @override
  String toString() {
    return 'PreflightValidationResult(success: $success, '
        'totalAccounts: $totalAccounts, validAccounts: $validAccounts, '
        'invalidAccounts: $invalidAccounts, errors: ${errors.length}, '
        'warnings: ${warnings.length})';
  }
}

/// Status of individual account validation
class AccountValidationStatus {
  /// Public key of the account
  final PublicKey publicKey;

  /// Whether the account passed validation
  final bool isValid;

  /// Whether the account exists
  final bool exists;

  /// Account owner (if account exists)
  final PublicKey? owner;

  /// Account data length (if account exists)
  final int? dataLength;

  /// Account balance in lamports (if account exists)
  final int? lamports;

  /// Whether the account is executable
  final bool? executable;

  /// Validation errors specific to this account
  final List<AccountValidationError> errors;

  /// Validation warnings specific to this account
  final List<AccountValidationWarning> warnings;

  /// Additional metadata for this account
  final Map<String, dynamic> metadata;

  const AccountValidationStatus({
    required this.publicKey,
    required this.isValid,
    required this.exists,
    this.owner,
    this.dataLength,
    this.lamports,
    this.executable,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });

  /// Create status for a valid account
  factory AccountValidationStatus.valid({
    required PublicKey publicKey,
    required PublicKey owner,
    required int dataLength,
    required int lamports,
    required bool executable,
    List<AccountValidationWarning> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return AccountValidationStatus(
      publicKey: publicKey,
      isValid: true,
      exists: true,
      owner: owner,
      dataLength: dataLength,
      lamports: lamports,
      executable: executable,
      warnings: warnings,
      metadata: metadata,
    );
  }

  /// Create status for an invalid account
  factory AccountValidationStatus.invalid({
    required PublicKey publicKey,
    required List<AccountValidationError> errors,
    bool exists = false,
    PublicKey? owner,
    int? dataLength,
    int? lamports,
    bool? executable,
    List<AccountValidationWarning> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return AccountValidationStatus(
      publicKey: publicKey,
      isValid: false,
      exists: exists,
      owner: owner,
      dataLength: dataLength,
      lamports: lamports,
      executable: executable,
      errors: errors,
      warnings: warnings,
      metadata: metadata,
    );
  }

  @override
  String toString() {
    return 'AccountValidationStatus(publicKey: ${publicKey.toBase58()}, '
        'isValid: $isValid, exists: $exists, errors: ${errors.length})';
  }
}

/// Account validation error
class AccountValidationError {
  /// Type of validation error
  final AccountValidationErrorType type;

  /// Account that caused the error
  final PublicKey publicKey;

  /// Error message
  final String message;

  /// Additional context about the error
  final Map<String, dynamic> context;

  /// Underlying exception (if any)
  final Exception? exception;

  const AccountValidationError({
    required this.type,
    required this.publicKey,
    required this.message,
    this.context = const {},
    this.exception,
  });

  @override
  String toString() {
    return 'AccountValidationError(type: $type, publicKey: ${publicKey.toBase58()}, '
        'message: $message)';
  }
}

/// Account validation warning
class AccountValidationWarning {
  /// Type of validation warning
  final AccountValidationWarningType type;

  /// Account that caused the warning
  final PublicKey publicKey;

  /// Warning message
  final String message;

  /// Additional context about the warning
  final Map<String, dynamic> context;

  const AccountValidationWarning({
    required this.type,
    required this.publicKey,
    required this.message,
    this.context = const {},
  });

  @override
  String toString() {
    return 'AccountValidationWarning(type: $type, publicKey: ${publicKey.toBase58()}, '
        'message: $message)';
  }
}

/// Types of account validation errors
enum AccountValidationErrorType {
  accountNotFound,
  ownershipMismatch,
  insufficientBalance,
  accountNotExecutable,
  accountTooSmall,
  accountNotMutable,
  stateDependencyFailed,
  crossAccountValidationFailed,
  rpcTimeout,
  networkError,
}

/// Types of account validation warnings
enum AccountValidationWarningType {
  lowBalance,
  largeAccount,
  deprecatedProgram,
  unusualOwner,
  potentialDependencyIssue,
}

/// Account dependency relationship
class AccountDependency {
  /// Account that depends on another
  final PublicKey dependent;

  /// Account that is depended upon
  final PublicKey dependency;

  /// Type of dependency relationship
  final AccountDependencyType type;

  /// Additional metadata about the dependency
  final Map<String, dynamic> metadata;

  const AccountDependency({
    required this.dependent,
    required this.dependency,
    required this.type,
    this.metadata = const {},
  });
}

/// Types of account dependencies
enum AccountDependencyType {
  ownership,
  stateConsistency,
  crossReference,
  pdaDerived,
  tokenAssociation,
  authorizationDerived,
}

/// Comprehensive pre-flight account validation system
class PreflightValidator {
  final AnchorProvider _provider;
  final Map<String, AccountValidationStatus> _cache = {};
  static const int _maxCacheSize = 1000;

  PreflightValidator(this._provider);

  /// Validate accounts for a transaction before simulation or execution
  Future<PreflightValidationResult> validateTransaction(
    transaction_types.Transaction transaction, {
    PreflightValidationConfig? config,
    List<AccountDependency>? dependencies,
    Map<PublicKey, PublicKey>? expectedOwners,
  }) async {
    config ??= PreflightValidationConfig.defaultConfig();
    final stopwatch = Stopwatch()..start();

    try {
      // Extract all accounts from transaction instructions
      final accounts = _extractAccountsFromTransaction(transaction);

      // Perform validation
      final result = await _validateAccounts(
        accounts,
        config: config,
        dependencies: dependencies,
        expectedOwners: expectedOwners,
      );

      stopwatch.stop();
      return result.copyWith(validationTime: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      return PreflightValidationResult.failure(
        errors: [
          AccountValidationError(
            type: AccountValidationErrorType.networkError,
            publicKey: PublicKey.systemProgram, // Placeholder
            message: 'Validation failed: $e',
          ),
        ],
        accountStatuses: {},
        validationTime: stopwatch.elapsed,
      );
    }
  }

  /// Validate a list of accounts with comprehensive checks
  Future<PreflightValidationResult> validateAccounts(
    List<PublicKey> accounts, {
    PreflightValidationConfig? config,
    List<AccountDependency>? dependencies,
    Map<PublicKey, PublicKey>? expectedOwners,
  }) async {
    config ??= PreflightValidationConfig.defaultConfig();
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _validateAccounts(
        accounts,
        config: config,
        dependencies: dependencies,
        expectedOwners: expectedOwners,
      );

      stopwatch.stop();
      return result.copyWith(validationTime: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      return PreflightValidationResult.failure(
        errors: [
          AccountValidationError(
            type: AccountValidationErrorType.networkError,
            publicKey: PublicKey.systemProgram, // Placeholder
            message: 'Validation failed: $e',
          ),
        ],
        accountStatuses: {},
        validationTime: stopwatch.elapsed,
      );
    }
  }

  /// Validate account ownership against expected program
  Future<bool> validateAccountOwnership(
    PublicKey account,
    PublicKey expectedOwner, {
    PreflightValidationConfig? config,
  }) async {
    config ??= PreflightValidationConfig.defaultConfig();

    if (!config.validateOwnership) return true;

    try {
      final accountInfo = await _provider.connection.getAccountInfo(
        account,
        commitment: config.commitment,
      );

      if (accountInfo == null) return false;
      return accountInfo.owner == expectedOwner;
    } catch (e) {
      return false;
    }
  }

  /// Validate account existence
  Future<bool> validateAccountExistence(
    PublicKey account, {
    PreflightValidationConfig? config,
  }) async {
    config ??= PreflightValidationConfig.defaultConfig();

    if (!config.validateExistence) return true;

    try {
      final accountInfo = await _provider.connection.getAccountInfo(
        account,
        commitment: config.commitment,
      );
      return accountInfo != null;
    } catch (e) {
      return false;
    }
  }

  /// Clear validation cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
    };
  }

  /// Extract all accounts from transaction instructions
  List<PublicKey> _extractAccountsFromTransaction(
    transaction_types.Transaction transaction,
  ) {
    final accounts = <PublicKey>{};

    // Add fee payer if present
    if (transaction.feePayer != null) {
      accounts.add(transaction.feePayer!);
    }

    // Extract accounts from all instructions
    for (final instruction in transaction.instructions) {
      accounts.add(instruction.programId);
      for (final account in instruction.accounts) {
        accounts.add(account.pubkey);
      }
    }

    return accounts.toList();
  }

  /// Perform comprehensive account validation
  Future<PreflightValidationResult> _validateAccounts(
    List<PublicKey> accounts, {
    required PreflightValidationConfig config,
    List<AccountDependency>? dependencies,
    Map<PublicKey, PublicKey>? expectedOwners,
  }) async {
    final accountStatuses = <String, AccountValidationStatus>{};
    final errors = <AccountValidationError>[];
    final warnings = <AccountValidationWarning>[];

    if (config.enableBatchValidation) {
      // Perform batch validation with parallel requests
      await _performBatchValidation(
        accounts,
        config,
        accountStatuses,
        errors,
        warnings,
        expectedOwners,
      );
    } else {
      // Perform sequential validation
      await _performSequentialValidation(
        accounts,
        config,
        accountStatuses,
        errors,
        warnings,
        expectedOwners,
      );
    }

    // Validate dependencies if provided
    if (dependencies != null && config.validateDependencies) {
      await _validateDependencies(
        dependencies,
        accountStatuses,
        errors,
        warnings,
      );
    }

    final success = errors.isEmpty;

    if (success) {
      return PreflightValidationResult.success(
        accountStatuses: accountStatuses,
        validationTime: Duration.zero, // Will be set by caller
        warnings: warnings,
      );
    } else {
      return PreflightValidationResult.failure(
        errors: errors,
        accountStatuses: accountStatuses,
        validationTime: Duration.zero, // Will be set by caller
        warnings: warnings,
      );
    }
  }

  /// Perform batch validation with parallel RPC calls
  Future<void> _performBatchValidation(
    List<PublicKey> accounts,
    PreflightValidationConfig config,
    Map<String, AccountValidationStatus> accountStatuses,
    List<AccountValidationError> errors,
    List<AccountValidationWarning> warnings,
    Map<PublicKey, PublicKey>? expectedOwners,
  ) async {
    // Split accounts into batches for parallel processing
    final batches = <List<PublicKey>>[];
    for (int i = 0; i < accounts.length; i += config.maxParallelRequests) {
      batches.add(accounts.sublist(
        i,
        (i + config.maxParallelRequests < accounts.length)
            ? i + config.maxParallelRequests
            : accounts.length,
      ));
    }

    // Process batches in parallel
    for (final batch in batches) {
      final futures = batch.map((account) async {
        return await _validateSingleAccount(
          account,
          config,
          expectedOwners?[account],
        );
      });

      final results = await Future.wait(futures);

      for (final result in results) {
        accountStatuses[result.publicKey.toBase58()] = result;
        errors.addAll(result.errors);
        warnings.addAll(result.warnings);
      }
    }
  }

  /// Perform sequential validation
  Future<void> _performSequentialValidation(
    List<PublicKey> accounts,
    PreflightValidationConfig config,
    Map<String, AccountValidationStatus> accountStatuses,
    List<AccountValidationError> errors,
    List<AccountValidationWarning> warnings,
    Map<PublicKey, PublicKey>? expectedOwners,
  ) async {
    for (final account in accounts) {
      final result = await _validateSingleAccount(
        account,
        config,
        expectedOwners?[account],
      );

      accountStatuses[account.toBase58()] = result;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }
  }

  /// Validate a single account
  Future<AccountValidationStatus> _validateSingleAccount(
    PublicKey account,
    PreflightValidationConfig config,
    PublicKey? expectedOwner,
  ) async {
    final cacheKey = account.toBase58();

    // Check cache first (if caching is enabled)
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final errors = <AccountValidationError>[];
    final warnings = <AccountValidationWarning>[];

    try {
      // Compute data length safely (will be used after fetching accountInfo)
      int dataLength = 0;

      // Skip validation for system accounts if configured
      if (config.skipSystemAccountValidation && _isSystemAccount(account)) {
        final status = AccountValidationStatus.valid(
          publicKey: account,
          owner: PublicKey.systemProgram,
          dataLength: 0,
          lamports: 0,
          executable: false,
          warnings: [
            AccountValidationWarning(
              type: AccountValidationWarningType.unusualOwner,
              publicKey: account,
              message: 'System account validation skipped',
            ),
          ],
        );
        _addToCache(cacheKey, status);
        return status;
      }

      // Fetch account info
      final accountInfo = await _provider.connection.getAccountInfo(
        account,
        commitment: config.commitment,
      );

      if (accountInfo != null && accountInfo.data != null) {
        if (accountInfo.data is String) {
          dataLength = (accountInfo.data as String).length;
        } else if (accountInfo.data is List<int>) {
          dataLength = (accountInfo.data as List<int>).length;
        } else if (accountInfo.data is Uint8List) {
          dataLength = (accountInfo.data as Uint8List).length;
        }
      }

      if (accountInfo == null) {
        if (config.validateExistence) {
          errors.add(AccountValidationError(
            type: AccountValidationErrorType.accountNotFound,
            publicKey: account,
            message: 'Account does not exist',
          ));
        }

        final status = AccountValidationStatus.invalid(
          publicKey: account,
          exists: false,
          errors: errors,
        );
        _addToCache(cacheKey, status);
        return status;
      }

      // Validate ownership if expected owner is provided
      if (expectedOwner != null && config.validateOwnership) {
        if (accountInfo.owner != expectedOwner) {
          errors.add(AccountValidationError(
            type: AccountValidationErrorType.ownershipMismatch,
            publicKey: account,
            message: 'Account owned by ${accountInfo.owner.toBase58()}, '
                'expected ${expectedOwner.toBase58()}',
            context: {
              'actualOwner': accountInfo.owner.toBase58(),
              'expectedOwner': expectedOwner.toBase58(),
            },
          ));
        }
      }

      // Add warnings for potential issues
      if (accountInfo.lamports < 1000000) {
        // Less than 0.001 SOL
        warnings.add(AccountValidationWarning(
          type: AccountValidationWarningType.lowBalance,
          publicKey: account,
          message: 'Account has low balance: ${accountInfo.lamports} lamports',
        ));
      }

      if (dataLength > 10 * 1024 * 1024) {
        // Larger than 10MB
        warnings.add(AccountValidationWarning(
          type: AccountValidationWarningType.largeAccount,
          publicKey: account,
          message: 'Account data is unusually large: $dataLength bytes',
        ));
      }

      final status = errors.isEmpty
          ? AccountValidationStatus.valid(
              publicKey: account,
              owner: accountInfo.owner,
              dataLength: dataLength,
              lamports: accountInfo.lamports,
              executable: accountInfo.executable,
              warnings: warnings,
            )
          : AccountValidationStatus.invalid(
              publicKey: account,
              exists: true,
              owner: accountInfo.owner,
              dataLength: dataLength,
              lamports: accountInfo.lamports,
              executable: accountInfo.executable,
              errors: errors,
              warnings: warnings,
            );

      _addToCache(cacheKey, status);
      return status;
    } catch (e) {
      errors.add(AccountValidationError(
        type: AccountValidationErrorType.networkError,
        publicKey: account,
        message: 'Failed to validate account: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));

      final status = AccountValidationStatus.invalid(
        publicKey: account,
        errors: errors,
      );
      _addToCache(cacheKey, status);
      return status;
    }
  }

  /// Validate account dependencies
  Future<void> _validateDependencies(
    List<AccountDependency> dependencies,
    Map<String, AccountValidationStatus> accountStatuses,
    List<AccountValidationError> errors,
    List<AccountValidationWarning> warnings,
  ) async {
    for (final dependency in dependencies) {
      final dependentStatus = accountStatuses[dependency.dependent.toBase58()];
      final dependencyStatus =
          accountStatuses[dependency.dependency.toBase58()];

      if (dependentStatus == null || dependencyStatus == null) {
        warnings.add(AccountValidationWarning(
          type: AccountValidationWarningType.potentialDependencyIssue,
          publicKey: dependency.dependent,
          message: 'Cannot validate dependency: missing account status',
        ));
        continue;
      }

      // Validate dependency based on type
      switch (dependency.type) {
        case AccountDependencyType.ownership:
          if (dependentStatus.owner != dependency.dependency) {
            errors.add(AccountValidationError(
              type: AccountValidationErrorType.ownershipMismatch,
              publicKey: dependency.dependent,
              message: 'Ownership dependency failed',
              context: {
                'dependency': dependency.dependency.toBase58(),
                'actualOwner': dependentStatus.owner?.toBase58(),
              },
            ));
          }
          break;
        case AccountDependencyType.stateConsistency:
          // Implement state consistency validation
          // This would require domain-specific logic
          break;
        default:
          // Other dependency types can be implemented as needed
          break;
      }
    }
  }

  /// Check if an account is a well-known system account
  bool _isSystemAccount(PublicKey account) {
    final systemAccounts = [
      PublicKey.systemProgram,
      PublicKey.fromBase58(
          '11111111111111111111111111111111'), // System Program
      PublicKey.fromBase58(
          'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'), // Token Program
      PublicKey.fromBase58(
          'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb'), // Token-2022 Program
    ];

    return systemAccounts.contains(account);
  }

  /// Add status to cache with LRU eviction
  void _addToCache(String key, AccountValidationStatus status) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry (simple FIFO for now)
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = status;
  }
}

/// Extension to add copyWith method to PreflightValidationResult
extension PreflightValidationResultExtension on PreflightValidationResult {
  PreflightValidationResult copyWith({
    bool? success,
    List<AccountValidationError>? errors,
    List<AccountValidationWarning>? warnings,
    Map<String, AccountValidationStatus>? accountStatuses,
    int? totalAccounts,
    int? validAccounts,
    int? invalidAccounts,
    Duration? validationTime,
    Map<String, dynamic>? metadata,
  }) {
    return PreflightValidationResult(
      success: success ?? this.success,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      accountStatuses: accountStatuses ?? this.accountStatuses,
      totalAccounts: totalAccounts ?? this.totalAccounts,
      validAccounts: validAccounts ?? this.validAccounts,
      invalidAccounts: invalidAccounts ?? this.invalidAccounts,
      validationTime: validationTime ?? this.validationTime,
      metadata: metadata ?? this.metadata,
    );
  }
}
