/// Transaction types and utilities for Solana
///
/// This module defines transaction structures, instruction types,
/// and utilities for building and managing Solana transactions.

library;

import 'dart:typed_data';
import 'package:bs58/bs58.dart';
import '../utils/binary_writer.dart';
import 'public_key.dart';

// Helper functions for collections comparison
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _bytesEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Helper class for account information during transaction compilation
class _AccountInfo {
  final PublicKey pubkey;
  final bool isSigner;
  final bool isWritable;

  const _AccountInfo({
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
  });
}

/// Solana transaction instruction
class TransactionInstruction {
  /// Program ID that will process this instruction
  final PublicKey programId;

  /// Accounts required by this instruction
  final List<AccountMeta> accounts;

  /// Instruction data (serialized parameters)
  final Uint8List data;

  const TransactionInstruction({
    required this.programId,
    required this.accounts,
    required this.data,
  });

  /// Create an instruction from a build result
  factory TransactionInstruction.fromInstructionData(
    PublicKey programId,
    List<AccountMeta> accounts,
    Uint8List data,
  ) {
    return TransactionInstruction(
      programId: programId,
      accounts: accounts,
      data: data,
    );
  }

  /// Create an empty instruction (for testing)
  factory TransactionInstruction.empty() {
    return TransactionInstruction(
      programId: PublicKey.systemProgram,
      accounts: [],
      data: Uint8List(0),
    );
  }

  @override
  String toString() {
    return 'TransactionInstruction(programId: $programId, accounts: ${accounts.length}, data: ${data.length} bytes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionInstruction &&
        other.programId == programId &&
        _listEquals(other.accounts, accounts) &&
        _bytesEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hash(programId, accounts, data);
}

/// Account metadata for transaction instructions
class AccountMeta {
  /// The account's public key
  final PublicKey pubkey;

  /// Whether this account is required to sign the transaction
  final bool isSigner;

  /// Whether this account can be modified by the instruction
  final bool isWritable;

  const AccountMeta({
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
  });

  /// Create a signer account meta
  factory AccountMeta.signer(PublicKey pubkey, {bool isWritable = false}) {
    return AccountMeta(pubkey: pubkey, isSigner: true, isWritable: isWritable);
  }

  /// Create a writable account meta
  factory AccountMeta.writable(PublicKey pubkey, {bool isSigner = false}) {
    return AccountMeta(pubkey: pubkey, isSigner: isSigner, isWritable: true);
  }

  /// Create a read-only account meta
  factory AccountMeta.readonly(PublicKey pubkey) {
    return AccountMeta(pubkey: pubkey, isSigner: false, isWritable: false);
  }

  @override
  String toString() {
    final flags = <String>[];
    if (isSigner) flags.add('signer');
    if (isWritable) flags.add('writable');
    if (flags.isEmpty) flags.add('readonly');

    return 'AccountMeta(${pubkey.toBase58()}, ${flags.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountMeta &&
        other.pubkey == pubkey &&
        other.isSigner == isSigner &&
        other.isWritable == isWritable;
  }

  @override
  int get hashCode => Object.hash(pubkey, isSigner, isWritable);
}

/// Transaction signature (base-58 encoded string)
typedef TransactionSignature = String;

/// Transaction simulation result
class TransactionSimulationResult {
  final bool success;
  final List<String> logs;
  final String? error;
  final int? computeUnits;
  final List<String> warnings;

  const TransactionSimulationResult({
    required this.success,
    required this.logs,
    this.error,
    this.computeUnits,
    this.warnings = const [],
  });
}

/// Transaction confirmation status
class TransactionConfirmation {
  final bool success;
  final String? error;
  final Map<String, dynamic>? details;

  const TransactionConfirmation({
    required this.success,
    this.error,
    this.details,
  });
}

/// Status of a transaction confirmation
class TransactionStatus {
  final bool confirmed;
  final String? error;
  final int? slot;
  final int confirmations;

  const TransactionStatus({
    required this.confirmed,
    this.error,
    this.slot,
    this.confirmations = 0,
  });

  factory TransactionStatus.unconfirmed() {
    return const TransactionStatus(confirmed: false);
  }
}

/// Log message from transaction simulation or execution
class LogMessage {
  final String message;
  final bool isError;

  const LogMessage(this.message, {this.isError = false});

  @override
  String toString() => message;
}

/// Transaction error information
class TransactionError {
  final String message;
  final String? code;
  final Map<String, dynamic>? data;

  const TransactionError(
    this.message, {
    this.code,
    this.data,
  });

