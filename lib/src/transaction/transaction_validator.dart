/// Transaction Validation Infrastructure
///
/// This module provides comprehensive transaction validation capabilities
/// matching TypeScript's validation framework with constraint checking,
/// error prevention, and debugging support.

library;

import '../types/public_key.dart';
import '../types/transaction.dart' as tx_types;
import 'transaction_builder.dart';

/// Transaction validation configuration
class TransactionValidationConfig {
  /// Enable account validation
  final bool validateAccounts;

  /// Enable instruction data validation
  final bool validateInstructionData;

  /// Enable transaction size validation
  final bool validateTransactionSize;

  /// Enable compute budget validation
  final bool validateComputeBudget;

  /// Enable signer validation
  final bool validateSigners;

  /// Maximum transaction size in bytes
  final int maxTransactionSize;

  /// Maximum compute units
  final int maxComputeUnits;

  const TransactionValidationConfig({
    this.validateAccounts = true,
    this.validateInstructionData = true,
    this.validateTransactionSize = true,
    this.validateComputeBudget = true,
    this.validateSigners = true,
    this.maxTransactionSize = 1232,
    this.maxComputeUnits = 1400000,
  });

  /// Create strict validation configuration
  factory TransactionValidationConfig.strict() {
    return const TransactionValidationConfig();
  }

  /// Create permissive validation configuration
  factory TransactionValidationConfig.permissive() {
    return const TransactionValidationConfig(
      validateAccounts: false,
      validateInstructionData: false,
      validateTransactionSize: false,
      validateComputeBudget: false,
      validateSigners: false,
    );
  }
}

/// Transaction validation result
class TransactionValidationResult {
  /// Whether the transaction is valid
  final bool isValid;

  /// List of validation errors
  final List<TransactionValidationError> errors;

  /// List of validation warnings
  final List<TransactionValidationWarning> warnings;

  /// Validation metrics
  final TransactionValidationMetrics metrics;

  const TransactionValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.metrics,
  });

  /// Create a successful validation result
  factory TransactionValidationResult.success({
    List<TransactionValidationWarning>? warnings,
    TransactionValidationMetrics? metrics,
  }) {
    return TransactionValidationResult(
      isValid: true,
      errors: [],
      warnings: warnings ?? [],
      metrics: metrics ?? TransactionValidationMetrics.empty(),
    );
  }

  /// Create a failed validation result
  factory TransactionValidationResult.failure({
    required List<TransactionValidationError> errors,
    List<TransactionValidationWarning>? warnings,
    TransactionValidationMetrics? metrics,
  }) {
    return TransactionValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
      metrics: metrics ?? TransactionValidationMetrics.empty(),
    );
  }

  /// Get summary of validation issues
  String get summary {
    final buffer = StringBuffer();

    if (isValid) {
      buffer.write('Transaction validation passed');
      if (warnings.isNotEmpty) {
        buffer.write(' with ${warnings.length} warnings');
      }
    } else {
      buffer
          .write('Transaction validation failed with ${errors.length} errors');
      if (warnings.isNotEmpty) {
        buffer.write(' and ${warnings.length} warnings');
      }
    }

    return buffer.toString();
  }
}

/// Transaction validation error
class TransactionValidationError {
  /// Error type
  final String type;

  /// Error message
  final String message;

  /// Error code
  final String? code;

  /// Context information
  final Map<String, dynamic>? context;

  const TransactionValidationError({
    required this.type,
    required this.message,
    this.code,
    this.context,
  });

  @override
  String toString() => '$type: $message${code != null ? ' ($code)' : ''}';
}

/// Transaction validation warning
class TransactionValidationWarning {
  /// Warning type
  final String type;

  /// Warning message
  final String message;

  /// Context information
  final Map<String, dynamic>? context;

  const TransactionValidationWarning({
    required this.type,
    required this.message,
    this.context,
  });

  @override
  String toString() => 'Warning - $type: $message';
}

