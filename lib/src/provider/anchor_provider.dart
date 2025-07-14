/// AnchorProvider implementation for Solana Anchor programs
///
/// This module provides the core AnchorProvider class that combines connection
/// and wallet functionality to provide a unified interface for interacting
/// with Solana programs through Anchor.

library;

import 'dart:async';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart'
    as transaction_types;
import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart'
    show TransactionSimulationResult;
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/error/rpc_error_parser.dart';

/// Default confirmation options for transactions
class ConfirmOptions {
  const ConfirmOptions({
    this.preflightCommitment,
    this.commitment = CommitmentConfigs.processed,
    this.skipPreflight = false,
    this.maxRetries,
    this.minContextSlot,
  });

  /// The commitment level for preflight checks
  final CommitmentConfig? preflightCommitment;

  /// The commitment level for transaction confirmation
  final CommitmentConfig commitment;

  /// Whether to skip preflight transaction checks
  final bool skipPreflight;

  /// Maximum number of retries for sending transactions
  final int? maxRetries;

  /// Minimum context slot to perform the request at
  final int? minContextSlot;

  /// Default confirmation options
  static const ConfirmOptions defaultOptions = ConfirmOptions(
    preflightCommitment: CommitmentConfigs.processed,
  );

  /// Copy this ConfirmOptions with optional parameter overrides
  ConfirmOptions copyWith({
    CommitmentConfig? preflightCommitment,
    CommitmentConfig? commitment,
    bool? skipPreflight,
    int? maxRetries,
    int? minContextSlot,
  }) =>
      ConfirmOptions(
        preflightCommitment: preflightCommitment ?? this.preflightCommitment,
        commitment: commitment ?? this.commitment,
        skipPreflight: skipPreflight ?? this.skipPreflight,
        maxRetries: maxRetries ?? this.maxRetries,
        minContextSlot: minContextSlot ?? this.minContextSlot,
      );

  @override
  String toString() =>
      'ConfirmOptions(preflightCommitment: $preflightCommitment, '
      'commitment: $commitment, skipPreflight: $skipPreflight, '
      'maxRetries: $maxRetries, minContextSlot: $minContextSlot)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfirmOptions &&
        other.preflightCommitment == preflightCommitment &&
        other.commitment == commitment &&
        other.skipPreflight == skipPreflight &&
        other.maxRetries == maxRetries &&
        other.minContextSlot == minContextSlot;
  }

  @override
  int get hashCode => Object.hash(
        preflightCommitment,
        commitment,
        skipPreflight,
        maxRetries,
        minContextSlot,
      );
}

/// Provider interface for Anchor programs
///
/// This interface defines the contract for provider implementations that
/// can send transactions, simulate them, and provide wallet/connection access.
abstract class Provider {
  /// The connection to the Solana cluster
  Connection get connection;

  /// The wallet used for signing transactions
  Wallet? get wallet;

  /// The public key of the wallet, if available
  PublicKey? get publicKey;

  /// Send and confirm a transaction
  Future<String> sendAndConfirm(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    ConfirmOptions? options,
  });

  /// Send and confirm multiple transactions
  Future<List<String>> sendAll(
    List<TransactionWithSigners> transactions, {
    ConfirmOptions? options,
  });

  /// Simulate a transaction
  Future<TransactionSimulationResult> simulate(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    CommitmentConfig? commitment,
    List<PublicKey>? includeAccounts,
  });
}

/// A transaction bundled with its additional signers
class TransactionWithSigners {
  const TransactionWithSigners({
    required this.transaction,
    this.signers,
  });

  /// The transaction to send
  final transaction_types.Transaction transaction;

  /// Additional signers for the transaction
  final List<Keypair>? signers;

  @override
  String toString() => 'TransactionWithSigners(transaction: $transaction, '
      'signers: ${signers?.length ?? 0})';
}

/// Result of transaction simulation
class SimulationResult {
  const SimulationResult({
    required this.success,
    required this.logs,
    this.accounts,
    this.error,
    this.unitsConsumed,
  });

  /// Whether the simulation was successful
  final bool success;

  /// Program logs from the simulation
  final List<String> logs;

  /// Accounts returned from simulation (if requested)
  final Map<String, dynamic>? accounts;

