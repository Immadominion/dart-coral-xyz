/// Type-safe method builder for fluent API construction
///
/// Provides a fluent interface for building and executing
/// program methods, matching TypeScript's MethodsBuilder pattern.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/provider/anchor_provider.dart'
    hide SimulationResult;
import 'package:coral_xyz/src/coder/main_coder.dart';
import 'package:coral_xyz/src/program/namespace/account_namespace.dart';
import 'package:coral_xyz/src/program/namespace/instruction_namespace.dart';
import 'package:coral_xyz/src/program/namespace/transaction_namespace.dart';
import 'package:coral_xyz/src/program/namespace/rpc_namespace.dart';
import 'package:coral_xyz/src/program/namespace/simulate_namespace.dart';
import 'package:coral_xyz/src/program/namespace/types.dart' as ns;

/// Type-safe method builder with fluent API
///
/// Stores args, accounts, signers, and delegates to namespace functions
/// for execution. Account resolution (including PDA derivation) is handled
/// by InstructionBuilder via AccountsResolver.
class TypeSafeMethodBuilder {
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
  }) : _instruction = instruction,
       _provider = provider,
       _programId = programId,
       _instructionNamespace = instructionNamespace,
       _transactionNamespace = transactionNamespace,
       _rpcNamespace = rpcNamespace,
       _simulateNamespace = simulateNamespace,
       _accountNamespace = accountNamespace,
       _coder = coder;

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
  ns.Accounts _accounts = {};
  List<ns.Signer>? _signers;
  List<ns.AccountMeta>? _remainingAccounts;
  List<ns.TransactionInstruction>? _preInstructions;
  List<ns.TransactionInstruction>? _postInstructions;

  /// Set arguments for the method call
  TypeSafeMethodBuilder call(List<dynamic> args) {
    _args = args;
    return this;
  }

  /// Create a new builder instance with the given arguments (TypeScript-compatible)
  TypeSafeMethodBuilder withArgs(List<dynamic> args) => TypeSafeMethodBuilder(
    instruction: _instruction,
    provider: _provider,
    programId: _programId,
    instructionNamespace: _instructionNamespace,
    transactionNamespace: _transactionNamespace,
    rpcNamespace: _rpcNamespace,
    simulateNamespace: _simulateNamespace,
    accountNamespace: _accountNamespace,
    coder: _coder,
  ).call(args);

  /// Set instruction accounts
  TypeSafeMethodBuilder accounts(ns.Accounts accounts) {
    _accounts = accounts;
    return this;
  }

  /// Set instruction accounts with partial resolution support
  ///
  /// Missing accounts will be auto-resolved by AccountsResolver
  /// during instruction building.
  TypeSafeMethodBuilder accountsPartial(ns.Accounts accounts) {
    _accounts = accounts;
    return this;
  }

  /// Set transaction signers (appends to existing)
  TypeSafeMethodBuilder signers(List<ns.Signer> signers) {
    _signers = (_signers ?? [])..addAll(signers);
    return this;
  }

  /// Set remaining accounts (appends to existing)
  TypeSafeMethodBuilder remainingAccounts(List<ns.AccountMeta> accounts) {
    _remainingAccounts = (_remainingAccounts ?? [])..addAll(accounts);
    return this;
  }

  /// Set pre-instructions
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

  /// Set post-instructions (appends to existing)
  TypeSafeMethodBuilder postInstructions(
    List<ns.TransactionInstruction> instructions,
  ) {
    _postInstructions = (_postInstructions ?? [])..addAll(instructions);
    return this;
  }

  /// Get the resolved public keys of instruction accounts
  Future<Map<String, PublicKey?>> pubkeys() async {
    final result = <String, PublicKey?>{};
    for (final accountSpec in _instruction.accounts) {
      final val = _accounts[accountSpec.name];
      result[accountSpec.name] = val is PublicKey ? val : null;
    }
    return result;
  }

  /// Create a transaction instruction
  Future<ns.TransactionInstruction> instruction() async {
    final context = _buildContext();
    final builder = _instructionNamespace[_instruction.name];
    if (builder == null) {
      throw ArgumentError('Instruction not found: ${_instruction.name}');
    }
    return builder.callAsync(_args, context);
  }

  /// Create a transaction
  Future<ns.AnchorTransaction> transaction() async {
    final context = _buildContext();
    final builder = _transactionNamespace[_instruction.name];
    if (builder == null) {
      throw ArgumentError(
        'Transaction builder not found: ${_instruction.name}',
      );
    }
    return builder.callAsync(_args, context);
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
  Future<ns.SimulationResult> simulate() async {
    final context = _buildContext();
    final simulateFn = _simulateNamespace[_instruction.name];
    if (simulateFn == null) {
      throw ArgumentError('Simulate function not found: ${_instruction.name}');
    }
    return simulateFn.call(_args, context);
  }

  /// View function call for read-only instructions with return values
  ///
  /// Simulates the transaction, extracts the base64 return data from logs,
  /// and decodes it using the IDL's return type via the coder.
  Future<dynamic> view() async {
    if (_instruction.returns == null) {
      throw StateError(
        'Method does not support views. '
        'The instruction should return a value.',
      );
    }

    final simulation = await simulate();
    final returnPrefix = 'Program return: $_programId ';
    final logs = simulation.logs;

    String? returnDataBase64;
    for (final log in logs) {
      if (log.startsWith(returnPrefix)) {
        returnDataBase64 = log.substring(returnPrefix.length).trim();
        break;
      }
    }

    if (returnDataBase64 == null) {
      throw StateError('View expected return log but none found.');
    }

    final bytes = Uint8List.fromList(base64Decode(returnDataBase64));
    return _coder.types.decode(_instruction.returns!, bytes);
  }

  /// Prepare instruction with signers and public keys
  Future<
    ({
      ns.TransactionInstruction instruction,
      List<ns.Signer> signers,
      Map<String, PublicKey?> pubkeys,
    })
  >
  prepare() async {
    final instructionResult = await instruction();
    final keys = await pubkeys();
    final signersList = _signers ?? <ns.Signer>[];

    return (
      instruction: instructionResult,
      signers: signersList,
      pubkeys: keys,
    );
  }

  ns.Context<ns.Accounts> _buildContext() => ns.Context(
    accounts: _accounts,
    remainingAccounts: _remainingAccounts,
    signers: _signers,
    preInstructions: _preInstructions,
    postInstructions: _postInstructions,
  );

  /// Get the instruction name
  String get name => _instruction.name;

  /// Get the instruction definition
  IdlInstruction get idlInstruction => _instruction;

  /// Check if this method has a return value (is view-eligible)
  bool get hasReturnValue => _instruction.returns != null;

  @override
  String toString() =>
      'TypeSafeMethodBuilder(name: ${_instruction.name}, '
      'args: ${_args.length}, accounts: ${_accounts.length})';
}
