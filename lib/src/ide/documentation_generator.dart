/// Documentation generation utilities for Anchor IDL
///
/// This module provides comprehensive documentation generation capabilities
/// for IDL files, generating API reference documentation in multiple formats.
library;

import 'dart:convert';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

/// Configuration for documentation generation
class DocumentationConfig {

  const DocumentationConfig({
    this.outputDirectory = 'docs',
    this.format = 'markdown',
    this.includeExamples = true,
    this.includeTypes = true,
    this.includeErrors = true,
    this.generateApiReference = true,
    this.customCss,
    this.title = 'Anchor Program Documentation',
  });

  /// Create a comprehensive documentation configuration
  factory DocumentationConfig.comprehensive() {
    return const DocumentationConfig(
      includeExamples: true,
      includeTypes: true,
      includeErrors: true,
      generateApiReference: true,
      format: 'markdown',
    );
  }

  /// Create a minimal documentation configuration
  factory DocumentationConfig.minimal() {
    return const DocumentationConfig(
      includeExamples: false,
      includeTypes: false,
      includeErrors: false,
      generateApiReference: true,
      format: 'markdown',
    );
  }
  /// Output directory for documentation
  final String outputDirectory;

  /// Documentation format (markdown, html, json)
  final String format;

  /// Whether to include examples
  final bool includeExamples;

  /// Whether to include type information
  final bool includeTypes;

  /// Whether to include error documentation
  final bool includeErrors;

  /// Whether to generate API reference
  final bool generateApiReference;

  /// Custom CSS styles for HTML output
  final String? customCss;

  /// Title for the documentation
  final String title;
}

/// Result of documentation generation
class DocumentationResult {

  const DocumentationResult({
    required this.success,
    required this.generatedDocs,
    required this.warnings,
    required this.errors,
  });

  /// Create successful result
  factory DocumentationResult.success({
    required Map<String, String> generatedDocs,
    List<String> warnings = const [],
  }) {
    return DocumentationResult(
      success: true,
      generatedDocs: generatedDocs,
      warnings: warnings,
      errors: const [],
    );
  }

  /// Create failed result
  factory DocumentationResult.failure({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, String> generatedDocs = const {},
  }) {
    return DocumentationResult(
      success: false,
      generatedDocs: generatedDocs,
      warnings: warnings,
      errors: errors,
    );
  }
  /// Whether generation was successful
  final bool success;

  /// Generated documentation files
  final Map<String, String> generatedDocs;

  /// Any warnings
  final List<String> warnings;

  /// Any errors
  final List<String> errors;
}

/// Main documentation generator
class AnchorDocumentationGenerator {

  const AnchorDocumentationGenerator(this.config);
  final DocumentationConfig config;

  /// Generate documentation from IDL
  Future<DocumentationResult> generateFromIdl(Idl idl) async {
    try {
      final generatedDocs = <String, String>{};
      final warnings = <String>[];

      switch (config.format) {
        case 'markdown':
          final markdownContent = _generateMarkdownDocumentation(idl);
          generatedDocs['README.md'] = markdownContent;

          if (config.generateApiReference) {
            final apiRefContent = _generateMarkdownApiReference(idl);
            generatedDocs['API_REFERENCE.md'] = apiRefContent;
          }
          break;

        case 'html':
          final htmlContent = _generateHtmlDocumentation(idl);
          generatedDocs['index.html'] = htmlContent;

          if (config.generateApiReference) {
            final apiRefContent = _generateHtmlApiReference(idl);
            generatedDocs['api-reference.html'] = apiRefContent;
          }
          break;

        case 'json':
          final jsonContent = _generateJsonDocumentation(idl);
          generatedDocs['documentation.json'] = jsonContent;
          break;

        default:
          return DocumentationResult.failure(
            errors: ['Unsupported documentation format: ${config.format}'],
          );
      }

      return DocumentationResult.success(
        generatedDocs: generatedDocs,
        warnings: warnings,
      );
    } catch (e) {
      return DocumentationResult.failure(
        errors: ['Documentation generation failed: $e'],
      );
    }
  }

