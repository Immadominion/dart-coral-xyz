import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Test account data structure
class TestAccount implements BorshSerializable {
  final int value;
  final String name;
  final PublicKey owner;

  const TestAccount({
    required this.value,
    required this.name,
    required this.owner,
  });

  @override
  Uint8List serialize() {
    final serializer = BorshSerializer();
    serializer.writeU32(value);
    serializer.writeString(name);
    BorshUtils.writePublicKey(serializer, owner.bytes);
    return serializer.toBytes();
  }

  @override
  int get serializedSize =>
      4 + BorshUtils.stringSize(name) + BorshUtils.publicKeySize;

  // Factory method for deserialization
  static TestAccount deserialize(BorshDeserializer deserializer) {
    final value = deserializer.readU32();
    final name = deserializer.readString();
    final ownerBytes = BorshUtils.readPublicKey(deserializer);
    final owner = PublicKey.fromBytes(ownerBytes);

    return TestAccount(value: value, name: name, owner: owner);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestAccount &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          name == other.name &&
          owner == other.owner;

  @override
  int get hashCode => value.hashCode ^ name.hashCode ^ owner.hashCode;
}

void main() {
  group('Anchor-Specific Borsh Extensions', () {
    late PublicKey testPublicKey;
    late TestAccount testAccount;

    setUp(() {
      // Create a test PublicKey (32 bytes of incrementing values)
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));
      testPublicKey = PublicKey.fromBytes(keyBytes);

      testAccount = TestAccount(
        value: 42,
        name: 'test',
        owner: testPublicKey,
      );
    });

    group('AnchorBorsh Account Serialization', () {
      test('should serialize account with discriminator', () {
        const accountName = 'TestAccount';
        final serialized =
            AnchorBorsh.serializeAccount(accountName, testAccount);

        // Should start with 8-byte discriminator
        expect(serialized.length, greaterThan(8));

        // Verify discriminator matches expected
        final expectedDiscriminator =
            BorshUtils.createAccountDiscriminator(accountName);
        final actualDiscriminator = serialized.sublist(0, 8);
        expect(actualDiscriminator, equals(expectedDiscriminator));
      });

      test('should deserialize account with discriminator verification', () {
        const accountName = 'TestAccount';
        final serialized =
            AnchorBorsh.serializeAccount(accountName, testAccount);

        final deserialized = AnchorBorsh.deserializeAccount<TestAccount>(
          accountName,
          serialized,
          TestAccount.deserialize,
        );

        expect(deserialized, equals(testAccount));
      });

      test('should throw on discriminator mismatch for accounts', () {
        const accountName = 'TestAccount';
        const wrongAccountName = 'WrongAccount';
        final serialized =
            AnchorBorsh.serializeAccount(accountName, testAccount);

        expect(
          () => AnchorBorsh.deserializeAccount<TestAccount>(
            wrongAccountName,
            serialized,
            TestAccount.deserialize,
          ),
          throwsA(isA<BorshException>()),
        );
      });
    });

    group('AnchorBorsh Instruction Serialization', () {
      test('should serialize instruction with discriminator', () {
        const instructionName = 'initialize';
        final serialized = AnchorBorsh.serializeInstruction(
          instructionName,
          (serializer) {
            serializer.writeU32(100);
            serializer.writeString('init');
          },
        );

        // Should start with 8-byte discriminator
        expect(
            serialized.length,
            equals(
                8 + 4 + 4 + 4)); // discriminator + u32 + string length + string

        // Verify discriminator
        final expectedDiscriminator =
            BorshUtils.createInstructionDiscriminator(instructionName);
        final actualDiscriminator = serialized.sublist(0, 8);
        expect(actualDiscriminator, equals(expectedDiscriminator));
      });

      test('should deserialize instruction with discriminator verification',
          () {
        const instructionName = 'initialize';
        final serialized = AnchorBorsh.serializeInstruction(
          instructionName,
          (serializer) {
            serializer.writeU32(100);
            serializer.writeString('init');
          },
        );

        final result = AnchorBorsh.deserializeInstruction<Map<String, dynamic>>(
          instructionName,
          serialized,
          (deserializer) {
            final value = deserializer.readU32();
            final name = deserializer.readString();
            return {'value': value, 'name': name};
          },
        );

        expect(result['value'], equals(100));
        expect(result['name'], equals('init'));
      });

      test('should throw on discriminator mismatch for instructions', () {
        const instructionName = 'initialize';
        const wrongInstructionName = 'update';
        final serialized = AnchorBorsh.serializeInstruction(
          instructionName,
          (serializer) => serializer.writeU32(100),
        );

        expect(
          () => AnchorBorsh.deserializeInstruction<int>(
            wrongInstructionName,
            serialized,
            (deserializer) => deserializer.readU32(),
          ),
          throwsA(isA<BorshException>()),
        );
      });
    });

    group('PublicKey Borsh Serialization', () {
      test('should serialize PublicKey correctly', () {
        final serialized = AnchorBorsh.serializePublicKey(testPublicKey);

        expect(serialized.length, equals(32));
        expect(serialized, equals(testPublicKey.bytes));
      });

      test('should deserialize PublicKey correctly', () {
        final serialized = AnchorBorsh.serializePublicKey(testPublicKey);
        final deserialized = AnchorBorsh.deserializePublicKey(serialized);

        expect(deserialized, equals(testPublicKey));
      });

      test('should use PublicKey extension method', () {
        final serialized = testPublicKey.serializeBorsh();

        expect(serialized.length, equals(32));
        expect(serialized, equals(testPublicKey.bytes));
      });
    });

    group('Event Serialization', () {
      test('should serialize event with discriminator', () {
        const eventName = 'MyEvent';
        final serialized = AnchorBorsh.serializeEvent(
          eventName,
          (serializer) {
            serializer.writeString('event data');
            serializer.writeU32(123);
          },
        );

        // Should start with 8-byte discriminator
        expect(serialized.length, greaterThan(8));

        // Verify event discriminator format
        final deserializer = BorshDeserializer(serialized);
        final discriminator = deserializer.readDiscriminator();
        expect(discriminator.length, equals(8));
      });
    });

    group('Custom Discriminators', () {
      test('should create custom discriminators', () {
        final disc1 = AnchorBorsh.createCustomDiscriminator('custom', 'MyType');
        final disc2 = AnchorBorsh.createCustomDiscriminator('custom', 'MyType');
        final disc3 =
            AnchorBorsh.createCustomDiscriminator('custom', 'OtherType');

        expect(disc1.length, equals(8));
        expect(disc1, equals(disc2)); // Same input should produce same output
        expect(
            disc1,
            isNot(equals(
                disc3))); // Different input should produce different output
      });
    });

    group('Extension Methods', () {
      test('should use serializer extension methods', () {
        final serializer = BorshSerializer();

        serializer.writeAccountDiscriminator('TestAccount');
        serializer.writePublicKeyObject(testPublicKey);
        serializer.writeInstructionDiscriminator('initialize');

        final result = serializer.toBytes();
        expect(result.length,
            equals(8 + 32 + 8)); // account disc + pubkey + instruction disc
      });

      test('should use deserializer extension methods', () {
        final serializer = BorshSerializer();
        serializer.writeAccountDiscriminator('TestAccount');
        serializer.writePublicKeyObject(testPublicKey);

        final data = serializer.toBytes();

        // Test correct discriminator verification
        final deserializer1 = BorshDeserializer(data);
        expect(deserializer1.verifyAccountDiscriminator('TestAccount'), isTrue);
        final publicKey1 = deserializer1.readPublicKeyObject();
        expect(publicKey1, equals(testPublicKey));

        // Test incorrect discriminator verification with fresh deserializer
        final deserializer2 = BorshDeserializer(data);
        expect(
            deserializer2.verifyAccountDiscriminator('WrongAccount'), isFalse);
      });
    });

    group('Complex Integration', () {
      test('should handle complete Anchor account workflow', () {
        const accountName = 'ComplexAccount';

        // Create a more complex account
        final complexAccount = TestAccount(
          value: 999,
          name: 'complex test account',
          owner: testPublicKey,
        );

        // Serialize with discriminator
        final serialized =
            AnchorBorsh.serializeAccount(accountName, complexAccount);

        // Verify structure
        expect(serialized.length, greaterThan(8)); // At least discriminator

        // Deserialize and verify
        final deserialized = AnchorBorsh.deserializeAccount<TestAccount>(
          accountName,
          serialized,
          TestAccount.deserialize,
        );

        expect(deserialized.value, equals(999));
        expect(deserialized.name, equals('complex test account'));
        expect(deserialized.owner, equals(testPublicKey));
      });
    });
  });
}
