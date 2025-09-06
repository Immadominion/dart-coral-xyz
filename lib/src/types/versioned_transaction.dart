/// VersionedTransaction support for Dart Coral XYZ Anchor Client
///
/// This module provides VersionedTransaction support that matches TypeScript SDK
/// functionality, including discriminator utilities and proper handling in provider
/// methods. Based on Solana's VersionedTransaction format with v0 support.

library;

import 'dart:typed_data';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/types/transaction.dart' as anchor_tx;
import 'package:coral_xyz/src/types/keypair.dart';
import 'package:coral_xyz/src/program/namespace/types.dart' as ns;

/// Abstract base class for versioned transactions
abstract class VersionedTransactionBase {
  /// Get transaction version
  TransactionVersion get version;

  /// Get transaction signatures
  List<Uint8List> get signatures;

  /// Get message content
  VersionedMessage get message;

  /// Add signature to transaction
  void addSignature(PublicKey publicKey, Uint8List signature);

  /// Serialize transaction to bytes
  Uint8List serialize();

  /// Sign the transaction with provided signers
  Future<void> signAsync(List<ns.Signer> signers);

  /// Sign the transaction with provided signers (sync version - limited support)
  void sign(List<ns.Signer> signers);
}

/// VersionedTransaction implementation matching TypeScript's web3.js VersionedTransaction
class VersionedTransaction extends VersionedTransactionBase {
  VersionedTransaction(this.message, [List<Uint8List>? signatures])
      : signatures = signatures ?? <Uint8List>[];

  @override
  final VersionedMessage message;

  @override
  List<Uint8List> signatures;

  @override
  TransactionVersion get version => message.version;

  @override
  void addSignature(PublicKey publicKey, Uint8List signature) {
    // Find the account index for this public key
    final accountKeys = message.getAccountKeys();
    final accountIndex = accountKeys.indexOf(publicKey);

    if (accountIndex == -1) {
      throw ArgumentError('Public key not found in account keys');
    }

    // Ensure signatures list is large enough
    while (signatures.length <= accountIndex) {
      signatures.add(Uint8List(64)); // Empty signature
    }

    signatures[accountIndex] = signature;
  }

  @override
  Uint8List serialize() {
    final message = this.message;
    final messageBytes = message.serialize();

    // Calculate total size: num_signatures (1) + signatures + message
    final totalSize = 1 + (signatures.length * 64) + messageBytes.length;
    final buffer = Uint8List(totalSize);
    int offset = 0;

    // Write number of signatures
    buffer[offset++] = signatures.length;

    // Write signatures
    for (final signature in signatures) {
      buffer.setRange(offset, offset + 64, signature);
      offset += 64;
    }

    // Write message
    buffer.setRange(offset, offset + messageBytes.length, messageBytes);

    return buffer;
  }

  @override
  Future<void> signAsync(List<ns.Signer> signers) async {
    final messageBytes = message.serialize();

    for (final signer in signers) {
      if (signer is Keypair) {
        final signature = await signer.signMessage(messageBytes.toList());
        addSignature(signer.publicKey, Uint8List.fromList(signature));
      }
    }
  }

  @override
  void sign(List<ns.Signer> signers) {
    // For sync version, we recommend using signAsync() instead
    throw UnimplementedError(
        'Use signAsync() instead for proper async signing');
  }

  /// Create a legacy transaction from a regular Transaction
  factory VersionedTransaction.fromLegacyTransaction(
      anchor_tx.Transaction transaction) {
    final message = VersionedMessage.fromLegacyMessage(
      LegacyMessage.fromTransaction(transaction),
    );
    return VersionedTransaction(message);
  }

  @override
  String toString() => 'VersionedTransaction(version: ${version.name}, '
      'signatures: ${signatures.length}, message: $message)';
}

/// Transaction version enum
enum TransactionVersion {
  legacy,
  v0;

  /// Create from version number
  factory TransactionVersion.fromNumber(int? version) {
    if (version == null) return TransactionVersion.legacy;
    switch (version) {
      case 0:
        return TransactionVersion.v0;
      default:
        throw ArgumentError('Unsupported transaction version: $version');
    }
  }
}

