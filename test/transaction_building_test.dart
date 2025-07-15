/// Tests for Transaction Building
///
/// This test suite validates the basic transaction building functionality.

import 'package:test/test.dart';
import 'dart:typed_data';

import 'package:coral_xyz_anchor/src/program/transaction_builder.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/program/namespace/types.dart';

void main() {
  group('Transaction Building', () {
    late AnchorProvider mockProvider;
    late Connection mockConnection;

    setUp(() async {
      // Create mock connection
      mockConnection = Connection('http://localhost:8899');

      // Create mock provider
      final keypair = await Keypair.generate();
      final wallet = KeypairWallet(keypair);
      mockProvider = AnchorProvider(mockConnection, wallet);
    });

    group('TransactionBuilder', () {
      test('creates builder with constructor', () {
        final builder = TransactionBuilder(provider: mockProvider);
        expect(builder, isNotNull);
      });

      test('adds instruction successfully', () {
        final builder = TransactionBuilder(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final instruction = TransactionInstruction(
          programId: programId,
          accounts: const <AccountMeta>[],
          data: Uint8List.fromList([1, 2, 3]),
        );

        final result = builder.add(instruction);

        expect(result, equals(builder));
        expect(result, isA<TransactionBuilder>());
      });

      test('adds multiple instructions', () {
        final builder = TransactionBuilder(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final instructions = List.generate(
          3,
          (i) => TransactionInstruction(
            programId: programId,
            accounts: const <AccountMeta>[],
            data: Uint8List.fromList([i]),
          ),
        );

        final result = builder.addAll(instructions);

        expect(result, equals(builder));
        expect(result, isA<TransactionBuilder>());
      });

      test('adds signer successfully', () {
        final builder = TransactionBuilder(provider: mockProvider);
        final testKey =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final result = builder.addSigner(testKey);

        expect(result, equals(builder));
      });

      test('sets simulation flag', () {
        final builder = TransactionBuilder(provider: mockProvider);

        final result = builder.simulation(true);

        expect(result, equals(builder));
      });

      test('calculates fee', () async {
        final builder = TransactionBuilder(provider: mockProvider);
        final testKey =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addSigner(testKey);
        final fee = await builder.calculateFee();

        expect(fee, greaterThan(0));
        expect(fee, isA<int>());
      });

      test('builds transaction with instructions', () async {
        final builder = TransactionBuilder(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final instruction = TransactionInstruction(
          programId: programId,
          accounts: const <AccountMeta>[],
          data: Uint8List.fromList([1, 2, 3]),
        );

        builder.add(instruction);
        final transaction = await builder.build();

        expect(transaction, isNotNull);
        expect(transaction.instructions.length, equals(1));
      });

      test('throws error when building empty transaction', () async {
        final builder = TransactionBuilder(provider: mockProvider);

        expect(
          () => builder.build(),
          throwsA(isA<Exception>()),
        );
      });

      test('can chain multiple operations', () {
        final builder = TransactionBuilder(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final signerKey =
            PublicKey.fromBase58('11111111111111111111111111111113');

        final instruction = TransactionInstruction(
          programId: programId,
          accounts: const <AccountMeta>[],
          data: Uint8List.fromList([1, 2, 3]),
        );

        final result =
            builder.add(instruction).addSigner(signerKey).simulation(true);

        expect(result, equals(builder));
      });
    });
  });
}
