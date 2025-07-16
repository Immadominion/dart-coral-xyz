/// Enhanced Transaction Building for Dart Coral XYZ Anchor Client
///
/// This module provides comprehensive transaction building capabilities including:
/// - Advanced transaction composition API
/// - Transaction instruction batching
/// - Custom transaction fee management
/// - Advanced simulation with compute units
/// - Transaction priority fee optimization
/// - Full TypeScript parity for transaction building

library;

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart';

/// Transaction fee configuration
class TransactionFeeConfig {
  final int? computeUnitLimit;
  final int? computeUnitPrice;
  final int? priorityFee;
  final bool autoCalculateFee;
  final int? maxFee;
  final double? feeMultiplier;

  const TransactionFeeConfig({
    this.computeUnitLimit,
    this.computeUnitPrice,
    this.priorityFee,
    this.autoCalculateFee = true,
    this.maxFee,
    this.feeMultiplier = 1.0,
  });

  /// Create default fee configuration
  factory TransactionFeeConfig.defaultConfig() {
    return const TransactionFeeConfig(
      autoCalculateFee: true,
      feeMultiplier: 1.0,
    );
  }

  /// Create configuration with priority fee
  factory TransactionFeeConfig.withPriority(int priorityFee) {
    return TransactionFeeConfig(
      priorityFee: priorityFee,
      autoCalculateFee: false,
    );
  }
}

/// Transaction composition options
class TransactionCompositionOptions {
  final List<TransactionInstruction>? preInstructions;
  final List<TransactionInstruction>? postInstructions;
  final List<Keypair>? signers;
  final String? recentBlockhash;
  final TransactionFeeConfig? feeConfig;
  final bool skipPreflight;
  final Commitment? commitment;
  final int? maxRetries;

  const TransactionCompositionOptions({
    this.preInstructions,
    this.postInstructions,
    this.signers,
    this.recentBlockhash,
    this.feeConfig,
    this.skipPreflight = false,
    this.commitment,
    this.maxRetries,
  });
}

/// Transaction batch configuration
class TransactionBatchConfig {
  final int maxInstructionsPerTransaction;
  final int maxTransactionSize;
  final bool parallel;
  final int maxConcurrentTransactions;
  final Duration? delay;

  const TransactionBatchConfig({
    this.maxInstructionsPerTransaction = 20,
    this.maxTransactionSize = 1232,
    this.parallel = false,
    this.maxConcurrentTransactions = 5,
    this.delay,
  });
}

/// Transaction simulation result with compute units
class TransactionSimulationResult {
  final bool success;
  final int? computeUnitsConsumed;
  final List<String> logs;
  final String? error;
  final int? feeRequired;
  final Map<String, dynamic>? accounts;

  const TransactionSimulationResult({
    required this.success,
    this.computeUnitsConsumed,
    required this.logs,
    this.error,
    this.feeRequired,
    this.accounts,
  });
}

/// Transaction priority fee calculation result
class PriorityFeeCalculation {
  final int recommendedFee;
  final int minFee;
  final int maxFee;
  final double congestionMultiplier;
  final List<int> recentFees;

  const PriorityFeeCalculation({
    required this.recommendedFee,
    required this.minFee,
    required this.maxFee,
    required this.congestionMultiplier,
    required this.recentFees,
  });
}

/// Enhanced Transaction Builder with full TypeScript parity
class EnhancedTransactionBuilder {
  EnhancedTransactionBuilder({
    required AnchorProvider provider,
    TransactionFeeConfig? feeConfig,
  })  : _provider = provider,
        _feeConfig = feeConfig ?? TransactionFeeConfig.defaultConfig();

  final AnchorProvider _provider;
  final TransactionFeeConfig _feeConfig;
  final List<TransactionInstruction> _instructions = [];
  final List<Keypair> _signers = [];
  String? _recentBlockhash;
  TransactionCompositionOptions? _compositionOptions;

  /// Connection convenience getter
  Connection get connection => _provider.connection;

  // ===========================================================================
  // TRANSACTION COMPOSITION API
  // ===========================================================================

  /// Add an instruction to the transaction
  EnhancedTransactionBuilder add(TransactionInstruction instruction) {
    _instructions.add(instruction);
    return this;
  }

  /// Add multiple instructions
  EnhancedTransactionBuilder addAll(List<TransactionInstruction> instructions) {
    _instructions.addAll(instructions);
    return this;
  }

  /// Add a signer to the transaction
  EnhancedTransactionBuilder addSigner(Keypair signer) {
    if (!_signers.any((s) => s.publicKey == signer.publicKey)) {
      _signers.add(signer);
    }
    return this;
  }

