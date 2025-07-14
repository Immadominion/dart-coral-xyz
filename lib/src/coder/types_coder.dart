/// Enhanced Types coder implementation for Anchor programs with generics support
///
/// This module provides the TypesCoder interface and implementations
/// for encoding and decoding user-defined types with enhanced IDL support,
/// including generics, advanced arrays, and sophisticated type definitions.

library;

import 'dart:math' as math;
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/idl/enhanced_types.dart' as enhanced;
import 'package:coral_xyz_anchor/src/coder/borsh_types.dart';
import 'package:coral_xyz_anchor/src/types/common.dart';
import 'dart:typed_data';

/// Interface for encoding and decoding user-defined types
abstract class TypesCoder<N extends String> {
  /// Encode a user-defined type
  ///
  /// [typeName] - The name of the type to encode
  /// [data] - The data to encode
  /// Returns the encoded data as a byte buffer
  Uint8List encode<T>(N typeName, T data);

  /// Decode a user-defined type
  ///
  /// [typeName] - The name of the type to decode
  /// [data] - The data to decode
  /// Returns the decoded data
  T decode<T>(N typeName, Uint8List data);

  /// Get the serialized size of a type in bytes
  ///
  /// [typeName] - The name of the type
  /// Returns the size in bytes, or null for variable-length types
  int? getTypeSize(N typeName);
}

/// Enhanced Borsh-based implementation of TypesCoder with generics support
class BorshTypesCoder<N extends String> implements TypesCoder<N> {

  /// Create a new BorshTypesCoder
  BorshTypesCoder(this.idl) {
    _typeLayouts = _buildTypeLayouts();
    _enhancedTypeLayouts = _buildEnhancedTypeLayouts();
  }
  /// The IDL containing type definitions
  final Idl idl;

  /// Cached type layouts
  late final Map<N, IdlTypeDef> _typeLayouts;

  /// Cached enhanced type definitions for generics support
  late final Map<N, enhanced.IdlTypeDefEnhanced> _enhancedTypeLayouts;

  /// Cached type sizes for performance
  final Map<String, int?> _typeSizeCache = {};

  @override
  Uint8List encode<T>(N typeName, T data) {
    // Try enhanced types first for generics support
    final enhancedTypeDef = _enhancedTypeLayouts[typeName];
    if (enhancedTypeDef != null) {
      return _encodeEnhancedType(data, enhancedTypeDef);
    }

    // Fallback to basic types
    final typeDef = _typeLayouts[typeName];
    if (typeDef == null) {
      throw TypesCoderException('Unknown type: $typeName');
    }

    try {
      // Encode using Borsh serializer with enhanced type support
      final serializer = BorshSerializer();
      _encodeTypeData(data, typeDef, serializer);
      return serializer.toBytes();
    } catch (e) {
      throw TypesCoderException('Failed to encode type $typeName: $e');
    }
  }

  @override
  T decode<T>(N typeName, Uint8List data) {
    // Try enhanced types first for generics support
    final enhancedTypeDef = _enhancedTypeLayouts[typeName];
    if (enhancedTypeDef != null) {
      return _decodeEnhancedType<T>(enhancedTypeDef, data);
    }

    // Fallback to basic types
    final typeDef = _typeLayouts[typeName];
    if (typeDef == null) {
      throw TypesCoderException('Unknown type: $typeName');
    }

    try {
      // Decode using Borsh deserializer with enhanced type support
      final deserializer = BorshDeserializer(data);
      return _decodeTypeData<T>(typeDef, deserializer);
    } catch (e) {
      throw TypesCoderException('Failed to decode type $typeName: $e');
    }
  }

  @override
  int? getTypeSize(N typeName) {
    final cacheKey = typeName.toString();
    if (_typeSizeCache.containsKey(cacheKey)) {
      return _typeSizeCache[cacheKey];
    }

    // Try enhanced types first
    final enhancedTypeDef = _enhancedTypeLayouts[typeName];
    if (enhancedTypeDef != null) {
      final size = _calculateEnhancedTypeSize(enhancedTypeDef);
      _typeSizeCache[cacheKey] = size;
      return size;
    }

    // Fallback to basic types
    final typeDef = _typeLayouts[typeName];
    if (typeDef == null) {
      throw TypesCoderException('Unknown type: $typeName');
    }

    final size = _calculateTypeSize(typeDef);
    _typeSizeCache[cacheKey] = size;
    return size;
  }

  /// Build type layouts from IDL with enhanced support
  Map<N, IdlTypeDef> _buildTypeLayouts() {
    final layouts = <N, IdlTypeDef>{};

    if (idl.types == null) {
      return layouts;
    }

    // Add all types
    for (final typeDef in idl.types!) {
      layouts[typeDef.name as N] = typeDef;
    }

    return layouts;
  }

