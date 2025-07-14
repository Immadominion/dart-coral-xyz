/// Clean Transaction Implementation
///
/// This file provides a working transaction serialization implementation
/// using the espresso-cash solana package, replacing all broken stubs.
library;

import 'dart:typed_data';
import 'package:solana/solana.dart' as solana;
import 'package:solana/encoder.dart' as encoder;
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Account metadata for transaction building
class AccountMeta {

  const AccountMeta({
    required this.publicKey,
    required this.isSigner,
    required this.isWritable,
  });
  final PublicKey publicKey;
  final bool isSigner;
  final bool isWritable;

  @override
  String toString() =>
      'AccountMeta(pubkey: $publicKey, signer: $isSigner, writable: $isWritable)';
}

/// Transaction instruction
class TransactionInstruction {

  const TransactionInstruction({
    required this.programId,
    required this.accounts,
    required this.data,
  });
  final PublicKey programId;
  final List<AccountMeta> accounts;
  final Uint8List data;

  @override
  String toString() =>
      'TransactionInstruction(programId: $programId, accounts: ${accounts.length}, data: ${data.length} bytes)';
}

/// Transaction implementation using espresso-cash solana package
class Transaction {

  Transaction({
    required this.instructions,
    this.feePayer,
    this.recentBlockhash,
  });
  final List<TransactionInstruction> instructions;
  final PublicKey? feePayer;
  final String? recentBlockhash;

  /// Convert to espresso-cash format and serialize
  Future<Uint8List> serialize({
    required solana.Ed25519HDKeyPair signer,
    required String recentBlockhash,
  }) async {
    // Convert instructions to espresso-cash format
    final workingInstructions = <encoder.Instruction>[];

    for (final instruction in instructions) {
      final workingInstruction = encoder.Instruction(
        programId: solana.Ed25519HDPublicKey.fromBase58(
            instruction.programId.toBase58(),),
        accounts: instruction.accounts
            .map(_convertAccountMeta)
            .toList(),
        data: encoder.ByteArray(instruction.data),
      );
      workingInstructions.add(workingInstruction);
    }

    // Create message
    final message = solana.Message(
      instructions: workingInstructions,
    );

    // Compile the message
    final compiledMessage = message.compile(
      recentBlockhash: recentBlockhash,
      feePayer: signer.publicKey,
    );

    // Sign the transaction
    final signature = await signer.sign(compiledMessage.toByteArray());

    // Create signed transaction
    final signedTx = encoder.SignedTx(
      compiledMessage: compiledMessage,
      signatures: [signature],
    );

    // Return serialized bytes
    return Uint8List.fromList(signedTx.toByteArray().toList());
  }

  /// Convert dart-coral-xyz AccountMeta to espresso-cash AccountMeta
  static encoder.AccountMeta _convertAccountMeta(AccountMeta account) {
    final pubkey =
        solana.Ed25519HDPublicKey.fromBase58(account.publicKey.toBase58());

    if (account.isSigner && account.isWritable) {
      return encoder.AccountMeta.writeable(pubKey: pubkey, isSigner: true);
    } else if (account.isSigner && !account.isWritable) {
      return encoder.AccountMeta.readonly(pubKey: pubkey, isSigner: true);
    } else if (!account.isSigner && account.isWritable) {
      return encoder.AccountMeta.writeable(pubKey: pubkey, isSigner: false);
    } else {
      return encoder.AccountMeta.readonly(pubKey: pubkey, isSigner: false);
    }
  }

  /// Send transaction using espresso-cash solana client
  static Future<String> sendTransaction({
    required solana.SolanaClient client,
    required Uint8List serializedTransaction,
    solana.Commitment? commitment,
  }) async {
    // Convert to base64 for RPC
    final encodedTx =
        encoder.SignedTx.fromBytes(serializedTransaction).encode();
    return client.rpcClient.sendTransaction(
      encodedTx,
      preflightCommitment: commitment ?? solana.Commitment.confirmed,
    );
  }
}
