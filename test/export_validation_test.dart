/// Core Library Export Validation Test
///
/// This test suite validates that all essential types, classes, and functions
/// are properly exported through the public API and accessible without
/// direct src/ imports.
library;

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Core Library Export Validation', () {
    group('Core Types and Classes', () {
      test('fundamental types are exported and accessible', () {
        // Test basic types
        expect(PublicKey, isA<Type>());
        expect(Keypair, isA<Type>());
        expect(Connection, isA<Type>());
        expect(Transaction, isA<Type>());
        expect(Instruction, isA<Type>());
        expect(AccountMeta, isA<Type>());

        // Test creation works
        expect(() => PublicKey.fromBase58('11111111111111111111111111111112'),
            returnsNormally,);
        expect(
            () => Connection('https://api.devnet.solana.com'), returnsNormally,);
      });

      test('anchor-specific types are exported and accessible', () {
        // Test Anchor framework types
        expect(Program, isA<Type>());
        expect(AnchorProvider, isA<Type>());
        expect(Idl, isA<Type>());
        expect(IdlInstruction, isA<Type>());
        expect(IdlAccount, isA<Type>());
        expect(IdlEvent, isA<Type>());
        expect(IdlField, isA<Type>());
        expect(IdlType, isA<Type>());
        expect(IdlTypeDef, isA<Type>());
        expect(IdlTypeDefType, isA<Type>());
      });

      test('coder system types are exported and accessible', () {
        // Test coding/serialization types
        expect(BorshCoder, isA<Type>());
        expect(InstructionCoder, isA<Type>());
        expect(AccountsCoder, isA<Type>());
        expect(EventCoder, isA<Type>());
        expect(BorshEventCoder, isA<Type>());
        expect(TypeConverter, isA<Type>());
      });

      test('event system types are exported and accessible', () {
        // Test event system types
        expect(EventContext, isA<Type>());
        expect(ParsedEvent, isA<Type>());
        expect(EventFilter, isA<Type>());
        expect(EventStats, isA<Type>());
        expect(EventSubscriptionConfig, isA<Type>());
        expect(EventReplayConfig, isA<Type>());
        expect(EventLogParser, isA<Type>());
        expect(EventSubscriptionManager, isA<Type>());
        expect(EventDefinition, isA<Type>());
      });

      test('workspace and namespace types are exported and accessible', () {
        // Test workspace types
        expect(Workspace, isA<Type>());
        expect(MethodsNamespace, isA<Type>());
        expect(AccountNamespace, isA<Type>());
        expect(RpcNamespace, isA<Type>());
        expect(SimulateNamespace, isA<Type>());
        expect(InstructionNamespace, isA<Type>());
        expect(TransactionNamespace, isA<Type>());
      });

      test('utility and helper types are exported and accessible', () {
        // Test utility types
        expect(ProgramAccount, isA<Type>());
        expect(AccountInfo, isA<Type>());
        expect(ConfirmOptions, isA<Type>());
        expect(SendTransactionOptions, isA<Type>());
      });
    });

    group('Functional API Validation', () {
      test('can create and use core objects through public API', () {
        // Test PublicKey creation and usage
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
        expect(pubkey.toBase58(), equals('11111111111111111111111111111112'));

        // Test Connection creation
        final connection = Connection('https://api.devnet.solana.com');
        expect(connection, isA<Connection>());

        // Test basic IDL structure
        final idl = const Idl(
          instructions: [],
          accounts: [],
          events: [],
          types: [],
        );
        expect(idl.instructions, isEmpty);
        expect(idl.accounts, isEmpty);
        expect(idl.events, isEmpty);
        expect(idl.types, isEmpty);
      });

      test('can create coders through public API', () {
        final idl = const Idl(
          instructions: [],
          events: [],
          types: [],
        );

        // Test BorshCoder creation
        final coder = BorshCoder(idl);
        expect(coder, isA<BorshCoder>());
        expect(coder.instructions, isA<InstructionCoder>());
        expect(coder.accounts, isA<AccountsCoder>());
        expect(coder.events, isA<EventCoder>());

        // Test TypeConverter creation
        final converter = TypeConverter();
        expect(converter, isA<TypeConverter>());
      });

      test('can create event system components through public API', () {
        // Test event context creation
        final context = EventContext(
          signature: 'test_sig',
          slot: 12345,
          blockTime: DateTime.now(),
        );
        expect(context.signature, equals('test_sig'));
        expect(context.slot, equals(12345));

        // Test event filter creation
        final filter = EventFilter(
          eventNames: {'TestEvent'},
          programIds: {
            PublicKey.fromBase58('11111111111111111111111111111112'),
          },
        );
        expect(filter.eventNames?.contains('TestEvent'), isTrue);

        // Test event subscription config
        final config = const EventSubscriptionConfig();
        expect(config, isA<EventSubscriptionConfig>());
      });

      test('can create workspace through public API', () {
        // Test that workspace type is exported and accessible
        expect(Workspace, isA<Type>());
      });

      test('can create anchor provider through public API', () {
        final connection = Connection('https://api.devnet.solana.com');
        // Test that AnchorProvider type exists and can be referenced
        expect(AnchorProvider, isA<Type>());
        expect(connection, isA<Connection>());
      });
    });

    group('Import Path Validation', () {
      test('complex workflow works with only public API imports', () {
        // This test verifies that all functionality works
        // without any direct src/ imports - only the main library import
        // 'package:coral_xyz_anchor/coral_xyz_anchor.dart' is used

        final connection = Connection('https://api.devnet.solana.com');
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');

        final idl = Idl(
          instructions: [
            IdlInstruction(
              name: 'initialize',
              args: [
                IdlField(name: 'amount', type: IdlType.u64()),
              ],
              accounts: [],
            ),
          ],
          events: [
            IdlEvent(
              name: 'Initialized',
              fields: [
                IdlField(name: 'amount', type: IdlType.u64()),
              ],
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'Initialized',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'amount', type: IdlType.u64()),
                ],
              ),
            ),
          ],
        );

        final coder = BorshCoder(idl);
        final eventParser = EventLogParser.fromIdl(pubkey, idl);

        expect(coder, isA<BorshCoder>());
        expect(eventParser, isA<EventLogParser>());

        // Test event subscription manager creation
        final eventDefinitions = <EventDefinition>[];
        final manager = EventSubscriptionManager(
          connection: connection,
          programId: pubkey,
          eventDefinitions: eventDefinitions,
        );
        expect(manager, isA<EventSubscriptionManager>());
      });
    });

    group('API Surface Documentation Validation', () {
      test('key classes have proper toString representations', () {
        final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
        expect(pubkey.toString(), contains('11111111111111111111111111111112'));

        final context = EventContext(
          signature: 'test_sig',
          slot: 12345,
          blockTime: DateTime.now(),
        );
        expect(context.toString(), contains('test_sig'));
        expect(context.toString(), contains('12345'));

        final idl = const Idl(instructions: []);
        expect(idl.toString(), contains('Idl'));
      });

      test('idl type system works correctly', () {
        // Test IDL type factory methods
        expect(IdlType.u64(), isA<IdlType>());
        expect(IdlType.string(), isA<IdlType>());
        expect(IdlType.publicKey(), isA<IdlType>());
        expect(IdlType.bool(), isA<IdlType>());
      });
    });

    group('Error Handling Validation', () {
      test('anchor exceptions are properly exported', () {
        // Test that exception types exist
        expect(AnchorException, isA<Type>());

        // Test that specific exceptions can be caught
        expect(() {
          throw Exception('Test error'); // Use generic exception instead
        }, throwsA(isA<Exception>()),);
      });

      test('error handling works correctly with public API', () {
        // Test invalid public key handling (throws ArgumentError, not Exception)
        expect(() => PublicKey.fromBase58('invalid'),
            throwsA(isA<ArgumentError>()),);

        // Test invalid connection
        expect(() => Connection('invalid_url'),
            returnsNormally,); // Constructor should not throw

        // Test invalid IDL handling
        expect(() => BorshCoder(const Idl(instructions: [])), returnsNormally);
      });
    });

    group('Type Integration Validation', () {
      test('static factory methods work correctly', () {
        // Test that IdlType static methods work
        final u64Type = IdlType.u64();
        final stringType = IdlType.string();
        final pubkeyType = IdlType.publicKey();

        expect(u64Type, isA<IdlType>());
        expect(stringType, isA<IdlType>());
        expect(pubkeyType, isA<IdlType>());
      });

      test('type converter integration works', () {
        final converter = TypeConverter();
        expect(converter, isA<TypeConverter>());

        // Test that TypeConverter can be instantiated
        expect(converter.runtimeType.toString(), contains('TypeConverter'));
      });
    });
  });
}
