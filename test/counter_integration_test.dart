/// Basic counter program integration test
///
/// This test demonstrates basic Anchor program interaction patterns
/// similar to the TypeScript basic-1 tutorial, but uses mocks to avoid
/// requiring a local Solana validator.
library;

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:test/test.dart';

void main() {
  group('Counter Program Integration', () {
    late Program program;
    late Connection connection;
    late AnchorProvider provider;

    setUpAll(() async {
      // Create a basic counter program IDL similar to tutorial examples
      final counterIdl = const Idl(
        address: 'Counter111111111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'basic_counter',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            docs: ['Initialize the counter'],
            discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: [
              IdlInstructionAccount(
                name: 'counter',
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
            docs: ['Increment the counter'],
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
        accounts: [
          IdlAccount(
            name: 'Counter',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'authority',
                  type: IdlType(kind: 'publicKey'),
                ),
                IdlField(
                  name: 'count',
                  type: IdlType(kind: 'u64'),
                ),
              ],
            ),
            discriminator: [255, 176, 4, 245, 188, 253, 124, 25],
          ),
        ],
      );

      // Setup provider and connection (mock)
      connection = Connection('http://localhost:8899');
      final wallet = await KeypairWallet.generate();
      provider = AnchorProvider(connection, wallet);

      // Create program instance
      program = Program(counterIdl, provider: provider);
    });

    test('should create program instance with counter IDL', () {
      expect(program.programId.toBase58(),
          equals('Counter111111111111111111111111111111111'));
      expect(program.idl.metadata?.name, equals('basic_counter'));
      expect(program.idl.instructions.length, equals(2));
      expect(program.idl.accounts?.length, equals(1));
    });

    test('should have accessible namespaces', () {
      // Test that all program namespaces are available
      expect(program.methods, isA<MethodsNamespace>());
      expect(program.account, isA<AccountNamespace>());
      expect(program.instruction, isA<InstructionNamespace>());
      expect(program.transaction, isA<TransactionNamespace>());
      expect(program.rpc, isA<RpcNamespace>());
      expect(program.views, isA<ViewsNamespace>());
    });

    test('should provide instruction builders', () {
      // Test that instruction builders are accessible
      // Note: These won't execute due to mock connection but demonstrate API structure
      expect(program.methods, isNotNull);
      expect(program.methods, isA<MethodsNamespace>());
    });

    test('should provide account fetchers', () {
      // Test that account fetchers are accessible
      expect(program.account, isNotNull);
      expect(program.account, isA<AccountNamespace>());
    });

    test('should handle error cases gracefully', () {
      // Test error handling without requiring actual blockchain interaction
      expect(
          () => program.getAccountSize('NonexistentAccount'), throwsException);

      // Test basic method access
      expect(program.methods, isNotNull);
    });

    test('should demonstrate PDA creation pattern', () async {
      // Test PDA creation pattern common in counter programs
      final counterSeeds = ['counter'.codeUnits];
      final counterPda = await PublicKey.findProgramAddress(
        counterSeeds.map((s) => s.map((c) => c).toList()).toList().cast(),
        program.programId,
      );

      expect(counterPda.address.isDefault, isFalse);
      expect(counterPda.bump, greaterThan(0));
      expect(counterPda.bump, lessThanOrEqualTo(255));
    });

    test('should validate instruction structure', () {
      // Test instruction structure matches expected patterns
      final initializeInstruction = program.idl.instructions
          .where((inst) => inst.name == 'initialize')
          .first;

      expect(initializeInstruction.accounts.length, equals(3));
      expect(initializeInstruction.args.length, equals(1));
      expect(initializeInstruction.args.first.name, equals('data'));
      expect(initializeInstruction.args.first.type.kind, equals('u64'));

      final incrementInstruction = program.idl.instructions
          .where((inst) => inst.name == 'increment')
          .first;

      expect(incrementInstruction.accounts.length, equals(2));
      expect(incrementInstruction.args.length, equals(0));
    });

    test('should validate account structure', () {
      // Test account structure matches expected patterns
      final counterAccount =
          program.idl.accounts!.where((acc) => acc.name == 'Counter').first;

      expect(counterAccount.name, equals('Counter'));
      expect(counterAccount.type.kind, equals('struct'));

      // Check that the struct has fields
      if (counterAccount.type.fields != null) {
        expect(counterAccount.type.fields!.length, equals(2));
        expect(counterAccount.type.fields![0].name, equals('authority'));
        expect(counterAccount.type.fields![0].type.kind, equals('publicKey'));
        expect(counterAccount.type.fields![1].name, equals('count'));
        expect(counterAccount.type.fields![1].type.kind, equals('u64'));
      }
    });
  });
}
