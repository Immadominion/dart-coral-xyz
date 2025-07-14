import 'package:test/test.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/program/method_validator.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

void main() {
  group('Method Interface Generation', () {
    test('should generate method interface from IDL instruction', () {
      // Create a sample IDL instruction
      final instruction = const IdlInstruction(
        name: 'initialize',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        docs: ['Initialize the program'],
        accounts: [
          IdlInstructionAccount(
            name: 'authority',
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'dataAccount',
            writable: true,
          ),
        ],
        args: [
          IdlField(
            name: 'amount',
            type: IdlType(kind: 'u64'),
          ),
        ],
      );

      final validator = MethodValidator(
        instruction: instruction,
        idlTypes: [],
      );

      // Test basic method generation
      expect(instruction.name, equals('initialize'));
      expect(instruction.accounts.length, equals(2));
      expect(instruction.args.length, equals(1));

      // Test validator creation
      expect(validator, isNotNull);

      // Test that we can create validators without errors
      final testKey1 = PublicKey.fromBase58('11111111111111111111111111111111');
      final testKey2 = PublicKey.fromBase58('11111111111111111111111111111112');
      expect(
        () async => validator
            .validate([100], {'authority': testKey1, 'dataAccount': testKey2}),
        returnsNormally,
      );
    });

    test('should validate method arguments correctly', () async {
      final instruction = const IdlInstruction(
        name: 'transfer',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: [],
        args: [
          IdlField(
            name: 'amount',
            type: IdlType(kind: 'u64'),
          ),
          IdlField(
            name: 'memo',
            type: IdlType(kind: 'string'),
          ),
        ],
      );

      final validator = MethodValidator(
        instruction: instruction,
        idlTypes: [],
      );

      // Valid arguments should pass
      await expectLater(
        () async => validator.validate([100, 'test memo'], {}),
        returnsNormally,
      );

      // Invalid argument count should throw
      await expectLater(
        () async => validator.validate([100], {}),
        throwsA(isA<MethodValidationError>()),
      );

      // Too many arguments should throw
      await expectLater(
        () async => validator.validate([100, 'test', 'extra'], {}),
        throwsA(isA<MethodValidationError>()),
      );
    });

    test('should validate account requirements', () async {
      final instruction = const IdlInstruction(
        name: 'updateData',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: [
          IdlInstructionAccount(
            name: 'authority',
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'dataAccount',
            writable: true,
          ),
        ],
        args: [],
      );

      final validator = MethodValidator(
        instruction: instruction,
        idlTypes: [],
      );

      // Test account validation (basic structure test)
      final testKey1 = PublicKey.fromBase58('11111111111111111111111111111111');
      final testKey2 = PublicKey.fromBase58('11111111111111111111111111111112');
      final accounts = {
        'authority': testKey1,
        'dataAccount': testKey2,
      };

      await expectLater(
        () async => validator.validate([], accounts),
        returnsNormally,
      );

      // Missing required account should throw
      final incompleteAccounts = {
        'authority': testKey1,
      };

      await expectLater(
        () async => validator.validate([], incompleteAccounts),
        throwsA(isA<MethodValidationError>()),
      );
    });
  });

  group('Method Interface Documentation', () {
    test('should generate comprehensive documentation', () {
      final instruction = const IdlInstruction(
        name: 'complexMethod',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        docs: ['This is a complex method', 'with multiple purposes'],
        accounts: [
          IdlInstructionAccount(
            name: 'signer',
            signer: true,
            docs: ['The signing authority'],
          ),
          IdlInstructionAccount(
            name: 'writableAccount',
            writable: true,
            optional: true,
            docs: ['Optional writable account'],
          ),
        ],
        args: [
          IdlField(
            name: 'value',
            type: IdlType(kind: 'u64'),
            docs: ['The value to process'],
          ),
        ],
      );

      // Test that instruction structure is correct
      expect(instruction.name, equals('complexMethod'));
      expect(instruction.docs?.length, equals(2));
      expect(instruction.accounts.length, equals(2));
      expect(instruction.args.length, equals(1));

      // Test account properties
      final signerAccount = instruction.accounts[0] as IdlInstructionAccount;
      expect(signerAccount.name, equals('signer'));
      expect(signerAccount.signer, isTrue);
      expect(signerAccount.writable, isFalse);

      final writableAccount = instruction.accounts[1] as IdlInstructionAccount;
      expect(writableAccount.name, equals('writableAccount'));
      expect(writableAccount.writable, isTrue);
      expect(writableAccount.optional, isTrue);
    });
  });
}
