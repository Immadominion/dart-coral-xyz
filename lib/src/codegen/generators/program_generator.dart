/// Program interface generator
///
/// This module generates the main program interface class that provides
/// typed method access to all program instructions.
library;

import 'package:build/build.dart';
import '../../idl/idl.dart';

/// Generator for the main program interface class
class ProgramGenerator {
  /// Creates a ProgramGenerator with the given IDL and options
  ProgramGenerator(this.idl, this.options);

  /// IDL definition
  final Idl idl;

  /// Build options
  final BuilderOptions options;

  /// Generate the program interface class
  String generate() {
    final buffer = StringBuffer();

    // Generate program class
    _generateProgramClass(buffer);

    return buffer.toString();
  }

  /// Generate the main program class
  void _generateProgramClass(StringBuffer buffer) {
    final programName = '${_toPascalCase(idl.name ?? 'Program')}Program';

    buffer.writeln('/// Main program interface for ${idl.name ?? 'program'}');
    if (idl.docs?.isNotEmpty == true) {
      for (final doc in idl.docs!) {
        buffer.writeln('/// $doc');
      }
    }
    buffer.writeln('class $programName extends Program {');
    buffer.writeln('  /// Creates a new $programName instance');
    buffer.writeln('  $programName({');
    buffer.writeln('    required PublicKey programId,');
    buffer.writeln('    AnchorProvider? provider,');
    buffer.writeln(
        '  }) : super.withProgramId(Idl.fromJson(programIdl), programId, provider: provider);');
    buffer.writeln();

    // Generate instruction methods
    for (final instruction in idl.instructions) {
      _generateInstructionMethod(buffer, instruction);
    }

    // Generate utility methods
    _generateUtilityMethods(buffer);

    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate method for a single instruction
  void _generateInstructionMethod(
      StringBuffer buffer, IdlInstruction instruction) {
    final methodName = _toCamelCase(instruction.name);
    final className = _toPascalCase(instruction.name);

    buffer.writeln('  /// ${instruction.name} instruction');
    if (instruction.docs?.isNotEmpty == true) {
      for (final doc in instruction.docs!) {
        buffer.writeln('  /// $doc');
      }
    }

    // Generate method signature
    if (instruction.args.isEmpty) {
      buffer.writeln('  ${className}InstructionBuilder $methodName() {');
    } else {
      buffer.writeln('  ${className}InstructionBuilder $methodName({');
      // Add parameters for instruction arguments
      for (final arg in instruction.args) {
        final paramType = _dartTypeFromIdlType(arg.type);
        final paramName = _toCamelCase(arg.name);
        buffer.writeln('    $paramType? $paramName,');
      }
      buffer.writeln('  }) {');
    }

    buffer.writeln('    return ${className}InstructionBuilder(');
    buffer.writeln('      program: this,');

    // Pass parameters
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('      $paramName: $paramName,');
    }

    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  /// Generate utility methods
  void _generateUtilityMethods(StringBuffer buffer) {
    buffer.writeln('  /// Get the program IDL');
    buffer.writeln('  static const Map<String, dynamic> programIdl = {');

    // Generate IDL structure
    buffer.writeln(
        '    \'version\': \'${idl.metadata?.version ?? idl.version ?? '0.1.0'}\',');
    buffer.writeln(
        '    \'name\': \'${idl.metadata?.name ?? idl.name ?? 'program'}\',');
    buffer.writeln('    \'instructions\': [');

    for (final instruction in idl.instructions) {
      buffer.writeln('      {');
      buffer.writeln('        \'name\': \'${instruction.name}\',');
      buffer.writeln('        \'args\': [');

      for (final arg in instruction.args) {
        buffer.writeln('          {');
        buffer.writeln('            \'name\': \'${arg.name}\',');
        buffer.writeln(
            '            \'type\': \'${_serializeIdlType(arg.type)}\',');
        buffer.writeln('          },');
      }

      buffer.writeln('        ],');
      buffer.writeln('      },');
    }

    buffer.writeln('    ],');
    buffer.writeln('  };');
    buffer.writeln();
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

  /// Serialize IDL type to string
  String _serializeIdlType(IdlType type) {
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
      case 'u128':
      case 'i128':
      case 'f32':
      case 'f64':
      case 'bytes':
      case 'string':
      case 'publicKey':
        return type.kind;
      case 'array':
        if (type.inner != null) {
          return 'array<${_serializeIdlType(type.inner!)}>';
        }
        return 'array';
      case 'vec':
        if (type.inner != null) {
          return 'vec<${_serializeIdlType(type.inner!)}>';
        }
        return 'vec';
      case 'option':
        if (type.inner != null) {
          return 'option<${_serializeIdlType(type.inner!)}>';
        }
        return 'option';
      case 'defined':
        return type.defined ?? 'unknown';
      default:
        return type.kind;
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
