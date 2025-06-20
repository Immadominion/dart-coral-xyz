import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Borsh Serialization System', () {
    group('BorshSerializer Basic Types', () {
      test('should serialize u8 correctly', () {
        final serializer = BorshSerializer();
        serializer.writeU8(42);
        serializer.writeU8(255);
        serializer.writeU8(0);

        final result = serializer.toBytes();
        expect(result, equals([42, 255, 0]));
      });

      test('should throw on invalid u8 values', () {
        final serializer = BorshSerializer();

        expect(() => serializer.writeU8(-1), throwsA(isA<BorshException>()));
        expect(() => serializer.writeU8(256), throwsA(isA<BorshException>()));
      });

      test('should serialize u16 correctly (little endian)', () {
        final serializer = BorshSerializer();
        serializer.writeU16(0x1234); // Should be [0x34, 0x12]
        serializer.writeU16(65535); // Should be [0xFF, 0xFF]
        serializer.writeU16(0); // Should be [0x00, 0x00]

        final result = serializer.toBytes();
        expect(result, equals([0x34, 0x12, 0xFF, 0xFF, 0x00, 0x00]));
      });

      test('should serialize u32 correctly (little endian)', () {
        final serializer = BorshSerializer();
        serializer.writeU32(0x12345678); // Should be [0x78, 0x56, 0x34, 0x12]

        final result = serializer.toBytes();
        expect(result, equals([0x78, 0x56, 0x34, 0x12]));
      });

      test('should serialize bool correctly', () {
        final serializer = BorshSerializer();
        serializer.writeBool(true);
        serializer.writeBool(false);

        final result = serializer.toBytes();
        expect(result, equals([1, 0]));
      });

      test('should serialize string correctly', () {
        final serializer = BorshSerializer();
        serializer.writeString('hello');

        final result = serializer.toBytes();
        // Length (5) as u32 little endian + UTF-8 bytes
        expect(result, equals([5, 0, 0, 0, 104, 101, 108, 108, 111]));
      });

      test('should serialize fixed array correctly', () {
        final serializer = BorshSerializer();
        final data = Uint8List.fromList([1, 2, 3, 4]);
        serializer.writeFixedArray(data);

        final result = serializer.toBytes();
        expect(result, equals([1, 2, 3, 4]));
      });

      test('should serialize array correctly', () {
        final serializer = BorshSerializer();
        serializer.writeArray([1, 2, 3], (item) => serializer.writeU8(item));

        final result = serializer.toBytes();
        // Length (3) as u32 little endian + items
        expect(result, equals([3, 0, 0, 0, 1, 2, 3]));
      });

      test('should serialize option correctly', () {
        final serializer = BorshSerializer();

        // Some(42)
        serializer.writeOption(42, (value) => serializer.writeU8(value));
        // None
        serializer.writeOption<int>(null, (value) => serializer.writeU8(value));

        final result = serializer.toBytes();
        expect(result, equals([1, 42, 0])); // Some tag + value, None tag
      });
    });

    group('BorshDeserializer Basic Types', () {
      test('should deserialize u8 correctly', () {
        final data = Uint8List.fromList([42, 255, 0]);
        final deserializer = BorshDeserializer(data);

        expect(deserializer.readU8(), equals(42));
        expect(deserializer.readU8(), equals(255));
        expect(deserializer.readU8(), equals(0));
      });

      test('should deserialize u16 correctly (little endian)', () {
        final data = Uint8List.fromList([0x34, 0x12, 0xFF, 0xFF]);
        final deserializer = BorshDeserializer(data);

        expect(deserializer.readU16(), equals(0x1234));
        expect(deserializer.readU16(), equals(65535));
      });

      test('should deserialize u32 correctly (little endian)', () {
        final data = Uint8List.fromList([0x78, 0x56, 0x34, 0x12]);
        final deserializer = BorshDeserializer(data);

        expect(deserializer.readU32(), equals(0x12345678));
      });

      test('should deserialize bool correctly', () {
        final data = Uint8List.fromList([1, 0]);
        final deserializer = BorshDeserializer(data);

        expect(deserializer.readBool(), equals(true));
        expect(deserializer.readBool(), equals(false));
      });

      test('should throw on invalid bool values', () {
        final data = Uint8List.fromList([2]);
        final deserializer = BorshDeserializer(data);

        expect(() => deserializer.readBool(), throwsA(isA<BorshException>()));
      });

      test('should deserialize string correctly', () {
        final data = Uint8List.fromList([5, 0, 0, 0, 104, 101, 108, 108, 111]);
        final deserializer = BorshDeserializer(data);

        expect(deserializer.readString(), equals('hello'));
      });

      test('should deserialize fixed array correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final deserializer = BorshDeserializer(data);

        final result = deserializer.readFixedArray(4);
        expect(result, equals([1, 2, 3, 4]));
      });

      test('should deserialize array correctly', () {
        final data = Uint8List.fromList([3, 0, 0, 0, 1, 2, 3]);
        final deserializer = BorshDeserializer(data);

        final result = deserializer.readArray(() => deserializer.readU8());
        expect(result, equals([1, 2, 3]));
      });

      test('should deserialize option correctly', () {
        final data = Uint8List.fromList([1, 42, 0]);
        final deserializer = BorshDeserializer(data);

        final some = deserializer.readOption(() => deserializer.readU8());
        expect(some, equals(42));

        final none = deserializer.readOption(() => deserializer.readU8());
        expect(none, isNull);
      });

      test('should throw on insufficient data', () {
        final data = Uint8List.fromList([1]);
        final deserializer = BorshDeserializer(data);

        expect(() => deserializer.readU16(), throwsA(isA<BorshException>()));
        expect(() => deserializer.readU32(), throwsA(isA<BorshException>()));
        expect(() => deserializer.readFixedArray(5),
            throwsA(isA<BorshException>()));
      });
    });

    group('BorshUtils Anchor-specific', () {
      test('should create account discriminator correctly', () {
        final discriminator =
            BorshUtils.createAccountDiscriminator('MyAccount');

        expect(discriminator.length, equals(8));
        // The discriminator should be deterministic
        final discriminator2 =
            BorshUtils.createAccountDiscriminator('MyAccount');
        expect(discriminator, equals(discriminator2));

        // Different names should produce different discriminators
        final differentDiscriminator =
            BorshUtils.createAccountDiscriminator('OtherAccount');
        expect(discriminator, isNot(equals(differentDiscriminator)));
      });

      test('should create instruction discriminator correctly', () {
        final discriminator =
            BorshUtils.createInstructionDiscriminator('initialize');

        expect(discriminator.length, equals(8));
        // The discriminator should be deterministic
        final discriminator2 =
            BorshUtils.createInstructionDiscriminator('initialize');
        expect(discriminator, equals(discriminator2));

        // Different names should produce different discriminators
        final differentDiscriminator =
            BorshUtils.createInstructionDiscriminator('update');
        expect(discriminator, isNot(equals(differentDiscriminator)));
      });

      test('should serialize and deserialize PublicKey correctly', () {
        final serializer = BorshSerializer();
        final publicKey = Uint8List.fromList(List.generate(32, (i) => i));

        BorshUtils.writePublicKey(serializer, publicKey);
        final serialized = serializer.toBytes();
        expect(serialized.length, equals(32));

        final deserializer = BorshDeserializer(serialized);
        final deserialized = BorshUtils.readPublicKey(deserializer);
        expect(deserialized, equals(publicKey));
      });

      test('should throw on invalid PublicKey size', () {
        final serializer = BorshSerializer();
        final invalidKey = Uint8List.fromList([1, 2, 3]); // Wrong size

        expect(
          () => BorshUtils.writePublicKey(serializer, invalidKey),
          throwsA(isA<BorshException>()),
        );
      });
    });

    group('BorshWrapper Integration', () {
      test('should serialize basic types through wrapper', () {
        expect(BorshWrapper.serialize(42), equals([42]));
        expect(BorshWrapper.serialize(true), equals([1]));
        expect(BorshWrapper.serialize(false), equals([0]));
        expect(BorshWrapper.serialize('hi'), equals([2, 0, 0, 0, 104, 105]));
      });

      test('should create discriminators through wrapper', () {
        final accountDisc = BorshWrapper.createAccountDiscriminator('Test');
        final instructionDisc =
            BorshWrapper.createInstructionDiscriminator('test');

        expect(accountDisc.length, equals(8));
        expect(instructionDisc.length, equals(8));
        expect(accountDisc, isNot(equals(instructionDisc)));
      });

      test('should deserialize through wrapper', () {
        final data = Uint8List.fromList([42]);
        final result = BorshWrapper.deserialize<int>(
          data,
          (deserializer) => deserializer.readU8(),
        );
        expect(result, equals(42));
      });
    });

    group('Round-trip Serialization', () {
      test('should handle complex data structures', () {
        final serializer = BorshSerializer();

        // Create a complex structure
        serializer.writeString('test');
        serializer.writeU32(12345);
        serializer.writeArray([1, 2, 3], (item) => serializer.writeU8(item));
        serializer.writeBool(true);
        serializer.writeOption(
            'optional', (value) => serializer.writeString(value));

        final serialized = serializer.toBytes();

        // Deserialize it back
        final deserializer = BorshDeserializer(serialized);

        expect(deserializer.readString(), equals('test'));
        expect(deserializer.readU32(), equals(12345));
        expect(deserializer.readArray(() => deserializer.readU8()),
            equals([1, 2, 3]));
        expect(deserializer.readBool(), equals(true));
        expect(
          deserializer.readOption(() => deserializer.readString()),
          equals('optional'),
        );
      });
    });
  });
}
