/// Tests for data conversion utilities
///
/// Comprehensive test suite covering all data conversion functionality including:
/// - Buffer manipulation and validation
/// - Base58/Base64/Hex encoding and decoding
/// - Number conversion utilities
/// - BigInt support
/// - Endianness handling
/// - Data validation functions

library;

import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('DataConverter', () {
    // ========================================================================
    // Buffer Manipulation Tests
    // ========================================================================

    group('Buffer Manipulation', () {
      test('createBuffer creates buffer with correct size', () {
        final buffer = DataConverter.createBuffer(10);
        expect(buffer.length, equals(10));
        expect(buffer.every((b) => b == 0), isTrue);
      });

      test('createBuffer with fill value', () {
        final buffer = DataConverter.createBuffer(5, 0xFF);
        expect(buffer.length, equals(5));
        expect(buffer.every((b) => b == 0xFF), isTrue);
      });

      test('createBuffer throws on negative size', () {
        expect(() => DataConverter.createBuffer(-1),
            throwsA(isA<DataConversionException>()),);
      });

      test('concat combines multiple arrays', () {
        final a = Uint8List.fromList([1, 2]);
        final b = Uint8List.fromList([3, 4, 5]);
        final c = Uint8List.fromList([6]);

        final result = DataConverter.concat([a, b, c]);
        expect(result, equals([1, 2, 3, 4, 5, 6]));
      });

      test('concat with empty arrays', () {
        final result = DataConverter.concat([]);
        expect(result.length, equals(0));

        final a = Uint8List.fromList([1, 2]);
        final b = Uint8List(0);
        final combined = DataConverter.concat([a, b]);
        expect(combined, equals([1, 2]));
      });

      test('copyBytes copies data correctly', () {
        final source = Uint8List.fromList([1, 2, 3, 4, 5]);
        final dest = Uint8List(5);

        DataConverter.copyBytes(source, dest);
        expect(dest, equals([1, 2, 3, 4, 5]));
      });

      test('copyBytes with ranges', () {
        final source = Uint8List.fromList([1, 2, 3, 4, 5]);
        final dest = Uint8List(10);

        DataConverter.copyBytes(source, dest,
            sourceStart: 1, sourceEnd: 4, destinationStart: 2,);

        expect(dest.sublist(2, 5), equals([2, 3, 4]));
      });

      test('slice creates subarray', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);

        expect(DataConverter.slice(data, 1, 4), equals([2, 3, 4]));
        expect(DataConverter.slice(data, 2), equals([3, 4, 5]));
        expect(DataConverter.slice(data, -2), equals([4, 5]));
        expect(DataConverter.slice(data, 1, -1), equals([2, 3, 4]));
      });

      test('equals compares arrays correctly', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2, 3]);
        final c = Uint8List.fromList([1, 2, 4]);
        final d = Uint8List.fromList([1, 2]);

        expect(DataConverter.equals(a, b), isTrue);
        expect(DataConverter.equals(a, c), isFalse);
        expect(DataConverter.equals(a, d), isFalse);
      });

      test('startsWith checks prefix correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final prefix1 = Uint8List.fromList([1, 2]);
        final prefix2 = Uint8List.fromList([2, 3]);
        final prefix3 = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

        expect(DataConverter.startsWith(data, prefix1), isTrue);
        expect(DataConverter.startsWith(data, prefix2), isFalse);
        expect(DataConverter.startsWith(data, prefix3), isFalse);
      });

      test('padLeft pads correctly', () {
        final data = Uint8List.fromList([1, 2]);
        final padded = DataConverter.padLeft(data, 5);
        expect(padded, equals([0, 0, 0, 1, 2]));

        final paddedWithValue = DataConverter.padLeft(data, 4, 0xFF);
        expect(paddedWithValue, equals([0xFF, 0xFF, 1, 2]));
      });

      test('padRight pads correctly', () {
        final data = Uint8List.fromList([1, 2]);
        final padded = DataConverter.padRight(data, 5);
        expect(padded, equals([1, 2, 0, 0, 0]));

        final paddedWithValue = DataConverter.padRight(data, 4, 0xFF);
        expect(paddedWithValue, equals([1, 2, 0xFF, 0xFF]));
      });
    });

    // ========================================================================
    // Base58 Encoding Tests
    // ========================================================================

    group('Base58 Encoding', () {
      test('encodes and decodes correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encoded = DataConverter.encodeBase58(data);
        final decoded = DataConverter.decodeBase58(encoded);

        expect(decoded, equals(data));
      });

      test('handles empty data', () {
        final empty = Uint8List(0);
        final encoded = DataConverter.encodeBase58(empty);
        final decoded = DataConverter.decodeBase58(encoded);

        expect(decoded.length, equals(0));
      });

      test('validates Base58 strings', () {
        expect(
            DataConverter.isValidBase58(
                '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz',),
            isTrue,);
        expect(DataConverter.isValidBase58('invalid0OIl'), isFalse);
      });

      test('throws on invalid Base58', () {
        expect(() => DataConverter.decodeBase58('0OIl'),
            throwsA(isA<DataConversionException>()),);
      });
    });

    // ========================================================================
    // Base64 Encoding Tests
    // ========================================================================

    group('Base64 Encoding', () {
      test('encodes and decodes correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encoded = DataConverter.encodeBase64(data);
        final decoded = DataConverter.decodeBase64(encoded);

        expect(decoded, equals(data));
      });

      test('handles text data', () {
        final text = 'Hello, World!';
        final textBytes = DataConverter.encodeUtf8(text);
        final encoded = DataConverter.encodeBase64(textBytes);
        final decoded = DataConverter.decodeBase64(encoded);
        final decodedText = DataConverter.decodeUtf8(decoded);

        expect(decodedText, equals(text));
      });

      test('validates Base64 strings', () {
        expect(DataConverter.isValidBase64('SGVsbG8gV29ybGQ='), isTrue);
        expect(DataConverter.isValidBase64('invalid_chars!@#'), isFalse);
      });

      test('Base64 URL encoding', () {
        final data = Uint8List.fromList([251, 252, 253, 254, 255]);
        final encoded = DataConverter.encodeBase64Url(data);
        final decoded = DataConverter.decodeBase64Url(encoded);

        expect(decoded, equals(data));
        expect(encoded.contains('+'), isFalse);
        expect(encoded.contains('/'), isFalse);
      });
    });

    // ========================================================================
    // Hex Encoding Tests
    // ========================================================================

    group('Hex Encoding', () {
      test('encodes and decodes correctly', () {
        final data = Uint8List.fromList([0, 15, 255, 170]);
        final encoded = DataConverter.encodeHex(data);
        final decoded = DataConverter.decodeHex(encoded);

        expect(encoded, equals('000fffaa'));
        expect(decoded, equals(data));
      });

      test('handles 0x prefix', () {
        final data = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        final encodedWithPrefix = DataConverter.encodeHex(data, prefix: true);
        final decoded = DataConverter.decodeHex(encodedWithPrefix);

        expect(encodedWithPrefix, equals('0xdeadbeef'));
        expect(decoded, equals(data));
      });

      test('validates hex strings', () {
        expect(DataConverter.isValidHex('deadbeef'), isTrue);
        expect(DataConverter.isValidHex('0xDEADBEEF'), isTrue);
        expect(DataConverter.isValidHex('invalid_hex'), isFalse);
        expect(DataConverter.isValidHex('odd_length1'), isFalse);
      });

      test('throws on invalid hex', () {
        expect(() => DataConverter.decodeHex('invalid'),
            throwsA(isA<DataConversionException>()),);
        expect(() => DataConverter.decodeHex('12G'),
            throwsA(isA<DataConversionException>()),);
      });
    });

    // ========================================================================
    // UTF-8 Encoding Tests
    // ========================================================================

    group('UTF-8 Encoding', () {
      test('encodes and decodes correctly', () {
        final text = 'Hello, 世界! 🌍';
        final encoded = DataConverter.encodeUtf8(text);
        final decoded = DataConverter.decodeUtf8(encoded);

        expect(decoded, equals(text));
      });

      test('validates UTF-8 sequences', () {
        final validUtf8 = DataConverter.encodeUtf8('Valid UTF-8 text');
        final invalidUtf8 = Uint8List.fromList([0xFF, 0xFE, 0xFD]);

        expect(DataConverter.isValidUtf8(validUtf8), isTrue);
        expect(DataConverter.isValidUtf8(invalidUtf8), isFalse);
      });
    });

    // ========================================================================
    // Number Conversion Tests
    // ========================================================================

    group('Number Conversion', () {
      test('u8 conversion', () {
        expect(DataConverter.u8ToBytes(0), equals([0]));
        expect(DataConverter.u8ToBytes(255), equals([255]));
        expect(DataConverter.bytesToU8(Uint8List.fromList([128])), equals(128));

        expect(() => DataConverter.u8ToBytes(-1),
            throwsA(isA<DataConversionException>()),);
        expect(() => DataConverter.u8ToBytes(256),
            throwsA(isA<DataConversionException>()),);
      });

      test('u16 little endian conversion', () {
        final bytes = DataConverter.u16ToBytes(0x1234);
        expect(bytes, equals([0x34, 0x12])); // Little endian
        expect(DataConverter.bytesToU16(bytes), equals(0x1234));

        expect(DataConverter.bytesToU16(Uint8List.fromList([0xFF, 0xFF])),
            equals(65535),);
      });

      test('u32 little endian conversion', () {
        final bytes = DataConverter.u32ToBytes(0x12345678);
        expect(bytes, equals([0x78, 0x56, 0x34, 0x12])); // Little endian
        expect(DataConverter.bytesToU32(bytes), equals(0x12345678));
      });

      test('u64 little endian conversion', () {
        final value = 0x123456789ABCDEF0;
        final bytes = DataConverter.u64ToBytes(value);
        expect(DataConverter.bytesToU64(bytes), equals(value));
      });

      test('signed integer conversions', () {
        expect(DataConverter.i8ToBytes(-128), equals([128]));
        expect(
            DataConverter.bytesToI8(Uint8List.fromList([128])), equals(-128),);

        final i16Bytes = DataConverter.i16ToBytes(-1);
        expect(DataConverter.bytesToI16(i16Bytes), equals(-1));

        final i32Bytes = DataConverter.i32ToBytes(-2147483648);
        expect(DataConverter.bytesToI32(i32Bytes), equals(-2147483648));
      });

      test('floating point conversions', () {
        final value = 3.14159;
        final f64Bytes = DataConverter.f64ToBytes(value);
        final f32Bytes = DataConverter.f32ToBytes(value);

        expect(DataConverter.bytesToF64(f64Bytes), closeTo(value, 1e-15));
        expect(DataConverter.bytesToF32(f32Bytes), closeTo(value, 1e-6));
      });
    });

    // ========================================================================
    // BigInt Conversion Tests
    // ========================================================================

    group('BigInt Conversion', () {
      test('converts positive BigInt to bytes', () {
        final value = BigInt.parse('1234567890123456789');
        final bytes = DataConverter.bigIntToBytes(value, 16);
        final decoded = DataConverter.bytesToBigInt(bytes);

        expect(decoded, equals(value));
      });

      test('handles maximum values', () {
        final maxU64 = (BigInt.one << 64) - BigInt.one;
        final bytes = DataConverter.bigIntToBytes(maxU64, 8);
        expect(DataConverter.bytesToBigInt(bytes), equals(maxU64));
      });

      test('throws on overflow', () {
        final tooBig = BigInt.one << 64;
        expect(() => DataConverter.bigIntToBytes(tooBig, 8),
            throwsA(isA<DataConversionException>()),);
      });

      test('signed BigInt conversion', () {
        final positive = BigInt.from(12345);
        final negative = BigInt.from(-12345);
        final zero = BigInt.zero;

        final posBytes = DataConverter.bigIntToSignedBytes(positive, 8);
        final negBytes = DataConverter.bigIntToSignedBytes(negative, 8);
        final zeroBytes = DataConverter.bigIntToSignedBytes(zero, 8);

        expect(DataConverter.bytesToSignedBigInt(posBytes), equals(positive));
        expect(DataConverter.bytesToSignedBigInt(negBytes), equals(negative));
        expect(DataConverter.bytesToSignedBigInt(zeroBytes), equals(zero));
      });

      test('handles extreme signed values', () {
        final maxPos = (BigInt.one << 63) - BigInt.one;
        final minNeg = -(BigInt.one << 63);

        final maxBytes = DataConverter.bigIntToSignedBytes(maxPos, 8);
        final minBytes = DataConverter.bigIntToSignedBytes(minNeg, 8);

        expect(DataConverter.bytesToSignedBigInt(maxBytes), equals(maxPos));
        expect(DataConverter.bytesToSignedBigInt(minBytes), equals(minNeg));
      });
    });

    // ========================================================================
    // Endianness Tests
    // ========================================================================

    group('Endianness Utilities', () {
      test('reverseBytes works correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final reversed = DataConverter.reverseBytes(data);
        expect(reversed, equals([4, 3, 2, 1]));
      });

      test('endian conversion', () {
        final little = Uint8List.fromList([0x78, 0x56, 0x34, 0x12]);
        final big = DataConverter.littleToBigEndian(little);
        expect(big, equals([0x12, 0x34, 0x56, 0x78]));

        final backToLittle = DataConverter.bigToLittleEndian(big);
        expect(backToLittle, equals(little));
      });

      test('read/write with endianness', () {
        final buffer = Uint8List(8);

        DataConverter.write16(buffer, 0x1234);
        DataConverter.write32(buffer, 0x12345678, offset: 2);

        expect(DataConverter.read16(buffer), equals(0x1234));
        expect(DataConverter.read32(buffer, offset: 2), equals(0x12345678));
      });

      test('read/write with big endian', () {
        final buffer = Uint8List(4);

        DataConverter.write32(buffer, 0x12345678, endian: Endian.big);
        expect(buffer, equals([0x12, 0x34, 0x56, 0x78]));

        final value = DataConverter.read32(buffer, endian: Endian.big);
        expect(value, equals(0x12345678));
      });
    });

    // ========================================================================
    // Data Validation Tests
    // ========================================================================

    group('Data Validation', () {
      test('validateLength works correctly', () {
        final data = Uint8List(10);

        expect(() => DataConverter.validateLength(data, 10), returnsNormally);
        expect(() => DataConverter.validateLength(data, 5),
            throwsA(isA<DataConversionException>()),);
      });

      test('validateMinLength works correctly', () {
        final data = Uint8List(10);

        expect(() => DataConverter.validateMinLength(data, 5), returnsNormally);
        expect(() => DataConverter.validateMinLength(data, 15),
            throwsA(isA<DataConversionException>()),);
      });

      test('validateIntRange works correctly', () {
        expect(
            () => DataConverter.validateIntRange(50, 0, 100), returnsNormally,);
        expect(() => DataConverter.validateIntRange(150, 0, 100),
            throwsA(isA<DataConversionException>()),);
      });

      test('validateBigIntRange works correctly', () {
        final value = BigInt.from(50);
        final min = BigInt.zero;
        final max = BigInt.from(100);

        expect(() => DataConverter.validateBigIntRange(value, min, max),
            returnsNormally,);
        expect(
            () => DataConverter.validateBigIntRange(BigInt.from(150), min, max),
            throwsA(isA<DataConversionException>()),);
      });

      test('isZeroBytes detects zero arrays', () {
        expect(DataConverter.isZeroBytes(Uint8List(10)), isTrue);
        expect(
            DataConverter.isZeroBytes(Uint8List.fromList([0, 0, 0])), isTrue,);
        expect(
            DataConverter.isZeroBytes(Uint8List.fromList([0, 1, 0])), isFalse,);
      });

      test('isValidEncoding validates formats', () {
        expect(DataConverter.isValidEncoding('SGVsbG8=', 'base64'), isTrue);
        expect(DataConverter.isValidEncoding('deadbeef', 'hex'), isTrue);
        expect(DataConverter.isValidEncoding('Hello', 'utf8'), isTrue);

        // Test that unknown encoding throws an exception
        expect(() => DataConverter.isValidEncoding('invalid', 'unknown'),
            throwsA(isA<DataConversionException>()),);
      });

      test('bytesToDebugString creates readable output', () {
        final data = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        final debug = DataConverter.bytesToDebugString(data);

        expect(debug, contains('de ad be ef'));
        expect(debug, contains('4 bytes'));
      });

      test('bytesToDebugString truncates long arrays', () {
        final longData = Uint8List(100);
        final debug = DataConverter.bytesToDebugString(longData, maxLength: 10);

        expect(debug, contains('more'));
        expect(debug, contains('100 bytes'));
      });
    });

    // ========================================================================
    // Error Handling Tests
    // ========================================================================

    group('Error Handling', () {
      test('DataConversionException has proper message', () {
        final exception = const DataConversionException('Test error');
        expect(exception.toString(), contains('Test error'));
      });

      test('invalid operations throw appropriate exceptions', () {
        // Test various invalid operations to ensure proper error handling
        expect(() => DataConverter.createBuffer(-1),
            throwsA(isA<DataConversionException>()),);
        expect(() => DataConverter.decodeHex('invalid'),
            throwsA(isA<DataConversionException>()),);
        expect(() => DataConverter.u8ToBytes(256),
            throwsA(isA<DataConversionException>()),);
        expect(() => DataConverter.bytesToU16(Uint8List(1)),
            throwsA(isA<DataConversionException>()),);
      });
    });

    // ========================================================================
    // Integration Tests
    // ========================================================================

    group('Integration Tests', () {
      test('complex data pipeline', () {
        // Test a complex pipeline of operations
        final originalText = 'Hello, Anchor! 🚀';

        // Text -> UTF-8 -> Base64 -> decode -> hex -> decode -> back to text
        final utf8Bytes = DataConverter.encodeUtf8(originalText);
        final base64String = DataConverter.encodeBase64(utf8Bytes);
        final decodedFromBase64 = DataConverter.decodeBase64(base64String);
        final hexString = DataConverter.encodeHex(decodedFromBase64);
        final decodedFromHex = DataConverter.decodeHex(hexString);
        final finalText = DataConverter.decodeUtf8(decodedFromHex);

        expect(finalText, equals(originalText));
      });

      test('number conversion pipeline', () {
        // Test various number conversions
        final numbers = [0, 1, 255, 65535, 4294967295];

        for (final num in numbers) {
          if (num <= 255) {
            final u8Bytes = DataConverter.u8ToBytes(num);
            expect(DataConverter.bytesToU8(u8Bytes), equals(num));
          }

          if (num <= 65535) {
            final u16Bytes = DataConverter.u16ToBytes(num);
            expect(DataConverter.bytesToU16(u16Bytes), equals(num));
          }

          final u32Bytes = DataConverter.u32ToBytes(num);
          expect(DataConverter.bytesToU32(u32Bytes), equals(num));
        }
      });

      test('BigInt with various encodings', () {
        final bigValue = BigInt.parse('123456789012345678901234567890');
        final bytes = DataConverter.bigIntToBytes(bigValue, 16);

        // Test encoding the bytes in different formats
        final hex = DataConverter.encodeHex(bytes);
        final base64 = DataConverter.encodeBase64(bytes);
        final base58 = DataConverter.encodeBase58(bytes);

        // Decode back and verify
        final hexDecoded = DataConverter.decodeHex(hex);
        final base64Decoded = DataConverter.decodeBase64(base64);
        final base58Decoded = DataConverter.decodeBase58(base58);

        expect(DataConverter.equals(hexDecoded, bytes), isTrue);
        expect(DataConverter.equals(base64Decoded, bytes), isTrue);
        expect(DataConverter.equals(base58Decoded, bytes), isTrue);

        final recoveredValue = DataConverter.bytesToBigInt(hexDecoded);
        expect(recoveredValue, equals(bigValue));
      });
    });
  });
}
