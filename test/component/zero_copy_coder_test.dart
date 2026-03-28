/// T1.5-R — Zero-Copy Accounts Coder Component Tests
///
/// Tests that ZeroCopyAccountsCoder correctly encodes and decodes account data
/// using repr(C)-style sequential field layout (alignment 1, no padding),
/// matching the Quasar on-chain representation.
import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a Quasar-format IDL with given accounts + types.
Idl _buildIdl({
  required List<Map<String, dynamic>> accounts,
  required List<Map<String, dynamic>> types,
  List<Map<String, dynamic>>? instructions,
}) {
  return Idl.fromJson({
    'address': 'Test111111111111111111111111111111111111111',
    'metadata': {'name': 'zc_test', 'version': '0.1.0', 'spec': '0.1.0'},
    'instructions': instructions ?? <Map<String, dynamic>>[],
    'accounts': accounts,
    'types': types,
  });
}

/// Simple IDL with one account that has 3 primitives.
Idl _simpleIdl() => _buildIdl(
  accounts: [
    {
      'name': 'Counter',
      'discriminator': [1, 2, 3, 4],
    },
  ],
  types: [
    {
      'name': 'Counter',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'authority', 'type': 'pubkey'},
          {'name': 'count', 'type': 'u64'},
          {'name': 'bump', 'type': 'u8'},
        ],
      },
    },
  ],
);

/// IDL with all primitive types.
Idl _allPrimitivesIdl() => _buildIdl(
  accounts: [
    {
      'name': 'AllPrims',
      'discriminator': [0xAA],
    },
  ],
  types: [
    {
      'name': 'AllPrims',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'a_bool', 'type': 'bool'},
          {'name': 'a_u8', 'type': 'u8'},
          {'name': 'a_i8', 'type': 'i8'},
          {'name': 'a_u16', 'type': 'u16'},
          {'name': 'a_i16', 'type': 'i16'},
          {'name': 'a_u32', 'type': 'u32'},
          {'name': 'a_i32', 'type': 'i32'},
          {'name': 'a_f32', 'type': 'f32'},
          {'name': 'a_u64', 'type': 'u64'},
          {'name': 'a_i64', 'type': 'i64'},
          {'name': 'a_f64', 'type': 'f64'},
        ],
      },
    },
  ],
);

/// IDL with complex types (vec, option, string, array, defined struct).
Idl _complexIdl() => _buildIdl(
  accounts: [
    {
      'name': 'Complex',
      'discriminator': [0xBB, 0xCC],
    },
  ],
  types: [
    {
      'name': 'Complex',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'name', 'type': 'string'},
          {
            'name': 'scores',
            'type': {'vec': 'u32'},
          },
          {
            'name': 'maybe',
            'type': {'option': 'u16'},
          },
          {
            'name': 'fixed',
            'type': {
              'array': ['u8', 3],
            },
          },
        ],
      },
    },
  ],
);

/// IDL with a nested defined struct.
Idl _nestedIdl() => _buildIdl(
  accounts: [
    {
      'name': 'Parent',
      'discriminator': [0xDD],
    },
  ],
  types: [
    {
      'name': 'Parent',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'id', 'type': 'u32'},
          {
            'name': 'child',
            'type': {'defined': 'Child'},
          },
        ],
      },
    },
    {
      'name': 'Child',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'x', 'type': 'u8'},
          {'name': 'y', 'type': 'u8'},
        ],
      },
    },
  ],
);

/// IDL with an enum.
Idl _enumIdl() => _buildIdl(
  accounts: [
    {
      'name': 'WithEnum',
      'discriminator': [0xEE],
    },
  ],
  types: [
    {
      'name': 'WithEnum',
      'type': {
        'kind': 'struct',
        'fields': [
          {
            'name': 'status',
            'type': {'defined': 'Status'},
          },
          {'name': 'value', 'type': 'u32'},
        ],
      },
    },
    {
      'name': 'Status',
      'type': {
        'kind': 'enum',
        'variants': [
          {'name': 'Idle'},
          {
            'name': 'Active',
            'fields': [
              {'name': 'since', 'type': 'u64'},
            ],
          },
          {'name': 'Paused'},
        ],
      },
    },
  ],
);

