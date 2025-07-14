/// Test suite for workspace configuration system
///
/// Tests comprehensive workspace management with Anchor.toml parsing,
/// program discovery, and configuration validation.
library;

import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('WorkspaceConfig', () {
    late Directory tempDir;
    late String tempPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('workspace_test_');
      tempPath = tempDir.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('TOML Parsing', () {
      test('should parse minimal Anchor.toml', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);

        expect(config.provider.cluster, equals('localnet'));
        expect(config.provider.wallet, equals('~/.config/solana/id.json'));
        expect(config.programs['localnet']?['my_program']?.address,
            equals('BPFLoader2111111111111111111111111111111111'),);
      });

      test('should parse complete Anchor.toml with all sections', () {
        final anchorToml = '''
[features]
seeds = false
skip-lint = true

[provider]
cluster = "devnet"
wallet = "/path/to/wallet.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
complex_program = { address = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", idl = "target/idl/complex.json" }

[programs.devnet]
devnet_program = "DevnetProgram111111111111111111111111111"

[scripts]
test = "yarn run ts-mocha -t 1000000 tests/**/*.ts"
build = "anchor build"

[test]
startup_wait = 20000

[[test.validator.account]]
address = "3vMPj13emX9JmifYcWc77ekEzV1F37ga36E1YeSr6Mdj"
filename = "./tests/accounts/SOME_ACCOUNT.json"

[[test.validator.account]]
address = "4vMPj13emX9JmifYcWc77ekEzV1F37ga36E1YeSr6Mdj"
filename = "./tests/accounts/ANOTHER_ACCOUNT.json"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);

        // Test provider
        expect(config.provider.cluster, equals('devnet'));
        expect(config.provider.wallet, equals('/path/to/wallet.json'));

        // Test features
        expect(config.features?.seeds, equals(false));
        expect(config.features?.skipLint, equals(true));

        // Test programs
        expect(config.programs['localnet']?['my_program']?.address,
            equals('BPFLoader2111111111111111111111111111111111'),);
        expect(config.programs['localnet']?['complex_program']?.address,
            equals('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),);
        expect(config.programs['localnet']?['complex_program']?.idl,
            equals('target/idl/complex.json'),);
        expect(config.programs['devnet']?['devnet_program']?.address,
            equals('DevnetProgram111111111111111111111111111'),);

        // Test scripts
        expect(config.scripts?.scripts['test'],
            equals('yarn run ts-mocha -t 1000000 tests/**/*.ts'),);
        expect(config.scripts?.scripts['build'], equals('anchor build'));

        // Test test configuration
        expect(config.test?.startupWait, equals(20000));
        expect(config.test?.validatorAccounts, hasLength(2));
        expect(config.test?.validatorAccounts?[0].address,
            equals('3vMPj13emX9JmifYcWc77ekEzV1F37ga36E1YeSr6Mdj'),);
        expect(config.test?.validatorAccounts?[0].filename,
            equals('./tests/accounts/SOME_ACCOUNT.json'),);
      });

      test('should handle missing Anchor.toml file', () {
        expect(
          () =>
              WorkspaceConfig.fromFile(path.join(tempPath, 'nonexistent.toml')),
          throwsA(isA<WorkspaceConfigException>()),
        );
      });

      test('should handle invalid TOML syntax', () {
        final invalidToml = '''
[provider
cluster = "localnet"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(invalidToml);

        expect(
          () => WorkspaceConfig.fromFile(tomlFile.path),
          throwsA(isA<WorkspaceConfigException>()),
        );
      });

      test('should handle missing provider section', () {
        final anchorToml = '''
[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        expect(
          () => WorkspaceConfig.fromFile(tomlFile.path),
          throwsA(isA<WorkspaceConfigException>()),
        );
      });
    });

    group('Program Discovery', () {
      test('should discover IDL files from target/idl directory', () {
        // Create IDL directory structure
        final idlDir = Directory(path.join(tempPath, 'target', 'idl'));
        idlDir.createSync(recursive: true);

        // Create sample IDL files
        final idl1 = File(path.join(idlDir.path, 'my_program.json'));
        final idl2 = File(path.join(idlDir.path, 'another_program.json'));

        idl1.writeAsStringSync('{"version": "0.1.0"}');
        idl2.writeAsStringSync('{"version": "0.2.0"}');

        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final idlFiles = config.discoverIdlFiles();

        expect(idlFiles, hasLength(2));
        expect(idlFiles, contains(idl1.path));
        expect(idlFiles, contains(idl2.path));
      });

      test('should return empty list when target/idl directory does not exist',
          () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final idlFiles = config.discoverIdlFiles();

        expect(idlFiles, isEmpty);
      });
    });

    group('IDL Loading', () {
      test('should load IDL from explicit path', () {
        // Create IDL file
        final idlDir = Directory(path.join(tempPath, 'target', 'idl'));
        idlDir.createSync(recursive: true);

        final idlFile = File(path.join(idlDir.path, 'custom.json'));
        final idlContent = {
          'version': '0.1.0',
          'name': 'my_program',
          'instructions': [],
        };
        idlFile.writeAsStringSync(jsonEncode(idlContent));

        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = { address = "BPFLoader2111111111111111111111111111111111", idl = "target/idl/custom.json" }
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final idl = config.loadProgramIdl('my_program');

        expect(idl, isNotNull);
        expect(idl!.name, equals('my_program'));
        expect(
            idl.address, equals('BPFLoader2111111111111111111111111111111111'),);
      });

      test('should auto-discover IDL file by snake_case name', () {
        // Create IDL file with snake_case name
        final idlDir = Directory(path.join(tempPath, 'target', 'idl'));
        idlDir.createSync(recursive: true);

        final idlFile = File(path.join(idlDir.path, 'my_program.json'));
        final idlContent = {
          'version': '0.1.0',
          'name': 'my_program',
          'instructions': [],
        };
        idlFile.writeAsStringSync(jsonEncode(idlContent));

        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
myProgram = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final idl = config.loadProgramIdl('myProgram');

        expect(idl, isNotNull);
        expect(idl!.name, equals('my_program'));
        expect(
            idl.address, equals('BPFLoader2111111111111111111111111111111111'),);
      });

      test('should return null for non-existent program', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final idl = config.loadProgramIdl('nonexistent');

        expect(idl, isNull);
      });

      test('should return null for non-existent IDL file', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final idl = config.loadProgramIdl('my_program');

        expect(idl, isNull);
      });
    });

    group('Program Access', () {
      test('should get programs for current cluster', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
program1 = "BPFLoader2111111111111111111111111111111111"
program2 = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"

[programs.devnet]
program3 = "DevnetProgram111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final localnetPrograms = config.getProgramsForCluster();

        expect(localnetPrograms, hasLength(2));
        expect(localnetPrograms['program1']?.address,
            equals('BPFLoader2111111111111111111111111111111111'),);
        expect(localnetPrograms['program2']?.address,
            equals('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),);
      });

      test('should get programs for specific cluster', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
program1 = "BPFLoader2111111111111111111111111111111111"

[programs.devnet]
program2 = "DevnetProgram111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final devnetPrograms = config.getProgramsForCluster('devnet');

        expect(devnetPrograms, hasLength(1));
        expect(devnetPrograms['program2']?.address,
            equals('DevnetProgram111111111111111111111111111'),);
      });

      test('should get specific program', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final program = config.getProgram('my_program');

        expect(program, isNotNull);
        expect(program!.address,
            equals('BPFLoader2111111111111111111111111111111111'),);
      });
    });

    group('Validation', () {
      test('should validate correct configuration', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final errors = config.validate();

        expect(errors, isEmpty);
      });

      test('should detect empty cluster name', () {
        final anchorToml = '''
[provider]
cluster = ""
wallet = "~/.config/solana/id.json"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final errors = config.validate();

        expect(errors, contains('Provider cluster cannot be empty'));
      });

      test('should detect empty wallet path', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = ""
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final errors = config.validate();

        expect(errors, contains('Provider wallet cannot be empty'));
      });

      test('should detect missing IDL file', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = { address = "BPFLoader2111111111111111111111111111111111", idl = "nonexistent.json" }
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final errors = config.validate();

        expect(errors, isNotEmpty);
        expect(errors.any((error) => error.contains('IDL file not found')),
            isTrue,);
      });
    });

    group('Case Conversion', () {
      test('should convert camelCase to snake_case', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
myProgram = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);

        // Create matching IDL file
        final idlDir = Directory(path.join(tempPath, 'target', 'idl'));
        idlDir.createSync(recursive: true);

        final idlFile = File(path.join(idlDir.path, 'my_program.json'));
        final idlContent = {
          'version': '0.1.0',
          'name': 'my_program',
          'instructions': [],
        };
        idlFile.writeAsStringSync(jsonEncode(idlContent));

        final idl = config.loadProgramIdl('myProgram');
        expect(idl, isNotNull);
      });
    });

    group('Environment Support', () {
      test('should load from current directory', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final originalDir = Directory.current;
        try {
          Directory.current = tempPath;
          final config = WorkspaceConfig.fromCurrentDirectory();

          expect(config.provider.cluster, equals('localnet'));
          expect(path.canonicalize(config.workspaceRoot!),
              equals(path.canonicalize(Directory.current.path)),);
        } finally {
          Directory.current = originalDir;
        }
      });

      test('should load from directory', () {
        final anchorToml = '''
[provider]
cluster = "devnet"
wallet = "~/.config/solana/id.json"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromDirectory(tempPath);

        expect(config.provider.cluster, equals('devnet'));
        expect(path.canonicalize(config.workspaceRoot!),
            equals(path.canonicalize(tempPath)),);
      });
    });

    group('TOML Generation', () {
      test('should generate TOML from configuration', () {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
my_program = "BPFLoader2111111111111111111111111111111111"

[features]
seeds = false
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final config = WorkspaceConfig.fromFile(tomlFile.path);
        final generatedToml = config.toToml();

        expect(generatedToml['provider']['cluster'], equals('localnet'));
        expect(generatedToml['provider']['wallet'],
            equals('~/.config/solana/id.json'),);
        expect(generatedToml['programs']['localnet']['my_program'],
            equals('BPFLoader2111111111111111111111111111111111'),);
        expect(generatedToml['features']['seeds'], equals(false));
      });
    });
  });

  group('WorkspaceConfigException', () {
    test('should create exception with message only', () {
      const exception = WorkspaceConfigException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.filePath, isNull);
      expect(exception.cause, isNull);
      expect(exception.toString(), contains('Test error'));
    });

    test('should create exception with file path and cause', () {
      const exception = WorkspaceConfigException(
        'Test error',
        filePath: '/path/to/file.toml',
        cause: 'Root cause',
      );

      expect(exception.message, equals('Test error'));
      expect(exception.filePath, equals('/path/to/file.toml'));
      expect(exception.cause, equals('Root cause'));

      final toString = exception.toString();
      expect(toString, contains('Test error'));
      expect(toString, contains('/path/to/file.toml'));
      expect(toString, contains('Root cause'));
    });
  });
}