  /// Calculate type size with enhanced support
  int? _calculateTypeSize(IdlTypeDef typeDef) {
    final typeSpec = typeDef.type;

    switch (typeSpec.kind) {
      case 'struct':
        final fields = typeSpec.fields;
        if (fields == null) return null;

        int totalSize = 0;
        for (final field in fields) {
          final fieldSize = _calculateFieldSize(field.type);
          if (fieldSize == null) return null; // Variable length
          totalSize += fieldSize;
        }
        return totalSize;

      case 'enum':
        final variants = typeSpec.variants;
        if (variants == null) return null;

        // Calculate max variant size + discriminator
        int maxVariantSize = 0;
        for (final variant in variants) {
          if (variant.fields != null && variant.fields!.isNotEmpty) {
            int variantSize = 0;
            for (final field in variant.fields!) {
              final fieldSize = _calculateFieldSize(field.type);
              if (fieldSize == null) return null; // Variable length
              variantSize += fieldSize;
            }
            maxVariantSize = math.max(maxVariantSize, variantSize);
          }
        }
        return 1 + maxVariantSize; // 1 byte discriminator + max variant size

      default:
        return null;
    }
  }

  /// Calculate field size with enhanced type support
  int? _calculateFieldSize(IdlType type) {
    switch (type.kind) {
      case 'bool':
        return 1;
      case 'u8':
      case 'i8':
        return 1;
      case 'u16':
      case 'i16':
        return 2;
      case 'u32':
      case 'i32':
      case 'f32':
        return 4;
      case 'u64':
      case 'i64':
      case 'f64':
        return 8;
      case 'u128':
      case 'i128':
        return 16;
      case 'u256':
      case 'i256':
        return 32;
      case 'pubkey':
        return 32;
      case 'string':
      case 'bytes':
      case 'vec':
        return null; // Variable length
      case 'option':
        final innerSize = _calculateFieldSize(type.inner!);
        return innerSize == null ? null : 1 + innerSize;
      case 'array':
        final innerSize = _calculateFieldSize(type.inner!);
        return innerSize == null ? null : innerSize * (type.size ?? 0);
      case 'defined':
        final typeName = type.defined;
        if (typeName == null) return null;
        final nestedTypeDef = _typeLayouts[typeName as N];
        return nestedTypeDef == null ? null : _calculateTypeSize(nestedTypeDef);
      default:
        return null;
    }
  }

  /// Build enhanced type layouts from IDL with generics support
  Map<N, enhanced.IdlTypeDefEnhanced> _buildEnhancedTypeLayouts() {
    final layouts = <N, enhanced.IdlTypeDefEnhanced>{};

    if (idl.types == null) {
      return layouts;
    }

    // Convert basic types to enhanced types where possible
    for (final typeDef in idl.types!) {
      try {
        final enhancedType = _convertToEnhancedTypeDef(typeDef);
        if (enhancedType != null) {
          layouts[typeDef.name as N] = enhancedType;
        }
      } catch (e) {
        // Ignore conversion errors, fallback to basic types
      }
    }

    return layouts;
  }

  /// Convert basic type definition to enhanced type definition
  enhanced.IdlTypeDefEnhanced? _convertToEnhancedTypeDef(IdlTypeDef typeDef) {
    try {
      final enhancedTypeKind = _convertToEnhancedTypeKind(typeDef.type);
      if (enhancedTypeKind != null) {
        return enhanced.IdlTypeDefEnhanced(
          name: typeDef.name,
          docs: typeDef.docs,
          type: enhancedTypeKind,
        );
      }
    } catch (e) {
      // Conversion failed
    }
    return null;
  }

  /// Convert basic type kind to enhanced type kind
  enhanced.IdlTypeDefTy? _convertToEnhancedTypeKind(IdlTypeDefType typeKind) {
    switch (typeKind.kind) {
      case 'struct':
        final fields = typeKind.fields;
        if (fields != null) {
          final enhancedFields = _convertToEnhancedFields(fields);
          if (enhancedFields != null) {
            return enhanced.IdlTypeDefTyStruct(enhancedFields);
          }
        }
        return const enhanced.IdlTypeDefTyStruct(null);
      case 'enum':
        final variants = typeKind.variants;
        if (variants != null) {
          final enhancedVariants = variants
              .map((v) => enhanced.IdlEnumVariant(
                  v.name,
                  v.fields != null && v.fields!.isNotEmpty
                      ? _convertToEnhancedFields(v.fields!)
                      : null,),)
              .toList();
          return enhanced.IdlTypeDefTyEnum(enhancedVariants);
        }
        return const enhanced.IdlTypeDefTyEnum([]);
      default:
        return null;
    }
  }

  /// Convert basic fields to enhanced fields
  enhanced.IdlDefinedFields? _convertToEnhancedFields(List<IdlField> fields) {
    try {
      final enhancedFields = fields
          .map((f) => enhanced.IdlField(
                name: f.name,
                docs: f.docs,
                type: _convertToEnhancedType(f.type),
              ),)
          .toList();
      return enhanced.IdlDefinedFieldsNamed(enhancedFields);
    } catch (e) {
      return null;
    }
  }

  /// Convert basic type to enhanced type
  enhanced.IdlType _convertToEnhancedType(IdlType type) {
    switch (type.kind) {
      case 'bool':
      case 'u8':
      case 'i8':
      case 'u16':
      case 'i16':
      case 'u32':
      case 'i32':
      case 'u64':
      case 'i64':
      case 'f32':
      case 'f64':
      case 'u128':
      case 'i128':
      case 'u256':
      case 'i256':
      case 'string':
      case 'bytes':
      case 'pubkey':
        return enhanced.IdlTypePrimitive(type.kind);
      case 'vec':
        if (type.inner != null) {
          return enhanced.IdlTypeVec(_convertToEnhancedType(type.inner!));
        }
        break;
      case 'option':
        if (type.inner != null) {
          return enhanced.IdlTypeOption(_convertToEnhancedType(type.inner!));
        }
        break;
      case 'array':
        if (type.inner != null && type.size != null) {
          return enhanced.IdlTypeArray(
            _convertToEnhancedType(type.inner!),
            enhanced.IdlArrayLenValue(type.size!),
          );
        }
        break;
      case 'defined':
        if (type.defined != null) {
          return enhanced.IdlTypeDefined(
              enhanced.IdlTypeDefinedSimple(type.defined!),);
        }
        break;
    }
    throw ArgumentError('Cannot convert type: ${type.kind}');
  }

