/// IDE Integration and Developer Experience
///
/// This module provides comprehensive code generation and IDE integration
/// capabilities for the Dart Coral XYZ SDK, matching TypeScript's developer
/// experience with IntelliSense, debugging, and development tools.

import '../idl/idl.dart';

/// Configuration for code generation
class CodeGenerationConfig {
  /// Output directory for generated files
  final String outputDirectory;

  /// Package name for generated code
  final String packageName;

  /// Whether to generate TypeScript-style interfaces
  final bool generateInterfaces;

  /// Whether to generate method builders
  final bool generateMethodBuilders;

  /// Whether to generate account classes
  final bool generateAccountClasses;

  /// Whether to generate error classes
  final bool generateErrorClasses;

  /// Custom imports to include in generated files
  final List<String> customImports;

  /// Naming convention (camelCase, snake_case, PascalCase)
  final String namingConvention;

  const CodeGenerationConfig({
    this.outputDirectory = 'lib/generated',
    this.packageName = 'generated_anchor',
    this.generateInterfaces = true,
    this.generateMethodBuilders = true,
    this.generateAccountClasses = true,
    this.generateErrorClasses = true,
    this.customImports = const [],
    this.namingConvention = 'camelCase',
  });

  /// Create a development-friendly configuration
  factory CodeGenerationConfig.development() {
    return const CodeGenerationConfig(
      generateInterfaces: true,
      generateMethodBuilders: true,
      generateAccountClasses: true,
      generateErrorClasses: true,
      namingConvention: 'camelCase',
    );
  }

  /// Create a production-optimized configuration
  factory CodeGenerationConfig.production() {
    return const CodeGenerationConfig(
      generateInterfaces: false,
      generateMethodBuilders: true,
      generateAccountClasses: true,
      generateErrorClasses: true,
      namingConvention: 'camelCase',
    );
  }
}

/// Result of code generation operation
class CodeGenerationResult {
  /// Whether the generation was successful
  final bool success;

  /// Generated files with their content
  final Map<String, String> generatedFiles;

  /// Any warnings or messages
  final List<String> warnings;

  /// Any errors that occurred
  final List<String> errors;

  /// Generation statistics
  final CodeGenerationStats stats;

  const CodeGenerationResult({
    required this.success,
    required this.generatedFiles,
    required this.warnings,
    required this.errors,
    required this.stats,
  });

  /// Create a successful result
  factory CodeGenerationResult.success({
    required Map<String, String> generatedFiles,
    List<String> warnings = const [],
    required CodeGenerationStats stats,
  }) {
    return CodeGenerationResult(
      success: true,
      generatedFiles: generatedFiles,
      warnings: warnings,
      errors: const [],
      stats: stats,
    );
  }

  /// Create a failed result
  factory CodeGenerationResult.failure({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, String> generatedFiles = const {},
    CodeGenerationStats? stats,
  }) {
    return CodeGenerationResult(
      success: false,
      generatedFiles: generatedFiles,
      warnings: warnings,
      errors: errors,
      stats: stats ?? CodeGenerationStats.empty(),
    );
  }
}

/// Statistics for code generation
class CodeGenerationStats {
  /// Number of generated files
  final int filesGenerated;

  /// Total lines of code generated
  final int linesGenerated;

  /// Number of interfaces generated
  final int interfacesGenerated;

  /// Number of method builders generated
  final int methodBuildersGenerated;

  /// Number of account classes generated
  final int accountClassesGenerated;

  /// Number of error classes generated
  final int errorClassesGenerated;

  /// Generation time in milliseconds
  final int generationTimeMs;

  const CodeGenerationStats({
    required this.filesGenerated,
    required this.linesGenerated,
    required this.interfacesGenerated,
    required this.methodBuildersGenerated,
    required this.accountClassesGenerated,
    required this.errorClassesGenerated,
    required this.generationTimeMs,
  });

  /// Create empty stats
  factory CodeGenerationStats.empty() {
    return const CodeGenerationStats(
      filesGenerated: 0,
      linesGenerated: 0,
      interfacesGenerated: 0,
      methodBuildersGenerated: 0,
      accountClassesGenerated: 0,
      errorClassesGenerated: 0,
      generationTimeMs: 0,
    );
  }
}

/// Main code generator for IDL-based types and interfaces
class AnchorCodeGenerator {
  final CodeGenerationConfig config;

  const AnchorCodeGenerator(this.config);

  /// Generate code from IDL
  Future<CodeGenerationResult> generateFromIdl(Idl idl) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final generatedFiles = <String, String>{};
    final warnings = <String>[];
    final errors = <String>[];

