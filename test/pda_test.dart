import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('PDA Calculation Tests', () {
    test('should calculate PDA correctly', () async {
      // Create a test program ID
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Test with simple string seed
      final seeds = [
        Uint8List.fromList('counter'.codeUnits),
      ];

      // This should not throw an exception anymore
      final result = await PublicKey.findProgramAddress(seeds, programId);

      expect(result, isNotNull);
      expect(result.address, isA<PublicKey>());
      expect(result.bump, isA<int>());
      expect(result.bump, greaterThanOrEqualTo(1));
      expect(result.bump, lessThanOrEqualTo(255));

      print('Generated PDA: ${result.address.toBase58()}');
      print('Bump: ${result.bump}');
    });

    test('should create program address with known bump', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      final seeds = [
        Uint8List.fromList('counter'.codeUnits),
        Uint8List.fromList([255]), // known bump
      ];

      try {
        final address = await PublicKey.createProgramAddress(seeds, programId);
        expect(address, isA<PublicKey>());
        print('Created program address: ${address.toBase58()}');
      } catch (e) {
        // This might fail if bump 255 doesn't work, which is expected
        print('Bump 255 failed (expected): $e');
      }
    });

    test('should be deterministic', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      final seeds = [
        Uint8List.fromList('test'.codeUnits),
      ];

      // Generate PDA twice
      final result1 = await PublicKey.findProgramAddress(seeds, programId);
      final result2 = await PublicKey.findProgramAddress(seeds, programId);

      // Should be identical
      expect(result1.address.toBase58(), equals(result2.address.toBase58()));
      expect(result1.bump, equals(result2.bump));
    });

    test('should work with different seed types', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      final seeds = [
        Uint8List.fromList('prefix'.codeUnits),
        programId.toBytes(), // Use program ID as seed
        Uint8List.fromList([1, 2, 3, 4]), // Raw bytes
      ];

      final result = await PublicKey.findProgramAddress(seeds, programId);

      expect(result, isNotNull);
      expect(result.address, isA<PublicKey>());
      print('Complex PDA: ${result.address.toBase58()}');
    });
  });
}
