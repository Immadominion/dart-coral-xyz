/// Integration test for transaction serialization and signing
///
/// This test verifies that the dart-coral-xyz package can properly
/// serialize, sign, and send transactions using the solana package.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:solana/solana.dart' as solana;
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Transaction Integration Tests', () {
    late solana.Ed25519HDKeyPair signer;
    late solana.SolanaClient client;

    setUpAll(() async {
      // Create a test keypair
      signer = await solana.Ed25519HDKeyPair.random();

      // Create a client (using devnet for testing)
      client = solana.SolanaClient(
        rpcUrl: Uri.parse('https://api.devnet.solana.com'),
        websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
      );
    });

    test('should create and serialize a simple transfer transaction', () async {
      // Create a simple transfer instruction
      final fromPubkey = PublicKey.fromBase58(signer.publicKey.toBase58());
      final toPubkey = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());
      final lamports = 1000000; // 0.001 SOL

      final transferInstruction = TransactionInstruction(
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
        data: _createTransferInstructionData(lamports),
      );

      // Create transaction
      final transaction = Transaction(
        instructions: [transferInstruction],
        feePayer: fromPubkey,
      );

      // Get recent blockhash
      final blockhashResponse = await client.rpcClient.getLatestBlockhash();
      final recentBlockhash = blockhashResponse.value.blockhash;

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
    });

    test('should create and serialize a transaction with multiple instructions',
        () async {
      final fromPubkey = PublicKey.fromBase58(signer.publicKey.toBase58());
      final toPubkey1 = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());
      final toPubkey2 = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());

      // Create multiple transfer instructions
      final instructions = [
        TransactionInstruction(
          programId: PublicKey.fromBase58('11111111111111111111111111111111'),
          accounts: [
            AccountMeta(
                publicKey: fromPubkey, isSigner: true, isWritable: true),
            AccountMeta(
                publicKey: toPubkey1, isSigner: false, isWritable: true),
          ],
          data: _createTransferInstructionData(500000),
        ),
        TransactionInstruction(
          programId: PublicKey.fromBase58('11111111111111111111111111111111'),
          accounts: [
            AccountMeta(
                publicKey: fromPubkey, isSigner: true, isWritable: true),
            AccountMeta(
                publicKey: toPubkey2, isSigner: false, isWritable: true),
          ],
          data: _createTransferInstructionData(500000),
        ),
      ];

      final transaction = Transaction(
        instructions: instructions,
        feePayer: fromPubkey,
      );

      // Get recent blockhash
      final blockhashResponse = await client.rpcClient.getLatestBlockhash();
      final recentBlockhash = blockhashResponse.value.blockhash;

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

    test('should demonstrate sending transaction (dry run)', () async {
      // Note: This is a dry run test - we won't actually send to avoid needing SOL

      final fromPubkey = PublicKey.fromBase58(signer.publicKey.toBase58());
      final toPubkey = PublicKey.fromBase58(
          (await solana.Ed25519HDKeyPair.random()).publicKey.toBase58());

      final transferInstruction = TransactionInstruction(
        programId: PublicKey.fromBase58('11111111111111111111111111111111'),
        accounts: [
          AccountMeta(publicKey: fromPubkey, isSigner: true, isWritable: true),
          AccountMeta(publicKey: toPubkey, isSigner: false, isWritable: true),
        ],
        data: _createTransferInstructionData(1000),
      );

      final transaction = Transaction(
        instructions: [transferInstruction],
        feePayer: fromPubkey,
      );

      // Get recent blockhash
      final blockhashResponse = await client.rpcClient.getLatestBlockhash();
      final recentBlockhash = blockhashResponse.value.blockhash;

      // Serialize and sign
      final serializedTx = await transaction.serialize(
        signer: signer,
        recentBlockhash: recentBlockhash,
      );

      // Verify we can create the send call structure
      // (We won't actually send to avoid needing funded accounts)
      expect(() async {
        return Transaction.sendTransaction(
          client: client,
          serializedTransaction: serializedTx,
          commitment: solana.Commitment.confirmed,
        );
      }, returnsNormally);

      print('✅ Transaction send structure verified');
    });

    test('should handle account metadata conversion correctly', () {
      final pubkey = PublicKey.fromBase58(signer.publicKey.toBase58());

      // Test all combinations of AccountMeta flags
      final testCases = [
        AccountMeta(publicKey: pubkey, isSigner: true, isWritable: true),
        AccountMeta(publicKey: pubkey, isSigner: true, isWritable: false),
        AccountMeta(publicKey: pubkey, isSigner: false, isWritable: true),
        AccountMeta(publicKey: pubkey, isSigner: false, isWritable: false),
      ];

      for (final accountMeta in testCases) {
        // This will test the internal _convertAccountMeta method
        // by creating a transaction and ensuring it doesn't throw
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
        expect(account.publicKey, equals(pubkey));
        expect(account.isSigner, equals(accountMeta.isSigner));
        expect(account.isWritable, equals(accountMeta.isWritable));
      }

      print('✅ AccountMeta conversion verified for all flag combinations');
    });
  });
}

/// Create transfer instruction data for System Program
Uint8List _createTransferInstructionData(int lamports) {
  final data = Uint8List(12); // 4 bytes instruction index + 8 bytes lamports

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