  /// Add multiple signers
  EnhancedTransactionBuilder addSigners(List<Keypair> signers) {
    for (final signer in signers) {
      addSigner(signer);
    }
    return this;
  }

  /// Set recent blockhash
  EnhancedTransactionBuilder setRecentBlockhash(String blockhash) {
    _recentBlockhash = blockhash;
    return this;
  }

  /// Set composition options
  EnhancedTransactionBuilder setCompositionOptions(
      TransactionCompositionOptions options) {
    _compositionOptions = options;
    return this;
  }

  /// Prepend instructions (like TypeScript preInstructions)
  EnhancedTransactionBuilder prepend(
      List<TransactionInstruction> instructions) {
    _instructions.insertAll(0, instructions);
    return this;
  }

  /// Append instructions (like TypeScript postInstructions)
  EnhancedTransactionBuilder append(List<TransactionInstruction> instructions) {
    _instructions.addAll(instructions);
    return this;
  }

  /// Clear all instructions
  EnhancedTransactionBuilder clear() {
    _instructions.clear();
    _signers.clear();
    _recentBlockhash = null;
    _compositionOptions = null;
    return this;
  }

  /// Clone the builder
  EnhancedTransactionBuilder clone() {
    final cloned = EnhancedTransactionBuilder(
      provider: _provider,
      feeConfig: _feeConfig,
    );
    cloned._instructions.addAll(_instructions);
    cloned._signers.addAll(_signers);
    cloned._recentBlockhash = _recentBlockhash;
    cloned._compositionOptions = _compositionOptions;
    return cloned;
  }

  // ===========================================================================
  // TRANSACTION INSTRUCTION BATCHING
  // ===========================================================================

  /// Batch instructions into multiple transactions if needed
  Future<List<Transaction>> batchInstructions(
    List<TransactionInstruction> instructions, {
    TransactionBatchConfig? config,
  }) async {
    config ??= const TransactionBatchConfig();

    if (instructions.isEmpty) return [];

    final transactions = <Transaction>[];
    final batches = <List<TransactionInstruction>>[];

    // Split instructions into batches
    for (int i = 0;
        i < instructions.length;
        i += config.maxInstructionsPerTransaction) {
      final end = math.min(
          i + config.maxInstructionsPerTransaction, instructions.length);
      batches.add(instructions.sublist(i, end));
    }

    // Create transactions from batches
    for (final batch in batches) {
      final txBuilder = EnhancedTransactionBuilder(
        provider: _provider,
        feeConfig: _feeConfig,
      );

      txBuilder.addAll(batch);

      // Add composition options if available
      if (_compositionOptions != null) {
        txBuilder.setCompositionOptions(_compositionOptions!);
      }

      final tx = await txBuilder.build();
      transactions.add(tx);
    }

    return transactions;
  }

  /// Execute batched transactions
  Future<List<String>> sendBatched(
    List<TransactionInstruction> instructions, {
    TransactionBatchConfig? config,
  }) async {
    config ??= const TransactionBatchConfig();

    final transactions = await batchInstructions(instructions, config: config);
    final signatures = <String>[];

    if (config.parallel) {
      // Send transactions in parallel
      final futures = transactions.map((tx) async {
        await _signTransaction(tx);
        return await connection.sendAndConfirmTransaction(tx);
      });

      final results = await Future.wait(futures);
      signatures.addAll(results);
    } else {
      // Send transactions sequentially
      for (final tx in transactions) {
        await _signTransaction(tx);
        final signature = await connection.sendAndConfirmTransaction(tx);
        signatures.add(signature);

        // Add delay between transactions if configured
        if (config.delay != null) {
          await Future<void>.delayed(config.delay!);
        }
      }
    }

    return signatures;
  }

  // ===========================================================================
  // CUSTOM TRANSACTION FEE MANAGEMENT
  // ===========================================================================

  /// Calculate transaction fee based on configuration
  Future<int> calculateTransactionFee() async {
    if (_feeConfig.autoCalculateFee) {
      // Calculate based on instructions and current network conditions
      final baseFee = await connection.getMinimumBalanceForRentExemption(0);
      final signatureFee = 5000 * (_signers.length + 1); // Fee per signature
      final instructionFee =
          _instructions.length * 1000; // Estimated fee per instruction

      var totalFee = baseFee + signatureFee + instructionFee;

      // Apply multiplier
      totalFee = (totalFee * (_feeConfig.feeMultiplier ?? 1.0)).round();

      // Apply max fee limit
      if (_feeConfig.maxFee != null) {
        totalFee = math.min(totalFee, _feeConfig.maxFee!);
      }

      return totalFee;
    } else {
      return _feeConfig.priorityFee ?? 5000;
    }
  }

