/// Tests for Step 8.1: Workspace and Multi-Program Management
///
/// This test suite validates the enhanced workspace management functionality
/// including auto-discovery, health checking, deployment, and multi-program
/// coordination matching TypeScript's Anchor workspace capabilities.

import 'package:test/test.dart';
import 'package:matcher/matcher.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../lib/src/workspace/workspace.dart';
import '../lib/src/workspace/workspace_config.dart';
import '../lib/src/workspace/program_manager.dart';
import '../lib/src/provider/anchor_provider.dart';
import '../lib/src/provider/connection.dart';
import '../lib/src/provider/wallet.dart';
import '../lib/src/types/keypair.dart';
import '../lib/src/types/public_key.dart';
import '../lib/src/idl/idl.dart';
import '../lib/src/program/program_class.dart';
import '../lib/src/coder/discriminator_computer.dart';

void main() {
  group('Step 8.1: Workspace and Multi-Program Management', () {
    late AnchorProvider mockProvider;
    late Connection mockConnection;
    late KeypairWallet mockWallet;
    late Keypair testKeypair;

    setUpAll(() async {
      // Create test keypair and wallet
      testKeypair = await Keypair.generate();
      mockWallet = KeypairWallet(testKeypair);

      // Create mock connection and provider
      mockConnection = Connection('http://localhost:8899');
      mockProvider = AnchorProvider(mockConnection, mockWallet);
    });

    group('Enhanced Workspace Features', () {
      test('should create workspace with auto-discovery', () async {
        final workspace = await Workspace.discover(
          provider: mockProvider,
        );

        expect(workspace.provider, equals(mockProvider));
        expect(workspace.programNames, isA<List<String>>());
      });

      test('should support TypeScript-like camelCase program access', () async {
        final workspace = Workspace(mockProvider);

        // Create test IDL
        final testIdl = createTestIdl();
        final programId = await Keypair.generate();

        // Load program with snake_case name
        await workspace.loadProgram(
            'test_program', testIdl, programId.publicKey);

        // Should find with camelCase
        final program = workspace.getProgramCamelCase('testProgram');
        expect(program, isNotNull);
        expect(program!.programId, equals(programId.publicKey));

        // Should also find with exact match
        final exactProgram = workspace.getProgramCamelCase('test_program');
        expect(exactProgram, isNotNull);
      });

      test('should validate workspace health', () async {
        final workspace = Workspace(mockProvider);

        // Add a test program
        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        await workspace.loadProgram('test', testIdl, programId.publicKey);

        final healthReport = await workspace.validateHealth();

        expect(healthReport, isA<WorkspaceHealthReport>());
        expect(healthReport.programStatuses.containsKey('test'), isTrue);
        expect(healthReport.checkedAt, isA<DateTime>());
      });

      test('should handle program deployment', () async {
        final workspace = Workspace(mockProvider);

        final programKeypair = await Keypair.generate();
        final programData =
            Uint8List.fromList([1, 2, 3, 4]); // Mock program data

        final result = await workspace.deployProgram(
          'test_program',
          programData,
          programKeypair,
        );

        expect(result.success, isTrue);
        expect(result.programId, equals(programKeypair.publicKey));
        expect(result.deployedAt, isA<DateTime>());
      });

      test('should handle program upgrades', () async {
        final workspace = Workspace(mockProvider);

        // First add a program
        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        await workspace.loadProgram('test', testIdl, programId.publicKey);

        final newProgramData = Uint8List.fromList([5, 6, 7, 8]);

        final result = await workspace.upgradeProgram('test', newProgramData);

        expect(result.success, isTrue);
        expect(result.programId, equals(programId.publicKey));
        expect(result.upgradedAt, isA<DateTime>());
      });

      test('should create development configuration', () {
        final workspace = Workspace(mockProvider);

        final devConfig = workspace.createDevConfig();

        expect(devConfig.containsKey('workspace'), isTrue);
        expect(devConfig.containsKey('programs'), isTrue);
        expect(devConfig['workspace']['cluster'], equals('localnet'));
      });

      test('should export workspace for deployment', () async {
        final workspace = Workspace(mockProvider);

        // Add test program
        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        await workspace.loadProgram('test', testIdl, programId.publicKey);

        final exportData = await workspace.exportForDeployment();

        expect(exportData.containsKey('workspace'), isTrue);
        expect(exportData.containsKey('programs'), isTrue);
        expect((exportData['programs'] as Map).containsKey('test'), isTrue);
      });
    });

    group('Workspace Configuration Management', () {
      test('should parse Anchor.toml configuration', () {
        final tomlContent = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
test_program = "11111111111111111111111111111111"

[test]
startup_wait = 5000
''';

        // Create temporary file
        final tempDir = Directory.systemTemp.createTempSync();
        final anchorTomlFile = File('${tempDir.path}/Anchor.toml');
        anchorTomlFile.writeAsStringSync(tomlContent);

        final config = WorkspaceConfig.fromFile(anchorTomlFile.path);

        expect(config.provider.cluster, equals('localnet'));
        expect(config.provider.wallet, equals('~/.config/solana/id.json'));
        expect(
            config.programs['localnet']!.containsKey('test_program'), isTrue);
        expect(config.test?.startupWait, equals(5000));

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });

      test('should discover IDL files from workspace', () {
        // Create temporary workspace structure
        final tempDir = Directory.systemTemp.createTempSync();
        final idlDir = Directory('${tempDir.path}/target/idl');
        idlDir.createSync(recursive: true);

        // Create Anchor.toml first
        final anchorToml = File('${tempDir.path}/Anchor.toml');
        anchorToml.writeAsStringSync('''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
test_program = "11111111111111111111111111111111"
''');

        // Create test IDL file
        final idlFile = File('${idlDir.path}/test_program.json');
        idlFile.writeAsStringSync(jsonEncode(createTestIdl().toJson()));

        final config = WorkspaceConfig.fromDirectory(tempDir.path);
        final idlFiles = config.discoverIdlFiles();

        expect(idlFiles, isNotEmpty);
        expect(idlFiles.first, endsWith('test_program.json'));

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });

      test('should load program IDL from workspace', () {
        // Create temporary workspace
        final tempDir = Directory.systemTemp.createTempSync();
        final idlDir = Directory('${tempDir.path}/target/idl');
        idlDir.createSync(recursive: true);

        // Create Anchor.toml
        final anchorToml = File('${tempDir.path}/Anchor.toml');
        anchorToml.writeAsStringSync('''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
test_program = "11111111111111111111111111111111"
''');

        // Create IDL file
        final idlFile = File('${idlDir.path}/test_program.json');
        idlFile.writeAsStringSync(jsonEncode(createTestIdl().toJson()));

        final config = WorkspaceConfig.fromDirectory(tempDir.path);
        final idl = config.loadProgramIdl('test_program');

        expect(idl, isNotNull);
        expect(idl!.name, equals('TestProgram'));

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });

      test('should validate workspace configuration', () {
        // Create temporary workspace with invalid config
        final tempDir = Directory.systemTemp.createTempSync();
        final anchorToml = File('${tempDir.path}/Anchor.toml');
        anchorToml.writeAsStringSync('''
[provider]
cluster = ""
wallet = ""

[programs.localnet]
test_program = { address = "11111111111111111111111111111111", idl = "nonexistent.json" }
''');

        final config = WorkspaceConfig.fromDirectory(tempDir.path);
        final errors = config.validate();

        expect(errors, isNotEmpty);
        expect(errors.any((error) => error.contains('cluster')), isTrue);
        expect(errors.any((error) => error.contains('wallet')), isTrue);

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });
    });

    group('Program Manager and Coordination', () {
      test('should register and manage programs', () async {
        final manager = ProgramManager();

        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        final program = Program.withProgramId(testIdl, programId.publicKey,
            provider: mockProvider);

        await manager.registerProgram('test', program);

        expect(manager.registry.hasProgram('test'), isTrue);
        expect(manager.registry.getProgram('test'), equals(program));
      });

      test('should handle program dependencies', () async {
        final manager = ProgramManager();

        // Create programs with dependencies
        final baseIdl = createTestIdl();
        final dependentIdl = createTestIdl();

        final baseProgramId = await Keypair.generate();
        final dependentProgramId = await Keypair.generate();

        final baseProgram = Program.withProgramId(
            baseIdl, baseProgramId.publicKey,
            provider: mockProvider);
        final dependentProgram = Program.withProgramId(
            dependentIdl, dependentProgramId.publicKey,
            provider: mockProvider);

        // Register base program
        await manager.registerProgram('base', baseProgram);

        // Register dependent program with dependency
        final dependency =
            ProgramDependency(name: 'base', programId: baseProgramId.publicKey);
        await manager.registerProgram('dependent', dependentProgram,
            dependencies: [dependency]);

        final dependencyOrder = manager.registry.resolveDependencyOrder();

        expect(dependencyOrder.indexOf('base'),
            lessThan(dependencyOrder.indexOf('dependent')));
      });

      test('should validate dependencies', () async {
        final manager = ProgramManager();

        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        final program = Program.withProgramId(testIdl, programId.publicKey,
            provider: mockProvider);

        // Register program with missing dependency
        final missingDep =
            ProgramDependency(name: 'missing_program', required: true);
        await manager
            .registerProgram('test', program, dependencies: [missingDep]);

        expect(() => manager.validateDependencies(),
            throwsA(isA<ProgramManagerException>()));
      });

      test('should manage shared resources', () {
        final manager = ProgramManager();

        manager.resourceManager.registerProvider('test', mockProvider);
        manager.resourceManager.setCachedValue('test_key', 'test_value');

        expect(
            manager.resourceManager.getProvider('test'), equals(mockProvider));
        expect(manager.resourceManager.getCachedValue<String>('test_key'),
            equals('test_value'));
      });

      test('should track program lifecycle', () async {
        final manager = ProgramManager();

        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        final program = Program.withProgramId(testIdl, programId.publicKey,
            provider: mockProvider);

        await manager.registerProgram('test', program);

        final lifecycle = manager.registry.getLifecycleInfo('test');
        expect(lifecycle, isNotNull);
        expect(lifecycle!.isLoaded, isTrue);

        await manager.initializeProgram('test');

        final updatedLifecycle = manager.registry.getLifecycleInfo('test');
        expect(updatedLifecycle!.isReady, isTrue);
      });

      test('should provide coordination statistics', () async {
        final manager = ProgramManager();

        final testIdl = createTestIdl();
        final programId = await Keypair.generate();
        final program = Program.withProgramId(testIdl, programId.publicKey,
            provider: mockProvider);

        await manager.registerProgram('test', program);
        manager.resourceManager.setCachedValue('test', 'value');

        final stats = manager.getStats();

        expect(stats.containsKey('registry'), isTrue);
        expect(stats.containsKey('resources'), isTrue);
        expect(stats['registry']['totalPrograms'], equals(1));
      });
    });

    group('Workspace Discovery and Validation', () {
      test('should discover workspaces in directory tree', () {
        // Create temporary directory structure with multiple workspaces
        final tempDir = Directory.systemTemp.createTempSync();

        final workspace1 = Directory('${tempDir.path}/workspace1');
        workspace1.createSync(recursive: true);
        File('${workspace1.path}/Anchor.toml')
            .writeAsStringSync('[provider]\ncluster = "localnet"');

        final workspace2 = Directory('${tempDir.path}/nested/workspace2');
        workspace2.createSync(recursive: true);
        File('${workspace2.path}/Anchor.toml')
            .writeAsStringSync('[provider]\ncluster = "localnet"');

        final discovered = WorkspaceDiscovery.discoverWorkspaces(tempDir.path);

        expect(discovered, hasLength(2));
        expect(discovered, contains(workspace1.path));
        expect(discovered, contains(workspace2.path));

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });

      test('should auto-detect workspace template', () {
        // Create workspace structure
        final tempDir = Directory.systemTemp.createTempSync();
        Directory('${tempDir.path}/programs').createSync();
        Directory('${tempDir.path}/tests').createSync();
        Directory('${tempDir.path}/target').createSync();

        final template = WorkspaceDiscovery.autoDetectTemplate(tempDir.path);

        expect(template, isNotNull);
        expect(template!.type, equals(WorkspaceType.anchor));
        expect(template.hasPrograms, isTrue);
        expect(template.hasTests, isTrue);
        expect(template.hasBuild, isTrue);

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });

      test('should validate workspace structure', () {
        // Create incomplete workspace
        final tempDir = Directory.systemTemp.createTempSync();
        Directory('${tempDir.path}/programs').createSync();
        // Missing Anchor.toml

        final result = WorkspaceDiscovery.validateStructure(tempDir.path);

        expect(result.isValid, isFalse);
        expect(result.issues.any((error) => error.contains('Anchor.toml')),
            isTrue);

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });

      test('should initialize workspace from template', () async {
        final tempDir = Directory.systemTemp.createTempSync();
        final workspacePath = '${tempDir.path}/new_workspace';

        final template =
            WorkspaceInitializationTemplate.basic('test_workspace');

        await WorkspaceDiscovery.initializeWorkspace(workspacePath, template);

        expect(Directory(workspacePath).existsSync(), isTrue);
        expect(File('$workspacePath/Anchor.toml').existsSync(), isTrue);
        expect(Directory('$workspacePath/programs').existsSync(), isTrue);
        expect(Directory('$workspacePath/tests').existsSync(), isTrue);

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });
    });

    group('Enhanced Workspace Builder', () {
      test('should build workspace with auto-discovery', () async {
        final builder = EnhancedWorkspaceBuilder(mockProvider)
            .withAutoDiscover()
            .withMetadata('version', '1.0.0');

        final workspace = await builder.build();

        expect(workspace.provider, equals(mockProvider));
      });

      test('should build workspace with programs', () async {
        final testIdl = createTestIdl();
        final programId = await Keypair.generate();

        final builder = EnhancedWorkspaceBuilder(mockProvider)
            .addProgramWithIdl('test', testIdl, programId.publicKey);

        final workspace = await builder.build();

        expect(workspace.hasProgram('test'), isTrue);
        expect(workspace.getProgram('test')!.programId,
            equals(programId.publicKey));
      });
    });

    group('Workspace Templates', () {
      test('should create workspace from template', () async {
        final testIdl = createTestIdl();
        final programId = await Keypair.generate();

        final programConfig = ProgramConfig(
          idl: testIdl,
          programId: programId.publicKey,
          name: 'test',
        );

        final template = WorkspaceTemplate(
          name: 'test_template',
          version: '1.0.0',
          programs: {'test': programConfig},
        );

        final workspace =
            await Workspace.initializeFromTemplate(mockProvider, template);

        expect(workspace.hasProgram('test'), isTrue);
        expect(workspace.getProgram('test')!.programId,
            equals(programId.publicKey));
      });

      test('should serialize and deserialize templates', () {
        final testIdl = createTestIdl();
        const programId = '11111111111111111111111111111111';

        final programConfig = ProgramConfig(
          idl: testIdl,
          programId: PublicKey.fromBase58(programId),
          name: 'test',
        );

        final template = WorkspaceTemplate(
          name: 'test_template',
          version: '1.0.0',
          programs: {'test': programConfig},
        );

        final json = template.toJson();
        final restored = WorkspaceTemplate.fromJson(json);

        expect(restored.name, equals(template.name));
        expect(restored.version, equals(template.version));
        expect(restored.programs.containsKey('test'), isTrue);
      });
    });
  });
}

/// Create a test IDL for testing purposes
Idl createTestIdl() {
  // Compute discriminator for DataAccount
  final discriminator =
      DiscriminatorComputer.computeAccountDiscriminator('DataAccount');

  return Idl.fromJson({
    'version': '0.1.0',
    'name': 'TestProgram',
    'instructions': [
      {
        'name': 'initialize',
        'accounts': [
          {
            'name': 'data',
            'isMut': true,
            'isSigner': false,
          },
          {
            'name': 'user',
            'isMut': false,
            'isSigner': true,
          },
        ],
        'args': [],
      },
    ],
    'accounts': [
      {
        'name': 'DataAccount',
        'discriminator': discriminator.toList(),
        'type': {
          'kind': 'struct',
          'fields': [
            {
              'name': 'value',
              'type': 'u64',
            },
          ],
        },
      },
    ],
    'types': [
      {
        'name': 'DataAccount',
        'type': {
          'kind': 'struct',
          'fields': [
            {
              'name': 'value',
              'type': 'u64',
            },
          ],
        },
      },
    ],
  });
}
