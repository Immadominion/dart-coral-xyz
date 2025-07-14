import 'package:test/test.dart';
import 'package:coral_xyz_anchor/src/coder/account_ownership_validator.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';

/// Mock connection for testing account ownership validation
class MockConnection extends Connection {

  MockConnection() : super('https://mock.test');
  final Map<String, AccountInfo?> _accounts = {};

  void setAccountInfo(PublicKey address, AccountInfo? info) {
    _accounts[address.toBase58()] = info;
  }

  @override
  Future<AccountInfo?> getAccountInfo(
    PublicKey publicKey, {
    CommitmentConfig? commitment,
  }) async => _accounts[publicKey.toBase58()];
}

/// Mock account info for testing
class MockAccountInfo extends AccountInfo {
  MockAccountInfo({
    required super.owner,
    super.data,
    super.lamports = 0,
    super.executable = false,
    super.rentEpoch = 0,
  });
}

void main() {
  group('AccountOwnershipValidator', () {
    late MockConnection mockConnection;
    late PublicKey testProgramId;
    late PublicKey testAccountAddress;
    late PublicKey wrongProgramId;

    setUp(() {
      mockConnection = MockConnection();
      testProgramId =
          PublicKey.fromBase58('BPFLoaderUpgradeab1e11111111111111111111111');
      testAccountAddress =
          PublicKey.fromBase58('SysvarC1ock11111111111111111111111111111111');
      wrongProgramId =
          PublicKey.fromBase58('Config1111111111111111111111111111111111111');

      // Reset statistics before each test
      AccountOwnershipValidator.resetStatistics();
    });

    group('Single Account Validation', () {
      test('should validate account with correct ownership', () async {
        // Setup: Account owned by the expected program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: testProgramId, data: [1, 2, 3, 4]),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.isValid, isTrue);
        expect(result.actualOwner, equals(testProgramId));
        expect(result.accountExists, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.context?['validation_type'], equals('exact_match'));
      });

      test('should fail validation for account with wrong ownership', () async {
        // Setup: Account owned by a different program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: wrongProgramId, data: [1, 2, 3, 4]),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.isValid, isFalse);
        expect(result.actualOwner, equals(wrongProgramId));
        expect(result.expectedOwner, equals(testProgramId));
        expect(result.errorMessage,
            contains('Account ownership validation failed'),);
        expect(
            result.context?['validation_type'], equals('ownership_mismatch'),);
      });

      test('should fail validation for non-existent account', () async {
        // Setup: No account info (account doesn't exist)
        mockConnection.setAccountInfo(testAccountAddress, null);

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.isValid, isFalse);
        expect(result.accountExists, isFalse);
        expect(result.errorMessage, contains('Account does not exist'));
        expect(result.context?['validation_type'], equals('existence_check'));
      });

      test('should respect bypass validation config', () async {
        // Setup: Account with wrong ownership, but bypass enabled
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: wrongProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
          config: AccountOwnershipValidationConfig.testing,
        );

        expect(result.isValid, isTrue);
        // Note: testing config has includeContext: false, so context is null
        expect(result.context, isNull);
      });

      test('should allow system-owned accounts when configured', () async {
        // Setup: Account owned by system program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: AccountOwnershipValidator.systemProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
          config:
              const AccountOwnershipValidationConfig(allowSystemOwned: true),
        );

        expect(result.isValid, isTrue);
        expect(
            result.context?['validation_type'], equals('system_owned_allowed'),);
      });

      test('should allow token program owned accounts when configured',
          () async {
        // Setup: Account owned by token program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: AccountOwnershipValidator.tokenProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
          config: const AccountOwnershipValidationConfig(
              allowTokenProgramOwned: true,),
        );

        expect(result.isValid, isTrue);
        expect(result.context?['validation_type'],
            equals('token_program_owned_allowed'),);
        expect(result.context?['token_program_variant'], equals('spl_token'));
      });

      test('should allow Token-2022 program owned accounts when configured',
          () async {
        // Setup: Account owned by Token-2022 program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: AccountOwnershipValidator.token2022ProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
          config: const AccountOwnershipValidationConfig(
              allowTokenProgramOwned: true,),
        );

        expect(result.isValid, isTrue);
        expect(result.context?['validation_type'],
            equals('token_program_owned_allowed'),);
        expect(result.context?['token_program_variant'], equals('token_2022'));
      });

      test('should allow custom allowed owners', () async {
        final customOwner =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

        // Setup: Account owned by custom allowed owner
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: customOwner),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
          config: AccountOwnershipValidationConfig(
              customAllowedOwners: {customOwner},),
        );

        expect(result.isValid, isTrue);
        expect(
            result.context?['validation_type'], equals('custom_allowed_owner'),);
        expect(
            result.context?['matched_owner'], equals(customOwner.toBase58()),);
      });

      test('should allow any ownership when strict validation is disabled',
          () async {
        // Setup: Account owned by wrong program, but permissive config
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: wrongProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
          config: AccountOwnershipValidationConfig.permissive,
        );

        expect(result.isValid, isTrue);
        expect(
            result.context?['validation_type'], equals('permissive_allowed'),);
      });
    });

    group('Batch Validation', () {
      test('should validate multiple accounts correctly', () async {
        final account1 =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final account2 =
            PublicKey.fromBase58('11111111111111111111111111111113');
        final account3 =
            PublicKey.fromBase58('11111111111111111111111111111114');

        // Setup: Mix of valid and invalid accounts
        mockConnection.setAccountInfo(
            account1, MockAccountInfo(owner: testProgramId),);
        mockConnection.setAccountInfo(
            account2, MockAccountInfo(owner: wrongProgramId),);
        mockConnection.setAccountInfo(account3, null); // Non-existent

        final results = await AccountOwnershipValidator.validateBatch(
          accounts: {
            account1: testProgramId,
            account2: testProgramId,
            account3: testProgramId,
          },
          connection: mockConnection,
        );

        expect(results, hasLength(3));
        expect(results[0].isValid, isTrue);
        expect(results[1].isValid, isFalse);
        expect(results[2].isValid, isFalse);
        expect(results[2].accountExists, isFalse);
      });
    });

    group('Validation with Exceptions', () {
      test('should throw exception on validation failure', () async {
        // Setup: Account with wrong ownership
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: wrongProgramId),
        );

        expect(
          () => AccountOwnershipValidator.validateOrThrow(
            accountAddress: testAccountAddress,
            expectedProgramId: testProgramId,
            connection: mockConnection,
          ),
          throwsA(isA<AccountOwnershipValidationException>()),
        );
      });

      test('should not throw exception on successful validation', () async {
        // Setup: Account with correct ownership
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: testProgramId),
        );

        await AccountOwnershipValidator.validateOrThrow(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );
        // No exception should be thrown
      });
    });

    group('Owner Matching', () {
      test('should find matching owner from set of program IDs', () async {
        final programId1 =
            PublicKey.fromBase58('BPFLoaderUpgradeab1e11111111111111111111111');
        final programId2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
        final programId3 =
            PublicKey.fromBase58('11111111111111111111111111111112');

        // Setup: Account owned by programId2
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: programId2),
        );

        final matchingOwner = await AccountOwnershipValidator.findMatchingOwner(
          accountAddress: testAccountAddress,
          programIds: {programId1, programId2, programId3},
          connection: mockConnection,
        );

        expect(matchingOwner, equals(programId2));
      });

      test('should return null when no matching owner found', () async {
        final programId1 =
            PublicKey.fromBase58('BPFLoaderUpgradeab1e11111111111111111111111');
        final programId2 =
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

        // Setup: Account owned by different program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: wrongProgramId),
        );

        final matchingOwner = await AccountOwnershipValidator.findMatchingOwner(
          accountAddress: testAccountAddress,
          programIds: {programId1, programId2},
          connection: mockConnection,
        );

        expect(matchingOwner, isNull);
      });

      test('should return null for non-existent account', () async {
        final programId1 =
            PublicKey.fromBase58('BPFLoaderUpgradeab1e11111111111111111111111');

        // Setup: No account info
        mockConnection.setAccountInfo(testAccountAddress, null);

        final matchingOwner = await AccountOwnershipValidator.findMatchingOwner(
          accountAddress: testAccountAddress,
          programIds: {programId1},
          connection: mockConnection,
        );

        expect(matchingOwner, isNull);
      });
    });

    group('Well-Known Programs', () {
      test('should identify well-known programs correctly', () async {
        expect(
            AccountOwnershipValidator.isWellKnownProgram(
                AccountOwnershipValidator.systemProgramId,),
            isTrue,);
        expect(
            AccountOwnershipValidator.isWellKnownProgram(
                AccountOwnershipValidator.tokenProgramId,),
            isTrue,);
        expect(
            AccountOwnershipValidator.isWellKnownProgram(
                AccountOwnershipValidator.token2022ProgramId,),
            isTrue,);
        expect(AccountOwnershipValidator.isWellKnownProgram(testProgramId),
            isFalse,);
      });

      test('should return correct names for well-known programs', () async {
        expect(
            AccountOwnershipValidator.getWellKnownProgramName(
                AccountOwnershipValidator.systemProgramId,),
            equals('System Program'),);
        expect(
            AccountOwnershipValidator.getWellKnownProgramName(
                AccountOwnershipValidator.tokenProgramId,),
            equals('SPL Token Program'),);
        expect(
            AccountOwnershipValidator.getWellKnownProgramName(
                AccountOwnershipValidator.token2022ProgramId,),
            equals('Token-2022 Program'),);
        expect(AccountOwnershipValidator.getWellKnownProgramName(testProgramId),
            isNull,);
      });
    });

    group('Error Messages', () {
      test('should format detailed ownership mismatch errors', () async {
        // Setup: Account with wrong ownership
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: AccountOwnershipValidator.systemProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.errorMessage,
            contains('Account ownership validation failed'),);
        expect(result.errorMessage, contains(testAccountAddress.toBase58()));
        expect(result.errorMessage, contains(testProgramId.toBase58()));
        expect(result.errorMessage,
            contains(AccountOwnershipValidator.systemProgramId.toBase58()),);
        expect(result.errorMessage, contains('System Program'));
      });

      test('should provide context for token program ownership', () async {
        // Setup: Account owned by token program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: AccountOwnershipValidator.tokenProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.errorMessage, contains('SPL Token Program'));
      });

      test('should provide context for Token-2022 program ownership', () async {
        // Setup: Account owned by Token-2022 program
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: AccountOwnershipValidator.token2022ProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.errorMessage, contains('Token-2022 Program'));
      });
    });

    group('Statistics', () {
      test('should track validation statistics correctly', () async {
        // Reset statistics
        AccountOwnershipValidator.resetStatistics();
        expect(AccountOwnershipValidator.statistics['totalValidations'],
            equals(0),);

        // Setup accounts
        final account1 =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final account2 =
            PublicKey.fromBase58('11111111111111111111111111111113');

        mockConnection.setAccountInfo(
            account1, MockAccountInfo(owner: testProgramId),);
        mockConnection.setAccountInfo(
            account2, MockAccountInfo(owner: wrongProgramId),);

        // Perform validations
        await AccountOwnershipValidator.validateSingle(
          accountAddress: account1,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        await AccountOwnershipValidator.validateSingle(
          accountAddress: account2,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        final stats = AccountOwnershipValidator.statistics;
        expect(stats['totalValidations'], equals(2));
        expect(stats['successes'], equals(1));
        expect(stats['failures'], equals(1));
      });

      test('should reset statistics correctly', () async {
        // Perform some validations first
        mockConnection.setAccountInfo(
            testAccountAddress, MockAccountInfo(owner: testProgramId),);

        await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(AccountOwnershipValidator.statistics['totalValidations'],
            greaterThan(0),);

        // Reset and verify
        AccountOwnershipValidator.resetStatistics();
        final stats = AccountOwnershipValidator.statistics;
        expect(stats['totalValidations'], equals(0));
        expect(stats['successes'], equals(0));
        expect(stats['failures'], equals(0));
      });
    });

    group('Result and Exception Classes', () {
      test('should create successful validation result correctly', () async {
        final result = AccountOwnershipValidationResult.success(
          accountAddress: testAccountAddress,
          actualOwner: testProgramId,
          context: {'test': 'value'},
        );

        expect(result.isValid, isTrue);
        expect(result.accountAddress, equals(testAccountAddress));
        expect(result.actualOwner, equals(testProgramId));
        expect(result.accountExists, isTrue);
        expect(result.context?['test'], equals('value'));
      });

      test('should create failed validation result correctly', () async {
        final result = AccountOwnershipValidationResult.failure(
          accountAddress: testAccountAddress,
          errorMessage: 'Test error',
          expectedOwner: testProgramId,
          actualOwner: wrongProgramId,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage, equals('Test error'));
        expect(result.expectedOwner, equals(testProgramId));
        expect(result.actualOwner, equals(wrongProgramId));
      });

      test('should format result toString correctly', () async {
        final successResult = AccountOwnershipValidationResult.success(
          accountAddress: testAccountAddress,
          actualOwner: testProgramId,
        );

        final failureResult = AccountOwnershipValidationResult.failure(
          accountAddress: testAccountAddress,
          errorMessage: 'Test error',
        );

        expect(successResult.toString(), contains('isValid: true'));
        expect(
            successResult.toString(), contains(testAccountAddress.toBase58()),);

        expect(failureResult.toString(), contains('isValid: false'));
        expect(failureResult.toString(), contains('Test error'));
      });

      test('should create exception with result correctly', () async {
        final result = AccountOwnershipValidationResult.failure(
          accountAddress: testAccountAddress,
          errorMessage: 'Test error',
        );

        final exception = AccountOwnershipValidationException(result);
        expect(exception.result, equals(result));
        expect(exception.toString(), contains('Test error'));
      });
    });

    group('Configuration Classes', () {
      test('should use correct default configurations', () async {
        expect(
            AccountOwnershipValidationConfig.strict.strictValidation, isTrue,);
        expect(
            AccountOwnershipValidationConfig.strict.bypassValidation, isFalse,);

        expect(AccountOwnershipValidationConfig.permissive.allowSystemOwned,
            isTrue,);
        expect(
            AccountOwnershipValidationConfig.permissive.allowTokenProgramOwned,
            isTrue,);
        expect(AccountOwnershipValidationConfig.permissive.strictValidation,
            isFalse,);

        expect(
            AccountOwnershipValidationConfig.testing.bypassValidation, isTrue,);
      });
    });

    group('Edge Cases', () {
      test('should handle connection errors gracefully', () async {
        // Create a connection that throws errors
        final errorConnection = MockConnection();
        // Don't set any account info, so it will return null by default

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: errorConnection,
        );

        expect(result.isValid, isFalse);
        expect(result.accountExists, isFalse);
      });

      test('should handle empty account data', () async {
        // Setup: Account with no data
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: testProgramId, data: []),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.isValid, isTrue);
        expect(result.context?['account_data_length'], equals(0));
      });

      test('should handle null account data', () async {
        // Setup: Account with null data
        mockConnection.setAccountInfo(
          testAccountAddress,
          MockAccountInfo(owner: testProgramId),
        );

        final result = await AccountOwnershipValidator.validateSingle(
          accountAddress: testAccountAddress,
          expectedProgramId: testProgramId,
          connection: mockConnection,
        );

        expect(result.isValid, isTrue);
        expect(result.context?['account_data_length'], equals(0));
      });
    });
  });
}
