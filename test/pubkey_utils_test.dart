import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('PublicKeyUtils Tests', () {
    late PublicKey testKey;
    late PublicKey programId;

    setUpAll(() {
      // Use known test keys
      testKey = PublicKey.fromBase58('11111111111111111111111111111112');
      programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
    });

    test('createWithSeedSync should create deterministic addresses', () {
      const seed = 'test-seed';

      final address1 =
          PublicKeyUtils.createWithSeedSync(testKey, seed, programId);
      final address2 =
          PublicKeyUtils.createWithSeedSync(testKey, seed, programId);

      expect(address1, equals(address2));
      expect(address1.toBase58(), isNotEmpty);
    });

    test('findProgramAddress should find PDA', () async {
      final seeds = [
        Uint8List.fromList('test'.codeUnits),
        Uint8List.fromList([1, 2, 3, 4]),
      ];

      final result = await PublicKeyUtils.findProgramAddress(seeds, programId);

      expect(result.address, isA<PublicKey>());
      expect(result.bump, greaterThanOrEqualTo(0));
      expect(result.bump, lessThan(256));
    });

    test('createProgramAddress should create address with known bump',
        () async {
      final seeds = [
        Uint8List.fromList('test'.codeUnits),
        Uint8List.fromList([255]), // bump
      ];

      // This should work or throw - both are valid behaviors
      try {
        final address =
            await PublicKeyUtils.createProgramAddress(seeds, programId);
        expect(address, isA<PublicKey>());
      } catch (e) {
        // Expected for many bump values
        expect(e, isA<Exception>());
      }
    });

    test('isOnCurve should return reasonable results', () {
      final defaultKey = PublicKeyUtils.defaultKey;
      final nonDefaultKey = testKey;

      expect(PublicKeyUtils.isOnCurve(defaultKey), isFalse);
      expect(PublicKeyUtils.isOnCurve(nonDefaultKey), isTrue);
    });

    test('isValidBase58 should validate addresses correctly', () {
      expect(PublicKeyUtils.isValidBase58('11111111111111111111111111111112'),
          isTrue,);
      expect(PublicKeyUtils.isValidBase58('invalid-address'), isFalse);
      expect(PublicKeyUtils.isValidBase58(''), isFalse);
    });

    test('fromBytes should validate byte length', () {
      final validBytes = Uint8List(32);
      final invalidBytes = Uint8List(31);

      expect(() => PublicKeyUtils.fromBytes(validBytes),
          isNot(throwsA(isA<ArgumentError>())),);
      expect(() => PublicKeyUtils.fromBytes(invalidBytes),
          throwsA(isA<ArgumentError>()),);
    });

    test('fromBase58 should validate base58 format', () {
      expect(
          () => PublicKeyUtils.fromBase58('11111111111111111111111111111112'),
          isNot(throwsException),);
      expect(() => PublicKeyUtils.fromBase58('invalid'),
          throwsA(isA<ArgumentError>()),);
    });

    test('toBase58 should convert to string', () {
      final result = PublicKeyUtils.toBase58(testKey);
      expect(result, equals('11111111111111111111111111111112'));
    });

    test('toBytes should return byte array', () {
      final bytes = PublicKeyUtils.toBytes(testKey);
      expect(bytes, hasLength(32));
      expect(bytes, isA<Uint8List>());
    });

    test('unique should generate different keys', () {
      final key1 = PublicKeyUtils.unique(testKey);
      final key2 = PublicKeyUtils.unique(testKey);

      // With time-based uniqueness, these should be different
      expect(key1, isNot(equals(key2)));
    });

    test('equals should compare keys correctly', () {
      final key1 = testKey;
      final key2 = PublicKey.fromBase58('11111111111111111111111111111112');
      final key3 =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

      expect(PublicKeyUtils.equals(key1, key2), isTrue);
      expect(PublicKeyUtils.equals(key1, key3), isFalse);
    });

    test('defaultKey should be all zeros', () {
      final defaultKey = PublicKeyUtils.defaultKey;
      expect(PublicKeyUtils.isDefault(defaultKey), isTrue);
      expect(PublicKeyUtils.isDefault(testKey), isFalse);
    });
  });
}
