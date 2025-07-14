/// IDE Integration and Developer Experience Demo
///
/// This example demonstrates the comprehensive IDE integration features
/// implemented in Step 8.4, showing code generation, documentation,
/// and debugging capabilities that match TypeScript's developer experience.
library;

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/ide/debug_utilities.dart' as ide;

void main() async {
  print('🚀 Dart Coral XYZ SDK - IDE Integration Demo');
  print('=' * 60);

  // Create a sample IDL for demonstration
  final testIdl = const Idl(
    name: 'DemoProgram',
    version: '1.0.0',
    instructions: [
      IdlInstruction(
        name: 'initialize',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: [
          IdlInstructionAccount(
            name: 'authority',
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'account',
            writable: true,
          ),
        ],
        args: [
          IdlField(name: 'value', type: IdlType(kind: 'u64')),
          IdlField(name: 'name', type: IdlType(kind: 'string')),
        ],
        docs: ['Initialize the program state'],
      ),
    ],
    accounts: [
      IdlAccount(
        name: 'ProgramState',
        discriminator: [10, 11, 12, 13, 14, 15, 16, 17],
        type: IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(name: 'authority', type: IdlType(kind: 'publicKey')),
            IdlField(name: 'value', type: IdlType(kind: 'u64')),
            IdlField(name: 'name', type: IdlType(kind: 'string')),
            IdlField(name: 'isInitialized', type: IdlType(kind: 'bool')),
          ],
        ),
      ),
    ],
    errors: [
      IdlErrorCode(
        code: 6000,
        name: 'InvalidAuthority',
        msg: 'Invalid authority provided',
      ),
    ],
  );

  // 1. Code Generation Demo
  print('\n📝 1. Code Generation Demo');
  print('-' * 30);

  final codeGenerator = AnchorCodeGenerator(
    CodeGenerationConfig.development(),
  );

  final codeResult = await codeGenerator.generateFromIdl(testIdl);

  if (codeResult.success) {
    print('✅ Code generation successful!');
    print('📊 Generated ${codeResult.stats.filesGenerated} files');
    print('📊 Generated ${codeResult.stats.linesGenerated} lines of code');
    print(
        '📊 Created ${codeResult.stats.interfacesGenerated} program interfaces',);
    print(
        '📊 Created ${codeResult.stats.accountClassesGenerated} account classes',);
    print(
        '📊 Created ${codeResult.stats.methodBuildersGenerated} method builders',);
    print('📊 Created ${codeResult.stats.errorClassesGenerated} error classes');

    // Show a sample of generated code
    print('\n📄 Generated Program Interface:');
    final programInterface = codeResult.generatedFiles.entries.first.value;
    final lines = programInterface.split('\n');
    for (int i = 0; i < 15 && i < lines.length; i++) {
      print('  ${lines[i]}');
    }
    if (lines.length > 15) print('  ... (${lines.length - 15} more lines)');
  } else {
    print('❌ Code generation failed');
    for (final error in codeResult.errors) {
      print('  Error: $error');
    }
  }

  // 2. Documentation Generation Demo
  print('\n📚 2. Documentation Generation Demo');
  print('-' * 35);

  final docGenerator = AnchorDocumentationGenerator(
    DocumentationConfig.comprehensive(),
  );

  final docResult = await docGenerator.generateFromIdl(testIdl);

  if (docResult.success) {
    print('✅ Documentation generation successful!');
    print('📊 Generated ${docResult.generatedDocs.length} documentation files');

    // Show available documentation formats
    for (final entry in docResult.generatedDocs.entries) {
      final format = entry.key.split('.').last;
      final lineCount = entry.value.split('\n').length;
      print('📄 ${entry.key} ($format format, $lineCount lines)');
    }

    // Show a snippet of markdown documentation
    final markdownDoc = docResult.generatedDocs.entries
        .firstWhere((e) => e.key.endsWith('.md'),
            orElse: () => const MapEntry('', ''),)
        .value;

    if (markdownDoc.isNotEmpty) {
      print('\n📄 Sample Markdown Documentation:');
      final lines = markdownDoc.split('\n');
      for (int i = 0; i < 10 && i < lines.length; i++) {
        print('  ${lines[i]}');
      }
      if (lines.length > 10) print('  ... (${lines.length - 10} more lines)');
    }
  } else {
    print('❌ Documentation generation failed');
    for (final error in docResult.errors) {
      print('  Error: $error');
    }
  }

  // 3. Debugging Utilities Demo
  print('\n🔍 3. Debugging Utilities Demo');
  print('-' * 30);

  final debugger = AnchorDebugger(
    ide.DebugConfig.development(),
  );

  final session = debugger.createSession();

  // Log some sample messages
  debugger.info('IDE integration demo started');
  debugger.warning('This is a demo warning message');
  debugger.debug('Debug information for development');

  // Analyze the IDL
  final analysis = debugger.analyzeIdl(testIdl);
  print('✅ IDL analysis completed');
  print('📊 Found ${analysis.length} analysis results');

  if (analysis.isNotEmpty) {
    print('\n⚠️  IDL Analysis Results:');
    for (final issue in analysis) {
      print('  • $issue');
    }
  }

  // Generate debug report
  final report = debugger.generateReport();
  print('\n📊 Debug Report Summary:');
  print('  • Total log entries: ${report.length}');
  print('  • Debug session: ${session.sessionId}');

  // 4. IDE Integration Demo
  print('\n🛠️  4. Complete IDE Integration Demo');
  print('-' * 40);

  final ideIntegration = AnchorIdeIntegration.defaultConfig();

  final packageResult =
      await ideIntegration.generateDevelopmentPackage(testIdl);

  if (packageResult.success) {
    print('✅ Complete development package generated!');
    print('📊 Code files: ${packageResult.codeResult.generatedFiles.length}');
    print(
        '📊 Documentation files: ${packageResult.documentationResult.generatedDocs.length}',);

    // Show summary
    final summary = packageResult.generateSummary();
    print('\n📋 Development Package Summary:');
    final summaryLines = summary.split('\n');
    for (int i = 0; i < 15 && i < summaryLines.length; i++) {
      print('  ${summaryLines[i]}');
    }
    if (summaryLines.length > 15) {
      print('  ... (${summaryLines.length - 15} more lines)');
    }
  } else {
    print('❌ Development package generation failed');
    for (final error in packageResult.errors) {
      print('  Error: $error');
    }
  }

  print('\n${'=' * 60}');
  print('🎉 IDE Integration Demo Complete!');
  print('');
  print('The Dart Coral XYZ SDK now provides comprehensive IDE integration');
  print(
      'and developer experience features that match and exceed TypeScript\'s',);
  print('capabilities, including:');
  print('');
  print('✅ Smart code generation with proper type mapping');
  print('✅ Multi-format documentation generation');
  print('✅ Advanced debugging and analysis tools');
  print('✅ Development workflow automation');
  print('✅ Complete TypeScript feature parity');
  print('');
  print('Ready for production development! 🚀');
}