/// Transaction validation metrics
class TransactionValidationMetrics {
  /// Estimated transaction size in bytes
  final int estimatedSize;

  /// Number of instructions
  final int instructionCount;

  /// Number of unique accounts
  final int accountCount;

  /// Number of signers
  final int signerCount;

  /// Estimated compute units
  final int estimatedComputeUnits;

  /// Validation time in milliseconds
  final int validationTimeMs;

  const TransactionValidationMetrics({
    required this.estimatedSize,
    required this.instructionCount,
    required this.accountCount,
    required this.signerCount,
    required this.estimatedComputeUnits,
    required this.validationTimeMs,
  });

  /// Create empty metrics
  factory TransactionValidationMetrics.empty() {
    return const TransactionValidationMetrics(
      estimatedSize: 0,
      instructionCount: 0,
      accountCount: 0,
      signerCount: 0,
      estimatedComputeUnits: 0,
      validationTimeMs: 0,
    );
  }

  /// Get efficiency score (0-100)
  double get efficiencyScore {
    // Simple scoring algorithm based on size and compute efficiency
    final sizeScore = (1232 - estimatedSize) / 1232 * 50;
    final computeScore = (1400000 - estimatedComputeUnits) / 1400000 * 50;
    return (sizeScore + computeScore).clamp(0, 100);
  }
}

/// Comprehensive transaction validator
class TransactionValidator {
  final TransactionValidationConfig _config;

  const TransactionValidator({
    TransactionValidationConfig? config,
  }) : _config = config ?? const TransactionValidationConfig();

  /// Validate a transaction builder
  Future<TransactionValidationResult> validateBuilder(
    TransactionBuilder builder,
  ) async {
    final stopwatch = Stopwatch()..start();
    final errors = <TransactionValidationError>[];
    final warnings = <TransactionValidationWarning>[];

    try {
      // Get builder stats
      final stats = builder.getStats();

      // Validate instruction count
      if (_config.validateInstructionData) {
        _validateInstructionCount(stats, errors, warnings);
      }

      // Validate transaction size
      if (_config.validateTransactionSize) {
        _validateTransactionSize(stats, errors, warnings);
      }

      // Validate compute budget
      if (_config.validateComputeBudget) {
        _validateComputeBudget(stats, errors, warnings);
      }

      // Validate accounts
      if (_config.validateAccounts) {
        _validateAccounts(stats, errors, warnings);
      }

      stopwatch.stop();

      final metrics = TransactionValidationMetrics(
        estimatedSize: stats['estimatedSize'] as int,
        instructionCount: stats['instructionCount'] as int,
        accountCount: stats['uniqueAccounts'] as int,
        signerCount: stats['signerAccounts'] as int,
        estimatedComputeUnits: _estimateComputeUnits(stats),
        validationTimeMs: stopwatch.elapsedMilliseconds,
      );

      return errors.isEmpty
          ? TransactionValidationResult.success(
              warnings: warnings,
              metrics: metrics,
            )
          : TransactionValidationResult.failure(
              errors: errors,
              warnings: warnings,
              metrics: metrics,
            );
    } catch (e) {
      stopwatch.stop();

      return TransactionValidationResult.failure(
        errors: [
          TransactionValidationError(
            type: 'validation_error',
            message: 'Validation failed: $e',
            code: 'VALIDATION_EXCEPTION',
          ),
        ],
        metrics: TransactionValidationMetrics(
          estimatedSize: 0,
          instructionCount: 0,
          accountCount: 0,
          signerCount: 0,
          estimatedComputeUnits: 0,
          validationTimeMs: stopwatch.elapsedMilliseconds,
        ),
      );
    }
  }

