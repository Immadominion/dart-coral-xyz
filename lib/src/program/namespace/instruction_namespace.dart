import '../../types/public_key.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import 'types.dart';
import '../accounts_resolver.dart';
import '../../provider/anchor_provider.dart';

/// The instruction namespace provides functions to build TransactionInstruction
/// objects for each method of a program.
///
/// ## Usage
///
/// ```dart
/// final instruction = program.instruction.methodName(...args, ctx);
/// ```
class InstructionNamespace {
  final Map<String, InstructionBuilder> _builders = {};

  InstructionNamespace._();

  /// Build instruction namespace from IDL
  static InstructionNamespace build({
    required Idl idl,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
  }) {
    final namespace = InstructionNamespace._();

    // Create instruction builders for each IDL instruction
    for (final instruction in idl.instructions) {
      namespace._builders[instruction.name] = InstructionBuilder(
        instruction: instruction,
        coder: coder,
        programId: programId,
        idl: idl, // Pass IDL to InstructionBuilder
        provider: provider, // Pass provider to InstructionBuilder
      );
    }

    return namespace;
  }

  /// Get an instruction builder by name
  InstructionBuilder? operator [](String name) => _builders[name];

  /// Get all instruction names
  Iterable<String> get names => _builders.keys;

  /// Check if an instruction exists
  bool contains(String name) => _builders.containsKey(name);

  @override
  String toString() {
    return 'InstructionNamespace(instructions: ${_builders.keys.toList()})';
  }
}

/// Builder for creating individual transaction instructions
class InstructionBuilder {
  final IdlInstruction _instruction;
  final Coder _coder;
  final PublicKey _programId;
  final Idl _idl; // Add IDL reference
  final AnchorProvider _provider; // Add provider reference

  InstructionBuilder({
    required IdlInstruction instruction,
    required Coder coder,
    required PublicKey programId,
    required Idl idl, // Add IDL to constructor
    required AnchorProvider provider, // Add provider to constructor
  })  : _instruction = instruction,
        _coder = coder,
        _programId = programId,
        _idl = idl,
        _provider = provider;

  /// Build a transaction instruction with the given arguments and context
  Future<TransactionInstruction> callAsync(
    List<dynamic> args,
    Context<Accounts> context,
  ) async {
    final argsMap = <String, dynamic>{};
    for (int i = 0; i < args.length && i < _instruction.args.length; i++) {
      argsMap[_instruction.args[i].name] = args[i];
    }

    // Enhanced: Resolve missing accounts using AccountsResolver
    final providedAccounts = Map<String, dynamic>.from(context.accounts);
    final programId = _programId;
    final idlTypes = (_idl.types ?? <IdlTypeDef>[]);
    final resolver = AccountsResolver(
      args: args,
      accounts: providedAccounts,
      provider: _provider, // Use provider from field instead of context
      programId: programId,
      idlInstruction: _instruction,
      idlTypes: idlTypes,
    );
    // Await resolution synchronously
    final resolved = await resolver.resolve();
    final resolvedAccounts = Map<String, dynamic>.from(providedAccounts)
      ..addAll(resolved);

    final data = _coder.instructions.encode(_instruction.name, argsMap);
    final accounts = _buildAccountMetas(context, resolvedAccounts);

    return TransactionInstruction(
      programId: _programId,
      accounts: accounts,
      data: data,
    );
  }

  /// Build a transaction instruction with the given arguments and context (legacy sync version)
  TransactionInstruction call(List<dynamic> args, Context<Accounts> context) {
    throw UnimplementedError('Use callAsync for enhanced account resolution.');
  }

  /// Build account metas from context, using resolved accounts
  List<AccountMeta> _buildAccountMetas(
    Context<Accounts> context,
    Map<String, dynamic> resolvedAccounts,
  ) {
    final accountMetas = <AccountMeta>[];

    // Process instruction accounts
    for (final account in _instruction.accounts) {
      final publicKey = resolvedAccounts[account.name];
      if (publicKey == null) {
        throw ArgumentError('Missing required account: \\${account.name}');
      }

      accountMetas.add(
        AccountMeta(
          publicKey: publicKey,
          isWritable: account is IdlInstructionAccount ? account.isMut : false,
          isSigner: account is IdlInstructionAccount ? account.isSigner : false,
        ),
      );
    }

    // Add any remaining accounts
    if (context.remainingAccounts != null) {
      accountMetas.addAll(context.remainingAccounts!);
    }

    return accountMetas;
  }

  /// Get the instruction name
  String get name => _instruction.name;

  /// Get the instruction arguments
  List<IdlField> get args => _instruction.args;

  /// Get the instruction accounts
  List<IdlInstructionAccountItem> get accounts => _instruction.accounts;

  @override
  String toString() {
    return 'InstructionBuilder(name: ${_instruction.name})';
  }
}
