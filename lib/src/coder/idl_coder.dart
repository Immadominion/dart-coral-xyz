/// IDL coder utilities for encoding/decoding and size calculations
///
/// This module provides TypeScript-compatible IDL utilities including
/// type size calculation, layout generation, and generic argument resolution.
library;

import 'package:coral_xyz/src/idl/idl.dart';

/// Error thrown when IDL operations fail
class IdlCoderError extends Error {
  final String message;
  IdlCoderError(this.message);

  @override
  String toString() => 'IdlCoderError: $message';
}

/// IDL coder providing static utilities for type size calculation and layout generation
///
/// This class mirrors the TypeScript `IdlCoder` implementation providing:
/// - Type size calculation with comprehensive IDL type support
/// - Generic argument resolution
/// - Array length resolution
/// - Layout generation utilities
class IdlCoder {
  /// Get the type size in bytes. Returns `1` for variable length types.
  ///
  /// This method provides comprehensive type size calculation matching
  /// the TypeScript `IdlCoder.typeSize()` implementation exactly.
  static int typeSize(
    IdlType type,
    Idl idl, {
    List<IdlGenericArg>? genericArgs,
  }) {
    return _calculateTypeSize(type, idl, genericArgs);
  }

  /// Calculate type size with comprehensive IDL type support
  static int _calculateTypeSize(
    IdlType type,
    Idl idl,
    List<IdlGenericArg>? genericArgs,
  ) {
    // Handle primitive types
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
      case 'bytes':
      case 'string':
        return 1; // Variable length
      case 'pubkey':
        return 32;

      // Option type
      case 'option':
        if (type.inner == null) {
          throw IdlCoderError('Option type missing inner type');
        }
        return 1 + _calculateTypeSize(type.inner!, idl, genericArgs);

      // COption type
      case 'coption':
        if (type.inner == null) {
          throw IdlCoderError('COption type missing inner type');
        }
        return 4 + _calculateTypeSize(type.inner!, idl, genericArgs);

      // Vec type
      case 'vec':
        return 1; // Variable length

      // Array type
      case 'array':
        if (type.inner == null || type.size == null) {
          throw IdlCoderError('Array type missing inner type or size');
        }

        int length;
        if (type.size is int) {
          length = type.size!;
        } else {
          length = _resolveArrayLen(type.size, genericArgs);
        }

        return _calculateTypeSize(type.inner!, idl, genericArgs) * length;

      // Defined type
      case 'defined':
        if (type.defined == null) {
          throw IdlCoderError('Defined type missing name');
        }

        final typeDef = idl.types?.firstWhere(
          (t) => t.name == type.defined,
          orElse: () => throw IdlCoderError('Type not found: ${type.defined}'),
        );

        if (typeDef == null) {
          throw IdlCoderError('Type not found: ${type.defined}');
        }

        return _calculateDefinedTypeSize(typeDef, idl, genericArgs);

      // Generic type
      case 'generic':
        final genericArg = genericArgs?.firstWhere(
          (arg) => arg.kind == 'type',
          orElse: () => throw IdlCoderError('Generic not found: ${type.kind}'),
        );

        if (genericArg == null || genericArg.kind != 'type') {
          throw IdlCoderError('Invalid generic: ${type.kind}');
        }

        return _calculateTypeSize(genericArg.type as IdlType, idl, genericArgs);

      default:
        throw IdlCoderError('Unknown type kind: ${type.kind}');
    }
  }

  /// Calculate size for defined types (struct, enum, type alias)
  static int _calculateDefinedTypeSize(
    IdlTypeDef typeDef,
    Idl idl,
    List<IdlGenericArg>? genericArgs,
  ) {
    final typeSpec = typeDef.type;

    switch (typeSpec.kind) {
      case 'struct':
        final fields = typeSpec.fields;
        if (fields == null || fields.isEmpty) {
          return 0;
        }

        int totalSize = 0;
        for (final field in fields) {
          totalSize += _calculateTypeSize(field.type, idl, genericArgs);
        }
        return totalSize;

      case 'enum':
        final variants = typeSpec.variants;
        if (variants == null || variants.isEmpty) {
          return 1; // Just discriminator
        }

        int maxVariantSize = 0;
        for (final variant in variants) {
          int variantSize = 0;
          if (variant.fields != null && variant.fields!.isNotEmpty) {
            for (final field in variant.fields!) {
              variantSize += _calculateTypeSize(field.type, idl, genericArgs);
            }
          }
          maxVariantSize =
              maxVariantSize > variantSize ? maxVariantSize : variantSize;
        }
        return 1 + maxVariantSize; // 1 byte discriminator + max variant size

      default:
        throw IdlCoderError('Unknown type definition kind: ${typeSpec.kind}');
    }
  }

  /// Resolve array length from generic or constant value
  static int _resolveArrayLen(
    dynamic len,
    List<IdlGenericArg>? genericArgs,
  ) {
    if (len is int) {
      return len;
    }

    if (len is Map<String, dynamic> && len.containsKey('generic')) {
      final genericName = len['generic'] as String;

      if (genericArgs != null) {
        final constGeneric = genericArgs.firstWhere(
          (g) => g.kind == 'const',
          orElse: () =>
              throw IdlCoderError('Const generic not found: $genericName'),
        );

        if (constGeneric.kind == 'const') {
          return int.parse(constGeneric.value);
        }
      }
    }

    throw IdlCoderError('Generic array length did not resolve: $len');
  }
}

/// Generic argument for IDL type resolution
class IdlGenericArg {
  final String kind; // 'type' or 'const'
  final dynamic type; // For 'type' kind
  final String value; // For 'const' kind

  const IdlGenericArg({
    required this.kind,
    this.type,
    this.value = '',
  });
}
