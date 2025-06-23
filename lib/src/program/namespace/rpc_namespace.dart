import 'dart:typed_data';

import '../../types/transaction.dart' as transaction_types;
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart';
import 'transaction_namespace.dart';
import 'types.dart';
import '../../error/rpc_error_parser.dart';

/// The RPC namespace provides async methods to send signed transactions for
/// each method of a program.
///
/// ## Usage
///
/// ```dart
/// final signature = await program.rpc.methodName(...args, ctx);
/// ```
class RpcNamespace {
  final TransactionNamespace _transactionNamespace;
  final AnchorProvider _provider;
  final Map<String, RpcFunction> _functions = {};

  RpcNamespace._({
    required Idl idl,
    required TransactionNamespace transactionNamespace,
    required AnchorProvider provider,
  })  : _transactionNamespace = transactionNamespace,
        _provider = provider;

  /// Build RPC namespace from IDL
  static RpcNamespace build({
    required Idl idl,
    required TransactionNamespace transactionNamespace,
    required AnchorProvider provider,
  }) {
    final namespace = RpcNamespace._(
      idl: idl,
      transactionNamespace: transactionNamespace,
      provider: provider,
    );

    // Create RPC functions for each IDL instruction
    for (final instruction in idl.instructions) {
      namespace._functions[instruction.name] = RpcFunction(
        instruction: instruction,
        transactionNamespace: transactionNamespace,
        provider: provider,
      );
    }

    return namespace;
  }

  /// Get an RPC function by name
  RpcFunction? operator [](String name) => _functions[name];

  /// Get all instruction names
  Iterable<String> get names => _functions.keys;

  /// Check if an instruction exists
  bool contains(String name) => _functions.containsKey(name);

  @override
  String toString() {
    return 'RpcNamespace(instructions: ${_functions.keys.toList()})';
  }
}

/// Function for sending a signed transaction for a specific instruction
class RpcFunction {
  final IdlInstruction _instruction;
  final TransactionNamespace _transactionNamespace;
  final AnchorProvider _provider;

  RpcFunction({
    required IdlInstruction instruction,
    required TransactionNamespace transactionNamespace,
    required AnchorProvider provider,
  })  : _instruction = instruction,
        _transactionNamespace = transactionNamespace,
        _provider = provider;

  /// Send a signed transaction with the given arguments and context
  Future<String> call(
    List<dynamic> args,
    Context<Accounts> context,
  ) async {
    // Build the transaction using the transaction namespace
    final anchorTransaction = await _transactionNamespace[_instruction.name]!
        .callAsync(args, context);

    // Convert TransactionInstructions from namespace types to transaction types
    final convertedInstructions = anchorTransaction.instructions.map((ix) {
      // Convert AccountMeta from namespace type to transaction type
      final convertedAccounts = ix.accounts.map((account) {
        return transaction_types.AccountMeta(
          pubkey: account
              .publicKey, // namespace uses 'publicKey', transaction uses 'pubkey'
          isSigner: account.isSigner,
          isWritable: account.isWritable,
        );
      }).toList();

      return transaction_types.TransactionInstruction(
        programId: ix.programId,
        accounts: convertedAccounts,
        data: Uint8List.fromList(ix.data),
      );
    }).toList();

    // Convert AnchorTransaction to Transaction type for provider
    final transaction = transaction_types.Transaction(
      instructions: convertedInstructions,
      feePayer: anchorTransaction.feePayer,
      recentBlockhash: anchorTransaction.recentBlockhash,
    );

    // Send the transaction using the provider (which will sign it with the wallet)
    try {
      final signature = await _provider.sendAndConfirm(
        transaction,
        options: _provider.options,
      );

      return signature;
    } catch (error) {
      // Use RpcErrorParser to translate errors with IDL context
      final enhancedError = translateRpcError(error, idlErrors: {});
      throw enhancedError;
    }
  }

  /// Get the instruction name
  String get name => _instruction.name;

  @override
  String toString() {
    return 'RpcFunction(name: ${_instruction.name})';
  }
}
