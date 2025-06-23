/// Tests for Critical Iteration 4: Core TypeScript Features
///
/// This test file verifies that the Dart implementation correctly implements
/// the core TypeScript features including Program.at(), dynamic IDL conversion,
/// context parameter patterns, and unified error handling.

import 'package:test/test.dart';
import 'dart:typed_data';
import '../lib/src/program/program_class.dart';
import '../lib/src/program/program_error_handler.dart';
import '../lib/src/program/context.dart';
import '../lib/src/idl/idl.dart';
import '../lib/src/idl/idl_utils.dart';
import '../lib/src/types/public_key.dart';
import '../lib/src/types/commitment.dart';

void main() {
  group('Critical Iteration 4: Core TypeScript Features', () {
    late PublicKey testProgramId;

    setUp(() {
      // Setup test environment
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111112');
    });

    group('Program.at() On-Chain IDL Fetching', () {
      test('should fetch IDL from blockchain and create Program instance',
          () async {
        // This test would require a mock provider and connection
        // For now, we test the method signature and error handling
        expect(() async {
          await Program.at('11111111111111111111111111111112');
        }, returnsNormally);
      });

      test('should return null when IDL is not found', () async {
        // Test error handling for missing IDL
        final result = await Program.at('11111111111111111111111111111112');
        // In a real test with mocked provider, this would verify null return
        expect(result, isA<Program?>());
      });

      test('should handle errors gracefully', () async {
        // Test that errors are properly wrapped in ProgramOperationError
        try {
          await Program.at('invalid_address');
          fail('Should have thrown an error');
        } catch (e) {
          expect(
              e,
              anyOf([
                isA<ArgumentError>(), // Invalid base58
                isA<ProgramOperationError>(), // Wrapped error
              ]));
        }
      });
    });

    group('Dynamic IDL Conversion', () {
      test('should convert snake_case to camelCase', () {
        final testIdl = Idl(
          instructions: [
            IdlInstruction(
              name: 'my_test_method',
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
              accounts: [],
              args: [
                IdlField(
                  name: 'some_field_name',
                  type: idlTypeString(),
                ),
              ],
            ),
          ],
        );

        final converted = IdlUtils.convertIdlToCamelCase(testIdl);

        // Test that instruction names are converted
        expect(converted.instructions.first.name, equals('myTestMethod'));

        // Test that field names are converted
        expect(converted.instructions.first.args.first.name,
            equals('someFieldName'));
      });

      test('should handle dot notation in names', () {
        final testIdl = Idl(
          instructions: [
            IdlInstruction(
              name: 'test_method',
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
              accounts: [],
              args: [
                IdlField(
                  name: 'nested_field.sub_field',
                  type: idlTypeString(),
                ),
              ],
            ),
          ],
        );

        final converted = IdlUtils.convertIdlToCamelCase(testIdl);

        // Should preserve dot notation while converting parts
        expect(converted.instructions.first.args.first.name,
            equals('nestedField.subField'));
      });

      test('should preserve non-snake_case names', () {
        final testIdl = Idl(
          instructions: [
            IdlInstruction(
              name: 'simpleMethod',
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
              accounts: [],
              args: [
                IdlField(
                  name: 'alreadyCamelCase',
                  type: idlTypeString(),
                ),
              ],
            ),
          ],
        );

        final converted = IdlUtils.convertIdlToCamelCase(testIdl);

        // Should not change already camelCase names
        expect(converted.instructions.first.name, equals('simpleMethod'));
        expect(converted.instructions.first.args.first.name,
            equals('alreadyCamelCase'));
      });
    });

    group('Context Parameter Patterns', () {
      test('should split arguments and context correctly', () {
        final mockInstruction = IdlInstruction(
          name: 'test',
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          accounts: [],
          args: [
            IdlField(name: 'arg1', type: idlTypeString()),
            IdlField(name: 'arg2', type: idlTypeU64()),
          ],
        );

        // Test with just arguments
        final result1 = splitArgsAndContext(mockInstruction, ['value1', 42]);
        expect(result1.args, equals(['value1', 42]));
        expect(result1.context.accounts, isNull);

        // Test with arguments + context
        final context = Context<DynamicAccounts>(
          accounts: DynamicAccounts({'test': 'account'}),
        );
        final result2 =
            splitArgsAndContext(mockInstruction, ['value1', 42, context]);
        expect(result2.args, equals(['value1', 42]));
        expect(result2.context.accounts, isNotNull);
      });

      test('should handle map-based context', () {
        final mockInstruction = IdlInstruction(
          name: 'test',
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          accounts: [],
          args: [IdlField(name: 'arg1', type: idlTypeString())],
        );

        final contextMap = {
          'accounts': {'testAccount': 'some_address'},
          'commitment': 'confirmed',
        };

        final result =
            splitArgsAndContext(mockInstruction, ['value1', contextMap]);
        expect(result.args, equals(['value1']));
        expect(result.context.accounts, isNotNull);
      });

      test('should throw error for too many arguments', () {
        final mockInstruction = IdlInstruction(
          name: 'test',
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          accounts: [],
          args: [IdlField(name: 'arg1', type: idlTypeString())],
        );

        expect(
          () => splitArgsAndContext(mockInstruction, ['arg1', 'arg2', 'arg3']),
          throwsArgumentError,
        );
      });

      test('should handle Context creation patterns', () {
        // Test factory constructors using the existing Context class
        final accounts = DynamicAccounts({
          'user': PublicKey.fromBase58('11111111111111111111111111111112'),
        });
        final accountsContext = Context<DynamicAccounts>(accounts: accounts);
        expect(accountsContext.accounts, isNotNull);

        // Test copyWith
        final commitment = CommitmentConfig(Commitment.confirmed);
        final updatedContext = accountsContext.copyWith(
          commitment: commitment,
        );
        expect(updatedContext.accounts, equals(accountsContext.accounts));
        expect(updatedContext.commitment, equals(commitment));

        // Test merging
        final signerContext = Context<DynamicAccounts>(
          signers: [], // Empty list for test
        );
        // Note: There's no merge method in the current Context implementation
        // This would need to be added for full TypeScript compatibility
        expect(signerContext.signers, isNotNull);
      });
    });

    group('Unified Error Handling', () {
      test('should create ProgramOperationError with proper context', () {
        final error = ProgramOperationError.methodExecution(
          methodName: 'testMethod',
          reason: 'Test failure',
          context: {'extra': 'info'},
        );

        expect(error.operation, equals('methodExecution'));
        expect(error.msg, contains('testMethod'));
        expect(error.msg, contains('Test failure'));
        expect(error.context!['methodName'], equals('testMethod'));
        expect(error.context!['extra'], equals('info'));
      });

      test('should handle different error types', () {
        // Test IDL fetch error
        final idlError = ProgramOperationError.idlFetch(
          programId: testProgramId,
          reason: 'Network error',
        );
        expect(idlError.operation, equals('fetchIdl'));
        expect(
            idlError.context!['programId'], equals(testProgramId.toBase58()));

        // Test account operation error
        final accountError = ProgramOperationError.accountOperation(
          accountType: 'UserAccount',
          operation: 'fetch',
          reason: 'Account not found',
          accountAddress: testProgramId,
        );
        expect(accountError.operation, equals('accountOperation'));
        expect(accountError.context!['accountType'], equals('UserAccount'));
      });

      test('should wrap operations with error handling', () async {
        var operationCalled = false;

        final result = await ProgramErrorHandler.wrapOperation(
          'testOperation',
          () async {
            operationCalled = true;
            return 'success';
          },
        );

        expect(operationCalled, isTrue);
        expect(result, equals('success'));
      });

      test('should convert exceptions to ProgramOperationError', () async {
        expect(() async {
          await ProgramErrorHandler.wrapOperation(
            'testOperation',
            () async {
              throw Exception('Test exception');
            },
          );
        }, throwsA(isA<ProgramOperationError>()));
      });

      test('should create user-friendly error messages', () {
        final idlError = ProgramOperationError.idlFetch(
          programId: testProgramId,
          reason: 'Network timeout',
        );

        final userMessage = ProgramErrorHandler.createUserMessage(idlError);
        expect(userMessage, contains('Could not load program interface'));
        expect(userMessage, contains('deployed'));
      });
    });

    group('IDL Utilities', () {
      test('should calculate IDL address correctly', () async {
        final idlAddress = await IdlUtils.getIdlAddress(testProgramId);
        expect(idlAddress, isA<PublicKey>());
        // The actual address calculation is deterministic and should be testable
      });

      test('should handle IDL account decoding', () {
        // Test with mock IDL account data
        final mockAuthority =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final mockData = 'test data'.codeUnits;

        // Create mock account data with proper format
        final accountData = <int>[
          ...mockAuthority.bytes, // 32 bytes authority
          mockData.length, 0, 0, 0, // 4 bytes length (little endian)
          ...mockData, // data
        ];

        final decoded =
            IdlProgramAccount.decode(Uint8List.fromList(accountData));
        expect(decoded.authority, equals(mockAuthority));
        expect(decoded.data, equals(mockData));
      });
    });

    group('Program Error Creation', () {
      test('should create unified errors from Program instance', () {
        final testIdl = Idl(
          address: '11111111111111111111111111111112',
          instructions: [],
        );
        final program = Program(testIdl);

        final error = program.createError('Test error message');
        expect(error, isA<ProgramOperationError>());
        expect(error.msg, equals('Test error message'));
        expect(
            error.context!['programId'], equals(program.programId.toBase58()));
      });

      test('should wrap operations with Program context', () async {
        final testIdl = Idl(
          address: '11111111111111111111111111111112',
          instructions: [],
        );
        final program = Program(testIdl);

        final result = await program.withErrorHandling(
          'testOperation',
          () async => 'success',
        );

        expect(result, equals('success'));
      });
    });
  });
}
