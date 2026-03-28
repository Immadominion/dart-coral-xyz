/// T5 — Robustness & Edge Cases
///
/// Tests error handling, data edge cases, and concurrent operations.
///
/// Run: dart test test/component/robustness_test.dart
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:coral_xyz/src/coder/borsh_types.dart';
import 'package:coral_xyz/src/coder/discriminator_computer.dart';
import 'package:coral_xyz/src/coder/instruction_coder.dart';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/program/program_interface.dart';
import 'package:test/test.dart';

void main() {
  // ─── T5.1 — Error Paths ────────────────────────────────────────────────────

  group('T5.1 — Error paths', () {
    test('Idl.fromJson with empty object throws on missing instructions', () {
      expect(() => Idl.fromJson(<String, dynamic>{}), throwsA(anything));
    });

    test('Idl.fromJson with missing required fields throws', () {
      expect(() => Idl.fromJson({'foo': 'bar'}), throwsA(anything));
    });

    test('DiscriminatorComputer with empty name throws ArgumentError', () {
      expect(
        () => DiscriminatorComputer.computeInstructionDiscriminator(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DiscriminatorComputer.computeAccountDiscriminator(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DiscriminatorComputer.computeEventDiscriminator(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BorshSerializer writeU8 out of range throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeU8(-1), throwsA(isA<BorshException>()));
      expect(() => s.writeU8(256), throwsA(isA<BorshException>()));
    });

    test('BorshSerializer writeI8 out of range throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeI8(-129), throwsA(isA<BorshException>()));
      expect(() => s.writeI8(128), throwsA(isA<BorshException>()));
    });

    test('BorshSerializer writeU16 out of range throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeU16(-1), throwsA(isA<BorshException>()));
      expect(() => s.writeU16(65536), throwsA(isA<BorshException>()));
    });

    test('BorshSerializer writeI16 out of range throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeI16(-32769), throwsA(isA<BorshException>()));
      expect(() => s.writeI16(32768), throwsA(isA<BorshException>()));
    });

    test('BorshSerializer writeU32 out of range throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeU32(-1), throwsA(isA<BorshException>()));
    });

    test('BorshSerializer writeI32 out of range throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeI32(-2147483649), throwsA(isA<BorshException>()));
      expect(() => s.writeI32(2147483648), throwsA(isA<BorshException>()));
    });

    test('BorshSerializer writeU64 negative int throws BorshException', () {
      final s = BorshSerializer();
      expect(() => s.writeU64(-1), throwsA(isA<BorshException>()));
    });

    test(
      'BorshSerializer writeU64 BigInt out of range throws BorshException',
      () {
        final s = BorshSerializer();
        expect(
          () => s.writeU64(BigInt.from(-1)),
          throwsA(isA<BorshException>()),
        );
        expect(
          () => s.writeU64(BigInt.two.pow(64)),
          throwsA(isA<BorshException>()),
        );
      },
    );

    test('BorshInstructionCoder encode with unknown instruction throws', () {
      final idl = _buildMinimalIdl();
      final coder = BorshInstructionCoder(idl);
      expect(
        () => coder.encode('nonexistent_instruction', {}),
        throwsA(anything),
      );
    });

    test('BorshInstructionCoder encode with missing arg throws', () {
      final idl = _buildIdlWithArgs();
      final coder = BorshInstructionCoder(idl);
      expect(
        () => coder.encode('do_thing', {}), // missing required 'amount'
        throwsA(anything),
      );
    });

    test('BorshDeserializer readU8 on empty data throws', () {
      final d = BorshDeserializer(Uint8List(0));
      expect(() => d.readU8(), throwsA(anything));
    });

    test('BorshDeserializer readU64 on insufficient data throws', () {
      final d = BorshDeserializer(Uint8List(4)); // need 8 bytes, only 4
      expect(() => d.readU64(), throwsA(anything));
    });

    test('BorshDeserializer readString on insufficient data throws', () {
      // String header says 100 bytes but only 2 bytes available
      final data = Uint8List.fromList([
        100, 0, 0, 0, // string length = 100
        65, 66, // only 2 bytes of actual data
      ]);
      final d = BorshDeserializer(data);
      expect(() => d.readString(), throwsA(anything));
    });
  });

  // ─── T5.2 — Data Edge Cases ────────────────────────────────────────────────

  group('T5.2 — Data edge cases', () {
    test('Borsh u8 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeU8(0);
      s.writeU8(255);
      final bytes = s.toBytes();
      expect(bytes, equals(Uint8List.fromList([0, 255])));

      final d = BorshDeserializer(bytes);
      expect(d.readU8(), equals(0));
      expect(d.readU8(), equals(255));
    });

    test('Borsh i8 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeI8(-128);
      s.writeI8(127);
      s.writeI8(0);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readI8(), equals(-128));
      expect(d.readI8(), equals(127));
      expect(d.readI8(), equals(0));
    });

    test('Borsh u16 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeU16(0);
      s.writeU16(65535);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readU16(), equals(0));
      expect(d.readU16(), equals(65535));
    });

    test('Borsh u32 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeU32(0);
      s.writeU32(4294967295);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readU32(), equals(0));
      expect(d.readU32(), equals(4294967295));
    });

    test('Borsh u64 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeU64(0);
      s.writeU64(9223372036854775807); // max Dart int
      final bytes = s.toBytes();
      expect(bytes.length, equals(16)); // 2 × 8 bytes

      final d = BorshDeserializer(bytes);
      expect(d.readU64(), equals(0));
      expect(d.readU64(), equals(9223372036854775807));
    });

    test('Borsh u64 MAX via BigInt', () {
      final s = BorshSerializer();
      final maxU64 = BigInt.parse('18446744073709551615');
      s.writeU64(maxU64);
      final bytes = s.toBytes();
      expect(bytes, equals(Uint8List.fromList(List.filled(8, 0xFF))));
    });

    test('Borsh i32 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeI32(-2147483648);
      s.writeI32(2147483647);
      s.writeI32(0);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readI32(), equals(-2147483648));
      expect(d.readI32(), equals(2147483647));
      expect(d.readI32(), equals(0));
    });

    test('Borsh i64 boundary values round-trip', () {
      final s = BorshSerializer();
      s.writeI64(-9223372036854775808);
      s.writeI64(9223372036854775807);
      s.writeI64(0);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readI64(), equals(-9223372036854775808));
      expect(d.readI64(), equals(9223372036854775807));
      expect(d.readI64(), equals(0));
    });

    test('Borsh bool round-trip', () {
      final s = BorshSerializer();
      s.writeBool(true);
      s.writeBool(false);
      final bytes = s.toBytes();
      expect(bytes, equals(Uint8List.fromList([1, 0])));

      final d = BorshDeserializer(bytes);
      expect(d.readBool(), isTrue);
      expect(d.readBool(), isFalse);
    });

    test('Borsh empty string round-trip', () {
      final s = BorshSerializer();
      s.writeString('');
      final bytes = s.toBytes();
      // 4-byte length (0) + no data
      expect(bytes, equals(Uint8List.fromList([0, 0, 0, 0])));

      final d = BorshDeserializer(bytes);
      expect(d.readString(), equals(''));
    });

    test('Borsh large string (1KB) round-trip', () {
      final bigString = 'A' * 1024;
      final s = BorshSerializer();
      s.writeString(bigString);
      final bytes = s.toBytes();
      // 4-byte length + 1024 bytes
      expect(bytes.length, equals(1028));

      final d = BorshDeserializer(bytes);
      expect(d.readString(), equals(bigString));
    });

    test('Borsh unicode string round-trip', () {
      const unicodeStr = '日本語テスト 🎉';
      final s = BorshSerializer();
      s.writeString(unicodeStr);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readString(), equals(unicodeStr));
    });

    test('Borsh empty fixedArray round-trip', () {
      final s = BorshSerializer();
      s.writeFixedArray(Uint8List(0));
      final bytes = s.toBytes();
      expect(bytes, isEmpty);
    });

    test('Borsh option None via writeOption', () {
      final s = BorshSerializer();
      s.writeOption<int>(null, s.writeU32);
      final bytes = s.toBytes();
      expect(bytes, equals(Uint8List.fromList([0])));
    });

    test('Borsh option Some via writeOption', () {
      final s = BorshSerializer();
      s.writeOption<int>(42, s.writeU32);
      final bytes = s.toBytes();
      // 1-byte flag (1) + 4-byte u32 (42)
      expect(bytes, equals(Uint8List.fromList([1, 42, 0, 0, 0])));
    });

    test('Borsh option round-trip', () {
      final s = BorshSerializer();
      s.writeOption<int>(12345, s.writeU32);
      s.writeOption<int>(null, s.writeU32);
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readOption(d.readU32), equals(12345));
      expect(d.readOption(d.readU32), isNull);
    });

    test('Borsh array round-trip', () {
      final s = BorshSerializer();
      s.writeArray<int>([10, 20, 30], s.writeU8);
      final bytes = s.toBytes();
      // 4-byte length (3) + 3 × 1-byte u8
      expect(bytes.length, equals(7));

      final d = BorshDeserializer(bytes);
      final list = d.readArray(d.readU8);
      expect(list, equals([10, 20, 30]));
    });

    test('Borsh empty array round-trip', () {
      final s = BorshSerializer();
      s.writeArray<int>([], s.writeU8);
      final bytes = s.toBytes();
      // 4-byte length (0)
      expect(bytes, equals(Uint8List.fromList([0, 0, 0, 0])));

      final d = BorshDeserializer(bytes);
      final list = d.readArray(d.readU8);
      expect(list, isEmpty);
    });

    test('Discriminator is always 8 bytes', () {
      final disc1 = DiscriminatorComputer.computeInstructionDiscriminator('a');
      expect(disc1.length, equals(8));

      final disc2 = DiscriminatorComputer.computeInstructionDiscriminator(
        'a' * 10000,
      );
      expect(disc2.length, equals(8));
    });

    test('Discriminator is deterministic', () {
      final d1 = DiscriminatorComputer.computeInstructionDiscriminator('test');
      final d2 = DiscriminatorComputer.computeInstructionDiscriminator('test');
      expect(d1, equals(d2));
    });

    test('Different names produce different discriminators', () {
      final d1 = DiscriminatorComputer.computeInstructionDiscriminator('foo');
      final d2 = DiscriminatorComputer.computeInstructionDiscriminator('bar');
      expect(d1, isNot(equals(d2)));
    });

    test('Different prefixes produce different discriminators', () {
      final instrDisc = DiscriminatorComputer.computeInstructionDiscriminator(
        'test',
      );
      final accountDisc = DiscriminatorComputer.computeAccountDiscriminator(
        'test',
      );
      final eventDisc = DiscriminatorComputer.computeEventDiscriminator('test');
      expect(instrDisc, isNot(equals(accountDisc)));
      expect(instrDisc, isNot(equals(eventDisc)));
      expect(accountDisc, isNot(equals(eventDisc)));
    });

    test('BorshSerializer multiple types in sequence round-trip', () {
      final s = BorshSerializer();
      s.writeBool(true);
      s.writeU8(255);
      s.writeU16(1000);
      s.writeU32(100000);
      s.writeU64(BigInt.from(1000000000000));
      s.writeI8(-42);
      s.writeI32(-100000);
      s.writeString('hello');
      final bytes = s.toBytes();

      final d = BorshDeserializer(bytes);
      expect(d.readBool(), isTrue);
      expect(d.readU8(), equals(255));
      expect(d.readU16(), equals(1000));
      expect(d.readU32(), equals(100000));
      expect(d.readU64(), equals(1000000000000));
      expect(d.readI8(), equals(-42));
      expect(d.readI32(), equals(-100000));
      expect(d.readString(), equals('hello'));
    });

    test('Borsh f32 round-trip', () {
      final s = BorshSerializer();
      s.writeF32(3.140000104904175); // f32 precision
      s.writeF32(0.0);
      s.writeF32(-1.0);
      final bytes = s.toBytes();
      expect(bytes.length, equals(12)); // 3 × 4 bytes

      final d = BorshDeserializer(bytes);
      expect(d.readF32(), closeTo(3.14, 0.001));
      expect(d.readF32(), equals(0.0));
      expect(d.readF32(), equals(-1.0));
    });

    test('Borsh f64 round-trip', () {
      final s = BorshSerializer();
      s.writeF64(3.141592653589793);
      s.writeF64(0.0);
      s.writeF64(-1e100);
      final bytes = s.toBytes();
      expect(bytes.length, equals(24)); // 3 × 8 bytes

      final d = BorshDeserializer(bytes);
      expect(d.readF64(), equals(3.141592653589793));
      expect(d.readF64(), equals(0.0));
      expect(d.readF64(), equals(-1e100));
    });
  });

  // ─── T5.3 — IDL & Instruction Coder Edge Cases ────────────────────────────

  group('T5.3 — IDL & instruction coder edge cases', () {
    test('ProgramInterface.define builds valid Idl with only name', () {
      final idl = ProgramInterface.define(name: 'my_program').build();
      expect(idl, isNotNull);
      expect(idl.name, equals('my_program'));
    });

    test('ProgramInterface with no-arg instruction', () {
      final idl = ProgramInterface.define(
        name: 'test_prog',
      ).instruction('do_nothing').done().build();
      final ix = idl.instructions.firstWhere((i) => i.name == 'do_nothing');
      expect(ix.args, isEmpty);
    });

    test('ProgramInterface with multiple instruction args', () {
      final idl = ProgramInterface.define(name: 'test_prog')
          .instruction('complex_ix')
          .arg('a', 'u8')
          .arg('b', 'u64')
          .arg('c', 'string')
          .arg('d', 'bool')
          .done()
          .build();
      final ix = idl.instructions.firstWhere((i) => i.name == 'complex_ix');
      expect(ix.args.length, equals(4));
    });

    test('Instruction coder encode → decode round-trip', () {
      final idl = _buildIdlWithAllPrimitiveArgs();
      final coder = BorshInstructionCoder(idl);

      final encoded = coder.encode('all_types', {
        'a_bool': true,
        'a_u8': 42,
        'a_u16': 1000,
        'a_u32': 100000,
        'a_u64': 1000000000000,
        'a_i8': -42,
        'a_i16': -1000,
        'a_i32': -100000,
        'a_string': 'test',
      });
      expect(encoded, isNotNull);
      expect(encoded.length, greaterThan(8)); // At least discriminator

      // Decode and verify
      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('all_types'));
      expect(decoded.data['a_bool'], isTrue);
      expect(decoded.data['a_u8'], equals(42));
      expect(decoded.data['a_u16'], equals(1000));
      expect(decoded.data['a_u32'], equals(100000));
      expect(decoded.data['a_u64'], equals(1000000000000));
      expect(decoded.data['a_i8'], equals(-42));
      expect(decoded.data['a_i16'], equals(-1000));
      expect(decoded.data['a_i32'], equals(-100000));
      expect(decoded.data['a_string'], equals('test'));
    });

    test('Instruction coder decode returns null for unknown discriminator', () {
      final idl = _buildMinimalIdl();
      final coder = BorshInstructionCoder(idl);
      // 8 bytes of zeros — unlikely to match any instruction
      final decoded = coder.decode(Uint8List(8));
      expect(decoded, isNull);
    });

    test('Idl.fromJson with valid minimal JSON succeeds', () {
      final idl = Idl.fromJson({
        'instructions': [
          {
            'name': 'init',
            'args': <Map<String, dynamic>>[],
            'accounts': <Map<String, dynamic>>[],
          },
        ],
      });
      expect(idl.instructions.length, equals(1));
      expect(idl.instructions.first.name, equals('init'));
    });

    test('Idl.fromJson preserves metadata', () {
      final idl = Idl.fromJson({
        'metadata': {'name': 'my_prog', 'version': '0.5.0', 'spec': '0.1.0'},
        'instructions': <Map<String, dynamic>>[],
      });
      expect(idl.metadata?.name, equals('my_prog'));
      expect(idl.metadata?.version, equals('0.5.0'));
    });

    test('Idl constructor with empty instructions list', () {
      final idl = Idl(instructions: []);
      expect(idl.instructions, isEmpty);
      expect(idl.accounts, isNull);
      expect(idl.events, isNull);
      expect(idl.errors, isNull);
    });

    test('BorshSerializer clear resets buffer', () {
      final s = BorshSerializer();
      s.writeU8(42);
      s.writeU32(99);
      expect(s.toBytes().length, equals(5));
      s.clear();
      expect(s.toBytes().length, equals(0));
    });
  });
}

