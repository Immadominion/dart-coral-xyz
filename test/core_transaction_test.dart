/// Simple transaction serialization test
///
/// This test verifies the core transaction functionality without dependencies
/// on other parts of the coral_xyz_anchor package.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:solana/solana.dart' as solana;
import '../lib/src/transaction/transaction.dart';
import '../lib/src/types/public_key.dart';

void main() {
  group('Core Transaction Tests', () {
    late solana.Ed25519HDKeyPair signer;

    setUpAll(() async {
      // Create a test keypair
      signer = await solana.Ed25519HDKeyPair.random();
    });

    test('should create and serialize a basic transaction', () async {
      // Create a simple instruction
      final fromPubkey = PublicKey.fromBase58(signer.publicKey.toBase58());
      final toPubkey = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());

      final instruction = TransactionInstruction(
        programId: PublicKey.fromBase58(
            '11111111111111111111111111111111'), // System Program
        accounts: [
          AccountMeta(
            publicKey: fromPubkey,
            isSigner: true,
            isWritable: true,
          ),
          AccountMeta(
            publicKey: toPubkey,
            isSigner: false,
            isWritable: true,
          ),
        ],
        data: _createTransferData(1000000), // 0.001 SOL
      );

      // Create transaction
      final transaction = Transaction(
        instructions: [instruction],
        feePayer: fromPubkey,
      );

      // Mock recent blockhash (would normally come from RPC)
      final recentBlockhash = 'EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N';

      // Serialize and sign the transaction
      final serializedTx = await transaction.serialize(
        signer: signer,
        recentBlockhash: recentBlockhash,
      );

      // Verify serialization produced bytes
      expect(serializedTx, isA<Uint8List>());
      expect(serializedTx.length, greaterThan(0));

      print(
          '✅ Transaction serialized successfully: ${serializedTx.length} bytes');
      print(
          '   First 32 bytes: ${serializedTx.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    });

    test('should create transaction with multiple instructions', () async {
      final fromPubkey = PublicKey.fromBase58(signer.publicKey.toBase58());
      final toPubkey1 = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());
      final toPubkey2 = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());

      // Create multiple instructions
      final instructions = [
        TransactionInstruction(
          programId: PublicKey.fromBase58('11111111111111111111111111111111'),
          accounts: [
            AccountMeta(
                publicKey: fromPubkey, isSigner: true, isWritable: true),
            AccountMeta(
                publicKey: toPubkey1, isSigner: false, isWritable: true),
          ],
          data: _createTransferData(500000),
        ),
        TransactionInstruction(
          programId: PublicKey.fromBase58('11111111111111111111111111111111'),
          accounts: [
            AccountMeta(
                publicKey: fromPubkey, isSigner: true, isWritable: true),
            AccountMeta(
                publicKey: toPubkey2, isSigner: false, isWritable: true),
          ],
          data: _createTransferData(500000),
        ),
      ];

      final transaction = Transaction(
        instructions: instructions,
        feePayer: fromPubkey,
      );

      final recentBlockhash = 'EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N';

      // Serialize and sign
      final serializedTx = await transaction.serialize(
        signer: signer,
        recentBlockhash: recentBlockhash,
      );

      expect(serializedTx, isA<Uint8List>());
      expect(serializedTx.length, greaterThan(0));

      print(
          '✅ Multi-instruction transaction serialized: ${serializedTx.length} bytes');
    });

    test('should handle different account metadata types', () {
      final pubkey = PublicKey.fromBase58(signer.publicKey.toBase58());

      // Test all combinations of AccountMeta flags
      final testCases = [
        AccountMeta(
            publicKey: pubkey,
            isSigner: true,
            isWritable: true), // Writable signer
        AccountMeta(
            publicKey: pubkey,
            isSigner: true,
            isWritable: false), // Readonly signer
        AccountMeta(
            publicKey: pubkey,
            isSigner: false,
            isWritable: true), // Writable non-signer
        AccountMeta(
            publicKey: pubkey,
            isSigner: false,
            isWritable: false), // Readonly non-signer
      ];

      for (final accountMeta in testCases) {
        final instruction = TransactionInstruction(
          programId: PublicKey.fromBase58('11111111111111111111111111111111'),
          accounts: [accountMeta],
          data: Uint8List.fromList([0, 1, 2, 3]),
        );

        final transaction = Transaction(
          instructions: [instruction],
          feePayer: pubkey,
        );

        expect(transaction.instructions.length, equals(1));
        expect(transaction.instructions[0].accounts.length, equals(1));

        final account = transaction.instructions[0].accounts[0];
        expect(account.publicKey.toBase58(), equals(pubkey.toBase58()));
        expect(account.isSigner, equals(accountMeta.isSigner));
        expect(account.isWritable, equals(accountMeta.isWritable));
      }

      print('✅ AccountMeta conversion verified for all combinations');
    });

    test('should create proper toString representations', () {
      final pubkey = PublicKey.fromBase58(signer.publicKey.toBase58());

      final accountMeta = AccountMeta(
        publicKey: pubkey,
        isSigner: true,
        isWritable: false,
      );

      final instruction = TransactionInstruction(
        programId: PublicKey.fromBase58('11111111111111111111111111111111'),
        accounts: [accountMeta],
        data: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      final transaction = Transaction(
        instructions: [instruction],
        feePayer: pubkey,
      );

      // Verify transaction was created
      expect(transaction.instructions.length, equals(1));

      // Test toString methods
      expect(accountMeta.toString(), contains('AccountMeta'));
      expect(accountMeta.toString(), contains(pubkey.toBase58()));
      expect(accountMeta.toString(), contains('signer: true'));
      expect(accountMeta.toString(), contains('writable: false'));

      expect(instruction.toString(), contains('TransactionInstruction'));
      expect(instruction.toString(), contains('accounts: 1'));
      expect(instruction.toString(), contains('data: 5 bytes'));

      print('✅ ToString methods work correctly');
    });
  });
}

/// Create transfer instruction data for System Program
Uint8List _createTransferData(int lamports) {
  final data = Uint8List(12); // 4 bytes instruction + 8 bytes lamports

  // System Program transfer instruction index is 2
  data[0] = 2;
  data[1] = 0;
  data[2] = 0;
  data[3] = 0;

  // Lamports as little-endian u64
  for (int i = 0; i < 8; i++) {
    data[4 + i] = (lamports >> (i * 8)) & 0xFF;
  }

  return data;
}
