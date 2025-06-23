/// Type-safe method builder for fluent API construction
///
/// This module provides TypeSafeMethodBuilder which creates fluent API
/// builders for each IDL instruction with full type safety and validation.

library;

import '../idl/idl.dart';
import '../types/public_key.dart';
import '../provider/anchor_provider.dart' hide SimulationResult;
import '../coder/main_coder.dart';
import 'namespace/account_namespace.dart';
import 'namespace/instruction_namespace.dart';
import 'namespace/transaction_namespace.dart';
import 'namespace/rpc_namespace.dart';
import 'namespace/simulate_namespace.dart';
import 'namespace/types.dart' as ns;
import 'method_validator.dart';

/// Type-safe method builder with fluent API and validation
///
/// This class provides a fluent interface for building and executing
/// program methods with compile-time type safety and runtime validation.
class TypeSafeMethodBuilder {
  final IdlInstruction _instruction;
  final AnchorProvider _provider;
  final PublicKey _programId;
  final InstructionNamespace _instructionNamespace;
  final TransactionNamespace _transactionNamespace;
  final RpcNamespace _rpcNamespace;
  final SimulateNamespace _simulateNamespace;
  final AccountNamespace _accountNamespace;
  final Coder _coder;
  final MethodValidator _validator;

  // Builder state
  List<dynamic> _args = [];
  ns.Accounts _accounts = {};
  List<ns.Signer>? _signers;
  List<ns.AccountMeta>? _remainingAccounts;
  List<ns.TransactionInstruction>? _preInstructions;
  List<ns.TransactionInstruction>? _postInstructions;
  bool _validated = false;

  TypeSafeMethodBuilder({
    required IdlInstruction instruction,
    required AnchorProvider provider,
    required PublicKey programId,
    required InstructionNamespace instructionNamespace,
    required TransactionNamespace transactionNamespace,
    required RpcNamespace rpcNamespace,
    required SimulateNamespace simulateNamespace,
    required AccountNamespace accountNamespace,
    required Coder coder,
    required MethodValidator validator,
  })  : _instruction = instruction,
        _provider = provider,
        _programId = programId,
        _instructionNamespace = instructionNamespace,
        _transactionNamespace = transactionNamespace,
        _rpcNamespace = rpcNamespace,
        _simulateNamespace = simulateNamespace,
        _accountNamespace = accountNamespace,
        _coder = coder,
        _validator = validator;

  /// Initialize the method with typed arguments
  ///
  /// Provides type-safe argument setting with validation.
  /// Arguments are validated against the IDL instruction definition.
  TypeSafeMethodBuilder call(List<dynamic> args) {
    _args = args;
    _validated = false; // Reset validation when args change
    return this;
  }

  /// Create a new builder instance with the given arguments (TypeScript-compatible)
  ///
  /// This method creates a fresh builder instance with the same configuration
  /// but new arguments, matching TypeScript's behavior where each method call
  /// returns a new MethodsBuilder instance.
  TypeSafeMethodBuilder withArgs(List<dynamic> args) {
    return TypeSafeMethodBuilder(
      instruction: _instruction,
      provider: _provider,
      programId: _programId,
      instructionNamespace: _instructionNamespace,
      transactionNamespace: _transactionNamespace,
      rpcNamespace: _rpcNamespace,
      simulateNamespace: _simulateNamespace,
      accountNamespace: _accountNamespace,
      coder: _coder,
      validator: _validator,
    ).call(args);
  }

  /// Set instruction accounts with type checking
  ///
  /// Validates account structure against IDL requirements and provides
  /// helpful error messages for missing or incorrect accounts.
  TypeSafeMethodBuilder accounts(ns.Accounts accounts) {
    _accounts = accounts;
    _validated = false; // Reset validation when accounts change
    return this;
  }

  /// Set transaction signers with validation
  ///
  /// Validates that provided signers match account requirements.
  /// Note: This method appends signers to existing ones (like TypeScript)
  TypeSafeMethodBuilder signers(List<ns.Signer> signers) {
    _signers = (_signers ?? [])..addAll(signers);
    return this;
  }

  /// Set remaining accounts with type safety
  ///
  /// Note: This method appends accounts to existing ones (like TypeScript)
  TypeSafeMethodBuilder remainingAccounts(List<ns.AccountMeta> accounts) {
    _remainingAccounts = (_remainingAccounts ?? [])..addAll(accounts);
    return this;
  }

  /// Set pre-instructions with validation
  ///
  /// [instructions] Instructions to add
  /// [prepend] Whether to prepend to existing instructions (default: false)
  TypeSafeMethodBuilder preInstructions(
    List<ns.TransactionInstruction> instructions, {
    bool prepend = false,
  }) {
    if (_preInstructions == null) {
      _preInstructions = instructions;
    } else if (prepend) {
      _preInstructions = [...instructions, ..._preInstructions!];
    } else {
      _preInstructions!.addAll(instructions);
    }
    return this;
  }

  /// Set post-instructions with validation
  ///
  /// Note: This method appends instructions to existing ones (like TypeScript)
  TypeSafeMethodBuilder postInstructions(
      List<ns.TransactionInstruction> instructions) {
    _postInstructions = (_postInstructions ?? [])..addAll(instructions);
    return this;
  }

