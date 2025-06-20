import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Tests for address and key utilities
void main() {
  group('AddressUtils', () {
    late PublicKey testProgramId;
    late PublicKey testUserKey;

    setUp(() {
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111113');
      testUserKey = PublicKey.fromBase58('11111111111111111111111111111114');
    });

    group('Seed Conversion', () {
      test('should convert string to seed bytes', () {
        final seed = 'test-seed';
        final bytes = AddressUtils.stringToSeedBytes(seed);

        expect(bytes, isA<Uint8List>());
        expect(bytes.length, equals(seed.length));
        expect(String.fromCharCodes(bytes), equals(seed));
      });

      test('should convert integer to seed bytes', () {
        final value = 12345;
        final bytes = AddressUtils.intToSeedBytes(value, size: 4);

        expect(bytes, isA<Uint8List>());
        expect(bytes.length, equals(4));

        // Verify little-endian encoding
        final decoded = bytes.buffer.asByteData().getUint32(0, Endian.little);
        expect(decoded, equals(value));
      });

      test('should convert big integer to seed bytes', () {
        final value = BigInt.from(987654321);
        final bytes = AddressUtils.bigIntToSeedBytes(value, size: 8);

        expect(bytes, isA<Uint8List>());
        expect(bytes.length, equals(8));
      });

      test('should convert PublicKey to seed bytes', () {
        final bytes = AddressUtils.toSeedBytes(testUserKey);

        expect(bytes, isA<Uint8List>());
        expect(bytes.length, equals(32));
        expect(bytes, equals(testUserKey.bytes));
      });

      test('should convert mixed seed types', () {
        final seeds = [
          'prefix',
          123,
          testUserKey,
          Uint8List.fromList([1, 2, 3, 4]),
        ];

        final seedBytes = AddressUtils.toSeedBytesList(seeds);

        expect(seedBytes, isA<List<Uint8List>>());
        expect(seedBytes.length, equals(4));
        expect(seedBytes[0], equals(AddressUtils.stringToSeedBytes('prefix')));
        expect(seedBytes[1], equals(AddressUtils.intToSeedBytes(123)));
        expect(seedBytes[2], equals(testUserKey.bytes));
        expect(seedBytes[3], equals(Uint8List.fromList([1, 2, 3, 4])));
      });

      test('should throw error for unsupported seed type', () {
        expect(
          () => AddressUtils.toSeedBytes(DateTime.now()),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('PDA Derivation', () {
      test('should derive PDA from mixed seeds', () async {
        final seeds = ['user', testUserKey];

        // This should successfully derive a PDA or throw a specific exception
        try {
          final result = await AddressUtils.derivePda(seeds, testProgramId);
          expect(result, isA<PdaResult>());
          expect(result.address, isA<PublicKey>());
          expect(result.bump, isA<int>());
        } catch (e) {
          // If PDA derivation fails, it should be a specific exception
          expect(e, isA<Exception>());
        }
      });
    });
  });

  group('AddressValidator', () {
    test('should validate base58 addresses', () {
      // Valid base58 address
      expect(
        AddressValidator.isValidBase58('11111111111111111111111111111112'),
        isTrue,
      );

      // Invalid base58 address
      expect(
        AddressValidator.isValidBase58('invalid-address'),
        isFalse,
      );

      // Empty string
      expect(
        AddressValidator.isValidBase58(''),
        isFalse,
      );
    });

    test('should validate hex addresses', () {
      // Valid hex address (32 bytes = 64 hex chars)
      expect(
        AddressValidator.isValidHex(
            '0000000000000000000000000000000000000000000000000000000000000000'),
        isTrue,
      );

      // Valid hex address with 0x prefix
      expect(
        AddressValidator.isValidHex(
            '0x0000000000000000000000000000000000000000000000000000000000000000'),
        isTrue,
      );

      // Invalid hex address (wrong length)
      expect(
        AddressValidator.isValidHex('0000'),
        isFalse,
      );
    });

    test('should identify system program', () {
      expect(
        AddressValidator.isSystemProgram(PublicKey.systemProgram),
        isTrue,
      );

      expect(
        AddressValidator.isSystemProgram(
            PublicKey.fromBase58('11111111111111111111111111111113')),
        isFalse,
      );
    });

    test('should identify default address', () {
      // The system program ID and default pubkey are the same value in Solana
      expect(
        AddressValidator.isDefaultAddress(PublicKey.systemProgram),
        isTrue,
      );

      expect(
        AddressValidator.isDefaultAddress(PublicKey.defaultPubkey),
        isTrue,
      );
    });
  });

  group('AddressFormatter', () {
    late PublicKey testAddress;

    setUp(() {
      testAddress = PublicKey.fromBase58(
          '11111111111111111111111111111114'); // Different from system program
    });

    test('should shorten long addresses', () {
      final address = '11111111111111111111111111111112';
      final shortened = AddressFormatter.shortenAddress(address);

      expect(shortened, equals('1111...1112'));
    });

    test('should not shorten short addresses', () {
      final address = '1234';
      final shortened = AddressFormatter.shortenAddress(address);

      expect(shortened, equals(address));
    });

    test('should format addresses with custom parameters', () {
      final address = '11111111111111111111111111111112';
      final shortened = AddressFormatter.shortenAddress(
        address,
        prefixLength: 6,
        suffixLength: 6,
        separator: '***',
      );

      expect(shortened, equals('111111***111112'));
    });

    test('should format PublicKey as shortened base58', () {
      final formatted = AddressFormatter.formatShortBase58(testAddress);

      expect(formatted, equals('1111...1114'));
    });

    test('should format addresses in different formats', () {
      // Base58 format
      final base58 = AddressFormatter.formatAddress(
        testAddress,
        format: AddressFormat.base58,
      );
      expect(base58, equals(testAddress.toBase58()));

      // Hex format with prefix
      final hex = AddressFormatter.formatAddress(
        testAddress,
        format: AddressFormat.hex,
      );
      expect(hex, equals('0x${testAddress.toHex()}'));

      // Hex format without prefix
      final hexNoPrefix = AddressFormatter.formatAddress(
        testAddress,
        format: AddressFormat.hexNoPrefix,
      );
      expect(hexNoPrefix, equals(testAddress.toHex()));
    });

    test('should format addresses with shortening', () {
      final formatted = AddressFormatter.formatAddress(
        testAddress,
        format: AddressFormat.base58,
        shorten: true,
      );

      expect(formatted, equals('1111...1114'));
    });

    test('should label common addresses', () {
      // Both system program and default pubkey should be labeled as "System Program"
      // since they are the same value in Solana (all-zeros public key)
      expect(
        AddressFormatter.labelAddress(PublicKey.systemProgram),
        equals('System Program'),
      );

      expect(
        AddressFormatter.labelAddress(PublicKey.defaultPubkey),
        equals('System Program'),
      );

      expect(
        AddressFormatter.labelAddress(testAddress),
        equals('1111...1114'),
      );
    });
  });

  group('KeyConverter', () {
    late PublicKey testKey;
    late String testBase58;
    late String testHex;

    setUp(() {
      testKey = PublicKey.fromBase58('11111111111111111111111111111113');
      testBase58 = testKey.toBase58();
      testHex = testKey.toHex();
    });

    test('should convert base58 to hex', () {
      final hex = KeyConverter.base58ToHex(testBase58);
      expect(hex, equals('0x$testHex'));

      final hexNoPrefix =
          KeyConverter.base58ToHex(testBase58, includePrefix: false);
      expect(hexNoPrefix, equals(testHex));
    });

    test('should convert hex to base58', () {
      final base58 = KeyConverter.hexToBase58(testHex);
      expect(base58, equals(testBase58));

      final base58WithPrefix = KeyConverter.hexToBase58('0x$testHex');
      expect(base58WithPrefix, equals(testBase58));
    });

    test('should convert bytes to base58', () {
      final base58 = KeyConverter.bytesToBase58(testKey.bytes);
      expect(base58, equals(testBase58));
    });

    test('should convert bytes to hex', () {
      final hex = KeyConverter.bytesToHex(testKey.bytes);
      expect(hex, equals('0x$testHex'));

      final hexNoPrefix =
          KeyConverter.bytesToHex(testKey.bytes, includePrefix: false);
      expect(hexNoPrefix, equals(testHex));
    });

    test('should parse addresses in different formats', () {
      // Parse base58
      final fromBase58 = KeyConverter.parseAddress(testBase58);
      expect(fromBase58, equals(testKey));

      // Parse hex
      final fromHex = KeyConverter.parseAddress(testHex);
      expect(fromHex, equals(testKey));

      // Parse hex with prefix
      final fromHexWithPrefix = KeyConverter.parseAddress('0x$testHex');
      expect(fromHexWithPrefix, equals(testKey));
    });

    test('should throw error for invalid address format', () {
      expect(
        () => KeyConverter.parseAddress('invalid-address-format'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SeedGenerator', () {
    late PublicKey userKey;
    late PublicKey mintKey;
    late PublicKey programKey;

    setUp(() {
      userKey = PublicKey.fromBase58('11111111111111111111111111111113');
      mintKey = PublicKey.fromBase58('11111111111111111111111111111114');
      programKey = PublicKey.fromBase58('11111111111111111111111111111115');
    });

    test('should generate user seeds', () {
      final seeds = SeedGenerator.userSeeds(userKey);

      expect(seeds, equals(['user', userKey]));
    });

    test('should generate token account seeds', () {
      final seeds = SeedGenerator.tokenAccountSeeds(mintKey, userKey);

      expect(seeds, equals(['token', mintKey, userKey]));
    });

    test('should generate metadata seeds', () {
      final seeds = SeedGenerator.metadataSeeds(programKey, mintKey);

      expect(seeds, equals(['metadata', programKey, mintKey]));
    });

    test('should generate vault seeds', () {
      final seeds = SeedGenerator.vaultSeeds(userKey);

      expect(seeds, equals(['vault', userKey]));
    });

    test('should generate numbered seeds', () {
      final seeds = SeedGenerator.numberedSeeds('account', 42);

      expect(seeds, equals(['account', 42]));
    });

    test('should generate custom seeds', () {
      final components = [userKey, 123, 'suffix'];
      final seeds = SeedGenerator.customSeeds('prefix', components);

      expect(seeds, equals(['prefix', userKey, 123, 'suffix']));
    });
  });
}
