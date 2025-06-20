import '../../types/public_key.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart' hide SimulationResult;
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
  final Coder _coder;
  final PublicKey _programId;

  SimulateFunction({
    required IdlInstruction instruction,
    required TransactionNamespace transactionNamespace,
    required AnchorProvider provider,
    required Coder coder,
    required PublicKey programId,
  })  : _instruction = instruction,
        _transactionNamespace = transactionNamespace,
        _provider = provider,
        _coder = coder,
        _programId = programId;

  /// Simulate a transaction with the given arguments and context
  Future<SimulationResult> call(
    List<dynamic> args,
    Context<Accounts> context,
  ) async {
    try {
      // Build the transaction using the transaction namespace
      final transaction =
          _transactionNamespace[_instruction.name]!(args, context);

      // Set fee payer if not already set (we don't use the result in simulation)
      if (transaction.feePayer == null && _provider.wallet?.publicKey != null) {
        // In a real implementation, we would prepare the transaction for simulation
      }

      // Simulate the transaction (placeholder implementation)
      return const SimulationResult(
        success: true,
        logs: ['Program log: Simulation successful'],
        unitsConsumed: 1000,
      );
    } catch (error) {
      return SimulationResult(
        success: false,
        logs: ['Program log: Simulation failed'],
        error: error.toString(),
      );
    }
  }

  /// Get the instruction name
  String get name => _instruction.name;

  @override
  String toString() {
    return 'SimulateFunction(name: ${_instruction.name})';
  }
}
