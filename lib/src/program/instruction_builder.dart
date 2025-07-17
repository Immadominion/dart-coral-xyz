// Instruction Builder for Dart Coral XYZ Anchor Client
// Phase 7.1: Implements fluent API for instruction building, account meta generation, data serialization, and validation.

import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/coder/instruction_coder.dart';
import 'package:coral_xyz_anchor/src/program/accounts_resolver.dart';
import 'package:coral_xyz_anchor/src/program/context.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart' as tx;
import 'package:coral_xyz_anchor/src/program/namespace/types.dart' show Signer;
import 'dart:typed_data';

/// Builds instructions for Anchor programs with a fluent API
///
/// Features:
/// - Fluent builder pattern API
/// - Automatic account meta generation
/// - PDA resolution
/// - Instruction data serialization
/// - Comprehensive validation
class InstructionBuilder {
  /// Create a new instruction builder
  InstructionBuilder({
    required this.idl,
    required this.methodName,
    required this.instructionCoder,
    required this.accountsResolver,
  });
  final Idl idl;
  final String methodName;
  final InstructionCoder instructionCoder;
  final AccountsResolver accountsResolver;
  final Map<String, dynamic> _args = {};
  final Map<String, dynamic> _accounts = {};
  final List<PublicKey> _signers = [];
  final List<tx.AccountMeta> _remainingAccounts = [];
  Context? _context;
  bool _validated = false;

  /// Set instruction arguments
  ///
  /// [args] - Map of argument name to value
  InstructionBuilder args(Map<String, dynamic> args) {
    _args.addAll(args);
    return this;
  }

  /// Set instruction accounts
  ///
  /// [accounts] - Map of account name to public key or account info, or an accounts object with toMap() method
  InstructionBuilder accounts(dynamic accounts) {
    if (accounts is Map<String, dynamic>) {
      _accounts.addAll(accounts);
    } else if (accounts is Map<String, PublicKey>) {
      // Convert Map<String, PublicKey> to Map<String, dynamic>
      final dynamicMap = <String, dynamic>{};
      accounts.forEach((key, value) {
        dynamicMap[key] = value;
      });
      _accounts.addAll(dynamicMap);
    } else {
      // Try to call toMap() method if it exists
      try {
        final map = accounts.toMap();
        if (map is Map<String, PublicKey>) {
          final dynamicMap = <String, dynamic>{};
          map.forEach((key, value) {
            dynamicMap[key] = value;
          });
          _accounts.addAll(dynamicMap);
        } else if (map is Map<String, dynamic>) {
          _accounts.addAll(map);
        } else {
          throw ArgumentError(
              'toMap() must return Map<String, PublicKey> or Map<String, dynamic>');
        }
      } catch (e) {
        throw ArgumentError(
            'Invalid accounts type: ${accounts.runtimeType}. Expected Map<String, dynamic>, Map<String, PublicKey>, or object with toMap() method');
      }
    }
    return this;
  }

  /// Add a signer to the instruction
  ///
  /// [signer] - The public key of the signer to add
  InstructionBuilder addSigner(PublicKey signer) {
    if (!_signers.contains(signer)) {
      _signers.add(signer);
    }
    return this;
  }

  /// Add multiple signers to the instruction
  ///
  /// [signers] - List of public keys to add as signers
  InstructionBuilder addSigners(List<PublicKey> signers) {
    for (final signer in signers) {
      addSigner(signer);
    }
    return this;
  }

  /// Set signers for the instruction (fluent API method)
  ///
  /// [signers] - List of signers to set
  /// Can accept a list of [PublicKey] or [Signer] objects
  InstructionBuilder signers(List<dynamic> signers) {
    // Convert Signer objects to PublicKey
    final pubKeys = <PublicKey>[];

    for (final signer in signers) {
      if (signer is PublicKey) {
        pubKeys.add(signer);
      } else if (signer is Signer) {
        pubKeys.add(signer.publicKey);
      } else {
        throw ArgumentError(
            'Invalid signer type: ${signer.runtimeType}. Expected PublicKey or Signer.');
      }
    }

    return addSigners(pubKeys);
  }

  /// Add remaining accounts that are not part of the instruction's account struct
  ///
  /// [remainingAccounts] - List of additional account metas
  InstructionBuilder remainingAccounts(List<tx.AccountMeta> remainingAccounts) {
    _remainingAccounts.addAll(remainingAccounts);
    return this;
  }