  @override
  String toString() => message;
}

/// Record of a completed transaction
class TransactionRecord {
  final String signature;
  final int? slot;
  final TransactionError? error;

  const TransactionRecord(
    this.signature, {
    this.slot,
    this.error,
  });

  /// Whether the transaction was successful
  bool get isSuccess => error == null;

  /// Whether the transaction failed
  bool get isError => error != null;

  @override
  String toString() => signature;
}

/// A Solana transaction
class Transaction {
  final List<TransactionInstruction> instructions;
  final PublicKey? feePayer;
  final String? recentBlockhash;
  final List<PublicKey> _signers = [];
  final Map<String, Uint8List> _signatures = {};

  Transaction({
    required this.instructions,
    this.feePayer,
    this.recentBlockhash,
  });

  Transaction setFeePayer(PublicKey payer) => Transaction(
        instructions: instructions,
        feePayer: payer,
        recentBlockhash: recentBlockhash,
      );

  Transaction setRecentBlockhash(String blockhash) => Transaction(
        instructions: instructions,
        feePayer: feePayer,
        recentBlockhash: blockhash,
      );

  void addSigners(List<PublicKey> signers) {
    for (final signer in signers) {
      if (!_signers.contains(signer)) {
        _signers.add(signer);
      }
    }
  }

  bool isSignedBy(PublicKey signer) {
    final key = signer.toBase58();
    return _signatures.containsKey(key);
  }

  void addSignature(PublicKey signer, Uint8List signature) {
    _signatures[signer.toBase58()] = signature;
  }

  List<PublicKey> get signers => List.unmodifiable(_signers);
  Map<String, Uint8List> get signatures => Map.unmodifiable(_signatures);

  /// Compile the transaction message for signing (omitting signatures).
  Uint8List compileMessage() {
    if (recentBlockhash == null) {
      throw StateError('Recent blockhash required');
    }
    return _serializeMessage();
  }

  Uint8List serialize() {
    if (recentBlockhash == null) {
      throw StateError('Recent blockhash required');
    }
    final message = _serializeMessage();
    final writer = BinaryWriter();
    final sigs = _signatures.values.toList();
    writer.writeCompactU16(sigs.length);
    for (final sig in sigs) {
      writer.write(sig);
    }
    writer.write(message);
    return writer.toArray();
  }

  Uint8List _serializeMessage() {
    final writer = BinaryWriter();

    // Get properly ordered account keys
    final accountData = _getOrderedAccountKeys();
    final accountKeys = accountData['keys'] as List<PublicKey>;
    final numRequiredSignatures = accountData['numRequiredSignatures'] as int;
    final numReadonlySignedAccounts =
        accountData['numReadonlySignedAccounts'] as int;
    final numReadonlyUnsignedAccounts =
        accountData['numReadonlyUnsignedAccounts'] as int;

    // Write message header
    writer.writeByte(numRequiredSignatures);
    writer.writeByte(numReadonlySignedAccounts);
    writer.writeByte(numReadonlyUnsignedAccounts);

    // Write account keys
    writer.writeCompactU16(accountKeys.length);
    for (final key in accountKeys) {
      writer.write(key.toBytes());
    }

    // Write blockhash as 32-byte binary representation (decode from base58)
    final blockhashBytes = base58.decode(recentBlockhash!);
    if (blockhashBytes.length != 32) {
      throw StateError(
          'Invalid blockhash: expected 32 bytes, got ${blockhashBytes.length}');
    }
    writer.write(blockhashBytes);

    // Write instructions
    writer.writeCompactU16(instructions.length);
    for (final ix in instructions) {
      _serializeInstruction(writer, ix, accountKeys);
    }
    return writer.toArray();
  }

