/// IDE Integration and Developer Experience Module
///
/// This module provides comprehensive IDE integration features for the
/// Dart Coral XYZ SDK, including code generation, documentation generation,
/// and debugging utilities.
library;

export 'code_generator.dart';
export 'documentation_generator.dart';
export 'debug_utilities.dart';

import 'dart:io';
import 'package:coral_xyz_anchor/src/ide/code_generator.dart';
import 'package:coral_xyz_anchor/src/ide/documentation_generator.dart';
import 'package:coral_xyz_anchor/src/ide/debug_utilities.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

/// Main IDE integration facade
class AnchorIdeIntegration {

  const AnchorIdeIntegration({
    required this.codeGenerator,
    required this.documentationGenerator,
    required this.debugger,
  });

  /// Create IDE integration with default configurations
  factory AnchorIdeIntegration.defaultConfig({
    String outputDirectory = 'generated',
    String packageName = 'anchor_generated',
  }) {
    final codeConfig = CodeGenerationConfig(
      outputDirectory: outputDirectory,
      packageName: packageName,
    );

    final docConfig = DocumentationConfig.comprehensive();
    final debugConfig = DebugConfig.development();

    return AnchorIdeIntegration(
      codeGenerator: AnchorCodeGenerator(codeConfig),
      documentationGenerator: AnchorDocumentationGenerator(docConfig),
      debugger: AnchorDebugger(debugConfig),
    );
  }

  /// Create IDE integration for production
  factory AnchorIdeIntegration.production({
    String outputDirectory = 'lib/generated',
    String packageName = 'anchor_client',
  }) {
    final codeConfig = CodeGenerationConfig.production();
    final docConfig = DocumentationConfig.minimal();
    final debugConfig = DebugConfig.production();

    return AnchorIdeIntegration(
      codeGenerator: AnchorCodeGenerator(codeConfig),
      documentationGenerator: AnchorDocumentationGenerator(docConfig),
      debugger: AnchorDebugger(debugConfig),
    );
  }
  /// Code generator instance
  final AnchorCodeGenerator codeGenerator;

  /// Documentation generator instance
  final AnchorDocumentationGenerator documentationGenerator;

  /// Debug utilities instance
  final AnchorDebugger debugger;

  /// Generate complete development package from IDL
  Future<DevelopmentPackageResult> generateDevelopmentPackage(
    Idl idl, {
    String? outputPath,
    bool writeFiles = true,
  }) async {
    final results = <String, dynamic>{};
    final warnings = <String>[];
    final errors = <String>[];

    try {
      // Generate code
      debugger.info('Starting code generation');
      final codeResult = await codeGenerator.generateFromIdl(idl);
      results['code'] = codeResult;

      if (!codeResult.success) {
        errors.addAll(codeResult.errors);
      } else {
        warnings.addAll(codeResult.warnings);
        debugger.info('Code generation completed', context: {
          'files': codeResult.generatedFiles.length,
          'lines': codeResult.stats.linesGenerated,
        },);
      }

      // Generate documentation
      debugger.info('Starting documentation generation');
      final docResult = await documentationGenerator.generateFromIdl(idl);
      results['documentation'] = docResult;

      if (!docResult.success) {
        errors.addAll(docResult.errors);
      } else {
        warnings.addAll(docResult.warnings);
        debugger.info('Documentation generation completed', context: {
          'files': docResult.generatedDocs.length,
        },);
      }

      // Analyze IDL for potential issues
      debugger.info('Analyzing IDL');
      final idlIssues = debugger.analyzeIdl(idl);
      if (idlIssues.isNotEmpty) {
        warnings.addAll(idlIssues.map((issue) => 'IDL Issue: $issue'));
      }

      // Write files if requested
      if (writeFiles && outputPath != null) {
        await _writeGeneratedFiles(outputPath, codeResult, docResult);
        debugger.info('Files written to disk', context: {'path': outputPath});
      }

      return DevelopmentPackageResult(
        success: errors.isEmpty,
        codeResult: codeResult,
        documentationResult: docResult,
        warnings: warnings,
        errors: errors,
        debugSession: debugger.currentSession,
      );
    } catch (e) {
      debugger.error('Development package generation failed',
          context: {'error': e.toString()},);
      errors.add('Package generation failed: $e');

      return DevelopmentPackageResult(
        success: false,
        codeResult: CodeGenerationResult.failure(errors: [e.toString()]),
        documentationResult:
            DocumentationResult.failure(errors: [e.toString()]),
        warnings: warnings,
        errors: errors,
        debugSession: debugger.currentSession,
      );
    }
  }

