/// Unified type conversion utilities for IDL and Borsh integration
///
/// This module provides comprehensive type conversion utilities between
/// IDL types and Dart native types, ensuring consistent type handling
/// across all serialization paths.

library;

import 'dart:typed_data';
import '../idl/idl.dart';
import '../types/public_key.dart';
import '../coder/borsh_types.dart';

/// Unified type conversion utilities
class TypeConverter {
  /// Serialize value using IDL type specification
  static Uint8List serializeWithIdlType(IdlType idlType, dynamic value) {
    final serializer = BorshSerializer();
    _writeValueWithIdlType(serializer, idlType, value);
    return serializer.toBytes();
  }

  /// Deserialize value using IDL type specification
  static dynamic deserializeWithIdlType(IdlType idlType, Uint8List data) {
    final deserializer = BorshDeserializer(data);
    return _readValueWithIdlType(deserializer, idlType);
  }

  /// Convert Dart value to appropriate type for IDL specification
  static dynamic convertValueForIdlType(IdlType idlType, dynamic value) {
    switch (idlType.kind) {
      case 'bool':
        if (value is bool) return value;
        if (value is int) return value != 0;
        throw ArgumentError(
            'Expected bool for bool type, got ${value.runtimeType}');

      case 'u8':
      case 'u16':
      case 'u32':
      case 'u64':
      case 'i8':
      case 'i16':
      case 'i32':
      case 'i64':
        if (value is int) return value;
        if (value is String) {
          try {
            return int.parse(value);
          } catch (e) {
            throw ArgumentError(
                'Invalid number format for ${idlType.kind} type: $value');
          }
        }
        throw ArgumentError(
            'Expected int for ${idlType.kind} type, got ${value.runtimeType}');

      case 'string':
        if (value is String) return value;
        return value.toString();

      case 'pubkey':
      case 'publicKey':
        if (value is PublicKey) return value;
        if (value is String) return PublicKey.fromBase58(value);
        if (value is List<int>) return PublicKey.fromBytes(value);
        throw ArgumentError(
            'Expected PublicKey for publicKey type, got ${value.runtimeType}');

      case 'vec':
        if (value is! List) {
          throw ArgumentError(
              'Expected List for vec type, got ${value.runtimeType}');
        }
        if (idlType.inner == null) {
          throw ArgumentError('Vec type requires inner type');
        }
        return value
            .map((item) => convertValueForIdlType(idlType.inner!, item))
            .toList();

      case 'option':
        if (value == null) return null;
        if (idlType.inner == null) {
          throw ArgumentError('Option type requires inner type');
        }
        return convertValueForIdlType(idlType.inner!, value);

      case 'array':
        if (value is! List) {
          throw ArgumentError(
              'Expected List for array type, got ${value.runtimeType}');
        }
        if (idlType.inner == null || idlType.size == null) {
          throw ArgumentError('Array type requires inner type and size');
        }
        if (value.length != idlType.size) {
          throw ArgumentError(
              'Array length ${value.length} doesn\'t match expected size ${idlType.size}');
        }
        return value
            .map((item) => convertValueForIdlType(idlType.inner!, item))
            .toList();

      default:
        return value; // Pass through for defined types and unknown types
    }
  }

  /// Write value using specific IDL type
  static void _writeValueWithIdlType(
      BorshSerializer serializer, IdlType idlType, dynamic value) {
    switch (idlType.kind) {
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
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'pubkey':
      case 'publicKey':
        if (value is PublicKey) {
          serializer.writeFixedArray(value.bytes);
        } else if (value is List<int>) {
          serializer.writeFixedArray(Uint8List.fromList(value));
        } else {
          throw ArgumentError(
              'Expected PublicKey or List<int> for publicKey type');
        }
        break;
      case 'vec':
        if (value is! List) {
          throw ArgumentError('Expected List for vec type');
        }
        serializer.writeU32(value.length);
        for (final item in value) {
          _writeValueWithIdlType(serializer, idlType.inner!, item);
        }
        break;
      case 'option':
        if (value == null) {
          serializer.writeU8(0);
        } else {
          serializer.writeU8(1);
          _writeValueWithIdlType(serializer, idlType.inner!, value);
        }
        break;
      case 'array':
        if (value is! List) {
          throw ArgumentError('Expected List for array type');
        }
        if (value.length != idlType.size) {
          throw ArgumentError(
              'Array length ${value.length} doesn\'t match expected size ${idlType.size}');
        }
        for (final item in value) {
          _writeValueWithIdlType(serializer, idlType.inner!, item);
        }
        break;
      default:
        throw ArgumentError(
            'Unsupported IDL type for serialization: ${idlType.kind}');
    }
  }

  /// Read value using specific IDL type
  static dynamic _readValueWithIdlType(
      BorshDeserializer deserializer, IdlType idlType) {
    switch (idlType.kind) {
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
      case 'string':
        return deserializer.readString();
      case 'pubkey':
      case 'publicKey':
        final bytes = deserializer.readFixedArray(32);
        return PublicKey.fromBytes(bytes);
      case 'vec':
        final length = deserializer.readU32();
        final List<dynamic> result = [];
        for (int i = 0; i < length; i++) {
          result.add(_readValueWithIdlType(deserializer, idlType.inner!));
        }
        return result;
      case 'option':
        final hasValue = deserializer.readU8() != 0;
        if (hasValue) {
          return _readValueWithIdlType(deserializer, idlType.inner!);
        }
        return null;
      case 'array':
        final List<dynamic> result = [];
        for (int i = 0; i < idlType.size!; i++) {
          result.add(_readValueWithIdlType(deserializer, idlType.inner!));
        }
        return result;
      default:
        throw ArgumentError(
            'Unsupported IDL type for deserialization: ${idlType.kind}');
    }
  }

  /// Validate that a value is compatible with an IDL type
  static bool isValueCompatibleWithIdlType(IdlType idlType, dynamic value) {
    try {
      convertValueForIdlType(idlType, value);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Extension methods for IdlType to add conversion utilities
extension IdlTypeConversion on IdlType {
  /// Serialize a value using this IDL type
  Uint8List serialize(dynamic value) =>
      TypeConverter.serializeWithIdlType(this, value);

  /// Deserialize data using this IDL type
  dynamic deserialize(Uint8List data) =>
      TypeConverter.deserializeWithIdlType(this, data);

  /// Convert a value to be compatible with this IDL type
  dynamic convertValue(dynamic value) =>
      TypeConverter.convertValueForIdlType(this, value);

  /// Check if a value is compatible with this IDL type
  bool isCompatibleWith(dynamic value) =>
      TypeConverter.isValueCompatibleWithIdlType(this, value);
}