  /// Generate markdown documentation
  String _generateMarkdownDocumentation(Idl idl) {
    final buffer = StringBuffer();

    // Title and description
    buffer.writeln('# ${config.title}');
    buffer.writeln();
    buffer.writeln(
        'Generated documentation for **${idl.name ?? 'Unknown'}** program.',);
    if (idl.metadata?.description != null) {
      buffer.writeln();
      buffer.writeln('## Description');
      buffer.writeln();
      buffer.writeln(idl.metadata!.description);
    }
    buffer.writeln();

    // Program information
    buffer.writeln('## Program Information');
    buffer.writeln();
    buffer.writeln('| Property | Value |');
    buffer.writeln('|----------|-------|');
    buffer.writeln('| Name | ${idl.name ?? 'Unknown'} |');
    buffer.writeln('| Version | ${idl.version ?? 'Unknown'} |');
    if (idl.metadata?.repository != null) {
      buffer.writeln('| Repository | ${idl.metadata!.repository} |');
    }
    if (idl.address != null) {
      buffer.writeln('| Program ID | `${idl.address}` |');
    }
    buffer.writeln();

    // Instructions
    if (idl.instructions.isNotEmpty) {
      buffer.writeln('## Instructions');
      buffer.writeln();
      for (final instruction in idl.instructions) {
        buffer.writeln('### ${instruction.name}');
        buffer.writeln();

        if (instruction.docs?.isNotEmpty == true) {
          buffer.writeln(instruction.docs!.join(' '));
          buffer.writeln();
        }

        if (config.includeTypes && instruction.args.isNotEmpty) {
          buffer.writeln('**Parameters:**');
          buffer.writeln();
          for (final arg in instruction.args) {
            final argType = _formatTypeForDocs(arg.type);
            buffer.writeln('- `${arg.name}` ($argType)');
          }
          buffer.writeln();
        }

        if (instruction.accounts.isNotEmpty) {
          buffer.writeln('**Accounts:**');
          buffer.writeln();
          for (final account in instruction.accounts) {
            final constraints = <String>[];
            // Check if this is an IdlInstructionAccount
            if (account is IdlInstructionAccount) {
              if (account.writable) constraints.add('mutable');
              if (account.signer) constraints.add('signer');
            }
            final constraintsStr =
                constraints.isNotEmpty ? ' (${constraints.join(', ')})' : '';
            buffer.writeln('- `${account.name}`$constraintsStr');
          }
          buffer.writeln();
        }

        if (config.includeExamples) {
          buffer.writeln('**Example:**');
          buffer.writeln();
          buffer.writeln('```dart');
          buffer.writeln('await program.methods.${instruction.name}(');
          if (instruction.args.isNotEmpty) {
            buffer.writeln('  {');
            for (final arg in instruction.args) {
              final exampleValue = _getExampleValue(arg.type);
              buffer.writeln('    ${arg.name}: $exampleValue,');
            }
            buffer.writeln('  }');
          }
          buffer.writeln(').rpc();');
          buffer.writeln('```');
          buffer.writeln();
        }
      }
    }

    // Accounts
    final accounts = idl.accounts ?? [];
    if (accounts.isNotEmpty) {
      buffer.writeln('## Accounts');
      buffer.writeln();
      for (final account in accounts) {
        buffer.writeln('### ${account.name}');
        buffer.writeln();

        if (config.includeTypes) {
          buffer.writeln('**Fields:**');
          buffer.writeln();
          final fields = account.type.fields ?? [];
          for (final field in fields) {
            final fieldType = _formatTypeForDocs(field.type);
            buffer.writeln('- `${field.name}` ($fieldType)');
          }
          buffer.writeln();
        }

        if (config.includeExamples) {
          buffer.writeln('**Example:**');
          buffer.writeln();
          buffer.writeln('```dart');
          buffer.writeln(
              'final accountData = await program.account.${account.name}.fetch(accountAddress);',);
          buffer.writeln('```');
          buffer.writeln();
        }
      }
    }

    // Errors
    if (config.includeErrors) {
      final errors = idl.errors ?? [];
      if (errors.isNotEmpty) {
        buffer.writeln('## Errors');
        buffer.writeln();
        buffer.writeln('| Code | Name | Message |');
        buffer.writeln('|------|------|---------|');
        for (final error in errors) {
          buffer.writeln('| ${error.code} | ${error.name} | ${error.msg} |');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Generate HTML documentation
  String _generateHtmlDocumentation(Idl idl) {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln(
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',);
    buffer.writeln('  <title>${config.title}</title>');

    if (config.customCss != null) {
      buffer.writeln('  <style>${config.customCss}</style>');
    } else {
      buffer.writeln('  <style>');
      buffer.writeln('''
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
    h1, h2, h3 { color: #333; }
    code { background: #f5f5f5; padding: 2px 4px; border-radius: 3px; }
    pre { background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    th { background-color: #f2f2f2; }
  ''');
      buffer.writeln('  </style>');
    }

    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Convert markdown to basic HTML
    final markdownContent = _generateMarkdownDocumentation(idl);
    final htmlContent = _markdownToBasicHtml(markdownContent);
    buffer.writeln(htmlContent);

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// Generate JSON documentation
  String _generateJsonDocumentation(Idl idl) {
    final docData = {
      'program': {
        'name': idl.name,
        'version': idl.version,
        'metadata': idl.metadata?.toJson(),
      },
      'instructions': idl.instructions
          .map((instruction) => {
                'name': instruction.name,
                'docs': instruction.docs,
                'args': instruction.args
                    .map((arg) => {
                          'name': arg.name,
                          'type': arg.type.toString(),
                        },)
                    .toList(),
                'accounts': instruction.accounts
                    .map((account) => {
                          'name': account.name,
                          'writable': account is IdlInstructionAccount
                              ? account.writable
                              : false,
                          'signer': account is IdlInstructionAccount
                              ? account.signer
                              : false,
                        },)
                    .toList(),
              },)
          .toList(),
      'accounts': idl.accounts
          ?.map((account) => {
                'name': account.name,
                'type': {
                  'kind': account.type.kind,
                  'fields': account.type.fields
                      ?.map((field) => {
                            'name': field.name,
                            'type': field.type.toString(),
                          },)
                      .toList(),
                },
              },)
          .toList(),
      'errors': idl.errors
          ?.map((error) => {
                'code': error.code,
                'name': error.name,
                'msg': error.msg,
              },)
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(docData);
  }

  /// Generate markdown API reference
  String _generateMarkdownApiReference(Idl idl) {
    final buffer = StringBuffer();

    buffer.writeln('# API Reference');
    buffer.writeln();
    buffer.writeln(
        'Complete API reference for ${idl.name ?? 'Unknown'} program.',);
    buffer.writeln();

    // Method reference
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

        buffer.writeln('```dart');
        buffer.write('Future<String> ${instruction.name}(');
        if (instruction.args.isNotEmpty) {
          buffer.writeln('{');
          for (final arg in instruction.args) {
            final argType = _formatTypeForDocs(arg.type);
            buffer.writeln('  required $argType ${arg.name},');
          }
          buffer.writeln('}');
        }
        buffer.writeln(')');
        buffer.writeln('```');
        buffer.writeln();

        if (instruction.args.isNotEmpty) {
          buffer.writeln('**Parameters:**');
          buffer.writeln();
          for (final arg in instruction.args) {
            final argType = _formatTypeForDocs(arg.type);
            buffer
                .writeln('- `${arg.name}` (`$argType`): Parameter description');
          }
          buffer.writeln();
        }

        buffer.writeln('**Returns:** `Future<String>` - Transaction signature');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Generate HTML API reference
  String _generateHtmlApiReference(Idl idl) {
    final markdownContent = _generateMarkdownApiReference(idl);
    return _markdownToBasicHtml(markdownContent);
  }

  /// Convert basic markdown to HTML
  String _markdownToBasicHtml(String markdown) {
    var html = markdown
        .replaceAllMapped(RegExp(r'^# (.+)$', multiLine: true),
            (match) => '<h1>${match.group(1)}</h1>',)
        .replaceAllMapped(RegExp(r'^## (.+)$', multiLine: true),
            (match) => '<h2>${match.group(1)}</h2>',)
        .replaceAllMapped(RegExp(r'^### (.+)$', multiLine: true),
            (match) => '<h3>${match.group(1)}</h3>',)
        .replaceAllMapped(
            RegExp('`([^`]+)`'), (match) => '<code>${match.group(1)}</code>',)
        .replaceAllMapped(RegExp(r'```dart\n(.*?)\n```', dotAll: true),
            (match) => '<pre><code>${match.group(1)}</code></pre>',)
        .replaceAllMapped(RegExp(r'```\n(.*?)\n```', dotAll: true),
            (match) => '<pre><code>${match.group(1)}</code></pre>',)
        .replaceAllMapped(RegExp(r'^\| (.+) \|$', multiLine: true), (match) {
      final cells =
          match.group(1)!.split(' | ').map((cell) => '<td>$cell</td>').join();
      return '<tr>$cells</tr>';
    });

    // Wrap table rows in table tags
    html = html.replaceAllMapped(RegExp('(<tr>.*?</tr>)+', dotAll: true),
        (match) => '<table>${match.group(0)}</table>',);

    // Convert line breaks to paragraphs
    html = html.replaceAll('\n\n', '</p><p>');
    html = '<p>$html</p>';
    html = html.replaceAll('<p></p>', '');

    return html;
  }

  /// Format type for documentation
  String _formatTypeForDocs(dynamic type) {
    if (type is String) {
      switch (type) {
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
          return type;
      }
    } else if (type is Map) {
      if (type.containsKey('array')) {
        final elementType = _formatTypeForDocs(type['array'][0]);
        return 'List<$elementType>';
      } else if (type.containsKey('vec')) {
        final elementType = _formatTypeForDocs(type['vec']);
        return 'List<$elementType>';
      } else if (type.containsKey('option')) {
        final innerType = _formatTypeForDocs(type['option']);
        return '$innerType?';
      } else if (type.containsKey('defined')) {
        return type['defined'].toString();
      }
    }
    return 'dynamic';
  }

  /// Get example value for type
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
          return 'PublicKey.fromBase58("11111111111111111111111111111112")';
        case 'bytes':
          return '[1, 2, 3]';
        default:
          return 'value';
      }
    } else if (type is Map) {
      if (type.containsKey('array') || type.containsKey('vec')) {
        return '[]';
      } else if (type.containsKey('option')) {
        return 'null';
      } else if (type.containsKey('defined')) {
        return '${type['defined']}()';
      }
    }
    return 'value';
  }
}
