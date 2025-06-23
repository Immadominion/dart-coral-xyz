import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('InstructionCoder Tests', () {
    late Idl testIdl;
    late BorshInstructionCoder coder;

    setUp(() {
      testIdl = Idl(
        address: 'Test111111111111111111111111111111111111111',
        metadata: const IdlMetadata(
          name: 'test',
          version: '0.0.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            discriminator: [0, 1, 2, 3, 4, 5, 6, 7],
            accounts: [
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'user',
                writable: true, // Changed from isMut
                signer: true, // Changed from isSigner
              ),
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'program',
                writable: false, // Changed from isMut
                signer: false, // Changed from isSigner
              ),
            ],
            args: [
              IdlField(
                name: 'amount',
                type: const IdlType(kind: 'u64'), // Changed
              ),
              IdlField(
                name: 'name',
                type: const IdlType(kind: 'string'), // Changed
              ),
            ],
          ),
          IdlInstruction(
            name: 'update',
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            accounts: [
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'authority',
                writable: false, // Changed from isMut
                signer: true, // Changed from isSigner
              ),
            ],
            args: [
              IdlField(
                name: 'newValue',
                type: const IdlType(kind: 'u32'), // Changed
              ),
            ],
          ),
          IdlInstruction(
            name: 'complexTypes',
            discriminator: [2, 3, 4, 5, 6, 7, 8, 9],
            accounts: [],
            args: [
              IdlField(
                name: 'optionalField',
                type: const IdlType(
                    kind: 'option', inner: IdlType(kind: 'u8')), // Changed
              ),
              IdlField(
                name: 'vector',
                type: const IdlType(
                    kind: 'vec', inner: IdlType(kind: 'string')), // Changed
              ),
              IdlField(
                name: 'array',
                type: const IdlType(
                    kind: 'array',
                    inner: IdlType(kind: 'u16'),
                    size: 3), // Changed
              ),
            ],
          ),
        ],
        accounts: [],
        types: [],
      );

      coder = BorshInstructionCoder(testIdl);
    });

    group('Instruction Encoding', () {
      test('should encode simple instruction correctly', () {
        final instructionData = {
          'amount': 12345,
          'name': 'test_name',
        };

        final encoded = coder.encode('initialize', instructionData);

        // Should start with discriminator
        expect(encoded.sublist(0, 8), equals([0, 1, 2, 3, 4, 5, 6, 7]));
        expect(encoded.length, greaterThan(8));
      });

      test('should encode instruction with complex types', () {
        final instructionData = {
          'optionalField': 42,
          'vector': ['hello', 'world'],
          'array': [100, 200, 300],
        };

        final encoded = coder.encode('complexTypes', instructionData);

        // Should start with discriminator
        expect(encoded.sublist(0, 8), equals([2, 3, 4, 5, 6, 7, 8, 9]));
        expect(encoded.length, greaterThan(8));
      });

      test('should encode instruction with null optional field', () {
        final instructionData = {
          'optionalField': null,
          'vector': ['single'],
          'array': [1, 2, 3],
        };

        final encoded = coder.encode('complexTypes', instructionData);

        // Should start with discriminator
        expect(encoded.sublist(0, 8), equals([2, 3, 4, 5, 6, 7, 8, 9]));
        expect(encoded.length, greaterThan(8));
      });

      test('should throw on unknown instruction', () {
        expect(
          () => coder.encode('unknown', {}),
          throwsA(isA<InstructionCoderException>()),
        );
      });

      test('should throw on missing required argument', () {
        final instructionData = {
          'amount': 12345,
          // missing 'name' field
        };

        expect(
          () => coder.encode('initialize', instructionData),
          throwsA(isA<InstructionCoderException>()),
        );
      });

      test('should throw on array size mismatch', () {
        final instructionData = {
          'optionalField': null,
          'vector': ['test'],
          'array': [1, 2], // should be 3 elements
        };

        expect(
          () => coder.encode('complexTypes', instructionData),
          throwsA(isA<InstructionCoderException>()),
        );
      });
    });

    group('Instruction Decoding', () {
      test('should decode simple instruction correctly', () {
        final originalData = {
          'amount': 12345,
          'name': 'test_name',
        };

        final encoded = coder.encode('initialize', originalData);
        final decoded = coder.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.name, equals('initialize'));
        expect(decoded.data['amount'], equals(12345));
        expect(decoded.data['name'], equals('test_name'));
      });

      test('should decode instruction with complex types', () {
        final originalData = {
          'optionalField': 42,
          'vector': ['hello', 'world'],
          'array': [100, 200, 300],
        };

        final encoded = coder.encode('complexTypes', originalData);
        final decoded = coder.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.name, equals('complexTypes'));
        expect(decoded.data['optionalField'], equals(42));
        expect(decoded.data['vector'], equals(['hello', 'world']));
        expect(decoded.data['array'], equals([100, 200, 300]));
      });

      test('should decode instruction with null optional field', () {
        final originalData = {
          'optionalField': null,
          'vector': ['single'],
          'array': [1, 2, 3],
        };

        final encoded = coder.encode('complexTypes', originalData);
        final decoded = coder.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.name, equals('complexTypes'));
        expect(decoded.data['optionalField'], isNull);
        expect(decoded.data['vector'], equals(['single']));
        expect(decoded.data['array'], equals([1, 2, 3]));
      });

      test('should return null for unrecognized instruction', () {
        final unknownData =
            Uint8List.fromList([99, 98, 97, 96, 95, 94, 93, 92]);
        final decoded = coder.decode(unknownData);
        expect(decoded, isNull);
      });

      test('should return null for empty data', () {
        final emptyData = Uint8List(0);
        final decoded = coder.decode(emptyData);
        expect(decoded, isNull);
      });

      test('should handle partial data gracefully', () {
        // Create data with discriminator but no instruction data
        final partialData = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
        final decoded = coder.decode(partialData);

        // Should return a decoded instruction with empty or default data
        expect(decoded, isNull);
      });
    });

    group('Instruction Formatting', () {
      test('should format instruction with accounts correctly', () {
        final instruction = Instruction(
          name: 'initialize',
          data: {
            'amount': 12345,
            'name': 'test_name',
          },
        );

        final accountMetas = [
          AccountMeta(
            pubkey: PublicKey.fromBase58(
                'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'),
            isSigner: true,
            isWritable: true,
          ),
          AccountMeta(
            pubkey: PublicKey.fromBase58(
                'So11111111111111111111111111111111111111112'),
            isSigner: false,
            isWritable: false,
          ),
        ];

        final formatted = coder.format(instruction, accountMetas);

        expect(formatted, isNotNull);
        expect(formatted!.args.length, equals(2));
        expect(formatted.args[0].name, equals('amount'));
        expect(formatted.args[0].type, equals('u64'));
        expect(formatted.args[0].data, equals('12345'));
        expect(formatted.args[1].name, equals('name'));
        expect(formatted.args[1].type, equals('string'));
        expect(formatted.args[1].data, equals('test_name'));

        expect(formatted.accounts.length, equals(2));
        expect(formatted.accounts[0].name, equals('user'));
        expect(formatted.accounts[0].pubkey,
            equals('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'));
        expect(formatted.accounts[0].isSigner, isTrue);
        expect(formatted.accounts[0].isWritable, isTrue);
        expect(formatted.accounts[1].name, equals('program'));
        expect(formatted.accounts[1].pubkey,
            equals('So11111111111111111111111111111111111111112'));
        expect(formatted.accounts[1].isSigner, isFalse);
        expect(formatted.accounts[1].isWritable, isFalse);
      });

      test('should format instruction with extra accounts', () {
        final instruction = Instruction(
          name: 'update',
          data: {
            'newValue': 999,
          },
        );

        final accountMetas = [
          AccountMeta(
            pubkey: PublicKey.fromBase58('11111111111111111111111111111112'),
            isSigner: true,
            isWritable: false,
          ),
          AccountMeta(
            pubkey: PublicKey.fromBase58(
                'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
            isSigner: false,
            isWritable: true,
          ),
        ];

        final formatted = coder.format(instruction, accountMetas);

        expect(formatted, isNotNull);
        expect(formatted!.accounts.length, equals(2));
        expect(formatted.accounts[0].name, equals('authority'));
        expect(formatted.accounts[1].name, isNull); // Extra account has no name
      });

      test('should throw on unknown instruction for formatting', () {
        final instruction = Instruction(
          name: 'unknown',
          data: {},
        );

        expect(
          () => coder.format(instruction, []),
          throwsA(isA<InstructionCoderException>()),
        );
      });

      test('should format complex types correctly', () {
        final instruction = Instruction(
          name: 'complexTypes',
          data: {
            'optionalField': 42,
            'vector': ['hello', 'world'],
            'array': [100, 200, 300],
          },
        );

        final formatted = coder.format(instruction, []);

        expect(formatted, isNotNull);
        expect(formatted!.args.length, equals(3));
        expect(formatted.args[0].name, equals('optionalField'));
        expect(formatted.args[0].type, equals('Option<u8>'));
        expect(formatted.args[1].name, equals('vector'));
        expect(formatted.args[1].type, equals('Vec<string>'));
        expect(formatted.args[2].name, equals('array'));
        expect(formatted.args[2].type, equals('Array<u16; 3>'));
      });
    });

    group('Round Trip Tests', () {
      test('should encode and decode successfully', () {
        final originalData = {
          'amount': 999999,
          'name': 'round_trip_test',
        };

        final encoded = coder.encode('initialize', originalData);
        final decoded = coder.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.name, equals('initialize'));
        expect(decoded.data, equals(originalData));
      });

      test('should handle all supported primitive types', () {
        // Create a test IDL with all primitive types
        final primitiveIdl = Idl(
          address: 'Primitive111111111111111111111111111111111',
          metadata: IdlMetadata(
            name: 'primitive_test',
            version: '0.0.0',
            spec: '0.1.0',
          ),
          instructions: [
            IdlInstruction(
              name: 'testPrimitives',
              discriminator: [10, 11, 12, 13, 14, 15, 16, 17],
              accounts: [],
              args: [
                IdlField(
                    name: 'boolVal',
                    type: const IdlType(kind: 'bool')), // Changed
                IdlField(
                    name: 'u8Val', type: const IdlType(kind: 'u8')), // Changed
                IdlField(
                    name: 'i8Val', type: const IdlType(kind: 'i8')), // Changed
                IdlField(
                    name: 'u16Val',
                    type: const IdlType(kind: 'u16')), // Changed
                IdlField(
                    name: 'i16Val',
                    type: const IdlType(kind: 'i16')), // Changed
                IdlField(
                    name: 'u32Val',
                    type: const IdlType(kind: 'u32')), // Changed
                IdlField(
                    name: 'i32Val',
                    type: const IdlType(kind: 'i32')), // Changed
                IdlField(
                    name: 'u64Val',
                    type: const IdlType(kind: 'u64')), // Changed
                IdlField(
                    name: 'i64Val',
                    type: const IdlType(kind: 'i64')), // Changed
                IdlField(
                    name: 'stringVal',
                    type: const IdlType(kind: 'string')), // Changed
                IdlField(
                    name: 'pubkeyVal',
                    type: const IdlType(kind: 'pubkey')), // Changed
              ],
            ),
          ],
          accounts: [],
          types: [],
        );

        final primitiveCoder = BorshInstructionCoder(primitiveIdl);

        final primitiveData = {
          'boolVal': true,
          'u8Val': 255,
          'i8Val': -128,
          'u16Val': 65535,
          'i16Val': -32768,
          'u32Val': 4294967295,
          'i32Val': -2147483648,
          'u64Val': 9223372036854775807,
          'i64Val': -9223372036854775808,
          'stringVal': 'hello world',
          'pubkeyVal': 'PublicKey111111111111111111111111111111111',
        };

        final encoded = primitiveCoder.encode('testPrimitives', primitiveData);
        final decoded = primitiveCoder.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded!.name, equals('testPrimitives'));
        expect(decoded.data, equals(primitiveData));
      });
    });

    group('Error Handling', () {
      test('should provide meaningful error messages', () {
        try {
          coder.encode('nonexistent', {});
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<InstructionCoderException>());
          expect(e.toString(), contains('Unknown instruction: nonexistent'));
        }
      });

      test('should handle encoding errors gracefully', () {
        final invalidData = {
          'amount': 'not_a_number', // Should be int
          'name': 'test_name',
        };

        expect(
          () => coder.encode('initialize', invalidData),
          throwsA(isA<InstructionCoderException>()),
        );
      });
    });

    group('Discriminator Validation', () {
      test('should validate discriminators during decode', () {
        // Create data with valid discriminator for 'initialize'
        final validData = {
          'amount': 12345,
          'name': 'test',
        };
        final encoded = coder.encode('initialize', validData);

        // Decode should work
        final decoded = coder.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.name, equals('initialize'));

        // Modify discriminator to make it invalid
        final modifiedData = Uint8List.fromList(encoded);
        modifiedData[0] = 99; // Change first byte of discriminator

        // Should return null for invalid discriminator
        final decodedInvalid = coder.decode(modifiedData);
        expect(decodedInvalid, isNull);
      });
    });
  });
}