  /// Encode enhanced type
  Uint8List _encodeEnhancedType<T>(
      T data, enhanced.IdlTypeDefEnhanced typeDef,) {
    try {
      final serializer = BorshSerializer();
      _encodeEnhancedTypeData(data, typeDef, serializer);
      return serializer.toBytes();
    } catch (e) {
      throw TypesCoderException(
          'Failed to encode enhanced type ${typeDef.name}: $e',);
    }
  }

  /// Decode enhanced type
  T _decodeEnhancedType<T>(
      enhanced.IdlTypeDefEnhanced typeDef, Uint8List data,) {
    try {
      final deserializer = BorshDeserializer(data);
      return _decodeEnhancedTypeData<T>(typeDef, deserializer);
    } catch (e) {
      throw TypesCoderException(
          'Failed to decode enhanced type ${typeDef.name}: $e',);
    }
  }

  /// Calculate enhanced type size
  int? _calculateEnhancedTypeSize(enhanced.IdlTypeDefEnhanced typeDef) => _calculateEnhancedTypeDefSize(typeDef.type);

  /// Calculate enhanced type definition size
  int? _calculateEnhancedTypeDefSize(enhanced.IdlTypeDefTy typeDef) {
    if (typeDef is enhanced.IdlTypeDefTyStruct) {
      return _calculateEnhancedFieldsSize(typeDef.fields);
    } else if (typeDef is enhanced.IdlTypeDefTyEnum) {
      // Enum size is discriminator + max variant size
      int maxVariantSize = 0;
      for (final variant in typeDef.variants) {
        final variantSize = _calculateEnhancedFieldsSize(variant.fields);
        if (variantSize == null) return null;
        maxVariantSize = math.max(maxVariantSize, variantSize);
      }
      return 1 + maxVariantSize;
    } else if (typeDef is enhanced.IdlTypeDefTyType) {
      return _calculateEnhancedTypeSize2(typeDef.alias);
    }
    return null;
  }

  /// Calculate enhanced fields size
  int? _calculateEnhancedFieldsSize(enhanced.IdlDefinedFields? fields) {
    if (fields == null) return 0;

    if (fields is enhanced.IdlDefinedFieldsNamed) {
      int totalSize = 0;
      for (final field in fields.fields) {
        final fieldSize = _calculateEnhancedTypeSize2(field.type);
        if (fieldSize == null) return null;
        totalSize += fieldSize;
      }
      return totalSize;
    } else if (fields is enhanced.IdlDefinedFieldsTuple) {
      int totalSize = 0;
      for (final fieldType in fields.fields) {
        final fieldSize = _calculateEnhancedTypeSize2(fieldType);
        if (fieldSize == null) return null;
        totalSize += fieldSize;
      }
      return totalSize;
    }
    return 0;
  }

  /// Calculate enhanced type size (individual type)
  int? _calculateEnhancedTypeSize2(enhanced.IdlType type) {
    if (type is enhanced.IdlTypePrimitive) {
      return _calculatePrimitiveSize(type.type);
    } else if (type is enhanced.IdlTypeOption) {
      final innerSize = _calculateEnhancedTypeSize2(type.inner);
      return innerSize == null ? null : 1 + innerSize;
    } else if (type is enhanced.IdlTypeCOption) {
      final innerSize = _calculateEnhancedTypeSize2(type.inner);
      return innerSize == null ? null : 4 + innerSize;
    } else if (type is enhanced.IdlTypeVec) {
      return null; // Variable size
    } else if (type is enhanced.IdlTypeArray) {
      final innerSize = _calculateEnhancedTypeSize2(type.inner);
      if (innerSize == null) return null;
      if (type.length is enhanced.IdlArrayLenValue) {
        final length = (type.length as enhanced.IdlArrayLenValue).value;
        return innerSize * length;
      }
      return null; // Generic length
    } else if (type is enhanced.IdlTypeDefined) {
      // Look up the defined type
      if (type.defined is enhanced.IdlTypeDefinedSimple) {
        final name = (type.defined as enhanced.IdlTypeDefinedSimple).name;
        final enhancedTypeDef = _enhancedTypeLayouts[name as N];
        if (enhancedTypeDef != null) {
          return _calculateEnhancedTypeSize(enhancedTypeDef);
        }
        final basicTypeDef = _typeLayouts[name];
        if (basicTypeDef != null) {
          return _calculateTypeSize(basicTypeDef);
        }
      }
      return null;
    } else if (type is enhanced.IdlTypeGeneric) {
      return null; // Generic types have unknown size
    }
    return null;
  }

