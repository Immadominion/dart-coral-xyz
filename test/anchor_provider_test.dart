/// Tests for the AnchorProvider implementation
///
/// This test file ensures the AnchorProvider class works correctly for
/// combining connection and wallet functionality, transaction sending,
/// simulation, and error handling.

library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('ConfirmOptions', () {
    test('should create with default values', () {
      const options = ConfirmOptions();

      expect(options.commitment, equals(CommitmentConfigs.processed));
      expect(options.skipPreflight, isFalse);
      expect(options.preflightCommitment, isNull);
      expect(options.maxRetries, isNull);
      expect(options.minContextSlot, isNull);
    });

    test('should create with custom values', () {
      const options = ConfirmOptions(
        commitment: CommitmentConfigs.finalized,
        preflightCommitment: CommitmentConfigs.confirmed,
        skipPreflight: true,
        maxRetries: 5,
        minContextSlot: 100,
      );

      expect(options.commitment, equals(CommitmentConfigs.finalized));
      expect(options.preflightCommitment, equals(CommitmentConfigs.confirmed));
      expect(options.skipPreflight, isTrue);
      expect(options.maxRetries, equals(5));
      expect(options.minContextSlot, equals(100));
    });

    test('should support copyWith', () {
      const original = ConfirmOptions(
        commitment: CommitmentConfigs.processed,
        skipPreflight: false,
      );

      final modified = original.copyWith(
        commitment: CommitmentConfigs.finalized,
        maxRetries: 3,
      );

      expect(modified.commitment, equals(CommitmentConfigs.finalized));
      expect(modified.skipPreflight, isFalse); // unchanged
      expect(modified.maxRetries, equals(3));
    });

    test('should implement equality correctly', () {
      const options1 = ConfirmOptions(
        commitment: CommitmentConfigs.finalized,
        maxRetries: 3,
      );

      const options2 = ConfirmOptions(
        commitment: CommitmentConfigs.finalized,
        maxRetries: 3,
      );

      const options3 = ConfirmOptions(
        commitment: CommitmentConfigs.processed,
        maxRetries: 3,
      );

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('should have proper toString representation', () {
      const options = ConfirmOptions(
        commitment: CommitmentConfigs.finalized,
        skipPreflight: true,
      );

      final str = options.toString();
      expect(str, contains('ConfirmOptions'));
      expect(str, contains('finalized'));
      expect(str, contains('skipPreflight: true'));
    });
  });

  group('TransactionWithSigners', () {
    test('should create with transaction only', () {
      final tx = Transaction(instructions: []);
      final txWithSigners = TransactionWithSigners(transaction: tx);

      expect(txWithSigners.transaction, equals(tx));
      expect(txWithSigners.signers, isNull);
    });

    test('should create with transaction and signers', () async {
      final tx = Transaction(instructions: []);
      final keypair = await Keypair.generate();
      final txWithSigners = TransactionWithSigners(
        transaction: tx,
        signers: [keypair],
      );

      expect(txWithSigners.transaction, equals(tx));
      expect(txWithSigners.signers, hasLength(1));
      expect(txWithSigners.signers!.first, equals(keypair));
    });

    test('should have proper toString representation', () {
      final tx = Transaction(instructions: []);
      final txWithSigners = TransactionWithSigners(transaction: tx);

      final str = txWithSigners.toString();
      expect(str, contains('TransactionWithSigners'));
      expect(str, contains('signers: 0'));
    });
  });

  group('SimulationResult', () {
    test('should create successful result', () {
      const result = SimulationResult(
        success: true,
        logs: ['log1', 'log2'],
        unitsConsumed: 1000,
      );

      expect(result.success, isTrue);
      expect(result.logs, hasLength(2));
      expect(result.error, isNull);
      expect(result.unitsConsumed, equals(1000));
    });

    test('should create failed result', () {
      const result = SimulationResult(
        success: false,
        logs: [],
        error: 'Transaction failed',
      );

      expect(result.success, isFalse);
      expect(result.logs, isEmpty);
      expect(result.error, equals('Transaction failed'));
    });

    test('should have proper toString representation', () {
      const result = SimulationResult(
        success: true,
        logs: ['log1', 'log2'],
        error: null,
        unitsConsumed: 1000,
      );

      final str = result.toString();
      expect(str, contains('SimulationResult'));
      expect(str, contains('success: true'));
      expect(str, contains('logs: 2'));
      expect(str, contains('unitsConsumed: 1000'));
    });
  });

  group('AnchorProvider', () {
    late Connection connection;
    late Wallet wallet;
    late AnchorProvider provider;

    setUp(() async {
      connection = Connection('http://localhost:8899');
      wallet = await KeypairWallet.generate();
      provider = AnchorProvider(connection, wallet);
    });

    test('should create provider with connection and wallet', () {
      expect(provider.connection, equals(connection));
      expect(provider.wallet, equals(wallet));
      expect(provider.publicKey, equals(wallet.publicKey));
      expect(provider.options, equals(ConfirmOptions.defaultOptions));
    });

    test('should create provider with custom options', () {
      const customOptions = ConfirmOptions(
        commitment: CommitmentConfigs.finalized,
        skipPreflight: true,
      );

      final customProvider = AnchorProvider(
        connection,
        wallet,
        options: customOptions,
      );

      expect(customProvider.options, equals(customOptions));
    });

    test('should create local provider', () async {
      final localProvider = await AnchorProvider.local();

      expect(localProvider.connection, isA<Connection>());
      expect(localProvider.wallet, isNull); // No wallet path provided
    });

    test('should create env provider', () async {
      final envProvider = await AnchorProvider.env();

      expect(envProvider.connection, isA<Connection>());
    });

    test('should create provider with wallet factory', () {
      final walletProvider = AnchorProvider.withWallet(connection, wallet);

      expect(walletProvider.connection, equals(connection));
      expect(walletProvider.wallet, equals(wallet));
      expect(walletProvider.publicKey, equals(wallet.publicKey));
    });

    test('should create read-only provider', () {
      final readOnlyProvider = AnchorProvider.readOnly(connection);

      expect(readOnlyProvider.connection, equals(connection));
      expect(readOnlyProvider.wallet, isNull);
      expect(readOnlyProvider.publicKey, isNull);
    });

    test('should implement equality correctly', () {
      final provider1 = AnchorProvider(connection, wallet);
      final provider2 = AnchorProvider(connection, wallet);

      expect(provider1, equals(provider2));
      expect(provider1.hashCode, equals(provider2.hashCode));
    });

    test('should have proper toString representation', () {
      final str = provider.toString();

      expect(str, contains('AnchorProvider'));
      expect(str, contains('connection:'));
      expect(str, contains('wallet: present'));
      expect(str, contains('publicKey:'));
    });

    test('should have proper toString for read-only provider', () {
      final readOnlyProvider = AnchorProvider.readOnly(connection);
      final str = readOnlyProvider.toString();

      expect(str, contains('wallet: null'));
    });
  });

  group('AnchorProvider Transaction Operations', () {
    late AnchorProvider provider;
    late AnchorProvider readOnlyProvider;
    late Transaction transaction;

    setUp(() async {
      final connection = Connection('http://localhost:8899');
      final wallet = await KeypairWallet.generate();
      provider = AnchorProvider(connection, wallet);
      readOnlyProvider = AnchorProvider.readOnly(connection);

      transaction = Transaction(
        instructions: [
          TransactionInstruction(
            programId: PublicKey.systemProgram,
            accounts: [],
            data: Uint8List.fromList([1, 2, 3]),
          ),
        ],
        recentBlockhash: 'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5',
      );
    });

    test('should throw when sending transaction without wallet', () async {
      expect(
        () => readOnlyProvider.sendAndConfirm(transaction),
        throwsA(isA<ProviderException>()),
      );
    });

    test('should send and confirm transaction (mock)', () async {
      final signature = await provider.sendAndConfirm(transaction);

      expect(signature, isA<String>());
      expect(signature, startsWith('mock_signature_'));
    });

    test('should send and confirm transaction with options', () async {
      const options = ConfirmOptions(
        commitment: CommitmentConfigs.finalized,
        skipPreflight: true,
      );

      final signature = await provider.sendAndConfirm(
        transaction,
        options: options,
      );

      expect(signature, isA<String>());
    });

    test('should send and confirm transaction with signers', () async {
      final keypair = await Keypair.generate();

      final signature = await provider.sendAndConfirm(
        transaction,
        signers: [keypair],
      );

      expect(signature, isA<String>());
    });

    test('should throw when sending multiple transactions without wallet',
        () async {
      final transactions = [
        TransactionWithSigners(transaction: transaction),
      ];

      expect(
        () => readOnlyProvider.sendAll(transactions),
        throwsA(isA<ProviderException>()),
      );
    });

    test('should send multiple transactions (mock)', () async {
      final transactions = [
        TransactionWithSigners(transaction: transaction),
        TransactionWithSigners(transaction: transaction),
      ];

      final signatures = await provider.sendAll(transactions);

      expect(signatures, hasLength(2));
      expect(signatures.first, startsWith('mock_batch_signature_0_'));
      expect(signatures.last, startsWith('mock_batch_signature_1_'));
    });

    test('should send multiple transactions with signers', () async {
      final keypair = await Keypair.generate();
      final transactions = [
        TransactionWithSigners(
          transaction: transaction,
          signers: [keypair],
        ),
      ];

      final signatures = await provider.sendAll(transactions);

      expect(signatures, hasLength(1));
    });

    test('should simulate transaction', () async {
      final result = await provider.simulate(transaction);

      expect(result.success, isTrue);
      expect(result.logs, isNotEmpty);
      expect(result.error, isNull);
    });

    test('should simulate transaction with signers', () async {
      final keypair = await Keypair.generate();

      final result = await provider.simulate(
        transaction,
        signers: [keypair],
      );

      expect(result.success, isTrue);
    });

    test('should simulate transaction with commitment', () async {
      final result = await provider.simulate(
        transaction,
        commitment: CommitmentConfigs.finalized,
      );

      expect(result.success, isTrue);
    });

    test('should simulate read-only transaction', () async {
      final result = await readOnlyProvider.simulate(transaction);

      expect(result.success, isTrue);
    });
  });

  group('Provider Exceptions', () {
    test('should create ProviderException with message', () {
      const exception = ProviderException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(exception.toString(), equals('ProviderException: Test error'));
    });

    test('should create ProviderException with cause', () {
      final cause = Exception('Original error');
      final exception = ProviderException('Test error', cause);

      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('Caused by:'));
    });

    test('should create ProviderTransactionException with signature and logs',
        () {
      const exception = ProviderTransactionException(
        'Transaction failed',
        null,
        'signature123',
        ['log1', 'log2'],
      );

      expect(exception.message, equals('Transaction failed'));
      expect(exception.signature, equals('signature123'));
      expect(exception.logs, hasLength(2));

      final str = exception.toString();
      expect(str, contains('ProviderTransactionException'));
      expect(str, contains('Transaction failed'));
      expect(str, contains('Transaction signature: signature123'));
      expect(str, contains('Program logs:'));
      expect(str, contains('log1'));
      expect(str, contains('log2'));
    });

    test('should create ProviderTransactionException without optional fields',
        () {
      const exception = ProviderTransactionException('Simple error');

      expect(exception.message, equals('Simple error'));
      expect(exception.signature, isNull);
      expect(exception.logs, isNull);

      final str = exception.toString();
      expect(str, equals('ProviderTransactionException: Simple error'));
    });
  });
}