  Map<String, dynamic> _getOrderedAccountKeys() {
    // Collect all unique accounts from instructions
    final allAccounts = <PublicKey, _AccountInfo>{};

    // Add fee payer as writable signer
    if (feePayer != null) {
      allAccounts[feePayer!] = _AccountInfo(
        pubkey: feePayer!,
        isSigner: true,
        isWritable: true,
      );
    }

    // Add other signers (typically read-only unless specified otherwise)
    for (final signer in _signers) {
      if (!allAccounts.containsKey(signer)) {
        allAccounts[signer] = _AccountInfo(
          pubkey: signer,
          isSigner: true,
          isWritable: false, // Default to read-only for non-fee-payer signers
        );
      }
    }

    // Process instruction accounts
    for (final ix in instructions) {
      // Add program ID as read-only non-signer
      if (!allAccounts.containsKey(ix.programId)) {
        allAccounts[ix.programId] = _AccountInfo(
          pubkey: ix.programId,
          isSigner: false,
          isWritable: false,
        );
      }

      // Add instruction accounts
      for (final meta in ix.accounts) {
        if (allAccounts.containsKey(meta.pubkey)) {
          // Merge with existing - more permissive wins
          final existing = allAccounts[meta.pubkey]!;
          allAccounts[meta.pubkey] = _AccountInfo(
            pubkey: meta.pubkey,
            isSigner: existing.isSigner || meta.isSigner,
            isWritable: existing.isWritable || meta.isWritable,
          );
        } else {
          allAccounts[meta.pubkey] = _AccountInfo(
            pubkey: meta.pubkey,
            isSigner: meta.isSigner,
            isWritable: meta.isWritable,
          );
        }
      }
    }

    // Sort accounts according to Solana specification:
    // 1. Writable signers
    // 2. Read-only signers
    // 3. Writable non-signers
    // 4. Read-only non-signers
    final sortedAccounts = allAccounts.values.toList();
    sortedAccounts.sort((a, b) {
      if (a.isSigner && b.isSigner) {
        // Both signers: writable first
        if (a.isWritable && !b.isWritable) return -1;
        if (!a.isWritable && b.isWritable) return 1;
        return 0;
      } else if (a.isSigner && !b.isSigner) {
        // Signers before non-signers
        return -1;
      } else if (!a.isSigner && b.isSigner) {
        // Non-signers after signers
        return 1;
      } else {
        // Both non-signers: writable first
        if (a.isWritable && !b.isWritable) return -1;
        if (!a.isWritable && b.isWritable) return 1;
        return 0;
      }
    }); // Calculate header values
    int numRequiredSignatures = 0;
    int numReadonlySignedAccounts = 0;
    int numReadonlyUnsignedAccounts = 0;

    print('DEBUG: Account ordering and privileges:');
    for (final account in sortedAccounts) {
      print(
          'DEBUG:   ${account.pubkey.toBase58()}: signer=${account.isSigner}, writable=${account.isWritable}');
      if (account.isSigner) {
        numRequiredSignatures++;
        if (!account.isWritable) {
          numReadonlySignedAccounts++;
        }
      } else if (!account.isWritable) {
        numReadonlyUnsignedAccounts++;
      }
    }

    print(
        'DEBUG: Header values - required: $numRequiredSignatures, readonly signed: $numReadonlySignedAccounts, readonly unsigned: $numReadonlyUnsignedAccounts');

    return {
      'keys': sortedAccounts.map((a) => a.pubkey).toList(),
      'numRequiredSignatures': numRequiredSignatures,
      'numReadonlySignedAccounts': numReadonlySignedAccounts,
      'numReadonlyUnsignedAccounts': numReadonlyUnsignedAccounts,
    };
  }

  /// Serialize an individual instruction
  void _serializeInstruction(BinaryWriter writer, TransactionInstruction ix,
      List<PublicKey> accountKeys) {
    // Program ID index
    final programIndex = accountKeys.indexOf(ix.programId);
    if (programIndex < 0) {
      throw StateError('Program ID not found in account keys');
    }
    writer.writeByte(programIndex);

    // Account indices
    writer.writeCompactU16(ix.accounts.length);
    for (final meta in ix.accounts) {
      final accountIndex = accountKeys.indexOf(meta.pubkey);
      if (accountIndex < 0) {
        throw StateError('Account ${meta.pubkey} not found in account keys');
      }
      writer.writeByte(accountIndex);
    }

    // Instruction data
    writer.writeCompactU16(ix.data.length);
    writer.write(ix.data);
  }
}

/// Solana transaction signature
class Signature {
  final Uint8List bytes;

  const Signature._(this.bytes);

  /// Create a signature from bytes
  factory Signature.fromBytes(Uint8List bytes) {
    if (bytes.length != 64) {
      throw ArgumentError('Signature must be exactly 64 bytes');
    }
    return Signature._(bytes);
  }

  /// Create a signature from base58 string
  factory Signature.fromString(String signature) {
    // This would decode base58, but for now we'll use a placeholder
    // since we don't have base58 decoder implemented yet
    throw UnimplementedError('Signature.fromString not yet implemented');
  }

  @override
  String toString() {
    // This would encode to base58, but for now return hex
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  bool operator ==(Object other) =>
      other is Signature && _bytesEquals(bytes, other.bytes);

  @override
  int get hashCode => Object.hashAll(bytes);
}
