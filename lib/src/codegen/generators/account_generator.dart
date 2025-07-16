/// Account data class generator
///
/// This module generates account data classes with proper serialization
/// and deserialization methods for Anchor program accounts.
library;

import 'package:build/build.dart';
import '../../idl/idl.dart';

/// Generator for account data classes
class AccountGenerator {
  /// Creates an AccountGenerator with the given IDL and options
  AccountGenerator(this.idl, this.options);

  /// IDL definition
  final Idl idl;

  /// Build options
  final BuilderOptions options;

  /// Generate all account data classes
  String generate() {
    final buffer = StringBuffer();

    // Generate account classes
    if (idl.accounts != null) {
      for (final account in idl.accounts!) {
        _generateAccountClass(buffer, account);
      }
    }

    return buffer.toString();
  }

  /// Generate account data class for a single account
  void _generateAccountClass(StringBuffer buffer, IdlAccount account) {
    final className = _toPascalCase(account.name);

    buffer.writeln('/// Account data class for ${account.name}');
    if (account.docs?.isNotEmpty == true) {
      for (final doc in account.docs!) {
        buffer.writeln('/// $doc');
      }
    }
    buffer.writeln('class $className {');

    // Generate constructor
    buffer.writeln('  /// Creates a new $className');
    buffer.writeln('  const $className({');

    // Add fields for account type
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (final field in account.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        buffer.writeln('    required this.$fieldName,');
      }
    }

    buffer.writeln('  });');
    buffer.writeln();