  /// Calculate primitive type size
  int _calculatePrimitiveSize(String type) {
    switch (type) {
      case 'bool':
      case 'u8':
      case 'i8':
        return 1;
      case 'u16':
      case 'i16':
        return 2;
      case 'u32':
      case 'i32':
      case 'f32':
        return 4;
      case 'u64':
      case 'i64':
      case 'f64':
        return 8;
      case 'u128':
      case 'i128':
        return 16;
      case 'u256':
      case 'i256':
        return 32;
      case 'pubkey':
        return 32;
      case 'string':
      case 'bytes':
        return 1; // Variable size (length prefix)
      default:
        return 1; // Unknown
    }
  }

  /// Encode enhanced type data
  void _encodeEnhancedTypeData(dynamic data,
      enhanced.IdlTypeDefEnhanced typeDef, BorshSerializer serializer,) {
    final typeDefKind = typeDef.type;

    if (typeDefKind is enhanced.IdlTypeDefTyStruct) {
      _encodeEnhancedStruct(data, typeDefKind, serializer);
    } else if (typeDefKind is enhanced.IdlTypeDefTyEnum) {
      _encodeEnhancedEnum(data, typeDefKind, serializer);
    } else if (typeDefKind is enhanced.IdlTypeDefTyType) {
      _encodeEnhancedValue(data, typeDefKind.alias, serializer);
    } else {
      throw TypesCoderException(
          'Unsupported enhanced type: ${typeDefKind.runtimeType}',);
    }
  }

  /// Encode enhanced struct
  void _encodeEnhancedStruct(dynamic data,
      enhanced.IdlTypeDefTyStruct structDef, BorshSerializer serializer,) {
    if (data is! Map<String, dynamic>) {
      throw const TypesCoderException('Expected Map for struct type');
    }

    final fields = structDef.fields;
    if (fields is enhanced.IdlDefinedFieldsNamed) {
      for (final field in fields.fields) {
        final value = data[field.name];
        if (value == null && !_isEnhancedOptionalType(field.type)) {
          throw TypesCoderException('Missing required field: ${field.name}');
        }
        _encodeEnhancedValue(value, field.type, serializer);
      }
    } else if (fields is enhanced.IdlDefinedFieldsTuple) {
      if (data is! List) {
        throw const TypesCoderException('Expected List for tuple struct');
      }
      if (data.length != fields.fields.length) {
        throw const TypesCoderException('Tuple struct field count mismatch');
      }
      for (int i = 0; i < fields.fields.length; i++) {
        _encodeEnhancedValue(data[i], fields.fields[i], serializer);
      }
    }
  }

  /// Encode enhanced enum
  void _encodeEnhancedEnum(dynamic data, enhanced.IdlTypeDefTyEnum enumDef,
      BorshSerializer serializer,) {
    if (data is! Map<String, dynamic>) {
      throw const TypesCoderException('Expected Map for enum type');
    }

    final variantName = data.keys.first;
    final variantIndex =
        enumDef.variants.indexWhere((v) => v.name == variantName);

    if (variantIndex == -1) {
      throw TypesCoderException('Unknown enum variant: $variantName');
    }

    // Encode variant index
    serializer.writeU8(variantIndex);

    // Encode variant data if present
    final variant = enumDef.variants[variantIndex];
    final variantData = data[variantName];

    if (variant.fields != null) {
      _encodeEnhancedVariantFields(variant.fields!, variantData, serializer);
    }
  }

  /// Encode enhanced variant fields
  void _encodeEnhancedVariantFields(enhanced.IdlDefinedFields fields,
      dynamic variantData, BorshSerializer serializer,) {
    if (fields is enhanced.IdlDefinedFieldsNamed) {
      if (variantData is Map<String, dynamic>) {
        for (final field in fields.fields) {
          final value = variantData[field.name];
          _encodeEnhancedValue(value, field.type, serializer);
        }
      } else {
        throw const TypesCoderException('Expected Map for named variant fields');
      }
    } else if (fields is enhanced.IdlDefinedFieldsTuple) {
      if (variantData is List) {
        if (variantData.length != fields.fields.length) {
          throw const TypesCoderException('Tuple variant field count mismatch');
        }
        for (int i = 0; i < fields.fields.length; i++) {
          _encodeEnhancedValue(variantData[i], fields.fields[i], serializer);
        }
      } else {
        throw const TypesCoderException('Expected List for tuple variant fields');
      }
    }
  }

  /// Check if enhanced type is optional
  bool _isEnhancedOptionalType(enhanced.IdlType type) => type is enhanced.IdlTypeOption || type is enhanced.IdlTypeCOption;

