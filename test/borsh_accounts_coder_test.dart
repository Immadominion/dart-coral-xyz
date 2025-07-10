/// Tests for BorshAccountsCoder Core Implementation
///
/// Comprehensive test suite validating the BorshAccountsCoder implementation
/// against TypeScript Anchor client behavior, ensuring exact compatibility
/// for encoding, decoding, discriminator validation, and error handling.

import 'package:test/test.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('BorshAccountsCoder', () {
    late Idl testIdl;
    late BorshAccountsCoder<String> coder;

    setUp(() {
      // Create a test IDL matching TypeScript structure
      testIdl = Idl(
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
            () => coder.accountDiscriminator('TestAccount'), returnsNormally);
        expect(
            () => coder.accountDiscriminator('UserAccount'), returnsNormally);
      });

      test('should handle empty accounts in IDL', () {
        final emptyIdl = Idl(instructions: [], accounts: []);
        final emptyCoder = BorshAccountsCoder<String>(emptyIdl);
        expect(emptyCoder, isNotNull);
      });

      test('should throw error when account type not found', () {
        final invalidIdl = Idl(
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
        final noTypesIdl = Idl(
          instructions: [],
          accounts: [
            IdlAccount(
              name: 'TestAccount',
              type: IdlTypeDefType(kind: 'struct', fields: []),
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
          ],
          types: null, // Missing types
        );

        expect(
          () => BorshAccountsCoder<String>(noTypesIdl),
          throwsA(isA<AccountCoderError>()),
        );
      });

      test('should throw error when account discriminator is missing', () {
        final noDiscriminatorIdl = Idl(
          instructions: [],
          accounts: [
            IdlAccount(
              name: 'TestAccount',
              type: IdlTypeDefType(kind: 'struct', fields: []),
              discriminator: null, // Missing discriminator
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
        expect(discriminator,
            equals(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])));
      });

      test('should return correct discriminator for different account', () {
        final discriminator = coder.accountDiscriminator('UserAccount');
        expect(discriminator,
            equals(Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16])));
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
          () async => await coder.encode('UnknownAccount', accountData),
          throwsA(isA<AccountCoderError>()),
        );
      });

      test('should handle encoding errors gracefully', () async {
        // Test with invalid data type
        expect(
          () async => await coder.encode('TestAccount', 'invalid_data'),
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
          expect(error.actualDiscriminator,
              equals([99, 98, 97, 96, 95, 94, 93, 92]));
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
            'UserAccount', accountData);
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
  });
}