    // Generate fields
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (final field in account.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        final fieldType = _dartTypeFromIdlType(field.type);
        buffer.writeln('  /// ${field.name} field');
        if (field.docs?.isNotEmpty == true) {
          for (final doc in field.docs!) {
            buffer.writeln('  /// $doc');
          }
        }
        buffer.writeln('  final $fieldType $fieldName;');
      }
    }
    buffer.writeln();

    // Generate serialization methods
    _generateSerializationMethods(buffer, account);

    // Generate utility methods
    _generateUtilityMethods(buffer, account);

    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate serialization methods
  void _generateSerializationMethods(StringBuffer buffer, IdlAccount account) {
    final className = _toPascalCase(account.name);

    // Generate fromBytes method
    buffer.writeln('  /// Create $className from bytes');
    buffer.writeln('  static $className fromBytes(List<int> bytes) {');
    buffer.writeln('    final reader = BinaryReader(bytes);');
    buffer.writeln('    return $className.fromReader(reader);');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate fromReader method
    buffer.writeln('  /// Create $className from BinaryReader');
    buffer.writeln('  static $className fromReader(BinaryReader reader) {');
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (final field in account.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        final deserializer = _getDeserializerForType(field.type);
        buffer.writeln('    final $fieldName = $deserializer;');
      }
    }
    buffer.writeln('    return $className(');
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (final field in account.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        buffer.writeln('      $fieldName: $fieldName,');
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate toBytes method
    buffer.writeln('  /// Convert $className to bytes');
    buffer.writeln('  List<int> toBytes() {');
    buffer.writeln('    final writer = BinaryWriter();');
    buffer.writeln('    writeToWriter(writer);');
    buffer.writeln('    return writer.toBytes();');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate writeToWriter method
    buffer.writeln('  /// Write $className to BinaryWriter');
    buffer.writeln('  void writeToWriter(BinaryWriter writer) {');
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (final field in account.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        final serializer = _getSerializerForType(field.type, fieldName);
        buffer.writeln('    $serializer;');
      }
    }
    buffer.writeln('  }');
    buffer.writeln();
  }

  /// Generate utility methods
  void _generateUtilityMethods(StringBuffer buffer, IdlAccount account) {
    final className = _toPascalCase(account.name);

    // Generate toString method
    buffer.writeln('  @override');
    buffer.writeln('  String toString() {');
    buffer.writeln('    return \'$className(\' +');
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (int i = 0; i < account.type.fields!.length; i++) {
        final field = account.type.fields![i];
        final fieldName = _toCamelCase(field.name);
        final separator = i < account.type.fields!.length - 1 ? ', ' : '';
        buffer.writeln('      \'${field.name}: \$$fieldName$separator\' +');
      }
    }
    buffer.writeln('      \')\';');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate equality methods
    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) {');
    buffer.writeln('    if (identical(this, other)) return true;');
    buffer.writeln('    if (other is! $className) return false;');
    buffer.writeln('    return');
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (int i = 0; i < account.type.fields!.length; i++) {
        final field = account.type.fields![i];
        final fieldName = _toCamelCase(field.name);
        final separator = i < account.type.fields!.length - 1 ? ' &&' : ';';
        buffer.writeln('      $fieldName == other.$fieldName$separator');
      }
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Generate hashCode method
    buffer.writeln('  @override');
    buffer.writeln('  int get hashCode {');
    buffer.writeln('    return Object.hash(');
    if (account.type.kind == 'struct' && account.type.fields != null) {
      for (final field in account.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        buffer.writeln('      $fieldName,');
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  /// Get deserializer code for a type
  String _getDeserializerForType(IdlType type) {
    switch (type.kind) {
      case 'bool':
        return 'reader.readBool()';
      case 'u8':
        return 'reader.readU8()';
      case 'i8':
        return 'reader.readI8()';
      case 'u16':
        return 'reader.readU16()';
      case 'i16':
        return 'reader.readI16()';
      case 'u32':
        return 'reader.readU32()';
      case 'i32':
        return 'reader.readI32()';
      case 'u64':
        return 'reader.readU64()';
      case 'i64':
        return 'reader.readI64()';
      case 'u128':
        return 'reader.readU128()';
      case 'i128':
        return 'reader.readI128()';
      case 'f32':
        return 'reader.readF32()';
      case 'f64':
        return 'reader.readF64()';
      case 'string':
        return 'reader.readString()';
      case 'publicKey':
        return 'PublicKey.fromBytes(reader.readBytes(32))';
      case 'bytes':
        return 'reader.readBytes(reader.readU32())';
      case 'vec':
        if (type.inner != null) {
          final innerDeserializer = _getDeserializerForType(type.inner!);
          return 'reader.readVec(() => $innerDeserializer)';
        }
        return 'reader.readVec(() => reader.readU8())';
      case 'option':
        if (type.inner != null) {
          final innerDeserializer = _getDeserializerForType(type.inner!);
          return 'reader.readOption(() => $innerDeserializer)';
        }
        return 'reader.readOption(() => reader.readU8())';
      case 'defined':
        final typeName = _toPascalCase(type.defined ?? 'Unknown');
        return '$typeName.fromReader(reader)';
      default:
        return 'reader.readU8()';
    }
  }

  /// Get serializer code for a type
  String _getSerializerForType(IdlType type, String fieldName) {
    switch (type.kind) {
      case 'bool':
        return 'writer.writeBool($fieldName)';
      case 'u8':
        return 'writer.writeU8($fieldName)';
      case 'i8':
        return 'writer.writeI8($fieldName)';
      case 'u16':
        return 'writer.writeU16($fieldName)';
      case 'i16':
        return 'writer.writeI16($fieldName)';
      case 'u32':
        return 'writer.writeU32($fieldName)';
      case 'i32':
        return 'writer.writeI32($fieldName)';
      case 'u64':
        return 'writer.writeU64($fieldName)';
      case 'i64':
        return 'writer.writeI64($fieldName)';
      case 'u128':
        return 'writer.writeU128($fieldName)';
      case 'i128':
        return 'writer.writeI128($fieldName)';
      case 'f32':
        return 'writer.writeF32($fieldName)';
      case 'f64':
        return 'writer.writeF64($fieldName)';
      case 'string':
        return 'writer.writeString($fieldName)';
      case 'publicKey':
        return 'writer.writeBytes($fieldName.toBytes())';
      case 'bytes':
        return 'writer.writeU32($fieldName.length); writer.writeBytes($fieldName)';
      case 'vec':
        return 'writer.writeVec($fieldName, (item) => ${_getSerializerForType(type.inner!, 'item')})';
      case 'option':
        return 'writer.writeOption($fieldName, (item) => ${_getSerializerForType(type.inner!, 'item')})';
      case 'defined':
        return '$fieldName.writeToWriter(writer)';
      default:
        return 'writer.writeU8($fieldName as int)';
    }
  }

  /// Convert IDL type to Dart type
  String _dartTypeFromIdlType(IdlType type) {
    switch (type.kind) {
      case 'bool':
        return 'bool';
      case 'u8':
      case 'i8':
      case 'u16':
      case 'i16':
      case 'u32':
      case 'i32':
        return 'int';
      case 'u64':
      case 'i64':
      case 'u128':
      case 'i128':
        return 'BigInt';
      case 'f32':
      case 'f64':
        return 'double';
      case 'bytes':
        return 'List<int>';
      case 'string':
        return 'String';
      case 'publicKey':
        return 'PublicKey';
      case 'array':
        if (type.inner != null) {
          final elementType = _dartTypeFromIdlType(type.inner!);
          return 'List<$elementType>';
        }
        return 'List<dynamic>';
      case 'vec':
        if (type.inner != null) {
          final elementType = _dartTypeFromIdlType(type.inner!);
          return 'List<$elementType>';
        }
        return 'List<dynamic>';
      case 'option':
        if (type.inner != null) {
          final elementType = _dartTypeFromIdlType(type.inner!);
          return '$elementType?';
        }
        return 'dynamic?';
      case 'defined':
        return _toPascalCase(type.defined ?? 'Unknown');
      default:
        return 'dynamic';
    }
  }

  /// Convert string to PascalCase
  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join('');
  }

  /// Convert string to camelCase
  String _toCamelCase(String input) {
    final pascalCase = _toPascalCase(input);
    return pascalCase.isNotEmpty
        ? pascalCase[0].toLowerCase() + pascalCase.substring(1)
        : '';
  }
}