  /// Validate a built transaction
  TransactionValidationResult validateTransaction(
    tx_types.Transaction transaction,
  ) {
    final stopwatch = Stopwatch()..start();
    final errors = <TransactionValidationError>[];
    final warnings = <TransactionValidationWarning>[];

    // Validate basic transaction structure
    _validateTransactionStructure(transaction, errors, warnings);

    // Validate instructions
    if (_config.validateInstructionData) {
      _validateTransactionInstructions(transaction, errors, warnings);
    }

    // Validate signers
    if (_config.validateSigners) {
      _validateTransactionSigners(transaction, errors, warnings);
    }

    stopwatch.stop();

    final metrics = _calculateTransactionMetrics(
        transaction, stopwatch.elapsedMilliseconds);

    return errors.isEmpty
        ? TransactionValidationResult.success(
            warnings: warnings,
            metrics: metrics,
          )
        : TransactionValidationResult.failure(
            errors: errors,
            warnings: warnings,
            metrics: metrics,
          );
  }

  /// Validate instruction count
  void _validateInstructionCount(
    Map<String, dynamic> stats,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    final count = stats['instructionCount'] as int;

    if (count == 0) {
      errors.add(const TransactionValidationError(
        type: 'instruction_count',
        message: 'Transaction must contain at least one instruction',
        code: 'EMPTY_TRANSACTION',
      ));
    } else if (count > 100) {
      warnings.add(TransactionValidationWarning(
        type: 'instruction_count',
        message:
            'High instruction count ($count) may increase transaction cost',
        context: {'count': count},
      ));
    }
  }

  /// Validate transaction size
  void _validateTransactionSize(
    Map<String, dynamic> stats,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    final size = stats['estimatedSize'] as int;

    if (size > _config.maxTransactionSize) {
      errors.add(TransactionValidationError(
        type: 'transaction_size',
        message:
            'Transaction size ($size bytes) exceeds limit (${_config.maxTransactionSize} bytes)',
        code: 'SIZE_EXCEEDED',
        context: {'size': size, 'limit': _config.maxTransactionSize},
      ));
    } else if (size > _config.maxTransactionSize * 0.8) {
      warnings.add(TransactionValidationWarning(
        type: 'transaction_size',
        message:
            'Transaction size ($size bytes) is approaching limit (${_config.maxTransactionSize} bytes)',
        context: {'size': size, 'limit': _config.maxTransactionSize},
      ));
    }
  }

  /// Validate compute budget
  void _validateComputeBudget(
    Map<String, dynamic> stats,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    final estimatedUnits = _estimateComputeUnits(stats);

    if (estimatedUnits > _config.maxComputeUnits) {
      errors.add(TransactionValidationError(
        type: 'compute_budget',
        message:
            'Estimated compute units ($estimatedUnits) exceed limit (${_config.maxComputeUnits})',
        code: 'COMPUTE_EXCEEDED',
        context: {
          'estimated': estimatedUnits,
          'limit': _config.maxComputeUnits
        },
      ));
    } else if (estimatedUnits > _config.maxComputeUnits * 0.8) {
      warnings.add(TransactionValidationWarning(
        type: 'compute_budget',
        message: 'Estimated compute units ($estimatedUnits) are high',
        context: {'estimated': estimatedUnits},
      ));
    }
  }

  /// Validate accounts
  void _validateAccounts(
    Map<String, dynamic> stats,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    final accountCount = stats['uniqueAccounts'] as int;
    final signerCount = stats['signerAccounts'] as int;

    if (accountCount > 64) {
      warnings.add(TransactionValidationWarning(
        type: 'account_count',
        message:
            'High account count ($accountCount) may increase transaction cost',
        context: {'count': accountCount},
      ));
    }

    if (signerCount > 10) {
      warnings.add(TransactionValidationWarning(
        type: 'signer_count',
        message:
            'High signer count ($signerCount) may complicate signing process',
        context: {'count': signerCount},
      ));
    }
  }

