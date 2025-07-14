import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('InstructionDefinition', () {
    late IdlInstruction sampleInstruction;

    setUp(() {
      sampleInstruction = const IdlInstruction(
        name: 'initialize',
        docs: ['Initialize a new account'],
        args: [
          IdlField(
            name: 'amount',
            type: IdlType(kind: 'u64'),
            docs: ['Amount to initialize'],
          ),
          IdlField(
            name: 'authority',
            type: IdlType(kind: 'publicKey'),
            docs: ['Authority for the account'],
          ),
        ],
        accounts: [
          IdlInstructionAccount(
            name: 'account',
            docs: ['Account to initialize'],
            writable: true,
          ),
          IdlInstructionAccount(
            name: 'authority',
            docs: ['Authority'],
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'systemProgram',
            docs: ['System program'],
            optional: true,
          ),
        ],
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        returns: 'bool',
      );
    });

    test('creates instruction definition from IDL', () {
      final definition = InstructionDefinition.fromIdl(sampleInstruction);

      expect(definition.name, equals('initialize'));
      expect(definition.docs, equals(['Initialize a new account']));
      expect(definition.discriminator, equals([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(definition.returnsType, equals('bool'));
      expect(definition.arguments.length, equals(2));
      expect(definition.accounts.length, equals(3));
    });

    test('validates arguments correctly', () {
      final definition = InstructionDefinition.fromIdl(sampleInstruction);

      // Valid arguments
      final validArgs = {
        'amount': 1000,
        'authority': 'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',
      };
      final validResult = definition.validateArguments(validArgs);
      expect(validResult.isValid, isTrue);
      expect(validResult.errors, isEmpty);

      // Missing required argument
      final missingArgs = {'amount': 1000};
      final missingResult = definition.validateArguments(missingArgs);
      expect(missingResult.isValid, isFalse);
      expect(missingResult.errors,
          contains('Missing required argument: authority'),);

      // Invalid type
      final invalidArgs = {
        'amount': 'not a number',
        'authority': 'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',
      };
      final invalidResult = definition.validateArguments(invalidArgs);
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.length, greaterThan(0));
    });

    test('validates accounts correctly', () {
      final definition = InstructionDefinition.fromIdl(sampleInstruction);

      // Valid accounts
      final validAccounts = {
        'account': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
        'authority': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
        'systemProgram':
            PublicKey.fromBase58('11111111111111111111111111111111'),
      };
      final validResult = definition.validateAccounts(validAccounts);
      expect(validResult.isValid, isTrue);
      expect(validResult.errors, isEmpty);

      // Missing required account
      final missingAccounts = {
        'account': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
      };
      final missingResult = definition.validateAccounts(missingAccounts);
      expect(missingResult.isValid, isFalse);
      expect(missingResult.errors,
          contains('Missing required account: authority'),);

      // Optional account can be missing
      final withoutOptional = {
        'account': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
        'authority': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
      };
      final optionalResult = definition.validateAccounts(withoutOptional);
      expect(optionalResult.isValid, isTrue);
    });

    test('validates complete instruction call', () {
      final definition = InstructionDefinition.fromIdl(sampleInstruction);

      final validArgs = {
        'amount': 1000,
        'authority': 'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',
      };
      final validAccounts = {
        'account': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
        'authority': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
      };

      final result = definition.validate(
        arguments: validArgs,
        accounts: validAccounts,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });

  group('ArgumentDefinition', () {
    test('creates from IDL field', () {
      final field = const IdlField(
        name: 'amount',
        type: IdlType(kind: 'u64'),
        docs: ['Amount parameter'],
      );

      final argDef = ArgumentDefinition.fromIdlField(field);
      expect(argDef.name, equals('amount'));
      expect(argDef.type.kind, equals('u64'));
      expect(argDef.docs, equals(['Amount parameter']));
      expect(argDef.isRequired, isTrue);
    });

    test('validates types correctly', () {
      final u64Field = const IdlField(
        name: 'amount',
        type: IdlType(kind: 'u64'),
      );
      final argDef = ArgumentDefinition.fromIdlField(u64Field);

      // Valid integer
      final validResult = argDef.validateType(1000);
      expect(validResult.isValid, isTrue);

      // Invalid type
      final invalidResult = argDef.validateType('not a number');
      expect(invalidResult.isValid, isFalse);
    });
  });

  group('InstructionAccountDefinition', () {
    test('creates from IDL instruction account', () {
      final account = const IdlInstructionAccount(
        name: 'authority',
        docs: ['Authority account'],
        signer: true,
      );

      final accountDef = InstructionAccountDefinition.fromIdlAccount(account);
      expect(accountDef.name, equals('authority'));
      expect(accountDef.docs, equals(['Authority account']));
      expect(accountDef.isWritable, isFalse);
      expect(accountDef.isSigner, isTrue);
      expect(accountDef.isOptional, isFalse);
      expect(accountDef.isRequired, isTrue);
    });

    test('validates accounts correctly', () {
      final account = const IdlInstructionAccount(
        name: 'authority',
        signer: true,
      );
      final accountDef = InstructionAccountDefinition.fromIdlAccount(account);

      // Valid PublicKey
      final publicKey =
          PublicKey.fromBase58('GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs');
      final validResult = accountDef.validateAccount(publicKey);
      expect(validResult.isValid, isTrue);

      // Valid string address
      final stringResult = accountDef
          .validateAccount('GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs');
      expect(stringResult.isValid, isTrue);

      // Invalid type
      final invalidResult = accountDef.validateAccount(123);
      expect(invalidResult.isValid, isFalse);
    });
  });

  group('TypeValidator', () {
    test('validates basic types correctly', () {
      // Boolean validator
      final boolValidator = TypeValidator.fromIdlType(const IdlType(kind: 'bool'));
      expect(boolValidator.validate(true).isValid, isTrue);
      expect(boolValidator.validate('not bool').isValid, isFalse);

      // Integer validator
      final u64Validator = TypeValidator.fromIdlType(const IdlType(kind: 'u64'));
      expect(u64Validator.validate(123).isValid, isTrue);
      expect(u64Validator.validate('not int').isValid, isFalse);

      // String validator
      final stringValidator =
          TypeValidator.fromIdlType(const IdlType(kind: 'string'));
      expect(stringValidator.validate('hello').isValid, isTrue);
      expect(stringValidator.validate(123).isValid, isFalse);

      // PublicKey validator
      final pubkeyValidator =
          TypeValidator.fromIdlType(const IdlType(kind: 'publicKey'));
      expect(
          pubkeyValidator
              .validate('GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs')
              .isValid,
          isTrue,);
      expect(
          pubkeyValidator
              .validate(PublicKey.fromBase58(
                  'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),)
              .isValid,
          isTrue,);
      expect(pubkeyValidator.validate(123).isValid, isFalse);
    });

    test('validates complex types correctly', () {
      // Array validator
      final arrayValidator = TypeValidator.fromIdlType(const IdlType(kind: 'array'));
      expect(arrayValidator.validate([1, 2, 3]).isValid, isTrue);
      expect(arrayValidator.validate('not array').isValid, isFalse);

      // Vec validator
      final vecValidator = TypeValidator.fromIdlType(const IdlType(kind: 'vec'));
      expect(vecValidator.validate([1, 2, 3]).isValid, isTrue);
      expect(vecValidator.validate('not vec').isValid, isFalse);

      // Option validator (allows any)
      final optionValidator =
          TypeValidator.fromIdlType(const IdlType(kind: 'option'));
      expect(optionValidator.validate(null).isValid, isTrue);
      expect(optionValidator.validate(123).isValid, isTrue);
      expect(optionValidator.validate('anything').isValid, isTrue);
    });
  });

  group('InstructionConstraints', () {
    test('creates from IDL instruction', () {
      final instruction = const IdlInstruction(
        name: 'test',
        args: [
          IdlField(name: 'arg1', type: IdlType(kind: 'u64')),
          IdlField(name: 'arg2', type: IdlType(kind: 'string')),
        ],
        accounts: [
          IdlInstructionAccount(
            name: 'account1',
            writable: true,
          ),
          IdlInstructionAccount(
            name: 'signer',
            signer: true,
          ),
        ],
      );

      final constraints = InstructionConstraints.fromIdl(instruction);
      expect(constraints.requiresSignature, isTrue); // Has signer account
      expect(constraints.maxArguments, greaterThanOrEqualTo(2));
      expect(constraints.maxAccounts, greaterThanOrEqualTo(2));
    });

    test('validates constraints correctly', () {
      final constraints = const InstructionConstraints(
        maxArguments: 5,
        maxAccounts: 10,
        requiresSignature: true,
      );

      // Valid constraints
      expect(
        constraints.validateConstraints(
          argumentCount: 3,
          accountCount: 5,
          hasSignature: true,
        ),
        isTrue,
      );

      // Too many arguments
      expect(
        constraints.validateConstraints(
          argumentCount: 10,
          accountCount: 5,
          hasSignature: true,
        ),
        isFalse,
      );

      // Missing signature
      expect(
        constraints.validateConstraints(
          argumentCount: 3,
          accountCount: 5,
          hasSignature: false,
        ),
        isFalse,
      );
    });
  });

  group('Integration Tests', () {
    test('handles complex instruction with nested accounts', () {
      final instruction = const IdlInstruction(
        name: 'complexInstruction',
        docs: ['A complex instruction with multiple account types'],
        args: [
          IdlField(
            name: 'data',
            type: IdlType(
              kind: 'array',
              inner: IdlType(kind: 'u8'),
              size: 32,
            ),
          ),
          IdlField(
            name: 'metadata',
            type: IdlType(kind: 'defined', defined: 'Metadata'),
          ),
        ],
        accounts: [
          IdlInstructionAccounts(
            name: 'accounts',
            accounts: [
              IdlInstructionAccount(
                name: 'source',
                writable: true,
              ),
              IdlInstructionAccount(
                name: 'destination',
                writable: true,
              ),
            ],
          ),
          IdlInstructionAccount(
            name: 'authority',
            signer: true,
          ),
        ],
      );

      final definition = InstructionDefinition.fromIdl(instruction);

      expect(definition.name, equals('complexInstruction'));
      expect(definition.arguments.length, equals(2));
      expect(
          definition.accounts.length, equals(2),); // Group + individual account

      // Validate with proper arguments and accounts
      final args = {
        'data': List.generate(32, (i) => i),
        'metadata': {'field1': 'value1'},
      };
      final accounts = {
        'accounts': 'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',
        'authority': PublicKey.fromBase58(
            'GjwELjxNsxkopfazDKLo5Pe8eHbznfM7VHuYQ5HxETKs',),
      };

      final result = definition.validate(arguments: args, accounts: accounts);
      expect(result.isValid, isTrue);
    });

    test('instruction definition metadata access', () {
      final instruction = const IdlInstruction(
        name: 'testInstruction',
        docs: ['Test docs'],
        args: [],
        accounts: [],
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        returns: 'void',
      );

      final definition = InstructionDefinition.fromIdl(instruction);
      final metadata = definition.metadata;

      expect(metadata.name, equals('testInstruction'));
      expect(metadata.docs, equals(['Test docs']));
      expect(metadata.discriminator, equals([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(metadata.returnsType, equals('void'));
    });
  });
}
