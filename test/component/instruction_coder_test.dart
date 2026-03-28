/// T1.3 — BorshInstructionCoder Component Tests
///
/// Tests encode/decode round-trip for all supported primitive and complex types,
/// discriminator handling (IDL-provided and SHA256 fallback), error paths,
/// and defined type encoding (struct/enum).
///
/// Ground truth: binary output manually computed per Borsh spec (little-endian).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart';
import 'package:test/test.dart';

/// Minimal IDL with controlled instructions for focused testing.
Idl _buildTestIdl({
  List<Map<String, dynamic>>? instructions,
  List<Map<String, dynamic>>? types,
}) {
  final json = {
    'address': 'Test111111111111111111111111111111111111111',
    'metadata': {'name': 'test_program', 'version': '0.1.0', 'spec': '0.1.0'},
    'instructions': instructions ?? [],
    'accounts': <Map<String, dynamic>>[],
    'types': types ?? [],
    'events': <Map<String, dynamic>>[],
    'errors': <Map<String, dynamic>>[],
  };
  return Idl.fromJson(json);
}

/// Load the full Anchor IDL fixture.
Idl _loadFullIdl() {
  final file = File('test/fixtures/anchor_idl_full.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Idl.fromJson(json);
}

/// Load the old-format counter IDL fixture.
Idl _loadOldFormatIdl() {
  final file = File('test/fixtures/old_format_counter.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Idl.fromJson(json);
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. Construction
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Construction', () {
    test('constructs from full Anchor IDL', () {
      final idl = _loadFullIdl();
      final coder = BorshInstructionCoder(idl);
      // Should not throw — all 4 instructions loaded
      expect(coder, isNotNull);
    });

    test('constructs from old-format IDL', () {
      final idl = _loadOldFormatIdl();
      final coder = BorshInstructionCoder(idl);
      expect(coder, isNotNull);
    });

    test('constructs from empty instruction list', () {
      final idl = _buildTestIdl(instructions: []);
      final coder = BorshInstructionCoder(idl);
      expect(coder, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Discriminator handling
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Discriminator handling', () {
    test('uses discriminator from IDL when present', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'my_ix',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('my_ix', {});
      // Encoded should be exactly the 8-byte discriminator (no args).
      expect(encoded, equals(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])));
    });

    test('computes SHA256 discriminator when IDL has none', () {
      // Old-format "initialize" has no discriminator field.
      // SHA256("global:initialize") first 8 bytes = [175, 175, 109, 31, 13, 152, 155, 237]
      final idl = _loadOldFormatIdl();
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('initialize', {});
      final discriminator = encoded.sublist(0, 8);
      expect(
        discriminator,
        equals(Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237])),
      );
    });

    test('decode matches correct instruction by discriminator', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'ix_a',
            'discriminator': [10, 20, 30, 40, 50, 60, 70, 80],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
          {
            'name': 'ix_b',
            'discriminator': [11, 22, 33, 44, 55, 66, 77, 88],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);

      final resultA = coder.decode(
        Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]),
      );
      expect(resultA, isNotNull);
      expect(resultA!.name, equals('ix_a'));

      final resultB = coder.decode(
        Uint8List.fromList([11, 22, 33, 44, 55, 66, 77, 88]),
      );
      expect(resultB, isNotNull);
      expect(resultB!.name, equals('ix_b'));
    });

    test('decode returns null for unknown discriminator', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'ix_a',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final result = coder.decode(
        Uint8List.fromList([99, 99, 99, 99, 99, 99, 99, 99]),
      );
      expect(result, isNull);
    });

    test('decode returns null for data shorter than discriminator', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'ix_a',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      // Only 4 bytes — shorter than discriminator
      final result = coder.decode(Uint8List.fromList([1, 2, 3, 4]));
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. No-arg instruction encode/decode
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - No-arg instructions', () {
    test('encode produces only discriminator bytes', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'no_args',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('no_args', {});
      expect(encoded.length, equals(8));
      expect(encoded, equals(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])));
    });

    test('decode no-arg instruction returns empty data map', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'no_args',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final result = coder.decode(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(result, isNotNull);
      expect(result!.name, equals('no_args'));
      expect(result.data, isEmpty);
    });

    test('encode/decode round-trip for no-arg instruction', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'noop',
            'discriminator': [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('noop', {});
      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('noop'));
      expect(decoded.data, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Primitive type encode/decode round-trip
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Primitive types', () {
    late BorshInstructionCoder coder;

    setUp(() {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'test_bool',
            'discriminator': [1, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'bool'},
            ],
          },
          {
            'name': 'test_u8',
            'discriminator': [2, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'u8'},
            ],
          },
          {
            'name': 'test_i8',
            'discriminator': [3, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'i8'},
            ],
          },
          {
            'name': 'test_u16',
            'discriminator': [4, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'u16'},
            ],
          },
          {
            'name': 'test_i16',
            'discriminator': [5, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'i16'},
            ],
          },
          {
            'name': 'test_u32',
            'discriminator': [6, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'u32'},
            ],
          },
          {
            'name': 'test_i32',
            'discriminator': [7, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'i32'},
            ],
          },
          {
            'name': 'test_u64',
            'discriminator': [8, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'u64'},
            ],
          },
          {
            'name': 'test_i64',
            'discriminator': [9, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'i64'},
            ],
          },
          {
            'name': 'test_string',
            'discriminator': [10, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'string'},
            ],
          },
          {
            'name': 'test_pubkey',
            'discriminator': [11, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'pubkey'},
            ],
          },
        ],
      );
      coder = BorshInstructionCoder(idl);
    });

    test('bool true round-trip', () {
      final encoded = coder.encode('test_bool', {'val': true});
      expect(encoded.length, equals(9)); // 8 disc + 1 bool
      expect(encoded[8], equals(1));
      final decoded = coder.decode(encoded);
      expect(decoded!.name, equals('test_bool'));
      expect(decoded.data['val'], isTrue);
    });

    test('bool false round-trip', () {
      final encoded = coder.encode('test_bool', {'val': false});
      expect(encoded[8], equals(0));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], isFalse);
    });

    test('u8 round-trip', () {
      final encoded = coder.encode('test_u8', {'val': 42});
      expect(encoded.length, equals(9));
      expect(encoded[8], equals(42));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(42));
    });

    test('u8 boundary values', () {
      for (final v in [0, 255]) {
        final encoded = coder.encode('test_u8', {'val': v});
        final decoded = coder.decode(encoded);
        expect(decoded!.data['val'], equals(v));
      }
    });

    test('i8 round-trip positive', () {
      final encoded = coder.encode('test_i8', {'val': 100});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(100));
    });

    test('i8 round-trip negative', () {
      final encoded = coder.encode('test_i8', {'val': -5});
      // -5 as unsigned byte = 251
      expect(encoded[8], equals(251));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(-5));
    });

    test('u16 round-trip (little-endian)', () {
      final encoded = coder.encode('test_u16', {'val': 1000});
      // 1000 = 0x03E8 → LE: [0xE8, 0x03]
      expect(encoded[8], equals(0xE8));
      expect(encoded[9], equals(0x03));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(1000));
    });

    test('i16 round-trip negative', () {
      final encoded = coder.encode('test_i16', {'val': -100});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(-100));
    });

    test('u32 round-trip', () {
      final encoded = coder.encode('test_u32', {'val': 70000});
      // 70000 = 0x00011170 → LE: [0x70, 0x11, 0x01, 0x00]
      expect(encoded[8], equals(0x70));
      expect(encoded[9], equals(0x11));
      expect(encoded[10], equals(0x01));
      expect(encoded[11], equals(0x00));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(70000));
    });

    test('i32 round-trip negative', () {
      final encoded = coder.encode('test_i32', {'val': -1000});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(-1000));
    });

    test('u64 round-trip', () {
      final encoded = coder.encode('test_u64', {'val': 100000});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(100000));
    });

    test('u64 round-trip with BigInt', () {
      final encoded = coder.encode('test_u64', {'val': BigInt.from(99999)});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(99999));
    });

    test('i64 round-trip negative', () {
      final encoded = coder.encode('test_i64', {'val': -500});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(-500));
    });

    test('string round-trip', () {
      final encoded = coder.encode('test_string', {'val': 'hello'});
      // String: 4-byte length prefix (5) + 5 UTF-8 bytes
      // disc(8) + len(4) + "hello"(5) = 17 bytes
      expect(encoded.length, equals(17));
      // Length prefix: 5 in LE
      expect(encoded[8], equals(5));
      expect(encoded[9], equals(0));
      expect(encoded[10], equals(0));
      expect(encoded[11], equals(0));
      // 'h' = 0x68
      expect(encoded[12], equals(0x68));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals('hello'));
    });

    test('string empty round-trip', () {
      final encoded = coder.encode('test_string', {'val': ''});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(''));
    });

    test('pubkey round-trip', () {
      final pubkeyBytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        pubkeyBytes[i] = i;
      }
      final encoded = coder.encode('test_pubkey', {'val': pubkeyBytes});
      // disc(8) + pubkey(32) = 40 bytes
      expect(encoded.length, equals(40));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(pubkeyBytes));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Complex type encode/decode round-trip
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Complex types', () {
    late BorshInstructionCoder coder;

    setUp(() {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'test_vec',
            'discriminator': [20, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {'vec': 'u32'},
              },
            ],
          },
          {
            'name': 'test_option_some',
            'discriminator': [21, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {'option': 'u8'},
              },
            ],
          },
          {
            'name': 'test_array',
            'discriminator': [22, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {
                  'array': ['bool', 3],
                },
              },
            ],
          },
          {
            'name': 'test_nested_vec_option',
            'discriminator': [23, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {
                  'vec': {'option': 'u64'},
                },
              },
            ],
          },
        ],
      );
      coder = BorshInstructionCoder(idl);
    });

    test('vec<u32> round-trip', () {
      final encoded = coder.encode('test_vec', {
        'val': [10, 20, 30],
      });
      // disc(8) + count(4: LE 3) + 3 * u32(4) = 8+4+12 = 24
      expect(encoded.length, equals(24));
      // count = 3 LE
      expect(encoded[8], equals(3));
      expect(encoded[9], equals(0));
      expect(encoded[10], equals(0));
      expect(encoded[11], equals(0));
      // first element = 10 LE
      expect(encoded[12], equals(10));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals([10, 20, 30]));
    });

    test('vec<u32> empty round-trip', () {
      final encoded = coder.encode('test_vec', {'val': <int>[]});
      // disc(8) + count(4: 0) = 12
      expect(encoded.length, equals(12));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], isEmpty);
    });

    test('option<u8> Some round-trip', () {
      final encoded = coder.encode('test_option_some', {'val': 42});
      // disc(8) + tag(1: Some=1) + u8(1: 42) = 10
      expect(encoded.length, equals(10));
      expect(encoded[8], equals(1)); // Some
      expect(encoded[9], equals(42));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(42));
    });

    test('option<u8> None round-trip', () {
      final encoded = coder.encode('test_option_some', {'val': null});
      // disc(8) + tag(1: None=0) = 9
      expect(encoded.length, equals(9));
      expect(encoded[8], equals(0)); // None
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], isNull);
    });

    test('array<bool, 3> round-trip', () {
      final encoded = coder.encode('test_array', {
        'val': [true, false, true],
      });
      // disc(8) + 3 bools(3) = 11 (no length prefix for fixed array)
      expect(encoded.length, equals(11));
      expect(encoded[8], equals(1));
      expect(encoded[9], equals(0));
      expect(encoded[10], equals(1));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals([true, false, true]));
    });

    test('array length mismatch throws', () {
      expect(
        () => coder.encode('test_array', {
          'val': [true, false],
        }),
        throwsA(isA<InstructionCoderException>()),
      );
    });

    test('vec<option<u64>> nested round-trip', () {
      final encoded = coder.encode('test_nested_vec_option', {
        'val': [100, null, 200],
      });
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals([100, null, 200]));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Multi-arg instruction
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Multi-arg', () {
    test('encodes and decodes multiple args in order', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'multi',
            'discriminator': [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'flag', 'type': 'bool'},
              {'name': 'count', 'type': 'u32'},
              {'name': 'label', 'type': 'string'},
            ],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('multi', {
        'flag': true,
        'count': 42,
        'label': 'hi',
      });
      // disc(8) + bool(1) + u32(4) + string(4+2) = 19
      expect(encoded.length, equals(19));
      final decoded = coder.decode(encoded);
      expect(decoded!.name, equals('multi'));
      expect(decoded.data['flag'], isTrue);
      expect(decoded.data['count'], equals(42));
      expect(decoded.data['label'], equals('hi'));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Error handling
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Error handling', () {
    test('encode throws for unknown instruction name', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'known',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      expect(
        () => coder.encode('unknown_ix', {}),
        throwsA(isA<InstructionCoderException>()),
      );
    });

    test('encode throws for missing required arg', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'needs_arg',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'value', 'type': 'u32'},
            ],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      expect(
        () => coder.encode('needs_arg', {}),
        throwsA(isA<InstructionCoderException>()),
      );
    });

    test('decode returns null for empty data', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'ix',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final result = coder.decode(Uint8List(0));
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Full fixture IDL — real discriminators
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Full fixture IDL', () {
    late BorshInstructionCoder coder;

    setUp(() {
      final idl = _loadFullIdl();
      coder = BorshInstructionCoder(idl);
    });

    test('encode cause_error (no args) uses IDL discriminator', () {
      final encoded = coder.encode('cause_error', {});
      // IDL discriminator: [67, 104, 37, 17, 2, 155, 68, 17]
      expect(
        encoded,
        equals(Uint8List.fromList([67, 104, 37, 17, 2, 155, 68, 17])),
      );
    });

    test('decode cause_error by its discriminator', () {
      final data = Uint8List.fromList([67, 104, 37, 17, 2, 155, 68, 17]);
      final decoded = coder.decode(data);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('cause_error'));
      expect(decoded.data, isEmpty);
    });

    test('encode initialize (no args) uses IDL discriminator', () {
      final encoded = coder.encode('initialize', {});
      // IDL discriminator: [175, 175, 109, 31, 13, 152, 155, 237]
      expect(
        encoded,
        equals(Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237])),
      );
    });

    test('encode/decode round-trip for cause_error', () {
      final encoded = coder.encode('cause_error', {});
      final decoded = coder.decode(encoded);
      expect(decoded!.name, equals('cause_error'));
      expect(decoded.data, isEmpty);
    });

    test('encode/decode round-trip for initialize', () {
      final encoded = coder.encode('initialize', {});
      final decoded = coder.decode(encoded);
      expect(decoded!.name, equals('initialize'));
      expect(decoded.data, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Old-format IDL (SHA256 discriminator fallback)
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Old-format IDL', () {
    late BorshInstructionCoder coder;

    setUp(() {
      final idl = _loadOldFormatIdl();
      coder = BorshInstructionCoder(idl);
    });

    test('encode increment with u64 arg', () {
      final encoded = coder.encode('increment', {'amount': 5});
      // SHA256("global:increment") first 8 bytes = discriminator
      // then u64 LE of 5
      expect(encoded.length, equals(16)); // 8 disc + 8 u64
    });

    test('encode/decode round-trip for increment with u64', () {
      final encoded = coder.encode('increment', {'amount': 42});
      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('increment'));
      expect(decoded.data['amount'], equals(42));
    });

    test('encode/decode round-trip for initialize (no args)', () {
      final encoded = coder.encode('initialize', {});
      final decoded = coder.decode(encoded);
      expect(decoded!.name, equals('initialize'));
      expect(decoded.data, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. camelCase → snake_case conversion for discriminator fallback
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - camelCase conversion', () {
    test('camelCase instruction name uses snake_case for discriminator', () {
      // If old-format IDL has "initializeMyAccount", the coder should compute
      // SHA256("global:initialize_my_account"). We can verify by comparing
      // with manually known DiscriminatorComputer output.
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'initializeMyAccount',
            // No discriminator — forces fallback computation
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('initializeMyAccount', {});
      // Compare with DiscriminatorComputer directly
      final expected = DiscriminatorComputer.computeInstructionDiscriminator(
        'initialize_my_account',
      );
      expect(encoded.sublist(0, 8), equals(expected));
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Encode binary output verification (byte-level)
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Binary output verification', () {
    test('multi-arg instruction binary layout matches Borsh spec', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'bin_test',
            'discriminator': [0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'a', 'type': 'u8'},
              {'name': 'b', 'type': 'u16'},
              {'name': 'c', 'type': 'bool'},
            ],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('bin_test', {
        'a': 0xAB,
        'b': 0x1234,
        'c': true,
      });
      // Layout: disc(8) + u8(1) + u16(2 LE) + bool(1)
      expect(
        encoded,
        equals(
          Uint8List.fromList([
            // discriminator
            0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00,
            // u8 = 0xAB
            0xAB,
            // u16 = 0x1234 LE
            0x34, 0x12,
            // bool = true
            1,
          ]),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 12. Defined type encoding
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - Defined type encoding', () {
    test('struct defined type encodes and decodes', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'struct_arg',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {
                  'defined': {'name': 'SomeStruct'},
                },
              },
            ],
          },
        ],
        types: [
          {
            'name': 'SomeStruct',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'x', 'type': 'u32'},
              ],
            },
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('struct_arg', {
        'val': {'x': 1},
      });
      // 8 bytes discriminator + 4 bytes u32
      expect(encoded.length, equals(12));
      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('struct_arg'));
      expect((decoded.data['val'] as Map)['x'], equals(1));
    });

    test('enum defined type encodes and decodes', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'enum_arg',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {
                  'defined': {'name': 'SomeEnum'},
                },
              },
            ],
          },
        ],
        types: [
          {
            'name': 'SomeEnum',
            'type': {
              'kind': 'enum',
              'variants': [
                {'name': 'A'},
                {'name': 'B'},
              ],
            },
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('enum_arg', {
        'val': {'B': {}},
      });
      // 8 bytes discriminator + 1 byte enum variant index
      expect(encoded.length, equals(9));
      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('enum_arg'));
      expect(decoded.data['val'], equals({'B': {}}));
    });

    test('type alias resolves correctly', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'alias_arg',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {
                'name': 'val',
                'type': {
                  'defined': {'name': 'MyU32'},
                },
              },
            ],
          },
        ],
        types: [
          {
            'name': 'MyU32',
            'type': {'kind': 'type', 'alias': 'u32'},
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('alias_arg', {'val': 42});
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(42));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. Missing type support (f32, f64, bytes) — should be fixed
  // ---------------------------------------------------------------------------
  group('BorshInstructionCoder - f32/f64/bytes support', () {
    test('f32 round-trip', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'test_f32',
            'discriminator': [30, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'f32'},
            ],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('test_f32', {'val': 3.14});
      expect(encoded.length, equals(12)); // 8 disc + 4 f32
      final decoded = coder.decode(encoded);
      // f32 loses precision: 3.14 → ~3.140000104904175
      expect(decoded!.data['val'], closeTo(3.14, 0.001));
    });

    test('f64 round-trip', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'test_f64',
            'discriminator': [31, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'f64'},
            ],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('test_f64', {'val': 3.141592653589793});
      expect(encoded.length, equals(16)); // 8 disc + 8 f64
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(3.141592653589793));
    });

    test('bytes round-trip', () {
      final idl = _buildTestIdl(
        instructions: [
          {
            'name': 'test_bytes',
            'discriminator': [32, 0, 0, 0, 0, 0, 0, 0],
            'accounts': <Map<String, dynamic>>[],
            'args': [
              {'name': 'val', 'type': 'bytes'},
            ],
          },
        ],
      );
      final coder = BorshInstructionCoder(idl);
      final data = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final encoded = coder.encode('test_bytes', {'val': data});
      // disc(8) + length(4) + 4 bytes = 16
      expect(encoded.length, equals(16));
      final decoded = coder.decode(encoded);
      expect(decoded!.data['val'], equals(data));
    });
  });

  // ---------------------------------------------------------------------------
  // 14. Instruction class equality & toString
  // ---------------------------------------------------------------------------
  group('Instruction', () {
    test('equality for same name and data', () {
      final a = Instruction(name: 'test', data: {'a': 1});
      final b = Instruction(name: 'test', data: {'a': 1});
      expect(a, equals(b));
    });

    test('inequality for different name', () {
      final a = Instruction(name: 'test1', data: {'a': 1});
      final b = Instruction(name: 'test2', data: {'a': 1});
      expect(a, isNot(equals(b)));
    });

    test('toString includes name', () {
      final ix = Instruction(name: 'myIx', data: {'x': 1});
      expect(ix.toString(), contains('myIx'));
    });
  });
}
