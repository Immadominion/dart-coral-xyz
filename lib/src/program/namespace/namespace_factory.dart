import '../../types/public_key.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart';
import 'account_namespace.dart';
import 'instruction_namespace.dart';
import 'methods_namespace.dart';
import 'rpc_namespace.dart';
import 'simulate_namespace.dart';
import 'transaction_namespace.dart';

/// Factory for creating namespace instances for a program
///
/// This class generates dynamic namespaces that provide type-safe,
/// IDL-based interfaces for interacting with Anchor programs.
class NamespaceFactory {
  /// Generates all namespaces for a given program
  ///
  /// Returns a record containing all the generated namespaces:
  /// - rpc: For sending signed transactions
  /// - instruction: For building transaction instructions
  /// - transaction: For building full transactions
  /// - account: For account operations
  /// - simulate: For transaction simulation
  /// - methods: For fluent method building
  static NamespaceSet build({
    required Idl idl,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
  }) {
    // Build account namespace from IDL accounts
    final accountNamespace = AccountNamespace.build(
      idl: idl,
      coder: coder,
      programId: programId,
      provider: provider,
    );

    // Build instruction namespace from IDL instructions
    final instructionNamespace = InstructionNamespace.build(
      idl: idl,
      coder: coder,
      programId: programId,
      provider: provider,
    );

    // Build transaction namespace
    final transactionNamespace = TransactionNamespace.build(
      idl: idl,
      instructionNamespace: instructionNamespace,
    );

    // Build RPC namespace
    final rpcNamespace = RpcNamespace.build(
      idl: idl,
      transactionNamespace: transactionNamespace,
      provider: provider,
    );

    // Build simulation namespace
    final simulateNamespace = SimulateNamespace.build(
      idl: idl,
      transactionNamespace: transactionNamespace,
      provider: provider,
      coder: coder,
      programId: programId,
    );

    // Build methods namespace (the main fluent interface)
    final methodsNamespace = MethodsNamespace.build(
      idl: idl,
      provider: provider,
      programId: programId,
      instructionNamespace: instructionNamespace,
      transactionNamespace: transactionNamespace,
      rpcNamespace: rpcNamespace,
      simulateNamespace: simulateNamespace,
      accountNamespace: accountNamespace,
      coder: coder,
    );

    return NamespaceSet(
      rpc: rpcNamespace,
      instruction: instructionNamespace,
      transaction: transactionNamespace,
      account: accountNamespace,
      simulate: simulateNamespace,
      methods: methodsNamespace,
    );
  }
}

/// Container for all namespace types
class NamespaceSet {
  /// RPC namespace for sending signed transactions
  final RpcNamespace rpc;

  /// Instruction namespace for building transaction instructions
  final InstructionNamespace instruction;

  /// Transaction namespace for building full transactions
  final TransactionNamespace transaction;

  /// Account namespace for account operations
  final AccountNamespace account;

  /// Simulation namespace for transaction simulation
  final SimulateNamespace simulate;

  /// Methods namespace for fluent method building
  final MethodsNamespace methods;

  const NamespaceSet({
    required this.rpc,
    required this.instruction,
    required this.transaction,
    required this.account,
    required this.simulate,
    required this.methods,
  });

  @override
  String toString() {
    return 'NamespaceSet(rpc: $rpc, instruction: $instruction, '
        'transaction: $transaction, account: $account, '
        'simulate: $simulate, methods: $methods)';
  }
}
