import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('External Package Wrappers', () {
    group('EncodingWrapper', () {
      test('should encode and decode hex correctly', () {
        final bytes = Uint8List.fromList(
          [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF],
        );
        final hex = EncodingWrapper.encodeHex(bytes);
        expect(hex, equals('0123456789abcdef'));

        final decoded = EncodingWrapper.decodeHex(hex);
        expect(decoded, equals(bytes));
      });

      test('should encode and decode Base64 correctly', () {
        final bytes = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
        final base64 = EncodingWrapper.encodeBase64(bytes);
        expect(base64, equals('SGVsbG8='));

        final decoded = EncodingWrapper.decodeBase64(base64);
        expect(decoded, equals(bytes));
      });

      test('should convert string to bytes and back', () {
        const testString = 'Hello, Anchor!';
        final bytes = EncodingWrapper.stringToBytes(testString);
        final decoded = EncodingWrapper.bytesToString(bytes);
        expect(decoded, equals(testString));
      });

      test('should validate Base58 format (basic)', () {
        expect(
          EncodingWrapper.isValidBase58(
            '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz',
          ),
          isTrue,
        );
        expect(EncodingWrapper.isValidBase58(''), isFalse);
        expect(
          EncodingWrapper.isValidBase58('0OIl'),
          isFalse,
        ); // Invalid Base58 characters
      });

      test('should throw on invalid hex', () {
        // Odd length should throw EncodingException
        expect(
          () => EncodingWrapper.decodeHex('abc'),
          throwsA(isA<EncodingException>()),
        );
        // Invalid hex characters (even length) should throw FormatException
        expect(
          () => EncodingWrapper.decodeHex('gg'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('CryptoWrapper', () {
      test('should generate keypair successfully', () async {
        final keypair = await CryptoWrapper.generateKeypair();
        expect(keypair.publicKey.length, equals(32));
        expect(keypair.privateKey.length, equals(64));
      });

      test('should throw CryptoException for invalid secret key', () {
        final invalidSecretKey = Uint8List(10); // Wrong size
        expect(
          () => CryptoWrapper.fromSecretKey(invalidSecretKey),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should throw CryptoException for invalid private key in sign', () {
        final invalidPrivateKey = Uint8List(10); // Wrong size
        final data = Uint8List.fromList([1, 2, 3]);
        expect(
          () => CryptoWrapper.sign(data, invalidPrivateKey),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should verify signature correctly', () async {
        final keypair = await CryptoWrapper.generateKeypair();
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final signature = await CryptoWrapper.sign(data, keypair.privateKey);
        final isValid =
            await CryptoWrapper.verify(data, signature, keypair.publicKey);
        expect(isValid, isTrue);
      });

      test('should throw CryptoException for invalid seed', () {
        final invalidSeed = Uint8List(10); // Wrong size
        expect(
          () => CryptoWrapper.fromSeed(invalidSeed),
          throwsA(isA<CryptoException>()),
        );
      });
    });

    group('BorshWrapper', () {
      test(
        'should serialize basic types correctly',
        () {
          expect(BorshWrapper.serialize(42), equals([42]));
          expect(BorshWrapper.serialize(true), equals([1]));
          expect(BorshWrapper.serialize(false), equals([0]));
          expect(BorshWrapper.serialize('hi'), equals([2, 0, 0, 0, 104, 105]));
        },
      );

      test(
        'should create discriminators correctly',
        () {
          final accountDisc = BorshWrapper.createAccountDiscriminator('Test');
          final instructionDisc =
              BorshWrapper.createInstructionDiscriminator('test');

          expect(accountDisc.length, equals(8));
          expect(instructionDisc.length, equals(8));
          expect(accountDisc, isNot(equals(instructionDisc)));
        },
      );

      test(
        'should deserialize data correctly',
        () {
          final data = Uint8List.fromList([42]);
          final result = BorshWrapper.deserialize<int>(
            data,
            (deserializer) => deserializer.readU8(),
          );
          expect(result, equals(42));
        },
      );
    });

    group('KeypairData', () {
      test('should create KeypairData correctly', () {
        final publicKey = Uint8List.fromList([1, 2, 3, 4]);
        final privateKey = Uint8List.fromList([5, 6, 7, 8]);

        final keypair =
            KeypairData(publicKey: publicKey, privateKey: privateKey);

        expect(keypair.publicKey, equals(publicKey));
        expect(keypair.privateKey, equals(privateKey));
        expect(keypair.toString(), contains('4 bytes'));
      });
    });

    group('Exception Classes', () {
      test('should format exception messages correctly', () {
        const message = 'Test error message';

        final cryptoException = const CryptoException(message);
        expect(cryptoException.toString(), equals('CryptoException: $message'));

        final borshException = const BorshException(message);
        expect(borshException.toString(), equals('BorshException: $message'));

        final encodingException = const EncodingException(message);
        expect(
          encodingException.toString(),
          equals('EncodingException: $message'),
        );
      });
    });
  });
}