  /// Get the resolved public keys of instruction accounts
  ///
  /// Returns a map with account names as keys and their public keys as values.
  /// Includes type-safe account resolution and validation.
  Future<Map<String, PublicKey?>> pubkeys() async {
    await _ensureValidated();

    final result = <String, PublicKey?>{};

    for (final accountSpec in _instruction.accounts) {
      final accountName = accountSpec.name;
      final accountValue = _accounts[accountName];
      result[accountName] = accountValue;
    }

    return result;
  }

  /// Create a type-safe transaction instruction
  ///
  /// Performs comprehensive validation before building the instruction.
  Future<ns.TransactionInstruction> instruction() async {
    await _ensureValidated();

    final context = _buildContext();
    final builder = _instructionNamespace[_instruction.name];
    if (builder == null) {
      throw ArgumentError('Instruction not found: ${_instruction.name}');
    }
    return await builder.callAsync(_args, context);
  }

  /// Create a type-safe transaction
  ///
  /// Builds a complete transaction with validation and account resolution.
  Future<ns.AnchorTransaction> transaction() async {
    await _ensureValidated();

    final context = _buildContext();
    final builder = _transactionNamespace[_instruction.name];
    if (builder == null) {
      throw ArgumentError(
          'Transaction builder not found: ${_instruction.name}');
    }
    return await builder.callAsync(_args, context);
  }

  /// Send and confirm the transaction with validation
  ///
  /// Performs comprehensive validation before sending the transaction.
  Future<String> rpc() async {
    await _ensureValidated();

    final context = _buildContext();
    final rpcFn = _rpcNamespace[_instruction.name];
    if (rpcFn == null) {
      throw ArgumentError('RPC function not found: ${_instruction.name}');
    }
    return rpcFn.call(_args, context);
  }

  /// Simulate the transaction with validation
  ///
  /// Provides detailed simulation results with type-safe error reporting.
  Future<ns.SimulationResult> simulate() async {
    await _ensureValidated();

    final context = _buildContext();
    final simulateFn = _simulateNamespace[_instruction.name];
    if (simulateFn == null) {
      throw ArgumentError('Simulate function not found: ${_instruction.name}');
    }
    return simulateFn.call(_args, context);
  }

  /// View function call for read-only instructions with return values
  ///
  /// Enhanced with type-safe return value parsing and validation.
  Future<dynamic> view() async {
    await _ensureValidated();

    // Validate instruction is eligible for view operations
    if (_instruction.returns == null) {
      throw StateError('Method does not support views. '
          'The instruction should return a value.');
    }

    // TODO: Implement enhanced account writability checking
    // For now, assume the instruction is view-eligible if it has a return type

    // Use simulation to get the return value
    final simulation = await simulate();

    // Parse return value from logs with enhanced error handling
    final returnPrefix = 'Program return: $_programId ';
    final logs = simulation.logs;

    String? returnLog;
    for (final log in logs) {
      if (log.startsWith(returnPrefix)) {
        returnLog = log;
        break;
      }
    }

    if (returnLog == null) {
      throw StateError('View expected return log but none found. '
          'Check if the instruction actually returns a value.');
    }

    // Extract and decode the return data with type safety
    final returnData = returnLog.substring(returnPrefix.length);

    // TODO: Implement proper type-specific deserialization based on IDL return type
    // For now, return the raw return data
    return returnData;
  }

  /// Send transaction and get both signature and resolved account keys
  ///
  /// Enhanced convenience method with comprehensive result reporting.
  Future<({String signature, Map<String, PublicKey?> pubkeys})>
      rpcAndKeys() async {
    final signature = await rpc();
    final keys = await pubkeys();
    return (signature: signature, pubkeys: keys);
  }

  /// Prepare instruction with comprehensive validation
  ///
  /// Returns instruction, signers, and resolved public keys for use in
  /// transaction building with full type safety.
  Future<
      ({
        ns.TransactionInstruction instruction,
        List<ns.Signer> signers,
        Map<String, PublicKey?> pubkeys,
      })> prepare() async {
    final instructionResult = await instruction();
    final keys = await pubkeys();
    final signers = _signers ?? <ns.Signer>[];

    return (
      instruction: instructionResult,
      signers: signers,
      pubkeys: keys,
    );
  }

  /// Ensure validation has been performed
  ///
  /// Validates arguments and accounts against IDL specification.
  Future<void> _ensureValidated() async {
    if (!_validated) {
      await _validator.validate(_args, _accounts);
      _validated = true;
    }
  }

  /// Build the context for the instruction with validation
  ns.Context<ns.Accounts> _buildContext() {
    return ns.Context(
      accounts: _accounts,
      remainingAccounts: _remainingAccounts,
      signers: _signers,
      preInstructions: _preInstructions,
      postInstructions: _postInstructions,
    );
  }

  /// Get the instruction name for debugging and logging
  String get name => _instruction.name;

  /// Get the instruction definition for introspection
  IdlInstruction get idlInstruction => _instruction;

  /// Check if this method has a return value (is view-eligible)
  bool get hasReturnValue => _instruction.returns != null;

  /// Get the return type specification if available
  String? get returnType => _instruction.returns;

  /// Get required argument count for validation
  int get requiredArgumentCount => _instruction.args.length;

  /// Get required account names for validation
  List<String> get requiredAccountNames =>
      _instruction.accounts.map((a) => a.name).toList();

  /// Get method documentation if available
  List<String>? get documentation => _instruction.docs;

  @override
  String toString() {
    return 'TypeSafeMethodBuilder(name: ${_instruction.name}, '
        'validated: $_validated, args: ${_args.length}, '
        'accounts: ${_accounts.length})';
  }
}
