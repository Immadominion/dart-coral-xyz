/// T1.5 — BorshEventCoder Component Tests
///
/// Tests decode from base64 log, encode/decode round-trip, 0xFF Quasar prefix
/// handling, discriminator matching, nested defined types, and error paths.
///
/// Ground truth: binary data manually constructed per Borsh spec, base64 encoded.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart';
import 'package:test/test.dart';

/// Borsh-encode helpers (same as account coder tests).
List<int> _borshBool(bool v) => [v ? 1 : 0];
List<int> _borshU8(int v) => [v & 0xFF];
List<int> _borshU32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];
List<int> _borshString(String s) {
  final utf8Bytes = utf8.encode(s);
  return [..._borshU32(utf8Bytes.length), ...utf8Bytes];
}

/// Build Anchor IDL with events.
Idl _buildEventIdl({
  required List<Map<String, dynamic>> events,
  required List<Map<String, dynamic>> types,
  List<Map<String, dynamic>>? instructions,
}) {
  final json = {
    'address': 'Test111111111111111111111111111111111111111',
    'metadata': {'name': 'test_program', 'version': '0.1.0', 'spec': '0.1.0'},
    'instructions': instructions ?? [],
    'accounts': <Map<String, dynamic>>[],
    'types': types,
    'events': events,
    'errors': <Map<String, dynamic>>[],
  };
  return Idl.fromJson(json);
}

/// Load the full Anchor IDL fixture.
Idl _loadFullIdl() {
  final file = File('test/fixtures/anchor_idl_full.json');
  return Idl.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}