  /// Generate TypeScript-compatible API reference
  Future<String> generateApiReference(Idl idl) async {
    debugger.info('Generating API reference');

    final buffer = StringBuffer();

    // Header
    buffer.writeln('# ${idl.name ?? 'Anchor Program'} API Reference');
    buffer.writeln();
    buffer.writeln(
        'This document provides a complete API reference for the ${idl.name ?? 'Anchor program'}.',);
    buffer.writeln();

    // Program interface
    buffer.writeln('## Program Interface');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln('final program = Program<Idl>(idl, provider: provider);');
    buffer.writeln('```');
    buffer.writeln();

    // Methods
    if (idl.instructions.isNotEmpty) {
      buffer.writeln('## Methods');
      buffer.writeln();

      for (final instruction in idl.instructions) {
        buffer.writeln('### `${instruction.name}()`');
        buffer.writeln();

        if (instruction.docs?.isNotEmpty == true) {
          buffer.writeln(instruction.docs!.join(' '));
          buffer.writeln();
        }

        // TypeScript-style usage example
        buffer.writeln('**Usage:**');
        buffer.writeln();
        buffer.writeln('```dart');
        buffer.write('await program.methods.${instruction.name}(');
        if (instruction.args.isNotEmpty) {
          buffer.writeln('[');
          for (final arg in instruction.args) {
            final exampleValue = _getExampleValue(arg.type);
            buffer.writeln('  $exampleValue, // ${arg.name}');
          }
          buffer.writeln(']');
        }
        buffer.writeln(').rpc();');
        buffer.writeln('```');
        buffer.writeln();

        // Fluent API example
        if (instruction.accounts.isNotEmpty) {
          buffer.writeln('**With account specification:**');
          buffer.writeln();
          buffer.writeln('```dart');
          buffer.write('await program.methods.${instruction.name}(');
          if (instruction.args.isNotEmpty) {
            buffer.write('[/* args */]');
          }
          buffer.writeln(')');
          buffer.writeln('  .accounts({');
          for (final account in instruction.accounts) {
            buffer.writeln('    ${account.name}: accountPublicKey,');
          }
          buffer.writeln('  })');
          buffer.writeln('  .rpc();');
          buffer.writeln('```');
          buffer.writeln();
        }
      }
    }

    // Account fetching
    final accounts = idl.accounts ?? [];
    if (accounts.isNotEmpty) {
      buffer.writeln('## Account Fetching');
      buffer.writeln();

      for (final account in accounts) {
        buffer.writeln('### `${account.name}`');
        buffer.writeln();

        buffer.writeln('**Fetch single account:**');
        buffer.writeln();
        buffer.writeln('```dart');
        buffer.writeln(
            'final accountData = await program.account.${account.name}.fetch(accountAddress);',);
        buffer.writeln('```');
        buffer.writeln();

        buffer.writeln('**Fetch multiple accounts:**');
        buffer.writeln();
        buffer.writeln('```dart');
        buffer.writeln(
            'final accounts = await program.account.${account.name}.all();',);
        buffer.writeln('```');
        buffer.writeln();
      }
    }

    debugger.info('API reference generated');
    return buffer.toString();
  }

  /// Create development workspace structure
  Future<void> createWorkspaceStructure(
      String projectPath, String projectName,) async {
    debugger.info('Creating workspace structure',
        context: {'path': projectPath, 'name': projectName},);

    final projectDir = Directory(projectPath);
    if (!projectDir.existsSync()) {
      projectDir.createSync(recursive: true);
    }

    // Create directory structure
    final directories = [
      'lib',
      'lib/src',
      'lib/generated',
      'test',
      'docs',
      'example',
    ];

    for (final dir in directories) {
      final dirPath = Directory('$projectPath/$dir');
      if (!dirPath.existsSync()) {
        dirPath.createSync(recursive: true);
      }
    }

    // Create pubspec.yaml
    final pubspecContent = '''
name: $projectName
description: Generated Anchor client for $projectName
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  coral_xyz_anchor: ^1.0.0

dev_dependencies:
  test: ^1.24.0
''';

    await File('$projectPath/pubspec.yaml').writeAsString(pubspecContent);

    // Create main library file
    final libContent = '''
/// $projectName Anchor Client
/// 
/// Generated client library for $projectName Anchor program
library $projectName;

// Export generated code
export 'generated/anchor_generated.dart';
''';

    await File('$projectPath/lib/$projectName.dart').writeAsString(libContent);

    // Create README
    final readmeContent = '''
# $projectName

Generated Anchor client for $projectName program.

## Usage

```dart
import 'package:$projectName/$projectName.dart';

// Initialize program
final program = Program<Idl>(idl, provider: provider);

// Use generated methods
await program.methods.initialize().rpc();
```

## Generated Files

- `lib/generated/` - Generated client code
- `docs/` - API documentation
- `test/` - Generated tests

## Development

Run `dart pub get` to install dependencies.
''';

    await File('$projectPath/README.md').writeAsString(readmeContent);

    debugger.info('Workspace structure created successfully');
  }

