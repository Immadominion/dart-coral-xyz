/// Tests for the unified type conversion system
///
/// This test suite validates the type conversion utilities between
/// IDL types and Dart native types, ensuring consistent handling
/// across all serialization paths.
library;

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('TypeConverter', () {
    group('IDL Type Compatibility', () {
      test('IdlType static factory methods work correctly', () {
        expect(IdlType.bool().kind, equals('bool'));
        expect(IdlType.u8().kind, equals('u8'));
        expect(IdlType.u16().kind, equals('u16'));
        expect(IdlType.u32().kind, equals('u32'));
        expect(IdlType.u64().kind, equals('u64'));
        expect(IdlType.i8().kind, equals('i8'));
        expect(IdlType.i16().kind, equals('i16'));
        expect(IdlType.i32().kind, equals('i32'));
        expect(IdlType.i64().kind, equals('i64'));
        expect(IdlType.string().kind, equals('string'));
        expect(IdlType.publicKey().kind, equals('pubkey'));
      });

      test('IdlType complex types work correctly', () {
        final vecType = IdlType.vec(IdlType.u32());
        expect(vecType.kind, equals('vec'));
        expect(vecType.inner?.kind, equals('u32'));

        final optionType = IdlType.option(IdlType.string());
        expect(optionType.kind, equals('option'));
        expect(optionType.inner?.kind, equals('string'));

        final arrayType = IdlType.array(IdlType.bool(), 10);
        expect(arrayType.kind, equals('array'));
        expect(arrayType.inner?.kind, equals('bool'));
        expect(arrayType.size, equals(10));

        final definedType = IdlType.definedType('MyStruct');
        expect(definedType.kind, equals('defined'));
        expect(definedType.defined, equals('MyStruct'));
      });
    });

    group('Value Conversion', () {
      test('converts primitive types correctly', () {
        expect(TypeConverter.convertValueForIdlType(IdlType.bool(), true),
            equals(true),);
        expect(TypeConverter.convertValueForIdlType(IdlType.bool(), 1),
            equals(true),);
        expect(TypeConverter.convertValueForIdlType(IdlType.bool(), 0),
            equals(false),);

        expect(TypeConverter.convertValueForIdlType(IdlType.u32(), 42),
            equals(42),);
        expect(TypeConverter.convertValueForIdlType(IdlType.u32(), '42'),
            equals(42),);

        expect(TypeConverter.convertValueForIdlType(IdlType.string(), 'hello'),
            equals('hello'),);
        expect(TypeConverter.convertValueForIdlType(IdlType.string(), 123),
            equals('123'),);
      });

      test('converts PublicKey types correctly', () {
        final keyBytes = List.generate(32, (i) => i);
        final publicKey = PublicKey.fromBytes(keyBytes);

        expect(
            TypeConverter.convertValueForIdlType(
                IdlType.publicKey(), publicKey,),
            equals(publicKey),);
        expect(
            TypeConverter.convertValueForIdlType(IdlType.publicKey(), keyBytes),
            isA<PublicKey>(),);

        final base58Key = publicKey.toBase58();
        final convertedKey =
            TypeConverter.convertValueForIdlType(IdlType.publicKey(), base58Key)
                as PublicKey;
        expect(convertedKey.toBase58(), equals(base58Key));
      });

      test('converts complex types correctly', () {
        final vecType = IdlType.vec(IdlType.u32());
        final values = [1, 2, 3, 4];
        final converted = TypeConverter.convertValueForIdlType(vecType, values);
        expect(converted, equals([1, 2, 3, 4]));

        final optionType = IdlType.option(IdlType.string());
        expect(TypeConverter.convertValueForIdlType(optionType, null), isNull);
        expect(TypeConverter.convertValueForIdlType(optionType, 'test'),
            equals('test'),);

        final arrayType = IdlType.array(IdlType.bool(), 3);
        final boolArray = [true, false, true];
        final convertedArray =
            TypeConverter.convertValueForIdlType(arrayType, boolArray);
        expect(convertedArray, equals([true, false, true]));
      });

      test('validates type compatibility', () {
        expect(TypeConverter.isValueCompatibleWithIdlType(IdlType.bool(), true),
            isTrue,);
        expect(TypeConverter.isValueCompatibleWithIdlType(IdlType.bool(), 1),
            isTrue,);
        expect(
            TypeConverter.isValueCompatibleWithIdlType(
                IdlType.bool(), 'invalid',),
            isFalse,);

        expect(TypeConverter.isValueCompatibleWithIdlType(IdlType.u32(), 42),
            isTrue,);
        expect(TypeConverter.isValueCompatibleWithIdlType(IdlType.u32(), '42'),
            isTrue,);
        expect(
            TypeConverter.isValueCompatibleWithIdlType(
                IdlType.u32(), 'invalid',),
            isFalse,);

        final vecType = IdlType.vec(IdlType.u32());
        expect(TypeConverter.isValueCompatibleWithIdlType(vecType, [1, 2, 3]),
            isTrue,);
        expect(
            TypeConverter.isValueCompatibleWithIdlType(vecType, 'not a list'),
            isFalse,);
      });
    });

    group('Serialization', () {
      test('serializes and deserializes primitive types', () {
        final boolData =
            TypeConverter.serializeWithIdlType(IdlType.bool(), true);
        expect(TypeConverter.deserializeWithIdlType(IdlType.bool(), boolData),
            equals(true),);

        final u32Data = TypeConverter.serializeWithIdlType(IdlType.u32(), 42);
        expect(TypeConverter.deserializeWithIdlType(IdlType.u32(), u32Data),
            equals(42),);

        final stringData =
            TypeConverter.serializeWithIdlType(IdlType.string(), 'hello');
        expect(
            TypeConverter.deserializeWithIdlType(IdlType.string(), stringData),
            equals('hello'),);
      });

      test('serializes and deserializes PublicKey', () {
        final keyBytes = List.generate(32, (i) => i);
        final publicKey = PublicKey.fromBytes(keyBytes);

        final serialized =
            TypeConverter.serializeWithIdlType(IdlType.publicKey(), publicKey);
        final deserialized = TypeConverter.deserializeWithIdlType(
            IdlType.publicKey(), serialized,) as PublicKey;

        expect(deserialized.bytes, equals(publicKey.bytes));
        expect(deserialized.toBase58(), equals(publicKey.toBase58()));
      });

      test('serializes and deserializes complex types', () {
        final vecType = IdlType.vec(IdlType.u32());
        final values = [1, 2, 3, 4];

        final serialized = TypeConverter.serializeWithIdlType(vecType, values);
        final deserialized =
            TypeConverter.deserializeWithIdlType(vecType, serialized)
                as List<dynamic>;

        expect(deserialized, equals([1, 2, 3, 4]));

        final optionType = IdlType.option(IdlType.string());

        final nullSerialized =
            TypeConverter.serializeWithIdlType(optionType, null);
        final nullDeserialized =
            TypeConverter.deserializeWithIdlType(optionType, nullSerialized);
        expect(nullDeserialized, isNull);

        final valueSerialized =
            TypeConverter.serializeWithIdlType(optionType, 'test');
        final valueDeserialized =
            TypeConverter.deserializeWithIdlType(optionType, valueSerialized);
        expect(valueDeserialized, equals('test'));
      });
    });

    group('Extension Methods', () {
      test('IdlType extension methods work correctly', () {
        final idlType = IdlType.u32();

        expect(idlType.isCompatibleWith(42), isTrue);
        expect(idlType.isCompatibleWith('invalid'), isFalse);

        expect(idlType.convertValue(42), equals(42));
        expect(idlType.convertValue('42'), equals(42));

        final serialized = idlType.serialize(42);
        expect(idlType.deserialize(serialized), equals(42));
      });
    });

    group('Error Handling', () {
      test('throws appropriate errors for invalid types', () {
        expect(
          () => TypeConverter.convertValueForIdlType(IdlType.bool(), 'invalid'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => TypeConverter.convertValueForIdlType(IdlType.u32(), 'invalid'),
          throwsA(isA<ArgumentError>()),
        );

        final vecType = IdlType.vec(IdlType.u32());
        expect(
          () => TypeConverter.convertValueForIdlType(vecType, 'not a list'),
          throwsA(isA<ArgumentError>()),
        );

        final arrayType = IdlType.array(IdlType.bool(), 3);
        expect(
          () => TypeConverter.convertValueForIdlType(
              arrayType, [true, false],), // Wrong length
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws errors for incomplete type definitions', () {
        final incompleteVec = const IdlType(kind: 'vec'); // Missing inner type
        expect(
          () => TypeConverter.convertValueForIdlType(incompleteVec, [1, 2, 3]),
          throwsA(isA<ArgumentError>()),
        );

        final incompleteArray =
            IdlType(kind: 'array', inner: IdlType.u32()); // Missing size
        expect(
          () =>
              TypeConverter.convertValueForIdlType(incompleteArray, [1, 2, 3]),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
