/// Transaction Builder for Dart Coral XYZ Anchor Client
///
/// This module provides the transaction building functionality including:
/// - Multiple instruction support
/// - Fee calculation
/// - Transaction size optimization
/// - Simulation support
/// - Confirmation tracking

library;

import 'dart:typed_data';

import '../types/transaction.dart' as transaction_types;
import '../types/public_key.dart';
import '../provider/anchor_provider.dart';
import 'namespace/types.dart';
import '../error/rpc_error_parser.dart';

/// Builds and manages Solana transactions
class TransactionBuilder {
  final AnchorProvider _provider;
  final List<TransactionInstruction> _instructions = [];
  final List<PublicKey> _signers = [];
  String? _recentBlockhash;

  /// Create a new transaction builder
  TransactionBuilder({
    required AnchorProvider provider,
  }) : _provider = provider;

  /// Add an instruction to the transaction
  TransactionBuilder add(TransactionInstruction instruction) {
    _instructions.add(instruction);
    return this;
  }

  /// Add multiple instructions to the transaction
  TransactionBuilder addAll(List<TransactionInstruction> instructions) {
    _instructions.addAll(instructions);
    return this;
  }

  /// Add a signer to the transaction
  TransactionBuilder addSigner(PublicKey signer) {
    if (!_signers.contains(signer)) {
      _signers.add(signer);
    }
    return this;
  }

  /// Set whether this is a simulation
  TransactionBuilder simulation(bool simulation) {
    // Simulation flag can be stored but is not currently used
    return this;
  }

  /// Calculate the transaction fee based on current network conditions
  Future<int> calculateFee() async {
    // For now, return a fixed fee estimate
    // In a real implementation, this would calculate based on instruction complexity
    return 5000 * (_signers.length + 1); // 5000 lamports per signature
  }

  /// Ensure accounts are ordered correctly
  List<transaction_types.AccountMeta> _orderAccounts(
      List<transaction_types.AccountMeta> accounts) {
    final writableSigners =
        accounts.where((acc) => acc.isSigner && acc.isWritable).toList();
    final readonlySigners =
        accounts.where((acc) => acc.isSigner && !acc.isWritable).toList();
    final writableNonSigners =
        accounts.where((acc) => !acc.isSigner && acc.isWritable).toList();
    final readonlyNonSigners =
        accounts.where((acc) => !acc.isSigner && !acc.isWritable).toList();

    return [
      ...writableSigners,
      ...readonlySigners,
      ...writableNonSigners,
      ...readonlyNonSigners
    ];
  }

  /// Build the transaction
  Future<transaction_types.Transaction> build() async {
    if (_instructions.isEmpty) {
      throw Exception('No instructions added to transaction');
    }

    // Get recent blockhash if not already set
    if (_recentBlockhash == null) {
      final blockhashResult = await _provider.connection.getLatestBlockhash();
      _recentBlockhash = blockhashResult.blockhash;
    }

    // Create transaction with instructions
    final tx = transaction_types.Transaction(
      feePayer: _provider.publicKey,
      recentBlockhash: _recentBlockhash,
      instructions: _instructions
          .map((ix) => transaction_types.TransactionInstruction(
                programId: ix.programId,
                accounts: _orderAccounts(ix.accounts
                    .map((acc) => transaction_types.AccountMeta(
                          pubkey: acc.publicKey,
                          isSigner: acc.isSigner,
                          isWritable: acc.isWritable,
                        ))
                    .toList()),
                data: Uint8List.fromList(ix.data),
              ))
          .toList(),
    );

    return tx;
  }

  /// Sign and send the transaction
  Future<String> send() async {
    try {
      final tx = await build();
      return await _provider.sendAndConfirm(tx);
    } catch (e) {
      // Use RpcErrorParser to enhance error information
      final enhancedError = translateRpcError(e);
      throw enhancedError;
    }
  }
}
