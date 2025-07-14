import 'package:test/test.dart';
import 'dart:convert';
import 'package:coral_xyz_anchor/src/ide/ide.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

void main() {
  group('Step 8.4: IDE Integration and Developer Experience Tests', () {
    late Idl testIdl;
    late AnchorIdeIntegration ideIntegration;

    setUp(() {
      // Create a simple test IDL
      testIdl = const Idl(
        name: 'TestProgram',
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
          IdlInstruction(
            name: 'update',
            discriminator: [2, 3, 4, 5, 6, 7, 8, 9],
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
              IdlField(name: 'newValue', type: IdlType(kind: 'u64')),
            ],
            docs: ['Update the program state'],
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
          IdlErrorCode(
            code: 6001,
            name: 'AlreadyInitialized',
            msg: 'Program state is already initialized',
          ),
        ],
        metadata: IdlMetadata(
          name: 'TestProgram',
          version: '1.0.0',
          spec: '0.1.0',
          description: 'A test program for IDE integration',
          repository: 'https://github.com/test/test-program',
        ),
      );

      ideIntegration = AnchorIdeIntegration.defaultConfig(
        packageName: 'test_program',
      );
    });

    group('AnchorCodeGenerator', () {
      test('should generate code successfully', () async {
        final result =
            await ideIntegration.codeGenerator.generateFromIdl(testIdl);

        expect(result.success, isTrue);
        expect(result.generatedFiles, isNotEmpty);
        expect(result.errors, isEmpty);

        // Check generated files
        expect(
            result.generatedFiles.keys, contains('test_program_program.dart'),);
        expect(
            result.generatedFiles.keys, contains('test_program_accounts.dart'),);
        expect(
            result.generatedFiles.keys, contains('test_program_methods.dart'),);
        expect(
            result.generatedFiles.keys, contains('test_program_errors.dart'),);
        expect(result.generatedFiles.keys, contains('test_program.dart'));

        // Check statistics
        expect(result.stats.filesGenerated, equals(5));
        expect(result.stats.linesGenerated, greaterThan(0));
        expect(result.stats.interfacesGenerated, equals(1));
        expect(result.stats.methodBuildersGenerated, equals(2));
        expect(result.stats.accountClassesGenerated, equals(1));
        expect(result.stats.errorClassesGenerated, equals(2));
      });

      test('should generate program interface correctly', () async {
        final result =
            await ideIntegration.codeGenerator.generateFromIdl(testIdl);
        final programCode = result.generatedFiles['test_program_program.dart'];

        expect(programCode, isNotNull);
        expect(programCode, contains('abstract class ITestProgram'));
        expect(
            programCode, contains('class TestProgram implements ITestProgram'),);
        expect(programCode, contains('Future<String> initialize('));
        expect(programCode, contains('Future<String> update('));
        expect(programCode, contains('required BigInt value'));
        expect(programCode, contains('required String name'));
      });

      test('should generate account classes correctly', () async {
        final result =
            await ideIntegration.codeGenerator.generateFromIdl(testIdl);
        final accountCode = result.generatedFiles['test_program_accounts.dart'];

        expect(accountCode, isNotNull);
        expect(accountCode, contains('class ProgramState {'));
        expect(accountCode, contains('final PublicKey authority;'));
        expect(accountCode, contains('final BigInt value;'));
        expect(accountCode, contains('final String name;'));
        expect(accountCode, contains('final bool isInitialized;'));
        expect(accountCode, contains('factory ProgramState.fromMap'));
        expect(accountCode, contains('Map<String, dynamic> toMap()'));
      });

      test('should generate method builders correctly', () async {
        final result =
            await ideIntegration.codeGenerator.generateFromIdl(testIdl);
        final methodCode = result.generatedFiles['test_program_methods.dart'];

        expect(methodCode, isNotNull);
        expect(methodCode, contains('class TestProgramMethods {'));
        expect(methodCode, contains('TypeSafeMethodBuilder initialize('));
        expect(methodCode, contains('TypeSafeMethodBuilder update('));
        expect(methodCode, contains('required BigInt value'));
        expect(methodCode, contains('required String name'));
      });

      test('should generate error classes correctly', () async {
        final result =
            await ideIntegration.codeGenerator.generateFromIdl(testIdl);
        final errorCode = result.generatedFiles['test_program_errors.dart'];

        expect(errorCode, isNotNull);
        expect(errorCode,
            contains('class InvalidAuthorityError extends AnchorError'),);
        expect(errorCode,
            contains('class AlreadyInitializedError extends AnchorError'),);
        expect(errorCode, contains('code: 6000'));
        expect(errorCode, contains('code: 6001'));
        expect(errorCode, contains('Invalid authority provided'));
        expect(errorCode, contains('Program state is already initialized'));
      });

      test('should generate barrel file correctly', () async {
        final result =
            await ideIntegration.codeGenerator.generateFromIdl(testIdl);
        final barrelCode = result.generatedFiles['test_program.dart'];

        expect(barrelCode, isNotNull);
        expect(barrelCode, contains('export \'test_program_program.dart\';'));
        expect(barrelCode, contains('export \'test_program_accounts.dart\';'));
        expect(barrelCode, contains('export \'test_program_methods.dart\';'));
        expect(barrelCode, contains('export \'test_program_errors.dart\';'));
      });
    });

    group('AnchorDocumentationGenerator', () {
      test('should generate markdown documentation', () async {
        final result = await ideIntegration.documentationGenerator
            .generateFromIdl(testIdl);

        expect(result.success, isTrue);
        expect(result.generatedDocs, isNotEmpty);
        expect(result.errors, isEmpty);

        final readme = result.generatedDocs['README.md'];
        expect(readme, isNotNull);
        expect(readme, contains('# Anchor Program Documentation'));
        expect(readme, contains('TestProgram'));
        expect(readme, contains('## Instructions'));
        expect(readme, contains('### initialize'));
        expect(readme, contains('### update'));
        expect(readme, contains('## Accounts'));
        expect(readme, contains('### ProgramState'));
        expect(readme, contains('## Errors'));
      });

      test('should generate API reference', () async {
        final result = await ideIntegration.documentationGenerator
            .generateFromIdl(testIdl);

        final apiRef = result.generatedDocs['API_REFERENCE.md'];
        expect(apiRef, isNotNull);
        expect(apiRef, contains('# API Reference'));
        expect(apiRef, contains('## Methods'));
        expect(apiRef, contains('### `initialize()`'));
        expect(apiRef, contains('### `update()`'));
        expect(apiRef, contains('Future<String>'));
      });

      test('should generate HTML documentation', () async {
        final docGen = const AnchorDocumentationGenerator(
          DocumentationConfig(format: 'html'),
        );

        final result = await docGen.generateFromIdl(testIdl);

        expect(result.success, isTrue);
        final html = result.generatedDocs['index.html'];
        expect(html, isNotNull);
        expect(html, contains('<!DOCTYPE html>'));
        expect(html, contains('<title>Anchor Program Documentation</title>'));
        expect(html, contains('<h1>Anchor Program Documentation</h1>'));
      });

      test('should generate JSON documentation', () async {
        final docGen = const AnchorDocumentationGenerator(
          DocumentationConfig(format: 'json'),
        );

        final result = await docGen.generateFromIdl(testIdl);

        expect(result.success, isTrue);
        final jsonDoc = result.generatedDocs['documentation.json'];
        expect(jsonDoc, isNotNull);

        // Should be valid JSON
        expect(() => jsonDecode(jsonDoc!), returnsNormally);
      });
    });

    group('AnchorDebugger', () {
      test('should create debug session', () {
        final session = ideIntegration.debugger.createSession();

        expect(session, isNotNull);
        expect(session.sessionId, isNotEmpty);
        expect(session.config, equals(ideIntegration.debugger.config));
        expect(ideIntegration.debugger.currentSession, equals(session));
      });

      test('should log messages correctly', () {
        final session = ideIntegration.debugger.createSession();

        ideIntegration.debugger
            .info('Test info message', context: {'key': 'value'});
        ideIntegration.debugger.warning('Test warning');
        ideIntegration.debugger.error('Test error');
        ideIntegration.debugger.debug('Test debug');

        expect(session.logs, hasLength(4));
        expect(session.logs[0].level, equals('info'));
        expect(session.logs[0].message, equals('Test info message'));
        expect(session.logs[0].context, equals({'key': 'value'}));
        expect(session.logs[1].level, equals('warning'));
        expect(session.logs[2].level, equals('error'));
        expect(session.logs[3].level, equals('debug'));
      });

      test('should analyze IDL for issues', () {
        final issues = ideIntegration.debugger.analyzeIdl(testIdl);

        // Should not find major issues with our well-formed test IDL
        expect(issues, isA<List<String>>());
        // May have some minor suggestions
      });

      test('should generate debug report', () {
        final session = ideIntegration.debugger.createSession();
        ideIntegration.debugger.info('Test message');

        final report = ideIntegration.debugger.generateReport();

        expect(report, contains('# Debug Report'));
        expect(report, contains('Session ID:'));
        expect(report, contains('## Logs Summary'));
        expect(report, contains('Total logs: 1'));
      });

      test('should export session data', () {
        final session = ideIntegration.debugger.createSession();
        ideIntegration.debugger.info('Test message');

        final exported = ideIntegration.debugger.exportAllSessions();

        expect(exported['sessions'], isNotEmpty);
        expect(exported['currentSessionId'], equals(session.sessionId));
      });
    });

    group('AnchorIdeIntegration', () {
      test('should generate complete development package', () async {
        final result = await ideIntegration.generateDevelopmentPackage(
          testIdl,
          writeFiles: false,
        );

        expect(result.success, isTrue);
        expect(result.codeResult.success, isTrue);
        expect(result.documentationResult.success, isTrue);
        expect(result.errors, isEmpty);

        // Check that we have both code and documentation
        expect(result.codeResult.generatedFiles, isNotEmpty);
        expect(result.documentationResult.generatedDocs, isNotEmpty);
      });

      test('should generate API reference', () async {
        final apiRef = await ideIntegration.generateApiReference(testIdl);

        expect(apiRef, contains('# TestProgram API Reference'));
        expect(apiRef, contains('## Methods'));
        expect(apiRef, contains('### `initialize()`'));
        expect(apiRef, contains('### `update()`'));
        expect(apiRef, contains('## Account Fetching'));
        expect(apiRef, contains('### `ProgramState`'));
        expect(apiRef, contains('program.methods.initialize'));
        expect(apiRef, contains('program.account.ProgramState.fetch'));
      });

      test('should create production configuration', () {
        final prodIntegration = AnchorIdeIntegration.production();

        expect(
            prodIntegration.codeGenerator.config.generateInterfaces, isFalse,);
        expect(prodIntegration.debugger.config.verbose, isFalse);
        expect(prodIntegration.debugger.config.captureTransactionLogs, isFalse);
      });

      test('should handle empty IDL gracefully', () async {
        final emptyIdl = const Idl(
          name: 'Empty',
          instructions: [],
        );

        final result = await ideIntegration.generateDevelopmentPackage(
          emptyIdl,
          writeFiles: false,
        );

        expect(result.success, isTrue);
        expect(result.warnings, isNotEmpty); // Should warn about empty program
      });
    });

    group('Development Package Result', () {
      test('should generate comprehensive summary', () async {
        final result = await ideIntegration.generateDevelopmentPackage(
          testIdl,
          writeFiles: false,
        );

        final summary = result.generateSummary();

        expect(summary, contains('# Development Package Generation Summary'));
        expect(summary, contains('**Status:** SUCCESS'));
        expect(summary, contains('## Code Generation'));
        expect(summary, contains('✅ **Success**'));
        expect(summary, contains('## Documentation Generation'));
        expect(summary, contains('Files generated:'));
        expect(summary, contains('Lines of code:'));
      });
    });

    group('Configuration Options', () {
      test('should support different naming conventions', () async {
        final snakeCaseConfig = const CodeGenerationConfig(
          namingConvention: 'snake_case',
          packageName: 'test_program',
        );

        final generator = AnchorCodeGenerator(snakeCaseConfig);
        final result = await generator.generateFromIdl(testIdl);

        expect(result.success, isTrue);
        final code = result.generatedFiles['test_program_program.dart'];
        expect(code, isNotNull);
        // Should use snake_case for field names
      });

      test('should support selective generation', () async {
        final minimalConfig = const CodeGenerationConfig(
          generateInterfaces: false,
          generateAccountClasses: false,
          generateErrorClasses: false,
          packageName: 'test_program',
        );

        final generator = AnchorCodeGenerator(minimalConfig);
        final result = await generator.generateFromIdl(testIdl);

        expect(result.success, isTrue);
        expect(
            result.generatedFiles.keys, contains('test_program_methods.dart'),);
        expect(result.generatedFiles.keys,
            isNot(contains('test_program_program.dart')),);
        expect(result.generatedFiles.keys,
            isNot(contains('test_program_accounts.dart')),);
        expect(result.generatedFiles.keys,
            isNot(contains('test_program_errors.dart')),);
      });
    });
  });
}