  /// Encode enhanced value
  void _encodeEnhancedValue(
      dynamic value, enhanced.IdlType type, BorshSerializer serializer,) {
    if (type is enhanced.IdlTypePrimitive) {
      _encodePrimitiveValue(value, type.type, serializer);
    } else if (type is enhanced.IdlTypeOption) {
      if (value == null) {
        serializer.writeU8(0); // None
      } else {
        serializer.writeU8(1); // Some
        _encodeEnhancedValue(value, type.inner, serializer);
      }
    } else if (type is enhanced.IdlTypeCOption) {
      if (value == null) {
        serializer.writeU32(0); // None
      } else {
        serializer.writeU32(1); // Some
        _encodeEnhancedValue(value, type.inner, serializer);
      }
    } else if (type is enhanced.IdlTypeVec) {
      final list = value as List;
      serializer.writeU32(list.length);
      for (final item in list) {
        _encodeEnhancedValue(item, type.inner, serializer);
      }
    } else if (type is enhanced.IdlTypeArray) {
      final list = value as List;
      if (type.length is enhanced.IdlArrayLenValue) {
        final expectedSize = (type.length as enhanced.IdlArrayLenValue).value;
        if (list.length != expectedSize) {
          throw TypesCoderException(
            'Array length mismatch: expected $expectedSize, got ${list.length}',
          );
        }
      }
      for (final item in list) {
        _encodeEnhancedValue(item, type.inner, serializer);
      }
    } else if (type is enhanced.IdlTypeDefined) {
      // Handle defined types recursively
      if (type.defined is enhanced.IdlTypeDefinedSimple) {
        final name = (type.defined as enhanced.IdlTypeDefinedSimple).name;
        final enhancedTypeDef = _enhancedTypeLayouts[name as N];
        if (enhancedTypeDef != null) {
          _encodeEnhancedTypeData(value, enhancedTypeDef, serializer);
          return;
        }
        final basicTypeDef = _typeLayouts[name];
        if (basicTypeDef != null) {
          _encodeTypeData(value, basicTypeDef, serializer);
          return;
        }
      }
      throw TypesCoderException('Defined type not found: ${type.defined}');
    } else if (type is enhanced.IdlTypeGeneric) {
      throw TypesCoderException('Cannot encode generic type: ${type.name}');
    } else {
      throw TypesCoderException(
          'Unsupported enhanced type: ${type.runtimeType}',);
    }
  }

  /// Encode primitive value
  void _encodePrimitiveValue(
      dynamic value, String type, BorshSerializer serializer,) {
    switch (type) {
      case 'bool':
        serializer.writeBool(value as bool);
        break;
      case 'u8':
        serializer.writeU8(value as int);
        break;
      case 'i8':
        serializer.writeI8(value as int);
        break;
      case 'u16':
        serializer.writeU16(value as int);
        break;
      case 'i16':
        serializer.writeI16(value as int);
        break;
      case 'u32':
        serializer.writeU32(value as int);
        break;
      case 'i32':
        serializer.writeI32(value as int);
        break;
      case 'u64':
        serializer.writeU64(value as int);
        break;
      case 'i64':
        serializer.writeI64(value as int);
        break;
      case 'f32':
        _writeF32(serializer, value as double);
        break;
      case 'f64':
        _writeF64(serializer, value as double);
        break;
      case 'u128':
        _writeU128(serializer, value as BigInt);
        break;
      case 'i128':
        _writeI128(serializer, value as BigInt);
        break;
      case 'u256':
        _writeU256(serializer, value as BigInt);
        break;
      case 'i256':
        _writeI256(serializer, value as BigInt);
        break;
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'bytes':
        serializer.writeFixedArray(value as Uint8List);
        break;
      case 'pubkey':
        serializer.writeString(value as String);
        break;
      default:
        throw TypesCoderException('Unsupported primitive type: $type');
    }
  }

  /// Decode enhanced type data
  T _decodeEnhancedTypeData<T>(
      enhanced.IdlTypeDefEnhanced typeDef, BorshDeserializer deserializer,) {
    final typeDefKind = typeDef.type;

    if (typeDefKind is enhanced.IdlTypeDefTyStruct) {
      return _decodeEnhancedStruct<T>(typeDefKind, deserializer);
    } else if (typeDefKind is enhanced.IdlTypeDefTyEnum) {
      return _decodeEnhancedEnum<T>(typeDefKind, deserializer);
    } else if (typeDefKind is enhanced.IdlTypeDefTyType) {
      // _decodeEnhancedValue returns dynamic, so cast to T
      return _decodeEnhancedValue(typeDefKind.alias, deserializer) as T;
    } else {
      throw TypesCoderException(
          'Unsupported enhanced type: ${typeDefKind.runtimeType}',);
    }
  }

  /// Decode enhanced struct
  T _decodeEnhancedStruct<T>(
      enhanced.IdlTypeDefTyStruct structDef, BorshDeserializer deserializer,) {
    final fields = structDef.fields;

    if (fields is enhanced.IdlDefinedFieldsNamed) {
      final data = <String, dynamic>{};
      for (final field in fields.fields) {
        data[field.name] =
            _decodeEnhancedValue<dynamic>(field.type, deserializer);
      }
      return data as T;
    } else if (fields is enhanced.IdlDefinedFieldsTuple) {
      final data = <dynamic>[];
      for (final fieldType in fields.fields) {
        data.add(_decodeEnhancedValue<dynamic>(fieldType, deserializer));
      }
      return data as T;
    } else {
      // Unit struct
      return <String, dynamic>{} as T;
    }
  }

  /// Decode enhanced enum
  T _decodeEnhancedEnum<T>(
      enhanced.IdlTypeDefTyEnum enumDef, BorshDeserializer deserializer,) {
    final variantIndex = deserializer.readU8();

    if (variantIndex >= enumDef.variants.length) {
      throw TypesCoderException('Invalid enum variant index: $variantIndex');
    }

    final variant = enumDef.variants[variantIndex];
    final data = <String, dynamic>{};

    if (variant.fields != null) {
      data[variant.name] =
          _decodeEnhancedVariantFields(variant.fields!, deserializer);
    } else {
      data[variant.name] = null;
    }

    return data as T;
  }