/// Abstract versioned message
abstract class VersionedMessage {
  /// Get transaction version
  TransactionVersion get version;

  /// Get account keys involved in transaction
  List<PublicKey> getAccountKeys();

  /// Serialize message to bytes
  Uint8List serialize();

  /// Create from legacy message
  factory VersionedMessage.fromLegacyMessage(LegacyMessage message) =>
      LegacyVersionedMessage(message);

  /// Create v0 message (future implementation)
  factory VersionedMessage.v0({
    required MessageHeader header,
    required List<PublicKey> staticAccountKeys,
    required String recentBlockhash,
    required List<CompiledInstruction> instructions,
    List<PublicKey>? addressTableLookups,
  }) =>
      V0VersionedMessage(
        header: header,
        staticAccountKeys: staticAccountKeys,
        recentBlockhash: recentBlockhash,
        instructions: instructions,
        addressTableLookups: addressTableLookups ?? [],
      );
}

/// Legacy transaction message (version = legacy)
class LegacyVersionedMessage implements VersionedMessage {
  LegacyVersionedMessage(this.message);

  final LegacyMessage message;

  @override
  TransactionVersion get version => TransactionVersion.legacy;

  @override
  List<PublicKey> getAccountKeys() => message.accountKeys;

  @override
  Uint8List serialize() => message.serialize();

  @override
  String toString() => 'LegacyVersionedMessage($message)';
}

/// V0 transaction message (version = 0)
class V0VersionedMessage implements VersionedMessage {
  V0VersionedMessage({
    required this.header,
    required this.staticAccountKeys,
    required this.recentBlockhash,
    required this.instructions,
    this.addressTableLookups = const [],
  });

  final MessageHeader header;
  final List<PublicKey> staticAccountKeys;
  final String recentBlockhash;
  final List<CompiledInstruction> instructions;
  final List<PublicKey> addressTableLookups;

  @override
  TransactionVersion get version => TransactionVersion.v0;

  @override
  List<PublicKey> getAccountKeys() {
    // For v0 transactions, account keys come from static keys + lookup tables
    // TODO: Implement address table lookup resolution
    return staticAccountKeys;
  }

  @override
  Uint8List serialize() {
    // TODO: Implement v0 message serialization
    // This is a complex format that includes address lookup tables
    throw UnimplementedError('V0 message serialization not yet implemented');
  }

  @override
  String toString() => 'V0VersionedMessage(header: $header, '
      'staticAccountKeys: ${staticAccountKeys.length}, '
      'recentBlockhash: $recentBlockhash, '
      'instructions: ${instructions.length}, '
      'addressTableLookups: ${addressTableLookups.length})';
}

/// Legacy message structure
class LegacyMessage {
  const LegacyMessage({
    required this.header,
    required this.accountKeys,
    required this.recentBlockhash,
    required this.instructions,
  });

  final MessageHeader header;
  final List<PublicKey> accountKeys;
  final String recentBlockhash;
  final List<CompiledInstruction> instructions;

