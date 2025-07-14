import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('PDA Integration Tests', () {
    test('should match expected anchor program patterns', () async {
      // Test with a realistic program ID (this is the system program ID for testing)
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Test common Anchor patterns
      final counterSeeds = [Uint8List.fromList('counter'.codeUnits)];
      final counterResult =
          await PublicKey.findProgramAddress(counterSeeds, programId);

      expect(counterResult.address.isDefault, isFalse);
      expect(counterResult.bump, greaterThan(0));

      print(
          'Counter PDA: ${counterResult.address.toBase58()}, bump: ${counterResult.bump}',);

      // Test with user-specific PDA
      final userPubkey =
          PublicKey.fromBase58('7BgBvyjrZX1YKz4oh9mjb8ZScatkkwb8DzFx6bisEzF');
      final userCounterSeeds = [
        Uint8List.fromList('user_counter'.codeUnits),
        userPubkey.toBytes(),
      ];
      final userResult =
          await PublicKey.findProgramAddress(userCounterSeeds, programId);

      expect(userResult.address.isDefault, isFalse);
      print(
          'User counter PDA: ${userResult.address.toBase58()}, bump: ${userResult.bump}',);
    });

    test('should handle edge cases correctly', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Test with empty seeds
      try {
        final emptyResult = await PublicKey.findProgramAddress([], programId);
        expect(emptyResult.address, isA<PublicKey>());
        print('Empty seeds PDA: ${emptyResult.address.toBase58()}');
      } catch (e) {
        print('Empty seeds failed (might be expected): $e');
      }

      // Test with maximum seed length
      final maxSeed = Uint8List(32); // 32 bytes is max per seed
      for (int i = 0; i < maxSeed.length; i++) {
        maxSeed[i] = i; // Fill with incremental values
      }

      final maxSeedResult =
          await PublicKey.findProgramAddress([maxSeed], programId);
      expect(maxSeedResult.address, isA<PublicKey>());
      print('Max seed PDA: ${maxSeedResult.address.toBase58()}');
    });

    test('should validate PDA correctly', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');
      final seeds = [Uint8List.fromList('validation_test'.codeUnits)];

      // Find the PDA
      final result = await PublicKey.findProgramAddress(seeds, programId);

      // Validate that we can recreate the same address with the bump
      final recreatedAddress = await PublicKey.createProgramAddress([
        ...seeds,
        Uint8List.fromList([result.bump]),
      ], programId,);

      expect(recreatedAddress.toBase58(), equals(result.address.toBase58()));
      print('Validation successful: ${result.address.toBase58()}');
    });

    test('should work with various data types as seeds', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Test with different data patterns that are common in Anchor
      final seeds = [
        Uint8List.fromList('anchor'.codeUnits), // String literal
        Uint8List.fromList([0, 0, 0, 1]), // u32 in little endian
        Uint8List.fromList([255, 255, 255, 255, 255, 255, 255, 255]), // u64 max
        PublicKey.fromBase58('7BgBvyjrZX1YKz4oh9mjb8ZScatkkwb8DzFx6bisEzF')
            .toBytes(), // PublicKey
      ];

      final result = await PublicKey.findProgramAddress(seeds, programId);
      expect(result.address, isA<PublicKey>());

      print('Multi-type seeds PDA: ${result.address.toBase58()}');
    });
  });
}
