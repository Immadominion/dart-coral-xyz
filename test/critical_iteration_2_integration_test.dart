/// Integration test demonstrating Critical Iteration 2: Dynamic Method Access
///
/// This test shows the TypeScript-compatible dynamic method access working
/// in realistic scenarios that mirror the TypeScript Anchor client usage.

library;

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Critical Iteration 2: Integration Test', () {
    late Program program;

    setUpAll(() {
      // Use a realistic IDL example (similar to tutorial examples)
      final idl = const Idl(
        address: 'Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS',
        metadata: IdlMetadata(
          name: 'basic_tutorial',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: [
              IdlInstructionAccount(
                name: 'myAccount',
                writable: true,
                signer: true,
              ),
              IdlInstructionAccount(
                name: 'user',
                writable: true,
                signer: true,
              ),
              IdlInstructionAccount(
                name: 'systemProgram',
              ),
            ],
            args: [
              IdlField(
                name: 'data',
                type: IdlType(kind: 'u64'),
              ),
            ],
          ),
          IdlInstruction(
            name: 'increment',
            discriminator: [11, 18, 104, 9, 104, 174, 59, 33],
            accounts: [
              IdlInstructionAccount(
                name: 'counter',
                writable: true,
              ),
              IdlInstructionAccount(
                name: 'authority',
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

      program = Program(idl, provider: AnchorProvider.defaultProvider());
    });

    test('TypeScript-style syntax: program.methods.initialize(value)', () {
      // This demonstrates the exact TypeScript syntax pattern working in Dart
      expect(() {
        final dynamic methods = program.methods;

        // TypeScript: program.methods.initialize(new BN(1234))
        // Dart:       program.methods.initialize([1234])
        final builder = methods.initialize([1234]);

        // Should return a properly configured method builder
        expect(builder, isA<TypeSafeMethodBuilder>());

        // Should be able to chain method calls fluently
        final accountsBuilder = builder.accounts({
          'myAccount': PublicKey.fromBase58('11111111111111111111111111111112'),
          'user': PublicKey.fromBase58('11111111111111111111111111111113'),
          'systemProgram':
              PublicKey.fromBase58('11111111111111111111111111111114'),
        });

        expect(accountsBuilder, isA<TypeSafeMethodBuilder>());
      }, returnsNormally,);
    });

    test('TypeScript-style syntax: program.methods.increment()', () {
      // Test method with no arguments
      expect(() {
        final dynamic methods = program.methods;

        // TypeScript: program.methods.increment()
        // Dart:       program.methods.increment([])
        final builder = methods.increment([]);

        expect(builder, isA<TypeSafeMethodBuilder>());

        // Chain accounts
        final result = builder.accounts({
          'counter': PublicKey.fromBase58('11111111111111111111111111111112'),
          'authority': PublicKey.fromBase58('11111111111111111111111111111113'),
        });

        expect(result, isA<TypeSafeMethodBuilder>());
      }, returnsNormally,);
    });

    test('Bracket notation: program.methods["methodName"](args)', () {
      // Test bracket notation syntax
      expect(() {
        final methodFunction = program.methods['initialize'];
        expect(methodFunction, isNotNull);

        final builder = methodFunction!([9999]);
        expect(builder, isA<TypeSafeMethodBuilder>());

        final result = builder.accounts({
          'myAccount': PublicKey.fromBase58('11111111111111111111111111111112'),
          'user': PublicKey.fromBase58('11111111111111111111111111111113'),
          'systemProgram':
              PublicKey.fromBase58('11111111111111111111111111111114'),
        });

        expect(result, isA<TypeSafeMethodBuilder>());
      }, returnsNormally,);
    });

    test('Multiple independent method calls', () {
      // Verify that multiple calls create independent builders
      expect(() {
        final dynamic methods = program.methods;

        // Create multiple builders
        final builder1 = methods.initialize([100]);
        final builder2 = methods.initialize([200]);
        final builder3 = methods.increment([]);

        // All should be valid but independent
        expect(builder1, isA<TypeSafeMethodBuilder>());
        expect(builder2, isA<TypeSafeMethodBuilder>());
        expect(builder3, isA<TypeSafeMethodBuilder>());

        // Should not be the same instances
        expect(identical(builder1, builder2), isFalse);
        expect(identical(builder1, builder3), isFalse);
        expect(identical(builder2, builder3), isFalse);
      }, returnsNormally,);
    });

    test('Error handling for non-existent methods', () {
      // Test proper error messages
      expect(() {
        final dynamic methods = program.methods;
        methods.nonExistentMethod([]);
      },
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf([
              contains('Method "nonExistentMethod" not found'),
              contains('Available methods:'),
              contains('initialize'),
              contains('increment'),
            ]),
          ),),);
    });

    test('Complete fluent chain like TypeScript examples', () {
      // Test the complete chain that you'd see in TypeScript documentation
      expect(() {
        final dynamic methods = program.methods;

        // This mirrors the TypeScript examples:
        // await program.methods
        //   .initialize(new anchor.BN(1234))
        //   .accounts({
        //     myAccount: myAccount.publicKey,
        //     user: provider.wallet.publicKey,
        //     systemProgram: SystemProgram.programId,
        //   })
        //   .signers([myAccount])
        //   .rpc();

        final result = methods.initialize([1234]).accounts({
          'myAccount': PublicKey.fromBase58('11111111111111111111111111111112'),
          'user': PublicKey.fromBase58('11111111111111111111111111111113'),
          'systemProgram':
              PublicKey.fromBase58('11111111111111111111111111111114'),
        }).signers(<Signer>[]);

        expect(result, isA<TypeSafeMethodBuilder>());

        // Should have all the execution methods available
        expect(result.instruction, isA<Function>());
        expect(result.transaction, isA<Function>());
        expect(result.rpc, isA<Function>());
        expect(result.simulate, isA<Function>());
      }, returnsNormally,);
    });
  });
}