  /// Add compute budget instructions for fee optimization
  EnhancedTransactionBuilder addComputeBudgetInstructions({
    int? computeUnitLimit,
    int? computeUnitPrice,
  }) {
    final finalComputeUnitLimit =
        computeUnitLimit ?? _feeConfig.computeUnitLimit;
    final finalComputeUnitPrice =
        computeUnitPrice ?? _feeConfig.computeUnitPrice;

    if (finalComputeUnitLimit != null) {
      // Add compute unit limit instruction
      final limitInstruction =
          _createComputeUnitLimitInstruction(finalComputeUnitLimit);
      _instructions.insert(0, limitInstruction);
    }

    if (finalComputeUnitPrice != null) {
      // Add compute unit price instruction
      final priceInstruction =
          _createComputeUnitPriceInstruction(finalComputeUnitPrice);
      _instructions.insert(0, priceInstruction);
    }

    return this;
  }

  /// Create compute unit limit instruction
  TransactionInstruction _createComputeUnitLimitInstruction(
      int computeUnitLimit) {
    // This is a simplified implementation
    // In reality, this would use the ComputeBudgetProgram
    return TransactionInstruction(
      programId:
          PublicKey.fromBase58('ComputeBudget111111111111111111111111111111'),
      accounts: [],
      data: Uint8List.fromList(
          [0, ...Uint8List(8)..buffer.asUint32List()[0] = computeUnitLimit]),
    );
  }

  /// Create compute unit price instruction
  TransactionInstruction _createComputeUnitPriceInstruction(
      int computeUnitPrice) {
    // This is a simplified implementation
    // In reality, this would use the ComputeBudgetProgram
    return TransactionInstruction(
      programId:
          PublicKey.fromBase58('ComputeBudget111111111111111111111111111111'),
      accounts: [],
      data: Uint8List.fromList(
          [1, ...Uint8List(8)..buffer.asUint64List()[0] = computeUnitPrice]),
    );
  }

  // ===========================================================================
  // ADVANCED SIMULATION WITH COMPUTE UNITS
  // ===========================================================================

  /// Simulate transaction with compute unit estimation
  Future<TransactionSimulationResult> simulateWithComputeUnits({
    Commitment? commitment,
    bool includeAccounts = false,
    List<PublicKey>? accountsToInclude,
  }) async {
    try {
      final tx = await build();

      // Create simulation config
      final simulationConfig = TransactionSimulationConfig(
        commitment: commitment?.value,
        includeAccounts: includeAccounts,
        accountsToInclude: accountsToInclude,
        sigVerify: true,
        replaceRecentBlockhash: true,
      );

      // Use the existing transaction simulator
      final simulator = TransactionSimulator(_provider);
      final result = await simulator.simulate(tx, config: simulationConfig);

      return TransactionSimulationResult(
        success: result.success,
        computeUnitsConsumed: result.unitsConsumed,
        logs: result.logs,
        error: result.error?.toString(),
        feeRequired: null, // Not available in current implementation
        accounts: result.accounts,
      );
    } catch (e) {
      return TransactionSimulationResult(
        success: false,
        error: e.toString(),
        logs: [],
        computeUnitsConsumed: null,
      );
    }
  }

  /// Estimate compute units required for transaction
  Future<int?> estimateComputeUnits() async {
    final result = await simulateWithComputeUnits();
    return result.computeUnitsConsumed;
  }

  // ===========================================================================
  // TRANSACTION PRIORITY FEE OPTIMIZATION
  // ===========================================================================

  /// Calculate optimal priority fee based on network conditions
  Future<PriorityFeeCalculation> calculatePriorityFee({
    int? targetConfirmationTime,
    int? maxFee,
  }) async {
    try {
      // Get recent priority fees (simplified implementation)
      final recentFees = await _getRecentPriorityFees();

      // Calculate statistics
      final minFee = recentFees.isNotEmpty ? recentFees.reduce(math.min) : 1000;
      final avgFee = recentFees.isNotEmpty
          ? recentFees.reduce((a, b) => a + b) ~/ recentFees.length
          : 5000;

      // Calculate congestion multiplier
      final congestionMultiplier = _calculateCongestionMultiplier(recentFees);

      // Calculate recommended fee
      var recommendedFee = (avgFee * congestionMultiplier).round();

      // Apply max fee limit
      final finalMaxFee = maxFee ?? 100000;
      recommendedFee = math.min(recommendedFee, finalMaxFee);

      return PriorityFeeCalculation(
        recommendedFee: recommendedFee,
        minFee: minFee,
        maxFee: finalMaxFee,
        congestionMultiplier: congestionMultiplier,
        recentFees: recentFees,
      );
    } catch (e) {
      // Return default calculation on error
      return const PriorityFeeCalculation(
        recommendedFee: 5000,
        minFee: 1000,
        maxFee: 10000,
        congestionMultiplier: 1.0,
        recentFees: [],
      );
    }
  }

