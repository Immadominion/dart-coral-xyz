import '../../types/public_key.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart' hide SimulationResult;
import '../method_builder.dart';
import 'account_namespace.dart';
import 'instruction_namespace.dart';
import 'rpc_namespace.dart';
import 'simulate_namespace.dart';
import 'transaction_namespace.dart';
import 'types.dart';

/// The methods namespace provides a fluent interface for building and executing
/// program methods with type-safe parameters.
///
/// ## Usage
///
/// ```dart
/// final result = await program.methods.methodName(...args)
///     .accounts({...})
///     .signers([...])
///     .rpc();
/// ```
class MethodsNamespace {
  final Map<String, MethodsBuilder> _builders = {};

  MethodsNamespace._();

  /// Build methods namespace from IDL
  static MethodsNamespace build({
    required Idl idl,
    required AnchorProvider provider,
    required PublicKey programId,
    required InstructionNamespace instructionNamespace,
    required TransactionNamespace transactionNamespace,
    required RpcNamespace rpcNamespace,
    required SimulateNamespace simulateNamespace,
    required AccountNamespace accountNamespace,
    required Coder coder,
  }) {
    final namespace = MethodsNamespace._();

    // Create method builders for each IDL instruction
    for (final instruction in idl.instructions) {
      namespace._builders[instruction.name] = MethodsBuilder(
        instruction: instruction,
        provider: provider,
        programId: programId,
        instructionNamespace: instructionNamespace,
        transactionNamespace: transactionNamespace,
        rpcNamespace: rpcNamespace,
        simulateNamespace: simulateNamespace,
        accountNamespace: accountNamespace,
        coder: coder,
      );
    }

    return namespace;
  }

  /// Get a method builder by name
  MethodsBuilder? operator [](String name) => _builders[name];

  /// Get all method names
  Iterable<String> get names => _builders.keys;

  /// Check if a method exists
  bool contains(String name) => _builders.containsKey(name);

  @override
  String toString() {
    return 'MethodsNamespace(methods: ${_builders.keys.toList()})';
  }
}

/// Fluent builder for constructing and executing program method calls
class MethodsBuilder {
  final IdlInstruction _instruction;
  final AnchorProvider _provider;
  final PublicKey _programId;
  final InstructionNamespace _instructionNamespace;
  final TransactionNamespace _transactionNamespace;
  final RpcNamespace _rpcNamespace;
  final SimulateNamespace _simulateNamespace;
  final AccountNamespace _accountNamespace;
  final Coder _coder;

  // Builder state
  List<dynamic> _args = [];
  Accounts _accounts = {};
  List<Signer>? _signers;
  List<AccountMeta>? _remainingAccounts;
  List<TransactionInstruction>? _preInstructions;
  List<TransactionInstruction>? _postInstructions;

  MethodsBuilder({
    required IdlInstruction instruction,
    required AnchorProvider provider,
    required PublicKey programId,
    required InstructionNamespace instructionNamespace,
    required TransactionNamespace transactionNamespace,
    required RpcNamespace rpcNamespace,
    required SimulateNamespace simulateNamespace,
    required AccountNamespace accountNamespace,
    required Coder coder,
  })  : _instruction = instruction,
        _provider = provider,
        _programId = programId,
        _instructionNamespace = instructionNamespace,
        _transactionNamespace = transactionNamespace,
        _rpcNamespace = rpcNamespace,
        _simulateNamespace = simulateNamespace,
        _accountNamespace = accountNamespace,
        _coder = coder;

  /// Initialize the method with arguments
  MethodsBuilder call(List<dynamic> args) {
    _args = args;
    return this;
  }

  /// Set the accounts for the instruction
  MethodsBuilder accounts(Accounts accounts) {
    _accounts = accounts;
    return this;
  }

  /// Set the signers for the transaction
  MethodsBuilder signers(List<Signer> signers) {
    _signers = signers;
    return this;
  }

  /// Set additional accounts that may be needed
  MethodsBuilder remainingAccounts(List<AccountMeta> accounts) {
    _remainingAccounts = accounts;
    return this;
  }

  /// Set instructions to run before this one
  MethodsBuilder preInstructions(List<TransactionInstruction> instructions) {
    _preInstructions = instructions;
    return this;
  }

  /// Set instructions to run after this one
  MethodsBuilder postInstructions(List<TransactionInstruction> instructions) {
    _postInstructions = instructions;
    return this;
  }

  /// Build a transaction instruction (PDA-aware, async)
  Future<TransactionInstruction> instructionAsync() async {
    final context = _buildContext();
    final builder = _instructionNamespace[_instruction.name];
    if (builder == null) {
      throw ArgumentError('Instruction not found: \\${_instruction.name}');
    }
    return await builder.callAsync(_args, context);
  }

  /// Build a transaction instruction (legacy sync version)
  TransactionInstruction instruction() {
    throw UnimplementedError(
        'Use instructionAsync for PDA-aware account resolution.');
  }

  /// Build a complete transaction (async for PDA resolution)
  Future<AnchorTransaction> transactionAsync() async {
    final context = _buildContext();
    final builder = _transactionNamespace[_instruction.name];
    if (builder == null) {
      throw ArgumentError(
          'Transaction builder not found: ${_instruction.name}');
    }
    return await builder.callAsync(_args, context);
  }

  /// Build a complete transaction (legacy sync version)
  AnchorTransaction transaction() {
    throw UnimplementedError(
        'Use transactionAsync for PDA-aware account resolution.');
  }

  /// Send and confirm the transaction
  Future<String> rpc() async {
    final context = _buildContext();
    final rpcFn = _rpcNamespace[_instruction.name];
    if (rpcFn == null) {
      throw ArgumentError('RPC function not found: ${_instruction.name}');
    }
    return rpcFn.call(_args, context);
  }

  /// Simulate the transaction
  Future<SimulationResult> simulate() async {
    final context = _buildContext();
    final simulateFn = _simulateNamespace[_instruction.name];
    if (simulateFn == null) {
      throw ArgumentError('Simulate function not found: ${_instruction.name}');
    }
    return simulateFn.call(_args, context);
  }

  /// Build the context for the instruction
  Context<Accounts> _buildContext() {
    return Context(
      accounts: _accounts,
      remainingAccounts: _remainingAccounts,
      signers: _signers,
      preInstructions: _preInstructions,
      postInstructions: _postInstructions,
    );
  }

  /// Get the instruction name
  String get name => _instruction.name;

  @override
  String toString() {
    return 'MethodsBuilder(name: ${_instruction.name})';
  }
}
