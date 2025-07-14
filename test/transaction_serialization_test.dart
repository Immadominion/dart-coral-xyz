import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('Transaction Serialization', () {
    late KeypairWallet wallet;
    late Transaction tx;
    late String blockhash;
    late PublicKey programId;

    setUp(() async {
      wallet = await KeypairWallet.generate();
      blockhash =
          'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5'; // Valid base58 blockhash
      programId = PublicKey.fromBase58('11111111111111111111111111111111');
      tx = Transaction(
        instructions: [
          TransactionInstruction(
            programId: programId,
            accounts: [
              AccountMeta(
                  pubkey: wallet.publicKey, isSigner: true, isWritable: true,),
            ],
            data: Uint8List.fromList([1, 2, 3]),
          ),
        ],
        recentBlockhash: blockhash,
        feePayer: wallet.publicKey,
      );
    });

    test('compileMessage produces consistent output', () {
      final message = tx.compileMessage();
      expect(message, isA<Uint8List>());
      expect(message.length, greaterThan(0));
    });

    test('serialize produces consistent output', () async {
      await wallet.signTransaction(tx);
      final serialized = tx.serialize();
      expect(serialized, isA<Uint8List>());
      expect(serialized.length, greaterThan(0));
    });

    test('throws if blockhash missing', () {
      final txNoBlockhash = Transaction(
        instructions: tx.instructions,
        feePayer: wallet.publicKey,
      );
      expect(txNoBlockhash.compileMessage, throwsA(isA<Exception>()));
      expect(txNoBlockhash.serialize, throwsA(isA<Exception>()));
    });
  });

  group('Transaction Partial Signatures', () {
    late KeypairWallet wallet1;
    late KeypairWallet wallet2;
    late Transaction tx;
    late String blockhash;
    late PublicKey programId;

    setUp(() async {
      wallet1 = await KeypairWallet.generate();
      wallet2 = await KeypairWallet.generate();
      blockhash =
          'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5'; // Valid base58 blockhash
      programId = PublicKey.fromBase58('11111111111111111111111111111113');
      tx = Transaction(
        instructions: [
          TransactionInstruction(
            programId: programId,
            accounts: [
              AccountMeta(
                  pubkey: wallet1.publicKey, isSigner: true, isWritable: true,),
              AccountMeta(
                  pubkey: wallet2.publicKey, isSigner: true, isWritable: false,),
            ],
            data: Uint8List.fromList([4, 5, 6]),
          ),
        ],
        recentBlockhash: blockhash,
        feePayer: wallet1.publicKey,
      );
    });

    test('allows multiple signers in any order', () async {
      await wallet2.signTransaction(tx);
      await wallet1.signTransaction(tx);
      expect(tx.signatures.length, equals(2));
      expect(tx.signatures.containsKey(wallet1.publicKey.toBase58()), isTrue);
      expect(tx.signatures.containsKey(wallet2.publicKey.toBase58()), isTrue);
    });

    test('signatures are matched to correct signers', () async {
      await wallet1.signTransaction(tx);
      await wallet2.signTransaction(tx);
      final sig1 = tx.signatures[wallet1.publicKey.toBase58()];
      final sig2 = tx.signatures[wallet2.publicKey.toBase58()];
      expect(sig1, isNotNull);
      expect(sig2, isNotNull);
      expect(sig1, isNot(equals(sig2)));
    });
  });
}
