/// Tests for Method Interface Generation (Task 7.3)
///
/// This test verifies that MethodBuilder correctly generates type-safe
/// method interfaces from IDL definitions with:
/// - Dynamic method generation from IDL
/// - Type-safe method parameters
/// - Automatic instruction building
/// - Return value handling
/// - Error propagation from methods

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/program/accounts_resolver.dart';
import 'package:coral_xyz_anchor/src/program/context.dart' as ctx;
import 'package:coral_xyz_anchor/src/coder/instruction_coder.dart';

void main() {
  group('MethodBuilder - Task 7.3: Method Interface Generation', () {
    late PublicKey programId;
    late AnchorProvider provider;
    late BorshInstructionCoder instructionCoder;
    late AccountsResolver accountsResolver;
    late IdlInstruction testInstruction;
    late MethodBuilder methodBuilder;

    setUp(() {
      // Set up test environment
      programId = PublicKey.fromBase58('11111111111111111111111111111112');

      // Create test connection and wallet
      final connection = Connection('http://localhost:8899');
      final wallet = KeypairWallet.fromJson([
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63,
        64
      ]);
      provider = AnchorProvider(connection, wallet);

      // Create test IDL instruction
      testInstruction = IdlInstruction(
        name: 'testMethod',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: [
          IdlInstructionAccount(
            name: 'testAccount',
            writable: true,
            signer: false,
          ),
        ],
        args: [
          IdlField(
            name: 'amount',
            type: idlTypeU64(),
          ),
          IdlField(
            name: 'recipient',
            type: idlTypePubkey(),
          ),
        ],
      );

      // Create test IDL
      final idl = Idl(
        address: programId.toBase58(),
        metadata: IdlMetadata(
          name: 'test-program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [testInstruction],
      );

      // Create instruction coder
      instructionCoder = BorshInstructionCoder(idl);

      // Create accounts resolver
      accountsResolver = AccountsResolver(
        args: [],
        accounts: {},
        provider: provider,
        programId: programId,
        idlInstruction: testInstruction,
        idlTypes: [],
      );

      // Create method builder
      methodBuilder = MethodBuilder(
        instruction: testInstruction,
        programId: programId,
        provider: provider,
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );
    });

    test('creates method builder from IDL instruction', () {
      expect(methodBuilder, isNotNull);
      expect(methodBuilder, isA<MethodBuilder>());
    });

    test('provides execute method interface', () {
      final executeMethod = methodBuilder.execute;
      expect(executeMethod, isA<Function>());
      expect(executeMethod,
          isA<Future<String> Function(Map<String, dynamic>, ctx.Context)>());
    });

    test('provides instruction method interface', () {
      final instructionMethod = methodBuilder.instruction;
      expect(instructionMethod, isA<Function>());
      expect(
          instructionMethod,
          isA<
              Future<TransactionInstruction> Function(
                  Map<String, dynamic>, ctx.Context)>());
    });

    test('provides transaction method interface', () {
      final transactionMethod = methodBuilder.transaction;
      expect(transactionMethod, isA<Function>());
      expect(transactionMethod,
          isA<Future<Transaction> Function(Map<String, dynamic>, ctx.Context)>());
    });

    test('provides simulate method interface', () {
      final simulateMethod = methodBuilder.simulate;
      expect(simulateMethod, isA<Function>());
      expect(
          simulateMethod,
          isA<
              Future<TransactionSimulationResult> Function(
                  Map<String, dynamic>, ctx.Context)>());
    });

    test('validates method arguments against IDL', () {
      final args = <String, dynamic>{
        'amount': 1000,
        'recipient': PublicKey.fromBase58('11111111111111111111111111111112'),
      };
      final accounts = ctx.DynamicAccounts({
        'testAccount': PublicKey.fromBase58('11111111111111111111111111111113'),
      });
      final context = ctx.Context<ctx.DynamicAccounts>(accounts: accounts);

      // Should not throw for valid arguments
      expect(() => methodBuilder.execute(args, context), returnsNormally);
    });

    test('throws error for missing required arguments', () {
      final args = <String, dynamic>{
        // Missing 'amount' and 'recipient'
      };
      final accounts = ctx.DynamicAccounts({
        'testAccount': PublicKey.fromBase58('11111111111111111111111111111113'),
      });
      final context = ctx.Context<ctx.DynamicAccounts>(accounts: accounts);

      // Should throw for missing required arguments
      expect(
        () => methodBuilder.execute(args, context),
        throwsA(isA<Exception>()),
      );
    });

    test('throws error for unexpected arguments', () {
      final args = <String, dynamic>{
        'amount': 1000,
        'recipient': PublicKey.fromBase58('11111111111111111111111111111112'),
        'unexpectedArg': 'should not be here',
      };
      final accounts = ctx.DynamicAccounts({
        'testAccount': PublicKey.fromBase58('11111111111111111111111111111113'),
      });
      final context = ctx.Context<ctx.DynamicAccounts>(accounts: accounts);

      // Should throw for unexpected arguments
      expect(
        () => methodBuilder.execute(args, context),
        throwsA(isA<Exception>()),
      );
    });

    test('validates argument types', () {
      final args = <String, dynamic>{
        'amount': 'not a number', // Should be u64/int
        'recipient': PublicKey.fromBase58('11111111111111111111111111111112'),
      };
      final accounts = ctx.DynamicAccounts({
        'testAccount': PublicKey.fromBase58('11111111111111111111111111111113'),
      });
      final context = ctx.Context<ctx.DynamicAccounts>(accounts: accounts);

      // Should throw for incorrect argument type
      expect(
        () => methodBuilder.execute(args, context),
        throwsA(isA<Exception>()),
      );
    });

    test('creates MethodInterface from builder', () {
      final methodInterface = MethodInterface.fromBuilder(methodBuilder);

      expect(methodInterface, isNotNull);
      expect(methodInterface.execute, isA<Function>());
      expect(methodInterface.instruction, isA<Function>());
      expect(methodInterface.transaction, isA<Function>());
      expect(methodInterface.simulate, isA<Function>());
    });

    group('MethodBuilderFactory', () {
      test('creates method builder for instruction', () {
        final factory = MethodBuilderFactory(
          programId: programId,
          provider: provider,
          instructionCoder: instructionCoder,
          accountsResolver: accountsResolver,
        );

        final builder = factory.createMethodBuilder(testInstruction);
        expect(builder, isA<MethodBuilder>());
      });

      test('creates all method builders from IDL', () {
        final idl = Idl(
          address: programId.toBase58(),
          metadata: IdlMetadata(
            name: 'test-program',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [
            testInstruction,
            IdlInstruction(
              name: 'anotherMethod',
              discriminator: [2, 3, 4, 5, 6, 7, 8, 9],
              accounts: [],
              args: [],
            ),
          ],
        );

        final factory = MethodBuilderFactory(
          programId: programId,
          provider: provider,
          instructionCoder: instructionCoder,
          accountsResolver: accountsResolver,
        );

        final builders = factory.createAllMethodBuilders(idl);
        expect(builders, hasLength(2));
        expect(builders['testMethod'], isNotNull);
        expect(builders['anotherMethod'], isNotNull);
      });
    });

    group('Error Handling', () {
      test('MethodArgumentError for invalid arguments', () {
        final error = MethodArgumentError('Invalid argument test');
        expect(error, isA<MethodArgumentError>());
        expect(error is AnchorException, isTrue);  // Check inheritance
        expect(error.toString(), contains('Invalid argument test'));
      });

      test('MethodBuildError for build failures', () {
        final error = MethodBuildError('Build failed test');
        expect(error, isA<MethodBuildError>());
        expect(error is AnchorException, isTrue);  // Check inheritance
        expect(error.toString(), contains('Build failed test'));
      });
    });
  });

  group('Dynamic Method Generation', () {
    test('supports method generation from IDL', () async {
      // Test that method builders can be dynamically created for any IDL instruction
      final instructions = [
        IdlInstruction(
          name: 'initialize',
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          accounts: [],
          args: [],
        ),
        IdlInstruction(
          name: 'transfer',
          discriminator: [2, 3, 4, 5, 6, 7, 8, 9],
          accounts: [],
          args: [
            IdlField(
              name: 'amount',
              type: const IdlType(kind: 'u64'),
            ),
          ],
        ),
        IdlInstruction(
          name: 'close',
          discriminator: [3, 4, 5, 6, 7, 8, 9, 10],
          accounts: [],
          args: [],
        ),
      ];

      final programId =
          PublicKey.fromBase58('11111111111111111111111111111112');
      final connection = Connection('http://localhost:8899');
      final wallet = await KeypairWallet.generate();
      final provider = AnchorProvider(connection, wallet);

      for (final instruction in instructions) {
        final idl = Idl(
          address: programId.toBase58(),
          metadata: IdlMetadata(
            name: 'test-program',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [instruction],
        );

        final instructionCoder = BorshInstructionCoder(idl);
        final accountsResolver = AccountsResolver(
          args: [],
          accounts: {},
          provider: provider,
          programId: programId,
          idlInstruction: instruction,
          idlTypes: [],
        );

        final builder = MethodBuilder(
          instruction: instruction,
          programId: programId,
          provider: provider,
          instructionCoder: instructionCoder,
          accountsResolver: accountsResolver,
        );

        expect(builder, isNotNull);
        expect(builder.execute, isA<Function>());
        expect(builder.instruction, isA<Function>());
        expect(builder.transaction, isA<Function>());
        expect(builder.simulate, isA<Function>());
      }
    });
  });
}
