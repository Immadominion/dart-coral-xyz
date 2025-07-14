/// Account resolution system for Anchor programs
///
/// This module provides the AccountsResolver class which automatically
/// resolves missing account addresses based on IDL specifications,
/// including PDA derivation and account relationships.

library;

import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/program/pda_utils.dart';
import 'package:coral_xyz_anchor/src/program/context.dart';

/// Resolves account addresses for instruction contexts
///
/// This class automatically populates missing accounts by:
/// - Deriving PDAs from specifications
/// - Resolving account relationships
/// - Validating account constraints
class AccountsResolver {

  AccountsResolver({
    required List<dynamic> args,
    required Map<String, dynamic> accounts,
    required AnchorProvider provider,
    required PublicKey programId,
    required IdlInstruction idlInstruction,
    required List<IdlTypeDef> idlTypes,
  })  : _args = args,
        _accounts = Map.from(accounts),
        _provider = provider,
        _programId = programId,
        _idlInstruction = idlInstruction,
        _idlTypes = idlTypes;
  final List<dynamic> _args;
  final Map<String, dynamic> _accounts;
  final AnchorProvider _provider;
  final PublicKey _programId;
  final IdlInstruction _idlInstruction;
  // ignore: unused_field
  final List<IdlTypeDef> _idlTypes;

  /// Resolve all accounts for the instruction
  ///
  /// This method attempts to resolve any missing accounts by:
  /// 1. Resolving constant accounts (like system program)
  /// 2. Deriving PDAs from IDL specifications
  /// 3. Applying custom resolution logic
  Future<Map<String, PublicKey>> resolve() async {
    // Start with a copy of provided accounts
    final resolvedAccounts = <String, PublicKey>{};

    // Convert provided accounts to PublicKey instances
    for (final entry in _accounts.entries) {
      final pubkey = _convertToPublicKey(entry.value);
      if (pubkey != null) {
        resolvedAccounts[entry.key] = pubkey;
      }
    }

    // Resolve constant accounts (signers, system programs, etc.)
    _resolveConstantAccounts(resolvedAccounts);

    // Resolve PDAs and other derived accounts
    await _resolveDerivedAccounts(resolvedAccounts);

    return resolvedAccounts;
  }

  /// Update the arguments for resolution
  void updateArgs(List<dynamic> args) {
    _args.clear();
    _args.addAll(args);
  }

  /// Update the accounts for resolution
  void updateAccounts(Map<String, dynamic> accounts) {
    _accounts.clear();
    _accounts.addAll(accounts);
  }

  /// Resolve constant accounts like signers and well-known programs
  void _resolveConstantAccounts(Map<String, PublicKey> resolved) {
    for (final accountItem in _idlInstruction.accounts) {
      _resolveConstantAccount(accountItem, resolved);
    }
  }

  /// Resolve a single account item (handles both single accounts and groups)
  void _resolveConstantAccount(
      IdlInstructionAccountItem accountItem, Map<String, PublicKey> resolved,) {
    if (accountItem is IdlInstructionAccount) {
      final name = accountItem.name;

      // Skip if already resolved
      if (resolved.containsKey(name)) return;

      // Resolve signers to provider public key
      if (accountItem.signer && _provider.publicKey != null) {
        resolved[name] = _provider.publicKey!;
      }

      // Resolve well-known program accounts
      if (name.toLowerCase().contains('system')) {
        resolved[name] = PublicKey.systemProgram;
      }

      // Resolve accounts with fixed addresses
      if (accountItem.address != null) {
        try {
          resolved[name] = PublicKey.fromBase58(accountItem.address!);
        } catch (e) {
          // Invalid address, skip
        }
      }
    } else if (accountItem is IdlInstructionAccounts) {
      // Recursively resolve account groups
      for (final account in accountItem.accounts) {
        _resolveConstantAccount(account, resolved);
      }
    }
  }

  /// Resolve derived accounts like PDAs
  Future<void> _resolveDerivedAccounts(Map<String, PublicKey> resolved) async {
    final maxDepth = 16; // Prevent infinite recursion
    int depth = 0;

    while (depth < maxDepth) {
      final initialSize = resolved.length;

      // Try to resolve PDAs for accounts that have PDA specifications
      await _resolvePdasForAccountItems(_idlInstruction.accounts, resolved);

      // If no new accounts were resolved, break
      if (resolved.length == initialSize) break;

      depth++;
    }

    // Check for unresolved required accounts
    final missingAccounts = _getMissingRequiredAccounts(resolved);

    if (missingAccounts.isNotEmpty) {
      throw StateError(
          'Failed to resolve required accounts: ${missingAccounts.join(', ')}',);
    }
  }

  /// Resolve PDAs for a list of account items
  Future<void> _resolvePdasForAccountItems(
    List<IdlInstructionAccountItem> accountItems,
    Map<String, PublicKey> resolved,
  ) async {
    for (final accountItem in accountItems) {
      if (accountItem is IdlInstructionAccount) {
        await _resolvePdaForAccount(accountItem, resolved);
      } else if (accountItem is IdlInstructionAccounts) {
        // Recursively resolve account groups
        await _resolvePdasForAccountItems(
            accountItem.accounts.cast<IdlInstructionAccountItem>(), resolved,);
      }
    }
  }