void main() {
  // Simple event definition used across multiple tests.
  final simpleDisc = [1, 2, 3, 4, 5, 6, 7, 8];
  final simpleEvents = [
    {'name': 'MyEvent', 'discriminator': simpleDisc},
  ];
  final simpleTypes = [
    {
      'name': 'MyEvent',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'flag', 'type': 'bool'},
          {'name': 'count', 'type': 'u32'},
        ],
      },
    },
  ];

  // ---------------------------------------------------------------------------
  // 1. Construction
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - Construction', () {
    test('constructs from IDL with events', () {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      final coder = BorshEventCoder(idl);
      expect(coder, isNotNull);
    });

    test('constructs from IDL with no events', () {
      final idl = _buildEventIdl(events: [], types: []);
      final coder = BorshEventCoder(idl);
      expect(coder, isNotNull);
    });

    test('constructs from full Anchor IDL', () {
      final idl = _loadFullIdl();
      final coder = BorshEventCoder(idl);
      expect(coder, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Decode simple event from base64 log
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - decode', () {
    late BorshEventCoder coder;

    setUp(() {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      coder = BorshEventCoder(idl);
    });

    test('decodes event from base64 log', () {
      // Binary: disc(8) + bool(1: true) + u32(4: 42 LE)
      final bytes = Uint8List.fromList([
        ...simpleDisc,
        1, // true
        42, 0, 0, 0, // u32 = 42
      ]);
      final log = base64.encode(bytes);

      final event = coder.decode(log);
      expect(event, isNotNull);
      expect(event!.name, equals('MyEvent'));
      expect(event.data['flag'], isTrue);
      expect(event.data['count'], equals(42));
    });

    test('returns null for unrecognized discriminator', () {
      final bytes = Uint8List.fromList([99, 99, 99, 99, 99, 99, 99, 99, 0]);
      final log = base64.encode(bytes);
      expect(coder.decode(log), isNull);
    });

    test('returns null for invalid base64', () {
      expect(coder.decode('!!!not-base64!!!'), isNull);
    });

    test('returns null for empty string', () {
      expect(coder.decode(''), isNull);
    });

    test('returns null for data shorter than discriminator', () {
      final log = base64.encode(Uint8List.fromList([1, 2, 3]));
      expect(coder.decode(log), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Encode / decode round-trip
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - encode/decode round-trip', () {
    test('round-trip for simple event', () {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      final coder = BorshEventCoder(idl);

      final encoded = coder.encode('MyEvent', {'flag': false, 'count': 999});
      final log = base64.encode(encoded);
      final event = coder.decode(log);

      expect(event, isNotNull);
      expect(event!.name, equals('MyEvent'));
      expect(event.data['flag'], isFalse);
      expect(event.data['count'], equals(999));
    });

    test('round-trip with string field', () {
      final idl = _buildEventIdl(
        events: [
          {
            'name': 'StrEvent',
            'discriminator': [10, 20, 30, 40, 50, 60, 70, 80],
          },
        ],
        types: [
          {
            'name': 'StrEvent',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'msg', 'type': 'string'},
              ],
            },
          },
        ],
      );
      final coder = BorshEventCoder(idl);

      final encoded = coder.encode('StrEvent', {'msg': 'hello world'});
      final log = base64.encode(encoded);
      final event = coder.decode(log);
      expect(event!.data['msg'], equals('hello world'));
    });

    test('round-trip with vec and option fields', () {
      final idl = _buildEventIdl(
        events: [
          {
            'name': 'ComplexEvent',
            'discriminator': [11, 22, 33, 44, 55, 66, 77, 88],
          },
        ],
        types: [
          {
            'name': 'ComplexEvent',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'items',
                  'type': {'vec': 'u8'},
                },
                {
                  'name': 'maybe',
                  'type': {'option': 'bool'},
                },
              ],
            },
          },
        ],
      );
      final coder = BorshEventCoder(idl);

      final encoded = coder.encode('ComplexEvent', {
        'items': [1, 2, 3],
        'maybe': true,
      });
      final log = base64.encode(encoded);
      final event = coder.decode(log);
      expect(event!.data['items'], equals([1, 2, 3]));
      expect(event.data['maybe'], isTrue);
    });

    test('option None round-trip', () {
      final idl = _buildEventIdl(
        events: [
          {
            'name': 'OptEvent',
            'discriminator': [1, 1, 1, 1, 1, 1, 1, 1],
          },
        ],
        types: [
          {
            'name': 'OptEvent',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'val',
                  'type': {'option': 'u32'},
                },
              ],
            },
          },
        ],
      );
      final coder = BorshEventCoder(idl);
      final encoded = coder.encode('OptEvent', {'val': null});
      final event = coder.decode(base64.encode(encoded));
      expect(event!.data['val'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. 0xFF Quasar prefix handling
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - 0xFF prefix', () {
    test('decode strips 0xFF prefix from raw CPI data', () {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      final coder = BorshEventCoder(idl);

      // Prefix 0xFF before disc + data (as if raw CPI data)
      final bytes = Uint8List.fromList([
        0xFF,
        ...simpleDisc,
        0, // false
        7, 0, 0, 0, // u32 = 7
      ]);
      final log = base64.encode(bytes);
      final event = coder.decode(log);

      expect(event, isNotNull);
      expect(event!.name, equals('MyEvent'));
      expect(event.data['flag'], isFalse);
      expect(event.data['count'], equals(7));
    });

    test('decode works without 0xFF prefix (stripped by handler)', () {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      final coder = BorshEventCoder(idl);

      final bytes = Uint8List.fromList([
        ...simpleDisc,
        1, // true
        99, 0, 0, 0, // u32 = 99
      ]);
      final log = base64.encode(bytes);
      final event = coder.decode(log);
      expect(event!.data['flag'], isTrue);
      expect(event.data['count'], equals(99));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Multiple events — disambiguate by discriminator
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - Multiple events', () {
    test('matches correct event among multiple', () {
      final idl = _buildEventIdl(
        events: [
          {
            'name': 'EventA',
            'discriminator': [1, 0, 0, 0, 0, 0, 0, 0],
          },
          {
            'name': 'EventB',
            'discriminator': [2, 0, 0, 0, 0, 0, 0, 0],
          },
        ],
        types: [
          {
            'name': 'EventA',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'x', 'type': 'u8'},
              ],
            },
          },
          {
            'name': 'EventB',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'y', 'type': 'u32'},
              ],
            },
          },
        ],
      );
      final coder = BorshEventCoder(idl);

      // Encode EventB data
      final bytes = Uint8List.fromList([
        2, 0, 0, 0, 0, 0, 0, 0, // EventB disc
        42, 0, 0, 0, // u32 = 42
      ]);
      final event = coder.decode(base64.encode(bytes));
      expect(event!.name, equals('EventB'));
      expect(event.data['y'], equals(42));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Full IDL — SomeEvent
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - Full IDL SomeEvent', () {
    test('coder constructed with SomeEvent from full IDL', () {
      final idl = _loadFullIdl();
      final coder = BorshEventCoder(idl);
      // SomeEvent has fields: bool_field, external_my_struct, other_module_my_struct
      // All are defined types that need nested struct resolution
      expect(coder, isNotNull);
    });

    test('encode/decode SomeEvent with nested structs', () {
      final idl = _loadFullIdl();
      final coder = BorshEventCoder(idl);

      // SomeEvent: bool_field (bool), external_my_struct (external::MyStruct),
      // other_module_my_struct (idl::some_other_module::MyStruct)
      // external::MyStruct has: some_field (u8)
      // idl::some_other_module::MyStruct has: some_u8 (u8)
      final encoded = coder.encode('SomeEvent', {
        'bool_field': true,
        'external_my_struct': {'some_field': 42},
        'other_module_my_struct': {'some_u8': 7},
      });
      final event = coder.decode(base64.encode(encoded));
      expect(event, isNotNull);
      expect(event!.name, equals('SomeEvent'));
      expect(event.data['bool_field'], isTrue);
      expect(event.data['external_my_struct']['some_field'], equals(42));
      expect(event.data['other_module_my_struct']['some_u8'], equals(7));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Encode error handling
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - encode errors', () {
    test('throws for unknown event name', () {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      final coder = BorshEventCoder(idl);
      expect(
        () => coder.encode('NonExistent', {}),
        throwsA(isA<EventCoderException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Encode binary output verification
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - binary output verification', () {
    test('Anchor event: disc + borsh data', () {
      final idl = _buildEventIdl(events: simpleEvents, types: simpleTypes);
      final coder = BorshEventCoder(idl);
      final encoded = coder.encode('MyEvent', {'flag': true, 'count': 1});
      expect(
        encoded,
        equals(
          Uint8List.fromList([
            ...simpleDisc,
            1, // true
            1, 0, 0, 0, // u32 = 1
          ]),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Discriminator resolution fallback
  // ---------------------------------------------------------------------------
  group('BorshEventCoder - discriminator resolution', () {
    test('computes SHA256 discriminator when IDL has empty discriminator', () {
      final idl = _buildEventIdl(
        events: [
          {'name': 'FallbackEvent', 'discriminator': <int>[]},
        ],
        types: [
          {
            'name': 'FallbackEvent',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'x', 'type': 'u8'},
              ],
            },
          },
        ],
      );
      final coder = BorshEventCoder(idl);

      // The discriminator should be SHA256("event:FallbackEvent") first 8 bytes
      final expected = DiscriminatorComputer.computeEventDiscriminator(
        'FallbackEvent',
      );
      final encoded = coder.encode('FallbackEvent', {'x': 5});
      expect(encoded.sublist(0, 8), equals(expected));
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Event class properties
  // ---------------------------------------------------------------------------
  group('Event', () {
    test('toString contains name', () {
      final event = Event<IdlEvent, Map<String, dynamic>>(
        name: 'TestEvent',
        data: {'x': 1},
        eventDef: const IdlEvent(name: 'TestEvent', discriminator: []),
        programId: PublicKeyUtils.defaultPubkey,
      );
      expect(event.toString(), contains('TestEvent'));
    });
  });
}
