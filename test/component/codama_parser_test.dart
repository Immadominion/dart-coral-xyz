/// T1.9 — Codama Parser Component Tests
///
/// Tests that CodamaParser correctly converts Codama node-tree JSON into
/// the flat Idl model, matching the upstream Codama spec:
///   https://github.com/codama-idl/codama
import 'package:coral_xyz/coral_xyz.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. Entry points (rootNode vs programNode)
  // ---------------------------------------------------------------------------
  group('CodamaParser - Entry points', () {
    test('parses rootNode containing a programNode', () {
      final json = {
        'kind': 'rootNode',
        'standard': 'codama',
        'version': '1.0.0',
        'program': {
          'kind': 'programNode',
          'name': 'myProgram',
          'publicKey': 'Prog11111111111111111111111111111111111111',
          'version': '0.2.0',
          'instructions': <Map<String, dynamic>>[],
          'accounts': <Map<String, dynamic>>[],
          'definedTypes': <Map<String, dynamic>>[],
          'errors': <Map<String, dynamic>>[],
        },
        'additionalPrograms': <Map<String, dynamic>>[],
      };

      final idl = CodamaParser.parse(json);
      expect(idl.name, equals('myProgram'));
      expect(idl.address, equals('Prog11111111111111111111111111111111111111'));
      expect(idl.version, equals('0.2.0'));
    });

    test('parses programNode directly', () {
      final json = {
        'kind': 'programNode',
        'name': 'directProg',
        'publicKey': 'Addr11111111111111111111111111111111111111',
        'version': '1.0.0',
        'instructions': <Map<String, dynamic>>[],
        'accounts': <Map<String, dynamic>>[],
        'definedTypes': <Map<String, dynamic>>[],
        'errors': <Map<String, dynamic>>[],
      };

      final idl = CodamaParser.parse(json);
      expect(idl.name, equals('directProg'));
    });

    test('throws for unknown node kind', () {
      expect(
        () => CodamaParser.parse({'kind': 'otherNode'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles missing optional fields gracefully', () {
      final json = {
        'kind': 'programNode',
        'name': 'minimal',
        'publicKey': 'MinAddr1111111111111111111111111111111111',
      };

      final idl = CodamaParser.parse(json);
      expect(idl.name, equals('minimal'));
      expect(idl.instructions, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Instructions
  // ---------------------------------------------------------------------------
  group('CodamaParser - Instructions', () {
    test('parses instruction with arguments', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'initialize',
            'arguments': [
              {
                'kind': 'instructionArgumentNode',
                'name': 'amount',
                'type': {'kind': 'numberTypeNode', 'format': 'u64'},
              },
              {
                'kind': 'instructionArgumentNode',
                'name': 'label',
                'type': {'kind': 'stringTypeNode'},
              },
            ],
            'accounts': <Map<String, dynamic>>[],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      expect(idl.instructions.length, equals(1));

      final ix = idl.instructions[0];
      expect(ix.name, equals('initialize'));
      expect(ix.args.length, equals(2));
      expect(ix.args[0].name, equals('amount'));
      expect(ix.args[0].type.kind, equals('u64'));
      expect(ix.args[1].name, equals('label'));
      expect(ix.args[1].type.kind, equals('string'));
    });

    test('parses instruction accounts with signer/writable/optional', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'transfer',
            'arguments': <Map<String, dynamic>>[],
            'accounts': [
              {
                'kind': 'instructionAccountNode',
                'name': 'from',
                'isMutable': true,
                'isSigner': true,
                'isOptional': false,
              },
              {
                'kind': 'instructionAccountNode',
                'name': 'to',
                'isMutable': true,
                'isSigner': false,
                'isOptional': false,
              },
              {
                'kind': 'instructionAccountNode',
                'name': 'delegate',
                'isMutable': false,
                'isSigner': false,
                'isOptional': true,
              },
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final ix = idl.instructions[0];
      expect(ix.accounts.length, equals(3));

      // from: writable + signer
      final from = ix.accounts[0] as IdlInstructionAccount;
      expect(from.name, equals('from'));
      expect(from.writable, isTrue);
      expect(from.signer, isTrue);

      // to: writable, not signer
      final to = ix.accounts[1] as IdlInstructionAccount;
      expect(to.writable, isTrue);
      expect(to.signer, isFalse);

      // delegate: optional
      final delegate = ix.accounts[2] as IdlInstructionAccount;
      expect(delegate.optional, isTrue);
    });

    test('parses constant discriminator (upstream format)', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'doSomething',
            'arguments': <Map<String, dynamic>>[],
            'accounts': <Map<String, dynamic>>[],
            'discriminators': [
              {
                'kind': 'constantDiscriminatorNode',
                'offset': 0,
                'constant': {
                  'kind': 'constantValueNode',
                  'type': {'kind': 'bytesTypeNode'},
                  'value': {
                    'kind': 'bytesValueNode',
                    'data': 'ff0142',
                    'encoding': 'hex',
                  },
                },
              },
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final ix = idl.instructions[0];
      expect(ix.discriminator, equals([0xFF, 0x01, 0x42]));
    });

    test('parses field discriminator', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'create',
            'arguments': [
              {
                'kind': 'instructionArgumentNode',
                'name': 'tag',
                'type': {'kind': 'numberTypeNode', 'format': 'u8'},
                'defaultValue': {'kind': 'numberValueNode', 'number': 3},
              },
            ],
            'accounts': <Map<String, dynamic>>[],
            'discriminators': [
              {'kind': 'fieldDiscriminatorNode', 'name': 'tag', 'offset': 0},
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final ix = idl.instructions[0];
      expect(ix.discriminator, equals([3]));
    });

    test('handles isSigner=either as signer=true', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'flexible',
            'arguments': <Map<String, dynamic>>[],
            'accounts': [
              {
                'kind': 'instructionAccountNode',
                'name': 'authority',
                'isMutable': false,
                'isSigner': 'either',
              },
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final acc = idl.instructions[0].accounts[0] as IdlInstructionAccount;
      expect(acc.signer, isTrue);
    });

    test('handles remaining accounts node', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'multi',
            'arguments': <Map<String, dynamic>>[],
            'accounts': [
              {'kind': 'instructionRemainingAccountsNode', 'name': 'extras'},
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final acc = idl.instructions[0].accounts[0] as IdlInstructionAccount;
      expect(acc.name, equals('extras'));
      expect(acc.optional, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Accounts
  // ---------------------------------------------------------------------------
  group('CodamaParser - Accounts', () {
    test('parses account with struct data and discriminator', () {
      final json = _programNode(
        accounts: [
          {
            'kind': 'accountNode',
            'name': 'Counter',
            'data': {
              'kind': 'structTypeNode',
              'fields': [
                {
                  'kind': 'structFieldTypeNode',
                  'name': 'count',
                  'type': {'kind': 'numberTypeNode', 'format': 'u64'},
                },
                {
                  'kind': 'structFieldTypeNode',
                  'name': 'authority',
                  'type': {'kind': 'publicKeyTypeNode'},
                },
              ],
            },
            'discriminators': [
              {
                'kind': 'constantDiscriminatorNode',
                'offset': 0,
                'constant': {
                  'kind': 'constantValueNode',
                  'type': {'kind': 'bytesTypeNode'},
                  'value': {
                    'kind': 'bytesValueNode',
                    'data': 'aabb',
                    'encoding': 'hex',
                  },
                },
              },
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);

      // Account entry
      expect(idl.accounts!.length, equals(1));
      expect(idl.accounts![0].name, equals('Counter'));
      expect(idl.accounts![0].discriminator, equals([0xAA, 0xBB]));

      // Account type def should be auto-generated in types
      final counterType = idl.types!.firstWhere((t) => t.name == 'Counter');
      expect(counterType.type.kind, equals('struct'));
      expect(counterType.type.fields!.length, equals(2));
      expect(counterType.type.fields![0].name, equals('count'));
      expect(counterType.type.fields![0].type.kind, equals('u64'));
      expect(counterType.type.fields![1].name, equals('authority'));
      expect(counterType.type.fields![1].type.kind, equals('pubkey'));
    });

    test('account without discriminator gets empty list', () {
      final json = _programNode(
        accounts: [
          {
            'kind': 'accountNode',
            'name': 'Simple',
            'data': {
              'kind': 'structTypeNode',
              'fields': <Map<String, dynamic>>[],
            },
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      expect(idl.accounts![0].discriminator, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Defined types
  // ---------------------------------------------------------------------------
  group('CodamaParser - Defined types', () {
    test('parses struct type', () {
      final json = _programNode(
        definedTypes: [
          {
            'kind': 'definedTypeNode',
            'name': 'Config',
            'type': {
              'kind': 'structTypeNode',
              'fields': [
                {
                  'kind': 'structFieldTypeNode',
                  'name': 'maxSize',
                  'type': {'kind': 'numberTypeNode', 'format': 'u32'},
                },
                {
                  'kind': 'structFieldTypeNode',
                  'name': 'active',
                  'type': {'kind': 'booleanTypeNode'},
                },
              ],
            },
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final config = idl.types!.firstWhere((t) => t.name == 'Config');
      expect(config.type.kind, equals('struct'));
      expect(config.type.fields![0].name, equals('maxSize'));
      expect(config.type.fields![0].type.kind, equals('u32'));
      expect(config.type.fields![1].name, equals('active'));
      expect(config.type.fields![1].type.kind, equals('bool'));
    });

    test('parses enum type', () {
      final json = _programNode(
        definedTypes: [
          {
            'kind': 'definedTypeNode',
            'name': 'Status',
            'type': {
              'kind': 'enumTypeNode',
              'variants': [
                {'kind': 'enumEmptyVariantTypeNode', 'name': 'Idle'},
                {
                  'kind': 'enumStructVariantTypeNode',
                  'name': 'Active',
                  'struct': {
                    'kind': 'structTypeNode',
                    'fields': [
                      {
                        'kind': 'structFieldTypeNode',
                        'name': 'since',
                        'type': {'kind': 'numberTypeNode', 'format': 'i64'},
                      },
                    ],
                  },
                },
              ],
            },
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final status = idl.types!.firstWhere((t) => t.name == 'Status');
      expect(status.type.kind, equals('enum'));
      expect(status.type.variants!.length, equals(2));
      expect(status.type.variants![0].name, equals('Idle'));
      expect(status.type.variants![1].name, equals('Active'));
      expect(status.type.variants![1].fields![0].name, equals('since'));
    });

    test('parses type alias (definedTypeLinkNode)', () {
      final json = _programNode(
        definedTypes: [
          {
            'kind': 'definedTypeNode',
            'name': 'Timestamp',
            'type': {'kind': 'numberTypeNode', 'format': 'i64'},
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      final ts = idl.types!.firstWhere((t) => t.name == 'Timestamp');
      // Type alias results in kind='type' with 'alias' field
      expect(ts.type.kind, equals('type'));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Type conversion
  // ---------------------------------------------------------------------------
  group('CodamaParser - Type conversion', () {
    test('all number types', () {
      for (final format in [
        'u8',
        'u16',
        'u32',
        'u64',
        'u128',
        'i8',
        'i16',
        'i32',
        'i64',
        'i128',
        'f32',
        'f64',
      ]) {
        final json = _programNode(
          instructions: [
            {
              'kind': 'instructionNode',
              'name': 'test_$format',
              'arguments': [
                {
                  'kind': 'instructionArgumentNode',
                  'name': 'val',
                  'type': {'kind': 'numberTypeNode', 'format': format},
                },
              ],
              'accounts': <Map<String, dynamic>>[],
            },
          ],
        );

        final idl = CodamaParser.parse(json);
        expect(
          idl.instructions[0].args[0].type.kind,
          equals(format),
          reason: 'Failed for $format',
        );
      }
    });

    test('boolean type', () {
      final idl = _parseWithArg({'kind': 'booleanTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('bool'));
    });

    test('string type', () {
      final idl = _parseWithArg({'kind': 'stringTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('string'));
    });

    test('publicKey type', () {
      final idl = _parseWithArg({'kind': 'publicKeyTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('pubkey'));
    });

    test('bytes type', () {
      final idl = _parseWithArg({'kind': 'bytesTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('bytes'));
    });

    test('option type (standard u8 prefix)', () {
      final idl = _parseWithArg({
        'kind': 'optionTypeNode',
        'item': {'kind': 'numberTypeNode', 'format': 'u64'},
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('option'));
      expect(type.inner!.kind, equals('u64'));
    });

    test('option type (COption u32 prefix)', () {
      final idl = _parseWithArg({
        'kind': 'optionTypeNode',
        'item': {'kind': 'numberTypeNode', 'format': 'u64'},
        'prefix': {'kind': 'numberTypeNode', 'format': 'u32', 'endian': 'le'},
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('coption'));
      expect(type.inner!.kind, equals('u64'));
    });

    test('array type (fixed count)', () {
      final idl = _parseWithArg({
        'kind': 'arrayTypeNode',
        'item': {'kind': 'numberTypeNode', 'format': 'u8'},
        'count': {'kind': 'fixedCountNode', 'value': 32},
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('array'));
      expect(type.inner!.kind, equals('u8'));
      expect(type.size, equals(32));
    });

    test('array type (prefixed count → vec)', () {
      final idl = _parseWithArg({
        'kind': 'arrayTypeNode',
        'item': {'kind': 'numberTypeNode', 'format': 'u32'},
        'count': {
          'kind': 'prefixedCountNode',
          'prefix': {'kind': 'numberTypeNode', 'format': 'u32'},
        },
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('vec'));
      expect(type.inner!.kind, equals('u32'));
    });

    test('set type → vec', () {
      final idl = _parseWithArg({
        'kind': 'setTypeNode',
        'item': {'kind': 'publicKeyTypeNode'},
      });

      expect(idl.instructions[0].args[0].type.kind, equals('vec'));
    });

    test('map type → vec bytes', () {
      final idl = _parseWithArg({
        'kind': 'mapTypeNode',
        'key': {'kind': 'stringTypeNode'},
        'value': {'kind': 'numberTypeNode', 'format': 'u64'},
      });

      expect(idl.instructions[0].args[0].type.kind, equals('vec'));
    });

    test('defined type link', () {
      final idl = _parseWithArg({
        'kind': 'definedTypeLinkNode',
        'name': 'MyStruct',
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('defined'));
    });

    test('amount type → underlying number', () {
      final idl = _parseWithArg({
        'kind': 'amountTypeNode',
        'number': {'kind': 'numberTypeNode', 'format': 'u64'},
      });

      expect(idl.instructions[0].args[0].type.kind, equals('u64'));
    });

    test('dateTime type → i64', () {
      final idl = _parseWithArg({'kind': 'dateTimeTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('i64'));
    });

    test('solAmount type → u64', () {
      final idl = _parseWithArg({'kind': 'solAmountTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('u64'));
    });

    test('remainderOption type → option', () {
      final idl = _parseWithArg({
        'kind': 'remainderOptionTypeNode',
        'item': {'kind': 'numberTypeNode', 'format': 'u32'},
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('option'));
      expect(type.inner!.kind, equals('u32'));
    });

    test('zeroableOption type → option', () {
      final idl = _parseWithArg({
        'kind': 'zeroableOptionTypeNode',
        'item': {'kind': 'publicKeyTypeNode'},
      });

      final type = idl.instructions[0].args[0].type;
      expect(type.kind, equals('option'));
    });

    test('fixedSize string → string', () {
      final idl = _parseWithArg({
        'kind': 'fixedSizeTypeNode',
        'type': {'kind': 'stringTypeNode'},
        'size': 32,
      });

      expect(idl.instructions[0].args[0].type.kind, equals('string'));
    });

    test('unknown type → bytes fallback', () {
      final idl = _parseWithArg({'kind': 'someFutureTypeNode'});
      expect(idl.instructions[0].args[0].type.kind, equals('bytes'));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Errors
  // ---------------------------------------------------------------------------
  group('CodamaParser - Errors', () {
    test('parses error codes', () {
      final json = _programNode(
        errors: [
          {
            'kind': 'errorNode',
            'code': 6000,
            'name': 'NotAuthorized',
            'message': 'You are not the authority.',
          },
          {'kind': 'errorNode', 'code': 6001, 'name': 'OverflowError'},
        ],
      );

      final idl = CodamaParser.parse(json);
      expect(idl.errors!.length, equals(2));
      expect(idl.errors![0].code, equals(6000));
      expect(idl.errors![0].name, equals('NotAuthorized'));
      expect(idl.errors![0].msg, equals('You are not the authority.'));
      expect(idl.errors![1].code, equals(6001));
      expect(idl.errors![1].name, equals('OverflowError'));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Format detection
  // ---------------------------------------------------------------------------
  group('CodamaParser - Format', () {
    test('parsed IDL has codama format', () {
      final json = _programNode();
      final idl = CodamaParser.parse(json);
      expect(idl.format, equals(IdlFormat.codama));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Full program round-trip (Pinocchio-style)
  // ---------------------------------------------------------------------------
  group('CodamaParser - Full Pinocchio program', () {
    test('parses a realistic Pinocchio counter program', () {
      final json = {
        'kind': 'rootNode',
        'standard': 'codama',
        'version': '1.0.0',
        'program': {
          'kind': 'programNode',
          'name': 'pinocchioCounter',
          'publicKey': 'Count11111111111111111111111111111111111111',
          'version': '0.1.0',
          'instructions': [
            {
              'kind': 'instructionNode',
              'name': 'initialize',
              'arguments': [
                {
                  'kind': 'instructionArgumentNode',
                  'name': 'tag',
                  'type': {'kind': 'numberTypeNode', 'format': 'u8'},
                  'defaultValue': {'kind': 'numberValueNode', 'number': 0},
                },
              ],
              'accounts': [
                {
                  'kind': 'instructionAccountNode',
                  'name': 'counter',
                  'isMutable': true,
                  'isSigner': true,
                },
                {
                  'kind': 'instructionAccountNode',
                  'name': 'payer',
                  'isMutable': true,
                  'isSigner': true,
                },
                {
                  'kind': 'instructionAccountNode',
                  'name': 'systemProgram',
                  'isMutable': false,
                  'isSigner': false,
                },
              ],
              'discriminators': [
                {'kind': 'fieldDiscriminatorNode', 'name': 'tag', 'offset': 0},
              ],
            },
            {
              'kind': 'instructionNode',
              'name': 'increment',
              'arguments': [
                {
                  'kind': 'instructionArgumentNode',
                  'name': 'tag',
                  'type': {'kind': 'numberTypeNode', 'format': 'u8'},
                  'defaultValue': {'kind': 'numberValueNode', 'number': 1},
                },
              ],
              'accounts': [
                {
                  'kind': 'instructionAccountNode',
                  'name': 'counter',
                  'isMutable': true,
                  'isSigner': false,
                },
              ],
              'discriminators': [
                {'kind': 'fieldDiscriminatorNode', 'name': 'tag', 'offset': 0},
              ],
            },
          ],
          'accounts': [
            {
              'kind': 'accountNode',
              'name': 'Counter',
              'data': {
                'kind': 'structTypeNode',
                'fields': [
                  {
                    'kind': 'structFieldTypeNode',
                    'name': 'count',
                    'type': {'kind': 'numberTypeNode', 'format': 'u64'},
                  },
                ],
              },
              'discriminators': [
                {
                  'kind': 'constantDiscriminatorNode',
                  'offset': 0,
                  'constant': {
                    'kind': 'constantValueNode',
                    'type': {'kind': 'bytesTypeNode'},
                    'value': {
                      'kind': 'bytesValueNode',
                      'data': '00',
                      'encoding': 'hex',
                    },
                  },
                },
              ],
            },
          ],
          'definedTypes': <Map<String, dynamic>>[],
          'errors': [
            {
              'kind': 'errorNode',
              'code': 0,
              'name': 'CounterOverflow',
              'message': 'Counter has overflowed.',
            },
          ],
        },
        'additionalPrograms': <Map<String, dynamic>>[],
      };

      final idl = CodamaParser.parse(json);

      // Program metadata
      expect(idl.name, equals('pinocchioCounter'));
      expect(
        idl.address,
        equals('Count11111111111111111111111111111111111111'),
      );
      expect(idl.format, equals(IdlFormat.codama));

      // Instructions
      expect(idl.instructions.length, equals(2));
      expect(idl.instructions[0].name, equals('initialize'));
      expect(idl.instructions[0].discriminator, equals([0]));
      expect(idl.instructions[0].accounts.length, equals(3));
      expect(idl.instructions[1].name, equals('increment'));
      expect(idl.instructions[1].discriminator, equals([1]));

      // Accounts
      expect(idl.accounts!.length, equals(1));
      expect(idl.accounts![0].name, equals('Counter'));
      expect(idl.accounts![0].discriminator, equals([0]));

      // Type defs (auto-generated from account)
      final counterType = idl.types!.firstWhere((t) => t.name == 'Counter');
      expect(counterType.type.fields![0].name, equals('count'));
      expect(counterType.type.fields![0].type.kind, equals('u64'));

      // Errors
      expect(idl.errors!.length, equals(1));
      expect(idl.errors![0].name, equals('CounterOverflow'));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Hex to bytes conversion
  // ---------------------------------------------------------------------------
  group('CodamaParser - Hex conversion', () {
    test('multi-byte discriminator from hex', () {
      final json = _programNode(
        accounts: [
          {
            'kind': 'accountNode',
            'name': 'HexTest',
            'data': {
              'kind': 'structTypeNode',
              'fields': <Map<String, dynamic>>[],
            },
            'discriminators': [
              {
                'kind': 'constantDiscriminatorNode',
                'offset': 0,
                'constant': {
                  'kind': 'constantValueNode',
                  'type': {'kind': 'bytesTypeNode'},
                  'value': {
                    'kind': 'bytesValueNode',
                    'data': 'deadbeef01',
                    'encoding': 'hex',
                  },
                },
              },
            ],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      expect(
        idl.accounts![0].discriminator,
        equals([0xDE, 0xAD, 0xBE, 0xEF, 0x01]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Docs
  // ---------------------------------------------------------------------------
  group('CodamaParser - Docs', () {
    test('preserves instruction docs', () {
      final json = _programNode(
        instructions: [
          {
            'kind': 'instructionNode',
            'name': 'documented',
            'arguments': <Map<String, dynamic>>[],
            'accounts': <Map<String, dynamic>>[],
            'docs': ['This is a documented instruction.'],
          },
        ],
      );

      final idl = CodamaParser.parse(json);
      expect(
        idl.instructions[0].docs,
        contains('This is a documented instruction.'),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Build a minimal programNode JSON wrapping optional sections.
Map<String, dynamic> _programNode({
  List<Map<String, dynamic>>? instructions,
  List<Map<String, dynamic>>? accounts,
  List<Map<String, dynamic>>? definedTypes,
  List<Map<String, dynamic>>? errors,
  List<Map<String, dynamic>>? events,
}) => {
  'kind': 'programNode',
  'name': 'testProg',
  'publicKey': 'Test1111111111111111111111111111111111111111',
  'version': '0.0.1',
  if (instructions != null) 'instructions': instructions,
  if (accounts != null) 'accounts': accounts,
  if (definedTypes != null) 'definedTypes': definedTypes,
  if (errors != null) 'errors': errors,
  if (events != null) 'events': events,
};

/// Parse a single instruction argument type for type-conversion tests.
Idl _parseWithArg(Map<String, dynamic> typeNode) => CodamaParser.parse(
  _programNode(
    instructions: [
      {
        'kind': 'instructionNode',
        'name': 'test',
        'arguments': [
          {'kind': 'instructionArgumentNode', 'name': 'val', 'type': typeNode},
        ],
        'accounts': <Map<String, dynamic>>[],
      },
    ],
  ),
);