  /// Resolve PDA for a single account
  Future<void> _resolvePdaForAccount(
    IdlInstructionAccount account,
    Map<String, PublicKey> resolved,
  ) async {
    final name = account.name;

    // Skip if already resolved
    if (resolved.containsKey(name)) return;

    // Try to resolve PDA if specification exists
    if (account.pda != null) {
      try {
        final pdaAddress = await _derivePda(account.pda!, resolved);
        if (pdaAddress != null) {
          resolved[name] = pdaAddress;
        }
      } catch (e) {
        // PDA derivation failed, continue
      }
    }

    // Handle account relations
    if (account.relations != null && account.relations!.isNotEmpty) {
      final relationName = account.relations!.first;
      if (resolved.containsKey(relationName)) {
        // For now, just copy the relation address
        // In a full implementation, you'd fetch and parse account data
        resolved[name] = resolved[relationName]!;
      }
    }
  }

  /// Derive a PDA from the IDL specification
  Future<PublicKey?> _derivePda(
      IdlPda pda, Map<String, PublicKey> resolved,) async {
    final seeds = <Uint8List>[];

    // Convert all seeds to byte arrays
    for (final seed in pda.seeds) {
      final seedBytes = await _seedToBytes(seed, resolved);
      if (seedBytes == null) return null; // Missing dependency
      seeds.add(Uint8List.fromList(seedBytes));
    }

    // Determine program ID for PDA derivation
    PublicKey programId = _programId;
    if (pda.programId != null) {
      final programSeedBytes = await _seedToBytes(pda.programId!, resolved);
      if (programSeedBytes != null) {
        try {
          programId = PublicKey.fromBytes(programSeedBytes);
        } catch (e) {
          return null;
        }
      }
    }

    // Use proper PDA derivation
    try {
      final result = await PublicKey.findProgramAddress(seeds, programId);
      return result.address;
    } catch (e) {
      return null;
    }
  }

  /// Convert a seed specification to bytes
  Future<List<int>?> _seedToBytes(
      IdlSeed seed, Map<String, PublicKey> resolved,) async {
    if (seed is IdlSeedConst) {
      return seed.value;
    } else if (seed is IdlSeedArg) {
      return _argToBytes(seed.path);
    } else if (seed is IdlSeedAccount) {
      return _accountToBytes(seed.path, resolved);
    }
    return null;
  }

  /// Convert instruction argument to bytes
  List<int>? _argToBytes(String argPath) {
    final pathParts = argPath.split('.');
    final argName = pathParts.first;

    // Find the argument in the instruction
    final argIndex =
        _idlInstruction.args.indexWhere((arg) => arg.name == argName);
    if (argIndex == -1 || argIndex >= _args.length) return null;

    dynamic value = _args[argIndex];
    if (value == null) return null;

    // Navigate nested paths
    for (int i = 1; i < pathParts.length; i++) {
      if (value is Map<String, dynamic>) {
        value = value[pathParts[i]];
      } else {
        return null;
      }
    }

    return _valueToBytes(value);
  }

  /// Convert account reference to bytes
  List<int>? _accountToBytes(
      String accountPath, Map<String, PublicKey> resolved,) {
    final pathParts = accountPath.split('.');
    final accountName = pathParts.first;

    if (!resolved.containsKey(accountName)) return null;

    final accountPubkey = resolved[accountName]!;

    // If it's just the pubkey, return its bytes
    if (pathParts.length == 1) {
      return accountPubkey.bytes;
    }

    // For nested account data, this would require fetching and parsing
    // the account data - simplified implementation returns null
    return null;
  }

  /// Convert a value to bytes based on its type
  List<int>? _valueToBytes(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      // Try to parse as public key first
      try {
        return PublicKey.fromBase58(value).bytes;
      } catch (e) {
        // If not a valid public key, treat as string
        return value.codeUnits;
      }
    }

    if (value is int) {
      // Convert int to little-endian bytes (8 bytes for u64)
      final bytes = <int>[];
      for (int i = 0; i < 8; i++) {
        bytes.add((value >> (i * 8)) & 0xFF);
      }
      return bytes;
    }

    if (value is List<int>) {
      return value;
    }

