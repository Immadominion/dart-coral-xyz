/// T1.6 — BorshCoder / AutoCoder / CoderFactory Component Tests
///
/// Tests that the facade coders (BorshCoder, AutoCoder, CoderFactory) correctly
/// compose the individual sub-coders and that encode/decode round-trips work
/// through the unified interface.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart';
import 'package:test/test.dart';

/// Load the full Anchor IDL fixture.
Idl _loadFullIdl() {
  final file = File('test/fixtures/anchor_idl_full.json');
  return Idl.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}

/// Build a minimal Anchor IDL with instruction, account, event, and type.
Idl _buildMinimalIdl() {
  final json = {
    'address': 'Test111111111111111111111111111111111111111',
    'metadata': {'name': 'test_program', 'version': '0.1.0', 'spec': '0.1.0'},
    'instructions': [
      {
        'name': 'noop',
        'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
        'accounts': <Map<String, dynamic>>[],
        'args': [
          {'name': 'val', 'type': 'u8'},
        ],
      },
    ],
    'accounts': [
      {
        'name': 'MyAccount',
        'discriminator': [10, 20, 30, 40, 50, 60, 70, 80],
      },
    ],
    'types': [
      {
        'name': 'MyAccount',
        'type': {
          'kind': 'struct',
          'fields': [
            {'name': 'x', 'type': 'u32'},
          ],
        },
      },
      {
        'name': 'MyEvent',
        'type': {
          'kind': 'struct',
          'fields': [
            {'name': 'y', 'type': 'bool'},
          ],
        },
      },
    ],
    'events': [
      {
        'name': 'MyEvent',
        'discriminator': [11, 22, 33, 44, 55, 66, 77, 88],
      },
    ],
    'errors': <Map<String, dynamic>>[],
  };
  return Idl.fromJson(json);
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. BorshCoder construction
  // ---------------------------------------------------------------------------
  group('BorshCoder - Construction', () {
    test('constructs from minimal IDL and exposes sub-coders', () {
      final idl = _buildMinimalIdl();
      final coder = BorshCoder(idl);
      expect(coder.instructions, isA<BorshInstructionCoder>());
      expect(coder.accounts, isA<BorshAccountsCoder>());
      expect(coder.events, isA<BorshEventCoder>());
      expect(coder.types, isA<BorshTypesCoder>());
    });

    test('constructs from full IDL', () {
      final idl = _loadFullIdl();
      final coder = BorshCoder(idl);
      expect(coder.instructions, isNotNull);
      expect(coder.accounts, isNotNull);
      expect(coder.events, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. AutoCoder construction & format detection
  // ---------------------------------------------------------------------------
  group('AutoCoder - Construction', () {
    test('detects Anchor format for standard IDL', () {
      final idl = _buildMinimalIdl();
      expect(idl.format, equals(IdlFormat.anchor));

      final coder = AutoCoder(idl);
      expect(coder.instructions, isA<BorshInstructionCoder>());
      expect(coder.accounts, isA<BorshAccountsCoder>());
      expect(coder.events, isA<BorshEventCoder>());
    });

    test('constructs from full IDL', () {
      final idl = _loadFullIdl();
      final coder = AutoCoder(idl);
      expect(coder, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. CoderFactory
  // ---------------------------------------------------------------------------
  group('CoderFactory', () {
    test('fromIdl returns AutoCoder', () {
      final idl = _buildMinimalIdl();
      final coder = CoderFactory.fromIdl(idl);
      expect(coder, isNotNull);
      expect(coder.instructions, isA<InstructionCoder>());
    });

    test('borsh returns BorshCoder', () {
      final idl = _buildMinimalIdl();
      final coder = CoderFactory.borsh(idl);
      expect(coder, isNotNull);
      expect(coder.accounts, isA<BorshAccountsCoder>());
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Instruction encode/decode through unified interface
  // ---------------------------------------------------------------------------
  group('BorshCoder - Instruction round-trip', () {
    test('encode and decode via coder.instructions', () {
      final idl = _buildMinimalIdl();
      final coder = BorshCoder(idl);

      final encoded = coder.instructions.encode('noop', {'val': 42});
      expect(encoded.length, equals(9)); // 8 disc + 1 u8

      final decoded = coder.instructions.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('noop'));
      expect(decoded.data['val'], equals(42));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Account decode through unified interface
  // ---------------------------------------------------------------------------
  group('BorshCoder - Account decode', () {
    test('decode via coder.accounts', () {
      final idl = _buildMinimalIdl();
      final coder = BorshCoder(idl);

      // Discriminator + u32(42) borsh
      final data = Uint8List.fromList([
        10, 20, 30, 40, 50, 60, 70, 80, // disc
        42, 0, 0, 0, // u32 LE
      ]);

      final result = coder.accounts.decode<Map<String, dynamic>>(
        'MyAccount',
        data,
      );
      expect(result['x'], equals(42));
    });

    test('accountDiscriminator via coder.accounts', () {
      final idl = _buildMinimalIdl();
      final coder = BorshCoder(idl);

      final disc = coder.accounts.accountDiscriminator('MyAccount');
      expect(
        disc,
        equals(Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80])),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Event decode through unified interface
  // ---------------------------------------------------------------------------
  group('BorshCoder - Event round-trip', () {
    test('encode and decode via coder.events', () {
      final idl = _buildMinimalIdl();
      final coder = BorshCoder(idl);

      final encoded = coder.events.encode('MyEvent', {'y': true});
      final log = base64.encode(encoded);
      final event = coder.events.decode(log);

      expect(event, isNotNull);
      expect(event!.name, equals('MyEvent'));
      expect(event.data['y'], isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Full IDL round-trips through CoderFactory
  // ---------------------------------------------------------------------------
  group('CoderFactory - Full IDL', () {
    test('instruction encode/decode for cause_error', () {
      final idl = _loadFullIdl();
      final coder = CoderFactory.fromIdl(idl);

      final encoded = coder.instructions.encode('cause_error', {});
      final decoded = coder.instructions.decode(encoded);
      expect(decoded!.name, equals('cause_error'));
    });

    test('account discriminator for State', () {
      final idl = _loadFullIdl();
      final coder = CoderFactory.fromIdl(idl);

      final disc = coder.accounts.accountDiscriminator('State');
      expect(
        disc,
        equals(Uint8List.fromList([216, 146, 107, 94, 104, 75, 182, 177])),
      );
    });

    test('event encode/decode for SomeEvent', () {
      final idl = _loadFullIdl();
      final coder = CoderFactory.fromIdl(idl);

      final encoded = coder.events.encode('SomeEvent', {
        'bool_field': true,
        'external_my_struct': {'some_field': 1},
        'other_module_my_struct': {'some_u8': 2},
      });
      final event = coder.events.decode(base64.encode(encoded));
      expect(event!.name, equals('SomeEvent'));
    });
  });
}
