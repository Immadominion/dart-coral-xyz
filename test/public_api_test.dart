import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Comprehensive test to validate the public API exports
///
/// This test ensures that all essential types and classes are accessible
/// through the main library export without requiring direct src/ imports.
void main() {
  group('Public API Export Validation', () {
    test('Core types are accessible', () {
      // These should all be accessible without direct src/ imports
      expect(PublicKey, isNotNull);
      expect(Connection, isNotNull);
      expect(AccountInfo, isNotNull);
      expect(Program, isNotNull);
    });

    test('Event system types are accessible', () {
      // Event system public API
      expect(EventContext, isNotNull);
      expect(ParsedEvent, isNotNull);
      expect(EventStats, isNotNull);
      expect(EventFilter, isNotNull);
      expect(EventSubscriptionConfig, isNotNull);
      expect(EventReplayConfig, isNotNull);
      expect(EventDefinition, isNotNull);
      expect(EventLogParser, isNotNull);
      expect(EventSubscriptionManager, isNotNull);
      expect(EventProcessor, isNotNull);
    });

    test('IDL system types are accessible', () {
      // IDL system
      expect(Idl, isNotNull);
      expect(IdlEvent, isNotNull);
      expect(IdlField, isNotNull);
      expect(IdlType, isNotNull);
      expect(IdlTypeDef, isNotNull);
      expect(IdlTypeDefType, isNotNull);
    });

    test('Account system types are accessible', () {
      // Account system
      expect(AccountDefinition, isNotNull);
      expect(AccountNamespace, isNotNull);
      expect(AccountClient, isNotNull);
      expect(AccountFetcher, isNotNull);
      expect(AccountFetcherConfig, isNotNull);
      expect(ProgramAccount, isNotNull);
    });

    test('Instruction system types are accessible', () {
      // Instruction system
      expect(InstructionDefinition, isNotNull);
      expect(InstructionBuilder, isNotNull);
    });

    test('Coder system types are accessible', () {
      // Coder system
      expect(BorshCoder, isNotNull);
      expect(EventCoder, isNotNull);
      expect(TypesCoder, isNotNull);
    });

    test('Error system types are accessible', () {
      // Error system
      expect(AnchorError, isNotNull);
      expect(ProgramError, isNotNull);
    });

    test('Provider system types are accessible', () {
      // Provider system
      expect(AnchorProvider, isNotNull);
      expect(SendTransactionOptions, isNotNull);
      expect(RpcTransactionConfirmation, isNotNull);
    });

    test('Namespace types are accessible', () {
      // Namespace system
      expect(NamespaceFactory, isNotNull);
      expect(MethodsNamespace, isNotNull);
      expect(RpcNamespace, isNotNull);
      expect(SimulateNamespace, isNotNull);
      expect(TransactionNamespace, isNotNull);
    });

    test('Transaction system types are accessible', () {
      // Transaction system
      expect(TransactionSimulator, isNotNull);
      expect(PreflightValidator, isNotNull);
      expect(ComputeUnitAnalyzer, isNotNull);
      expect(SimulationResultProcessor, isNotNull);
    });

    test('Utility types are accessible', () {
      // Utilities
      expect(PdaUtils, isNotNull);
      expect(AddressResolver, isNotNull);
    });

    test('PDA (Program Derived Address) types are accessible', () {
      // PDA derivation engine public API
      expect(PdaDerivationEngine, isNotNull);
      expect(PdaResult, isNotNull);
      expect(PdaDerivationException, isNotNull);
      expect(PdaSeed, isNotNull);
      expect(StringSeed, isNotNull);
      expect(BytesSeed, isNotNull);
      expect(PublicKeySeed, isNotNull);
      expect(NumberSeed, isNotNull);
      expect(PdaUtils, isNotNull);

      // PDA caching system
      expect(PdaCache, isNotNull);
      expect(PdaCacheKey, isNotNull);
      expect(PdaCacheEntry, isNotNull);
      expect(PdaCacheStats, isNotNull);

      // PDA definition and metadata system
      expect(PdaDefinition, isNotNull);
      expect(PdaSeedRequirement, isNotNull);
      expect(PdaSeedType, isNotNull);
      expect(PdaValidationResult, isNotNull);
      expect(PdaValidationException, isNotNull);
      expect(PdaDefinitionRegistry, isNotNull);
    });

    test('Filter utilities are accessible', () {
      // Filter functions should be accessible
      expect(memcmpFilter, isNotNull);
      expect(dataSizeFilter, isNotNull);
      expect(tokenAccountFilter, isNotNull);
    });

    test('Workspace configuration types are accessible', () {
      // Workspace configuration system
      expect(WorkspaceConfig, isNotNull);
      expect(ProviderConfig, isNotNull);
      expect(ProgramEntry, isNotNull);
      expect(TestConfig, isNotNull);
      expect(ValidatorAccount, isNotNull);
      expect(FeaturesConfig, isNotNull);
      expect(ScriptsConfig, isNotNull);
      expect(WorkspaceConfigException, isNotNull);
    });
  });

  group('Public API Functionality Validation', () {
    test('Can create and use core objects through public API', () {
      // Test that we can actually instantiate and use objects from public API
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      expect(programId, isNotNull);
      expect(programId.toBase58(), equals('11111111111111111111111111111111'));

      final connection = Connection('https://api.devnet.solana.com');
      expect(connection, isNotNull);
      expect(connection.rpcUrl, equals('https://api.devnet.solana.com'));
    });

    test('Can create EventContext through public API', () {
      final context = EventContext(
        slot: 12345,
        signature: 'test_signature',
        blockTime: DateTime.now(),
      );

      expect(context.slot, equals(12345));
      expect(context.signature, equals('test_signature'));
      expect(context.blockTime, isNotNull);
    });

    test('Can create EventFilter through public API', () {
      final filter = const EventFilter(
        eventNames: {'TestEvent'},
        minSlot: 1000,
        maxSlot: 2000,
      );

      expect(filter, isNotNull);
      expect(filter.eventNames, contains('TestEvent'));
      expect(filter.minSlot, equals(1000));
      expect(filter.maxSlot, equals(2000));
      expect(filter.includeFailed, equals(false));
    });

    test('Can create basic IDL through public API', () {
      final idl = const Idl(
        instructions: [],
        events: [
          IdlEvent(
            name: 'TestEvent',
            fields: [
              IdlField(
                name: 'flag',
                type: IdlType(kind: 'bool'),
              ),
            ],
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          ),
        ],
      );

      expect(idl, isNotNull);
      expect(idl.events, isNotNull);
      expect(idl.events!.length, equals(1));
      expect(idl.events!.first.name, equals('TestEvent'));
    });

    test('Can use PDA derivation through public API', () {
      // Test that we can create and use PDA functionality from public API
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');

      // Test seed creation
      final stringSeed = const StringSeed('test');
      final bytesSeed = BytesSeed(Uint8List.fromList([1, 2, 3]));

      expect(stringSeed, isNotNull);
      expect(bytesSeed, isNotNull);
      expect(stringSeed.toDebugString(), equals('String("test")'));

      // Test PDA derivation using static methods
      final result =
          PdaDerivationEngine.findProgramAddress([stringSeed], programId);
      expect(result, isNotNull);
      expect(result.address, isA<PublicKey>());
      expect(result.bump, isA<int>());
      expect(result.bump, inInclusiveRange(0, 255));

      // Test PDA creation with known bump
      final address = PdaDerivationEngine.createProgramAddress(
          [stringSeed, NumberSeed(result.bump, byteLength: 1)], programId,);
      expect(address, equals(result.address));
    });

    test('Can create workspace configuration objects through public API', () {
      // Test that we can create workspace configuration objects
      final providerConfig = const ProviderConfig(
        cluster: 'localnet',
        wallet: '~/.config/solana/id.json',
      );
      expect(providerConfig, isNotNull);
      expect(providerConfig.cluster, equals('localnet'));

      final programEntry = const ProgramEntry(
        address: '11111111111111111111111111111111',
        idl: 'target/idl/test.json',
      );
      expect(programEntry, isNotNull);
      expect(programEntry.address, equals('11111111111111111111111111111111'));

      final workspaceConfig = WorkspaceConfig(
        provider: providerConfig,
        programs: {
          'localnet': {'test_program': programEntry},
        },
      );
      expect(workspaceConfig, isNotNull);
      expect(workspaceConfig.provider, equals(providerConfig));
      expect(workspaceConfig.programs['localnet']?['test_program'],
          equals(programEntry),);
    });
  });

  group('Import Path Validation', () {
    test('No direct src/ imports should be needed', () {
      // This test verifies that all necessary types are available
      // through the main export without requiring any src/ imports
      // If this test compiles and runs, it means our public API is complete

      // Try to create a comprehensive workflow using only public API
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final connection = Connection('https://api.devnet.solana.com');
      final provider = AnchorProvider(connection, MockWallet());

      final idl = Idl(instructions: [], address: programId.toBase58());
      final program = Program(idl, provider: provider);

      expect(program, isNotNull);
      expect(program.programId, equals(programId));
      expect(program.provider, equals(provider));
    });
  });
}

/// Mock wallet for testing purposes
class MockWallet extends Wallet {
  @override
  PublicKey get publicKey =>
      PublicKey.fromBase58('11111111111111111111111111111111');

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    return transaction; // Mock implementation - return unsigned transaction
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions,) async {
    return transactions; // Mock implementation - return unsigned transactions
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    return message; // Mock implementation - return message as signature
  }
}
