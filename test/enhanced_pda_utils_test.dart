import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Enhanced PDA Utils Tests', () {
    late PublicKey programId;

    setUpAll(() {
      programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
    });

    test('seedToBytesEnhanced should handle various types', () {
      // String conversion
      final stringBytes = PdaUtils.seedToBytesEnhanced('test');
      expect(stringBytes, equals(Uint8List.fromList('test'.codeUnits)));

      // Int conversion with default size
      final intBytes = PdaUtils.seedToBytesEnhanced(42);
      expect(intBytes, hasLength(8));
      expect(intBytes[0], equals(42));

      // Int conversion with custom size
      final smallIntBytes = PdaUtils.seedToBytesEnhanced(42, intSize: 4);
      expect(smallIntBytes, hasLength(4));
      expect(smallIntBytes[0], equals(42));

      // BigInt conversion
      final bigIntBytes = PdaUtils.seedToBytesEnhanced(BigInt.from(42));
      expect(bigIntBytes, hasLength(32));
      expect(bigIntBytes[0], equals(42));

      // Bool conversion
      final trueBoolBytes = PdaUtils.seedToBytesEnhanced(true);
      expect(trueBoolBytes, equals(Uint8List.fromList([1])));

      final falseBoolBytes = PdaUtils.seedToBytesEnhanced(false);
      expect(falseBoolBytes, equals(Uint8List.fromList([0])));

      // PublicKey conversion
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
      final pubkeyBytes = PdaUtils.seedToBytesEnhanced(pubkey);
      expect(pubkeyBytes, equals(pubkey.bytes));

      // Uint8List passthrough
      final originalBytes = Uint8List.fromList([1, 2, 3, 4]);
      final passThroughBytes = PdaUtils.seedToBytesEnhanced(originalBytes);
      expect(passThroughBytes, equals(originalBytes));

      // List<int> conversion
      final listIntBytes = PdaUtils.seedToBytesEnhanced([1, 2, 3, 4]);
      expect(listIntBytes, equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('seedToBytesEnhanced should reject unsupported types', () {
      expect(() => PdaUtils.seedToBytesEnhanced(<String, dynamic>{}),
          throwsA(isA<ArgumentError>()),);
      expect(() => PdaUtils.seedToBytesEnhanced(<dynamic>[]),
          throwsA(isA<ArgumentError>()),);
      expect(() => PdaUtils.seedToBytesEnhanced(null),
          throwsA(isA<ArgumentError>()),);
    });

    test('seedFromAccount should extract field values', () {
      final account = {
        'field1': 'value1',
        'nested': {
          'field2': 42,
        },
      };

      final field1Bytes = PdaUtils.seedFromAccount(account, 'field1');
      expect(field1Bytes, equals(Uint8List.fromList('value1'.codeUnits)));

      final field2Bytes = PdaUtils.seedFromAccount(account, 'nested.field2');
      expect(field2Bytes, hasLength(8));
      expect(field2Bytes[0], equals(42));
    });

    test('seedFromAccount should handle missing fields', () {
      final account = {'field1': 'value1'};

      expect(
        () => PdaUtils.seedFromAccount(account, 'missing'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => PdaUtils.seedFromAccount(account, 'field1.missing'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createProgramAddressValidated should validate seeds', () async {
      // Valid seeds
      final validSeeds = [
        Uint8List.fromList('test'.codeUnits),
        Uint8List.fromList([1, 2, 3]),
      ];

      // This should work or throw based on whether the seeds are valid
      try {
        final address =
            await PdaUtils.createProgramAddressValidated(validSeeds, programId);
        expect(address, isA<PublicKey>());
      } catch (e) {
        // Some seed combinations don't produce valid addresses
        expect(e, isA<Exception>());
      }

      // Too many seeds
      final tooManySeeds = List.generate(17, (i) => Uint8List.fromList([i]));
      expect(
        () => PdaUtils.createProgramAddressValidated(tooManySeeds, programId),
        throwsA(isA<ArgumentError>()),
      );

      // Seed too long
      final tooLongSeed = [Uint8List(33)];
      expect(
        () => PdaUtils.createProgramAddressValidated(tooLongSeed, programId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createWithSeedSync should create deterministic addresses', () {
      final baseKey = PublicKey.fromBase58('11111111111111111111111111111112');
      const seed = 'test-seed';

      final address1 = PdaUtils.createWithSeedSync(baseKey, seed, programId);
      final address2 = PdaUtils.createWithSeedSync(baseKey, seed, programId);

      expect(address1, equals(address2));
      expect(address1.toBase58(), isNotEmpty);
    });

    test('deriveAddress should handle mixed seed types', () async {
      final seeds = [
        'string-seed',
        42,
        true,
        PublicKey.fromBase58('11111111111111111111111111111112'),
      ];

      final result = await PdaUtils.deriveAddress(seeds, programId);

      expect(result.address, isA<PublicKey>());
      expect(result.bump, greaterThanOrEqualTo(0));
      expect(result.bump, lessThan(256));
    });

    test('seedsToBytes should convert multiple seeds', () {
      final seeds = [
        'test',
        42,
        true,
        Uint8List.fromList([1, 2, 3]),
      ];

      final seedBytes = PdaUtils.seedsToBytes(seeds);

      expect(seedBytes, hasLength(4));
      expect(seedBytes[0], equals(Uint8List.fromList('test'.codeUnits)));
      expect(seedBytes[1], hasLength(8));
      expect(seedBytes[1][0], equals(42));
      expect(seedBytes[2], equals(Uint8List.fromList([1])));
      expect(seedBytes[3], equals(Uint8List.fromList([1, 2, 3])));
    });
  });

  group('AddressResolver Enhanced Tests', () {
    test('valueToBytes should handle different value types', () {
      // String
      final stringBytes = AddressResolver.valueToBytes('test');
      expect(stringBytes, equals(Uint8List.fromList('test'.codeUnits)));

      // Int
      final intBytes = AddressResolver.valueToBytes(42);
      expect(intBytes, hasLength(8));
      expect(intBytes[0], equals(42));

      // Bool
      final trueBoolBytes = AddressResolver.valueToBytes(true);
      expect(trueBoolBytes, equals(Uint8List.fromList([1])));

      final falseBoolBytes = AddressResolver.valueToBytes(false);
      expect(falseBoolBytes, equals(Uint8List.fromList([0])));

      // PublicKey
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
      final pubkeyBytes = AddressResolver.valueToBytes(pubkey);
      expect(pubkeyBytes, equals(pubkey.bytes));

      // Uint8List
      final originalBytes = Uint8List.fromList([1, 2, 3, 4]);
      final passThroughBytes = AddressResolver.valueToBytes(originalBytes);
      expect(passThroughBytes, equals(originalBytes));

      // List<int>
      final listIntBytes = AddressResolver.valueToBytes([1, 2, 3, 4]);
      expect(listIntBytes, equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('valueToBytes should reject unsupported types', () {
      expect(() => AddressResolver.valueToBytes(<String, dynamic>{}),
          throwsA(isA<ArgumentError>()),);
      expect(() => AddressResolver.valueToBytes(null),
          throwsA(isA<ArgumentError>()),);
    });
  });

  group('AddressValidator Enhanced Tests', () {
    test('validatePda should verify PDA derivation', () async {
      final seeds = [Uint8List.fromList('test'.codeUnits)];
      final programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

      // Derive a real PDA
      final pdaResult = await PdaUtils.findProgramAddress(seeds, programId);

      // Should validate correctly
      final isValid = await AddressValidator.validatePda(
        pdaResult.address,
        seeds,
        programId,
      );
      expect(isValid, isTrue);

      // Should not validate with different seeds
      final differentSeeds = [Uint8List.fromList('different'.codeUnits)];
      final isValidDifferent = await AddressValidator.validatePda(
        pdaResult.address,
        differentSeeds,
        programId,
      );
      expect(isValidDifferent, isFalse);
    });

    test('validatePublicKey should validate base58 strings', () {
      expect(AddressValidator.isValidBase58('11111111111111111111111111111112'),
          isTrue,);
      expect(
          AddressValidator.isValidBase58(
              'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',),
          isTrue,);
      expect(AddressValidator.isValidBase58('invalid-address'), isFalse);
      expect(AddressValidator.isValidBase58(''), isFalse);
    });
  });
}
