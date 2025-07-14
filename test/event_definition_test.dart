import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:test/test.dart';


void main() {
  group('EventDefinition Tests', () {
    late Map<String, IdlTypeDef> customTypes;

    setUp(() {
      // Setup custom types for testing
      customTypes = {
        'UserData': IdlTypeDef(
          name: 'UserData',
          docs: ['User data structure'],
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [
              IdlField(name: 'id', type: idlTypeU64()),
              IdlField(name: 'name', type: idlTypeString()),
              IdlField(name: 'balance', type: idlTypeU64()),
            ],
          ),
        ),
        'TokenInfo': IdlTypeDef(
          name: 'TokenInfo',
          docs: ['Token information'],
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [
              IdlField(name: 'mint', type: idlTypePubkey()),
              IdlField(name: 'amount', type: idlTypeU64()),
            ],
          ),
        ),
      };
    });

    group('Basic Event Definition Creation', () {
      test('should create EventDefinition from simple IDL event', () {
        final idlEvent = IdlEvent(
          name: 'UserCreated',
          docs: ['Event emitted when a new user is created'],
          fields: [
            IdlField(name: 'userId', type: idlTypeU64()),
            IdlField(name: 'username', type: idlTypeString()),
            IdlField(name: 'isActive', type: idlTypeBool()),
          ],
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);

        expect(eventDef.name, equals('UserCreated'));
        expect(eventDef.docs, equals(['Event emitted when a new user is created']));
        expect(eventDef.fields.length, equals(3));
        expect(eventDef.discriminator, equals([1, 2, 3, 4, 5, 6, 7, 8]));
        expect(eventDef.metadata.totalFields, equals(3));
        expect(eventDef.metadata.hasOptionalFields, isFalse);
        expect(eventDef.metadata.complexity, equals(EventComplexity.low));
      });

      test('should auto-generate discriminator when not provided', () {
        final idlEvent = IdlEvent(
          name: 'TestEvent',
          fields: [
            IdlField(name: 'value', type: idlTypeU32()),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);
        final expectedDiscriminator = DiscriminatorComputer.computeEventDiscriminator('TestEvent');

        expect(eventDef.discriminator, equals(expectedDiscriminator));
      });

      test('should handle complex field types', () {
        final idlEvent = IdlEvent(
          name: 'ComplexEvent',
          fields: [
            IdlField(name: 'optionalValue', type: idlTypeOption(idlTypeU64())),
            IdlField(name: 'vectorData', type: idlTypeVec(idlTypeString())),
            IdlField(name: 'arrayData', type: idlTypeArray(idlTypeU8(), 32)),
            IdlField(name: 'customData', type: idlTypeDefined('UserData')),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent, customTypes: customTypes);

        expect(eventDef.fields.length, equals(4));
        expect(eventDef.fields[0].typeInfo.isOptional, isTrue);
        expect(eventDef.fields[1].typeInfo.typeName, equals('Vec<string>'));
        expect(eventDef.fields[2].typeInfo.typeName, equals('[u8; 32]'));
        expect(eventDef.fields[3].typeInfo.typeName, equals('UserData'));
        expect(eventDef.metadata.hasNestedStructures, isTrue);
        expect(eventDef.metadata.complexity, equals(EventComplexity.medium));
      });
    });

    group('Event Field Validation', () {
      test('should validate primitive field types correctly', () {
        final fieldDef = EventFieldDefinition(
          name: 'testNumber',
          typeInfo: EventFieldTypeInfo.fromIdlType(idlTypeU64()),
        );

        final validResult = fieldDef.validateValue(12345);
        expect(validResult.isValid, isTrue);
        expect(validResult.errors, isEmpty);

        final invalidResult = fieldDef.validateValue('not a number');
        expect(invalidResult.isValid, isFalse);
        expect(invalidResult.errors, isNotEmpty);
      });

      test('should validate optional field types correctly', () {
        final fieldDef = EventFieldDefinition(
          name: 'optionalField',
          typeInfo: EventFieldTypeInfo.fromIdlType(idlTypeOption(idlTypeString())),
        );

        final nullResult = fieldDef.validateValue(null);
        expect(nullResult.isValid, isTrue);

        final validResult = fieldDef.validateValue('test string');
        expect(validResult.isValid, isTrue);
      });

      test('should enforce field constraints', () {
        final fieldDef = EventFieldDefinition(
          name: 'constrainedField',
          typeInfo: EventFieldTypeInfo.fromIdlType(idlTypeU32()),
          constraints: [
            EventFieldConstraint.min(10),
            EventFieldConstraint.max(100),
          ],
        );

        final validResult = fieldDef.validateValue(50);
        expect(validResult.isValid, isTrue);

        final tooSmallResult = fieldDef.validateValue(5);
        expect(tooSmallResult.isValid, isFalse);
        expect(tooSmallResult.errors.first, contains('less than minimum'));

        final tooLargeResult = fieldDef.validateValue(150);
        expect(tooLargeResult.isValid, isFalse);
        expect(tooLargeResult.errors.first, contains('greater than maximum'));
      });
    });

    group('Event Data Validation', () {
      late EventDefinition eventDef;

      setUp(() {
        final idlEvent = IdlEvent(
          name: 'UserEvent',
          fields: [
            IdlField(name: 'userId', type: idlTypeU64()),
            IdlField(name: 'username', type: idlTypeString()),
            IdlField(name: 'balance', type: idlTypeU64()),
            IdlField(name: 'isActive', type: idlTypeBool()),
          ],
        );
        eventDef = EventDefinition.fromIdl(idlEvent);
      });

      test('should validate complete event data', () {
        final eventData = {
          'userId': 12345,
          'username': 'testuser',
          'balance': 1000000,
          'isActive': true,
        };

        final result = eventDef.validateEventData(eventData);
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should detect missing required fields', () {
        final eventData = {
          'userId': 12345,
          'username': 'testuser',
          // Missing balance and isActive
        };

        final result = eventDef.validateEventData(eventData);
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2));
        expect(result.errors.any((e) => e.contains('balance')), isTrue);
        expect(result.errors.any((e) => e.contains('isActive')), isTrue);
      });

      test('should warn about unknown fields', () {
        final eventData = {
          'userId': 12345,
          'username': 'testuser',
          'balance': 1000000,
          'isActive': true,
          'unknownField': 'extra data',
        };

        final result = eventDef.validateEventData(eventData);
        expect(result.isValid, isTrue);
        expect(result.warnings.length, equals(1));
        expect(result.warnings.first, contains('Unknown field: unknownField'));
      });

      test('should validate field type mismatches', () {
        final eventData = {
          'userId': 'not a number', // Wrong type
          'username': 123, // Wrong type
          'balance': 1000000,
          'isActive': true,
        };

        final result = eventDef.validateEventData(eventData);
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2));
        expect(result.errors.any((e) => e.contains('userId')), isTrue);
        expect(result.errors.any((e) => e.contains('username')), isTrue);
      });
    });

    group('Event Size Calculation', () {
      test('should calculate event size correctly', () {
        final idlEvent = IdlEvent(
          name: 'SizeTestEvent',
          fields: [
            IdlField(name: 'id', type: idlTypeU64()), // 8 bytes
            IdlField(name: 'flag', type: idlTypeBool()), // 1 byte
            IdlField(name: 'data', type: idlTypeArray(idlTypeU8(), 32)), // 32 bytes
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);
        final eventData = {
          'id': 12345,
          'flag': true,
          'data': List.filled(32, 0),
        };

        final size = eventDef.calculateEventSize(eventData);
        // 8 (discriminator) + 8 (u64) + 1 (bool) + 32 (array) = 49 bytes
        expect(size, equals(49));
      });

      test('should calculate variable string size correctly', () {
        final idlEvent = IdlEvent(
          name: 'StringEvent',
          fields: [
            IdlField(name: 'message', type: idlTypeString()),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);

        final shortEventData = {'message': 'Hi'};
        final shortSize = eventDef.calculateEventSize(shortEventData);
        // 8 (discriminator) + 4 (string length) + 2 (string content) = 14 bytes
        expect(shortSize, equals(14));

        final longEventData = {'message': 'This is a longer message'};
        final longSize = eventDef.calculateEventSize(longEventData);
        // 8 (discriminator) + 4 (string length) + 24 (string content) = 36 bytes
        expect(longSize, equals(36));
      });
    });

    group('Event Inheritance and Versioning', () {
      test('should parse inheritance information from docs', () {
        final idlEvent = IdlEvent(
          name: 'DerivedEvent',
          docs: ['@inherits BaseEvent', 'A derived event'],
          fields: [
            IdlField(name: 'extraField', type: idlTypeU32()),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);

        expect(eventDef.inheritanceInfo, isNotNull);
        expect(eventDef.inheritanceInfo!.parentEvent, equals('BaseEvent'));
        expect(eventDef.inheritanceInfo!.inheritanceType, equals(EventInheritanceType.extendsType));
      });

      test('should parse version information from docs', () {
        final idlEvent = IdlEvent(
          name: 'VersionedEvent',
          docs: ['@version 2.1.3', 'A versioned event'],
          fields: [
            IdlField(name: 'field', type: idlTypeU32()),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);

        expect(eventDef.versionInfo, isNotNull);
        expect(eventDef.versionInfo!.major, equals(2));
        expect(eventDef.versionInfo!.minor, equals(1));
        expect(eventDef.versionInfo!.patch, equals(3));
        expect(eventDef.versionInfo!.versionString, equals('2.1.3'));
      });

      test('should check event compatibility', () {
        final baseEvent = IdlEvent(
          name: 'BaseEvent',
          fields: [
            IdlField(name: 'id', type: idlTypeU64()),
            IdlField(name: 'name', type: idlTypeString()),
          ],
        );

        final compatibleEvent = IdlEvent(
          name: 'BaseEvent',
          fields: [
            IdlField(name: 'id', type: idlTypeU64()),
            IdlField(name: 'name', type: idlTypeString()),
            IdlField(name: 'extra', type: idlTypeU32()), // Additional optional field
          ],
        );

        final incompatibleEvent = IdlEvent(
          name: 'BaseEvent',
          fields: [
            IdlField(name: 'id', type: idlTypeString()), // Changed type from u64 to string
            IdlField(name: 'name', type: idlTypeString()),
          ],
        );

        final baseDef = EventDefinition.fromIdl(baseEvent);
        final compatibleDef = EventDefinition.fromIdl(compatibleEvent);
        final incompatibleDef = EventDefinition.fromIdl(incompatibleEvent);

        expect(baseDef.isCompatibleWith(compatibleDef), isTrue);
        expect(baseDef.isCompatibleWith(incompatibleDef), isFalse);
      });
    });

    group('Configuration and Error Handling', () {
      test('should respect configuration settings', () {
        final config = EventDefinitionConfig.strict();
        
        final idlEvent = IdlEvent(
          name: 'ConfigTestEvent',
          fields: [
            IdlField(name: 'field', type: idlTypeString()),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent, config: config);

        expect(eventDef.validationRules.enforceRequiredFields, isTrue);
        expect(eventDef.validationRules.typeStrictness, equals(TypeValidationStrictness.strict));
        expect(eventDef.validationRules.maxEventSize, isNotNull);
      });

      test('should handle parsing errors gracefully', () {
        final invalidIdlEvents = [
          IdlEvent(
            name: 'InvalidEvent',
            fields: [
              IdlField(name: 'field', type: idlTypeDefined('NonExistentType')),
            ],
          ),
        ];

        // This should complete normally since we don't currently validate custom types strictly
        final events = IdlEventParser.parseEvents(invalidIdlEvents);
        expect(events.length, equals(1));
        expect(events[0].name, equals('InvalidEvent'));
      });
    });

    group('Schema Generation', () {
      test('should generate comprehensive schema', () {
        final idlEvent = IdlEvent(
          name: 'SchemaEvent',
          docs: ['@version 1.0.0', 'Test event for schema generation'],
          fields: [
            IdlField(name: 'id', type: idlTypeU64()),
            IdlField(name: 'data', type: idlTypeOption(idlTypeString())),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);
        final schema = eventDef.generateSchema();

        expect(schema['name'], equals('SchemaEvent'));
        expect(schema['docs'], isNotNull);
        expect(schema['fields'], isList);
        expect(schema['metadata'], isMap);
        expect(schema['validationRules'], isMap);
        expect(schema['version'], isNotNull);
        expect((schema['fields'] as List).length, equals(2));
      });
    });

    group('Field Constraints and Default Values', () {
      test('should parse field constraints from documentation', () {
        final idlEvent = IdlEvent(
          name: 'ConstraintEvent',
          fields: [
            IdlField(
              name: 'constrainedField',
              type: idlTypeU32(),
              docs: ['@min 10', '@max 100', 'A field with constraints'],
            ),
            IdlField(
              name: 'lengthField',
              type: idlTypeString(),
              docs: ['@length 50', 'A string with fixed length'],
            ),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);

        expect(eventDef.fields[0].constraints.length, equals(2));
        expect(eventDef.fields[0].constraints[0].type, equals(EventConstraintType.min));
        expect(eventDef.fields[0].constraints[0].value, equals(10));
        expect(eventDef.fields[0].constraints[1].type, equals(EventConstraintType.max));
        expect(eventDef.fields[0].constraints[1].value, equals(100));

        expect(eventDef.fields[1].constraints.length, equals(1));
        expect(eventDef.fields[1].constraints[0].type, equals(EventConstraintType.length));
        expect(eventDef.fields[1].constraints[0].value, equals(50));
      });

      test('should parse default values from documentation', () {
        final idlEvent = IdlEvent(
          name: 'DefaultValueEvent',
          fields: [
            IdlField(
              name: 'numberField',
              type: idlTypeU32(),
              docs: ['@default 42', 'A number with default value'],
            ),
            IdlField(
              name: 'stringField',
              type: idlTypeString(),
              docs: ['@default "hello"', 'A string with default value'],
            ),
            IdlField(
              name: 'boolField',
              type: idlTypeBool(),
              docs: ['@default true', 'A boolean with default value'],
            ),
          ],
        );

        final eventDef = EventDefinition.fromIdl(idlEvent);

        expect(eventDef.fields[0].hasDefaultValue, isTrue);
        expect(eventDef.fields[0].defaultValue, equals(42));
        expect(eventDef.fields[1].hasDefaultValue, isTrue);
        expect(eventDef.fields[1].defaultValue, equals('hello'));
        expect(eventDef.fields[2].hasDefaultValue, isTrue);
        expect(eventDef.fields[2].defaultValue, equals(true));
      });
    });
  });
}
