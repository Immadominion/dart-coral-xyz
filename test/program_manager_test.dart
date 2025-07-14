/// Test suite for multi-program management and coordination system
///
/// Tests comprehensive program registry, shared resource management,
/// dependency resolution, and lifecycle coordination.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('ProgramManager', () {
    late Directory tempDir;
    late String tempPath;
    late AnchorProvider provider;
    late ProgramManager manager;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('program_manager_test_');
      tempPath = tempDir.path;

      // Create mock provider
      final connection = Connection('https://api.devnet.solana.com');
      provider = AnchorProvider(connection, MockWallet());

      manager = ProgramManager();
    });

    tearDown(() async {
      await manager.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('ProgramRegistry', () {
      test('should register and retrieve programs', () {
        final registry = manager.registry;
        final program = createMockProgram('test_program');

        registry.registerProgram('test_program', program);

        expect(registry.hasProgram('test_program'), isTrue);
        expect(registry.getProgram('test_program'), equals(program));
        expect(registry.programNames, contains('test_program'));
        expect(registry.programs['test_program'], equals(program));
      });

      test('should prevent duplicate program registration', () {
        final registry = manager.registry;
        final program = createMockProgram('test_program');

        registry.registerProgram('test_program', program);

        expect(
          () => registry.registerProgram('test_program', program),
          throwsA(isA<ProgramManagerException>()),
        );
      });

      test('should unregister programs', () {
        final registry = manager.registry;
        final program = createMockProgram('test_program');

        registry.registerProgram('test_program', program);
        expect(registry.hasProgram('test_program'), isTrue);

        final removed = registry.unregisterProgram('test_program');
        expect(removed, isTrue);
        expect(registry.hasProgram('test_program'), isFalse);
        expect(registry.getProgram('test_program'), isNull);
      });

      test('should handle program ID indexing', () {
        final registry = manager.registry;
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111111');
        final program1 = createMockProgram('program1', programId: programId);
        final program2 = createMockProgram('program2', programId: programId);

        registry.registerProgram('program1', program1);
        registry.registerProgram('program2', program2);

        final programs = registry.getProgramsById(programId);
        expect(programs, hasLength(2));
        expect(programs.map((p) => p.programId).toSet(), equals({programId}));
      });

      test('should track program metadata', () {
        final registry = manager.registry;
        final program = createMockProgram('test_program');
        final dependencies = [
          const ProgramDependency(name: 'dep1'),
          const ProgramDependency(name: 'dep2', required: false),
        ];
        final metadata = {'version': '1.0.0', 'author': 'test'};

        registry.registerProgram(
          'test_program',
          program,
          dependencies: dependencies,
          metadata: metadata,
        );

        final programMeta = registry.getProgramMetadata('test_program');
        expect(programMeta, isNotNull);
        expect(programMeta!.name, equals('test_program'));
        expect(programMeta.dependencies, equals(dependencies));
        expect(programMeta.metadata, equals(metadata));
        expect(programMeta.loadedAt, isNotNull);
      });

      test('should track program lifecycle', () {
        final registry = manager.registry;
        final program = createMockProgram('test_program');

        registry.registerProgram('test_program', program);

        final lifecycle = registry.getLifecycleInfo('test_program');
        expect(lifecycle, isNotNull);
        expect(lifecycle!.state, equals(ProgramLifecycleState.loaded));
        expect(lifecycle.stateChangedAt, isNotNull);

        registry.updateLifecycleState(
          'test_program',
          ProgramLifecycleState.ready,
        );

        final updatedLifecycle = registry.getLifecycleInfo('test_program');
        expect(updatedLifecycle!.state, equals(ProgramLifecycleState.ready));
        expect(updatedLifecycle.isReady, isTrue);
      });
    });

    group('Dependency Resolution', () {
      test('should resolve simple dependency order', () {
        final registry = manager.registry;

        // Create programs with dependencies: B depends on A, C depends on B
        final programA = createMockProgram('program_a');
        final programB = createMockProgram('program_b');
        final programC = createMockProgram('program_c');

        registry.registerProgram('program_a', programA);
        registry.registerProgram(
          'program_b',
          programB,
          dependencies: [const ProgramDependency(name: 'program_a')],
        );
        registry.registerProgram(
          'program_c',
          programC,
          dependencies: [const ProgramDependency(name: 'program_b')],
        );

        final order = registry.resolveDependencyOrder();

        // A should come before B, B should come before C
        expect(
            order.indexOf('program_a'), lessThan(order.indexOf('program_b')),);
        expect(
            order.indexOf('program_b'), lessThan(order.indexOf('program_c')),);
      });

      test('should detect circular dependencies', () {
        final registry = manager.registry;

        final programA = createMockProgram('program_a');
        final programB = createMockProgram('program_b');

        registry.registerProgram(
          'program_a',
          programA,
          dependencies: [const ProgramDependency(name: 'program_b')],
        );
        registry.registerProgram(
          'program_b',
          programB,
          dependencies: [const ProgramDependency(name: 'program_a')],
        );

        expect(
          registry.resolveDependencyOrder,
          throwsA(isA<ProgramManagerException>()),
        );
      });

      test('should validate dependencies', () {
        final registry = manager.registry;

        final program = createMockProgram('program_with_deps');
        registry.registerProgram(
          'program_with_deps',
          program,
          dependencies: [
            const ProgramDependency(name: 'missing_required'),
            const ProgramDependency(name: 'missing_optional', required: false),
          ],
        );

        final errors = registry.validateDependencies();
        expect(errors, hasLength(1));
        expect(errors.first, contains('missing_required'));
      });

      test('should get program dependents', () {
        final registry = manager.registry;

        final programA = createMockProgram('program_a');
        final programB = createMockProgram('program_b');
        final programC = createMockProgram('program_c');

        registry.registerProgram('program_a', programA);
        registry.registerProgram(
          'program_b',
          programB,
          dependencies: [const ProgramDependency(name: 'program_a')],
        );
        registry.registerProgram(
          'program_c',
          programC,
          dependencies: [const ProgramDependency(name: 'program_a')],
        );

        final dependents = registry.getDependents('program_a');
        expect(dependents, containsAll(['program_b', 'program_c']));
      });
    });

    group('SharedResourceManager', () {
      test('should manage shared providers', () {
        final resourceManager = manager.resourceManager;
        final provider1 =
            AnchorProvider(Connection('https://test1.com'), MockWallet());
        final provider2 =
            AnchorProvider(Connection('https://test2.com'), MockWallet());

        resourceManager.registerProvider('provider1', provider1);
        resourceManager.registerProvider('provider2', provider2);

        expect(resourceManager.getProvider('provider1'), equals(provider1));
        expect(resourceManager.getProvider('provider2'), equals(provider2));
        expect(resourceManager.getProvider('nonexistent'), isNull);
      });

      test('should manage shared cache', () {
        final resourceManager = manager.resourceManager;

        resourceManager.setCachedValue('key1', 'value1');
        resourceManager.setCachedValue('key2', 42);

        expect(
            resourceManager.getCachedValue<String>('key1'), equals('value1'),);
        expect(resourceManager.getCachedValue<int>('key2'), equals(42));
        expect(resourceManager.getCachedValue<String>('nonexistent'), isNull);
      });

      test('should manage event streams', () async {
        final resourceManager = manager.resourceManager;
        final events = <String>[];

        // Subscribe to stream
        final stream = resourceManager.getEventStream<String>('test_stream');
        final subscription = stream.listen(events.add);

        // Emit events
        resourceManager.emitEvent('test_stream', 'event1');
        resourceManager.emitEvent('test_stream', 'event2');

        // Allow events to propagate
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events, equals(['event1', 'event2']));

        await subscription.cancel();
      });

      test('should provide resource statistics', () {
        final resourceManager = manager.resourceManager;

        resourceManager.registerProvider('provider1', provider);
        resourceManager.setCachedValue('key1', 'value1');
        resourceManager.getEventStream<String>('stream1');

        final stats = resourceManager.getStats();
        expect(stats['providers'], equals(1));
        expect(stats['cachedEntries'], equals(1));
        expect(stats['eventStreams'], equals(1));
        expect(stats['activeStreams'], equals(1));
      });
    });

    group('Program Loading and Initialization', () {
      test('should register program with coordination', () async {
        final program = createMockProgram('test_program');

        await manager.registerProgram('test_program', program);

        expect(manager.registry.hasProgram('test_program'), isTrue);
        final lifecycle = manager.registry.getLifecycleInfo('test_program');
        expect(lifecycle?.isReady, isTrue);
      });

      test('should initialize program dependencies', () async {
        final programA = createMockProgram('program_a');
        final programB = createMockProgram('program_b');

        await manager.registerProgram('program_a', programA,
            autoInitialize: false,);
        await manager.registerProgram(
          'program_b',
          programB,
          dependencies: [const ProgramDependency(name: 'program_a')],
          autoInitialize: false,
        );

        // Both should be loaded but not ready
        expect(manager.registry.getLifecycleInfo('program_a')?.state,
            equals(ProgramLifecycleState.loaded),);
        expect(manager.registry.getLifecycleInfo('program_b')?.state,
            equals(ProgramLifecycleState.loaded),);

        // Initialize B should also initialize A
        await manager.initializeProgram('program_b');

        expect(manager.registry.getLifecycleInfo('program_a')?.isReady, isTrue);
        expect(manager.registry.getLifecycleInfo('program_b')?.isReady, isTrue);
      });

      test('should initialize all programs in order', () async {
        final programA = createMockProgram('program_a');
        final programB = createMockProgram('program_b');
        final programC = createMockProgram('program_c');

        await manager.registerProgram('program_a', programA,
            autoInitialize: false,);
        await manager.registerProgram(
          'program_b',
          programB,
          dependencies: [const ProgramDependency(name: 'program_a')],
          autoInitialize: false,
        );
        await manager.registerProgram(
          'program_c',
          programC,
          dependencies: [const ProgramDependency(name: 'program_b')],
          autoInitialize: false,
        );

        await manager.initializeAll();

        expect(manager.registry.getLifecycleInfo('program_a')?.isReady, isTrue);
        expect(manager.registry.getLifecycleInfo('program_b')?.isReady, isTrue);
        expect(manager.registry.getLifecycleInfo('program_c')?.isReady, isTrue);
      });

      test('should batch initialize specific programs', () async {
        final programA = createMockProgram('program_a');
        final programB = createMockProgram('program_b');
        final programC = createMockProgram('program_c');

        await manager.registerProgram('program_a', programA,
            autoInitialize: false,);
        await manager.registerProgram('program_b', programB,
            autoInitialize: false,);
        await manager.registerProgram('program_c', programC,
            autoInitialize: false,);

        await manager.batchInitialize(['program_a', 'program_c']);

        expect(manager.registry.getLifecycleInfo('program_a')?.isReady, isTrue);
        expect(
            manager.registry.getLifecycleInfo('program_b')?.isReady, isFalse,);
        expect(manager.registry.getLifecycleInfo('program_c')?.isReady, isTrue);
      });
    });

    group('Workspace Integration', () {
      test('should load program from workspace config', () async {
        // Create workspace config
        final idlContent = {
          'version': '0.1.0',
          'name': 'test_program',
          'instructions': [],
        };

        final idlDir = Directory(path.join(tempPath, 'target', 'idl'));
        idlDir.createSync(recursive: true);

        final idlFile = File(path.join(idlDir.path, 'test_program.json'));
        idlFile.writeAsStringSync(jsonEncode(idlContent));

        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
test_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final workspaceConfig = WorkspaceConfig.fromFile(tomlFile.path);

        final program = await manager.loadProgram(
          'test_program',
          workspaceConfig,
          provider,
        );

        expect(program, isNotNull);
        expect(program.idl.name, equals('test_program'));
        expect(manager.registry.hasProgram('test_program'), isTrue);
        expect(
            manager.registry.getLifecycleInfo('test_program')?.isReady, isTrue,);
      });

      test('should handle missing IDL gracefully', () async {
        final anchorToml = '''
[provider]
cluster = "localnet"
wallet = "~/.config/solana/id.json"

[programs.localnet]
missing_program = "BPFLoader2111111111111111111111111111111111"
''';

        final tomlFile = File(path.join(tempPath, 'Anchor.toml'));
        tomlFile.writeAsStringSync(anchorToml);

        final workspaceConfig = WorkspaceConfig.fromFile(tomlFile.path);

        expect(
          () =>
              manager.loadProgram('missing_program', workspaceConfig, provider),
          throwsA(isA<ProgramManagerException>()),
        );

        final lifecycle = manager.registry.getLifecycleInfo('missing_program');
        expect(lifecycle?.hasError, isTrue);
      });
    });

    group('Validation and Error Handling', () {
      test('should validate dependencies on demand', () {
        final program = createMockProgram('test_program');
        manager.registry.registerProgram(
          'test_program',
          program,
          dependencies: [const ProgramDependency(name: 'missing_dep')],
        );

        expect(
          () => manager.validateDependencies(),
          throwsA(isA<ProgramManagerException>()),
        );
      });

      test('should handle program loading errors', () async {
        final completer = manager.loadProgram(
          'nonexistent',
          const WorkspaceConfig(
            provider: ProviderConfig(cluster: 'test', wallet: 'test'),
            programs: {},
          ),
          provider,
        );

        expect(completer, throwsA(isA<ProgramManagerException>()));
      });
    });

    group('Statistics and Monitoring', () {
      test('should provide comprehensive statistics', () async {
        final program = createMockProgram('test_program');
        await manager.registerProgram('test_program', program);

        manager.resourceManager.registerProvider('provider1', provider);
        manager.resourceManager.setCachedValue('key1', 'value1');

        final stats = manager.getStats();

        expect(stats['registry'], isA<Map<String, dynamic>>());
        expect(stats['resources'], isA<Map<String, dynamic>>());
        expect(stats['loadingPrograms'], isA<int>());

        final registryStats = stats['registry'] as Map<String, dynamic>;
        expect(registryStats['totalPrograms'], equals(1));
      });

      test('should track registry state counts', () async {
        final program1 = createMockProgram('program1');
        final program2 = createMockProgram('program2');

        await manager.registerProgram('program1', program1);
        await manager.registerProgram('program2', program2,
            autoInitialize: false,);

        final stats = manager.registry.getStats();
        final stateCount = stats['stateCount'] as Map<String, dynamic>;

        expect(stateCount['ready'], equals(1));
        expect(stateCount['loaded'], equals(1));
      });
    });

    group('Cleanup and Disposal', () {
      test('should dispose cleanly', () async {
        final program = createMockProgram('test_program');
        await manager.registerProgram('test_program', program);

        manager.resourceManager.registerProvider('provider1', provider);

        await manager.dispose();

        expect(manager.registry.programNames, isEmpty);
        expect(manager.resourceManager.getStats()['providers'], equals(0));
      });
    });
  });

  group('ProgramDependency', () {
    test('should create from map', () {
      final map = {
        'name': 'test_dep',
        'programId': '11111111111111111111111111111111',
        'version': '1.0.0',
        'required': false,
        'features': ['feature1', 'feature2'],
      };

      final dep = ProgramDependency.fromMap(map);

      expect(dep.name, equals('test_dep'));
      expect(dep.programId?.toBase58(),
          equals('11111111111111111111111111111111'),);
      expect(dep.version, equals('1.0.0'));
      expect(dep.required, isFalse);
      expect(dep.features, equals(['feature1', 'feature2']));
    });

    test('should convert to map', () {
      final dep = ProgramDependency(
        name: 'test_dep',
        programId: PublicKey.fromBase58('11111111111111111111111111111111'),
        version: '1.0.0',
        required: false,
        features: ['feature1'],
      );

      final map = dep.toMap();

      expect(map['name'], equals('test_dep'));
      expect(map['programId'], equals('11111111111111111111111111111111'));
      expect(map['version'], equals('1.0.0'));
      expect(map['required'], isFalse);
      expect(map['features'], equals(['feature1']));
    });
  });
}

/// Helper function to create mock programs for testing
Program createMockProgram(String name, {PublicKey? programId}) {
  final idl = Idl(
    name: name,
    version: '0.1.0',
    instructions: [],
  );

  final id =
      programId ?? PublicKey.fromBase58('11111111111111111111111111111111');

  return Program.withProgramId(
    idl,
    id,
    provider: AnchorProvider(
      Connection('https://api.devnet.solana.com'),
      MockWallet(),
    ),
  );
}

/// Mock wallet for testing
class MockWallet extends Wallet {
  @override
  PublicKey get publicKey =>
      PublicKey.fromBase58('11111111111111111111111111111111');

  @override
  Future<Transaction> signTransaction(Transaction transaction) async => transaction;

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions,) async => transactions;

  @override
  Future<Uint8List> signMessage(Uint8List message) async => Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
}
