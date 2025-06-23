/// Comprehensive event system integration test
///
/// This test validates the complete event system integration including
/// BorshEventCoder delegation, Connection.onLogs integration, and
/// TypeScript compatibility patterns.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Event System Integration', () {
    group('Type Export Integration', () {
      test('all event types accessible through public API', () {
        // Test that key event types are accessible without direct src/ imports
        expect(EventContext, isA<Type>());
        expect(ParsedEvent, isA<Type>());
        expect(EventStats, isA<Type>());
        expect(EventFilter, isA<Type>());
        expect(EventSubscriptionConfig, isA<Type>());
        expect(EventReplayConfig, isA<Type>());
      });

      test('event context creation and usage', () {
        final context = EventContext(
          signature: 'test_signature',
          slot: 12345,
          blockTime: DateTime.now(),
        );

        expect(context.signature, equals('test_signature'));
        expect(context.slot, equals(12345));
        expect(context.blockTime, isA<DateTime>());
      });

      test('event filters work correctly', () {
        final filter = EventFilter(
          eventNames: {'TestEvent'},
          programIds: {
            PublicKey.fromBase58('11111111111111111111111111111112')
          },
          maxSlot: 100,
        );

        expect(filter.eventNames?.contains('TestEvent'), isTrue);
        expect(filter.programIds?.length, equals(1));
        expect(filter.maxSlot, equals(100));

        // Create a test event for filter matching
        final testEvent = ParsedEvent(
          name: 'TestEvent',
          data: {'test': 'data'},
          context: EventContext(
            signature: 'test_sig',
            slot: 50,
            blockTime: DateTime.now(),
          ),
          eventDef: IdlEvent(
            name: 'TestEvent',
            fields: [IdlField(name: 'test', type: IdlType.string())],
          ),
        );

        final testProgramId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final nonMatchingProgramId =
            PublicKey.fromBase58('So11111111111111111111111111111111111111112');

        expect(filter.matches(testEvent, testProgramId), isTrue);
        expect(filter.matches(testEvent, nonMatchingProgramId), isFalse);
      });
    });

    group('BorshEventCoder Integration', () {
      test('BorshEventCoder accessible through main coder system', () {
        final idl = Idl(
          instructions: [],
          events: [
            IdlEvent(
              name: 'TestEvent',
              fields: [
                IdlField(name: 'value', type: IdlType.u64()),
                IdlField(name: 'message', type: IdlType.string()),
              ],
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'TestEvent',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'value', type: IdlType.u64()),
                  IdlField(name: 'message', type: IdlType.string()),
                ],
              ),
            ),
          ],
        );

        final coder = BorshCoder(idl);
        expect(coder.events, isA<EventCoder>());
        expect(coder.events, isA<BorshEventCoder>());
      });

      test('event decoding delegation works correctly', () {
        final idl = Idl(
          instructions: [],
          events: [
            IdlEvent(
              name: 'TestEvent',
              fields: [
                IdlField(name: 'value', type: IdlType.u32()),
              ],
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'TestEvent',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'value', type: IdlType.u32()),
                ],
              ),
            ),
          ],
        );

        final eventCoder = BorshEventCoder(idl);

        // Test that the EventCoder interface is properly implemented
        expect(eventCoder.decode('invalid_log'), isNull);

        // The decode method should handle invalid logs gracefully
        expect(() => eventCoder.decode(''), returnsNormally);
        expect(() => eventCoder.decode('not_base64'), returnsNormally);
      });

      test('event parser uses BorshEventCoder delegation', () {
        final idl = Idl(
          instructions: [],
          events: [
            IdlEvent(
              name: 'MyEvent',
              fields: [
                IdlField(name: 'data', type: IdlType.string()),
              ],
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'MyEvent',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'data', type: IdlType.string()),
                ],
              ),
            ),
          ],
        );

        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final parser = EventLogParser.fromIdl(programId, idl);

        // Parser should have BorshEventCoder integration
        expect(parser, isA<EventLogParser>());

        // Test that parser handles invalid logs gracefully
        final result = parser.parseLogs(['Program log: invalid']);
        expect(result.length, equals(0));
      });
    });

    group('EventSubscriptionManager Integration', () {
      test('event subscription manager can be created with proper parameters',
          () {
        // Create mock dependencies
        final connection = Connection('https://api.devnet.solana.com');
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final eventDefinitions = <EventDefinition>[];
        final config = EventSubscriptionConfig();

        final manager = EventSubscriptionManager(
          connection: connection,
          programId: programId,
          eventDefinitions: eventDefinitions,
          config: config,
        );

        expect(manager, isA<EventSubscriptionManager>());
        expect(manager.connectionState, equals(ConnectionState.disconnected));
        expect(manager.eventStream, isA<Stream>());
        expect(manager.metrics, isA<EventSubscriptionMetrics>());
      });

      test('event subscription follows TypeScript onLogs pattern', () {
        final connection = Connection('https://api.devnet.solana.com');
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final eventDefinitions = <EventDefinition>[];
        final config = EventSubscriptionConfig();

        final manager = EventSubscriptionManager(
          connection: connection,
          programId: programId,
          eventDefinitions: eventDefinitions,
          config: config,
        );

        final subscription = manager.subscribe(
          eventName: 'TestEvent',
          onEvent: (event) {
            // Event received
          },
        );

        expect(subscription.eventName, equals('TestEvent'));
        expect(manager.metrics.subscriptionCount, equals(1));

        // Test unsubscribe
        manager.unsubscribe(subscription.id);
        expect(manager.metrics.subscriptionCount, equals(0));
      });

      test('event stream provides reactive interface', () {
        final connection = Connection('https://api.devnet.solana.com');
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final eventDefinitions = <EventDefinition>[];

        final manager = EventSubscriptionManager(
          connection: connection,
          programId: programId,
          eventDefinitions: eventDefinitions,
        );

        final eventStream = manager.eventStream;
        expect(eventStream, isA<Stream>());

        // Stream should be broadcast-capable for multiple listeners
        expect(eventStream.isBroadcast, isTrue);
      });
    });

    group('TypeScript Compatibility', () {
      test('event system matches TypeScript functionality', () {
        // Test that all major TypeScript patterns are supported

        // 1. IDL-based event definition
        final idl = Idl(
          instructions: [],
          events: [
            IdlEvent(
              name: 'TransferEvent',
              fields: [
                IdlField(name: 'from', type: IdlType.publicKey()),
                IdlField(name: 'to', type: IdlType.publicKey()),
                IdlField(name: 'amount', type: IdlType.u64()),
              ],
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'TransferEvent',
              type: IdlTypeDefType(
                kind: 'struct',
                fields: [
                  IdlField(name: 'from', type: IdlType.publicKey()),
                  IdlField(name: 'to', type: IdlType.publicKey()),
                  IdlField(name: 'amount', type: IdlType.u64()),
                ],
              ),
            ),
          ],
        );

        // 2. BorshEventCoder creation
        final eventCoder = BorshEventCoder(idl);
        expect(eventCoder, isA<BorshEventCoder>());

        // 3. EventLogParser with delegation
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final parser = EventLogParser.fromIdl(programId, idl);
        expect(parser, isA<EventLogParser>());

        // 4. Event subscription management
        final connection = Connection('https://api.devnet.solana.com');
        final eventDefinitions = <EventDefinition>[];
        final config = EventSubscriptionConfig();
        final manager = EventSubscriptionManager(
          connection: connection,
          programId: programId,
          eventDefinitions: eventDefinitions,
          config: config,
        );
        expect(manager, isA<EventSubscriptionManager>());

        // All components integrate seamlessly
        expect(
            () => manager.subscribe(
                eventName: 'TransferEvent', onEvent: (event) {}),
            returnsNormally);
      });

      test('event configuration patterns match TypeScript', () {
        // Default configuration
        final defaultConfig = EventSubscriptionConfig();
        expect(defaultConfig.maxBufferSize, isNull);
        expect(defaultConfig.maxReconnectAttempts, equals(5));

        // Custom configuration
        final customConfig = EventSubscriptionConfig(
          maxBufferSize: 2000,
          maxReconnectAttempts: 10,
          reconnectTimeout: Duration(seconds: 30),
        );
        expect(customConfig.maxBufferSize, equals(2000));
        expect(customConfig.maxReconnectAttempts, equals(10));
      });

      test('event replay system provides TypeScript-compatible interface', () {
        final replayConfig = EventReplayConfig(
          fromSlot: 1000,
          toSlot: 2000,
          filter: EventFilter(eventNames: {'TestEvent'}),
        );

        expect(replayConfig.fromSlot, equals(1000));
        expect(replayConfig.toSlot, equals(2000));
        expect(replayConfig.filter?.eventNames?.contains('TestEvent'), isTrue);
      });
    });

    group('Performance and Compatibility Validation', () {
      test('event system handles multiple subscriptions', () {
        final connection = Connection('https://api.devnet.solana.com');
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final eventDefinitions = <EventDefinition>[];
        final config = EventSubscriptionConfig();

        final manager = EventSubscriptionManager(
          connection: connection,
          programId: programId,
          eventDefinitions: eventDefinitions,
          config: config,
        );

        // Test with multiple concurrent subscriptions
        final subscriptionIds = <String>[];
        for (int i = 0; i < 10; i++) {
          final subscription = manager.subscribe(
            eventName: 'Event$i',
            onEvent: (event) {},
          );
          subscriptionIds.add(subscription.id);
        }

        expect(manager.metrics.subscriptionCount, equals(10));

        // Cleanup
        for (final subscriptionId in subscriptionIds) {
          manager.unsubscribe(subscriptionId);
        }

        expect(manager.metrics.subscriptionCount, equals(0));
      });

      test('event types are properly exported and accessible', () {
        // Verify that all essential types are available through public API
        expect(EventContext, isA<Type>());
        expect(ParsedEvent, isA<Type>());
        expect(EventStats, isA<Type>());
        expect(EventFilter, isA<Type>());
        expect(EventSubscriptionConfig, isA<Type>());
        expect(EventReplayConfig, isA<Type>());
        expect(BorshEventCoder, isA<Type>());
        expect(EventLogParser, isA<Type>());
        expect(EventSubscriptionManager, isA<Type>());
      });
    });
  });
}