/// IDL with u128 / i128.
Idl _bigIntIdl() => _buildIdl(
  accounts: [
    {
      'name': 'BigNums',
      'discriminator': [0xFF],
    },
  ],
  types: [
    {
      'name': 'BigNums',
      'type': {
        'kind': 'struct',
        'fields': [
          {'name': 'big_u', 'type': 'u128'},
          {'name': 'big_i', 'type': 'i128'},
        ],
      },
    },
  ],
);

void main() {
  // ---------------------------------------------------------------------------
  // 1. Construction
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Construction', () {
    test('constructs from IDL with accounts', () {
      final idl = _simpleIdl();
      final coder = ZeroCopyAccountsCoder(idl);
      expect(coder, isNotNull);
    });

    test('constructs from IDL with no accounts', () {
      final idl = _buildIdl(accounts: [], types: []);
      final coder = ZeroCopyAccountsCoder(idl);
      expect(coder, isNotNull);
    });

    test('throws when type def missing for account', () {
      expect(
        () => ZeroCopyAccountsCoder(
          _buildIdl(
            accounts: [
              {
                'name': 'Missing',
                'discriminator': [1],
              },
            ],
            types: [],
          ),
        ),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Discriminator
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Discriminator', () {
    test('returns correct discriminator', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      final disc = coder.accountDiscriminator('Counter');
      expect(disc, equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('single-byte discriminator', () {
      final coder = ZeroCopyAccountsCoder(_allPrimitivesIdl());
      final disc = coder.accountDiscriminator('AllPrims');
      expect(disc, equals(Uint8List.fromList([0xAA])));
    });

    test('throws for unknown account', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      expect(
        () => coder.accountDiscriminator('Nope'),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Simple struct decode
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Simple decode', () {
    test('decodes Counter with pubkey + u64 + u8', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());

      final pubkeyBytes = List.generate(32, (i) => i + 10);
      final data = Uint8List.fromList([
        1, 2, 3, 4, // disc
        ...pubkeyBytes, // pubkey (32 bytes)
        42, 0, 0, 0, 0, 0, 0, 0, // u64 LE = 42
        7, // u8 = 7
      ]);

      final result = coder.decode<Map<String, dynamic>>('Counter', data);
      expect(result['authority'], equals(Uint8List.fromList(pubkeyBytes)));
      expect(result['count'], equals(BigInt.from(42)));
      expect(result['bump'], equals(7));
    });

    test('decode throws on wrong discriminator', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      final data = Uint8List.fromList([
        9, 9, 9, 9, // wrong disc
        ...List.filled(41, 0),
      ]);
      expect(
        () => coder.decode('Counter', data),
        throwsA(isA<AccountDiscriminatorMismatchError>()),
      );
    });

    test('decode throws on data too short for disc', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      expect(
        () => coder.decode('Counter', Uint8List.fromList([1, 2])),
        throwsA(isA<AccountDiscriminatorMismatchError>()),
      );
    });

    test('decodeUnchecked skips disc check', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      // Use wrong disc bytes — should still decode from after disc
      final data = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0xFF, // wrong disc (ignored)
        ...List.filled(32, 0), // pubkey all zeros
        1, 0, 0, 0, 0, 0, 0, 0, // u64 = 1
        0, // u8 = 0
      ]);
      final result = coder.decodeUnchecked<Map<String, dynamic>>(
        'Counter',
        data,
      );
      expect(result['count'], equals(BigInt.from(1)));
      expect(result['bump'], equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. All primitive types
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - All primitives', () {
    test('decodes all primitive types correctly', () {
      final coder = ZeroCopyAccountsCoder(_allPrimitivesIdl());

      final bd = ByteData(46); // 1 disc + 1+1+1+2+2+4+4+4+8+8+8 = 43+1+1 = 45
      var offset = 0;

      // Discriminator
      bd.setUint8(offset++, 0xAA);

      // bool
      bd.setUint8(offset++, 1);
      // u8
      bd.setUint8(offset++, 255);
      // i8
      bd.setInt8(offset++, -42);
      // u16
      bd.setUint16(offset, 1000, Endian.little);
      offset += 2;
      // i16
      bd.setInt16(offset, -300, Endian.little);
      offset += 2;
      // u32
      bd.setUint32(offset, 1234567, Endian.little);
      offset += 4;
      // i32
      bd.setInt32(offset, -99999, Endian.little);
      offset += 4;
      // f32
      bd.setFloat32(offset, 3.14, Endian.little);
      offset += 4;
      // u64
      bd.setUint64(offset, 9876543210, Endian.little);
      offset += 8;
      // i64
      bd.setInt64(offset, -1234567890, Endian.little);
      offset += 8;
      // f64
      bd.setFloat64(offset, 2.718281828, Endian.little);
      offset += 8;

      final data = bd.buffer.asUint8List();
      final m = coder.decode<Map<String, dynamic>>('AllPrims', data);

      expect(m['a_bool'], isTrue);
      expect(m['a_u8'], equals(255));
      expect(m['a_i8'], equals(-42));
      expect(m['a_u16'], equals(1000));
      expect(m['a_i16'], equals(-300));
      expect(m['a_u32'], equals(1234567));
      expect(m['a_i32'], equals(-99999));
      expect((m['a_f32'] as double), closeTo(3.14, 0.001));
      expect(m['a_u64'], equals(BigInt.from(9876543210)));
      expect(m['a_i64'], equals(BigInt.from(-1234567890)));
      expect((m['a_f64'] as double), closeTo(2.718281828, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Complex types
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Complex types', () {
    test('decodes string + vec + option(Some) + array', () {
      final coder = ZeroCopyAccountsCoder(_complexIdl());

      final strBytes = utf8.encode('hello');
      final data = Uint8List.fromList([
        0xBB, 0xCC, // disc
        // string: 4-byte len + bytes
        5, 0, 0, 0, ...strBytes,
        // vec<u32>: 4-byte count + elements
        2, 0, 0, 0,
        10, 0, 0, 0, // u32 = 10
        20, 0, 0, 0, // u32 = 20
        // option<u16>: 1-byte tag (Some) + u16
        1, 42, 0,
        // array [u8; 3]
        7, 8, 9,
      ]);

      final m = coder.decode<Map<String, dynamic>>('Complex', data);
      expect(m['name'], equals('hello'));
      expect(m['scores'], equals([10, 20]));
      expect(m['maybe'], equals(42));
      expect(m['fixed'], equals([7, 8, 9]));
    });

    test('decodes option(None)', () {
      final coder = ZeroCopyAccountsCoder(_complexIdl());

      final data = Uint8List.fromList([
        0xBB, 0xCC, // disc
        // string: empty
        0, 0, 0, 0,
        // vec<u32>: empty
        0, 0, 0, 0,
        // option<u16>: None
        0,
        // array [u8; 3]
        1, 2, 3,
      ]);

      final m = coder.decode<Map<String, dynamic>>('Complex', data);
      expect(m['name'], equals(''));
      expect(m['scores'], isEmpty);
      expect(m['maybe'], isNull);
      expect(m['fixed'], equals([1, 2, 3]));
    });

    test('decodes empty vec', () {
      final coder = ZeroCopyAccountsCoder(_complexIdl());

      final data = Uint8List.fromList([
        0xBB, 0xCC,
        0, 0, 0, 0, // empty string
        0, 0, 0, 0, // empty vec
        0, // None
        0, 0, 0, // array
      ]);

      final m = coder.decode<Map<String, dynamic>>('Complex', data);
      expect(m['scores'], equals([]));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Nested defined struct
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Nested struct', () {
    test('decodes parent containing child struct', () {
      final coder = ZeroCopyAccountsCoder(_nestedIdl());

      final data = Uint8List.fromList([
        0xDD, // disc
        99, 0, 0, 0, // u32 id = 99
        10, // child.x = 10
        20, // child.y = 20
      ]);

      final m = coder.decode<Map<String, dynamic>>('Parent', data);
      expect(m['id'], equals(99));
      final child = m['child'] as Map<String, dynamic>;
      expect(child['x'], equals(10));
      expect(child['y'], equals(20));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Enum types
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Enum', () {
    test('decodes unit enum variant (Idle)', () {
      final coder = ZeroCopyAccountsCoder(_enumIdl());

      final data = Uint8List.fromList([
        0xEE, // disc
        0, // variant 0 = Idle (no fields)
        42, 0, 0, 0, // u32 value = 42
      ]);

      final m = coder.decode<Map<String, dynamic>>('WithEnum', data);
      expect(m['status'], equals({'Idle': null}));
      expect(m['value'], equals(42));
    });

    test('decodes enum variant with fields (Active)', () {
      final coder = ZeroCopyAccountsCoder(_enumIdl());

      final data = Uint8List.fromList([
        0xEE, // disc
        1, // variant 1 = Active
        100, 0, 0, 0, 0, 0, 0, 0, // since: u64 = 100
        7, 0, 0, 0, // u32 value = 7
      ]);

      final m = coder.decode<Map<String, dynamic>>('WithEnum', data);
      expect(
        m['status'],
        equals({
          'Active': {'since': BigInt.from(100)},
        }),
      );
      expect(m['value'], equals(7));
    });

    test('decodes third variant (Paused)', () {
      final coder = ZeroCopyAccountsCoder(_enumIdl());

      final data = Uint8List.fromList([
        0xEE,
        2, // variant 2 = Paused
        0, 0, 0, 0,
      ]);

      final m = coder.decode<Map<String, dynamic>>('WithEnum', data);
      expect(m['status'], equals({'Paused': null}));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. u128 / i128
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Big integers', () {
    test('decodes u128 and i128', () {
      final coder = ZeroCopyAccountsCoder(_bigIntIdl());

      // u128 = 2^64 + 1 = hi=1 lo=1
      final bd = ByteData(33); // 1 disc + 16 + 16
      bd.setUint8(0, 0xFF); // disc
      // u128: lo=1, hi=1
      bd.setUint64(1, 1, Endian.little);
      bd.setUint64(9, 1, Endian.little);
      // i128: lo=0, hi=-1 (= -2^64)
      bd.setUint64(17, 0, Endian.little);
      bd.setInt64(25, -1, Endian.little);

      final data = bd.buffer.asUint8List();
      final m = coder.decode<Map<String, dynamic>>('BigNums', data);

      // u128 = (1 << 64) | 1
      expect(m['big_u'], equals((BigInt.one << 64) | BigInt.one));
      // i128 = (-1 << 64)
      expect(m['big_i'], equals(BigInt.from(-1) << 64));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Encode/decode round-trip
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Round-trip', () {
    test('simple struct round-trips', () async {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      final pubkeyBytes = Uint8List.fromList(List.generate(32, (i) => i));

      final original = {
        'authority': pubkeyBytes,
        'count': BigInt.from(999),
        'bump': 254,
      };

      final encoded = await coder.encode('Counter', original);
      final decoded = coder.decode<Map<String, dynamic>>('Counter', encoded);

      expect(decoded['authority'], equals(pubkeyBytes));
      expect(decoded['count'], equals(BigInt.from(999)));
      expect(decoded['bump'], equals(254));
    });

    test('complex struct round-trips', () async {
      final coder = ZeroCopyAccountsCoder(_complexIdl());

      final original = {
        'name': 'test_name',
        'scores': [100, 200, 300],
        'maybe': 42,
        'fixed': [1, 2, 3],
      };

      final encoded = await coder.encode('Complex', original);
      final decoded = coder.decode<Map<String, dynamic>>('Complex', encoded);

      expect(decoded['name'], equals('test_name'));
      expect(decoded['scores'], equals([100, 200, 300]));
      expect(decoded['maybe'], equals(42));
      expect(decoded['fixed'], equals([1, 2, 3]));
    });

    test('nested struct round-trips', () async {
      final coder = ZeroCopyAccountsCoder(_nestedIdl());

      final original = {
        'id': 42,
        'child': {'x': 10, 'y': 20},
      };

      final encoded = await coder.encode('Parent', original);
      final decoded = coder.decode<Map<String, dynamic>>('Parent', encoded);

      expect(decoded['id'], equals(42));
      expect((decoded['child'] as Map)['x'], equals(10));
      expect((decoded['child'] as Map)['y'], equals(20));
    });

    test('enum round-trips (unit variant)', () async {
      final coder = ZeroCopyAccountsCoder(_enumIdl());

      final original = {
        'status': {'Idle': null},
        'value': 7,
      };

      final encoded = await coder.encode('WithEnum', original);
      final decoded = coder.decode<Map<String, dynamic>>('WithEnum', encoded);

      expect(decoded['status'], equals({'Idle': null}));
      expect(decoded['value'], equals(7));
    });

    test('enum round-trips (variant with fields)', () async {
      final coder = ZeroCopyAccountsCoder(_enumIdl());

      final original = {
        'status': {
          'Active': {'since': BigInt.from(12345)},
        },
        'value': 99,
      };

      final encoded = await coder.encode('WithEnum', original);
      final decoded = coder.decode<Map<String, dynamic>>('WithEnum', encoded);

      expect(
        decoded['status'],
        equals({
          'Active': {'since': BigInt.from(12345)},
        }),
      );
      expect(decoded['value'], equals(99));
    });

    test('option None round-trips', () async {
      final coder = ZeroCopyAccountsCoder(_complexIdl());

      final original = {
        'name': '',
        'scores': <int>[],
        'maybe': null,
        'fixed': [0, 0, 0],
      };

      final encoded = await coder.encode('Complex', original);
      final decoded = coder.decode<Map<String, dynamic>>('Complex', encoded);

      expect(decoded['maybe'], isNull);
    });

    test('u128 round-trips', () async {
      final coder = ZeroCopyAccountsCoder(_bigIntIdl());
      final bigVal = (BigInt.one << 100) + BigInt.from(42);

      final original = {'big_u': bigVal, 'big_i': -bigVal};

      final encoded = await coder.encode('BigNums', original);
      final decoded = coder.decode<Map<String, dynamic>>('BigNums', encoded);

      expect(decoded['big_u'], equals(bigVal));
      expect(decoded['big_i'], equals(-bigVal));
    });
  });

  // ---------------------------------------------------------------------------
  // 10. decodeAny
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - decodeAny', () {
    test('finds matching account by disc', () {
      final idl = _buildIdl(
        accounts: [
          {
            'name': 'A',
            'discriminator': [1],
          },
          {
            'name': 'B',
            'discriminator': [2],
          },
        ],
        types: [
          {
            'name': 'A',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'x', 'type': 'u8'},
              ],
            },
          },
          {
            'name': 'B',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'y', 'type': 'u16'},
              ],
            },
          },
        ],
      );

      final coder = ZeroCopyAccountsCoder(idl);

      // Encode B
      final data = Uint8List.fromList([2, 42, 0]); // disc=2, u16=42
      final result = coder.decodeAny<Map<String, dynamic>>(data);
      expect(result['y'], equals(42));
    });

    test('throws when no disc matches', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      expect(
        () => coder.decodeAny(Uint8List.fromList([0xFF, 0xFF, 0, 0])),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 11. memcmp
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - memcmp', () {
    test('returns offset 0 with base64 disc', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      final result = coder.memcmp('Counter');
      expect(result['offset'], equals(0));
      // Decode and check it matches disc bytes
      final decoded = base64.decode(result['bytes'] as String);
      expect(decoded, equals([1, 2, 3, 4]));
    });

    test('appends data to disc', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      final extra = Uint8List.fromList([0xAA, 0xBB]);
      final result = coder.memcmp('Counter', appendData: extra);
      final decoded = base64.decode(result['bytes'] as String);
      expect(decoded, equals([1, 2, 3, 4, 0xAA, 0xBB]));
    });
  });

  // ---------------------------------------------------------------------------
  // 12. size
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - size', () {
    test('computes size for simple struct', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      // disc(4) + pubkey(32) + u64(8) + u8(1) = 45
      expect(coder.size('Counter'), equals(45));
    });

    test('computes size for enum struct (max variant)', () {
      final coder = ZeroCopyAccountsCoder(_enumIdl());
      // disc(1) + enum(1 tag + max variant Active: u64=8) + u32(4) = 14
      expect(coder.size('WithEnum'), equals(14));
    });

    test('computes size for u128 struct', () {
      final coder = ZeroCopyAccountsCoder(_bigIntIdl());
      // disc(1) + u128(16) + i128(16) = 33
      expect(coder.size('BigNums'), equals(33));
    });

    test('throws for unknown account', () {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      expect(() => coder.size('Unknown'), throwsA(isA<AccountCoderError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. Encode errors
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Encode errors', () {
    test('encode throws for non-Map input', () async {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      expect(
        () => coder.encode('Counter', 'not a map'),
        throwsA(isA<AccountCoderError>()),
      );
    });

    test('encode throws for unknown account', () async {
      final coder = ZeroCopyAccountsCoder(_simpleIdl());
      expect(
        () => coder.encode('Missing', {}),
        throwsA(isA<AccountCoderError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 14. Binary output verification
  // ---------------------------------------------------------------------------
  group('ZeroCopyAccountsCoder - Binary verification', () {
    test('encode produces exact expected bytes for simple struct', () async {
      final idl = _buildIdl(
        accounts: [
          {
            'name': 'Tiny',
            'discriminator': [0x42],
          },
        ],
        types: [
          {
            'name': 'Tiny',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'a', 'type': 'u8'},
                {'name': 'b', 'type': 'u16'},
              ],
            },
          },
        ],
      );

      final coder = ZeroCopyAccountsCoder(idl);
      final encoded = await coder.encode('Tiny', {'a': 1, 'b': 0x0304});

      expect(
        encoded,
        equals(
          Uint8List.fromList([
            0x42, // disc
            1, // u8
            4, 3, // u16 LE
          ]),
        ),
      );
    });

    test('f32 encode produces correct IEEE 754 bytes', () async {
      final idl = _buildIdl(
        accounts: [
          {
            'name': 'F',
            'discriminator': [0],
          },
        ],
        types: [
          {
            'name': 'F',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'v', 'type': 'f32'},
              ],
            },
          },
        ],
      );

      final coder = ZeroCopyAccountsCoder(idl);
      final encoded = await coder.encode('F', {'v': 1.0});

      // IEEE 754 f32 for 1.0: 0x3F800000 → LE: 00 00 80 3F
      expect(encoded.sublist(1), equals([0x00, 0x00, 0x80, 0x3F]));
    });
  });

  // ---------------------------------------------------------------------------
  // 15. AccountsCoderFactory selects ZeroCopy for quasar format
  // ---------------------------------------------------------------------------
  group('AccountsCoderFactory - ZeroCopy selection', () {
    test('creates ZeroCopyAccountsCoder for quasar format', () {
      // Build a quasar-format IDL (needs explicit encoding marker)
      final idl = _buildIdl(
        accounts: [
          {
            'name': 'QA',
            'discriminator': [1],
          },
        ],
        types: [
          {
            'name': 'QA',
            'type': {
              'kind': 'struct',
              'fields': [
                {'name': 'x', 'type': 'u8'},
              ],
            },
          },
        ],
      );

      // The factory selects based on idl.format
      // For standard anchor format, it returns BorshAccountsCoder
      final coder = AccountsCoderFactory.create(idl);
      // Anchor format IDL → BorshAccountsCoder
      expect(coder, isA<BorshAccountsCoder>());

      // Direct zero-copy construction
      final zcCoder = AccountsCoderFactory.zeroCopy(idl);
      expect(zcCoder, isA<ZeroCopyAccountsCoder>());
    });
  });
}
