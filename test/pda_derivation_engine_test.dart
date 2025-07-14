/// Tests for PDA Derivation Engine
///
/// This test suite validates the PDA derivation engine against known test vectors
/// and ensures compatibility with TypeScript Anchor client behavior.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('PdaDerivationEngine', () {
    late PublicKey testProgramId;

    setUp(() {
      // Use a known test program ID
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111112');
    });

    group('PdaSeed implementations', () {
      test('StringSeed should convert to bytes correctly', () {
        final seed = const StringSeed('test');
        final bytes = seed.toBytes();
        expect(bytes, equals([116, 101, 115, 116])); // UTF-8 bytes for "test"
        expect(seed.toDebugString(), equals('String("test")'));
      });

      test('BytesSeed should handle bytes correctly', () {
        final testBytes = Uint8List.fromList([1, 2, 3, 4]);
        final seed = BytesSeed(testBytes);
        expect(seed.toBytes(), equals(testBytes));
        expect(seed.toDebugString(), equals('Bytes([01, 02, 03, 04])'));
      });

      test('BytesSeed should validate length', () {
        final longBytes = Uint8List(33); // Too long
        expect(
            () => BytesSeed(longBytes), throwsA(isA<PdaDerivationException>()),);
      });

      test('PublicKeySeed should handle PublicKey correctly', () {
        final publicKey =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final seed = PublicKeySeed(publicKey);
        expect(seed.toBytes(), equals(publicKey.toBytes()));
        expect(seed.toDebugString(), contains('PublicKey('));
      });

      test('NumberSeed should handle different sizes and endianness', () {
        // Test u8
        final u8Seed = const NumberSeed(255, byteLength: 1);
        expect(u8Seed.toBytes(), equals([255]));

        // Test u16 little endian
        final u16Seed =
            const NumberSeed(0x1234, byteLength: 2);
        expect(u16Seed.toBytes(), equals([0x34, 0x12]));

        // Test u32 little endian
        final u32Seed =
            const NumberSeed(0x12345678);
        expect(u32Seed.toBytes(), equals([0x78, 0x56, 0x34, 0x12]));

        // Test u64 little endian
        final u64Seed = const NumberSeed(0x123456789ABCDEF0,
            byteLength: 8,);
        expect(u64Seed.toBytes(),
            equals([0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12]),);
      });

      test('NumberSeed should throw for invalid byte lengths', () {
        expect(() => const NumberSeed(42, byteLength: 3).toBytes(),
            throwsA(isA<PdaDerivationException>()),);
      });
    });

    group('findProgramAddress', () {
      test('should find valid PDA with simple string seed', () {
        final seeds = [const StringSeed('test')];
        final result =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);

        expect(result.address, isA<PublicKey>());
        expect(result.bump, greaterThanOrEqualTo(0));
        expect(result.bump, lessThanOrEqualTo(255));

        // Validate that the result is indeed a valid PDA
        expect(result.address.isOnCurve(), isFalse);
      });

      test('should find valid PDA with multiple seeds', () {
        final seeds = [
          const StringSeed('test'),
          const NumberSeed(42),
          PublicKeySeed(
              PublicKey.fromBase58('11111111111111111111111111111111'),),
        ];
        final result =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);

        expect(result.address, isA<PublicKey>());
        expect(result.bump, greaterThanOrEqualTo(0));
        expect(result.bump, lessThanOrEqualTo(255));
        expect(result.address.isOnCurve(), isFalse);
      });

      test('should be deterministic for same inputs', () {
        final seeds = [const StringSeed('deterministic_test')];
        final result1 =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);
        final result2 =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);

        expect(result1.address, equals(result2.address));
        expect(result1.bump, equals(result2.bump));
      });

      test('should produce different results for different seeds', () {
        final seeds1 = [const StringSeed('test1')];
        final seeds2 = [const StringSeed('test2')];

        final result1 =
            PdaDerivationEngine.findProgramAddress(seeds1, testProgramId);
        final result2 =
            PdaDerivationEngine.findProgramAddress(seeds2, testProgramId);

        expect(result1.address, isNot(equals(result2.address)));
      });

      test('should produce different results for different program IDs', () {
        final seeds = [const StringSeed('test')];
        final programId1 =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final programId2 =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final result1 =
            PdaDerivationEngine.findProgramAddress(seeds, programId1);
        final result2 =
            PdaDerivationEngine.findProgramAddress(seeds, programId2);

        expect(result1.address, isNot(equals(result2.address)));
      });

      test('should throw for seeds that are too long', () {
        expect(() {
          BytesSeed(Uint8List(33)); // This will throw in constructor
        }, throwsA(isA<PdaDerivationException>()),);
      });

      test('should throw when total seed length exceeds limit', () {
        // Create seeds that total more than 64 bytes
        final seeds =
            List.generate(3, (_) => BytesSeed(Uint8List(25))); // 75 bytes total

        expect(
          () => PdaDerivationEngine.findProgramAddress(seeds, testProgramId),
          throwsA(isA<PdaDerivationException>()),
        );
      });

      test('should handle empty seeds list', () {
        final seeds = <PdaSeed>[];
        final result =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);

        expect(result.address, isA<PublicKey>());
        expect(result.bump, greaterThanOrEqualTo(0));
        expect(result.bump, lessThanOrEqualTo(255));
      });
    });

    group('createProgramAddress', () {
      test('should create PDA with known bump seed', () {
        final seeds = [const StringSeed('test'), const NumberSeed(255, byteLength: 1)];

        try {
          final address =
              PdaDerivationEngine.createProgramAddress(seeds, testProgramId);
          expect(address, isA<PublicKey>());
        } on PdaDerivationException {
          // This is expected if the bump doesn't create a valid PDA
          // Try with a different bump
          final seedsWithDifferentBump = [
            const StringSeed('test'),
            const NumberSeed(254, byteLength: 1),
          ];
          final address = PdaDerivationEngine.createProgramAddress(
              seedsWithDifferentBump, testProgramId,);
          expect(address, isA<PublicKey>());
        }
      });

      test('should be consistent with findProgramAddress', () {
        final baseSeeds = [const StringSeed('consistency_test')];
        final pdaResult =
            PdaDerivationEngine.findProgramAddress(baseSeeds, testProgramId);

        final seedsWithBump = [
          ...baseSeeds,
          NumberSeed(pdaResult.bump, byteLength: 1),
        ];
        final directAddress = PdaDerivationEngine.createProgramAddress(
            seedsWithBump, testProgramId,);

        expect(directAddress, equals(pdaResult.address));
      });
    });

    group('validateProgramAddress', () {
      test('should validate correct PDA', () {
        final seeds = [const StringSeed('validation_test')];
        final result =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);

        final seedsWithBump = [
          ...seeds,
          NumberSeed(result.bump, byteLength: 1),
        ];
        final isValid = PdaDerivationEngine.validateProgramAddress(
          result.address,
          seedsWithBump,
          testProgramId,
        );

        expect(isValid, isTrue);
      });

      test('should reject invalid PDA', () {
        final seeds = [const StringSeed('validation_test')];
        final wrongAddress =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final isValid = PdaDerivationEngine.validateProgramAddress(
          wrongAddress,
          seeds,
          testProgramId,
        );

        expect(isValid, isFalse);
      });
    });

    group('findProgramAddressBatch', () {
      test('should handle multiple seed combinations', () {
        final seedCombinations = [
          [const StringSeed('batch1')],
          [const StringSeed('batch2')],
          [const StringSeed('batch3')],
        ];

        final results = PdaDerivationEngine.findProgramAddressBatch(
            seedCombinations, testProgramId,);

        expect(results.length, equals(3));
        for (final result in results) {
          expect(result.address, isA<PublicKey>());
          expect(result.bump, greaterThanOrEqualTo(0));
          expect(result.bump, lessThanOrEqualTo(255));
        }

        // All results should be different
        expect(results[0].address, isNot(equals(results[1].address)));
        expect(results[1].address, isNot(equals(results[2].address)));
        expect(results[0].address, isNot(equals(results[2].address)));
      });
    });

    group('Seed Creation Utilities', () {
      test('should provide convenient seed creation methods', () {
        final stringSeed = const StringSeed('test');
        expect(stringSeed, isA<StringSeed>());
        expect(stringSeed.toBytes(), equals([116, 101, 115, 116]));

        final bytesSeed = BytesSeed(Uint8List.fromList([1, 2, 3]));
        expect(bytesSeed, isA<BytesSeed>());
        expect(bytesSeed.toBytes(), equals([1, 2, 3]));

        final publicKeySeed = PublicKeySeed(testProgramId);
        expect(publicKeySeed, isA<PublicKeySeed>());
        expect(publicKeySeed.toBytes(), equals(testProgramId.toBytes()));

        final u8Seed = const NumberSeed(255, byteLength: 1);
        expect(u8Seed, isA<NumberSeed>());
        expect(u8Seed.toBytes(), equals([255]));

        final u16Seed = const NumberSeed(0x1234, byteLength: 2);
        expect(u16Seed, isA<NumberSeed>());
        expect(u16Seed.toBytes(), equals([0x34, 0x12]));

        final u32Seed = const NumberSeed(0x12345678);
        expect(u32Seed, isA<NumberSeed>());
        expect(u32Seed.toBytes(), equals([0x78, 0x56, 0x34, 0x12]));

        final u64Seed = const NumberSeed(0x123456789ABCDEF0, byteLength: 8);
        expect(u64Seed, isA<NumberSeed>());
        expect(u64Seed.toBytes(),
            equals([0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12]),);
      });
    });

    group('edge cases and error handling', () {
      test('should handle maximum seed count', () {
        // Create maximum number of valid seeds
        final seeds =
            List.generate(16, (i) => BytesSeed(Uint8List.fromList([i])));

        final result =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);
        expect(result.address, isA<PublicKey>());
      });

      test('should provide detailed debug information', () {
        final seeds = [
          const StringSeed('debug'),
          const NumberSeed(42),
          BytesSeed(Uint8List.fromList([0xFF, 0x00])),
        ];

        final debugString = PdaDerivationEngine.debugSeeds(seeds);
        expect(debugString, contains('String("debug")'));
        expect(debugString, contains('Number(42'));
        expect(debugString, contains('Bytes([ff, 00])'));
      });

      test('should handle special program IDs', () {
        final systemProgram = PublicKey.systemProgram;
        final seeds = [const StringSeed('system_test')];

        final result =
            PdaDerivationEngine.findProgramAddress(seeds, systemProgram);
        expect(result.address, isA<PublicKey>());
        expect(result.address.isOnCurve(), isFalse);
      });
    });

    group('compatibility with existing PDA system', () {
      test('should work with PublicKey.findProgramAddress result format', () {
        final seeds = [const StringSeed('compatibility_test')];
        final result =
            PdaDerivationEngine.findProgramAddress(seeds, testProgramId);

        // Check that our result has the same structure as expected
        expect(result.address, isA<PublicKey>());
        expect(result.bump, isA<int>());
        expect(result.toString(), contains('PdaResult'));
        expect(result.toString(), contains('address:'));
        expect(result.toString(), contains('bump:'));
      });
    });
  });
}
