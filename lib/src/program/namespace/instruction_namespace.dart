import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/coder/main_coder.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/program/namespace/types.dart';
import 'package:coral_xyz_anchor/src/program/accounts_resolver.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/program/pda_cache.dart';

/// The instruction namespace provides functions to build TransactionInstruction
/// objects for each method of a program.
///
/// ## Usage
///
/// ```dart
/// final instruction = program.instruction.methodName(...args, ctx);
/// ```
class InstructionNamespace {

  InstructionNamespace._();
  final Map<String, InstructionBuilder> _builders = {};

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
  String toString() => 'InstructionNamespace(instructions: ${_builders.keys.toList()})';
}

/// Builder for creating individual transaction instructions
class InstructionBuilder { // Add provider reference

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
  final IdlInstruction _instruction;
  final Coder _coder;
  final PublicKey _programId;
  final Idl _idl; // Add IDL reference
  final AnchorProvider _provider;

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
    final idlTypes = _idl.types ?? <IdlTypeDef>[];
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
    try {
      // For sync API, try to use cached account resolution when possible
      final cachedResults = _tryGetCachedAccountResolution(context);

      if (cachedResults != null) {
        return _buildInstructionSync(args, context, cachedResults);
      }

      // If PDA resolution required and no cache available, provide helpful error
      final needsPdaResolution = _checkIfNeedsPdaResolution(context);
      if (needsPdaResolution) {
        throw UnsupportedError(
            'Synchronous API cannot resolve PDAs. Use callAsync() instead, '
            'or ensure all accounts are pre-resolved in the context. '
            'Missing accounts: ${_getMissingAccountNames(context).join(", ")}');
      }

      // If all accounts are resolved, build instruction directly
      return _buildInstructionSync(args, context, {});
    } catch (e) {
      if (e is UnsupportedError) rethrow;
      throw Exception('Failed to build instruction synchronously: $e');
    }
  }

  /// Try to get cached account resolution results
  Map<String, dynamic>? _tryGetCachedAccountResolution(
      Context<Accounts> context,) {
    // Implementation for checking cached PDA results
    // This would check a global PDA cache for resolved addresses
    return PdaCache.getCachedResults(context.accounts, _programId);
  }

  /// Check if the context requires PDA resolution
  bool _checkIfNeedsPdaResolution(Context<Accounts> context) {
    // Check if any accounts in the context are PDAs that need resolution
    // For now, assume any missing accounts might need PDA resolution
    final provided = context.accounts;
    for (final account in _instruction.accounts) {
      if (!provided.containsKey(account.name)) {
        return true;
      }
    }
    return false;
  }

  /// Get names of missing accounts
  List<String> _getMissingAccountNames(Context<Accounts> context) {
    final provided = context.accounts;
    final missing = <String>[];
    for (final account in _instruction.accounts) {
      if (!provided.containsKey(account.name)) {
        missing.add(account.name);
      }
    }
    return missing;
  }

  /// Build instruction synchronously with provided accounts
  TransactionInstruction _buildInstructionSync(
    List<dynamic> args,
    Context<Accounts> context,
    Map<String, dynamic> resolvedAccounts,
  ) {
    final argsMap = _buildArgsMapFromList(args);
    final data = _coder.instructions.encode(_instruction.name, argsMap);

    // Merge provided accounts with resolved accounts
    final allAccounts = <String, dynamic>{};
    allAccounts.addAll(context.accounts);
    allAccounts.addAll(resolvedAccounts);

    final accounts = _buildAccountMetas(context, allAccounts);

    return TransactionInstruction(
      programId: _programId,
      accounts: accounts,
      data: data,
    );
  }

  /// Build arguments map from list of arguments
  Map<String, dynamic> _buildArgsMapFromList(List<dynamic> args) {
    final argsMap = <String, dynamic>{};

    // Map positional arguments to named parameters based on instruction definition
    final params = _instruction.args;
    for (int i = 0; i < args.length && i < params.length; i++) {
      argsMap[params[i].name] = args[i];
    }

    return argsMap;
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
          publicKey: publicKey as PublicKey,
          isWritable:
              account is IdlInstructionAccount ? account.writable : false,
          isSigner: account is IdlInstructionAccount ? account.signer : false,
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
  String toString() => 'InstructionBuilder(name: ${_instruction.name})';
}