// ─── Test Helpers ──────────────────────────────────────────────────────────

Idl _buildMinimalIdl() {
  return Idl(
    instructions: [
      IdlInstruction(
        name: 'init',
        discriminator: DiscriminatorComputer.computeInstructionDiscriminator(
          'init',
        ).toList(),
        args: [],
        accounts: [],
      ),
    ],
  );
}

Idl _buildIdlWithArgs() {
  return Idl(
    instructions: [
      IdlInstruction(
        name: 'do_thing',
        discriminator: DiscriminatorComputer.computeInstructionDiscriminator(
          'do_thing',
        ).toList(),
        args: [
          IdlField(
            name: 'amount',
            type: IdlType(kind: 'u64'),
          ),
        ],
        accounts: [],
      ),
    ],
  );
}

Idl _buildIdlWithAllPrimitiveArgs() {
  return Idl(
    instructions: [
      IdlInstruction(
        name: 'all_types',
        discriminator: DiscriminatorComputer.computeInstructionDiscriminator(
          'all_types',
        ).toList(),
        args: [
          IdlField(
            name: 'a_bool',
            type: IdlType(kind: 'bool'),
          ),
          IdlField(
            name: 'a_u8',
            type: IdlType(kind: 'u8'),
          ),
          IdlField(
            name: 'a_u16',
            type: IdlType(kind: 'u16'),
          ),
          IdlField(
            name: 'a_u32',
            type: IdlType(kind: 'u32'),
          ),
          IdlField(
            name: 'a_u64',
            type: IdlType(kind: 'u64'),
          ),
          IdlField(
            name: 'a_i8',
            type: IdlType(kind: 'i8'),
          ),
          IdlField(
            name: 'a_i16',
            type: IdlType(kind: 'i16'),
          ),
          IdlField(
            name: 'a_i32',
            type: IdlType(kind: 'i32'),
          ),
          IdlField(
            name: 'a_string',
            type: IdlType(kind: 'string'),
          ),
        ],
        accounts: [],
      ),
    ],
  );
}