    try {
      // Generate main program interface
      if (config.generateInterfaces) {
        final interfaceCode = _generateProgramInterface(idl);
        generatedFiles['${config.packageName}_program.dart'] = interfaceCode;
      }

      // Generate account classes
      if (config.generateAccountClasses && idl.accounts?.isNotEmpty == true) {
        final accountCode = _generateAccountClasses(idl);
        generatedFiles['${config.packageName}_accounts.dart'] = accountCode;
      }

      // Generate method builders
      if (config.generateMethodBuilders && idl.instructions.isNotEmpty) {
        final methodCode = _generateMethodBuilders(idl);
        generatedFiles['${config.packageName}_methods.dart'] = methodCode;
      }

      // Generate error classes
      if (config.generateErrorClasses && idl.errors?.isNotEmpty == true) {
        final errorCode = _generateErrorClasses(idl);
        generatedFiles['${config.packageName}_errors.dart'] = errorCode;
      }

      // Generate barrel file
      final barrelCode = _generateBarrelFile(generatedFiles.keys.toList());
      generatedFiles['${config.packageName}.dart'] = barrelCode;

      final endTime = DateTime.now().millisecondsSinceEpoch;
      final stats = CodeGenerationStats(
        filesGenerated: generatedFiles.length,
        linesGenerated: _countLines(generatedFiles.values),
        interfacesGenerated: config.generateInterfaces ? 1 : 0,
        methodBuildersGenerated:
            config.generateMethodBuilders ? idl.instructions.length : 0,
        accountClassesGenerated:
            config.generateAccountClasses ? (idl.accounts?.length ?? 0) : 0,
        errorClassesGenerated:
            config.generateErrorClasses ? (idl.errors?.length ?? 0) : 0,
        generationTimeMs: endTime - startTime,
      );

      return CodeGenerationResult.success(
        generatedFiles: generatedFiles,
        warnings: warnings,
        stats: stats,
      );
    } catch (e) {
      errors.add('Code generation failed: $e');
      return CodeGenerationResult.failure(
        errors: errors,
        warnings: warnings,
      );
    }
  }

  /// Generate TypeScript-style program interface
  String _generateProgramInterface(Idl idl) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from IDL: ${idl.name}');
    buffer.writeln('');

    // Imports
    for (final import in config.customImports) {
      buffer.writeln("import '$import';");
    }
    buffer.writeln("import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';");
    buffer.writeln('');

    // Program interface
    final className = _formatClassName(idl.name ?? 'Unknown');
    buffer.writeln(
        '/// Generated program interface for ${idl.name ?? 'Unknown'}');
    buffer.writeln('abstract class I$className {');

    // Method signatures
    for (final instruction in idl.instructions) {
      final methodName = _formatMethodName(instruction.name);
      buffer.writeln('  /// ${instruction.name} instruction');
      buffer.writeln('  Future<String> $methodName(');

      // Parameters
      if (instruction.args.isNotEmpty) {
        buffer.writeln('    {');
        for (final arg in instruction.args) {
          final paramName = _formatParameterName(arg.name);
          final paramType = _dartTypeFromIdlType(arg.type);
          buffer.writeln('    required $paramType $paramName,');
        }
        buffer.writeln('    }');
      }
      buffer.writeln('  );');
      buffer.writeln('');
    }

    buffer.writeln('}');
    buffer.writeln('');

    // Concrete implementation
    buffer.writeln('/// Concrete implementation of ${idl.name} program');
    buffer.writeln('class $className implements I$className {');
    buffer.writeln('  final Program<Idl> _program;');
    buffer.writeln('');
    buffer.writeln('  const $className(this._program);');
    buffer.writeln('');

    // Method implementations
    for (final instruction in idl.instructions) {
      final methodName = _formatMethodName(instruction.name);
      buffer.writeln('  @override');
      buffer.writeln('  Future<String> $methodName(');

      if (instruction.args.isNotEmpty) {
        buffer.writeln('    {');
        for (final arg in instruction.args) {
          final paramName = _formatParameterName(arg.name);
          final paramType = _dartTypeFromIdlType(arg.type);
          buffer.writeln('    required $paramType $paramName,');
        }
        buffer.writeln('    }');
      }
      buffer.writeln('  ) async {');
      buffer.writeln(
          "    return await _program.methods['${instruction.name}']([");

      // Method arguments
      for (final arg in instruction.args) {
        final paramName = _formatParameterName(arg.name);
        buffer.writeln('      $paramName,');
      }

      buffer.writeln('    ]).rpc();');
      buffer.writeln('  }');
      buffer.writeln('');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate account classes
  String _generateAccountClasses(Idl idl) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated account classes from IDL: ${idl.name}');
    buffer.writeln('');

    // Imports
    buffer.writeln("import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';");
    buffer.writeln('');

    // Generate each account class
    final accounts = idl.accounts ?? [];
    for (final account in accounts) {
      final className = _formatClassName(account.name);
      buffer.writeln('/// Generated account class: ${account.name}');
      buffer.writeln('class $className {');

      // Fields
      final fields = account.type.fields ?? [];
      for (final field in fields) {
        final fieldName = _formatFieldName(field.name);
        final fieldType = _dartTypeFromIdlType(field.type);
        buffer.writeln('  final $fieldType $fieldName;');
      }
      buffer.writeln('');

      // Constructor
      buffer.writeln('  const $className({');
      for (final field in fields) {
        final fieldName = _formatFieldName(field.name);
        buffer.writeln('    required this.$fieldName,');
      }
      buffer.writeln('  });');
      buffer.writeln('');

      // From map constructor
      buffer
          .writeln('  factory $className.fromMap(Map<String, dynamic> map) {');
      buffer.writeln('    return $className(');
      for (final field in fields) {
        final fieldName = _formatFieldName(field.name);
        buffer.writeln("      $fieldName: map['${field.name}'],");
      }
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('');

      // To map method
      buffer.writeln('  Map<String, dynamic> toMap() {');
      buffer.writeln('    return {');
      for (final field in fields) {
        final fieldName = _formatFieldName(field.name);
        buffer.writeln("      '${field.name}': $fieldName,");
      }
      buffer.writeln('    };');
      buffer.writeln('  }');

      buffer.writeln('}');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generate method builders
  String _generateMethodBuilders(Idl idl) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated method builders from IDL: ${idl.name}');
    buffer.writeln('');

    // Imports
    buffer.writeln("import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';");
    buffer.writeln('');

    // Generate method builder class
    final className = _formatClassName('${idl.name}Methods');
    buffer.writeln('/// Generated method builders for ${idl.name}');
    buffer.writeln('class $className {');
    buffer.writeln('  final Program<Idl> _program;');
    buffer.writeln('');
    buffer.writeln('  const $className(this._program);');
    buffer.writeln('');

    // Generate each method
    for (final instruction in idl.instructions) {
      final methodName = _formatMethodName(instruction.name);
      buffer.writeln('  /// Builder for ${instruction.name} instruction');
      buffer.writeln('  TypeSafeMethodBuilder $methodName(');

      if (instruction.args.isNotEmpty) {
        buffer.writeln('    {');
        for (final arg in instruction.args) {
          final paramName = _formatParameterName(arg.name);
          final paramType = _dartTypeFromIdlType(arg.type);
          buffer.writeln('    required $paramType $paramName,');
        }
        buffer.writeln('    }');
      }
      buffer.writeln('  ) {');
      buffer.writeln("    return _program.methods['${instruction.name}']([");

      // Method arguments
      for (final arg in instruction.args) {
        final paramName = _formatParameterName(arg.name);
        buffer.writeln('      $paramName,');
      }

      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln('');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate error classes
  String _generateErrorClasses(Idl idl) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated error classes from IDL: ${idl.name}');
    buffer.writeln('');

    // Imports
    buffer.writeln("import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';");
    buffer.writeln('');

    // Generate each error class
    final errors = idl.errors ?? [];
    for (final error in errors) {
      final className = _formatClassName('${error.name}Error');
      buffer.writeln('/// Generated error class: ${error.name}');
      buffer.writeln('class $className extends AnchorError {');
      buffer.writeln('  const $className()');
      buffer.writeln('      : super(');
      buffer.writeln('          code: ${error.code},');
      buffer.writeln("          message: '${error.msg}',");
      buffer.writeln("          name: '${error.name}',");
      buffer.writeln('        );');
      buffer.writeln('');

      // Factory constructor
      buffer.writeln('  factory $className.fromCode(int code) {');
      buffer.writeln('    if (code == ${error.code}) {');
      buffer.writeln('      return const $className();');
      buffer.writeln('    }');
      buffer.writeln('    throw ArgumentError("Invalid error code: \$code");');
      buffer.writeln('  }');

      buffer.writeln('}');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generate barrel file for all generated modules
  String _generateBarrelFile(List<String> fileNames) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer
        .writeln('// Barrel file for generated ${config.packageName} modules');
    buffer.writeln('');

    // Export all generated files
    for (final fileName in fileNames) {
      if (fileName != '${config.packageName}.dart') {
        buffer.writeln("export '$fileName';");
      }
    }

    return buffer.toString();
  }

  /// Format class name according to naming convention
  /// Class names should always be PascalCase in Dart
  String _formatClassName(String name) {
    return _toPascalCase(name);
  }

  /// Format method name according to naming convention
  String _formatMethodName(String name) {
    switch (config.namingConvention) {
      case 'PascalCase':
        return _toPascalCase(name);
      case 'camelCase':
        return _toCamelCase(name);
      case 'snake_case':
        return _toSnakeCase(name);
      default:
        return _toCamelCase(name);
    }
  }

  /// Format field name according to naming convention
  String _formatFieldName(String name) {
    return _formatMethodName(name); // Same as method name
  }

  /// Format parameter name according to naming convention
  String _formatParameterName(String name) {
    return _formatMethodName(name); // Same as method name
  }

  /// Convert to PascalCase
  String _toPascalCase(String input) {
    // If the input is already in a reasonable PascalCase format, preserve it
    if (RegExp(r'^[A-Z][a-zA-Z0-9]*$').hasMatch(input)) {
      return input;
    }

    // Split by underscores, spaces, or camelCase boundaries
    final words = input
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) =>
                '${match.group(1)}_${match.group(2)}') // Insert underscore before caps
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty);

    return words
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join('');
  }

  /// Convert to camelCase
  String _toCamelCase(String input) {
    final pascalCase = _toPascalCase(input);
    return pascalCase.isNotEmpty
        ? pascalCase[0].toLowerCase() + pascalCase.substring(1)
        : '';
  }

  /// Convert to snake_case
  String _toSnakeCase(String input) {
    return input
        .replaceAll(RegExp(r'[A-Z]'), '_\$0')
        .toLowerCase()
        .replaceAll(RegExp(r'^_'), '');
  }

  /// Convert IDL type to Dart type
  String _dartTypeFromIdlType(dynamic idlType) {
    // Handle IdlType objects
    if (idlType is IdlType) {
      switch (idlType.kind) {
        case 'bool':
          return 'bool';
        case 'u8':
        case 'u16':
        case 'u32':
        case 'i8':
        case 'i16':
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
        case 'string':
          return 'String';
        case 'publicKey':
          return 'PublicKey';
        case 'bytes':
          return 'List<int>';
        case 'vec':
          if (idlType.inner != null) {
            final elementType = _dartTypeFromIdlType(idlType.inner);
            return 'List<$elementType>';
          }
          return 'List<dynamic>';
        case 'array':
          if (idlType.inner != null) {
            final elementType = _dartTypeFromIdlType(idlType.inner);
            return 'List<$elementType>';
          }
          return 'List<dynamic>';
        case 'option':
          if (idlType.inner != null) {
            final innerType = _dartTypeFromIdlType(idlType.inner);
            return '$innerType?';
          }
          return 'dynamic?';
        case 'defined':
          if (idlType.defined != null) {
            return _formatClassName(idlType.defined!);
          }
          return 'dynamic';
        default:
          return 'dynamic';
      }
    }

    // Handle legacy string-based types
    if (idlType is String) {
      switch (idlType) {
        case 'bool':
          return 'bool';
        case 'u8':
        case 'u16':
        case 'u32':
        case 'i8':
        case 'i16':
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
        case 'string':
          return 'String';
        case 'publicKey':
          return 'PublicKey';
        case 'bytes':
          return 'List<int>';
        default:
          return 'dynamic';
      }
    }

    // Handle legacy Map-based types (fallback)
    else if (idlType is Map) {
      if (idlType.containsKey('array')) {
        final elementType = _dartTypeFromIdlType(idlType['array'][0]);
        return 'List<$elementType>';
      } else if (idlType.containsKey('vec')) {
        final elementType = _dartTypeFromIdlType(idlType['vec']);
        return 'List<$elementType>';
      } else if (idlType.containsKey('option')) {
        final innerType = _dartTypeFromIdlType(idlType['option']);
        return '$innerType?';
      } else if (idlType.containsKey('defined')) {
        return _formatClassName(idlType['defined']);
      }
    }
    return 'dynamic';
  }

  /// Count total lines in generated files
  int _countLines(Iterable<String> contents) {
    return contents.fold(
        0, (total, content) => total + content.split('\n').length);
  }
}
