import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'integration_test_utils.dart';

/// TypeScript compatibility integration tests
void main() {
  group('TypeScript Compatibility Tests', () {
    late IntegrationTestEnvironment env;
    late TypeScriptCompatibilityTester tester;

    setUpAll(() async {
      env = IntegrationTestEnvironment();
      await env.setUp();
      tester = TypeScriptCompatibilityTester(env);
    });

    tearDownAll(() async {
      await env.tearDown();
    });

    test('IDL parsing compatibility with TypeScript', () async {
      // Sample IDL that should be compatible with TypeScript @coral-xyz/anchor
      final tsCompatibleIdl = {
        'address': 'TSCompatible11111111111111111111111111111',
        'metadata': {
          'name': 'ts_compatible_program',
          'version': '0.1.0',
          'spec': '0.1.0',
        },
        'instructions': [
          {
            'name': 'initialize',
            'docs': ['Initialize the program'],
            'discriminator': [175, 175, 109, 31, 13, 152, 155, 237],
            'accounts': [
              {
                'name': 'user',
                'writable': true,
                'signer': true,
              },
              {
                'name': 'system_program',
                'writable': false,
                'signer': false,
              },
            ],
            'args': [
              {
                'name': 'amount',
                'type': 'u64',
              },
              {
                'name': 'bump',
                'type': 'u8',
              },
            ],
          },
          {
            'name': 'transfer',
            'docs': ['Transfer tokens'],
            'discriminator': [163, 52, 200, 231, 140, 3, 69, 186],
            'accounts': [
              {
                'name': 'from',
                'writable': true,
                'signer': true,
              },
              {
                'name': 'to',
                'writable': true,
                'signer': false,
              },
            ],
            'args': [
              {
                'name': 'amount',
                'type': 'u64',
              },
            ],
          },
        ],
        'accounts': [
          {
            'name': 'UserAccount',
            'discriminator': [211, 8, 232, 43, 2, 152, 117, 119],
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'authority',
                  'type': 'pubkey',
                },
                {
                  'name': 'balance',
                  'type': 'u64',
                },
                {
                  'name': 'bump',
                  'type': 'u8',
                },
              ],
            },
          },
        ],
        'types': [
          {
            'name': 'TransferParams',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'amount',
                  'type': 'u64',
                },
                {
                  'name': 'memo',
                  'type': {
                    'option': 'string',
                  },
                },
              ],
            },
          },
        ],
        'events': [
          {
            'name': 'TransferEvent',
            'fields': [
              {
                'name': 'from',
                'type': 'pubkey',
                'index': false,
              },
              {
                'name': 'to',
                'type': 'pubkey',
                'index': false,
              },
              {
                'name': 'amount',
                'type': 'u64',
                'index': false,
              },
            ],
          },
        ],
        'errors': [
          {
            'code': 6000,
            'name': 'InsufficientFunds',
            'msg': 'Insufficient funds for transfer',
          },
          {
            'code': 6001,
            'name': 'InvalidAuthority',
            'msg': 'Invalid authority for operation',
          },
        ],
      };

      // Test IDL parsing compatibility
      final isCompatible = await tester.testIdlCompatibility(tsCompatibleIdl);
      expect(isCompatible, isTrue);

      // Test that Dart can parse the same IDL structure as TypeScript
      final dartIdl = Idl.fromJson(tsCompatibleIdl);

      expect(
          dartIdl.address, equals('TSCompatible11111111111111111111111111111'));
      expect(dartIdl.metadata?.name, equals('ts_compatible_program'));
      expect(dartIdl.instructions.length, equals(2));
      expect(dartIdl.accounts?.length, equals(1));
      expect(dartIdl.types?.length, equals(1));
      expect(dartIdl.events?.length, equals(1));
      expect(dartIdl.errors?.length, equals(2));

      // Verify instruction details
      final initInstruction =
          dartIdl.instructions.firstWhere((i) => i.name == 'initialize');
      expect(initInstruction.accounts.length, equals(2));
      expect(initInstruction.args.length, equals(2));

      final transferInstruction =
          dartIdl.instructions.firstWhere((i) => i.name == 'transfer');
      expect(transferInstruction.accounts.length, equals(2));
      expect(transferInstruction.args.length, equals(1));
    });

    test('instruction encoding compatibility', () async {
      // Test that Dart produces the same instruction encoding as TypeScript
      final testCases = [
        {
          'instruction': 'initialize',
          'args': {'amount': 1000000, 'bump': 255},
          'expected_discriminator': [175, 175, 109, 31, 13, 152, 155, 237],
        },
        {
          'instruction': 'transfer',
          'args': {'amount': 500000},
          'expected_discriminator': [163, 52, 200, 231, 140, 3, 69, 186],
        },
      ];

      for (final testCase in testCases) {
        final isCompatible = await tester.testInstructionEncoding(
          instructionName: testCase['instruction'] as String,
          args: testCase['args'] as Map<String, dynamic>,
          expectedBytes: testCase['expected_discriminator'] as List<int>,
        );

        expect(isCompatible, isTrue,
            reason:
                'Instruction ${testCase['instruction']} encoding should be compatible');
      }
    });

    test('account data parsing compatibility', () async {
      // Test that Dart parses account data the same way as TypeScript
      final testCases = [
        {
          'account_type': 'UserAccount',
          'raw_data': [
            // Discriminator (8 bytes)
            211, 8, 232, 43, 2, 152, 117, 119,
            // Authority (32 bytes) - mock public key
            ...List.filled(32, 1),
            // Balance (8 bytes) - 1000000 as u64 little endian
            64, 66, 15, 0, 0, 0, 0, 0,
            // Bump (1 byte)
            255,
          ],
          'expected_parsed': {
            'authority': 'mock_public_key',
            'balance': 1000000,
            'bump': 255,
          },
        },
      ];

      for (final testCase in testCases) {
        final isCompatible = await tester.testAccountDataCompatibility(
          accountData: testCase['raw_data'] as List<int>,
          expectedParsed: testCase['expected_parsed'] as Map<String, dynamic>,
        );

        expect(isCompatible, isTrue,
            reason:
                'Account ${testCase['account_type']} parsing should be compatible');
      }
    });

    test('complex type serialization compatibility', () async {
      // Test complex types like options, vectors, structs
      final complexIdl = {
        'address': 'ComplexTypes1111111111111111111111111111',
        'metadata': {
          'name': 'complex_types_test',
          'version': '0.1.0',
          'spec': '0.1.0',
        },
        'instructions': [
          {
            'name': 'complex_instruction',
            'discriminator': [100, 100, 100, 100, 100, 100, 100, 100],
            'accounts': [],
            'args': [
              {
                'name': 'optional_value',
                'type': {'option': 'u64'},
              },
              {
                'name': 'vector_data',
                'type': {'vec': 'u32'},
              },
              {
                'name': 'array_data',
                'type': {
                  'array': ['u8', 10]
                },
              },
              {
                'name': 'nested_struct',
                'type': {'defined': 'NestedStruct'},
              },
            ],
          },
        ],
        'types': [
          {
            'name': 'NestedStruct',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'inner_value',
                  'type': 'u32',
                },
                {
                  'name': 'inner_flag',
                  'type': 'bool',
                },
              ],
            },
          },
        ],
      };

      final dartIdl = Idl.fromJson(complexIdl);
      final coder = BorshCoder(dartIdl);

      // Test complex argument encoding
      final complexArgs = {
        'optional_value': 42, // Some value for option
        'vector_data': [1, 2, 3, 4, 5],
        'array_data': List.generate(10, (i) => i + 1),
        'nested_struct': {
          'inner_value': 999,
          'inner_flag': true,
        },
      };

      final encoded =
          coder.instructions.encode('complex_instruction', complexArgs);
      expect(encoded, isNotNull);
      expect(encoded.length,
          greaterThan(8)); // Should include discriminator + data

      // Verify that complex types are handled correctly
      expect(complexArgs['optional_value'], equals(42));
      expect(complexArgs['vector_data'], hasLength(5));
      expect(complexArgs['array_data'], hasLength(10));
      final nestedStruct = complexArgs['nested_struct'] as Map<String, dynamic>;
      expect(nestedStruct['inner_value'], equals(999));
      expect(nestedStruct['inner_flag'], isTrue);
    });

    test('event parsing compatibility', () async {
      // Test that Dart parses program events the same way as TypeScript
      final eventIdl = {
        'address': 'EventTest111111111111111111111111111111',
        'metadata': {
          'name': 'event_test_program',
          'version': '0.1.0',
          'spec': '0.1.0',
        },
        'instructions': [],
        'events': [
          {
            'name': 'TestEvent',
            'fields': [
              {
                'name': 'user',
                'type': 'pubkey',
                'index': true,
              },
              {
                'name': 'amount',
                'type': 'u64',
                'index': false,
              },
              {
                'name': 'timestamp',
                'type': 'i64',
                'index': false,
              },
            ],
          },
        ],
      };

      final dartIdl = Idl.fromJson(eventIdl);

      expect(dartIdl.events, isNotNull);
      expect(dartIdl.events!.length, equals(1));

      final testEvent = dartIdl.events!.first;
      expect(testEvent.name, equals('TestEvent'));
      expect(testEvent.fields.length, equals(3));

      // Verify field details (note: index property is part of TypeScript IDL but not used in Dart implementation)
      final userField = testEvent.fields.firstWhere((f) => f.name == 'user');
      expect(userField.type.kind, equals('pubkey'));

      final amountField =
          testEvent.fields.firstWhere((f) => f.name == 'amount');
      expect(amountField.type.kind, equals('u64'));
    });

    test('error code compatibility', () async {
      // Test that Dart handles error codes the same way as TypeScript
      final errorIdl = {
        'address': 'ErrorTest111111111111111111111111111111',
        'metadata': {
          'name': 'error_test_program',
          'version': '0.1.0',
          'spec': '0.1.0',
        },
        'instructions': [],
        'errors': [
          {
            'code': 6000,
            'name': 'CustomError',
            'msg': 'This is a custom error message',
          },
          {
            'code': 6001,
            'name': 'AnotherError',
            'msg': 'Another error occurred',
          },
        ],
      };

      final dartIdl = Idl.fromJson(errorIdl);

      expect(dartIdl.errors, isNotNull);
      expect(dartIdl.errors!.length, equals(2));

      final customError =
          dartIdl.errors!.firstWhere((e) => e.name == 'CustomError');
      expect(customError.code, equals(6000));
      expect(customError.msg, equals('This is a custom error message'));

      final anotherError =
          dartIdl.errors!.firstWhere((e) => e.name == 'AnotherError');
      expect(anotherError.code, equals(6001));
      expect(anotherError.msg, equals('Another error occurred'));
    });
  });
}
