import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('PDA Definition and Metadata System', () {
    late PublicKey testProgramId;
    late PdaDefinitionRegistry registry;

    setUp(() {
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111112');
      registry = PdaDefinitionRegistry();
    });

    group('PdaSeedRequirement', () {
      test('should validate string seeds correctly', () {
        final requirement = const PdaSeedRequirement(
          name: 'username',
          type: PdaSeedType.string,
          minLength: 3,
          maxLength: 20,
        );

        expect(requirement.validate('alice'), isTrue);
        expect(requirement.validate(''), isFalse);
        expect(requirement.validate('ab'), isFalse);
        expect(requirement.validate('a' * 25), isFalse);
        expect(requirement.validate(123), isFalse);
      });

      test('should validate bytes seeds correctly', () {
        final requirement = const PdaSeedRequirement(
          name: 'data',
          type: PdaSeedType.bytes,
          fixedLength: 32,
        );

        final validBytes = Uint8List(32);
        final invalidBytes = Uint8List(16);

        expect(requirement.validate(validBytes), isTrue);
        expect(requirement.validate(invalidBytes), isFalse);
        expect(requirement.validate('not bytes'), isFalse);
      });

      test('should validate PublicKey seeds correctly', () {
        final requirement = const PdaSeedRequirement(
          name: 'authority',
          type: PdaSeedType.publicKey,
        );

        final validKey =
            PublicKey.fromBase58('11111111111111111111111111111111');

        expect(requirement.validate(validKey), isTrue);
        expect(requirement.validate('not a key'), isFalse);
        expect(requirement.validate(123), isFalse);
      });

      test('should validate number seeds correctly', () {
        final requirement = const PdaSeedRequirement(
          name: 'id',
          type: PdaSeedType.number,
          allowedValues: [1, 2, 3, 5, 8, 13],
        );

        expect(requirement.validate(5), isTrue);
        expect(requirement.validate(4), isFalse);
        expect(requirement.validate('not a number'), isFalse);
      });

      test('should handle optional seeds correctly', () {
        final requirement = const PdaSeedRequirement(
          name: 'optional_id',
          type: PdaSeedType.number,
          optional: true,
        );

        expect(requirement.validate(null), isTrue);
        expect(requirement.validate(42), isTrue);
        expect(requirement.validate('invalid'), isFalse);
      });

      test('should handle default values correctly', () {
        final requirement = const PdaSeedRequirement(
          name: 'version',
          type: PdaSeedType.number,
          defaultValue: 1,
        );

        expect(requirement.validate(null), isTrue);
        expect(requirement.validate(2), isTrue);
      });

      test('should convert values to PdaSeeds correctly', () {
        final stringReq = const PdaSeedRequirement(
          name: 'test',
          type: PdaSeedType.string,
        );
        final stringSeed = stringReq.toPdaSeed('hello');
        expect(stringSeed, isA<StringSeed>());

        final bytesReq = const PdaSeedRequirement(
          name: 'data',
          type: PdaSeedType.bytes,
        );
        final bytesSeed = bytesReq.toPdaSeed(Uint8List.fromList([1, 2, 3]));
        expect(bytesSeed, isA<BytesSeed>());

        final publicKeyReq = const PdaSeedRequirement(
          name: 'authority',
          type: PdaSeedType.publicKey,
        );
        final publicKeySeed = publicKeyReq.toPdaSeed(testProgramId);
        expect(publicKeySeed, isA<PublicKeySeed>());

        final numberReq = const PdaSeedRequirement(
          name: 'id',
          type: PdaSeedType.number,
          fixedLength: 8,
        );
        final numberSeed = numberReq.toPdaSeed(42);
        expect(numberSeed, isA<NumberSeed>());
      });
    });

    group('PdaDefinition', () {
      test('should create basic PDA definition', () {
        final definition = PdaDefinition(
          name: 'user_account',
          description: 'User account PDA',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'user',
              type: PdaSeedType.publicKey,
            ),
            const PdaSeedRequirement(
              name: 'seed_string',
              type: PdaSeedType.string,
              defaultValue: 'user',
            ),
          ],
          programId: testProgramId,
          accountType: 'UserAccount',
        );

        expect(definition.name, equals('user_account'));
        expect(definition.seedRequirements.length, equals(2));
        expect(definition.programId, equals(testProgramId));
      });

      test('should validate seeds correctly', () {
        final definition = PdaDefinition(
          name: 'test_account',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'authority',
              type: PdaSeedType.publicKey,
            ),
            const PdaSeedRequirement(
              name: 'id',
              type: PdaSeedType.number,
            ),
          ],
          programId: testProgramId,
        );

        final validSeeds = {
          'authority': testProgramId,
          'id': 42,
        };

        final result = definition.validateSeeds(validSeeds);
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.resolvedSeeds.length, equals(2));
      });

      test('should handle validation errors', () {
        final definition = PdaDefinition(
          name: 'test_account',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'authority',
              type: PdaSeedType.publicKey,
            ),
            const PdaSeedRequirement(
              name: 'id',
              type: PdaSeedType.number,
            ),
          ],
          programId: testProgramId,
        );

        final invalidSeeds = {
          'authority': 'not a key',
          'id': 'not a number',
        };

        final result = definition.validateSeeds(invalidSeeds);
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2));
      });

      test('should derive PDA correctly', () {
        final definition = PdaDefinition(
          name: 'test_account',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'prefix',
              type: PdaSeedType.string,
              defaultValue: 'test',
            ),
            const PdaSeedRequirement(
              name: 'id',
              type: PdaSeedType.number,
            ),
          ],
          programId: testProgramId,
        );

        final seedValues = {'id': 42};
        final result = definition.derivePda(seedValues, null);

        expect(result, isA<PdaResult>());
        expect(result.address, isA<PublicKey>());
        expect(result.bump, isA<int>());
      });

      test('should handle inheritance correctly', () {
        final baseDefinition = PdaDefinition(
          name: 'base',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'base_seed',
              type: PdaSeedType.string,
            ),
          ],
          programId: testProgramId,
        );

        final derivedDefinition = PdaDefinition(
          name: 'derived',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'derived_seed',
              type: PdaSeedType.number,
            ),
          ],
          parent: baseDefinition,
          programId: testProgramId,
        );

        expect(derivedDefinition.inheritsFrom(baseDefinition), isTrue);

        final allRequirements = derivedDefinition.getAllSeedRequirements();
        expect(allRequirements.length, equals(2));
        expect(allRequirements[0].name, equals('base_seed'));
        expect(allRequirements[1].name, equals('derived_seed'));
      });

      test('should create definition from IDL account', () {
        final account = const IdlAccount(
          name: 'UserAccount',
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [],
          ),
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        );

        final definition = PdaDefinition.fromIdlAccount(account, testProgramId);

        expect(definition, isNotNull);
        expect(definition!.name, equals('UserAccount'));
        expect(definition.seedRequirements, isNotEmpty);
        expect(definition.programId, equals(testProgramId));
        expect(definition.metadata?['auto_generated'], isTrue);
      });

      test('should handle accounts without meaningful patterns', () {
        final account = const IdlAccount(
          name: 'GenericAccount',
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [],
          ),
        );

        final definition = PdaDefinition.fromIdlAccount(account, testProgramId);

        // Should not create definition for generic account without patterns
        expect(definition, isNull);
      });
    });

    group('PdaValidationResult', () {
      test('should create validation result correctly', () {
        final result = const PdaValidationResult(
          isValid: false,
          errors: ['Error 1', 'Error 2'],
          warnings: ['Warning 1'],
          resolvedSeeds: [],
        );

        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2));
        expect(result.warnings.length, equals(1));
        expect(result.resolvedSeeds, isEmpty);
      });
    });

    group('PdaValidationException', () {
      test('should create exception correctly', () {
        final exception = const PdaValidationException('Test error');

        expect(exception.message, equals('Test error'));
        expect(exception.toString(), contains('Test error'));
      });
    });

    group('PdaDefinitionRegistry', () {
      test('should register and retrieve definitions', () {
        final definition = PdaDefinition(
          name: 'test_account',
          seedRequirements: [],
          programId: testProgramId,
        );

        registry.register(definition);

        final retrieved = registry.getDefinition('test_account');
        expect(retrieved, isNotNull);
        expect(retrieved!.name, equals('test_account'));
      });

      test('should get definitions for program', () {
        final def1 = PdaDefinition(
          name: 'account1',
          seedRequirements: [],
          programId: testProgramId,
        );

        final def2 = PdaDefinition(
          name: 'account2',
          seedRequirements: [],
          programId: testProgramId,
        );

        final otherProgramId =
            PublicKey.fromBase58('11111111111111111111111111111113');
        final def3 = PdaDefinition(
          name: 'account3',
          seedRequirements: [],
          programId: otherProgramId,
        );

        registry.register(def1);
        registry.register(def2);
        registry.register(def3);

        final programDefs = registry.getDefinitionsForProgram(testProgramId);
        expect(programDefs.length, equals(2));
        expect(programDefs.map((d) => d.name),
            containsAll(['account1', 'account2']),);
      });

      test('should register from IDL', () {
        final idl = const Idl(
          instructions: [],
          accounts: [
            IdlAccount(
              name: 'UserAccount',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [],
              ),
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
            IdlAccount(
              name: 'MintInfo',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [],
              ),
              discriminator: [9, 10, 11, 12, 13, 14, 15, 16],
            ),
          ],
        );

        registry.registerFromIdl(idl, testProgramId);

        final userDef = registry.getDefinition('UserAccount');
        final mintDef = registry.getDefinition('MintInfo');

        expect(userDef, isNotNull);
        expect(mintDef, isNotNull);
      });

      test('should find definitions by tag', () {
        final def1 = const PdaDefinition(
          name: 'account1',
          seedRequirements: [],
          tags: ['user', 'primary'],
        );

        final def2 = const PdaDefinition(
          name: 'account2',
          seedRequirements: [],
          tags: ['user', 'secondary'],
        );

        final def3 = const PdaDefinition(
          name: 'account3',
          seedRequirements: [],
          tags: ['admin'],
        );

        registry.register(def1);
        registry.register(def2);
        registry.register(def3);

        final userDefs = registry.findDefinitionsByTag('user');
        expect(userDefs.length, equals(2));
        expect(
            userDefs.map((d) => d.name), containsAll(['account1', 'account2']),);

        final primaryDefs = registry.findDefinitionsByTag('primary');
        expect(primaryDefs.length, equals(1));
        expect(primaryDefs.first.name, equals('account1'));
      });

      test('should find definitions by account type', () {
        final def1 = const PdaDefinition(
          name: 'user1',
          seedRequirements: [],
          accountType: 'UserAccount',
        );

        final def2 = const PdaDefinition(
          name: 'user2',
          seedRequirements: [],
          accountType: 'UserAccount',
        );

        final def3 = const PdaDefinition(
          name: 'mint1',
          seedRequirements: [],
          accountType: 'MintAccount',
        );

        registry.register(def1);
        registry.register(def2);
        registry.register(def3);

        final userDefs = registry.findDefinitionsByAccountType('UserAccount');
        expect(userDefs.length, equals(2));
        expect(userDefs.map((d) => d.name), containsAll(['user1', 'user2']));
      });

      test('should clear all definitions', () {
        final definition = const PdaDefinition(
          name: 'test',
          seedRequirements: [],
        );

        registry.register(definition);
        expect(registry.getAllDefinitions().length, equals(1));

        registry.clear();
        expect(registry.getAllDefinitions(), isEmpty);
      });
    });

    group('Global Registry', () {
      test('should provide global registry instance', () {
        final global1 = getGlobalPdaDefinitionRegistry();
        final global2 = getGlobalPdaDefinitionRegistry();

        expect(identical(global1, global2), isTrue);
      });

      test('should allow setting custom global registry', () {
        final customRegistry = PdaDefinitionRegistry();
        setGlobalPdaDefinitionRegistry(customRegistry);

        final globalRegistry = getGlobalPdaDefinitionRegistry();
        expect(identical(globalRegistry, customRegistry), isTrue);
      });

      test('should clear global registry', () {
        final globalRegistry = getGlobalPdaDefinitionRegistry();

        final definition = const PdaDefinition(
          name: 'test',
          seedRequirements: [],
        );
        globalRegistry.register(definition);

        expect(globalRegistry.getAllDefinitions().length, equals(1));

        clearGlobalPdaDefinitionRegistry();
        expect(globalRegistry.getAllDefinitions(), isEmpty);
      });
    });

    group('Integration Tests', () {
      test('should work with complete PDA workflow', () {
        // Create a realistic PDA definition
        final definition = PdaDefinition(
          name: 'user_token_account',
          description: 'User token account PDA',
          seedRequirements: [
            const PdaSeedRequirement(
              name: 'prefix',
              type: PdaSeedType.string,
              defaultValue: 'token',
            ),
            const PdaSeedRequirement(
              name: 'user',
              type: PdaSeedType.publicKey,
              description: 'User authority',
            ),
            const PdaSeedRequirement(
              name: 'id',
              type: PdaSeedType.number,
              description: 'Token ID',
            ),
          ],
          programId: testProgramId,
          accountType: 'UserTokenAccount',
          tags: ['token', 'user'],
        );

        // Register in global registry
        final globalRegistry = getGlobalPdaDefinitionRegistry();
        globalRegistry.register(definition);

        // Use the definition
        final userKey =
            PublicKey.fromBase58('11111111111111111111111111111111');

        final seedValues = {
          'user': userKey,
          'id': 42,
        };

        // Validate and derive PDA
        final result = definition.derivePda(seedValues, null);
        expect(result, isA<PdaResult>());
        expect(result.address, isA<PublicKey>());

        // Verify we can retrieve from registry
        final retrieved = globalRegistry.getDefinition('user_token_account');
        expect(retrieved, equals(definition));

        // Verify filtering works
        final tokenDefs = globalRegistry.findDefinitionsByTag('token');
        expect(tokenDefs, contains(definition));
      });
    });
  });
}
