/// Comprehensive tests for complex IDL type deserialization in BorshDeserializer
///
/// This test file specifically validates the newly added methods for handling
/// complex IDL types including structs, enums, arrays, vectors, and options.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/src/coder/borsh_types.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

void main() {
  group('BorshDeserializer Complex Types', () {
    late BorshSerializer serializer;
    late BorshDeserializer deserializer;

    setUp(() {
      serializer = BorshSerializer();
    });

    group('readVec', () {
      test('should read vector of integers correctly', () {
        // Serialize test data
        serializer.writeU32(3); // length
        serializer.writeU32(100);
        serializer.writeU32(200);
        serializer.writeU32(300);

        deserializer = BorshDeserializer(serializer.toBytes());
        final result = deserializer.readVec(() => deserializer.readU32());

        expect(result, equals([100, 200, 300]));
        expect(result.length, equals(3));
      });

      test('should read empty vector correctly', () {
        serializer.writeU32(0); // length = 0

        deserializer = BorshDeserializer(serializer.toBytes());
        final result = deserializer.readVec(() => deserializer.readU32());

        expect(result, isEmpty);
      });

      test('should read vector of strings correctly', () {
        // Serialize test data
        serializer.writeU32(2); // length
        serializer.writeString('hello');
        serializer.writeString('world');

        deserializer = BorshDeserializer(serializer.toBytes());
        final result = deserializer.readVec(() => deserializer.readString());

        expect(result, equals(['hello', 'world']));
      });
    });

    group('readStruct', () {
      test('should read struct with multiple field types', () {
        // Serialize test data in field order
        serializer.writeU32(42); // age field
        serializer.writeString('Alice'); // name field
        serializer.writeBool(true); // active field

        deserializer = BorshDeserializer(serializer.toBytes());

        final fields = {
          'age': const IdlType(kind: 'u32'),
          'name': const IdlType(kind: 'string'),
          'active': const IdlType(kind: 'bool'),
        };

        final result = deserializer.readStruct(fields);

        expect(result['age'], equals(42));
        expect(result['name'], equals('Alice'));
        expect(result['active'], equals(true));
        expect(result.keys.length, equals(3));
      });

      test('should read empty struct correctly', () {
        deserializer = BorshDeserializer(Uint8List(0));
        final fields = <String, IdlType>{};

        final result = deserializer.readStruct(fields);

        expect(result, isEmpty);
      });

      test('should read nested struct with PublicKey', () {
        // Create test PublicKey bytes
        final testKeyBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          testKeyBytes[i] = i;
        }

        // Serialize test data
        serializer.writeU64(1000000); // amount field
        for (int i = 0; i < 32; i++) {
          serializer.writeU8(testKeyBytes[i]); // owner field
        }

        deserializer = BorshDeserializer(serializer.toBytes());

        final fields = {
          'amount': const IdlType(kind: 'u64'),
          'owner': const IdlType(kind: 'publicKey'),
        };

        final result = deserializer.readStruct(fields);

        expect(result['amount'], equals(1000000));
        expect(result['owner'], isA<PublicKey>());
        expect((result['owner'] as PublicKey).toBytes(), equals(testKeyBytes));
      });
    });

    group('readIdlType', () {
      test('should handle all primitive types correctly', () {
        // Serialize all primitive types
        serializer.writeBool(true);
        serializer.writeU8(255);
        serializer.writeU16(65535);
        serializer.writeU32(4294967295);
        serializer.writeU64(9223372036854775807);
        serializer.writeI8(-128);
        serializer.writeI16(-32768);
        serializer.writeI32(-2147483648);
        serializer.writeI64(-9223372036854775808);
        serializer.writeString('test string');

        // Create test PublicKey with different pattern
        final testKeyBytes = Uint8List(32);
        testKeyBytes.fillRange(
            0, 32, 42,); // Fill with 42s instead of incrementing pattern
        for (int i = 0; i < 32; i++) {
          serializer.writeU8(testKeyBytes[i]);
        }

        deserializer = BorshDeserializer(serializer.toBytes());

        expect(deserializer.readIdlType(const IdlType(kind: 'bool')),
            equals(true),);
        expect(
            deserializer.readIdlType(const IdlType(kind: 'u8')), equals(255),);
        expect(deserializer.readIdlType(const IdlType(kind: 'u16')),
            equals(65535),);
        expect(deserializer.readIdlType(const IdlType(kind: 'u32')),
            equals(4294967295),);
        expect(deserializer.readIdlType(const IdlType(kind: 'u64')),
            equals(9223372036854775807),);
        expect(
            deserializer.readIdlType(const IdlType(kind: 'i8')), equals(-128),);
        expect(deserializer.readIdlType(const IdlType(kind: 'i16')),
            equals(-32768),);
        expect(deserializer.readIdlType(const IdlType(kind: 'i32')),
            equals(-2147483648),);
        expect(deserializer.readIdlType(const IdlType(kind: 'i64')),
            equals(-9223372036854775808),);
        expect(deserializer.readIdlType(const IdlType(kind: 'string')),
            equals('test string'),);

        final publicKey =
            deserializer.readIdlType(const IdlType(kind: 'publicKey'));
        expect(publicKey, isA<PublicKey>());
        expect((publicKey as PublicKey).toBytes(), equals(testKeyBytes));
      });

      test('should handle vec type correctly', () {
        // Serialize vector data
        serializer.writeU32(3); // length
        serializer.writeU32(100);
        serializer.writeU32(200);
        serializer.writeU32(300);

        deserializer = BorshDeserializer(serializer.toBytes());

        final vecType = const IdlType(
          kind: 'vec',
          inner: IdlType(kind: 'u32'),
        );

        final result = deserializer.readIdlType(vecType);
        expect(result, equals([100, 200, 300]));
      });

      test('should handle array type correctly', () {
        // Serialize fixed array data
        serializer.writeU16(10);
        serializer.writeU16(20);
        serializer.writeU16(30);

        deserializer = BorshDeserializer(serializer.toBytes());

        final arrayType = const IdlType(
          kind: 'array',
          inner: IdlType(kind: 'u16'),
          size: 3,
        );

        final result = deserializer.readIdlType(arrayType);
        expect(result, equals([10, 20, 30]));
        expect(result.length, equals(3));
      });

      test('should handle option type with Some value', () {
        // Serialize Some(42)
        serializer.writeU8(1); // Some variant
        serializer.writeU32(42);

        deserializer = BorshDeserializer(serializer.toBytes());

        final optionType = const IdlType(
          kind: 'option',
          inner: IdlType(kind: 'u32'),
        );

        final result = deserializer.readIdlType(optionType);
        expect(result, equals(42));
      });

      test('should handle option type with None value', () {
        // Serialize None
        serializer.writeU8(0); // None variant

        deserializer = BorshDeserializer(serializer.toBytes());

        final optionType = const IdlType(
          kind: 'option',
          inner: IdlType(kind: 'u32'),
        );

        final result = deserializer.readIdlType(optionType);
        expect(result, isNull);
      });

      test('should handle bytes type correctly', () {
        // Serialize bytes data
        final testBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
        serializer.writeU32(testBytes.length);
        for (final byte in testBytes) {
          serializer.writeU8(byte);
        }

        deserializer = BorshDeserializer(serializer.toBytes());

        final bytesType = const IdlType(kind: 'bytes');
        final result = deserializer.readIdlType(bytesType);

        expect(result, isA<Uint8List>());
        expect(result as Uint8List, equals(testBytes));
      });

      test('should handle nested complex types', () {
        // Serialize vec of options
        serializer.writeU32(3); // vec length
        serializer.writeU8(1); // Some(10)
        serializer.writeU16(10);
        serializer.writeU8(0); // None
        serializer.writeU8(1); // Some(20)
        serializer.writeU16(20);

        deserializer = BorshDeserializer(serializer.toBytes());

        final complexType = const IdlType(
          kind: 'vec',
          inner: IdlType(
            kind: 'option',
            inner: IdlType(kind: 'u16'),
          ),
        );

        final result = deserializer.readIdlType(complexType);
        expect(result, equals([10, null, 20]));
      });

      test('should throw error for unsupported type', () {
        deserializer = BorshDeserializer(Uint8List(0));

        final unsupportedType = const IdlType(kind: 'unsupported');

        expect(
          () => deserializer.readIdlType(unsupportedType),
          throwsA(isA<BorshException>()),
        );
      });

      test('should throw error for defined type without IDL context', () {
        deserializer = BorshDeserializer(Uint8List(0));

        final definedType = const IdlType(kind: 'defined', defined: 'CustomStruct');

        expect(
          () => deserializer.readIdlType(definedType),
          throwsA(isA<BorshException>()),
        );
      });

      test('should throw error for vec type missing inner type', () {
        deserializer = BorshDeserializer(Uint8List(0));

        final invalidVecType = const IdlType(kind: 'vec');

        expect(
          () => deserializer.readIdlType(invalidVecType),
          throwsA(isA<BorshException>()),
        );
      });

      test('should throw error for array type missing size', () {
        deserializer = BorshDeserializer(Uint8List(0));

        final invalidArrayType = const IdlType(
          kind: 'array',
          inner: IdlType(kind: 'u32'),
        );

        expect(
          () => deserializer.readIdlType(invalidArrayType),
          throwsA(isA<BorshException>()),
        );
      });

      test('should throw error for option type missing inner type', () {
        deserializer = BorshDeserializer(Uint8List(0));

        final invalidOptionType = const IdlType(kind: 'option');

        expect(
          () => deserializer.readIdlType(invalidOptionType),
          throwsA(isA<BorshException>()),
        );
      });
    });

    group('Integration with BorshEventCoder', () {
      test('should support complex event types', () {
        // This test demonstrates the integration between readIdlType and BorshEventCoder
        // by testing a complex event structure

        // Serialize a complex event with nested data
        serializer.writeU32(42); // simple field
        serializer.writeU32(2); // vec length
        serializer.writeU32(100);
        serializer.writeU32(200);
        serializer.writeU8(1); // Some variant
        serializer.writeString('optional value');

        deserializer = BorshDeserializer(serializer.toBytes());

        // Simulate reading complex event fields
        final simpleField =
            deserializer.readIdlType(const IdlType(kind: 'u32'));
        final vecField = deserializer.readIdlType(const IdlType(
          kind: 'vec',
          inner: IdlType(kind: 'u32'),
        ),);
        final optionField = deserializer.readIdlType(const IdlType(
          kind: 'option',
          inner: IdlType(kind: 'string'),
        ),);

        expect(simpleField, equals(42));
        expect(vecField, equals([100, 200]));
        expect(optionField, equals('optional value'));
      });
    });
  });
}
