import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Mock IDL for testing
const mockIdl = Idl(
  address: '11111111111111111111111111111112',
  metadata: IdlMetadata(
    name: 'test_program',
    version: '1.0.0',
    spec: '0.1.0',
  ),
  instructions: [],
  accounts: [],
  types: [],
);

const mockIdl2 = Idl(
  address: '11111111111111111111111111111113',
  metadata: IdlMetadata(
    name: 'program1',
    version: '1.0.0',
    spec: '0.1.0',
  ),
  instructions: [],
  accounts: [],
  types: [],
);

const mockIdl3 = Idl(
  address: '11111111111111111111111111111114',
  metadata: IdlMetadata(
    name: 'program2',
    version: '1.0.0',
    spec: '0.1.0',
  ),
  instructions: [],
  accounts: [],
  types: [],
);

void main() {
  group('CpiFramework', () {
    late ProgramManager programManager;
    late AnchorProvider provider;
    late CpiFramework cpiFramework;

    setUp(() {
      programManager = ProgramManager();
      // Create a mock provider for testing
      provider = AnchorProvider.defaultProvider();
      cpiFramework = CpiFramework(
        programManager: programManager,
        provider: provider,
      );
    });

    group('CpiAuthority', () {
      test('should create signer authority', () {
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
        final authority = CpiAuthority.signer(pubkey);

        expect(authority.publicKey, equals(pubkey));
        expect(authority.isSigner, isTrue);
        expect(authority.isMutable, isFalse);
        expect(authority.isPda, isFalse);
      });

      test('should create mutable authority', () {
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
        final authority = CpiAuthority.mutable(pubkey);

        expect(authority.publicKey, equals(pubkey));
        expect(authority.isSigner, isFalse);
        expect(authority.isMutable, isTrue);
        expect(authority.isPda, isFalse);
      });

      test('should create PDA authority', () {
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111113');
        final seeds = [
          [1, 2, 3],
          [4, 5, 6]
        ];
        final authority = CpiAuthority.pda(
          publicKey: pubkey,
          seeds: seeds,
          programId: programId,
          isSigner: true,
          isMutable: true,
        );

        expect(authority.publicKey, equals(pubkey));
        expect(authority.isSigner, isTrue);
        expect(authority.isMutable, isTrue);
        expect(authority.isPda, isTrue);
        expect(authority.seeds, equals(seeds));
        expect(authority.programId, equals(programId));
      });
    });

    group('CpiAccountDependency', () {
      test('should create account dependency', () {
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
        final owner = PublicKey.fromBase58('11111111111111111111111111111113');
        final discriminator = [1, 2, 3, 4];

        final dependency = CpiAccountDependency(
          publicKey: pubkey,
          owner: owner,
          isRequired: true,
          shouldValidate: true,
          expectedSize: 100,
          discriminator: discriminator,
        );

        expect(dependency.publicKey, equals(pubkey));
        expect(dependency.owner, equals(owner));
        expect(dependency.isRequired, isTrue);
        expect(dependency.shouldValidate, isTrue);
        expect(dependency.expectedSize, equals(100));
        expect(dependency.discriminator, equals(discriminator));
      });
    });

    group('CpiConfig', () {
      test('should create default config', () {
        const config = CpiConfig();

        expect(config.maxDepth, equals(10));
        expect(config.enableAccountValidation, isTrue);
        expect(config.enableSignerPropagation, isTrue);
        expect(config.enableOptimization, isTrue);
        expect(config.enableDebugging, isFalse);
        expect(config.maxAccountsPerCall, equals(255));
      });

      test('should create production config', () {
        const config = CpiConfig.production;

        expect(config.enableAccountValidation, isTrue);
        expect(config.enableSignerPropagation, isTrue);
        expect(config.enableOptimization, isTrue);
        expect(config.enableDebugging, isFalse);
      });

      test('should create development config', () {
        const config = CpiConfig.development;

        expect(config.enableAccountValidation, isTrue);
        expect(config.enableSignerPropagation, isTrue);
        expect(config.enableOptimization, isFalse);
        expect(config.enableDebugging, isTrue);
      });
    });

    group('CpiInvocationContext', () {
      test('should create invocation context', () {
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        const instructionName = 'test_instruction';
        final arguments = {'arg1': 'value1'};

        final context = CpiInvocationContext(
          programId: programId,
          instructionName: instructionName,
          arguments: arguments,
        );

        expect(context.programId, equals(programId));
        expect(context.instructionName, equals(instructionName));
        expect(context.arguments, equals(arguments));
        expect(context.accounts, isEmpty);
        expect(context.authorities, isEmpty);
        expect(context.signers, isEmpty);
        expect(context.nestedInvocations, isEmpty);
        expect(context.depth, equals(1));
      });

      test('should calculate depth correctly with nested invocations', () {
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final nestedContext = CpiInvocationContext(
          programId: programId,
          instructionName: 'nested',
        );

        final context = CpiInvocationContext(
          programId: programId,
          instructionName: 'parent',
          nestedInvocations: [nestedContext],
        );

        expect(context.depth, equals(2));
      });

      test('should copy with modifications', () {
        final programId1 =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final programId2 =
            PublicKey.fromBase58('11111111111111111111111111111113');

        final context = CpiInvocationContext(
          programId: programId1,
          instructionName: 'original',
        );

        final copied = context.copyWith(
          programId: programId2,
          instructionName: 'modified',
        );

        expect(copied.programId, equals(programId2));
        expect(copied.instructionName, equals('modified'));
        expect(context.programId, equals(programId1)); // Original unchanged
      });
    });

    group('CpiValidationResult', () {
      test('should create successful result', () {
        final result = CpiValidationResult.success(
          warnings: ['warning1'],
          metadata: {'key': 'value'},
        );

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.warnings, equals(['warning1']));
        expect(result.metadata, equals({'key': 'value'}));
      });

      test('should create failure result', () {
        final result = CpiValidationResult.failure(
          errors: ['error1', 'error2'],
          warnings: ['warning1'],
          metadata: {'key': 'value'},
        );

        expect(result.isValid, isFalse);
        expect(result.errors, equals(['error1', 'error2']));
        expect(result.warnings, equals(['warning1']));
        expect(result.metadata, equals({'key': 'value'}));
      });
    });

    group('CpiStatistics', () {
      test('should initialize with zero values', () {
        final stats = CpiStatistics();

        expect(stats.totalCalls, equals(0));
        expect(stats.successfulCalls, equals(0));
        expect(stats.failedCalls, equals(0));
        expect(stats.averageExecutionTime, equals(0.0));
        expect(stats.maxDepthEncountered, equals(0));
        expect(stats.totalAccountsProcessed, equals(0));
        expect(stats.totalAuthoritiesHandled, equals(0));
        expect(stats.successRate, equals(0.0));
      });

      test('should calculate success rate correctly', () {
        final stats = CpiStatistics();
        stats.totalCalls = 10;
        stats.successfulCalls = 8;
        stats.failedCalls = 2;

        expect(stats.successRate, equals(80.0));
      });

      test('should reset statistics', () {
        final stats = CpiStatistics();
        stats.totalCalls = 10;
        stats.successfulCalls = 8;
        stats.failedCalls = 2;
        stats.averageExecutionTime = 100.0;
        stats.maxDepthEncountered = 5;
        stats.totalAccountsProcessed = 50;
        stats.totalAuthoritiesHandled = 20;

        stats.reset();

        expect(stats.totalCalls, equals(0));
        expect(stats.successfulCalls, equals(0));
        expect(stats.failedCalls, equals(0));
        expect(stats.averageExecutionTime, equals(0.0));
        expect(stats.maxDepthEncountered, equals(0));
        expect(stats.totalAccountsProcessed, equals(0));
        expect(stats.totalAuthoritiesHandled, equals(0));
      });
    });

    group('CpiBuilder', () {
      test('should build simple invocation', () {
        // Register a test program
        final program = Program(mockIdl, provider: provider);
        programManager.registry.registerProgram('test_program', program);

        final context = cpiFramework
            .builder()
            .invoke('test_program', 'test_instruction')
            .build();

        expect(context.programId, equals(program.programId));
        expect(context.instructionName, equals('test_instruction'));
      });

      test('should add accounts and authorities', () {
        // Register a test program
        final program = Program(mockIdl, provider: provider);
        programManager.registry.registerProgram('test_program', program);

        final accountKey =
            PublicKey.fromBase58('11111111111111111111111111111113');
        final authority = CpiAuthority.signer(accountKey);

        final context = cpiFramework
            .builder()
            .invoke('test_program', 'test_instruction')
            .account('test_account', accountKey)
            .authority('test_authority', authority)
            .build();

        expect(context.accounts.length, equals(1));
        expect(context.accounts.first.publicKey, equals(accountKey));
        expect(context.authorities.length, equals(1));
        expect(context.authorities.first.publicKey, equals(accountKey));
      });

      test('should handle nested invocations', () {
        // Register test programs
        final program1 = Program(mockIdl2, provider: provider);
        final program2 = Program(mockIdl3, provider: provider);

        programManager.registry.registerProgram('program1', program1);
        programManager.registry.registerProgram('program2', program2);

        final context = cpiFramework
            .builder()
            .invoke('program1', 'instruction1')
            .invoke('program2', 'instruction2') // nested
            .endInvoke()
            .build();

        expect(context.programId, equals(program1.programId));
        expect(context.instructionName, equals('instruction1'));
        expect(context.nestedInvocations.length, equals(1));
        expect(context.nestedInvocations.first.programId,
            equals(program2.programId));
        expect(context.depth, equals(2));
      });

      test('should throw error for unknown program', () {
        expect(
          () => cpiFramework.builder().invoke('unknown_program', 'test'),
          throwsA(isA<CpiException>()),
        );
      });

      test('should clear builder state', () {
        final builder = cpiFramework.builder();
        builder.clear();

        expect(
          () => builder.build(),
          throwsA(isA<CpiException>()),
        );
      });
    });

    group('CpiCoordinator', () {
      test('should validate invocation context', () {
        final program = Program(mockIdl, provider: provider);
        programManager.registry.registerProgram('test_program', program);

        final context = CpiInvocationContext(
          programId: program.programId,
          instructionName: 'test_instruction',
        );

        final result = cpiFramework.coordinator.validateInvocation(context);
        expect(result.isValid, isTrue);
      });

      test('should detect depth limit violations', () {
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        // Create nested contexts that exceed depth limit
        var context = CpiInvocationContext(
          programId: programId,
          instructionName: 'test',
        );

        // Create a deeply nested context (depth > 10)
        for (int i = 0; i < 12; i++) {
          context = CpiInvocationContext(
            programId: programId,
            instructionName: 'nested_$i',
            nestedInvocations: [context],
          );
        }

        final result = cpiFramework.coordinator.validateInvocation(context);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('exceeds maximum')));
      });

      test('should create builder', () {
        final builder = cpiFramework.coordinator.builder();
        expect(builder, isA<CpiBuilder>());
      });
    });

    group('CpiFramework Integration', () {
      test('should provide access to coordinator', () {
        expect(cpiFramework.coordinator, isA<CpiCoordinator>());
      });

      test('should provide access to builder', () {
        expect(cpiFramework.builder(), isA<CpiBuilder>());
      });

      test('should validate contexts', () {
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final context = CpiInvocationContext(
          programId: programId,
          instructionName: 'test',
        );

        final result = cpiFramework.validate(context);
        expect(result, isA<CpiValidationResult>());
      });

      test('should access statistics', () {
        expect(cpiFramework.statistics, isA<CpiStatistics>());
      });

      test('should reset statistics', () {
        cpiFramework.resetStatistics();
        expect(cpiFramework.statistics.totalCalls, equals(0));
      });
    });

    group('Error Handling', () {
      test('should throw CpiException for invalid operations', () {
        expect(
          () => cpiFramework.builder().account(
              'test', PublicKey.fromBase58('11111111111111111111111111111112')),
          throwsA(isA<CpiException>()),
        );
      });

      test('should handle validation errors gracefully', () {
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final context = CpiInvocationContext(
          programId: programId,
          instructionName: 'nonexistent',
        );

        final result = cpiFramework.validate(context);
        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
      });
    });
  });
}
