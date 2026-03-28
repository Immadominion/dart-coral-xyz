/// T1.4 — BorshAccountsCoder Component Tests
///
/// Tests discriminator handling, decode/decodeUnchecked/decodeAny for struct
/// accounts, memcmp filter generation, encode limitations, and error paths.
///
/// Ground truth: binary data manually constructed per Borsh spec.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart';
import 'package:test/test.dart';

/// Build a minimal IDL with accounts and matching type definitions.
Idl _buildTestIdl({
  required List<Map<String, dynamic>> accounts,
  required List<Map<String, dynamic>> types,
}) {
  final json = {
    'address': 'Test111111111111111111111111111111111111111',
    'metadata': {'name': 'test_program', 'version': '0.1.0', 'spec': '0.1.0'},
    'instructions': <Map<String, dynamic>>[],
    'accounts': accounts,
    'types': types,
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

/// Manually build Borsh-encoded bytes for a simple struct.
/// Prepends the discriminator, then encodes each field in order.
Uint8List _buildAccountData({
  required List<int> discriminator,
  required List<int> borshPayload,
}) {
  return Uint8List.fromList([...discriminator, ...borshPayload]);
}

/// Borsh-encode a bool.
List<int> _borshBool(bool v) => [v ? 1 : 0];

/// Borsh-encode a u8.
List<int> _borshU8(int v) => [v & 0xFF];

/// Borsh-encode a u32 little-endian.
List<int> _borshU32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

/// Borsh-encode a u64 little-endian.
List<int> _borshU64(int v) {
  final bytes = <int>[];
  for (int i = 0; i < 8; i++) {
    bytes.add((v >> (i * 8)) & 0xFF);
  }
  return bytes;
}

/// Borsh-encode a string (4-byte LE length + UTF-8).
List<int> _borshString(String s) {
  final utf8Bytes = utf8.encode(s);
  return [..._borshU32(utf8Bytes.length), ...utf8Bytes];
}

void main() {
  // A simple account with only primitive fields for controlled testing.
  final simpleDisc = [10, 20, 30, 40, 50, 60, 70, 80];
  final simpleAccounts = [
    {'name': 'SimpleAccount', 'discriminator': simpleDisc},
  ];
  final simpleTypes = [
    {
      'name': 'SimpleAccount',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'val_bool', 'type': 'bool'},
          {'name': 'val_u32', 'type': 'u32'},
          {'name': 'val_str', 'type': 'string'},
        ],
      },
    },
  ];

  // ---------------------------------------------------------------------------
  // 1. Construction
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - Construction', () {
    test('constructs from IDL with accounts + matching types', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      expect(coder, isNotNull);
    });

    test('constructs from IDL with no accounts', () {
      final idl = _buildTestIdl(accounts: [], types: []);
      final coder = BorshAccountsCoder(idl);
      expect(coder, isNotNull);
    });

    test('throws when type definition is missing for an account', () {
      expect(
        () => BorshAccountsCoder(
          _buildTestIdl(
            accounts: [
              {
                'name': 'MissingType',
                'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
              },
            ],
            types: [], // No matching type
          ),
        ),
        throwsA(isA<AccountCoderError>()),
      );
    });

    test('constructs from full Anchor IDL', () {
      final idl = _loadFullIdl();
      final coder = BorshAccountsCoder(idl);
      expect(coder, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. accountDiscriminator
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - accountDiscriminator', () {
    test('returns IDL discriminator for known account', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      final disc = coder.accountDiscriminator('SimpleAccount');
      expect(disc, equals(Uint8List.fromList(simpleDisc)));
    });

    test('returns correct discriminator for State from full IDL', () {
      final idl = _loadFullIdl();
      final coder = BorshAccountsCoder(idl);
      final disc = coder.accountDiscriminator('State');
      expect(
        disc,
        equals(Uint8List.fromList([216, 146, 107, 94, 104, 75, 182, 177])),
      );
    });

    test('throws for unknown account name', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      expect(
        () => coder.accountDiscriminator('NonExistent'),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Decode — simple struct
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - decode', () {
    late BorshAccountsCoder coder;

    setUp(() {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      coder = BorshAccountsCoder(idl);
    });

    test('decodes simple struct with correct discriminator', () {
      final payload = [
        ..._borshBool(true),
        ..._borshU32(42),
        ..._borshString('hello'),
      ];
      final data = _buildAccountData(
        discriminator: simpleDisc,
        borshPayload: payload,
      );

      final result = coder.decode<Map<String, dynamic>>('SimpleAccount', data);
      expect(result['val_bool'], isTrue);
      expect(result['val_u32'], equals(42));
      expect(result['val_str'], equals('hello'));
    });

    test('throws on discriminator mismatch', () {
      final wrongDisc = [99, 99, 99, 99, 99, 99, 99, 99];
      final payload = [
        ..._borshBool(false),
        ..._borshU32(0),
        ..._borshString(''),
      ];
      final data = _buildAccountData(
        discriminator: wrongDisc,
        borshPayload: payload,
      );

      expect(
        () => coder.decode<Map<String, dynamic>>('SimpleAccount', data),
        throwsA(isA<AccountDiscriminatorMismatchError>()),
      );
    });

    test('throws on data too short', () {
      expect(
        () => coder.decode<Map<String, dynamic>>(
          'SimpleAccount',
          Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<AccountDiscriminatorMismatchError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 4. DecodeUnchecked — skips discriminator check
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - decodeUnchecked', () {
    test('decodes even with wrong discriminator bytes in data', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);

      // Use wrong discriminator — decodeUnchecked should still work
      // because it skips validation but still strips discriminator.length bytes
      final payload = [
        ..._borshBool(false),
        ..._borshU32(999),
        ..._borshString('test'),
      ];
      // Put the CORRECT discriminator length of bytes (8) but wrong values
      final data = _buildAccountData(
        discriminator: [0, 0, 0, 0, 0, 0, 0, 0],
        borshPayload: payload,
      );

      final result = coder.decodeUnchecked<Map<String, dynamic>>(
        'SimpleAccount',
        data,
      );
      expect(result['val_bool'], isFalse);
      expect(result['val_u32'], equals(999));
      expect(result['val_str'], equals('test'));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. DecodeAny — match by discriminator
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - decodeAny', () {
    test('matches correct account by discriminator', () {
      final disc1 = [1, 1, 1, 1, 1, 1, 1, 1];
      final disc2 = [2, 2, 2, 2, 2, 2, 2, 2];

      final idl = _buildTestIdl(
        accounts: [
          {'name': 'Acc1', 'discriminator': disc1},
          {'name': 'Acc2', 'discriminator': disc2},
        ],
        types: [
          {
            'name': 'Acc1',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'x', 'type': 'u8'},
              ],
            },
          },
          {
            'name': 'Acc2',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'y', 'type': 'u32'},
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);

      // Build data for Acc2
      final data = _buildAccountData(
        discriminator: disc2,
        borshPayload: _borshU32(42),
      );

      final result = coder.decodeAny<Map<String, dynamic>>(data);
      expect(result['y'], equals(42));
    });

    test('throws for unknown discriminator', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);

      final data = Uint8List.fromList([99, 99, 99, 99, 99, 99, 99, 99, 0]);
      expect(
        () => coder.decodeAny<Map<String, dynamic>>(data),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. memcmp filter
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - memcmp', () {
    test('returns discriminator as base64 at offset 0', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);

      final filter = coder.memcmp('SimpleAccount');
      expect(filter['offset'], equals(0));

      // Decode base64 and compare
      final bytes = base64.decode(filter['bytes'] as String);
      expect(bytes, equals(simpleDisc));
    });

    test('memcmp with appendData includes additional bytes', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);

      final appendData = Uint8List.fromList([0xAA, 0xBB]);
      final filter = coder.memcmp('SimpleAccount', appendData: appendData);

      final bytes = base64.decode(filter['bytes'] as String);
      expect(bytes, equals([...simpleDisc, 0xAA, 0xBB]));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Struct with u64/i64 fields (BigInt return)
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - Numeric types', () {
    test('u64 field decoded as BigInt', () {
      final disc = [1, 2, 3, 4, 5, 6, 7, 8];
      final idl = _buildTestIdl(
        accounts: [
          {'name': 'NumAccount', 'discriminator': disc},
        ],
        types: [
          {
            'name': 'NumAccount',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'big_val', 'type': 'u64'},
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);

      final data = _buildAccountData(
        discriminator: disc,
        borshPayload: _borshU64(100000),
      );

      final result = coder.decode<Map<String, dynamic>>('NumAccount', data);
      // Account coder returns BigInt for u64
      expect(result['big_val'], equals(BigInt.from(100000)));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Complex struct fields (bool, u8, u32, vec, option, array)
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - Complex struct decode', () {
    test('decodes struct with vec and option fields', () {
      final disc = [1, 2, 3, 4, 5, 6, 7, 8];
      final idl = _buildTestIdl(
        accounts: [
          {'name': 'ComplexAccount', 'discriminator': disc},
        ],
        types: [
          {
            'name': 'ComplexAccount',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'flag', 'type': 'bool'},
                {
                  'name': 'items',
                  'type': {'vec': 'u32'},
                },
                {
                  'name': 'maybe',
                  'type': {'option': 'u8'},
                },
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);

      final payload = [
        ..._borshBool(true),
        // vec<u32>: count=2, items=[10, 20]
        ..._borshU32(2),
        ..._borshU32(10),
        ..._borshU32(20),
        // option<u8>: Some(42)
        1, 42,
      ];
      final data = _buildAccountData(
        discriminator: disc,
        borshPayload: payload,
      );

      final result = coder.decode<Map<String, dynamic>>('ComplexAccount', data);
      expect(result['flag'], isTrue);
      expect(result['items'], equals([10, 20]));
      expect(result['maybe'], equals(42));
    });

    test('decodes option None as null', () {
      final disc = [1, 2, 3, 4, 5, 6, 7, 8];
      final idl = _buildTestIdl(
        accounts: [
          {'name': 'OptAccount', 'discriminator': disc},
        ],
        types: [
          {
            'name': 'OptAccount',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'maybe',
                  'type': {'option': 'u8'},
                },
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);
      final data = _buildAccountData(
        discriminator: disc,
        borshPayload: [0], // None
      );
      final result = coder.decode<Map<String, dynamic>>('OptAccount', data);
      expect(result['maybe'], isNull);
    });

    test('decodes fixed-size array', () {
      final disc = [1, 2, 3, 4, 5, 6, 7, 8];
      final idl = _buildTestIdl(
        accounts: [
          {'name': 'ArrAccount', 'discriminator': disc},
        ],
        types: [
          {
            'name': 'ArrAccount',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'flags',
                  'type': {
                    'array': ['bool', 3],
                  },
                },
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);
      final data = _buildAccountData(
        discriminator: disc,
        borshPayload: [1, 0, 1], // [true, false, true]
      );
      final result = coder.decode<Map<String, dynamic>>('ArrAccount', data);
      expect(result['flags'], equals([true, false, true]));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Full IDL — State2 decode (simpler fields)
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - Full IDL State2', () {
    late BorshAccountsCoder coder;

    setUp(() {
      final idl = _loadFullIdl();
      coder = BorshAccountsCoder(idl);
    });

    test('decodes State2 with vec_of_option and box_field', () {
      // State2 discriminator: [106, 97, 255, 161, 250, 205, 185, 192]
      final disc = [106, 97, 255, 161, 250, 205, 185, 192];
      final payload = [
        // vec_of_option: vec<option<u64>> — count=2
        ..._borshU32(2),
        // first: Some(100)
        1, ..._borshU64(100),
        // second: None
        0,
        // box_field: true
        ..._borshBool(true),
      ];
      final data = _buildAccountData(
        discriminator: disc,
        borshPayload: payload,
      );

      final result = coder.decode<Map<String, dynamic>>('State2', data);
      expect(result['vec_of_option'], equals([BigInt.from(100), null]));
      expect(result['box_field'], isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Encode (known limitations)
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - encode', () {
    test('encode throws for unknown account', () async {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      expect(
        () => coder.encode('NonExistent', <String, dynamic>{}),
        throwsA(isA<AccountCoderError>()),
      );
    });

    // Encode uses _encodeAccountData which has hardcoded Counter-specific logic
    // and falls back to JSON for other types. This is a known limitation.
    test('encode falls back to JSON for non-Counter accounts', () async {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      final encoded = await coder.encode('SimpleAccount', {
        'val_bool': true,
        'val_u32': 42,
        'val_str': 'hello',
      });
      // The encoded data starts with discriminator
      expect(encoded.sublist(0, 8), equals(simpleDisc));
      // But the payload is JSON, not Borsh (known limitation)
      // Verify it's non-empty (the JSON bytes are appended)
      expect(encoded.length, greaterThan(8));
    });
  });

  // ---------------------------------------------------------------------------
  // 11. size — calculates discriminator + field sizes from IDL
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - size', () {
    test('returns discriminator + type size from IDL', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      final sz = coder.size('SimpleAccount');
      // disc(8) + bool(1) + u32(4) + string(1 variable-length marker) = 14
      expect(sz, equals(14));
    });

    test('throws for unknown account', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      expect(
        () => coder.size('NonExistent'),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 12. Enum decode in account struct
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - Enum type decode', () {
    test('decodes simple enum (unit variant)', () {
      final disc = [1, 2, 3, 4, 5, 6, 7, 8];
      final idl = _buildTestIdl(
        accounts: [
          {'name': 'EnumAccount', 'discriminator': disc},
        ],
        types: [
          {
            'name': 'EnumAccount',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'status',
                  'type': {
                    'defined': {'name': 'MyStatus'},
                  },
                },
              ],
            },
          },
          {
            'name': 'MyStatus',
            'type': {
              'kind': 'enum',
              'variants': [
                {'name': 'Active'},
                {'name': 'Inactive'},
                {'name': 'Paused'},
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);

      // Enum discriminator = 1 → Inactive (0-indexed variant)
      final data = _buildAccountData(discriminator: disc, borshPayload: [1]);
      final result = coder.decode<Map<String, dynamic>>('EnumAccount', data);
      expect(result['status'], equals({'Inactive': null}));
    });

    test('decodes enum with named fields', () {
      final disc = [1, 2, 3, 4, 5, 6, 7, 8];
      final idl = _buildTestIdl(
        accounts: [
          {'name': 'EnumAccount2', 'discriminator': disc},
        ],
        types: [
          {
            'name': 'EnumAccount2',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'val',
                  'type': {
                    'defined': {'name': 'MyEnum'},
                  },
                },
              ],
            },
          },
          {
            'name': 'MyEnum',
            'type': {
              'kind': 'enum',
              'variants': [
                {'name': 'Empty'},
                {
                  'name': 'WithData',
                  'fields': [
                    {'name': 'x', 'type': 'u8'},
                    {'name': 'y', 'type': 'bool'},
                  ],
                },
              ],
            },
          },
        ],
      );
      final coder = BorshAccountsCoder(idl);

      // variant index 1 (WithData), then u8=42, bool=true
      final data = _buildAccountData(
        discriminator: disc,
        borshPayload: [1, 42, 1],
      );
      final result = coder.decode<Map<String, dynamic>>('EnumAccount2', data);
      expect(
        result['val'],
        equals({
          'WithData': {'x': 42, 'y': true},
        }),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 13. String field decode
  // ---------------------------------------------------------------------------
  group('BorshAccountsCoder - String field', () {
    test('decodes empty string', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      final payload = [
        ..._borshBool(false),
        ..._borshU32(0),
        ..._borshString(''),
      ];
      final data = _buildAccountData(
        discriminator: simpleDisc,
        borshPayload: payload,
      );
      final result = coder.decode<Map<String, dynamic>>('SimpleAccount', data);
      expect(result['val_str'], equals(''));
    });

    test('decodes UTF-8 string', () {
      final idl = _buildTestIdl(accounts: simpleAccounts, types: simpleTypes);
      final coder = BorshAccountsCoder(idl);
      final payload = [
        ..._borshBool(true),
        ..._borshU32(1),
        ..._borshString('café'),
      ];
      final data = _buildAccountData(
        discriminator: simpleDisc,
        borshPayload: payload,
      );
      final result = coder.decode<Map<String, dynamic>>('SimpleAccount', data);
      expect(result['val_str'], equals('café'));
    });
  });
}
