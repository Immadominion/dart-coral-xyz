/// Account Definition Metadata System Tests
///
/// Comprehensive test suite for the account definition system that validates
/// TypeScript Anchor client compatibility and covers all functionality.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('AccountDefinition', () {
    late Idl testIdl;
    late IdlAccount testAccount;
    late IdlTypeDef testTypeDef;

    setUp(() {
      // Create test IDL structure
      testTypeDef = IdlTypeDef(
        name: 'TestAccount',
        docs: ['Test account structure'],
        type: IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(
              name: 'authority',
              type: IdlType(kind: 'pubkey'),
            ),
            IdlField(
              name: 'balance',
              type: IdlType(kind: 'u64'),
            ),
            IdlField(
              name: 'name',
              type: IdlType(kind: 'string'),
            ),
            IdlField(
              name: 'optional_field',
              type: IdlType(kind: 'option', inner: IdlType(kind: 'u32')),
            ),
            IdlField(
              name: 'items',
              type: IdlType(kind: 'vec', inner: IdlType(kind: 'u16')),
            ),
            IdlField(
              name: 'fixed_array',
              type:
                  IdlType(kind: 'array', inner: IdlType(kind: 'u8'), size: 32),
            ),
          ],
        ),
      );

      testAccount = IdlAccount(
        name: 'TestAccount',
        docs: ['Test account'],
        type: testTypeDef.type,
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
      );

      testIdl = Idl(
        address: 'TestProgram1111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'test_program',
          version: '1.0.0',
          spec: '0.1.0',
        ),
        instructions: [],
        accounts: [testAccount],
        types: [testTypeDef],
      );
    });

    group('fromIdlAccount', () {
      test('creates account definition from IDL account', () {
        final accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);

        expect(accountDef.name, equals('TestAccount'));
        expect(accountDef.docs, equals(['Test account']));
        expect(accountDef.discriminator, equals([1, 2, 3, 4, 5, 6, 7, 8]));
        expect(accountDef.fields.length, equals(6));
      });

      test('extracts field definitions correctly', () {
        final accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);

        final authorityField = accountDef.getField('authority');
        expect(authorityField, isNotNull);
        expect(authorityField!.name, equals('authority'));
        expect(authorityField.typeInfo.typeName, equals('pubkey'));
        expect(authorityField.typeInfo.isFixedSize, isTrue);
        expect(authorityField.typeInfo.minimumSize, equals(32));
        expect(authorityField.isRequired, isTrue);

        final optionalField = accountDef.getField('optional_field');
        expect(optionalField, isNotNull);
        expect(optionalField!.typeInfo.typeName, equals('option'));
        expect(optionalField.typeInfo.isOptional, isTrue);
        expect(optionalField.isRequired, isFalse);

        final vectorField = accountDef.getField('items');
        expect(vectorField, isNotNull);
        expect(vectorField!.typeInfo.typeName, equals('vec'));
        expect(vectorField.typeInfo.isFixedSize, isFalse);
        expect(vectorField.typeInfo.isNested, isTrue);
      });

      test('creates validation rules correctly', () {
        final accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);

        expect(accountDef.validationRules.requireDiscriminator, isTrue);
        expect(
            accountDef.validationRules.requiredFields.length, greaterThan(0));
        expect(accountDef.validationRules.minimumSize,
            greaterThan(8)); // discriminator + fields
        expect(accountDef.validationRules.fieldConstraints.length, equals(6));
      });

      test('creates structure metadata correctly', () {
        final accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);

        expect(accountDef.structureMetadata.totalFields, equals(6));
        expect(accountDef.structureMetadata.fixedSizeFields, greaterThan(0));
        expect(accountDef.structureMetadata.variableSizeFields, greaterThan(0));
        expect(accountDef.structureMetadata.hasNestedStructures, isTrue);
        expect(accountDef.structureMetadata.serialization, equals('borsh'));
      });

      test('throws error when type definition not found', () {
        final accountWithoutType = IdlAccount(
          name: 'NonExistentAccount',
          type: IdlTypeDefType(kind: 'struct'),
        );

        expect(
          () => AccountDefinition.fromIdlAccount(
              accountWithoutType, testIdl.types),
          throwsA(isA<IdlError>()),
        );
      });
    });

    group('field access methods', () {
      late AccountDefinition accountDef;

      setUp(() {
        accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);
      });

      test('getField returns correct field', () {
        final field = accountDef.getField('authority');
        expect(field, isNotNull);
        expect(field!.name, equals('authority'));
      });

      test('getField returns null for non-existent field', () {
        final field = accountDef.getField('non_existent');
        expect(field, isNull);
      });

      test('hasField returns correct values', () {
        expect(accountDef.hasField('authority'), isTrue);
        expect(accountDef.hasField('non_existent'), isFalse);
      });

      test('requiredFields returns correct fields', () {
        final required = accountDef.requiredFields;
        expect(required.length, greaterThan(0));
        expect(required.any((f) => f.name == 'authority'), isTrue);
        expect(required.any((f) => f.name == 'optional_field'), isFalse);
      });

      test('optionalFields returns correct fields', () {
        final optional = accountDef.optionalFields;
        expect(optional.length, greaterThan(0));
        expect(optional.any((f) => f.name == 'optional_field'), isTrue);
        expect(optional.any((f) => f.name == 'authority'), isFalse);
      });

      test('fixedSizeFields returns correct fields', () {
        final fixedSize = accountDef.fixedSizeFields;
        expect(fixedSize.length, greaterThan(0));
        expect(fixedSize.any((f) => f.name == 'authority'), isTrue);
        expect(fixedSize.any((f) => f.name == 'balance'), isTrue);
        expect(fixedSize.any((f) => f.name == 'name'), isFalse);
      });

      test('variableSizeFields returns correct fields', () {
        final variableSize = accountDef.variableSizeFields;
        expect(variableSize.length, greaterThan(0));
        expect(variableSize.any((f) => f.name == 'name'), isTrue);
        expect(variableSize.any((f) => f.name == 'items'), isTrue);
        expect(variableSize.any((f) => f.name == 'authority'), isFalse);
      });
    });

    group('validateStructure', () {
      late AccountDefinition accountDef;

      setUp(() {
        accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);
      });

      test('validates correct discriminator', () {
        final validData = [1, 2, 3, 4, 5, 6, 7, 8] + List.filled(100, 0);
        final result = accountDef.validateStructure(validData);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.accountName, equals('TestAccount'));
      });

      test('detects incorrect discriminator', () {
        final invalidData = [0, 0, 0, 0, 0, 0, 0, 0] + List.filled(100, 0);
        final result = accountDef.validateStructure(invalidData);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('Discriminator mismatch')),
            isTrue);
      });

      test('detects insufficient data for discriminator', () {
        final shortData = [1, 2, 3, 4]; // Less than 8 bytes
        final result = accountDef.validateStructure(shortData);

        expect(result.isValid, isFalse);
        expect(
            result.errors.any(
                (e) => e.contains('Account data too short for discriminator')),
            isTrue);
      });

      test('detects data below minimum size', () {
        final smallData = [1, 2, 3, 4, 5, 6, 7, 8]; // Only discriminator
        final result = accountDef.validateStructure(smallData);

        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.contains('Account data below minimum size')),
            isTrue);
      });
    });

    group('calculateExpectedSize', () {
      late AccountDefinition accountDef;

      setUp(() {
        accountDef =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);
      });

      test('calculates size for fixed fields', () {
        final fieldValues = {
          'authority': 'TestAuthority111111111111111111111111',
          'balance': 1000,
        };

        final size = accountDef.calculateExpectedSize(fieldValues);
        expect(size, greaterThan(8)); // discriminator + field sizes
      });

      test('includes minimum size for missing required fields', () {
        final fieldValues = <String, dynamic>{};
        final size = accountDef.calculateExpectedSize(fieldValues);
        expect(size, equals(accountDef.validationRules.minimumSize));
      });
    });

    group('equality and comparison', () {
      test('accounts with same properties are equal', () {
        final accountDef1 =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);
        final accountDef2 =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);

        expect(accountDef1, equals(accountDef2));
        expect(accountDef1.hashCode, equals(accountDef2.hashCode));
      });
      test('accounts with different properties are not equal', () {
        final differentTypeDef = IdlTypeDef(
          name: 'DifferentAccount',
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [
              IdlField(name: 'different_field', type: IdlType(kind: 'u32')),
            ],
          ),
        );

        final differentAccount = IdlAccount(
          name: 'DifferentAccount',
          type: differentTypeDef.type,
          discriminator: [8, 7, 6, 5, 4, 3, 2, 1],
        );

        final accountDef1 =
            AccountDefinition.fromIdlAccount(testAccount, testIdl.types);
        final accountDef2 = AccountDefinition.fromIdlAccount(
            differentAccount, [differentTypeDef]);

        expect(accountDef1, isNot(equals(accountDef2)));
      });
    });
  });

  group('FieldDefinition', () {
    group('fromIdlField', () {
      test('creates definition for primitive types', () {
        final field = IdlField(name: 'test_u64', type: IdlType(kind: 'u64'));
        final fieldDef = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef.name, equals('test_u64'));
        expect(fieldDef.typeInfo.typeName, equals('u64'));
        expect(fieldDef.typeInfo.isFixedSize, isTrue);
        expect(fieldDef.typeInfo.minimumSize, equals(8));
        expect(fieldDef.isRequired, isTrue);
      });

      test('creates definition for optional types', () {
        final field = IdlField(
          name: 'optional_u32',
          type: IdlType(kind: 'option', inner: IdlType(kind: 'u32')),
        );
        final fieldDef = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef.name, equals('optional_u32'));
        expect(fieldDef.typeInfo.typeName, equals('option'));
        expect(fieldDef.typeInfo.isOptional, isTrue);
        expect(fieldDef.isRequired, isFalse);
        expect(fieldDef.typeInfo.innerType, isNotNull);
        expect(fieldDef.typeInfo.innerType!.typeName, equals('u32'));
      });

      test('creates definition for vector types', () {
        final field = IdlField(
          name: 'test_vec',
          type: IdlType(kind: 'vec', inner: IdlType(kind: 'u16')),
        );
        final fieldDef = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef.name, equals('test_vec'));
        expect(fieldDef.typeInfo.typeName, equals('vec'));
        expect(fieldDef.typeInfo.isFixedSize, isFalse);
        expect(fieldDef.typeInfo.isNested, isTrue);
        expect(fieldDef.typeInfo.minimumSize, equals(4)); // length prefix
      });

      test('creates definition for array types', () {
        final field = IdlField(
          name: 'test_array',
          type: IdlType(kind: 'array', inner: IdlType(kind: 'u8'), size: 16),
        );
        final fieldDef = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef.name, equals('test_array'));
        expect(fieldDef.typeInfo.typeName, equals('array'));
        expect(fieldDef.typeInfo.isFixedSize, isTrue);
        expect(fieldDef.typeInfo.minimumSize, equals(16)); // 16 * 1 byte
      });

      test('creates definition for string types', () {
        final field =
            IdlField(name: 'test_string', type: IdlType(kind: 'string'));
        final fieldDef = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef.name, equals('test_string'));
        expect(fieldDef.typeInfo.typeName, equals('string'));
        expect(fieldDef.typeInfo.isFixedSize, isFalse);
        expect(fieldDef.typeInfo.minimumSize, equals(4)); // length prefix
      });

      test('creates definition for pubkey types', () {
        final field =
            IdlField(name: 'test_pubkey', type: IdlType(kind: 'pubkey'));
        final fieldDef = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef.name, equals('test_pubkey'));
        expect(fieldDef.typeInfo.typeName, equals('pubkey'));
        expect(fieldDef.typeInfo.isFixedSize, isTrue);
        expect(fieldDef.typeInfo.minimumSize, equals(32));
      });
    });

    group('equality', () {
      test('fields with same properties are equal', () {
        final field = IdlField(name: 'test', type: IdlType(kind: 'u64'));
        final fieldDef1 = FieldDefinition.fromIdlField(field, []);
        final fieldDef2 = FieldDefinition.fromIdlField(field, []);

        expect(fieldDef1, equals(fieldDef2));
        expect(fieldDef1.hashCode, equals(fieldDef2.hashCode));
      });

      test('fields with different properties are not equal', () {
        final field1 = IdlField(name: 'test1', type: IdlType(kind: 'u64'));
        final field2 = IdlField(name: 'test2', type: IdlType(kind: 'u32'));
        final fieldDef1 = FieldDefinition.fromIdlField(field1, []);
        final fieldDef2 = FieldDefinition.fromIdlField(field2, []);

        expect(fieldDef1, isNot(equals(fieldDef2)));
      });
    });
  });

  group('FieldTypeInfo', () {
    group('fromIdlType', () {
      test('handles all primitive types correctly', () {
        final primitiveTypes = {
          'bool': (1, 1),
          'u8': (1, 1),
          'i8': (1, 1),
          'u16': (2, 2),
          'i16': (2, 2),
          'u32': (4, 4),
          'i32': (4, 4),
          'u64': (8, 8),
          'i64': (8, 8),
          'pubkey': (32, 32),
        };

        for (final entry in primitiveTypes.entries) {
          final type = IdlType(kind: entry.key);
          final typeInfo = FieldTypeInfo.fromIdlType(type, []);

          expect(typeInfo.typeName, equals(entry.key),
              reason: 'Type name should match for ${entry.key}');
          expect(typeInfo.isFixedSize, isTrue,
              reason: 'Should be fixed size for ${entry.key}');
          expect(typeInfo.minimumSize, equals(entry.value.$1),
              reason: 'Min size should match for ${entry.key}');
          expect(typeInfo.maximumSize, equals(entry.value.$2),
              reason: 'Max size should match for ${entry.key}');
        }
      });

      test('handles variable-size types correctly', () {
        final stringType = IdlType(kind: 'string');
        final stringTypeInfo = FieldTypeInfo.fromIdlType(stringType, []);

        expect(stringTypeInfo.typeName, equals('string'));
        expect(stringTypeInfo.isFixedSize, isFalse);
        expect(stringTypeInfo.minimumSize, equals(4)); // length prefix
        expect(stringTypeInfo.maximumSize, isNull);
      });

      test('handles complex types correctly', () {
        final optionType = IdlType(kind: 'option', inner: IdlType(kind: 'u64'));
        final optionTypeInfo = FieldTypeInfo.fromIdlType(optionType, []);

        expect(optionTypeInfo.typeName, equals('option'));
        expect(optionTypeInfo.isFixedSize, isFalse);
        expect(optionTypeInfo.isOptional, isTrue);
        expect(optionTypeInfo.minimumSize, equals(1));
        expect(optionTypeInfo.innerType, isNotNull);
        expect(optionTypeInfo.innerType!.typeName, equals('u64'));
      });
    });

    group('calculateSize', () {
      test('calculates fixed-size types correctly', () {
        final u64Type = FieldTypeInfo.fromIdlType(IdlType(kind: 'u64'), []);
        expect(u64Type.calculateSize(123), equals(8));
      });

      test('calculates string size correctly', () {
        final stringType =
            FieldTypeInfo.fromIdlType(IdlType(kind: 'string'), []);
        expect(stringType.calculateSize('hello'), equals(9)); // 4 + 5
      });

      test('calculates vector size correctly', () {
        final vecType = FieldTypeInfo.fromIdlType(
          IdlType(kind: 'vec', inner: IdlType(kind: 'u16')),
          [],
        );
        expect(vecType.calculateSize([1, 2, 3]), equals(10)); // 4 + 3*2
      });

      test('calculates option size correctly', () {
        final optionType = FieldTypeInfo.fromIdlType(
          IdlType(kind: 'option', inner: IdlType(kind: 'u32')),
          [],
        );
        expect(optionType.calculateSize(null), equals(1)); // None discriminator
        expect(optionType.calculateSize(42),
            equals(5)); // Some discriminator + u32
      });
    });

    group('equality', () {
      test('type infos with same properties are equal', () {
        final type = IdlType(kind: 'u64');
        final typeInfo1 = FieldTypeInfo.fromIdlType(type, []);
        final typeInfo2 = FieldTypeInfo.fromIdlType(type, []);

        expect(typeInfo1, equals(typeInfo2));
        expect(typeInfo1.hashCode, equals(typeInfo2.hashCode));
      });

      test('type infos with different properties are not equal', () {
        final type1 = IdlType(kind: 'u64');
        final type2 = IdlType(kind: 'u32');
        final typeInfo1 = FieldTypeInfo.fromIdlType(type1, []);
        final typeInfo2 = FieldTypeInfo.fromIdlType(type2, []);

        expect(typeInfo1, isNot(equals(typeInfo2)));
      });
    });
  });

  group('IdlAccountParser', () {
    late Idl testIdl;

    setUp(() {
      final testTypeDef = IdlTypeDef(
        name: 'TestAccount',
        type: IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(name: 'value', type: IdlType(kind: 'u64')),
          ],
        ),
      );

      final testAccount = IdlAccount(
        name: 'TestAccount',
        type: testTypeDef.type,
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
      );

      testIdl = Idl(
        address: 'TestProgram1111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'test_program',
          version: '1.0.0',
          spec: '0.1.0',
        ),
        instructions: [],
        accounts: [testAccount],
        types: [testTypeDef],
      );
    });

    test('parseAccounts returns all account definitions', () {
      final accounts = IdlAccountParser.parseAccounts(testIdl);
      expect(accounts.length, equals(1));
      expect(accounts.first.name, equals('TestAccount'));
    });

    test('parseAccounts returns empty list for IDL without accounts', () {
      final emptyIdl = Idl(
        metadata: IdlMetadata(name: 'empty', version: '1.0.0', spec: '0.1.0'),
        instructions: [],
      );
      final accounts = IdlAccountParser.parseAccounts(emptyIdl);
      expect(accounts, isEmpty);
    });

    test('parseAccount returns specific account definition', () {
      final account = IdlAccountParser.parseAccount(testIdl, 'TestAccount');
      expect(account, isNotNull);
      expect(account!.name, equals('TestAccount'));
    });

    test('parseAccount returns null for non-existent account', () {
      final account = IdlAccountParser.parseAccount(testIdl, 'NonExistent');
      expect(account, isNull);
    });

    test('validateIdlAccounts returns no errors for valid IDL', () {
      final errors = IdlAccountParser.validateIdlAccounts(testIdl);
      expect(errors, isEmpty);
    });

    test('validateIdlAccounts detects missing type definitions', () {
      final invalidAccount = IdlAccount(
        name: 'MissingType',
        type: IdlTypeDefType(kind: 'struct'),
      );

      final invalidIdl = Idl(
        metadata: IdlMetadata(name: 'invalid', version: '1.0.0', spec: '0.1.0'),
        instructions: [],
        accounts: [invalidAccount],
        types: [], // No type definitions
      );

      final errors = IdlAccountParser.validateIdlAccounts(invalidIdl);
      expect(errors.length, equals(1));
      expect(errors.first.contains('Missing type definition'), isTrue);
    });
  });
}