  /// Validate transaction structure
  void _validateTransactionStructure(
    tx_types.Transaction transaction,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    // Validate blockhash
    if (transaction.recentBlockhash == null ||
        transaction.recentBlockhash!.isEmpty) {
      errors.add(const TransactionValidationError(
        type: 'blockhash',
        message: 'Transaction must have a recent blockhash',
        code: 'MISSING_BLOCKHASH',
      ));
    }

    // Validate fee payer
    if (transaction.feePayer == null) {
      errors.add(const TransactionValidationError(
        type: 'fee_payer',
        message: 'Transaction must have a fee payer',
        code: 'MISSING_FEE_PAYER',
      ));
    }

    // Validate instructions
    if (transaction.instructions.isEmpty) {
      errors.add(const TransactionValidationError(
        type: 'instructions',
        message: 'Transaction must have at least one instruction',
        code: 'EMPTY_INSTRUCTIONS',
      ));
    }
  }

  /// Validate transaction instructions
  void _validateTransactionInstructions(
    tx_types.Transaction transaction,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    for (int i = 0; i < transaction.instructions.length; i++) {
      final instruction = transaction.instructions[i];

      // Validate program ID
      if (instruction.programId.toString().isEmpty) {
        errors.add(TransactionValidationError(
          type: 'instruction_program_id',
          message: 'Instruction $i has invalid program ID',
          code: 'INVALID_PROGRAM_ID',
          context: {'index': i},
        ));
      }

      // Validate instruction data
      if (instruction.data.isEmpty) {
        warnings.add(TransactionValidationWarning(
          type: 'instruction_data',
          message: 'Instruction $i has empty data',
          context: {'index': i},
        ));
      }
    }
  }

  /// Validate transaction signers
  void _validateTransactionSigners(
    tx_types.Transaction transaction,
    List<TransactionValidationError> errors,
    List<TransactionValidationWarning> warnings,
  ) {
    // Check for duplicate signers
    final signerSet = <PublicKey>{};
    final duplicates = <PublicKey>[];

    for (final signer in transaction.signers) {
      if (signerSet.contains(signer)) {
        duplicates.add(signer);
      } else {
        signerSet.add(signer);
      }
    }

    if (duplicates.isNotEmpty) {
      warnings.add(TransactionValidationWarning(
        type: 'duplicate_signers',
        message:
            'Transaction has duplicate signers: ${duplicates.map((s) => s.toString()).join(', ')}',
        context: {'duplicates': duplicates.map((s) => s.toString()).toList()},
      ));
    }
  }

  /// Estimate compute units for transaction stats
  int _estimateComputeUnits(Map<String, dynamic> stats) {
    final instructionCount = stats['instructionCount'] as int;
    final accountCount = stats['uniqueAccounts'] as int;

    // Simple estimation: base cost + per instruction + per account
    return 5000 + (instructionCount * 1000) + (accountCount * 100);
  }

  /// Calculate transaction metrics
  TransactionValidationMetrics _calculateTransactionMetrics(
    tx_types.Transaction transaction,
    int validationTimeMs,
  ) {
    // Count unique accounts
    final uniqueAccounts = <PublicKey>{};
    final signerAccounts = <PublicKey>{};

    if (transaction.feePayer != null) {
      uniqueAccounts.add(transaction.feePayer!);
      signerAccounts.add(transaction.feePayer!);
    }

    for (final instruction in transaction.instructions) {
      uniqueAccounts.add(instruction.programId);
      for (final account in instruction.accounts) {
        uniqueAccounts.add(account.pubkey);
        if (account.isSigner) {
          signerAccounts.add(account.pubkey);
        }
      }
    }

    // Estimate size (simplified)
    final estimatedSize = 100 +
        (uniqueAccounts.length * 32) +
        transaction.instructions
            .fold<int>(0, (sum, ix) => sum + ix.data.length + 10);

    return TransactionValidationMetrics(
      estimatedSize: estimatedSize,
      instructionCount: transaction.instructions.length,
      accountCount: uniqueAccounts.length,
      signerCount: signerAccounts.length,
      estimatedComputeUnits: _estimateComputeUnits({
        'instructionCount': transaction.instructions.length,
        'uniqueAccounts': uniqueAccounts.length,
      }),
      validationTimeMs: validationTimeMs,
    );
  }
}