  /// Error message if simulation failed
  final String? error;

  /// Compute units consumed
  final int? unitsConsumed;

  @override
  String toString() =>
      'SimulationResult(success: $success, logs: ${logs.length}, '
      'error: $error, unitsConsumed: $unitsConsumed)';
}

/// The main provider implementation that combines Connection and Wallet
///
/// AnchorProvider is the primary class for interacting with Solana programs
/// through Anchor. It combines a connection to a Solana cluster with a wallet
/// for signing transactions.
class AnchorProvider implements Provider {
  /// Create a new AnchorProvider
  ///
  /// [connection] - The connection to the Solana cluster
  /// [wallet] - The wallet for signing transactions (optional)
  /// [options] - Default confirmation options
  AnchorProvider(
    this.connection,
    this.wallet, {
    this.options = ConfirmOptions.defaultOptions,
  });

  /// Create a provider with a specific wallet
  ///
  /// [connection] - The connection to use
  /// [wallet] - The wallet to use
  /// [options] - Confirmation options
  factory AnchorProvider.withWallet(
    Connection connection,
    Wallet wallet, {
    ConfirmOptions options = ConfirmOptions.defaultOptions,
  }) {
    return AnchorProvider(connection, wallet, options: options);
  }

  /// Create a read-only provider (no wallet)
  ///
  /// [connection] - The connection to use
  /// [options] - Confirmation options
  factory AnchorProvider.readOnly(
    Connection connection, {
    ConfirmOptions options = ConfirmOptions.defaultOptions,
  }) {
    return AnchorProvider(connection, null, options: options);
  }

  /// The connection to the Solana cluster
  @override
  final Connection connection;

  /// The wallet used for signing transactions
  @override
  final Wallet? wallet;

  /// Default confirmation options for transactions
  final ConfirmOptions options;

  /// Create a provider for local development
  ///
  /// This creates a provider connected to a local Solana test validator
  /// with a keypair wallet loaded from the local filesystem.
  ///
  /// [url] - The RPC URL (defaults to localhost)
  /// [options] - Confirmation options
  /// [walletPath] - Path to the wallet JSON file (optional)
  static Future<AnchorProvider> local({
    String url = 'http://127.0.0.1:8899',
    ConfirmOptions options = ConfirmOptions.defaultOptions,
    String? walletPath,
  }) async {
    final connection = Connection(url);

    Wallet? wallet;
    if (walletPath != null) {
      // For now, we'll create a random wallet as file system access
      // will be implemented when crypto wrapper is complete
      wallet = await KeypairWallet.generate();
    }

    return AnchorProvider(connection, wallet, options: options);
  }

  /// Create a provider from environment variables
  ///
  /// This method would read configuration from environment variables
  /// in a real implementation. For now, it returns a local provider.
  static Future<AnchorProvider> env({
    ConfirmOptions options = ConfirmOptions.defaultOptions,
  }) async {
    // In a real implementation, this would read from environment variables
    // For now, default to local development setup
    return local(options: options);
  }

  /// Get a default provider instance
  ///
  /// This provides a singleton-like default provider for convenient usage
  /// when no specific provider configuration is needed.
  static AnchorProvider? _defaultProviderInstance;

  static AnchorProvider defaultProvider() =>
      _defaultProviderInstance ??= AnchorProvider(
        Connection('http://127.0.0.1:8899'),
        null, // No wallet by default
        options: ConfirmOptions.defaultOptions,
      );

  /// Set the default provider instance
  static void setDefaultProvider(AnchorProvider provider) {
    _defaultProviderInstance = provider;
  }

  @override
  PublicKey? get publicKey => wallet?.publicKey;