    // For other types, convert to string and then to bytes
    return value.toString().codeUnits;
  }

  /// Get missing required accounts
  List<String> _getMissingRequiredAccounts(Map<String, PublicKey> resolved) {
    final missing = <String>[];
    _findMissingAccounts(_idlInstruction.accounts, resolved, missing);
    return missing;
  }

  /// Recursively find missing accounts in account items
  void _findMissingAccounts(
    List<IdlInstructionAccountItem> accountItems,
    Map<String, PublicKey> resolved,
    List<String> missing,
  ) {
    for (final accountItem in accountItems) {
      if (accountItem is IdlInstructionAccount) {
        if (!accountItem.optional && !resolved.containsKey(accountItem.name)) {
          missing.add(accountItem.name);
        }
      } else if (accountItem is IdlInstructionAccounts) {
        _findMissingAccounts(
            accountItem.accounts.cast<IdlInstructionAccountItem>(),
            resolved,
            missing,);
      }
    }
  }

  /// Convert various account representations to PublicKey
  PublicKey? _convertToPublicKey(dynamic account) {
    if (account is PublicKey) {
      return account;
    } else if (account is String) {
      try {
        return PublicKey.fromBase58(account);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Validate resolved accounts against IDL constraints
  Future<bool> validateAccounts(Map<String, PublicKey> accounts) async => AddressValidator.validateAccountRelationships(
      accounts.map((k, v) => MapEntry(k, v.toBase58())),
      _idlInstruction.accounts,
    );

  /// Get account metas for instruction building
  List<AccountMeta> getAccountMetas(Map<String, PublicKey> accounts) {
    final metas = <AccountMeta>[];

    for (final accountSpec in _idlInstruction.accounts) {
      // Handle nested account groups
      if (accountSpec is IdlInstructionAccounts) {
        // Recursively process nested accounts
        for (final nestedSpec in accountSpec.accounts) {
          final pubkey = accounts[nestedSpec.name];
          if (pubkey == null) {
            if (nestedSpec is IdlInstructionAccount && !nestedSpec.optional) {
              throw StateError(
                  'Required account \\${nestedSpec.name} not found',);
            }
            continue;
          }

          metas.add(AccountMeta(
            pubkey: pubkey,
            isSigner:
                nestedSpec is IdlInstructionAccount ? nestedSpec.signer : false,
            isWritable: nestedSpec is IdlInstructionAccount
                ? nestedSpec.writable
                : false,
          ),);
        }
      } else if (accountSpec is IdlInstructionAccount) {
        final pubkey = accounts[accountSpec.name];
        if (pubkey == null) {
          if (!accountSpec.optional) {
            throw StateError('Required account ${accountSpec.name} not found');
          }
          continue;
        }

        metas.add(AccountMeta(
          pubkey: pubkey,
          isSigner: accountSpec.signer,
          isWritable: accountSpec.writable,
        ),);
      }
    }

    return metas;
  }

  PublicKey get programId => _programId;
}

/// Factory for creating account resolvers
class AccountResolverFactory {
  /// Create an accounts resolver for a specific instruction
  static AccountsResolver create({
    required List<dynamic> args,
    required Map<String, dynamic> accounts,
    required AnchorProvider provider,
    required PublicKey programId,
    required IdlInstruction idlInstruction,
    required List<IdlTypeDef> idlTypes,
  }) => AccountsResolver(
      args: args,
      accounts: accounts,
      provider: provider,
      programId: programId,
      idlInstruction: idlInstruction,
      idlTypes: idlTypes,
    );
}

/// Utility for resolving accounts from context
class ContextAccountResolver {
  /// Resolve accounts from a context object
  static Future<Map<String, PublicKey>> resolveFromContext(
    Context context,
    IdlInstruction idlInstruction,
    AnchorProvider provider,
    PublicKey programId,
    List<IdlTypeDef> idlTypes, {
    List<dynamic> args = const [],
  }) async {
    final accounts = context.accounts?.toMap() ?? {};

    final resolver = AccountResolverFactory.create(
      args: args,
      accounts: accounts,
      provider: provider,
      programId: programId,
      idlInstruction: idlInstruction,
      idlTypes: idlTypes,
    );

    return resolver.resolve();
  }

  /// Merge resolved accounts with remaining accounts from context
  static List<AccountMeta> buildAccountMetas(
    Map<String, PublicKey> resolvedAccounts,
    Context context,
    IdlInstruction idlInstruction,
  ) {
    final metas = <AccountMeta>[];

    for (final accountSpec in idlInstruction.accounts) {
      // Handle nested account groups
      if (accountSpec is IdlInstructionAccounts) {
        // Recursively process nested accounts
        for (final nestedSpec in accountSpec.accounts) {
          final pubkey = resolvedAccounts[nestedSpec.name];
          if (pubkey == null) {
            if (nestedSpec is IdlInstructionAccount && !nestedSpec.optional) {
              throw StateError(
                  'Required account \\${nestedSpec.name} not found',);
            }
            continue;
          }

          metas.add(AccountMeta(
            pubkey: pubkey,
            isSigner:
                nestedSpec is IdlInstructionAccount ? nestedSpec.signer : false,
            isWritable: nestedSpec is IdlInstructionAccount
                ? nestedSpec.writable
                : false,
          ),);
        }
      } else if (accountSpec is IdlInstructionAccount) {
        final pubkey = resolvedAccounts[accountSpec.name];
        if (pubkey == null) {
          if (!accountSpec.optional) {
            throw StateError('Required account ${accountSpec.name} not found');
          }
          continue;
        }

        metas.add(AccountMeta(
          pubkey: pubkey,
          isSigner: accountSpec.signer,
          isWritable: accountSpec.writable,
        ),);
      }
    }

    // Add remaining accounts if provided
    if (context.remainingAccounts != null) {
      metas.addAll(context.remainingAccounts!);
    }

    return metas;
  }
}
