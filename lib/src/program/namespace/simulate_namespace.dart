import 'dart:typed_data';

import '../../types/public_key.dart';
import '../../types/transaction.dart' as transaction_types;
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart' hide SimulationResult;
import '../../transaction/transaction_simulator.dart';
import 'transaction_namespace.dart';
import 'types.dart';

/// The simulation namespace provides functions to simulate transactions for
/// each method of a program without sending them to the blockchain.
///
/// ## Usage
///
/// ```dart
/// final result = await program.simulate.methodName(...args, ctx);
/// ```
class SimulateNamespace {
  final Map<String, SimulateFunction> _functions = {};

  SimulateNamespace._();

  /// Build simulation namespace from IDL
  static SimulateNamespace build({
    required Idl idl,
    required TransactionNamespace transactionNamespace,
    required AnchorProvider provider,
    required Coder coder,
    required PublicKey programId,
  }) {
    final namespace = SimulateNamespace._();

    // Create simulation functions for each IDL instruction
    for (final instruction in idl.instructions) {
      namespace._functions[instruction.name] = SimulateFunction(
        instruction: instruction,
        transactionNamespace: transactionNamespace,
        provider: provider,
        coder: coder,
        programId: programId,
      );
    }

    return namespace;
  }

  /// Get a simulation function by name
  SimulateFunction? operator [](String name) => _functions[name];

  /// Get all instruction names
  Iterable<String> get names => _functions.keys;

  /// Check if an instruction exists
  bool contains(String name) => _functions.containsKey(name);

  @override
  String toString() {
    return 'SimulateNamespace(instructions: ${_functions.keys.toList()})';
  }
}

/// Function for simulating a transaction for a specific instruction
class SimulateFunction {
  final IdlInstruction _instruction;
  final TransactionNamespace _transactionNamespace;
  final AnchorProvider _provider;
  // Note: _coder and _programId may be needed for future enhancements
  // final Coder _coder;
  // final PublicKey _programId;

  SimulateFunction({
    required IdlInstruction instruction,
    required TransactionNamespace transactionNamespace,
    required AnchorProvider provider,
    required Coder coder,
    required PublicKey programId,
  })  : _instruction = instruction,
        _transactionNamespace = transactionNamespace,
        _provider = provider;
  // _coder = coder,
  // _programId = programId;

  /// Simulate a transaction with the given arguments and context
  Future<SimulationResult> call(
    List<dynamic> args,
    Context<Accounts> context,
  ) async {
    try {
      // Build the transaction using the transaction namespace
      final anchorTransaction =
          _transactionNamespace[_instruction.name]!(args, context);

      // Convert AnchorTransaction to Transaction for simulation
      final transaction = _convertToTransaction(anchorTransaction);

      // Create a transaction simulator
      final simulator = TransactionSimulator(_provider);

      // Simulate the transaction using the new simulator
      final result = await simulator.simulate(transaction);

      // Convert to the namespace's SimulationResult format
      return SimulationResult(
        success: result.success,
        logs: result.logs,
        error: result.error?.toString(),
        unitsConsumed: result.unitsConsumed,
      );
    } catch (error) {
      return SimulationResult(
        success: false,
        logs: ['Program log: Simulation failed'],
        error: error.toString(),
      );
    }
  }

  /// Convert AnchorTransaction to Transaction for simulation
  transaction_types.Transaction _convertToTransaction(
      AnchorTransaction anchorTx) {
    // Convert instructions from namespace types to transaction types
    final convertedInstructions = anchorTx.instructions.map((instruction) {
      return transaction_types.TransactionInstruction(
        programId: instruction.programId,
        accounts: instruction.accounts.map((account) {
          return transaction_types.AccountMeta(
            pubkey: account.publicKey,
            isWritable: account.isWritable,
            isSigner: account.isSigner,
          );
        }).toList(),
        data: Uint8List.fromList(instruction.data),
      );
    }).toList();

    return transaction_types.Transaction(
      instructions: convertedInstructions,
      feePayer: anchorTx.feePayer,
      recentBlockhash: anchorTx.recentBlockhash,
    );
  }

  /// Get the instruction name
  String get name => _instruction.name;

  @override
  String toString() {
    return 'SimulateFunction(name: ${_instruction.name})';
  }
}
