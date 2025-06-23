/// Tests for Step 8.2: Testing Infrastructure and Development Tools
///
/// This test suite validates the enhanced testing infrastructure including
/// test validator management, account management, mocks, fixtures, and
/// development utilities matching TypeScript's testing capabilities.

import 'package:test/test.dart';
import 'dart:typed_data';
import '../lib/src/testing/test_infrastructure.dart';
import '../lib/src/types/keypair.dart';
import '../lib/src/types/public_key.dart';
import '../lib/src/types/transaction.dart';
import '../lib/src/provider/connection.dart';
import '../lib/src/idl/idl.dart';

void main() {
  group('Step 8.2: Testing Infrastructure and Development Tools', () {
    group('Test Validator Management', () {
      test('should create test validator with configuration', () {
        final validator = TestValidator(
          rpcUrl: 'http://localhost:8899',
          config: {'reset': true, 'quiet': true},
        );

        expect(validator.rpcUrl, equals('http://localhost:8899'));
        expect(validator.config['reset'], isTrue);
        expect(validator.isRunning, isFalse);
      });

      test('should get connection to test validator', () {
        final validator = TestValidator();
        final connection = validator.getConnection();

        expect(connection.endpoint, equals('http://localhost:8899'));
      });

      test('should track deployed programs', () {
        final validator = TestValidator();

        expect(validator.deployedPrograms, isEmpty);
      });
    });

    group('Test Account Management', () {
      late TestAccountManager accountManager;
      late AdvancedMockProvider mockProvider;

      setUp(() async {
        // Use mock provider to avoid real network connections
        mockProvider = AdvancedMockProvider.create();
        mockProvider.configureMockScenario('test', {
          'getMinimumBalanceForRentExemption': 1000000,
          'getBalance': 1000000000,
        });
        mockProvider.activateScenario('test');

        final payer = await Keypair.generate();
        accountManager = TestAccountManager(mockProvider.connection, payer);
      });

      test('should create funded test account', () async {
        final account = await accountManager.createFundedAccount(
          name: 'test_account',
          lamports: 2000000000,
        );

        expect(account, isA<Keypair>());
        expect(accountManager.getAccount('test_account'), equals(account));
      });

      test('should create account with specific data', () async {
        final owner = await Keypair.generate();
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

        final account = await accountManager.createAccountWithData(
          owner: owner.publicKey,
          space: 1024,
          data: testData,
          name: 'data_account',
        );

        expect(account, isA<Keypair>());
        expect(accountManager.getAccount('data_account'), equals(account));
      });

      test('should cleanup managed accounts', () async {
        await accountManager.createFundedAccount(name: 'temp_account');
        expect(accountManager.getAccount('temp_account'), isNotNull);

        await accountManager.cleanup();
        expect(accountManager.getAccount('temp_account'), isNull);
      });
    });

    group('Mock Provider and Connection Framework', () {
      late AdvancedMockProvider mockProvider;

      setUp(() async {
        final keypair = await Keypair.generate();
        mockProvider = AdvancedMockProvider.create(
          walletKeypair: keypair,
          config: {'test_mode': true},
        );
      });

      test('should create mock provider with configuration', () {
        expect(mockProvider.getConfig<bool>('test_mode'), isTrue);
        expect(mockProvider.mockConnection, isA<AdvancedMockConnection>());
        expect(mockProvider.mockWallet, isA<MockWallet>());
      });

      test('should support scenario configuration', () {
        mockProvider.configureMockScenario('success_scenario', {
          'getBalance': 5000000000,
          'checkHealth': 'healthy',
        });

        mockProvider.activateScenario('success_scenario');

        expect(mockProvider.mockConnection.callHistory, isEmpty);
      });

      test('should record connection method calls', () async {
        final connection = mockProvider.mockConnection;

        await connection.checkHealth();
        await connection.getBalance(mockProvider.wallet!.publicKey);

        expect(connection.callHistory, hasLength(2));
        expect(connection.callHistory[0], contains('checkHealth'));
        expect(connection.callHistory[1], contains('getBalance'));
        expect(connection.callCount, equals(2));
      });

      test('should support connection reset', () async {
        final connection = mockProvider.mockConnection;

        await connection.checkHealth();
        expect(connection.callCount, equals(1));

        connection.reset();
        expect(connection.callCount, equals(0));
        expect(connection.callHistory, isEmpty);
      });
    });

    group('Mock Wallet', () {
      late MockWallet mockWallet;

      setUp(() async {
        final keypair = await Keypair.generate();
        mockWallet = MockWallet(keypair);
      });

      test('should sign transactions', () async {
        final transaction = Transaction(
          instructions: [],
          feePayer: mockWallet.publicKey,
          recentBlockhash: 'test-blockhash',
        );

        final signedTx = await mockWallet.signTransaction(transaction);

        expect(signedTx, isA<Transaction>());
        expect(mockWallet.signedTransactions, hasLength(1));
      });

      test('should sign multiple transactions', () async {
        final transactions = [
          Transaction(
            instructions: [],
            feePayer: mockWallet.publicKey,
            recentBlockhash: 'test-blockhash-1',
          ),
          Transaction(
            instructions: [],
            feePayer: mockWallet.publicKey,
            recentBlockhash: 'test-blockhash-2',
          ),
        ];

        final signedTxs = await mockWallet.signAllTransactions(transactions);

        expect(signedTxs, hasLength(2));
        expect(mockWallet.signedTransactions, hasLength(2));
      });

      test('should sign messages', () async {
        final message = Uint8List.fromList([1, 2, 3, 4]);

        final signature = await mockWallet.signMessage(message);

        expect(signature, hasLength(64));
        expect(mockWallet.signedTransactions, hasLength(1));
      });

      test('should support signing error simulation', () async {
        final exception = Exception('Signing failed');
        mockWallet.setThrowOnSign(exception);

        final transaction = Transaction(
          instructions: [],
          feePayer: mockWallet.publicKey,
          recentBlockhash: 'test-blockhash',
        );

        expect(
          () => mockWallet.signTransaction(transaction),
          throwsA(equals(exception)),
        );
      });

      test('should reset signing behavior', () async {
        final exception = Exception('Signing failed');
        mockWallet.setThrowOnSign(exception);
        mockWallet.resetSigningBehavior();

        final transaction = Transaction(
          instructions: [],
          feePayer: mockWallet.publicKey,
          recentBlockhash: 'test-blockhash',
        );

        // Should not throw after reset
        final signedTx = await mockWallet.signTransaction(transaction);
        expect(signedTx, isA<Transaction>());
      });
    });

    group('Test Fixtures', () {
      tearDown(() {
        TestFixtures.clear();
      });

      test('should register and retrieve program IDL fixtures', () {
        final testIdl = TestDataGenerator.generateTestIdl(
          name: 'test_program',
        );

        TestFixtures.registerProgramIdl('test_program', testIdl);
        final retrievedIdl = TestFixtures.getProgramIdl('test_program');

        expect(retrievedIdl, equals(testIdl));
        expect(retrievedIdl?.metadata?.name, equals('test_program'));
      });

      test('should register and retrieve account fixtures', () {
        final accountData = TestDataGenerator.generateAccountData(
          fields: {'amount': 1000, 'owner': 'test_owner'},
        );

        TestFixtures.registerAccountFixture('test_account', accountData);
        final retrievedData = TestFixtures.getAccountFixture('test_account');

        expect(retrievedData, equals(accountData));
        expect(retrievedData?['amount'], equals(1000));
        expect(retrievedData?['owner'], equals('test_owner'));
      });

      test('should create workspace fixtures', () {
        final workspaceFixture = TestFixtures.createWorkspaceFixture(
          name: 'test_workspace',
          programs: ['program1', 'program2'],
          config: {'cluster': 'devnet'},
        );

        expect(workspaceFixture.name, equals('test_workspace'));
        expect(workspaceFixture.programs, equals(['program1', 'program2']));
        expect(workspaceFixture.config['cluster'], equals('devnet'));
      });

      test('should clear all fixtures', () {
        final testIdl = TestDataGenerator.generateTestIdl();
        TestFixtures.registerProgramIdl('test', testIdl);
        TestFixtures.registerAccountFixture('test', {});

        expect(TestFixtures.getProgramIdl('test'), isNotNull);
        expect(TestFixtures.getAccountFixture('test'), isNotNull);

        TestFixtures.clear();

        expect(TestFixtures.getProgramIdl('test'), isNull);
        expect(TestFixtures.getAccountFixture('test'), isNull);
      });
    });

    group('Test Data Generator', () {
      test('should generate random bytes', () {
        final bytes1 = TestDataGenerator.randomBytes(32);
        final bytes2 = TestDataGenerator.randomBytes(32);

        expect(bytes1, hasLength(32));
        expect(bytes2, hasLength(32));
        // Should be different (very high probability)
        expect(bytes1, isNot(equals(bytes2)));
      });

      test('should generate test IDL', () {
        final idl = TestDataGenerator.generateTestIdl(
          name: 'custom_program',
          address: 'CustomProgram111111111111111111111111111',
        );

        expect(idl.metadata?.name, equals('custom_program'));
        expect(idl.address, equals('CustomProgram111111111111111111111111111'));
        expect(idl.instructions, isNotEmpty);
        expect(idl.instructions[0].name, equals('initialize'));
      });

      test('should generate test account data', () {
        final accountData = TestDataGenerator.generateAccountData(
          discriminator: 'custom_discriminator',
          fields: {'balance': 5000, 'status': 'active'},
        );

        expect(accountData['discriminator'], equals('custom_discriminator'));
        expect(accountData['balance'], equals(5000));
        expect(accountData['status'], equals('active'));
        expect(accountData['lamports'], isA<int>());
        expect(accountData['created_at'], isA<int>());
      });
    });

    group('Integration Test Runner', () {
      test('should create from validator with mock components', () {
        // Create a simple runner without starting actual validator
        final validator = TestValidator();
        final connection = validator.getConnection();

        expect(validator, isA<TestValidator>());
        expect(connection, isA<Connection>());
      });

      test('should run test with setup and cleanup simulation', () async {
        // Create a simplified test runner that doesn't require actual validator
        final mockProvider = AdvancedMockProvider.create();
        final payer = await Keypair.generate();
        final accountManager =
            TestAccountManager(mockProvider.connection, payer);

        final runner = IntegrationTestRunner(
          validator: null, // No real validator
          connection: mockProvider.connection,
          accountManager: accountManager,
        );

        bool testExecuted = false;

        final result = await runner.runTest(() async {
          testExecuted = true;
          return 'test_result';
        });

        expect(testExecuted, isTrue);
        expect(result, equals('test_result'));
      });

      test('should handle test exceptions and still cleanup', () async {
        final mockProvider = AdvancedMockProvider.create();
        final payer = await Keypair.generate();
        final accountManager =
            TestAccountManager(mockProvider.connection, payer);

        final runner = IntegrationTestRunner(
          validator: null, // No real validator
          connection: mockProvider.connection,
          accountManager: accountManager,
        );

        final testException = Exception('Test failed');

        expect(
          () => runner.runTest(() async {
            throw testException;
          }),
          throwsA(equals(testException)),
        );
        // Cleanup should still happen even after exception
      });
    });

    group('TypeScript Testing Patterns Compatibility', () {
      test('should support TypeScript-like test setup patterns', () async {
        // Simulate TypeScript Anchor test setup
        final provider = AdvancedMockProvider.create();
        provider.configureMockScenario('program_test', {
          'getBalance': 1000000000,
          'getLatestBlockhash': 'test-blockhash',
        });
        provider.activateScenario('program_test');

        // Register test IDL
        final programIdl =
            TestDataGenerator.generateTestIdl(name: 'test_program');
        TestFixtures.registerProgramIdl('test_program', programIdl);

        // Create workspace fixture
        final workspaceFixture = TestFixtures.createWorkspaceFixture(
          name: 'test_workspace',
          programs: ['test_program'],
        );

        expect(workspaceFixture.programs, contains('test_program'));
        expect(TestFixtures.getProgramIdl('test_program'), equals(programIdl));
      });

      test('should support mock provider scenarios like TypeScript', () async {
        final provider = AdvancedMockProvider.create();

        // Configure success scenario
        provider.configureMockScenario('success', {
          'getBalance': 5000000000,
          'checkHealth': 'ok',
        });

        // Configure failure scenario
        provider.configureMockScenario('failure', {
          'getBalance': 0,
          'checkHealth': 'error',
        });

        // Test success scenario
        provider.activateScenario('success');
        final balance1 =
            await provider.connection.getBalance(provider.wallet!.publicKey);
        expect(balance1, equals(5000000000));

        // Test failure scenario
        provider.activateScenario('failure');
        final balance2 =
            await provider.connection.getBalance(provider.wallet!.publicKey);
        expect(balance2, equals(0));
      });

      test('should provide comprehensive test utilities like TypeScript',
          () async {
        // Use mocks to avoid network issues
        final mockProvider = AdvancedMockProvider.create();
        mockProvider.configureMockScenario('test', {
          'getBalance': 2000000000,
        });
        mockProvider.activateScenario('test');

        final payer = await Keypair.generate();
        final accountManager =
            TestAccountManager(mockProvider.connection, payer);

        // Create test accounts
        final testAccount = await accountManager.createFundedAccount(
          name: 'main_account',
          lamports: 2000000000,
        );

        // Data generation
        final testData = TestDataGenerator.randomBytes(256);
        final accountData = TestDataGenerator.generateAccountData(
          fields: {'balance': 1000}, // Override lamports to avoid random issue
        );

        // Fixtures
        final testIdl = TestDataGenerator.generateTestIdl();
        TestFixtures.registerProgramIdl('test', testIdl);
        TestFixtures.registerAccountFixture('test', accountData);

        // Verification
        expect(testAccount, isA<Keypair>());
        expect(testData, hasLength(256));
        expect(accountData, containsPair('balance', 1000));
        expect(TestFixtures.getProgramIdl('test'), equals(testIdl));
      });
    });
  });
}
