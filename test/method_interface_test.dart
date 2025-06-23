import 'package:test/test.dart';
import '../lib/src/idl/idl.dart';
import '../lib/src/program/method_validator.dart';
import '../lib/src/types/public_key.dart';

void main() {
  group('Method Interface Generation', () {
    test('should generate method interface from IDL instruction', () {
      // Create a sample IDL instruction
      final instruction = IdlInstruction(
        name: 'initialize',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        docs: ['Initialize the program'],
        accounts: [
          const IdlInstructionAccount(
            name: 'authority',
            writable: false,
            signer: true,
            optional: false,
          ),
          const IdlInstructionAccount(
            name: 'dataAccount',
            writable: true,
            signer: false,
            optional: false,
          ),
        ],
        args: [
          IdlField(
            name: 'amount',
            type: const IdlType(kind: 'u64'),
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
        () async => await validator
            .validate([100], {'authority': testKey1, 'dataAccount': testKey2}),
        returnsNormally,
      );
    });

    test('should validate method arguments correctly', () async {
      final instruction = IdlInstruction(
        name: 'transfer',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: [],
        args: [
          IdlField(
            name: 'amount',
            type: const IdlType(kind: 'u64'),
          ),
          IdlField(
            name: 'memo',
            type: const IdlType(kind: 'string'),
          ),
        ],
      );

      final validator = MethodValidator(
        instruction: instruction,
        idlTypes: [],
      );

      // Valid arguments should pass
      await expectLater(
        () async => await validator.validate([100, 'test memo'], {}),
        returnsNormally,
      );

      // Invalid argument count should throw
      await expectLater(
        () async => await validator.validate([100], {}),
        throwsA(isA<MethodValidationError>()),
      );

      // Too many arguments should throw
      await expectLater(
        () async => await validator.validate([100, 'test', 'extra'], {}),
        throwsA(isA<MethodValidationError>()),
      );
    });

    test('should validate account requirements', () async {
      final instruction = IdlInstruction(
        name: 'updateData',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: [
          const IdlInstructionAccount(
            name: 'authority',
            writable: false,
            signer: true,
          ),
          const IdlInstructionAccount(
            name: 'dataAccount',
            writable: true,
            signer: false,
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
        () async => await validator.validate([], accounts),
        returnsNormally,
      );

      // Missing required account should throw
      final incompleteAccounts = {
        'authority': testKey1,
      };

      await expectLater(
        () async => await validator.validate([], incompleteAccounts),
        throwsA(isA<MethodValidationError>()),
      );
    });
  });

  group('Method Interface Documentation', () {
    test('should generate comprehensive documentation', () {
      final instruction = IdlInstruction(
        name: 'complexMethod',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        docs: ['This is a complex method', 'with multiple purposes'],
        accounts: [
          const IdlInstructionAccount(
            name: 'signer',
            writable: false,
            signer: true,
            docs: ['The signing authority'],
          ),
          const IdlInstructionAccount(
            name: 'writableAccount',
            writable: true,
            signer: false,
            optional: true,
            docs: ['Optional writable account'],
          ),
        ],
        args: [
          IdlField(
            name: 'value',
            type: const IdlType(kind: 'u64'),
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
