/// Test suite for Critical Iteration 2: Dynamic Method Access and Fluent API
///
/// This test file verifies that the Dart implementation matches TypeScript's
/// dynamic method access patterns and fluent API capabilities.

library;

import 'package:test/test.dart';
import '../lib/coral_xyz_anchor.dart';
import '../lib/src/program/namespace/types.dart' as ns;

// Mock Signer implementation for testing
class MockSigner implements Signer {
  @override
  final PublicKey publicKey;

  const MockSigner(this.publicKey);

  @override
  Future<List<int>> signMessage(List<int> message) async {
    // Mock implementation - return empty signature
    return List.filled(64, 0);
  }
}

void main() {
  group('Critical Iteration 2: Dynamic Method Access', () {
    late Idl testIdl;
    late AnchorProvider provider;
    late Program program;

    setUpAll(() {
      // Create a mock IDL with test instructions
      testIdl = Idl(
        address: '11111111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'dynamic_method_test',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: [
              IdlInstructionAccount(
                name: 'user',
                writable: true,
                signer: true,
              ),
              IdlInstructionAccount(
                name: 'systemProgram',
                writable: false,
                signer: false,
              ),
            ],
            args: [
              IdlField(
                name: 'value',
                type: const IdlType(kind: 'u64'),
              ),
            ],
          ),
          IdlInstruction(
            name: 'updateData',
            discriminator: [129, 25, 88, 69, 104, 200, 15, 164],
            accounts: [
              IdlInstructionAccount(
                name: 'dataAccount',
                writable: true,
                signer: false,
              ),
              IdlInstructionAccount(
                name: 'authority',
                writable: false,
                signer: true,
              ),
            ],
            args: [
              IdlField(
                name: 'newValue',
                type: const IdlType(kind: 'string'),
              ),
              IdlField(
                name: 'timestamp',
                type: const IdlType(kind: 'i64'),
              ),
            ],
          ),
          IdlInstruction(
            name: 'noArgs',
            discriminator: [233, 42, 199, 87, 255, 18, 234, 127],
            accounts: [
              IdlInstructionAccount(
                name: 'signer',
                writable: false,
                signer: true,
              ),
            ],
            args: [],
          ),
        ],
        accounts: [],
        events: [],
        errors: [],
        types: [],
        constants: [],
      );

      // Create provider and program
      provider = AnchorProvider.defaultProvider();
      program = Program(testIdl, provider: provider);
    });

    group('Dynamic Method Access Patterns', () {
      test('should support TypeScript-style dynamic method access', () {
        // Verify that we can access methods dynamically like TypeScript:
        // program.methods.initialize(value)

        expect(() {
          // This should not throw an error - the method exists in IDL
          final dynamic methodsNamespace = program.methods;
          final result = methodsNamespace.initialize([42]);
          expect(result, isA<TypeSafeMethodBuilder>());
        }, returnsNormally);
      });

      test('should support bracket notation method access', () {
        // Verify bracket notation access: program.methods['methodName'](args)

        final methodsNamespace = program.methods;
        final methodFunction = methodsNamespace['initialize'];

        expect(methodFunction, isNotNull);
        expect(methodFunction, isA<Function>());

        // Call the function with arguments
        final builder = methodFunction!([42]);
        expect(builder, isA<TypeSafeMethodBuilder>());
      });

      test('should handle methods with no arguments', () {
        // Test methods that don't require arguments

        expect(() {
          final dynamic methodsNamespace = program.methods;
          final result = methodsNamespace.noArgs([]);
          expect(result, isA<TypeSafeMethodBuilder>());
        }, returnsNormally);
      });

      test('should handle methods with multiple arguments', () {
        // Test methods with multiple parameters

        expect(() {
          final dynamic methodsNamespace = program.methods;
          final result =
              methodsNamespace.updateData(['test string', 1234567890]);
          expect(result, isA<TypeSafeMethodBuilder>());
        }, returnsNormally);
      });

      test('should throw helpful error for non-existent methods', () {
        // Verify proper error handling for invalid method names

        expect(() {
          final dynamic methodsNamespace = program.methods;
          methodsNamespace.nonExistentMethod([]);
        },
            throwsA(isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Method "nonExistentMethod" not found in program IDL'),
            )));
      });

      test('should list available methods in error message', () {
        // Verify that error messages include available methods for discoverability

        expect(() {
          final dynamic methodsNamespace = program.methods;
          methodsNamespace.invalidMethod([]);
        },
            throwsA(isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Available methods:'),
                contains('initialize'),
                contains('updateData'),
                contains('noArgs'),
              ]),
            )));
      });
    });

    group('Fluent API Verification', () {
      test('should support full fluent chain like TypeScript', () {
        // Verify the complete fluent API chain works as expected

        expect(() {
          final dynamic methodsNamespace = program.methods;
          final builder = methodsNamespace.initialize([42]);

          // Chain should be fluent like TypeScript
          final result = builder.accounts({
            'user': PublicKey.fromBase58('11111111111111111111111111111111'),
            'systemProgram':
                PublicKey.fromBase58('11111111111111111111111111111111'),
          }).signers(<Signer>[]);

          expect(result, isA<TypeSafeMethodBuilder>());
        }, returnsNormally);
      });

      test('should support method chaining with bracket notation', () {
        // Verify fluent API works with bracket notation too

        final methodFunction = program.methods['updateData'];
        expect(methodFunction, isNotNull);

        expect(() {
          final builder = methodFunction!(['new value', 9876543210]);

          final result = builder.accounts({
            'dataAccount':
                PublicKey.fromBase58('11111111111111111111111111111111'),
            'authority':
                PublicKey.fromBase58('11111111111111111111111111111111'),
          }).signers(<Signer>[]);

          expect(result, isA<TypeSafeMethodBuilder>());
        }, returnsNormally);
      });

      test('should maintain builder state independently', () {
        // Verify that different method calls don't interfere with each other

        final dynamic methodsNamespace = program.methods;

        // Create two different builders
        final builder1 = methodsNamespace.initialize([100]);
        final builder2 = methodsNamespace.initialize([200]);

        // They should be different instances (not identical)
        expect(identical(builder1, builder2), isFalse);

        // But both should be valid TypeSafeMethodBuilder instances
        expect(builder1, isA<TypeSafeMethodBuilder>());
        expect(builder2, isA<TypeSafeMethodBuilder>());

        // Configure them differently
        builder1.accounts({
          'user': PublicKey.fromBase58('11111111111111111111111111111112'),
          'systemProgram':
              PublicKey.fromBase58('11111111111111111111111111111113'),
        });

        builder2.accounts({
          'user': PublicKey.fromBase58('11111111111111111111111111111114'),
          'systemProgram':
              PublicKey.fromBase58('11111111111111111111111111111115'),
        });

        // Both should work independently
        expect(builder1, isA<TypeSafeMethodBuilder>());
        expect(builder2, isA<TypeSafeMethodBuilder>());
      });
    });

    group('Type Safety and IDE Support', () {
      test('should provide type-safe builder interface', () {
        // Verify that the returned builder provides type safety

        final dynamic methodsNamespace = program.methods;
        final builder = methodsNamespace.initialize([42]);

        // Builder should have all expected methods
        expect(builder.accounts, isA<Function>());
        expect(builder.signers, isA<Function>());
        expect(builder.instruction, isA<Function>());
        expect(builder.transaction, isA<Function>());
        expect(builder.rpc, isA<Function>());
        expect(builder.simulate, isA<Function>());
      });

      test('should support method introspection', () {
        // Verify that we can introspect available methods

        final methodsNamespace = program.methods;

        // Should be able to list all methods
        final methodNames = methodsNamespace.names;
        expect(methodNames, contains('initialize'));
        expect(methodNames, contains('updateData'));
        expect(methodNames, contains('noArgs'));

        // Should be able to check method existence
        expect(methodsNamespace.contains('initialize'), isTrue);
        expect(methodsNamespace.contains('nonExistent'), isFalse);
      });

      test('should provide direct builder access for advanced use cases', () {
        // Verify getBuilder method for advanced scenarios

        final methodsNamespace = program.methods;

        final builder = methodsNamespace.getBuilder('initialize');
        expect(builder, isNotNull);
        expect(builder, isA<TypeSafeMethodBuilder>());

        // Non-existent method should return null
        final nonExistent = methodsNamespace.getBuilder('nonExistent');
        expect(nonExistent, isNull);
      });
    });

    group('API Compatibility with TypeScript', () {
      test('should match TypeScript method call syntax exactly', () {
        // This test verifies that our Dart syntax matches TypeScript as closely as possible

        // TypeScript: program.methods.initialize(42).accounts({...}).rpc()
        // Dart:       program.methods.initialize([42]).accounts({...}).rpc()
        //
        // The only difference is that Dart requires args in a list due to language constraints

        expect(() {
          final dynamic methodsNamespace = program.methods;

          // This should work exactly like TypeScript (except for list wrapping)
          final builder = methodsNamespace.initialize([42]);
          final accountsSet = builder.accounts({
            'user': PublicKey.fromBase58('11111111111111111111111111111111'),
            'systemProgram':
                PublicKey.fromBase58('11111111111111111111111111111111'),
          });

          expect(accountsSet, isA<TypeSafeMethodBuilder>());
        }, returnsNormally);
      });

      test('should support all TypeScript builder methods', () {
        // Verify that all TypeScript MethodsBuilder methods are available

        final dynamic methodsNamespace = program.methods;
        final builder = methodsNamespace.initialize([42]);

        // All these methods should be available (like in TypeScript)
        expect(() => builder.accounts(<String, PublicKey>{}), returnsNormally);
        expect(() => builder.signers(<Signer>[]), returnsNormally);
        expect(
            () => builder.remainingAccounts(<ns.AccountMeta>[
                  ns.AccountMeta(
                    publicKey: PublicKey.fromBase58(
                        '11111111111111111111111111111111'),
                    isWritable: false,
                    isSigner: false,
                  )
                ]),
            returnsNormally);
        expect(() => builder.preInstructions(<ns.TransactionInstruction>[]),
            returnsNormally);
        expect(() => builder.postInstructions(<ns.TransactionInstruction>[]),
            returnsNormally);

        // Execution methods
        expect(builder.instruction, isA<Function>());
        expect(builder.transaction, isA<Function>());
        expect(builder.rpc, isA<Function>());
        expect(builder.simulate, isA<Function>());
      });
    });

    group('Error Handling and Developer Experience', () {
      test('should provide clear error messages for invalid method access', () {
        // Verify developer-friendly error messages

        expect(() {
          final dynamic methodsNamespace = program.methods;
          methodsNamespace.thisMethodDoesNotExist([]);
        },
            throwsA(isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Method "thisMethodDoesNotExist" not found'),
                contains('Available methods:'),
                contains('[initialize, updateData, noArgs]'),
              ]),
            )));
      });

      test('should handle property access vs method calls correctly', () {
        // Verify that we only intercept method calls, not property access

        final dynamic methodsNamespace = program.methods;

        // Property access should fail normally (not intercepted)
        expect(() {
          // This is property access, not a method call
          // ignore: unused_local_variable
          final something = methodsNamespace.nonExistentProperty;
        }, throwsA(isA<NoSuchMethodError>()));

        // Method calls should be intercepted
        expect(() {
          // This is a method call - should be intercepted
          methodsNamespace.nonExistentMethod([]);
        }, throwsA(isA<ArgumentError>()));
      });
    });
  });
}
