import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/event/types.dart' as event_types;

/// Comprehensive test suite for the event system
///
/// Tests event parsing, filtering, subscription management,
/// listener functionality, and replay capabilities.
void main() {
  group('Event System Tests', () {
    late PublicKey programId;
    late IdlEvent testEventDef;

    setUp(() {
      // Create mock provider and program ID for testing
      programId = PublicKey.fromBase58('11111111111111111111111111111112');

      // Create a test event definition
      testEventDef = const IdlEvent(
        name: 'TestEvent',
        fields: [
          IdlField(name: 'id', type: IdlType(kind: 'u64')),
          IdlField(name: 'data', type: IdlType(kind: 'string')),
          IdlField(name: 'timestamp', type: IdlType(kind: 'u64')),
        ],
      );
    });

    group('Event Types and Context', () {
      test('EventContext creation and properties', () {
        final signature = 'test_signature';
        final slot = 12345;
        final blockTime = DateTime.now();

        final context = EventContext(
          signature: signature,
          slot: slot,
          blockTime: blockTime,
        );

        expect(context.signature, equals(signature));
        expect(context.slot, equals(slot));
        expect(context.blockTime, equals(blockTime));
      });

      test('EventStats structure', () {
        final stats = EventStats(
          totalEvents: 100,
          parsedEvents: 90,
          parseErrors: 5,
          filteredEvents: 5,
          lastProcessed: DateTime.now(),
          eventsPerSecond: 10.5,
        );

        expect(stats.totalEvents, equals(100));
        expect(stats.parsedEvents, equals(90));
        expect(stats.parseErrors, equals(5));
        expect(stats.filteredEvents, equals(5));
        expect(stats.eventsPerSecond, equals(10.5));
      });

      test('EventFilter creation and configuration', () {
        final filter = EventFilter(
          eventNames: {'TestEvent'},
          programIds: {programId},
        );

        expect(filter.eventNames, contains('TestEvent'));
        expect(filter.programIds, contains(programId));
      });
    });

    group('Event Parser', () {
      test('EventParser initialization', () {
        // Create a type definition for the event
        final testTypeDef = const IdlTypeDef(
          name: 'TestEvent',
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [
              IdlField(name: 'id', type: IdlType(kind: 'u64')),
              IdlField(name: 'data', type: IdlType(kind: 'string')),
              IdlField(name: 'timestamp', type: IdlType(kind: 'u64')),
            ],
          ),
        );

        final mockIdl = Idl(
          address: '11111111111111111111111111111112',
          metadata: const IdlMetadata(
              name: 'test_program', version: '0.1.0', spec: '0.1.0',),
          instructions: [],
          accounts: [],
          events: [testEventDef],
          types: [testTypeDef],
        );
        final coder = BorshCoder(mockIdl);

        final parser = EventParser(
          programId: programId,
          coder: coder,
        );

        expect(parser.programId, equals(programId));
        expect(parser.coder, equals(coder));
      });

      test('Log parsing with valid program logs', () {
        // Create a type definition for the event
        final testTypeDef = const IdlTypeDef(
          name: 'TestEvent',
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [
              IdlField(name: 'id', type: IdlType(kind: 'u64')),
              IdlField(name: 'data', type: IdlType(kind: 'string')),
              IdlField(name: 'timestamp', type: IdlType(kind: 'u64')),
            ],
          ),
        );

        final mockIdl = Idl(
          address: '11111111111111111111111111111112',
          metadata: const IdlMetadata(
              name: 'test_program', version: '0.1.0', spec: '0.1.0',),
          instructions: [],
          accounts: [],
          events: [testEventDef],
          types: [testTypeDef],
        );
        final coder = BorshCoder(mockIdl);

        final parser = EventParser(
          programId: programId,
          coder: coder,
        );

        // Create mock transaction log data
        final logs = [
          'Program $programId invoke [1]',
          'Program log: Instruction: Initialize',
          'Program $programId success',
        ];

        final events = parser.parseLogs(logs);
        expect(events, isA<Iterable<ParsedEvent>>());
      });
    });

    group('Event Filters', () {
      test('Basic event filter matching', () {
        final filter = const EventFilter(
          eventNames: {'TestEvent', 'AnotherEvent'},
        );

        final matchingEvent = ParsedEvent(
          name: 'TestEvent',
          data: {},
          context: EventContext(
            signature: 'test',
            slot: 1,
            blockTime: DateTime.now(),
          ),
          eventDef: testEventDef,
        );

        final nonMatchingEvent = ParsedEvent(
          name: 'DifferentEvent',
          data: {},
          context: EventContext(
            signature: 'test',
            slot: 1,
            blockTime: DateTime.now(),
          ),
          eventDef: testEventDef,
        );

        expect(filter.matches(matchingEvent, programId), isTrue);
        expect(filter.matches(nonMatchingEvent, programId), isFalse);
      });

      test('Slot range filtering', () {
        final filter = const EventFilter(
          minSlot: 100,
          maxSlot: 200,
        );

        final inRangeEvent = ParsedEvent(
          name: 'TestEvent',
          data: {},
          context: EventContext(
            signature: 'test',
            slot: 150,
            blockTime: DateTime.now(),
          ),
          eventDef: testEventDef,
        );

        final outOfRangeEvent = ParsedEvent(
          name: 'TestEvent',
          data: {},
          context: EventContext(
            signature: 'test',
            slot: 250,
            blockTime: DateTime.now(),
          ),
          eventDef: testEventDef,
        );

        expect(filter.matches(inRangeEvent, programId), isTrue);
        expect(filter.matches(outOfRangeEvent, programId), isFalse);
      });
    });

    group('Event Subscription Types', () {
      test('EventSubscriptionConfig with defaults', () {
        final config = const EventSubscriptionConfig();

        expect(config.commitment, equals(CommitmentConfigs.confirmed));
        expect(config.includeFailed, equals(false));
        expect(config.reconnectTimeout, equals(const Duration(seconds: 30)));
        expect(config.maxReconnectAttempts, equals(5));
      });

      test('EventSubscriptionConfig with custom values', () {
        final config = const EventSubscriptionConfig(
          commitment: CommitmentConfigs.finalized,
          includeFailed: true,
          maxBufferSize: 1000,
          reconnectTimeout: Duration(minutes: 1),
          maxReconnectAttempts: 10,
        );

        expect(config.commitment, equals(CommitmentConfigs.finalized));
        expect(config.includeFailed, equals(true));
        expect(config.maxBufferSize, equals(1000));
        expect(config.reconnectTimeout, equals(const Duration(minutes: 1)));
        expect(config.maxReconnectAttempts, equals(10));
      });
    });

    group('Event Replay System', () {
      test('EventReplayConfig validation', () {
        final config = const EventReplayConfig(
          fromSlot: 100,
          toSlot: 200,
          maxEvents: 1000,
        );

        expect(config.fromSlot, equals(100));
        expect(config.toSlot, equals(200));
        expect(config.maxEvents, equals(1000));
        expect(config.includeFailed, equals(false));
      });

      test('EventReplayConfig with filter', () {
        final filter = const EventFilter(
          eventNames: {'ImportantEvent'},
        );

        final config = EventReplayConfig(
          fromSlot: 100,
          filter: filter,
          includeFailed: true,
        );

        expect(config.fromSlot, equals(100));
        expect(config.filter, equals(filter));
        expect(config.includeFailed, equals(true));
      });
    });

    group('LogsNotification', () {
      test('LogsNotification creation and success status', () {
        final notification = const event_types.LogsNotification(
          signature: 'test_signature',
          logs: ['Program log: test'],
          slot: 12345,
        );

        expect(notification.signature, equals('test_signature'));
        expect(notification.logs, equals(['Program log: test']));
        expect(notification.slot, equals(12345));
        expect(notification.isSuccess, isTrue);
        expect(notification.err, isNull);
      });

      test('LogsNotification with error', () {
        final notification = const event_types.LogsNotification(
          signature: 'failed_signature',
          logs: ['Program log: error'],
          err: 'Transaction failed',
          slot: 12345,
        );

        expect(notification.signature, equals('failed_signature'));
        expect(notification.err, equals('Transaction failed'));
        expect(notification.isSuccess, isFalse);
      });
    });
  });
}
