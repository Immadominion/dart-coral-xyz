import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/program/namespace/simulate_namespace.dart';

/// Type definitions for namespace generation system
///
/// This module contains type definitions and utilities used by the
/// namespace generation system to create type-safe program interfaces.

/// All instructions for an IDL
typedef AllInstructions<I extends Idl> = List<IdlInstruction>;

/// Returns a type map of instruction name to the IdlInstruction
typedef InstructionMap<I extends List<IdlInstruction>>
    = Map<String, IdlInstruction>;

/// All accounts for an IDL
typedef AllAccounts<I extends Idl> = List<IdlAccount>;

/// Returns a type map of account name to the IdlAccount
typedef AccountMap<I extends List<IdlAccount>> = Map<String, IdlAccount>;

/// All events for an IDL
typedef AllEvents<I extends Idl> = List<IdlEvent>;

/// Context for instruction execution
class Context<T> {

  const Context({
    required this.accounts,
    this.remainingAccounts,
    this.signers,
    this.preInstructions,
    this.postInstructions,
  });
  /// The accounts required for the instruction
  final T accounts;

  /// Additional accounts that may be needed
  final List<AccountMeta>? remainingAccounts;

  /// Signers for the instruction
  final List<Signer>? signers;

  /// Instructions to run before this one
  final List<TransactionInstruction>? preInstructions;

  /// Instructions to run after this one
  final List<TransactionInstruction>? postInstructions;
}

/// Account meta for instruction execution
class AccountMeta {

  const AccountMeta({
    required this.publicKey,
    required this.isWritable,
    required this.isSigner,
  });
  /// The public key of the account
  final PublicKey publicKey;

  /// Whether the account is writable
  final bool isWritable;

  /// Whether the account is a signer
  final bool isSigner;

  @override
  String toString() => 'AccountMeta(publicKey: $publicKey, isWritable: $isWritable, isSigner: $isSigner)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AccountMeta &&
        other.publicKey == publicKey &&
        other.isWritable == isWritable &&
        other.isSigner == isSigner;
  }

  @override
  int get hashCode => Object.hash(publicKey, isWritable, isSigner);
}

/// Signer interface for accounts that can sign transactions
abstract class Signer {
  /// The public key of the signer
  PublicKey get publicKey;

  /// Sign the given message
  Future<List<int>> signMessage(List<int> message);
}

/// Transaction instruction for Solana programs
class TransactionInstruction {

  const TransactionInstruction({
    required this.programId,
    required this.accounts,
    required this.data,
  });
  /// The program ID that owns this instruction
  final PublicKey programId;

  /// The accounts required for this instruction
  final List<AccountMeta> accounts;

  /// The instruction data
  final List<int> data;

  @override
  String toString() => 'TransactionInstruction(programId: $programId, '
        'accounts: ${accounts.length}, data: ${data.length} bytes)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionInstruction &&
        other.programId == programId &&
        _listEquals(other.accounts, accounts) &&
        _listEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hash(programId, accounts, data);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Transaction containing multiple instructions
class AnchorTransaction {

  const AnchorTransaction({
    this.feePayer,
    this.recentBlockhash,
    required this.instructions,
  });
  /// The fee payer for this transaction
  final PublicKey? feePayer;

  /// The recent blockhash for this transaction
  final String? recentBlockhash;

  /// The instructions in this transaction
  final List<TransactionInstruction> instructions;

  /// Create a new transaction with a fee payer
  AnchorTransaction setFeePayer(PublicKey feePayer) => AnchorTransaction(
      feePayer: feePayer,
      recentBlockhash: recentBlockhash,
      instructions: instructions,
    );

  /// Create a new transaction with a recent blockhash
  AnchorTransaction setRecentBlockhash(String blockhash) => AnchorTransaction(
      feePayer: feePayer,
      recentBlockhash: blockhash,
      instructions: instructions,
    );

  /// Add an instruction to this transaction
  AnchorTransaction add(TransactionInstruction instruction) => AnchorTransaction(
      feePayer: feePayer,
      recentBlockhash: recentBlockhash,
      instructions: [...instructions, instruction],
    );

  /// Estimate the size of the transaction in bytes (rough estimate)
  int estimateSize() {
    // Each instruction: programId (32), each account meta (34), data length
    int size = 0;
    for (final ix in instructions) {
      size += 32; // programId
      size += ix.accounts.length * 34; // pubkey + flags
      size += ix.data.length;
    }
    // Add some overhead for signatures, blockhash, etc.
    size += 100;
    return size;
  }

  /// Estimate the transaction fee (stub, replace with real RPC call for accuracy)
  int estimateFee({int lamportsPerSignature = 5000}) {
    // 1 signature for fee payer + 1 per unique signer in all instructions
    final signers = <String>{};
    if (feePayer != null) signers.add(feePayer!.toBase58());
    for (final ix in instructions) {
      for (final meta in ix.accounts) {
        if (meta.isSigner) signers.add(meta.publicKey.toBase58());
      }
    }
    return signers.length * lamportsPerSignature;
  }

  /// Simulate this transaction (requires provider and simulate namespace)
  Future<SimulationResult> simulate(
    SimulateFunction simulateFn,
    List<dynamic> args,
    Context<Accounts> context,
  ) async => await simulateFn(args, context);

  /// Confirm this transaction (requires provider/connection and signature)
  Future<bool> confirm(
    AnchorProvider provider,
    String signature,
  ) async {
    // Stub implementation - always return true for now
    // In a real implementation, this would check transaction status
    return true;
  }

  @override
  String toString() => 'AnchorTransaction(feePayer: $feePayer, '
        'instructions: ${instructions.length})';
}

/// Generic accounts type for instruction contexts
typedef Accounts = Map<String, PublicKey>;

/// Transaction result containing signature
class TransactionResult {

  const TransactionResult({
    required this.signature,
    this.confirmed = false,
  });
  /// The transaction signature
  final String signature;

  /// Confirmation status
  final bool confirmed;

  @override
  String toString() => 'TransactionResult(signature: $signature, confirmed: $confirmed)';
}

/// Simulation result for transactions
class SimulationResult {

  const SimulationResult({
    required this.success,
    required this.logs,
    this.error,
    this.unitsConsumed,
  });
  /// Whether the simulation was successful
  final bool success;

  /// Program logs from the simulation
  final List<String> logs;

  /// Error message if simulation failed
  final String? error;

  /// Compute units consumed
  final int? unitsConsumed;

  @override
  String toString() => 'SimulationResult(success: $success, logs: ${logs.length}, '
        'error: $error, unitsConsumed: $unitsConsumed)';
}
