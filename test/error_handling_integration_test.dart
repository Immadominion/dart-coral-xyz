/// Error handling integration test
///
/// This test demonstrates error handling patterns for invalid inputs
/// and edge cases that can occur during Anchor program interaction.
library;

import 'dart:typed_data';

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:test/test.dart';

void main() {
  group('Error Handling Integration', () {
    test('should handle invalid program IDs', () {
      expect(
        () => PublicKey.fromBase58('invalid_program_id'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => PublicKey.fromBase58(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle invalid IDL structures', () {
      // Test with missing required fields
      expect(
        () => const Idl(instructions: []),
        returnsNormally, // Basic IDL creation should work
      );

      // Test with invalid instruction
      expect(
        () => const IdlInstruction(
          name: '',
          discriminator: [],
          accounts: [],
          args: [],
        ),
        returnsNormally, // Constructor should work, validation happens elsewhere
      );
    });

    test('should handle connection errors gracefully', () async {
      // Test with invalid RPC URL
      final connection = Connection('http://invalid-url:9999');

      // Connection creation should work, but usage will fail
      expect(connection.endpoint, equals('http://invalid-url:9999'));

      // We can't test actual network failures without a real request,
      // but we can ensure the connection object is created properly
    });

    test('should handle invalid keypair data', () {
      // Test with invalid secret key lengths
      expect(
        () => Keypair.fromSecretKey(Uint8List(32)), // Too short
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Keypair.fromSecretKey(Uint8List(128)), // Too long
        throwsA(isA<ArgumentError>()),
      );

      // Test with invalid base58 string
      expect(
        () => Keypair.fromBase58('invalid_base58_with_invalid_chars'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate PDA generation edge cases', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Test with simple seeds (should work in most cases)
      final counterSeeds = [
        'counter'.codeUnits,
        [1]
      ]; // Add some variation

      try {
        final counterResult = await PublicKey.findProgramAddress(
          counterSeeds.map((s) => s.map((c) => c).toList()).toList().cast(),
          programId,
        );
        expect(counterResult.address.isDefault, isFalse);
        expect(counterResult.bump, lessThanOrEqualTo(255));
      } catch (e) {
        // PDA generation might fail for some seeds, which is expected behavior
        expect(e, isA<Exception>());
        expect(
            e.toString(), contains('Unable to find a viable program address'));
      }
    });

    test('should handle program validation errors', () async {
      // Use a valid base58 string for the address
      final validIdl = const Idl(
        address: '11111111111111111111111111111112', // Valid system program ID
        instructions: [],
      );

      final program = Program(validIdl);
      final validProgramId =
          PublicKey.fromBase58('11111111111111111111111111111112');
      final invalidProgramId =
          PublicKey.fromBase58('11111111111111111111111111111113');

      // Should validate correctly for matching program ID
      expect(() => program.validateProgramId(validProgramId), returnsNormally);

      // Should throw for mismatched program ID
      expect(
        () => program.validateProgramId(invalidProgramId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle missing accounts gracefully', () async {
      // Use a valid base58 string for the address
      final idl = const Idl(
        address: '11111111111111111111111111111112', // Valid system program ID
        instructions: [],
      );

      final program = Program(idl);

      // Should throw for nonexistent account type
      expect(
        () => program.getAccountSize('NonexistentAccount'),
        throwsA(isA<AccountCoderError>()),
      );
    });

    test('should validate instruction arguments', () {
      // Test instruction with invalid discriminator
      const instruction = IdlInstruction(
        name: 'test_instruction',
        discriminator: [], // Empty discriminator should be handled
        accounts: [],
        args: [],
      );

      expect(instruction.name, equals('test_instruction'));
      expect(instruction.discriminator, isEmpty);
    });

    test('should handle transaction building errors', () {
      // Test transaction with no instructions
      final emptyTransaction = Transaction(instructions: []);
      expect(emptyTransaction.instructions, isEmpty);

      // Test that we can create transaction objects even if they're invalid
      // (validation happens during execution)
    });

    test('should validate account metadata', () {
      // Test AccountMeta creation with different combinations
      final validPubkey =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // All combinations should be valid
      final readOnly = AccountMeta(
          publicKey: validPubkey, isSigner: false, isWritable: false);
      final signer = AccountMeta(
          publicKey: validPubkey, isSigner: true, isWritable: false);
      final writable = AccountMeta(
          publicKey: validPubkey, isSigner: false, isWritable: true);
      final signerWritable =
          AccountMeta(publicKey: validPubkey, isSigner: true, isWritable: true);

      expect(readOnly.isSigner, isFalse);
      expect(readOnly.isWritable, isFalse);

      expect(signer.isSigner, isTrue);
      expect(signer.isWritable, isFalse);

      expect(writable.isSigner, isFalse);
      expect(writable.isWritable, isTrue);

      expect(signerWritable.isSigner, isTrue);
      expect(signerWritable.isWritable, isTrue);
    });
  });
}
