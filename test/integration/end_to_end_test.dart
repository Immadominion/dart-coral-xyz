import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'integration_test_utils.dart';
import '../test_helpers.dart';

/// End-to-end integration tests
void main() {
  group('End-to-End Integration Tests', () {
    late IntegrationTestEnvironment env;

    setUpAll(() async {
      env = IntegrationTestEnvironment();
      await env.setUp();
    });

    tearDownAll(() async {
      await env.tearDown();
    });

    test('basic program interaction flow', () async {
      // Create test accounts
      final programAccount = await env.createFundedAccount();

      // Create mock IDL for testing
      final mockIdl = Idl(
        address: programAccount.publicKey.toBase58(),
        metadata: IdlMetadata(
          name: 'test_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            docs: ['Initialize the program'],
            discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: [
              IdlInstructionAccount(
                name: 'user',
                writable: true,
                signer: true,
              ),
              IdlInstructionAccount(
                name: 'program',
                writable: false,
                signer: false,
              ),
            ],
            args: [
              IdlField(
                name: 'value',
                type: idlTypeU64(),
              ),
            ],
          ),
        ],
        accounts: [
          IdlAccount(
            name: 'UserData',
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'value', type: idlTypeU64()),
                IdlField(name: 'authority', type: idlTypePubkey()),
              ],
            ),
          ),
        ],
      );

      // Create program instance
      final program = Program(mockIdl, provider: env.provider);

      // Test basic program properties
      expect(program.programId.toBase58(),
          equals(programAccount.publicKey.toBase58()));
      expect(program.provider, equals(env.provider));

      // Test namespace access
      expect(program.account, isNotNull);
      expect(program.instruction, isNotNull);
      expect(program.methods, isNotNull);
      expect(program.rpc, isNotNull);

      // Test IDL access
      expect(program.idl.metadata?.name, equals('test_program'));
      expect(program.idl.instructions.length, equals(1));
      expect(program.idl.accounts?.length, equals(1));
    });

    test('account creation and fetching', () async {
      // Test account creation utilities from test helpers
      final createdData =
          createTestAccountData(name: 'test_account', lamports: 1000);
      expect(createdData['name'], equals('test_account'));
      expect(createdData['lamports'], equals(1000));

      // Test account assertion helpers
      expectAnchorAccount(createdData,
          expectedName: 'test_account', expectedLamports: 1000);
    });

    test('instruction building and transaction flow', () async {
      // Create test accounts
      final programKeypair = await env.createFundedAccount();
      final userKeypair = await env.createFundedAccount();

      // Test instruction building helper
      final instruction = buildTestInstruction(
        programId: programKeypair.publicKey,
        accounts: [
          AccountMeta(
            pubkey: userKeypair.publicKey,
            isWritable: true,
            isSigner: true,
          ),
        ],
        data: [1, 2, 3, 4],
      );

      expect(instruction.programId, equals(programKeypair.publicKey));
      expect(instruction.accounts.length, equals(1));
      expect(instruction.data.length, equals(4));

      // Test transaction creation
      final transaction = Transaction(
        instructions: [instruction],
        feePayer: userKeypair.publicKey,
      );

      expect(transaction.instructions.length, equals(1));
      expect(transaction.feePayer, equals(userKeypair.publicKey));
    });

    test('coder functionality integration', () async {
      // Create mock IDL
      final mockIdl = Idl(
        address: 'TestProgram111111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'test_coder_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'test_instruction',
            docs: ['Test instruction'],
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            accounts: [],
            args: [
              IdlField(name: 'value', type: idlTypeU64()),
              IdlField(name: 'flag', type: idlTypeBool()),
            ],
          ),
        ],
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            discriminator: [10, 20, 30, 40, 50, 60, 70, 80],
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'data', type: idlTypeU32()),
              ],
            ),
          ),
        ],
      );

      // Create coder
      final coder = BorshCoder(mockIdl);

      // Test instruction encoding
      final instructionData = coder.instructions.encode('test_instruction', {
        'value': 123456,
        'flag': true,
      });

      expect(instructionData, isNotNull);
      expect(instructionData.length,
          greaterThan(8)); // Should include discriminator

      // Test account encoding
      final accountData = await coder.accounts.encode('TestAccount', {
        'data': 42,
      });

      expect(accountData, isNotNull);
      expect(
          accountData.length, greaterThan(8)); // Should include discriminator

      // Test decoding
      final decodedAccount = coder.accounts.decode('TestAccount', accountData);
      expect(decodedAccount?['data'], equals(42));
    });

    test('provider and connection integration', () async {
      // Test connection properties
      expect(env.connection, isNotNull);
      expect(env.provider.connection, equals(env.connection));

      // Test wallet integration
      expect(env.provider.wallet, isNotNull);
      expect(env.provider.publicKey, isNotNull);

      // Test provider utilities
      final testKeypair = await env.createFundedAccount();
      expect(testKeypair.publicKey, isNotNull);
      expect(testKeypair.secretKey, isNotNull);
    });
  });
}

/// Helper to create test account data
Map<String, dynamic> createTestAccountData({
  required String name,
  required int lamports,
}) {
  return {
    'name': name,
    'lamports': lamports,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
}

/// Helper assertion for account data
void expectAnchorAccount(
  Map<String, dynamic>? account, {
  required String expectedName,
  required int expectedLamports,
}) {
  expect(account, isNotNull);
  expect(account!['name'], equals(expectedName));
  expect(account['lamports'], equals(expectedLamports));
}