  /// Decode enhanced variant fields
  dynamic _decodeEnhancedVariantFields(
      enhanced.IdlDefinedFields fields, BorshDeserializer deserializer,) {
    if (fields is enhanced.IdlDefinedFieldsNamed) {
      final variantData = <String, dynamic>{};
      for (final field in fields.fields) {
        variantData[field.name] =
            _decodeEnhancedValue<dynamic>(field.type, deserializer);
      }
      return variantData;
    } else if (fields is enhanced.IdlDefinedFieldsTuple) {
      final variantData = <dynamic>[];
      for (final fieldType in fields.fields) {
        variantData.add(_decodeEnhancedValue<dynamic>(fieldType, deserializer));
      }
      return variantData;
    }
    return null;
  }

  /// Decode enhanced value
  dynamic _decodeEnhancedValue<T>(
      enhanced.IdlType type, BorshDeserializer deserializer,) {
    if (type is enhanced.IdlTypePrimitive) {
      return _decodePrimitiveValue(type.type, deserializer);
    } else if (type is enhanced.IdlTypeOption) {
      final hasValue = deserializer.readU8();
      if (hasValue == 0) {
        return null;
      } else {
        return _decodeEnhancedValue<dynamic>(type.inner, deserializer);
      }
    } else if (type is enhanced.IdlTypeCOption) {
      final hasValue = deserializer.readU32();
      if (hasValue == 0) {
        return null;
      } else {
        return _decodeEnhancedValue<dynamic>(type.inner, deserializer);
      }
    } else if (type is enhanced.IdlTypeVec) {
      final length = deserializer.readU32();
      final list = <dynamic>[];
      for (int i = 0; i < length; i++) {
        list.add(_decodeEnhancedValue<dynamic>(type.inner, deserializer));
      }
      return list;
    } else if (type is enhanced.IdlTypeArray) {
      final length = type.length is enhanced.IdlArrayLenValue
          ? (type.length as enhanced.IdlArrayLenValue).value
          : 0; // Should handle generics better
      final list = <dynamic>[];
      for (int i = 0; i < length; i++) {
        list.add(_decodeEnhancedValue<dynamic>(type.inner, deserializer));
      }
      return list;
    } else if (type is enhanced.IdlTypeDefined) {
      // Handle defined types recursively
      if (type.defined is enhanced.IdlTypeDefinedSimple) {
        final name = (type.defined as enhanced.IdlTypeDefinedSimple).name;
        final enhancedTypeDef = _enhancedTypeLayouts[name as N];
        if (enhancedTypeDef != null) {
          return _decodeEnhancedTypeData<dynamic>(
              enhancedTypeDef, deserializer,);
        }
        final basicTypeDef = _typeLayouts[name];
        if (basicTypeDef != null) {
          return _decodeTypeData<dynamic>(basicTypeDef, deserializer);
        }
      }
      throw TypesCoderException('Defined type not found: ${type.defined}');
    } else if (type is enhanced.IdlTypeGeneric) {
      throw TypesCoderException('Cannot decode generic type: ${type.name}');
    } else {
      throw TypesCoderException(
          'Unsupported enhanced type: ${type.runtimeType}',);
    }
  }

  /// Decode primitive value
  dynamic _decodePrimitiveValue(String type, BorshDeserializer deserializer) {
    switch (type) {
      case 'bool':
        return deserializer.readBool();
      case 'u8':
        return deserializer.readU8();
      case 'i8':
        return deserializer.readI8();
      case 'u16':
        return deserializer.readU16();
      case 'i16':
        return deserializer.readI16();
      case 'u32':
        return deserializer.readU32();
      case 'i32':
        return deserializer.readI32();
      case 'u64':
        return deserializer.readU64();
      case 'i64':
        return deserializer.readI64();
      case 'f32':
        return _readF32(deserializer);
      case 'f64':
        return _readF64(deserializer);
      case 'u128':
        return _readU128(deserializer);
      case 'i128':
        return _readI128(deserializer);
      case 'u256':
        return _readU256(deserializer);
      case 'i256':
        return _readI256(deserializer);
      case 'string':
        return deserializer.readString();
      case 'bytes':
        return deserializer.readFixedArray(deserializer.remaining);
      case 'pubkey':
        return deserializer.readString();
      default:
        throw TypesCoderException('Unsupported primitive type: $type');
    }
  }

