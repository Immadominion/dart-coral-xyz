import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Account Error Types', () {
    late PublicKey testAccountAddress;
    late PublicKey expectedOwner;
    late PublicKey actualOwner;
    late List<String> testLogs;

    setUp(() {
      testAccountAddress =
          PublicKey.fromBase58('BPFLoaderUpgradeab1e11111111111111111111111');
      expectedOwner =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
      actualOwner = PublicKey.fromBase58('11111111111111111111111111111111');
      testLogs = ['Program log: Test error'];
    });

    group('AccountDiscriminatorMismatchError', () {
      test('creates error with correct properties', () {
        final expected = [0xFF, 0x00, 0xFF, 0x00, 0x11, 0x22, 0x33, 0x44];
        final actual = [0xFE, 0x01, 0xFE, 0x01, 0x11, 0x22, 0x33, 0x44];

        final error = AccountDiscriminatorMismatchError(
          expectedDiscriminator: expected,
          actualDiscriminator: actual,
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
          accountName: 'TestAccount',
        );

        expect(error.expectedDiscriminator, equals(expected));
        expect(error.actualDiscriminator, equals(actual));
        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountName, equals('TestAccount'));
        expect(error.errorCode.number,
            equals(LangErrorCode.accountDiscriminatorMismatch),);
        expect(error.expectedHex, equals('FF00FF0011223344'));
        expect(error.actualHex, equals('FE01FE0111223344'));
      });

      test('creates error from factory method', () {
        final expected = [0xFF, 0x00, 0xFF, 0x00];
        final actual = [0xFE, 0x01, 0xFE, 0x01];

        final error = AccountDiscriminatorMismatchError.fromComparison(
          expected: expected,
          actual: actual,
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error.expectedDiscriminator, equals(expected));
        expect(error.actualDiscriminator, equals(actual));
      });

      test('formats toString correctly', () {
        final expected = [0xFF, 0x00];
        final actual = [0xFE, 0x01];

        final error = AccountDiscriminatorMismatchError(
          expectedDiscriminator: expected,
          actualDiscriminator: actual,
          errorLogs: testLogs,
          logs: testLogs,
          accountName: 'TestAccount',
        );

        final str = error.toString();
        expect(str, contains('TestAccount'));
        expect(str, contains('AccountDiscriminatorMismatch'));
        expect(str, contains('FF00'));
        expect(str, contains('FE01'));
      });
    });

    group('AccountOwnedByWrongProgramError', () {
      test('creates error with correct properties', () {
        final error = AccountOwnedByWrongProgramError(
          expectedOwner: expectedOwner,
          actualOwner: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
        );

        expect(error.expectedOwner, equals(expectedOwner));
        expect(error.actualOwner, equals(actualOwner));
        expect(error.errorCode.number,
            equals(LangErrorCode.accountOwnedByWrongProgram),);
        expect(error.error.comparedValues, isA<ComparedPublicKeys>());
      });

      test('creates error from factory method', () {
        final error = AccountOwnedByWrongProgramError.fromValidation(
          expected: expectedOwner,
          actual: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error.expectedOwner, equals(expectedOwner));
        expect(error.actualOwner, equals(actualOwner));
      });
    });

    group('AccountNotInitializedError', () {
      test('creates error with correct properties', () {
        final error = AccountNotInitializedError(
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
          accountName: 'UninitializedAccount',
        );

        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountName, equals('UninitializedAccount'));
        expect(error.errorCode.number,
            equals(LangErrorCode.accountNotInitialized),);
      });

      test('creates error from factory method', () {
        final error = AccountNotInitializedError.fromAddress(
          accountAddress: testAccountAddress,
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error.accountAddress, equals(testAccountAddress));
      });
    });

    group('AccountDidNotDeserializeError', () {
      test('creates error with correct properties', () {
        final error = AccountDidNotDeserializeError(
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
          accountDataSize: 100,
          expectedStructure: 'TestStruct',
        );

        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountDataSize, equals(100));
        expect(error.expectedStructure, equals('TestStruct'));
        expect(error.errorCode.number,
            equals(LangErrorCode.accountDidNotDeserialize),);
      });

      test('creates error from factory method', () {
        final error = AccountDidNotDeserializeError.fromFailure(
          errorLogs: testLogs,
          logs: testLogs,
          dataSize: 50,
        );

        expect(error.accountDataSize, equals(50));
      });
    });

    group('AccountNotSystemOwnedError', () {
      test('creates error with correct properties', () {
        final error = AccountNotSystemOwnedError(
          actualOwner: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
        );

        expect(error.actualOwner, equals(actualOwner));
        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.errorCode.number,
            equals(LangErrorCode.accountNotSystemOwned),);
      });

      test('creates error from factory method', () {
        final error = AccountNotSystemOwnedError.fromValidation(
          actualOwner: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error.actualOwner, equals(actualOwner));
      });
    });

    group('AccountNotSignerError', () {
      test('creates error with correct properties', () {
        final error = AccountNotSignerError(
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
          accountName: 'NonSignerAccount',
        );

        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountName, equals('NonSignerAccount'));
        expect(error.errorCode.number, equals(LangErrorCode.accountNotSigner));
      });

      test('creates error from factory method', () {
        final error = AccountNotSignerError.fromValidation(
          accountAddress: testAccountAddress,
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error.accountAddress, equals(testAccountAddress));
      });
    });

    group('AccountNotMutableError', () {
      test('creates error with correct properties', () {
        final error = AccountNotMutableError(
          errorLogs: testLogs,
          logs: testLogs,
          accountAddress: testAccountAddress,
          accountName: 'ImmutableAccount',
        );

        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountName, equals('ImmutableAccount'));
        expect(error.errorCode.number, equals(LangErrorCode.accountNotMutable));
      });

      test('creates error from factory method', () {
        final error = AccountNotMutableError.fromValidation(
          accountAddress: testAccountAddress,
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error.accountAddress, equals(testAccountAddress));
      });
    });

    group('AccountErrorFactory', () {
      test('creates discriminator mismatch error', () {
        final expected = [0xFF, 0x00];
        final actual = [0xFE, 0x01];

        final error = AccountErrorFactory.discriminatorMismatch(
          expected: expected,
          actual: actual,
          accountAddress: testAccountAddress,
        );

        expect(error.expectedDiscriminator, equals(expected));
        expect(error.actualDiscriminator, equals(actual));
        expect(error.logs, isNotEmpty);
      });

      test('creates wrong program owner error', () {
        final error = AccountErrorFactory.wrongProgramOwner(
          expectedOwner: expectedOwner,
          actualOwner: actualOwner,
          accountAddress: testAccountAddress,
        );

        expect(error.expectedOwner, equals(expectedOwner));
        expect(error.actualOwner, equals(actualOwner));
        expect(error.logs, isNotEmpty);
      });

      test('creates not initialized error', () {
        final error = AccountErrorFactory.notInitialized(
          accountAddress: testAccountAddress,
          accountName: 'TestAccount',
        );

        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountName, equals('TestAccount'));
        expect(error.logs, isNotEmpty);
      });

      test('creates deserialization failed error', () {
        final error = AccountErrorFactory.deserializationFailed(
          accountAddress: testAccountAddress,
          dataSize: 100,
          expectedStructure: 'TestStruct',
        );

        expect(error.accountAddress, equals(testAccountAddress));
        expect(error.accountDataSize, equals(100));
        expect(error.expectedStructure, equals('TestStruct'));
        expect(error.logs, isNotEmpty);
      });
    });

    group('Error Code Integration', () {
      test('all account errors use correct error codes', () {
        final discriminatorError = AccountDiscriminatorMismatchError(
          expectedDiscriminator: [0xFF],
          actualDiscriminator: [0xFE],
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(discriminatorError.errorCode.number, equals(3002));

        final wrongOwnerError = AccountOwnedByWrongProgramError(
          expectedOwner: expectedOwner,
          actualOwner: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(wrongOwnerError.errorCode.number, equals(3007));

        final notInitializedError = AccountNotInitializedError(
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(notInitializedError.errorCode.number, equals(3012));

        final deserializeError = AccountDidNotDeserializeError(
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(deserializeError.errorCode.number, equals(3003));

        final notSystemOwnedError = AccountNotSystemOwnedError(
          actualOwner: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(notSystemOwnedError.errorCode.number, equals(3011));

        final notSignerError = AccountNotSignerError(
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(notSignerError.errorCode.number, equals(3010));

        final notMutableError = AccountNotMutableError(
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(notMutableError.errorCode.number, equals(3006));
      });

      test('all account errors have correct error messages', () {
        final discriminatorError = AccountDiscriminatorMismatchError(
          expectedDiscriminator: [0xFF],
          actualDiscriminator: [0xFE],
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(
            discriminatorError.error.errorMessage, contains('discriminator'),);
        expect(
            discriminatorError.error.errorMessage, contains('did not match'),);

        final wrongOwnerError = AccountOwnedByWrongProgramError(
          expectedOwner: expectedOwner,
          actualOwner: actualOwner,
          errorLogs: testLogs,
          logs: testLogs,
        );
        expect(wrongOwnerError.error.errorMessage, contains('owned by'));
        expect(
            wrongOwnerError.error.errorMessage, contains('different program'),);
      });
    });

    group('Error Context and Inheritance', () {
      test('account errors inherit from AccountError and AnchorError', () {
        final error = AccountDiscriminatorMismatchError(
          expectedDiscriminator: [0xFF],
          actualDiscriminator: [0xFE],
          errorLogs: testLogs,
          logs: testLogs,
        );

        expect(error, isA<AccountError>());
        expect(error, isA<AnchorError>());
        expect(error.accountContext, contains('account'));
      });

      test('account context formatting', () {
        final errorWithNameAndAddress = AccountDiscriminatorMismatchError(
          expectedDiscriminator: [0xFF],
          actualDiscriminator: [0xFE],
          errorLogs: testLogs,
          logs: testLogs,
          accountName: 'TestAccount',
          accountAddress: testAccountAddress,
        );

        final context = errorWithNameAndAddress.accountContext;
        expect(context, contains('TestAccount'));
        expect(context, contains(testAccountAddress.toBase58()));

        final errorWithNameOnly = AccountDiscriminatorMismatchError(
          expectedDiscriminator: [0xFF],
          actualDiscriminator: [0xFE],
          errorLogs: testLogs,
          logs: testLogs,
          accountName: 'TestAccount',
        );

        expect(errorWithNameOnly.accountContext, contains('TestAccount'));
        expect(errorWithNameOnly.accountContext,
            isNot(contains(testAccountAddress.toBase58())),);
      });
    });
  });
}
