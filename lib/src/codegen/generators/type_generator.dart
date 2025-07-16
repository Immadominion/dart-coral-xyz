/// Type definition generator
///
/// This module generates Dart classes for custom types defined in the IDL,
/// including struct types, enum types, and type aliases.
library;

import 'package:build/build.dart';
import '../../idl/idl.dart';

/// Generator for type definitions
class TypeGenerator {
  /// Creates a TypeGenerator with the given IDL and options
  TypeGenerator(this.idl, this.options);

  /// IDL definition
  final Idl idl;

  /// Build options
  final BuilderOptions options;

  /// Generate all type definitions
  String generate() {
    final buffer = StringBuffer();

    // Generate type definitions
    if (idl.types != null && idl.types!.isNotEmpty) {
      for (final typeDef in idl.types!) {
        _generateTypeDefinition(buffer, typeDef);
      }
    }

    return buffer.toString();
  }

  /// Generate type definition
  void _generateTypeDefinition(StringBuffer buffer, IdlTypeDef typeDef) {
    switch (typeDef.type.kind) {
      case 'struct':
        _generateStructType(buffer, typeDef);
        break;
      case 'enum':
        _generateEnumType(buffer, typeDef);
        break;
      default:
        // For other types, generate a simple type alias
        _generateTypeAlias(buffer, typeDef);
        break;
    }
  }

  /// Generate struct type
  void _generateStructType(StringBuffer buffer, IdlTypeDef typeDef) {
    final className = _toPascalCase(typeDef.name);

    buffer.writeln('/// Struct type: ${typeDef.name}');
    if (typeDef.docs?.isNotEmpty == true) {
      for (final doc in typeDef.docs!) {
        buffer.writeln('/// $doc');
      }
    }
    buffer.writeln('class $className {');

    // Generate constructor
    buffer.writeln('  /// Creates a new $className');
    buffer.writeln('  const $className({');

    if (typeDef.type.fields != null) {
      for (final field in typeDef.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        buffer.writeln('    required this.$fieldName,');
      }
    }

    buffer.writeln('  });');
    buffer.writeln();

    // Generate fields
    if (typeDef.type.fields != null) {
      for (final field in typeDef.type.fields!) {
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
    _generateStructSerialization(buffer, typeDef);

    // Generate utility methods
    _generateStructUtilities(buffer, typeDef);

    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate enum type
  void _generateEnumType(StringBuffer buffer, IdlTypeDef typeDef) {
    final className = _toPascalCase(typeDef.name);

    buffer.writeln('/// Enum type: ${typeDef.name}');
    if (typeDef.docs?.isNotEmpty == true) {
      for (final doc in typeDef.docs!) {
        buffer.writeln('/// $doc');
      }
    }
    buffer.writeln('enum $className {');

    // Generate enum values
    if (typeDef.type.variants != null) {
      for (final variant in typeDef.type.variants!) {
        final variantName = _toCamelCase(variant.name);
        buffer.writeln('  /// ${variant.name} variant');
        buffer.writeln('  $variantName,');
      }
    }

    buffer.writeln('}');
    buffer.writeln();

    // Generate enum extension for additional functionality
    buffer.writeln('/// Extension for $className enum');
    buffer.writeln('extension ${className}Extension on $className {');

    // Generate fromIndex method
    buffer.writeln('  /// Create enum from index');
    buffer.writeln('  static $className fromIndex(int index) {');
    buffer.writeln('    return $className.values[index];');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate toIndex method
    buffer.writeln('  /// Get index of enum value');
    buffer.writeln('  int get index => $className.values.indexOf(this);');
    buffer.writeln();

    // Generate name method
    buffer.writeln('  /// Get name of enum value');
    buffer.writeln('  String get name {');
    buffer.writeln('    switch (this) {');
    if (typeDef.type.variants != null) {
      for (final variant in typeDef.type.variants!) {
        final variantName = _toCamelCase(variant.name);
        buffer.writeln('      case $className.$variantName:');
        buffer.writeln('        return \'${variant.name}\';');
      }
    }
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate type alias
  void _generateTypeAlias(StringBuffer buffer, IdlTypeDef typeDef) {
    final className = _toPascalCase(typeDef.name);

    buffer.writeln('/// Type alias: ${typeDef.name}');
    if (typeDef.docs?.isNotEmpty == true) {
      for (final doc in typeDef.docs!) {
        buffer.writeln('/// $doc');
      }
    }
    buffer.writeln(
        'typedef $className = dynamic; // TODO: Implement proper type mapping');
    buffer.writeln();
  }

  /// Generate struct serialization methods
  void _generateStructSerialization(StringBuffer buffer, IdlTypeDef typeDef) {
    final className = _toPascalCase(typeDef.name);

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
    if (typeDef.type.fields != null) {
      for (final field in typeDef.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        final deserializer = _getDeserializerForType(field.type);
        buffer.writeln('    final $fieldName = $deserializer;');
      }
    }
    buffer.writeln('    return $className(');
    if (typeDef.type.fields != null) {
      for (final field in typeDef.type.fields!) {
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
    if (typeDef.type.fields != null) {
      for (final field in typeDef.type.fields!) {
        final fieldName = _toCamelCase(field.name);
        final serializer = _getSerializerForType(field.type, fieldName);
        buffer.writeln('    $serializer;');
      }
    }
    buffer.writeln('  }');
    buffer.writeln();
  }

  /// Generate struct utility methods
  void _generateStructUtilities(StringBuffer buffer, IdlTypeDef typeDef) {
    final className = _toPascalCase(typeDef.name);

    // Generate toString method
    buffer.writeln('  @override');
    buffer.writeln('  String toString() {');
    buffer.writeln('    return \'$className(\' +');
    if (typeDef.type.fields != null) {
      for (int i = 0; i < typeDef.type.fields!.length; i++) {
        final field = typeDef.type.fields![i];
        final fieldName = _toCamelCase(field.name);
        final separator = i < typeDef.type.fields!.length - 1 ? ', ' : '';
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
    if (typeDef.type.fields != null) {
      for (int i = 0; i < typeDef.type.fields!.length; i++) {
        final field = typeDef.type.fields![i];
        final fieldName = _toCamelCase(field.name);
        final separator = i < typeDef.type.fields!.length - 1 ? ' &&' : ';';
        buffer.writeln('      $fieldName == other.$fieldName$separator');
      }
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Generate hashCode method
    buffer.writeln('  @override');
    buffer.writeln('  int get hashCode {');
    buffer.writeln('    return Object.hash(');
    if (typeDef.type.fields != null) {
      for (final field in typeDef.type.fields!) {
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