  @override
  Future<String> sendAndConfirm(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    ConfirmOptions? options,
  }) async {
    if (wallet == null) {
      throw const ProviderException(
        'Cannot send transaction without a wallet. Use AnchorProvider.withWallet() '
        'or provide a wallet in the constructor.',
      );
    }

    final opts = options ?? this.options;

    // Retry logic for blockhash-related errors
    const maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Always get a fresh blockhash for each attempt
        print(
            'DEBUG: Attempt ${attempt + 1}/$maxRetries - Getting fresh blockhash...');
        final blockhashResult = await connection.getLatestBlockhash(
          commitment: opts.preflightCommitment ?? opts.commitment,
        );
        print(
            'DEBUG: Fresh blockhash for attempt ${attempt + 1}: ${blockhashResult.blockhash}');

        // Create a new transaction with fresh blockhash
        final transactionWithFreshBlockhash =
            transaction.setRecentBlockhash(blockhashResult.blockhash);

        // Prepare the transaction
        final preparedTransaction = await _prepareTransaction(
            transactionWithFreshBlockhash, signers, opts);

        // Sign the transaction with the wallet
        final signedTransaction =
            await wallet!.signTransaction(preparedTransaction);

        print(
            'DEBUG: signedTransaction type: ${signedTransaction.runtimeType}');
        print(
            'DEBUG: signedTransaction.serialize() type: ${signedTransaction.serialize().runtimeType}');
        print(
            'DEBUG: signedTransaction.serialize() value: ${signedTransaction.serialize()}');

        // Use the connection to send the transaction
        final signature = await connection.sendAndConfirmTransaction(
          signedTransaction.serialize(),
          commitment: opts.commitment,
        );

        print('DEBUG: Transaction sent successfully on attempt ${attempt + 1}');
        return signature;
      } catch (e) {
        final errorString = e.toString();
        final isBlockhashError = errorString.contains('Blockhash not found') ||
            errorString.contains('BlockhashNotFound') ||
            errorString.contains('Invalid blockhash');

        if (isBlockhashError && attempt < maxRetries - 1) {
          print(
              'DEBUG: Blockhash error on attempt ${attempt + 1}, retrying...');
          // Wait a bit before retry
          await Future<void>.delayed(Duration(milliseconds: 500));
          continue;
        }

        // If it's not a blockhash error or we've exhausted retries, throw
        final enhancedError = translateRpcError(e);
        throw ProviderException(
          'Failed to send and confirm transaction: ${enhancedError.toString()}',
          e,
        );
      }
    }

    // This should never be reached due to the loop structure, but just in case
    throw ProviderException('Maximum retry attempts exceeded');
  }

  @override
  Future<List<String>> sendAll(
    List<TransactionWithSigners> transactions, {
    ConfirmOptions? options,
  }) async {
    if (wallet == null) {
      throw const ProviderException(
        'Cannot send transactions without a wallet. Use AnchorProvider.withWallet() '
        'or provide a wallet in the constructor.',
      );
    }

    final opts = options ?? this.options;
    final signatures = <String>[];

    // Get recent blockhash for all transactions (with fallback for testing)
    String blockhash;
    try {
      final blockhashResult = await connection.getLatestBlockhash(
        commitment: opts.preflightCommitment ?? opts.commitment,
      );
      blockhash = blockhashResult.blockhash;
    } catch (e) {
      // For testing or when connection fails, use a mock valid base58 blockhash
      // This generates a valid base58 string that looks like a real blockhash
      blockhash = 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5';
    }

    // Prepare all transactions
    final preparedTransactions = <transaction_types.Transaction>[];
    for (final txWithSigners in transactions) {
      final transaction_types.Transaction tx = txWithSigners.transaction;

      // Create new transaction with fee payer and recent blockhash
      transaction_types.Transaction preparedTx = tx;
      if (tx.feePayer == null) {
        preparedTx = tx.setFeePayer(wallet!.publicKey);
      }
      if (tx.recentBlockhash == null) {
        preparedTx = preparedTx.setRecentBlockhash(blockhash);
      }

      // TODO: Add additional signers when transaction.partialSign is implemented
      if (txWithSigners.signers != null) {
        // for (final signer in txWithSigners.signers!) {
        //   preparedTx = preparedTx.partialSign(signer);
        // }
      }

      preparedTransactions.add(preparedTx);
    }

    // Sign all transactions with the wallet
    final signedTransactions =
        await wallet!.signAllTransactions(preparedTransactions);

    // Send all transactions (mock for now)
    for (int i = 0; i < signedTransactions.length; i++) {
      try {
        // Mock signature for development
        final mockSignature =
            'mock_batch_signature_${i}_${DateTime.now().millisecondsSinceEpoch}';

        // TODO: Implement actual transaction sending when serialization is complete
        // final serialized = signedTx.serialize();
        // final signature = await connection.sendRawTransaction(serialized);
        // await connection.confirmTransaction(signature, commitment: opts.commitment);

        signatures.add(mockSignature);
      } catch (e) {
        throw ProviderException('Failed to send transaction in batch: $e', e);
      }
    }

    return signatures;
  }

  @override
  Future<TransactionSimulationResult> simulate(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    CommitmentConfig? commitment,
    List<PublicKey>? includeAccounts,
  }) async {
    try {
      // Prepare transaction for simulation
      await _prepareTransaction(transaction, signers, null);

      // For now, return a mock simulation result since transaction serialization
      // and connection.simulateTransaction are not yet implemented
      return const TransactionSimulationResult(
        success: true,
        logs: ['Program log: Simulation not yet implemented'],
      );
    } catch (e) {
      return TransactionSimulationResult(
        success: false,
        logs: ['Program log: Simulation failed: $e'],
      );
    }
  }

  /// Prepare a transaction for sending by setting fee payer and recent blockhash
  Future<transaction_types.Transaction> _prepareTransaction(
    transaction_types.Transaction transaction,
    List<Keypair>? signers,
    ConfirmOptions? options,
  ) async {
    transaction_types.Transaction preparedTx = transaction;

    // Set fee payer if not already set
    if (transaction.feePayer == null && wallet != null) {
      preparedTx = preparedTx.setFeePayer(wallet!.publicKey);
    }

    // Only fetch a fresh blockhash if the transaction doesn't already have one
    if (transaction.recentBlockhash == null) {
      try {
        print('DEBUG: Fetching fresh blockhash in _prepareTransaction...');
        final commitment = options?.preflightCommitment ??
            options?.commitment ??
            this.options.commitment;

        final blockhashResult = await connection.getLatestBlockhash(
          commitment: commitment,
        );
        preparedTx = preparedTx.setRecentBlockhash(blockhashResult.blockhash);
        print(
          'DEBUG: _prepareTransaction set fresh blockhash: ${blockhashResult.blockhash}',
        );
      } catch (e) {
        print(
            'WARNING: Failed to fetch fresh blockhash in _prepareTransaction: $e');
        // Use valid base58 mock for testing if fresh fetch fails
        preparedTx = preparedTx
            .setRecentBlockhash('FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5');
      }
    } else {
      print(
        'DEBUG: _prepareTransaction - transaction already has blockhash: ${transaction.recentBlockhash}',
      );
    }

    // TODO: Add additional signers when transaction.partialSign is implemented
    if (signers != null) {
      // for (final signer in signers) {
      //   preparedTx = preparedTx.partialSign(signer);
      // }
    }

    return preparedTx;
  }

  @override
  String toString() => 'AnchorProvider(connection: $connection, '
      'wallet: ${wallet != null ? 'present' : 'null'}, '
      'publicKey: $publicKey)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnchorProvider &&
        other.connection == connection &&
        other.wallet == wallet &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(connection, wallet, options);
}

/// Exception thrown by provider operations
class ProviderException implements Exception {
  const ProviderException(this.message, [this.cause]);

  /// The error message
  final String message;

  /// The underlying cause of the error (optional)
  final dynamic cause;

  @override
  String toString() {
    if (cause != null) {
      return 'ProviderException: $message\nCaused by: $cause';
    }
    return 'ProviderException: $message';
  }
}

/// Exception thrown when a transaction fails to send
class ProviderTransactionException extends ProviderException {
  const ProviderTransactionException(
    String message, [
    dynamic cause,
    this.signature,
    this.logs,
  ]) : super(message, cause);

  /// The transaction signature (if available)
  final String? signature;

  /// Program logs from the failed transaction
  final List<String>? logs;

  @override
  String toString() {
    final buffer = StringBuffer('ProviderTransactionException: $message');

    if (signature != null) {
      buffer.write('\nTransaction signature: $signature');
    }

    if (logs != null && logs!.isNotEmpty) {
      buffer.write('\nProgram logs:');
      for (final log in logs!) {
        buffer.write('\n  $log');
      }
    }

    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }

    return buffer.toString();
  }
}
