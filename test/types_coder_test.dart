import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('TypesCoder Tests', () {
    late Idl testIdl;
    late BorshTypesCoder<String> typesCoder;

    setUp(() {
      // Create a test IDL with type definitions
      testIdl = const Idl(
        address: 'TYPES123456789012345678901234567890ABCDEF',
        metadata: IdlMetadata(
          name: 'test_types',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [],
        types: [
          IdlTypeDef(
            name: 'person',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'name', type: IdlType(kind: 'string')),
                IdlField(name: 'age', type: IdlType(kind: 'u32')),
                IdlField(name: 'isActive', type: IdlType(kind: 'bool')),
              ],
            ),
          ),
          IdlTypeDef(
            name: 'status',
            type: IdlTypeDefType(
              kind: 'enum',
              variants: [
                IdlEnumVariant(
                  name: 'pending',
                  fields: [],
                ),
                IdlEnumVariant(
                  name: 'approved',
                  fields: [],
                ),
                IdlEnumVariant(
                  name: 'rejected',
                  fields: [
                    IdlField(name: 'reason', type: IdlType(kind: 'string')),
                  ],
                ),
              ],
            ),
          ),
          IdlTypeDef(
            name: 'complexType',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'numbers',
                  type: IdlType(kind: 'vec', inner: IdlType(kind: 'u64')),
                ),
                IdlField(
                  name: 'optionalData',
                  type: IdlType(kind: 'option', inner: IdlType(kind: 'string')),
                ),
                IdlField(
                  name: 'fixedArray',
                  type: IdlType(kind: 'array', inner: IdlType(kind: 'u8'), size: 4),
                ),
              ],
            ),
          ),
          IdlTypeDef(
            name: 'nestedType',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'person',
                  type: IdlType(kind: 'defined', defined: 'person'),
                ),
                IdlField(name: 'id', type: IdlType(kind: 'u32')),
              ],
            ),
          ),
        ],
      );

      typesCoder = BorshTypesCoder<String>(testIdl);
    });

    group('Struct Type Encoding/Decoding', () {
      test('should encode and decode simple struct correctly', () {
        final personData = {
          'name': 'John Doe',
          'age': 30,
          'isActive': true,
        };

        final encoded = typesCoder.encode('person', personData);
        final decoded =
            typesCoder.decode<Map<String, dynamic>>('person', encoded);

        expect(decoded['name'], equals('John Doe'));
        expect(decoded['age'], equals(30));
        expect(decoded['isActive'], equals(true));
      });

      test('should encode and decode complex struct with collections', () {
        final complexData = {
          'numbers': [100, 200, 300],
          'optionalData': 'some optional data',
          'fixedArray': [1, 2, 3, 4],
        };

        final encoded = typesCoder.encode('complexType', complexData);
        final decoded =
            typesCoder.decode<Map<String, dynamic>>('complexType', encoded);

        expect(decoded['numbers'], equals([100, 200, 300]));
        expect(decoded['optionalData'], equals('some optional data'));
        expect(decoded['fixedArray'], equals([1, 2, 3, 4]));
      });

      test('should handle null optional fields', () {
        final complexData = {
          'numbers': [42],
          'optionalData': null,
          'fixedArray': [255, 128, 64, 32],
        };

        final encoded = typesCoder.encode('complexType', complexData);
        final decoded =
            typesCoder.decode<Map<String, dynamic>>('complexType', encoded);

        expect(decoded['numbers'], equals([42]));
        expect(decoded['optionalData'], isNull);
        expect(decoded['fixedArray'], equals([255, 128, 64, 32]));
      });

      test('should encode and decode nested types', () {
        final nestedData = {
          'person': {
            'name': 'Alice',
            'age': 25,
            'isActive': false,
          },
          'id': 12345,
        };

        final encoded = typesCoder.encode('nestedType', nestedData);
        final decoded =
            typesCoder.decode<Map<String, dynamic>>('nestedType', encoded);

        expect(decoded['person']['name'], equals('Alice'));
        expect(decoded['person']['age'], equals(25));
        expect(decoded['person']['isActive'], equals(false));
        expect(decoded['id'], equals(12345));
      });
    });

    group('Enum Type Encoding/Decoding', () {
      test('should encode and decode simple enum variant', () {
        final pendingStatus = {'pending': null};

        final encoded = typesCoder.encode('status', pendingStatus);
        final decoded =
            typesCoder.decode<Map<String, dynamic>>('status', encoded);

        expect(decoded.keys.first, equals('pending'));
        expect(decoded['pending'], isNull);
      });

      test('should encode and decode enum variant with data', () {
        final rejectedStatus = {
          'rejected': {'reason': 'Invalid documentation'},
        };

        final encoded = typesCoder.encode('status', rejectedStatus);
        final decoded =
            typesCoder.decode<Map<String, dynamic>>('status', encoded);

        expect(decoded.keys.first, equals('rejected'));
        expect(decoded['rejected']['reason'], equals('Invalid documentation'));
      });

      test('should encode and decode all enum variants', () {
        final variants = [
          {'pending': null},
          {'approved': null},
          {
            'rejected': {'reason': 'Test reason'},
          },
        ];

        for (final variant in variants) {
          final encoded = typesCoder.encode('status', variant);
          final decoded =
              typesCoder.decode<Map<String, dynamic>>('status', encoded);

          expect(decoded.keys.first, equals(variant.keys.first));
        }
      });
    });

    group('Type Validation and Error Handling', () {
      test('should throw on unknown type name', () {
        final someData = {'field': 'value'};

        expect(
          () => typesCoder.encode('unknownType', someData),
          throwsA(isA<TypesCoderException>()),
        );

        final someBytes = Uint8List.fromList([1, 2, 3, 4]);
        expect(
          () => typesCoder.decode('unknownType', someBytes),
          throwsA(isA<TypesCoderException>()),
        );
      });

      test('should throw on missing required struct field', () {
        final incompleteData = {
          'name': 'John',
          // Missing 'age' and 'isActive'
        };

        expect(
          () => typesCoder.encode('person', incompleteData),
          throwsA(isA<TypesCoderException>()),
        );
      });

      test('should throw on invalid array size', () {
        final invalidArrayData = {
          'numbers': [1, 2, 3],
          'optionalData': null,
          'fixedArray': [1, 2, 3], // Should be size 4
        };

        expect(
          () => typesCoder.encode('complexType', invalidArrayData),
          throwsA(isA<TypesCoderException>()),
        );
      });

      test('should throw on invalid enum variant', () {
        final invalidEnum = {'invalidVariant': null};

        expect(
          () => typesCoder.encode('status', invalidEnum),
          throwsA(isA<TypesCoderException>()),
        );
      });

      test('should throw on wrong data type for struct', () {
        final wrongTypeData = 'this should be a map';

        expect(
          () => typesCoder.encode('person', wrongTypeData),
          throwsA(isA<TypesCoderException>()),
        );
      });

      test('should throw on wrong data type for enum', () {
        final wrongTypeData = 'this should be a map';

        expect(
          () => typesCoder.encode('status', wrongTypeData),
          throwsA(isA<TypesCoderException>()),
        );
      });
    });

    group('Round Trip Tests', () {
      test('should maintain data integrity through encode/decode cycles', () {
        final testCases = [
          {
            'type': 'person',
            'data': {
              'name': 'Test Person',
              'age': 42,
              'isActive': true,
            },
          },
          {
            'type': 'complexType',
            'data': {
              'numbers': [1, 2, 3, 4, 5],
              'optionalData': 'test data',
              'fixedArray': [10, 20, 30, 40],
            },
          },
          {
            'type': 'status',
            'data': {
              'rejected': {'reason': 'Test rejection'},
            },
          },
        ];

        for (final testCase in testCases) {
          final typeName = testCase['type'] as String;
          final originalData = testCase['data'] as Map<String, dynamic>;

          final encoded = typesCoder.encode(typeName, originalData);
          final decoded =
              typesCoder.decode<Map<String, dynamic>>(typeName, encoded);

          expect(decoded, equals(originalData));
        }
      });

      test('should handle edge cases correctly', () {
        final edgeCases = [
          {
            'name': '',
            'age': 0,
            'isActive': false,
          },
          {
            'name': 'Very long name that tests string handling',
            'age': 4294967295, // Max u32
            'isActive': true,
          },
        ];

        for (final edgeCase in edgeCases) {
          final encoded = typesCoder.encode('person', edgeCase);
          final decoded =
              typesCoder.decode<Map<String, dynamic>>('person', encoded);

          expect(decoded, equals(edgeCase));
        }
      });
    });

    group('Type Layout Building', () {
      test('should handle IDL with no types', () {
        final emptyTypesIdl = const Idl(
          address: 'EMPTY123456789012345678901234567890ABCDEF',
          metadata: IdlMetadata(
            name: 'empty_types',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [],
          types: null,
        );

        final emptyCoder = BorshTypesCoder<String>(emptyTypesIdl);

        expect(
          () => emptyCoder.encode('anyType', {}),
          throwsA(isA<TypesCoderException>()),
        );
      });

      test('should handle all defined types', () {
        final genericTypesIdl = const Idl(
          address: 'GENERIC123456789012345678901234567890ABCDEF',
          metadata: IdlMetadata(
            name: 'generic_types',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [],
          types: [
            IdlTypeDef(
              name: 'regularType',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'data', type: IdlType(kind: 'u32')),
                ],
              ),
            ),
            IdlTypeDef(
              name: 'anotherType',
              type: IdlTypeDefType(
                // Changed
                kind: 'struct',
                fields: [
                  IdlField(name: 'data', type: IdlType(kind: 'u32')),
                ],
              ),
            ),
          ],
        );

        final genericCoder = BorshTypesCoder<String>(genericTypesIdl);

        // Should work for both types
        final regularData = {'data': 42};
        final encoded1 = genericCoder.encode('regularType', regularData);
        final decoded1 =
            genericCoder.decode<Map<String, dynamic>>('regularType', encoded1);
        expect(decoded1, equals(regularData));

        final encoded2 = genericCoder.encode('anotherType', regularData);
        final decoded2 =
            genericCoder.decode<Map<String, dynamic>>('anotherType', encoded2);
        expect(decoded2, equals(regularData));

        // Should fail for undefined type
        expect(
          () => genericCoder.encode('undefinedType', regularData),
          throwsA(isA<TypesCoderException>()),
        );
      });
    });

    group('Data Type Support', () {
      test('should handle all primitive types correctly', () {
        final primitiveTypesIdl = const Idl(
          address: 'PRIMITIVE123456789012345678901234567890ABCDEF',
          metadata: IdlMetadata(
            name: 'primitive_types',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [],
          types: [
            IdlTypeDef(
              name: 'primitives',
              type: IdlTypeDefType(
                // Changed
                kind: 'struct',
                fields: [
                  IdlField(name: 'boolVal', type: IdlType(kind: 'bool')),
                  IdlField(name: 'u8Val', type: IdlType(kind: 'u8')),
                  IdlField(name: 'i8Val', type: IdlType(kind: 'i8')),
                  IdlField(name: 'u16Val', type: IdlType(kind: 'u16')),
                  IdlField(name: 'i16Val', type: IdlType(kind: 'i16')),
                  IdlField(name: 'u32Val', type: IdlType(kind: 'u32')),
                  IdlField(name: 'i32Val', type: IdlType(kind: 'i32')),
                  IdlField(name: 'u64Val', type: IdlType(kind: 'u64')),
                  IdlField(name: 'i64Val', type: IdlType(kind: 'i64')),
                  IdlField(name: 'stringVal', type: IdlType(kind: 'string')),
                  IdlField(name: 'pubkeyVal', type: IdlType(kind: 'pubkey')),
                ],
              ),
            ),
          ],
        );

        final primitiveCoder = BorshTypesCoder<String>(primitiveTypesIdl);

        final primitiveData = {
          'boolVal': true,
          'u8Val': 255,
          'i8Val': -128,
          'u16Val': 65535,
          'i16Val': -32768,
          'u32Val': 4294967295,
          'i32Val': -2147483648,
          'u64Val': 9223372036854775807,
          'i64Val': -9223372036854775808,
          'stringVal': 'hello world',
          'pubkeyVal': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        };

        final encoded = primitiveCoder.encode('primitives', primitiveData);
        final decoded =
            primitiveCoder.decode<Map<String, dynamic>>('primitives', encoded);

        expect(decoded, equals(primitiveData));
      });
    });

    group('Error Message Quality', () {
      test('should provide helpful error messages', () {
        try {
          typesCoder.encode('unknownType', {});
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<TypesCoderException>());
          expect(e.toString(), contains('Unknown type'));
          expect(e.toString(), contains('unknownType'));
        }

        try {
          final badData = {'name': 'John'}; // Missing required fields
          typesCoder.encode('person', badData);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<TypesCoderException>());
          expect(e.toString(), contains('Missing required field'));
        }
      });
    });
  });
}