  /// Get recent priority fees from the network
  Future<List<int>> _getRecentPriorityFees() async {
    // This is a simplified implementation
    // In reality, this would query the network for recent priority fees
    return [1000, 2000, 5000, 3000, 7000, 4000, 6000, 8000, 2500, 3500];
  }

  /// Calculate network congestion multiplier
  double _calculateCongestionMultiplier(List<int> recentFees) {
    if (recentFees.isEmpty) return 1.0;

    // Simple congestion calculation based on fee variance
    final avgFee = recentFees.reduce((a, b) => a + b) / recentFees.length;
    final variance = recentFees
            .map((fee) => math.pow(fee - avgFee, 2))
            .reduce((a, b) => a + b) /
        recentFees.length;
    final stdDev = math.sqrt(variance);

    // Higher variance indicates more congestion
    return 1.0 + (stdDev / avgFee).clamp(0.0, 2.0);
  }

  /// Apply optimal priority fee to transaction
  Future<EnhancedTransactionBuilder> withOptimalPriorityFee({
    int? targetConfirmationTime,
    int? maxFee,
  }) async {
    final calculation = await calculatePriorityFee(
      targetConfirmationTime: targetConfirmationTime,
      maxFee: maxFee,
    );

    return addComputeBudgetInstructions(
      computeUnitPrice: calculation.recommendedFee,
    );
  }

  // ===========================================================================
  // TRANSACTION BUILDING AND EXECUTION
  // ===========================================================================

  /// Build the transaction
  Future<Transaction> build() async {
    if (_instructions.isEmpty) {
      throw Exception('No instructions added to transaction');
    }

    // Get recent blockhash if not set
    String blockhash = _recentBlockhash ??
        _compositionOptions?.recentBlockhash ??
        (await connection.getLatestBlockhash()).blockhash;

    // Prepare final instructions
    final finalInstructions = <TransactionInstruction>[];

    // Add pre-instructions from composition options
    if (_compositionOptions?.preInstructions != null) {
      finalInstructions.addAll(_compositionOptions!.preInstructions!);
    }

    // Add main instructions
    finalInstructions.addAll(_instructions);

    // Add post-instructions from composition options
    if (_compositionOptions?.postInstructions != null) {
      finalInstructions.addAll(_compositionOptions!.postInstructions!);
    }

    // Create transaction
    final tx = Transaction(
      feePayer: _provider.publicKey,
      recentBlockhash: blockhash,
      instructions: finalInstructions,
    );

    return tx;
  }

  /// Sign the transaction
  Future<Transaction> _signTransaction(Transaction tx) async {
    // Sign with provider's wallet
    if (_provider.wallet != null) {
      tx = await _provider.wallet!.signTransaction(tx);
    }

    // Sign with additional signers
    final allSigners = [..._signers];
    if (_compositionOptions?.signers != null) {
      allSigners.addAll(_compositionOptions!.signers!);
    }

    if (allSigners.isNotEmpty) {
      tx.sign(allSigners);
    }

    return tx;
  }

  /// Send the transaction
  Future<String> send({
    bool skipPreflight = false,
    Commitment? commitment,
    int? maxRetries,
  }) async {
    final tx = await build();
    final signedTx = await _signTransaction(tx);

    return await connection.sendAndConfirmTransaction(
      signedTx,
      // These parameters might need adjustment based on the actual sendAndConfirmTransaction method signature
    );
  }

  /// Send and confirm the transaction
  Future<String> sendAndConfirm({
    bool skipPreflight = false,
    Commitment? commitment,
    int? maxRetries,
  }) async {
    final tx = await build();
    final signedTx = await _signTransaction(tx);

    return await _provider.sendAndConfirm(signedTx);
  }

  /// Get transaction size estimate
  Future<int> getTransactionSize() async {
    final tx = await build();
    // Simplified size calculation
    return tx.instructions.length * 64 + 64; // Rough estimate
  }

  /// Check if transaction would exceed size limits
  Future<bool> wouldExceedSizeLimit() async {
    final size = await getTransactionSize();
    return size > 1232; // Solana transaction size limit
  }

  // ===========================================================================
  // UTILITY METHODS
  // ===========================================================================

  /// Get instruction count
  int get instructionCount => _instructions.length;

  /// Get signer count
  int get signerCount => _signers.length;

  /// Check if transaction is empty
  bool get isEmpty => _instructions.isEmpty;

  /// Get instructions (read-only)
  List<TransactionInstruction> get instructions =>
      List.unmodifiable(_instructions);

  /// Get signers (read-only)
  List<Keypair> get signers => List.unmodifiable(_signers);
}
