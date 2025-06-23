/// Context and address resolution utilities for Anchor programs
///
/// This module provides the Context class and related utilities for handling
/// non-argument inputs to program instructions, including account resolution,
/// signers, and transaction management.

library;

import '../idl/idl.dart';
import '../types/transaction.dart';
import '../types/keypair.dart';
import '../types/commitment.dart';

/// Context provides all non-argument inputs for generating Anchor transactions
///
/// This includes accounts, signers, additional instructions, and transaction options.
class Context<T extends Accounts> {
  /// Accounts used in the instruction context
  final T? accounts;

  /// All accounts to pass into an instruction after the main accounts
  /// This can be used for optional or otherwise unknown accounts
  final List<AccountMeta>? remainingAccounts;

  /// Accounts that must sign a given transaction
  final List<Keypair>? signers;

  /// Instructions to run before a given method
  /// Often used to create accounts prior to executing a method
  final List<TransactionInstruction>? preInstructions;

  /// Instructions to run after a given method
  /// Often used to close accounts after executing a method
  final List<TransactionInstruction>? postInstructions;

  /// Commitment parameters to use for a transaction
  final CommitmentConfig? commitment;

  /// Options for transaction confirmation
  final ConfirmOptions? options;

  const Context({
    this.accounts,
    this.remainingAccounts,
    this.signers,
    this.preInstructions,
    this.postInstructions,
    this.commitment,
    this.options,
  });

  /// Create a copy of this context with updated values
  Context<T> copyWith({
    T? accounts,
    List<AccountMeta>? remainingAccounts,
    List<Keypair>? signers,
    List<TransactionInstruction>? preInstructions,
    List<TransactionInstruction>? postInstructions,
    CommitmentConfig? commitment,
    ConfirmOptions? options,
  }) {
    return Context<T>(
      accounts: accounts ?? this.accounts,
      remainingAccounts: remainingAccounts ?? this.remainingAccounts,
      signers: signers ?? this.signers,
      preInstructions: preInstructions ?? this.preInstructions,
      postInstructions: postInstructions ?? this.postInstructions,
      commitment: commitment ?? this.commitment,
      options: options ?? this.options,
    );
  }
}

/// Base class for account structures
///
/// A set of accounts mapping one-to-one to the program's accounts struct,
/// i.e., the type deriving `#[derive(Accounts)]`.
abstract class Accounts {
  /// Convert this accounts structure to a map representation
  Map<String, dynamic> toMap();

  /// Get an account by name
  dynamic getAccount(String name);

  /// Set an account by name
  void setAccount(String name, dynamic account);

  /// Get all account names
  List<String> getAccountNames();
}

/// Implementation of Accounts that uses a dynamic map structure
class DynamicAccounts extends Accounts {
  final Map<String, dynamic> _accounts = {};

  /// Create dynamic accounts from a map
  DynamicAccounts([Map<String, dynamic>? accounts]) {
    if (accounts != null) {
      _accounts.addAll(accounts);
    }
  }

  @override
  Map<String, dynamic> toMap() => Map.from(_accounts);

  @override
  dynamic getAccount(String name) => _accounts[name];

  @override
  void setAccount(String name, dynamic account) {
    _accounts[name] = account;
  }

  @override
  List<String> getAccountNames() => _accounts.keys.toList();

  /// Add multiple accounts at once
  void addAccounts(Map<String, dynamic> accounts) {
    _accounts.addAll(accounts);
  }

  /// Remove an account
  void removeAccount(String name) {
    _accounts.remove(name);
  }

  /// Check if an account exists
  bool hasAccount(String name) => _accounts.containsKey(name);
}

/// Options for transaction confirmation
class ConfirmOptions {
  /// Skip preflight checks
  final bool? skipPreflight;

  /// Commitment level for transaction confirmation
  final CommitmentConfig? commitment;

  /// Maximum number of retries
  final int? maxRetries;

  const ConfirmOptions({
    this.skipPreflight,
    this.commitment,
    this.maxRetries,
  });

  /// Convert to map for RPC calls
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (skipPreflight != null) map['skipPreflight'] = skipPreflight;
    if (commitment != null) map['commitment'] = commitment.toString();
    if (maxRetries != null) map['maxRetries'] = maxRetries;
    return map;
  }
}

/// Helper function to split arguments and context from method parameters
///
/// This separates the instruction arguments from the context object
/// based on the expected number of arguments in the IDL instruction.
ContextSplitResult splitArgsAndContext(
  IdlInstruction idlInstruction,
  List<dynamic> args,
) {
  final inputLen = idlInstruction.args.length;

  if (args.length > inputLen) {
    if (args.length != inputLen + 1) {
      throw ArgumentError(
        'Provided too many arguments ${args.length} to instruction '
        '$idlInstruction.name expecting: ${inputLen + 1} '
        '($inputLen args + 1 context)',
      );
    }

    final context = args.last;
    final instructionArgs = args.take(inputLen).toList();

    if (context is Context) {
      return ContextSplitResult(instructionArgs, context);
    } else if (context is Map<String, dynamic>) {
      // Convert map to Context
      return ContextSplitResult(
        instructionArgs,
        Context<DynamicAccounts>(
          accounts: context.containsKey('accounts')
              ? DynamicAccounts(context['accounts'] as Map<String, dynamic>?)
              : null,
          remainingAccounts: context['remainingAccounts'] as List<AccountMeta>?,
          signers: context['signers'] as List<Keypair>?,
          preInstructions:
              context['preInstructions'] as List<TransactionInstruction>?,
          postInstructions:
              context['postInstructions'] as List<TransactionInstruction>?,
          commitment: _parseCommitment(context['commitment']),
          options: context['options'] as ConfirmOptions?,
        ),
      );
    } else {
      throw ArgumentError(
        'Last argument must be a Context or Map<String, dynamic>, '
        'got ${context.runtimeType}',
      );
    }
  }

  // No context provided, return empty context
  return ContextSplitResult(
    args,
    const Context<DynamicAccounts>(),
  );
}

/// Parse commitment from various input types
CommitmentConfig? _parseCommitment(dynamic commitment) {
  if (commitment == null) return null;
  if (commitment is CommitmentConfig) return commitment;
  if (commitment is String) {
    final commitmentEnum = Commitment.fromString(commitment);
    return CommitmentConfig(commitmentEnum);
  }
  throw ArgumentError('Invalid commitment type: ${commitment.runtimeType}');
}

/// Result of splitting arguments and context
class ContextSplitResult {
  final List<dynamic> args;
  final Context context;

  const ContextSplitResult(this.args, this.context);
}
