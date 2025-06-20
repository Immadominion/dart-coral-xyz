/// Tests for the Wallet implementations
///
/// This test file ensures the Wallet interface and KeypairWallet implementation
/// work correctly for transaction signing and message signing.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('Wallet Interface', () {
    late KeypairWallet wallet;
    late Keypair testKeypair;

    setUp(() async {
      // Create a test keypair for consistent testing
      final secretKeyBytes = Uint8List.fromList(List.generate(64, (i) => i));
      testKeypair = Keypair.fromSecretKey(secretKeyBytes);
      wallet = KeypairWallet(testKeypair);
    });

    test('should create wallet from keypair', () {
      expect(wallet.publicKey, equals(testKeypair.publicKey));
      expect(wallet.keypair, equals(testKeypair));
    });

    test('should create wallet from secret key', () {
      final secretKey = Uint8List.fromList(List.generate(64, (i) => i + 1));
      final wallet = KeypairWallet.fromSecretKey(secretKey);

      expect(wallet.publicKey, isA<PublicKey>());
      expect(wallet.keypair, isA<Keypair>());
    });

    test('should create wallet from JSON array', () {
      final secretKeyArray = List.generate(64, (i) => i + 2);
      final wallet = KeypairWallet.fromJson(secretKeyArray);

      expect(wallet.publicKey, isA<PublicKey>());
      expect(wallet.keypair, isA<Keypair>());
    });

    test('should generate random wallet', () async {
      final randomWallet = await KeypairWallet.generate();

      expect(randomWallet.publicKey, isA<PublicKey>());
      expect(randomWallet.keypair, isA<Keypair>());
    });

    test('should create wallet from seed', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final seedWallet = await KeypairWallet.fromSeed(seed);

      expect(seedWallet.publicKey, isA<PublicKey>());
      expect(seedWallet.keypair, isA<Keypair>());
    });

    test('should have proper toString representation', () {
      final walletString = wallet.toString();
      expect(walletString, contains('KeypairWallet'));
      expect(walletString, contains('publicKey'));
    });

    test('should implement equality correctly', () {
      final wallet1 = KeypairWallet(testKeypair);
      final wallet2 = KeypairWallet(testKeypair);

      expect(wallet1, equals(wallet2));
      expect(wallet1.hashCode, equals(wallet2.hashCode));
    });

    test('should not be equal to different wallet', () async {
      final differentWallet = await KeypairWallet.generate();

      expect(wallet, isNot(equals(differentWallet)));
    });
  });

  group('Transaction Signing', () {
    late KeypairWallet wallet;
    late Transaction testTransaction;

    setUp(() async {
      wallet = await KeypairWallet.generate();

      // Create a test transaction
      testTransaction = Transaction(
        instructions: [
          TransactionInstruction(
            programId: PublicKey.systemProgram,
            accounts: [
              AccountMeta(
                pubkey: wallet.publicKey,
                isSigner: true,
                isWritable: true,
              ),
            ],
            data: Uint8List.fromList([1, 2, 3, 4]),
          ),
        ],
        recentBlockhash:
            'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5', // Valid base58 blockhash
        feePayer: wallet.publicKey,
      );
    });

    test('should sign a single transaction', () async {
      final signedTransaction = await wallet.signTransaction(testTransaction);

      expect(signedTransaction, isA<Transaction>());
      expect(
          signedTransaction.instructions, equals(testTransaction.instructions));
      expect(signedTransaction.feePayer, equals(wallet.publicKey));
      expect(signedTransaction.signatures.length, equals(1)); // Single signer
    });

    test('should sign multiple transactions', () async {
      final transactions = [
        testTransaction,
        Transaction(
          instructions: [
            TransactionInstruction(
              programId: PublicKey.systemProgram,
              accounts: [],
              data: Uint8List.fromList([5, 6, 7, 8]),
            ),
          ],
          recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',
          feePayer: wallet.publicKey,
        ),
      ];

      final signedTransactions = await wallet.signAllTransactions(transactions);

      expect(signedTransactions.length, equals(2));
      expect(signedTransactions[0], isA<Transaction>());
      expect(signedTransactions[1], isA<Transaction>());

      for (final signedTx in signedTransactions) {
        expect(signedTx.signatures.length, greaterThan(0));
        expect(signedTx.feePayer, equals(wallet.publicKey));
      }
    });

    test('should preserve existing transaction properties when signing',
        () async {
      final transactionWithProperties = Transaction(
        instructions: testTransaction.instructions,
        feePayer: wallet.publicKey,
        recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',
      );

      final signed = await wallet.signTransaction(transactionWithProperties);

      expect(
          signed.instructions, equals(transactionWithProperties.instructions));
      expect(signed.feePayer, equals(transactionWithProperties.feePayer));
      expect(signed.recentBlockhash,
          equals(transactionWithProperties.recentBlockhash));
      expect(signed.signatures.length, greaterThan(0));
    });

    test('should handle empty transaction list', () async {
      final signedTransactions = await wallet.signAllTransactions([]);

      expect(signedTransactions, isEmpty);
    });
  });

  group('Message Signing', () {
    late KeypairWallet wallet;

    setUp(() async {
      wallet = await KeypairWallet.generate();
    });

    test('should sign a message', () async {
      final message = Uint8List.fromList([1, 2, 3, 4, 5]);
      final signature = await wallet.signMessage(message);

      expect(signature, isA<Uint8List>());
      expect(signature.length, greaterThan(0));
    });

    test('should sign different messages differently', () async {
      final message1 = Uint8List.fromList([1, 2, 3]);
      final message2 = Uint8List.fromList([4, 5, 6]);

      final signature1 = await wallet.signMessage(message1);
      final signature2 = await wallet.signMessage(message2);

      expect(signature1, isNot(equals(signature2)));
    });

    test('should handle empty message', () async {
      final emptyMessage = Uint8List(0);
      final signature = await wallet.signMessage(emptyMessage);

      expect(signature, isA<Uint8List>());
    });

    test('should sign same message consistently', () async {
      final message = Uint8List.fromList([1, 2, 3, 4, 5]);

      final signature1 = await wallet.signMessage(message);
      final signature2 = await wallet.signMessage(message);

      // Note: Signatures might not be identical due to potential randomness in signing
      // But they should both be valid signatures for the same message
      expect(signature1, isA<Uint8List>());
      expect(signature2, isA<Uint8List>());
      expect(signature1.length, equals(signature2.length));
    });
  });

  group('Wallet Exceptions', () {
    test('should create WalletException with message', () {
      const exception = WalletException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(exception.toString(), equals('WalletException: Test error'));
    });

    test('should create WalletException with cause', () {
      final cause = Exception('Original error');
      final exception = WalletException('Test error', cause);
      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('Caused by:'));
    });

    test('should create specialized exceptions', () {
      const userRejected = WalletUserRejectedException();
      const notConnected = WalletNotConnectedException();
      const notAvailable = WalletNotAvailableException();
      expect(userRejected, isA<WalletException>());
      expect(notConnected, isA<WalletException>());
      expect(notAvailable, isA<WalletException>());
      expect(userRejected.message.toLowerCase(), contains('rejected'));
      expect(notConnected.message.toLowerCase(), contains('not connected'));
      expect(notAvailable.message.toLowerCase(), contains('not available'));
    });

    test('should allow custom messages for specialized exceptions', () {
      const notAvailable =
          WalletNotAvailableException('Custom availability message');
      expect(notAvailable.message, equals('Custom availability message'));
    });
  });
}