  /// Set the instruction context
  ///
  /// [context] - The context for this instruction
  InstructionBuilder context(Context context) {
    _context = context;
    return this;
  }

  /// Get the IDL instruction for this builder
  IdlInstruction get _instruction => idl.instructions.firstWhere(
        (ix) => ix.name == methodName,
        orElse: () =>
            throw IdlError('Instruction $methodName not found in IDL'),
      );

  /// Validate the instruction arguments and accounts
  ///
  /// Throws if validation fails
  void _validate() {
    if (_validated) return;

    final instruction = _instruction;

    // Validate args
    for (final arg in instruction.args) {
      if (!_args.containsKey(arg.name)) {
        throw IdlError('Missing required argument: ${arg.name}');
      }
      // TODO: Add type validation for args
    }

    // Validate accounts recursively
    void validateAccounts(List<IdlInstructionAccountItem> accounts) {
      for (final acct in accounts) {
        if (acct is IdlInstructionAccount) {
          if (!_accounts.containsKey(acct.name) && !acct.optional) {
            throw IdlError('Missing required account: ${acct.name}');
          }
          // Validate signer requirement
          if (acct.isSigner) {
            final pubkey = _accounts[acct.name];
            if (pubkey is PublicKey && !_signers.contains(pubkey)) {
              throw IdlError('Account ${acct.name} must be a signer');
            }
          }
        } else if (acct is IdlInstructionAccounts) {
          validateAccounts(acct.accounts);
        }
      }
    }

    validateAccounts(instruction.accounts);
    _validated = true;
  }

  /// Build the instruction data
  Future<Uint8List> _buildData() async {
    try {
      return Uint8List.fromList(instructionCoder.encode(methodName, _args));
    } catch (e) {
      throw IdlError('Failed to serialize instruction data: $e');
    }
  }

  /// Generate account metas from the resolved accounts
  List<tx.AccountMeta> _generateMetas(Map<String, PublicKey> resolvedAccounts) {
    final instruction = _instruction;
    final metas = <tx.AccountMeta>[];

    void addMetas(List<IdlInstructionAccountItem> accounts) {
      for (final acct in accounts) {
        if (acct is IdlInstructionAccount) {
          final pubkey = resolvedAccounts[acct.name];
          if (pubkey == null && acct.optional) continue;
          if (pubkey == null) {
            throw IdlError('Account ${acct.name} could not be resolved');
          }

          metas.add(
            tx.AccountMeta(
              pubkey: pubkey,
              isSigner: acct.isSigner || _signers.contains(pubkey),
              isWritable: acct.writable,
            ),
          );
        } else if (acct is IdlInstructionAccounts) {
          addMetas(acct.accounts);
        }
      }
    }

    addMetas(instruction.accounts);
    metas.addAll(_remainingAccounts);
    return metas;
  }

  /// Build the complete instruction
  ///
  /// Returns the built instruction with data, account metas, and resolved accounts
  Future<InstructionBuildResult> build() async {
    _validate();

    // Update the accounts resolver with current accounts
    accountsResolver.updateAccounts(_accounts);

    // Resolve accounts (including PDAs)
    final resolvedAccounts = await accountsResolver.resolve();

    // Build instruction data
    final data = await _buildData();

    // Generate account metas
    final metas = _generateMetas(resolvedAccounts);

    return InstructionBuildResult(
      data: data,
      metas: metas,
      resolvedAccounts: resolvedAccounts,
      signers: _signers,
      programId: accountsResolver.programId,
      context: _context,
    );
  }

  /// The programId for this instruction
  PublicKey get programId => accountsResolver.programId;
}

/// Result of building an instruction
class InstructionBuildResult {
  const InstructionBuildResult({
    required this.data,
    required this.metas,
    required this.resolvedAccounts,
    required this.signers,
    required this.programId,
    this.context,
  });
  final Uint8List data;
  final List<tx.AccountMeta> metas;
  final Map<String, dynamic> resolvedAccounts;
  final List<PublicKey> signers;
  final PublicKey programId;
  final Context? context;

  @override
  String toString() =>
      'InstructionBuildResult(metas: ${metas.length}, signers: ${signers.length})';
}
