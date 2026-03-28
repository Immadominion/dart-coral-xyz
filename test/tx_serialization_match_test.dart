/// Verification test: proves our Transaction._serializeMessage() produces
/// byte-identical output to espresso-cash's Message.compile() → CompiledMessage.toByteArray().
///
/// This test uses the same inputs (accounts, programId, blockhash) and compares
/// the wire-format bytes from both serialization paths.
library;

import 'dart:typed_data';
import 'package:coral_xyz/src/types/transaction.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:solana/encoder.dart' as solana;
import 'package:solana/solana.dart' as solana;
import 'package:test/test.dart';

void main() {
  group('Transaction serialization matches espresso-cash', () {
    // Deterministic keys for testing
    final walletPubkey = PublicKey.fromBase58(
      '9aE476sH92Vz7DMPyq5WLPkrKWivxeuTKEFKd2sZZcde',
    );
    final counterPda = PublicKey.fromBase58(
      'GHC5KJPwrgcXqSDdsXE1tuxcv7oNaqdNm3JDQnbnsw9A',
    );
    final systemProgram = PublicKey.fromBase58(
      '11111111111111111111111111111111',
    );
    final programId = PublicKey.fromBase58(
      'FTeQEfu9uunWyM9EkETP2eJFaeSYY98UE8Y99Ma9zko8',
    );
    const blockhash = 'EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N';

    test('initialize instruction produces identical message bytes', () {
      // ===== Path 1: Our Transaction._serializeMessage() =====
      final ourTx = Transaction(
        instructions: [
          TransactionInstruction(
            programId: programId,
            accounts: [
              AccountMeta(
                pubkey: counterPda,
                isSigner: false,
                isWritable: true,
              ),
              AccountMeta(
                pubkey: walletPubkey,
                isSigner: true,
                isWritable: true,
              ),
              AccountMeta(
                pubkey: systemProgram,
                isSigner: false,
                isWritable: false,
              ),
            ],
            data: Uint8List.fromList([
              175,
              175,
              109,
              31,
              13,
              152,
              155,
              237,
            ]), // "initialize" disc
          ),
        ],
        feePayer: walletPubkey,
        recentBlockhash: blockhash,
      );
      final ourMessageBytes = ourTx.compileMessage();

      // ===== Path 2: espresso-cash Message.compile() =====
      final espressoMessage = solana.Message(
        instructions: [
          solana.Instruction(
            programId: programId,
            accounts: [
              solana.AccountMeta.writeable(pubKey: counterPda, isSigner: false),
              solana.AccountMeta.writeable(
                pubKey: walletPubkey,
                isSigner: true,
              ),
              solana.AccountMeta.readonly(
                pubKey: systemProgram,
                isSigner: false,
              ),
            ],
            data: solana.ByteArray([175, 175, 109, 31, 13, 152, 155, 237]),
          ),
        ],
      );
      final compiled = espressoMessage.compile(
        recentBlockhash: blockhash,
        feePayer: walletPubkey,
      );
      final espressoMessageBytes = compiled.toByteArray().toList();

      // ===== Compare =====
      expect(
        ourMessageBytes.length,
        equals(espressoMessageBytes.length),
        reason: 'Message byte lengths differ',
      );
      expect(
        ourMessageBytes.toList(),
        equals(espressoMessageBytes),
        reason: 'Message bytes differ',
      );
    });

    test('increment instruction produces identical message bytes', () {
      // For increment: only counter account, u64 amount arg
      final amountBytes = Uint8List(8);
      amountBytes.buffer.asByteData().setUint64(0, 1, Endian.little);

      // Discriminator for "increment": SHA256("global:increment")[0..7]
      final discBytes = [11, 18, 104, 9, 104, 174, 59, 33]; // pre-computed

      final data = Uint8List.fromList([...discBytes, ...amountBytes]);

      // ===== Path 1: Our Transaction =====
      final ourTx = Transaction(
        instructions: [
          TransactionInstruction(
            programId: programId,
            accounts: [
              AccountMeta(
                pubkey: counterPda,
                isSigner: false,
                isWritable: true,
              ),
            ],
            data: data,
          ),
        ],
        feePayer: walletPubkey,
        recentBlockhash: blockhash,
      );
      final ourMessageBytes = ourTx.compileMessage();

      // ===== Path 2: espresso-cash =====
      final espressoMessage = solana.Message(
        instructions: [
          solana.Instruction(
            programId: programId,
            accounts: [
              solana.AccountMeta.writeable(pubKey: counterPda, isSigner: false),
            ],
            data: solana.ByteArray(data.toList()),
          ),
        ],
      );
      final compiled = espressoMessage.compile(
        recentBlockhash: blockhash,
        feePayer: walletPubkey,
      );
      final espressoMessageBytes = compiled.toByteArray().toList();

      // ===== Compare =====
      expect(
        ourMessageBytes.length,
        equals(espressoMessageBytes.length),
        reason: 'Message byte lengths differ',
      );
      expect(
        ourMessageBytes.toList(),
        equals(espressoMessageBytes),
        reason: 'Message bytes differ',
      );
    });

    test('full wire format matches for unsigned transaction', () {
      // Build the same initialize tx as before
      final ourTx = Transaction(
        instructions: [
          TransactionInstruction(
            programId: programId,
            accounts: [
              AccountMeta(
                pubkey: counterPda,
                isSigner: false,
                isWritable: true,
              ),
              AccountMeta(
                pubkey: walletPubkey,
                isSigner: true,
                isWritable: true,
              ),
              AccountMeta(
                pubkey: systemProgram,
                isSigner: false,
                isWritable: false,
              ),
            ],
            data: Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237]),
          ),
        ],
        feePayer: walletPubkey,
        recentBlockhash: blockhash,
      );
      final ourMessageBytes = ourTx.compileMessage();

      // Build unsigned wire format the same way _MwaWallet does it
      final int numSigs = ourMessageBytes[0];
      final sigOffset = 1 + 64 * numSigs;
      final ourUnsigned = Uint8List(sigOffset + ourMessageBytes.length);
      ourUnsigned[0] = numSigs;
      ourUnsigned.setRange(sigOffset, ourUnsigned.length, ourMessageBytes);

      // Build espresso-cash SignedTx wire format
      final espressoMessage = solana.Message(
        instructions: [
          solana.Instruction(
            programId: programId,
            accounts: [
              solana.AccountMeta.writeable(pubKey: counterPda, isSigner: false),
              solana.AccountMeta.writeable(
                pubKey: walletPubkey,
                isSigner: true,
              ),
              solana.AccountMeta.readonly(
                pubKey: systemProgram,
                isSigner: false,
              ),
            ],
            data: solana.ByteArray([175, 175, 109, 31, 13, 152, 155, 237]),
          ),
        ],
      );
      final compiled = espressoMessage.compile(
        recentBlockhash: blockhash,
        feePayer: walletPubkey,
      );
      final signedTx = solana.SignedTx(
        compiledMessage: compiled,
        signatures: [
          solana.Signature(List.filled(64, 0), publicKey: walletPubkey),
        ],
      );
      final espressoUnsigned = signedTx.toByteArray().toList();

      // ===== Compare full wire format =====
      expect(
        ourUnsigned.length,
        equals(espressoUnsigned.length),
        reason: 'Unsigned wire format lengths differ',
      );
      expect(
        ourUnsigned.toList(),
        equals(espressoUnsigned),
        reason: 'Unsigned wire format bytes differ',
      );
    });
  });
}