  /// Create from anchor Transaction
  factory LegacyMessage.fromTransaction(anchor_tx.Transaction transaction) {
    // Convert anchor transaction to legacy message format
    final accountKeys = <PublicKey>[];
    final compiledInstructions = <CompiledInstruction>[];

    // Collect all unique account keys
    final uniqueAccounts = <PublicKey, int>{};

    // Add fee payer first if set
    if (transaction.feePayer != null) {
      uniqueAccounts[transaction.feePayer!] = 0;
      accountKeys.add(transaction.feePayer!);
    }

    // Process instructions and collect accounts
    for (final instruction in transaction.instructions) {
      // Add program ID
      if (!uniqueAccounts.containsKey(instruction.programId)) {
        uniqueAccounts[instruction.programId] = accountKeys.length;
        accountKeys.add(instruction.programId);
      }

      // Add account keys from instruction
      for (final account in instruction.accounts) {
        if (!uniqueAccounts.containsKey(account.pubkey)) {
          uniqueAccounts[account.pubkey] = accountKeys.length;
          accountKeys.add(account.pubkey);
        }
      }
    }

    // Compile instructions
    for (final instruction in transaction.instructions) {
      final programIdIndex = uniqueAccounts[instruction.programId]!;
      final accountIndices = instruction.accounts
          .map((account) => uniqueAccounts[account.pubkey]!)
          .toList();

      compiledInstructions.add(CompiledInstruction(
        programIdIndex: programIdIndex,
        accounts: accountIndices,
        data: instruction.data,
      ));
    }

    // Create message header
    final header = MessageHeader(
      numRequiredSignatures: 1, // Fee payer signature
      numReadonlySignedAccounts: 0,
      numReadonlyUnsignedAccounts: accountKeys
          .where((key) => !transaction.instructions.any((ix) =>
              ix.accounts.any((acc) => acc.pubkey == key && acc.isWritable)))
          .length,
    );

    return LegacyMessage(
      header: header,
      accountKeys: accountKeys,
      recentBlockhash: transaction.recentBlockhash ?? '',
      instructions: compiledInstructions,
    );
  }

  /// Serialize to bytes
  Uint8List serialize() {
    // TODO: Implement legacy message serialization
    // This would involve binary encoding of all components
    throw UnimplementedError(
        'Legacy message serialization not yet implemented');
  }

  @override
  String toString() => 'LegacyMessage(header: $header, '
      'accountKeys: ${accountKeys.length}, '
      'recentBlockhash: $recentBlockhash, '
      'instructions: ${instructions.length})';
}

/// Message header structure
class MessageHeader {
  const MessageHeader({
    required this.numRequiredSignatures,
    required this.numReadonlySignedAccounts,
    required this.numReadonlyUnsignedAccounts,
  });

  final int numRequiredSignatures;
  final int numReadonlySignedAccounts;
  final int numReadonlyUnsignedAccounts;

  @override
  String toString() => 'MessageHeader('
      'numRequiredSignatures: $numRequiredSignatures, '
      'numReadonlySignedAccounts: $numReadonlySignedAccounts, '
      'numReadonlyUnsignedAccounts: $numReadonlyUnsignedAccounts)';
}

/// Compiled instruction structure
class CompiledInstruction {
  const CompiledInstruction({
    required this.programIdIndex,
    required this.accounts,
    required this.data,
  });

  final int programIdIndex;
  final List<int> accounts;
  final Uint8List data;

  @override
  String toString() => 'CompiledInstruction('
      'programIdIndex: $programIdIndex, '
      'accounts: $accounts, '
      'data: ${data.length} bytes)';
}

/// Utility functions for VersionedTransaction discrimination and handling
class VersionedTransactionUtils {
  /// Check if a transaction is a VersionedTransaction
  /// Matches TypeScript's isVersionedTransaction function
  static bool isVersionedTransaction(dynamic tx) {
    if (tx is VersionedTransaction) return true;
    if (tx is anchor_tx.Transaction) return false;

    // Duck typing check for version property
    try {
      return tx?.version != null;
    } catch (e) {
      return false;
    }
  }

  /// Convert a regular Transaction to VersionedTransaction
  static VersionedTransaction fromLegacyTransaction(
      anchor_tx.Transaction transaction) {
    return VersionedTransaction.fromLegacyTransaction(transaction);
  }

  /// Get signatures from either transaction type
  static List<Uint8List> getSignatures(dynamic tx) {
    if (tx is VersionedTransaction) {
      return tx.signatures;
    } else if (tx is anchor_tx.Transaction) {
      // Convert regular transaction signatures to format expected
      return tx.signatures.values.toList();
    }
    throw ArgumentError('Unsupported transaction type');
  }

  /// Serialize either transaction type
  static Uint8List serialize(dynamic tx) {
    if (tx is VersionedTransaction) {
      return tx.serialize();
    } else if (tx is anchor_tx.Transaction) {
      return tx.serialize();
    }
    throw ArgumentError('Unsupported transaction type');
  }
}
