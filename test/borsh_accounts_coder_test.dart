/// Tests for BorshAccountsCoder Core Implementation
///
/// Comprehensive test suite validating the BorshAccountsCoder implementation
/// against TypeScript Anchor client behavior, ensuring exact compatibility
/// for encoding, decoding, discriminator validation, and error handling.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz_anchor.dart';
import 'package:test/test.dart';

void main() {
  group('BorshAccountsCoder', () {
    late Idl testIdl;
    late BorshAccountsCoder<String> coder;

    setUp(() {
      // Create a test IDL matching TypeScript structure
      testIdl = const Idl(
        instructions: [],
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'id', type: IdlType(kind: 'u64')),
                IdlField(name: 'name', type: IdlType(kind: 'string')),
                IdlField(name: 'isActive', type: IdlType(kind: 'bool')),
              ],
            ),
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8], // 8-byte discriminator
          ),
          IdlAccount(
            name: 'UserAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'userId', type: IdlType(kind: 'u32')),
                IdlField(name: 'balance', type: IdlType(kind: 'u64')),
              ],
            ),
            discriminator: [9, 10, 11, 12, 13, 14, 15, 16],
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'TestAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'id', type: IdlType(kind: 'u64')),
                IdlField(name: 'name', type: IdlType(kind: 'string')),
                IdlField(name: 'isActive', type: IdlType(kind: 'bool')),
              ],
            ),
          ),
          IdlTypeDef(
            name: 'UserAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'userId', type: IdlType(kind: 'u32')),
                IdlField(name: 'balance', type: IdlType(kind: 'u64')),
              ],
            ),
          ),
        ],
      );

      coder = BorshAccountsCoder<String>(testIdl);
    });

    group('Constructor and Layout Building', () {
      test('should create coder successfully with valid IDL', () {
        expect(coder, isNotNull);

        // Test that basic operations work to verify layouts were built
        expect(
          () => coder.accountDiscriminator('TestAccount'),
          returnsNormally,
        );
        expect(
          () => coder.accountDiscriminator('UserAccount'),
          returnsNormally,
        );
      });

      test('should handle empty accounts in IDL', () {
        final emptyIdl = const Idl(instructions: [], accounts: []);
        final emptyCoder = BorshAccountsCoder<String>(emptyIdl);
        expect(emptyCoder, isNotNull);
      });

      test('should throw error when account type not found', () {
        final invalidIdl = const Idl(
          instructions: [],
          accounts: [
            IdlAccount(
              name: 'TestAccount',
              type: IdlTypeDefType(kind: 'struct', fields: []),
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
          ],
          types: [], // No matching type definition
        );

        expect(
          () => BorshAccountsCoder<String>(invalidIdl),
          throwsA(isA<AccountCoderError>()),
        );
      });

      test('should throw error when types are missing', () {
        final noTypesIdl = const Idl(
          instructions: [],
          accounts: [
            IdlAccount(
              name: 'TestAccount',
              type: IdlTypeDefType(kind: 'struct', fields: []),
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
          ],
        );

        expect(
          () => BorshAccountsCoder<String>(noTypesIdl),
          throwsA(isA<AccountCoderError>()),
        );
      });

      test('should throw error when account discriminator is missing', () {
        final noDiscriminatorIdl = const Idl(
          instructions: [],
          accounts: [
            IdlAccount(
              name: 'TestAccount',
              type: IdlTypeDefType(kind: 'struct', fields: []),
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'TestAccount',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [],
              ),
            ),
          ],
        );

        expect(
          () => BorshAccountsCoder<String>(noDiscriminatorIdl),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Account Discriminator', () {
      test('should return correct discriminator for account', () {
        final discriminator = coder.accountDiscriminator('TestAccount');
        expect(
          discriminator,
          equals(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
        );
      });

      test('should return correct discriminator for different account', () {
        final discriminator = coder.accountDiscriminator('UserAccount');
        expect(
          discriminator,
          equals(Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16])),
        );
      });

      test('should throw error for unknown account', () {
        expect(
          () => coder.accountDiscriminator('UnknownAccount'),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Encoding', () {
      test('should encode simple account data', () async {
        final accountData = {
          'id': 123,
          'name': 'test',
          'isActive': true,
        };

        final encoded = await coder.encode('TestAccount', accountData);

        // Should start with discriminator
        expect(encoded.sublist(0, 8), equals([1, 2, 3, 4, 5, 6, 7, 8]));
        expect(encoded.length, greaterThan(8));
      });

      test('should throw error for unknown account name', () async {
        final accountData = {'id': 123};

        expect(
          () async => coder.encode('UnknownAccount', accountData),
          throwsA(isA<AccountCoderError>()),
        );
      });

      test('should handle encoding errors gracefully', () async {
        // Test with invalid data type
        expect(
          () async => coder.encode('TestAccount', 'invalid_data'),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Decoding with Discriminator Validation', () {
      test('should decode valid account data', () {
        final testData = {
          'id': 456,
          'name': 'decoded_test',
          'isActive': false,
        };
        final jsonStr = jsonEncode(testData);
        final jsonBytes = utf8.encode(jsonStr);
        final discriminator = [1, 2, 3, 4, 5, 6, 7, 8];
        final accountData =
            Uint8List.fromList([...discriminator, ...jsonBytes]);

        final decoded =
            coder.decode<Map<String, dynamic>>('TestAccount', accountData);
        expect(decoded, isA<Map<String, dynamic>>());
      });

      test('should throw error for invalid discriminator', () {
        final jsonBytes = utf8.encode('{}');
        final wrongDiscriminator = [99, 98, 97, 96, 95, 94, 93, 92];
        final accountData =
            Uint8List.fromList([...wrongDiscriminator, ...jsonBytes]);

        expect(
          () => coder.decode('TestAccount', accountData),
          throwsA(isA<AccountDiscriminatorMismatchError>()),
        );
      });

      test('should throw error for data too short for discriminator', () {
        final shortData = Uint8List.fromList([1, 2, 3]); // Only 3 bytes

        expect(
          () => coder.decode('TestAccount', shortData),
          throwsA(isA<AccountDiscriminatorMismatchError>()),
        );
      });

      test(
          'should provide detailed error information for discriminator mismatch',
          () {
        final jsonBytes = utf8.encode('{}');
        final wrongDiscriminator = [99, 98, 97, 96, 95, 94, 93, 92];
        final accountData =
            Uint8List.fromList([...wrongDiscriminator, ...jsonBytes]);

        try {
          coder.decode('TestAccount', accountData);
          fail('Expected AccountDiscriminatorMismatchError');
        } catch (e) {
          expect(e, isA<AccountDiscriminatorMismatchError>());
          final error = e as AccountDiscriminatorMismatchError;
          expect(error.expectedDiscriminator, equals([1, 2, 3, 4, 5, 6, 7, 8]));
          expect(
            error.actualDiscriminator,
            equals([99, 98, 97, 96, 95, 94, 93, 92]),
          );
        }
      });
    });

    group('Unchecked Decoding', () {
      test('should decode without discriminator validation', () {
        final testData = {'userId': 789, 'balance': 1000};
        final jsonStr = jsonEncode(testData);
        final jsonBytes = utf8.encode(jsonStr);
        final discriminator = [9, 10, 11, 12, 13, 14, 15, 16];
        final accountData =
            Uint8List.fromList([...discriminator, ...jsonBytes]);

        final decoded = coder.decodeUnchecked<Map<String, dynamic>>(
          'UserAccount',
          accountData,
        );
        expect(decoded, isA<Map<String, dynamic>>());
      });

      test('should handle decoding errors gracefully', () {
        final discriminator = [1, 2, 3, 4, 5, 6, 7, 8];
        final invalidData = [255, 254, 253]; // Invalid data
        final accountData =
            Uint8List.fromList([...discriminator, ...invalidData]);

        expect(
          () => coder.decodeUnchecked('TestAccount', accountData),
          throwsA(isA<AccountDidNotDeserializeError>()),
        );
      });

      test('should throw error for unknown account name in unchecked decode',
          () {
        final accountData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

        expect(
          () => coder.decodeUnchecked('UnknownAccount', accountData),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Decode Any', () {
      test('should decode account by matching discriminator', () {
        final testData = {'userId': 555, 'balance': 2000};
        final jsonStr = jsonEncode(testData);
        final jsonBytes = utf8.encode(jsonStr);
        final userDiscriminator = [9, 10, 11, 12, 13, 14, 15, 16];
        final accountData =
            Uint8List.fromList([...userDiscriminator, ...jsonBytes]);

        final decoded = coder.decodeAny<Map<String, dynamic>>(accountData);
        expect(decoded, isA<Map<String, dynamic>>());
      });

      test('should try all account types until match found', () {
        final testData = {'id': 111, 'name': 'test', 'isActive': true};
        final jsonStr = jsonEncode(testData);
        final jsonBytes = utf8.encode(jsonStr);
        final testDiscriminator = [1, 2, 3, 4, 5, 6, 7, 8];
        final accountData =
            Uint8List.fromList([...testDiscriminator, ...jsonBytes]);

        final decoded = coder.decodeAny<Map<String, dynamic>>(accountData);
        expect(decoded, isA<Map<String, dynamic>>());
      });

      test('should throw error when no discriminator matches', () {
        final unknownDiscriminator = [255, 254, 253, 252, 251, 250, 249, 248];
        final jsonBytes = utf8.encode('{}');
        final accountData =
            Uint8List.fromList([...unknownDiscriminator, ...jsonBytes]);

        expect(
          () => coder.decodeAny(accountData),
          throwsA(isA<AccountCoderError>()),
        );
      });

      test('should handle data too short for any discriminator', () {
        final shortData = Uint8List.fromList([1, 2, 3]); // Only 3 bytes

        expect(
          () => coder.decodeAny(shortData),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Memcmp Filter', () {
      test('should create correct memcmp filter', () {
        final filter = coder.memcmp('TestAccount');

        expect(filter['offset'], equals(0));
        expect(filter['bytes'], isA<String>());

        // Decode base64 and verify it contains the discriminator
        final bytes = base64.decode(filter['bytes'] as String);
        expect(bytes, equals([1, 2, 3, 4, 5, 6, 7, 8]));
      });

      test('should create memcmp filter with additional data', () {
        final appendData = Uint8List.fromList([100, 101, 102]);
        final filter = coder.memcmp('UserAccount', appendData: appendData);

        expect(filter['offset'], equals(0));

        final bytes = base64.decode(filter['bytes'] as String);
        final expected = [9, 10, 11, 12, 13, 14, 15, 16, 100, 101, 102];
        expect(bytes, equals(expected));
      });

      test('should throw error for unknown account in memcmp', () {
        expect(
          () => coder.memcmp('UnknownAccount'),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Size Calculation', () {
      test('should return size including discriminator', () {
        final size = coder.size('TestAccount');
        expect(size, greaterThanOrEqualTo(8)); // At least discriminator size
        expect(size, equals(1008)); // 8 bytes discriminator + 1000 bytes buffer
      });

      test('should throw error for unknown account in size calculation', () {
        expect(
          () => coder.size('UnknownAccount'),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });

    group('Integration with TypeScript Behavior', () {
      test('should match TypeScript encode/decode roundtrip', () async {
        final originalData = {
          'id': 42,
          'name': 'integration_test',
          'isActive': true,
        };

        // Encode data
        final encoded = await coder.encode('TestAccount', originalData);

        // Decode data
        final decoded =
            coder.decode<Map<String, dynamic>>('TestAccount', encoded);

        // Should successfully roundtrip
        expect(decoded, isA<Map<String, dynamic>>());
      });

      test('should handle TypeScript-style discriminator mismatch errors', () {
        // Simulate TypeScript discriminator mismatch scenario
        final wrongData = Uint8List.fromList([
          255, 254, 253, 252, 251, 250, 249, 248, // Wrong discriminator
          123, 125, // Some JSON-like data
        ]);

        try {
          coder.decode('TestAccount', wrongData);
          fail('Expected discriminator mismatch error');
        } catch (e) {
          expect(e, isA<AccountDiscriminatorMismatchError>());
          expect(e.toString(), contains('discriminator'));
        }
      });

      test('should provide TypeScript-compatible error messages', () {
        try {
          coder.accountDiscriminator('NonExistentAccount');
          fail('Expected AccountCoderError');
        } catch (e) {
          expect(e, isA<AccountCoderError>());
          expect(e.toString(), contains('Account not found'));
        }
      });
    });

    group('Generic Borsh Decoding', () {
      late BorshAccountsCoder<String> complexCoder;

      setUp(() {
        // Create an IDL with complex types similar to a voting program
        final complexIdl = const Idl(
          instructions: [],
          accounts: [
            // Inline account type definition (like Poll)
            IdlAccount(
              name: 'Poll',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'finished', type: IdlType(kind: 'bool')),
                  IdlField(name: 'title', type: IdlType(kind: 'string')),
                  IdlField(name: 'voteCount', type: IdlType(kind: 'u64')),
                  IdlField(
                    name: 'options',
                    type: IdlType(
                      kind: 'vec',
                      inner: IdlType(kind: 'defined', defined: 'PollOption'),
                    ),
                  ),
                ],
              ),
            ),
            // Counter account for compatibility testing
            IdlAccount(
              name: 'Counter',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'count', type: IdlType(kind: 'u64')),
                  IdlField(name: 'bump', type: IdlType(kind: 'u8')),
                ],
              ),
            ),
          ],
          types: [
            // Separate type definition referenced by Poll
            IdlTypeDef(
              name: 'PollOption',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'name', type: IdlType(kind: 'string')),
                  IdlField(name: 'votes', type: IdlType(kind: 'u32')),
                ],
              ),
            ),
          ],
        );

        complexCoder = BorshAccountsCoder<String>(complexIdl);
      });

      test('should decode inline account type (Poll) correctly', () async {
        // Create test data for a Poll account
        final pollData = {
          'finished': false,
          'title': 'Test Poll',
          'voteCount': BigInt.from(42),
          'options': [
            {'name': 'Option A', 'votes': 10},
            {'name': 'Option B', 'votes': 32},
          ],
        };

        // Encode and decode to test roundtrip
        final encoded = await complexCoder.encode('Poll', pollData);
        final decoded = complexCoder.decodeUnchecked<Map<String, dynamic>>('Poll', encoded);

        expect(decoded['finished'], equals(false));
        expect(decoded['title'], equals('Test Poll'));
        expect(decoded['voteCount'], equals(BigInt.from(42)));
        expect(decoded['options'], isA<List>());
        expect((decoded['options'] as List).length, equals(2));
        expect((decoded['options'] as List)[0]['name'], equals('Option A'));
        expect((decoded['options'] as List)[0]['votes'], equals(10));
      });

      test('should decode separate type definition (Counter) correctly', () async {
        // Create test data for a Counter account
        final counterData = {
          'count': BigInt.from(100),
          'bump': 255,
        };

        // Encode and decode to test roundtrip
        final encoded = await complexCoder.encode('Counter', counterData);
        final decoded = complexCoder.decodeUnchecked<Map<String, dynamic>>('Counter', encoded);

        expect(decoded['count'], equals(BigInt.from(100)));
        expect(decoded['bump'], equals(255));
      });

      test('should handle nested defined types correctly', () async {
        // Test that PollOption type can be resolved from Poll's vec<defined<PollOption>>
        final pollWithComplexOptions = {
          'finished': true,
          'title': 'Complex Poll',
          'voteCount': BigInt.from(1000),
          'options': [
            {'name': 'First Option', 'votes': 250},
            {'name': 'Second Option', 'votes': 300},
            {'name': 'Third Option', 'votes': 450},
          ],
        };

        final encoded = await complexCoder.encode('Poll', pollWithComplexOptions);
        final decoded = complexCoder.decodeUnchecked<Map<String, dynamic>>('Poll', encoded);

        expect(decoded['finished'], equals(true));
        expect(decoded['title'], equals('Complex Poll'));
        expect(decoded['voteCount'], equals(BigInt.from(1000)));
        
        final options = decoded['options'] as List;
        expect(options.length, equals(3));
        expect(options[0]['name'], equals('First Option'));
        expect(options[0]['votes'], equals(250));
        expect(options[2]['name'], equals('Third Option'));
        expect(options[2]['votes'], equals(450));
      });

      test('should handle discriminator validation for complex types', () async {
        // Create valid Poll data
        final pollData = {
          'finished': false,
          'title': 'Valid Poll',
          'voteCount': BigInt.from(5),
          'options': <Map<String, dynamic>>[],
        };

        final encoded = await complexCoder.encode('Poll', pollData);
        
        // Should decode successfully with correct discriminator
        expect(
          () => complexCoder.decode<Map<String, dynamic>>('Poll', encoded),
          returnsNormally,
        );

        // Should fail with wrong account type
        expect(
          () => complexCoder.decode<Map<String, dynamic>>('Counter', encoded),
          throwsA(isA<AccountDiscriminatorMismatchError>()),
        );
      });

      test('should handle empty vectors correctly', () async {
        final pollWithNoOptions = {
          'finished': false,
          'title': 'Empty Poll',
          'voteCount': BigInt.zero,
          'options': <Map<String, dynamic>>[],
        };

        final encoded = await complexCoder.encode('Poll', pollWithNoOptions);
        final decoded = complexCoder.decodeUnchecked<Map<String, dynamic>>('Poll', encoded);

        expect(decoded['title'], equals('Empty Poll'));
        expect(decoded['options'], isA<List>());
        expect((decoded['options'] as List).isEmpty, isTrue);
      });

      test('should provide meaningful error for invalid field types', () async {
        final invalidPollData = {
          'finished': 'not a boolean', // Wrong type
          'title': 'Invalid Poll',
          'voteCount': BigInt.from(10),
          'options': <Map<String, dynamic>>[],
        };

        expect(
          () async => await complexCoder.encode('Poll', invalidPollData),
          throwsA(isA<AccountCoderError>()),
        );
      });
    });
  });
}