  /// Encode type data based on its type definition (basic types)
  void _encodeTypeData(
      dynamic data, IdlTypeDef typeDef, BorshSerializer serializer,) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) {
        throw const TypesCoderException('Struct type missing fields');
      }

      if (data is! Map<String, dynamic>) {
        throw const TypesCoderException('Expected Map for struct type');
      }

      for (final field in fields) {
        final value = data[field.name];
        if (value == null && !_isOptionalType(field.type)) {
          throw TypesCoderException('Missing required field: ${field.name}');
        }
        _encodeValue(value, field.type, serializer);
      }
    } else if (typeSpec.kind == 'enum') {
      final variants = typeSpec.variants;
      if (variants == null) {
        throw const TypesCoderException('Enum type missing variants');
      }

      if (data is! Map<String, dynamic>) {
        throw const TypesCoderException('Expected Map for enum type');
      }

      // Find the variant index
      final variantName = data.keys.first;
      final variantIndex = variants.indexWhere((v) => v.name == variantName);

      if (variantIndex == -1) {
        throw TypesCoderException('Unknown enum variant: $variantName');
      }

      // Encode variant index
      serializer.writeU8(variantIndex);

      // Encode variant data if present
      final variant = variants[variantIndex];
      final variantData = data[variantName];

      if (variant.fields != null && variant.fields!.isNotEmpty) {
        _encodeVariantFields(variant.fields!, variantData, serializer);
      }
    } else {
      throw TypesCoderException('Unsupported type kind: ${typeSpec.kind}');
    }
  }

  /// Encode variant fields with enhanced support (basic types)
  void _encodeVariantFields(
      List<IdlField> fields, dynamic variantData, BorshSerializer serializer,) {
    if (variantData is Map<String, dynamic>) {
      // Struct-like variant (named fields)
      for (final field in fields) {
        final value = variantData[field.name];
        if (value == null && !_isOptionalType(field.type)) {
          throw TypesCoderException('Missing required field: ${field.name}');
        }
        _encodeValue(value, field.type, serializer);
      }
    } else if (variantData is List) {
      // Tuple-like variant (unnamed fields)
      if (variantData.length != fields.length) {
        throw const TypesCoderException('Tuple variant field count mismatch');
      }
      for (int i = 0; i < fields.length; i++) {
        _encodeValue(variantData[i], fields[i].type, serializer);
      }
    } else {
      throw const TypesCoderException('Expected Map or List for variant with fields');
    }
  }

  /// Check if a type is optional (basic types)
  bool _isOptionalType(IdlType type) => type.kind == 'option';

  /// Decode type data based on its type definition (basic types)
  T _decodeTypeData<T>(IdlTypeDef typeDef, BorshDeserializer deserializer) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) {
        throw const TypesCoderException('Struct type missing fields');
      }

      final data = <String, dynamic>{};
      for (final field in fields) {
        data[field.name] = _decodeValue(field.type, deserializer);
      }
      return data as T;
    } else if (typeSpec.kind == 'enum') {
      final variants = typeSpec.variants;
      if (variants == null) {
        throw const TypesCoderException('Enum type missing variants');
      }

      // Decode variant index
      final variantIndex = deserializer.readU8();

      if (variantIndex >= variants.length) {
        throw TypesCoderException('Invalid enum variant index: $variantIndex');
      }

      final variant = variants[variantIndex];
      final data = <String, dynamic>{};

      if (variant.fields != null && variant.fields!.isNotEmpty) {
        data[variant.name] =
            _decodeVariantFields(variant.fields!, deserializer);
      } else {
        // Unit variant (no data)
        data[variant.name] = null;
      }

      return data as T;
    } else {
      throw TypesCoderException('Unsupported type kind: ${typeSpec.kind}');
    }
  }

  /// Decode variant fields with enhanced support (basic types)
  dynamic _decodeVariantFields(
      List<IdlField> fields, BorshDeserializer deserializer,) {
    // Check if fields have names (struct-like) or are unnamed (tuple-like)
    if (fields.every((f) => f.name.isNotEmpty)) {
      // Struct-like: all fields have names
      final variantData = <String, dynamic>{};
      for (final field in fields) {
        variantData[field.name] = _decodeValue(field.type, deserializer);
      }
      return variantData;
    } else {
      // Tuple-like: unnamed fields
      final variantData = <dynamic>[];
      for (final field in fields) {
        variantData.add(_decodeValue(field.type, deserializer));
      }
      return variantData;
    }
  }

  /// Encode a single value based on its IDL type (basic types)
  void _encodeValue(dynamic value, IdlType type, BorshSerializer serializer) {
    switch (type.kind) {
      case 'bool':
        serializer.writeBool(value as bool);
        break;
      case 'u8':
        serializer.writeU8(value as int);
        break;
      case 'i8':
        serializer.writeI8(value as int);
        break;
      case 'u16':
        serializer.writeU16(value as int);
        break;
      case 'i16':
        serializer.writeI16(value as int);
        break;
      case 'u32':
        serializer.writeU32(value as int);
        break;
      case 'i32':
        serializer.writeI32(value as int);
        break;
      case 'u64':
        serializer.writeU64(value as int);
        break;
      case 'i64':
        serializer.writeI64(value as int);
        break;
      case 'f32':
        _writeF32(serializer, value as double);
        break;
      case 'f64':
        _writeF64(serializer, value as double);
        break;
      case 'u128':
        _writeU128(serializer, value as BigInt);
        break;
      case 'i128':
        _writeI128(serializer, value as BigInt);
        break;
      case 'u256':
        _writeU256(serializer, value as BigInt);
        break;
      case 'i256':
        _writeI256(serializer, value as BigInt);
        break;
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'bytes':
        serializer.writeFixedArray(value as Uint8List);
        break;
      case 'pubkey':
        serializer.writeString(value as String);
        break;
      case 'vec':
        final list = value as List;
        serializer.writeU32(list.length);
        for (final item in list) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      case 'option':
        if (value == null) {
          serializer.writeU8(0); // None
        } else {
          serializer.writeU8(1); // Some
          _encodeValue(value, type.inner!, serializer);
        }
        break;
      case 'array':
        final list = value as List;
        final expectedSize = type.size ?? 0;
        if (list.length != expectedSize) {
          throw TypesCoderException(
            'Array length mismatch: expected $expectedSize, got ${list.length}',
          );
        }
        for (final item in list) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      case 'defined':
        // Handle user-defined types (nested structs/enums)
        final typeName = type.defined;
        if (typeName == null) {
          throw const TypesCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == typeName,
          orElse: () => throw TypesCoderException('Type not found: $typeName'),
        );
        if (nestedTypeDef != null) {
          _encodeTypeData(value, nestedTypeDef, serializer);
        }
        break;
      default:
        throw TypesCoderException(
            'Unsupported type for encoding: ${type.kind}',);
    }
  }

  /// Decode a single value based on its IDL type (basic types)
  dynamic _decodeValue(IdlType type, BorshDeserializer deserializer) {
    switch (type.kind) {
      case 'bool':
        return deserializer.readBool();
      case 'u8':
        return deserializer.readU8();
      case 'i8':
        return deserializer.readI8();
      case 'u16':
        return deserializer.readU16();
      case 'i16':
        return deserializer.readI16();
      case 'u32':
        return deserializer.readU32();
      case 'i32':
        return deserializer.readI32();
      case 'u64':
        return deserializer.readU64();
      case 'i64':
        return deserializer.readI64();
      case 'f32':
        return _readF32(deserializer);
      case 'f64':
        return _readF64(deserializer);
      case 'u128':
        return _readU128(deserializer);
      case 'i128':
        return _readI128(deserializer);
      case 'u256':
        return _readU256(deserializer);
      case 'i256':
        return _readI256(deserializer);
      case 'string':
        return deserializer.readString();
      case 'bytes':
        return deserializer.readFixedArray(deserializer.remaining);
      case 'pubkey':
        return deserializer.readString();
      case 'vec':
        final length = deserializer.readU32();
        final list = <dynamic>[];
        for (int i = 0; i < length; i++) {
          list.add(_decodeValue(type.inner!, deserializer));
        }
        return list;
      case 'option':
        final hasValue = deserializer.readU8();
        if (hasValue == 0) {
          return null;
        } else {
          return _decodeValue(type.inner!, deserializer);
        }
      case 'array':
        final size = type.size ?? 0;
        final list = <dynamic>[];
        for (int i = 0; i < size; i++) {
          list.add(_decodeValue(type.inner!, deserializer));
        }
        return list;
      case 'defined':
        // Handle user-defined types (nested structs/enums)
        final typeName = type.defined;
        if (typeName == null) {
          throw const TypesCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == typeName,
          orElse: () => throw TypesCoderException('Type not found: $typeName'),
        );
        if (nestedTypeDef != null) {
          return _decodeTypeData<dynamic>(nestedTypeDef, deserializer);
        }
        return null;
      default:
        throw TypesCoderException(
            'Unsupported type for decoding: ${type.kind}',);
    }
  }

  // Helper methods for extended numeric types
  void _writeF32(BorshSerializer serializer, double value) {
    final bytes = Uint8List(4);
    bytes.buffer.asByteData().setFloat32(0, value, Endian.little);
    serializer.writeFixedArray(bytes);
  }

  void _writeF64(BorshSerializer serializer, double value) {
    final bytes = Uint8List(8);
    bytes.buffer.asByteData().setFloat64(0, value, Endian.little);
    serializer.writeFixedArray(bytes);
  }

  void _writeU128(BorshSerializer serializer, BigInt value) {
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = (value >> (8 * i) & BigInt.from(0xFF)).toInt();
    }
    serializer.writeFixedArray(bytes);
  }

  void _writeI128(BorshSerializer serializer, BigInt value) {
    _writeU128(serializer, value);
  }

  void _writeU256(BorshSerializer serializer, BigInt value) {
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = (value >> (8 * i) & BigInt.from(0xFF)).toInt();
    }
    serializer.writeFixedArray(bytes);
  }

  void _writeI256(BorshSerializer serializer, BigInt value) {
    _writeU256(serializer, value);
  }

  double _readF32(BorshDeserializer deserializer) {
    final bytes = deserializer.readFixedArray(4);
    return bytes.buffer.asByteData().getFloat32(0, Endian.little);
  }

  double _readF64(BorshDeserializer deserializer) {
    final bytes = deserializer.readFixedArray(8);
    return bytes.buffer.asByteData().getFloat64(0, Endian.little);
  }

  BigInt _readU128(BorshDeserializer deserializer) {
    final bytes = deserializer.readFixedArray(16);
    BigInt result = BigInt.zero;
    for (int i = 0; i < 16; i++) {
      result |= BigInt.from(bytes[i]) << (8 * i);
    }
    return result;
  }

  BigInt _readI128(BorshDeserializer deserializer) => _readU128(deserializer);

  BigInt _readU256(BorshDeserializer deserializer) {
    final bytes = deserializer.readFixedArray(32);
    BigInt result = BigInt.zero;
    for (int i = 0; i < 32; i++) {
      result |= BigInt.from(bytes[i]) << (8 * i);
    }
    return result;
  }

  BigInt _readI256(BorshDeserializer deserializer) => _readU256(deserializer);
}

/// Exception thrown by types coder operations
class TypesCoderException extends AnchorException {
  const TypesCoderException(super.message, [super.cause]);
}
