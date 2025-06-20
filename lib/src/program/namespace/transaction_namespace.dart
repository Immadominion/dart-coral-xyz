import '../../idl/idl.dart';
import 'instruction_namespace.dart';
import 'types.dart';

/// The transaction namespace provides functions to build Transaction objects
/// for each method of a program.
///
/// ## Usage
///
/// ```dart
/// final transaction = program.transaction.methodName(...args, ctx);
/// ```
class TransactionNamespace {
  final Map<String, TransactionBuilder> _builders = {};

  TransactionNamespace._();

  /// Build transaction namespace from IDL
  static TransactionNamespace build({
    required Idl idl,
    required InstructionNamespace instructionNamespace,
  }) {
    final namespace = TransactionNamespace._();

    // Create transaction builders for each IDL instruction
    for (final instruction in idl.instructions) {
      namespace._builders[instruction.name] = TransactionBuilder(
        instruction: instruction,
        instructionNamespace: instructionNamespace,
      );
    }

    return namespace;
  }

  /// Get a transaction builder by name
  TransactionBuilder? operator [](String name) => _builders[name];

  /// Get all instruction names
  Iterable<String> get names => _builders.keys;

  /// Check if an instruction exists
  bool contains(String name) => _builders.containsKey(name);

  @override
  String toString() {
    return 'TransactionNamespace(instructions: ${_builders.keys.toList()})';
  }
}

/// Builder for creating transactions with specific instructions
class TransactionBuilder {
  final IdlInstruction _instruction;
  final InstructionNamespace _instructionNamespace;

  TransactionBuilder({
    required IdlInstruction instruction,
    required InstructionNamespace instructionNamespace,
  })  : _instruction = instruction,
        _instructionNamespace = instructionNamespace;

  /// Build a transaction with the given arguments and context (async for PDA resolution)
  Future<AnchorTransaction> callAsync(
      List<dynamic> args, Context<Accounts> context) async {
    // Get the instruction builder
    final instructionBuilder = _instructionNamespace[_instruction.name];
    if (instructionBuilder == null) {
      throw ArgumentError('Instruction not found: ${_instruction.name}');
    }

    // Build the instruction
    final instruction = await instructionBuilder.callAsync(args, context);

    // Create transaction with pre and post instructions
    final instructions = <TransactionInstruction>[];

    // Add pre-instructions if any
    if (context.preInstructions != null) {
      instructions.addAll(context.preInstructions!);
    }

    // Add the main instruction
    instructions.add(instruction);

    // Add post-instructions if any
    if (context.postInstructions != null) {
      instructions.addAll(context.postInstructions!);
    }

    return AnchorTransaction(
      instructions: instructions,
    );
  }

  /// Build a transaction with the given arguments and context (legacy sync version)
  AnchorTransaction call(List<dynamic> args, Context<Accounts> context) {
    throw UnimplementedError('Use callAsync for PDA-aware account resolution.');
  }

  /// Get the instruction name
  String get name => _instruction.name;

  @override
  String toString() {
    return 'TransactionBuilder(name: ${_instruction.name})';
  }
}