  /// Write generated files to disk
  Future<void> _writeGeneratedFiles(
    String outputPath,
    CodeGenerationResult codeResult,
    DocumentationResult docResult,
  ) async {
    final outputDir = Directory(outputPath);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write code files
    for (final entry in codeResult.generatedFiles.entries) {
      final filePath = '$outputPath/${entry.key}';
      await File(filePath).writeAsString(entry.value);
    }

    // Write documentation files
    final docsDir = Directory('$outputPath/docs');
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }

    for (final entry in docResult.generatedDocs.entries) {
      final filePath = '$outputPath/docs/${entry.key}';
      await File(filePath).writeAsString(entry.value);
    }
  }

  /// Get example value for IDL type
  String _getExampleValue(dynamic type) {
    if (type is String) {
      switch (type) {
        case 'bool':
          return 'true';
        case 'u8':
        case 'u16':
        case 'u32':
        case 'i8':
        case 'i16':
        case 'i32':
          return '42';
        case 'u64':
        case 'i64':
        case 'u128':
        case 'i128':
          return 'BigInt.from(42)';
        case 'f32':
        case 'f64':
          return '3.14';
        case 'string':
          return '"example"';
        case 'publicKey':
          return 'PublicKey.fromBase58("...")';
        case 'bytes':
          return '[1, 2, 3]';
        default:
          return 'value';
      }
    }
    return 'value';
  }
}

/// Result of development package generation
class DevelopmentPackageResult {

  const DevelopmentPackageResult({
    required this.success,
    required this.codeResult,
    required this.documentationResult,
    required this.warnings,
    required this.errors,
    this.debugSession,
  });
  /// Whether generation was successful
  final bool success;

  /// Code generation result
  final CodeGenerationResult codeResult;

  /// Documentation generation result
  final DocumentationResult documentationResult;

  /// Warnings from generation process
  final List<String> warnings;

  /// Errors from generation process
  final List<String> errors;

  /// Debug session used during generation
  final DebugSession? debugSession;

  /// Generate summary report
  String generateSummary() {
    final buffer = StringBuffer();

    buffer.writeln('# Development Package Generation Summary');
    buffer.writeln();
    buffer.writeln('**Status:** ${success ? "SUCCESS" : "FAILED"}');
    buffer.writeln();

    // Code generation
    buffer.writeln('## Code Generation');
    if (codeResult.success) {
      buffer.writeln('✅ **Success**');
      buffer.writeln('- Files generated: ${codeResult.generatedFiles.length}');
      buffer.writeln('- Lines of code: ${codeResult.stats.linesGenerated}');
      buffer.writeln('- Interfaces: ${codeResult.stats.interfacesGenerated}');
      buffer.writeln(
          '- Method builders: ${codeResult.stats.methodBuildersGenerated}',);
      buffer.writeln(
          '- Account classes: ${codeResult.stats.accountClassesGenerated}',);
      buffer.writeln(
          '- Error classes: ${codeResult.stats.errorClassesGenerated}',);
    } else {
      buffer.writeln('❌ **Failed**');
      for (final error in codeResult.errors) {
        buffer.writeln('- $error');
      }
    }
    buffer.writeln();

    // Documentation generation
    buffer.writeln('## Documentation Generation');
    if (documentationResult.success) {
      buffer.writeln('✅ **Success**');
      buffer.writeln(
          '- Documentation files: ${documentationResult.generatedDocs.length}',);
    } else {
      buffer.writeln('❌ **Failed**');
      for (final error in documentationResult.errors) {
        buffer.writeln('- $error');
      }
    }
    buffer.writeln();

    // Warnings
    if (warnings.isNotEmpty) {
      buffer.writeln('## Warnings');
      for (final warning in warnings) {
        buffer.writeln('⚠️ $warning');
      }
      buffer.writeln();
    }

    // Errors
    if (errors.isNotEmpty) {
      buffer.writeln('## Errors');
      for (final error in errors) {
        buffer.writeln('❌ $error');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
