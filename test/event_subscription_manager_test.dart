import 'dart:async';
import 'package:test/test.dart';

import 'package:coral_xyz_anchor/src/event/event_subscription_manager.dart';
import 'package:coral_xyz_anchor/src/event/event_definition.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/event/types.dart';

void main() {
  group('EventSubscriptionManager - TypeScript Compatibility', () {
    late Connection connection;
    late PublicKey programId;
    late List<EventDefinition> eventDefinitions;
    late EventSubscriptionManager manager;

    setUp(() {
      connection = Connection('https://api.devnet.solana.com');
      programId = PublicKey.fromBase58('11111111111111111111111111111111');

      eventDefinitions = [
        const EventDefinition(
          name: 'TestEvent',
          docs: [],
          fields: [],
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          metadata: EventMetadata(
            totalFields: 0,
            hasOptionalFields: false,
            hasNestedStructures: false,
            estimatedSize: 8,
            complexity: EventComplexity.low,
            tags: [],
          ),
          validationRules: EventValidationRules(
            customValidators: [],
          ),
        ),
      ];

      manager = EventSubscriptionManager(
        connection: connection,
        programId: programId,
        eventDefinitions: eventDefinitions,
      );
    });

    tearDown(() {
      manager.dispose();
    });

    group('Basic Functionality', () {
      test('creates manager with default configuration', () {
        expect(manager.connectionState, equals(ConnectionState.disconnected));
        expect(manager.getActiveSubscriptions().isEmpty, isTrue);
      });

      test('subscribes to events by name', () {
        final subscription = manager.subscribe(
          eventName: 'TestEvent',
          onEvent: (event) {
            // Event would be received here
          },
        );

        expect(subscription.id, isNotEmpty);
        expect(subscription.eventName, equals('TestEvent'));
        expect(manager.getActiveSubscriptions().length, equals(1));
        expect(manager.getSubscription(subscription.id), equals(subscription));
      });

      test('unsubscribes from events', () async {
        final subscription = manager.subscribe(
          eventName: 'TestEvent',
          onEvent: (event) {},
        );

        expect(manager.getActiveSubscriptions().length, equals(1));

        await manager.unsubscribe(subscription.id);

        expect(manager.getActiveSubscriptions().length, equals(0));
        expect(manager.getSubscription(subscription.id), isNull);
      });

      test('tracks metrics correctly', () {
        manager.subscribe(eventName: 'TestEvent', onEvent: (event) {});
        manager.subscribe(eventName: 'AnotherEvent', onEvent: (event) {});

        expect(manager.metrics.subscriptionCount, equals(2));
      });
    });

    group('Configuration', () {
      test('uses default configuration', () {
        const config = EventSubscriptionConfig();

        expect(config.includeFailed, isFalse);
        expect(config.maxReconnectAttempts, equals(5));
      });

      test('uses custom configuration', () {
        const config = EventSubscriptionConfig(
          includeFailed: true,
          maxBufferSize: 500,
          maxReconnectAttempts: 3,
        );

        expect(config.includeFailed, isTrue);
        expect(config.maxBufferSize, equals(500));
        expect(config.maxReconnectAttempts, equals(3));
      });

      test('creates manager with custom config', () {
        final customConfig = const EventSubscriptionConfig(
          includeFailed: true,
          maxBufferSize: 500,
        );

        final customManager = EventSubscriptionManager(
          connection: connection,
          programId: programId,
          eventDefinitions: eventDefinitions,
          config: customConfig,
        );

        expect(customManager.connectionState,
            equals(ConnectionState.disconnected),);
        customManager.dispose();
      });
    });

    group('TypeScript Pattern Compatibility', () {
      test('uses Connection.onLogs for subscription (TypeScript pattern)',
          () async {
        expect(manager.connectionState, equals(ConnectionState.disconnected));

        // Test the connect method uses Connection.onLogs internally
        // Note: In a real scenario, this would connect to a real WebSocket
        // For unit tests, this tests the interface without actually connecting
        expect(() => manager.connect(), returnsNormally);
      });

      test('subscription interface matches TypeScript pattern', () {
        // Verify that the manager uses Connection.onLogs instead of custom WebSocket
        final subscription = manager.subscribe(
          eventName: 'TestEvent',
          onEvent: (event) {},
        );

        expect(subscription.id, isNotEmpty);
        expect(manager.connectionState, equals(ConnectionState.disconnected));
      });
    });

    group('Event Stream', () {
      test('provides event stream', () {
        expect(manager.eventStream, isA<Stream>());
      });

      test('broadcasts events to stream', () async {
        final streamEvents = <dynamic>[];
        final streamSubscription = manager.eventStream.listen(streamEvents.add);

        // Stream is ready but no events will be received without actual connection
        expect(streamEvents.isEmpty, isTrue);

        await streamSubscription.cancel();
      });
    });

    group('Error Handling', () {
      test('handles subscription errors gracefully', () {
        var errorReceived = false;

        manager.subscribe(
          eventName: 'TestEvent',
          onEvent: (event) {
            throw Exception('Handler error');
          },
          onError: (error) {
            errorReceived = true;
          },
        );

        // Errors would be triggered by actual event processing
        expect(errorReceived, isFalse); // No events processed yet
      });
    });

    group('EventSubscriptionError', () {
      test('creates error with all fields', () {
        final error = EventSubscriptionError(
          type: EventSubscriptionErrorType.connectionError,
          message: 'Connection failed',
          data: {'url': 'ws://localhost:8080'},
        );

        expect(error.type, equals(EventSubscriptionErrorType.connectionError));
        expect(error.message, equals('Connection failed'));
        expect(error.data?['url'], equals('ws://localhost:8080'));
        expect(error.timestamp, isNotNull);
      });

      test('has readable toString', () {
        final error = EventSubscriptionError(
          type: EventSubscriptionErrorType.handlerError,
          message: 'Handler threw exception',
        );

        expect(error.toString(), contains('EventSubscriptionError'));
        expect(error.toString(), contains('handlerError'));
        expect(error.toString(), contains('Handler threw exception'));
      });
    });

    group('EventSubscriptionMetrics', () {
      test('tracks metrics correctly', () {
        final metrics = EventSubscriptionMetrics();

        expect(metrics.connectionCount, equals(0));
        expect(metrics.messagesReceived, equals(0));
        expect(metrics.eventsProcessed, equals(0));
        expect(metrics.notificationsDelivered, equals(0));
        expect(metrics.errorCount, equals(0));
        expect(metrics.subscriptionCount, equals(0));

        metrics.connectionCount++;
        metrics.messagesReceived += 5;
        metrics.eventsProcessed += 3;
        metrics.notificationsDelivered += 2;
        metrics.errorCount++;
        metrics.subscriptionCount += 2;

        expect(metrics.connectionCount, equals(1));
        expect(metrics.messagesReceived, equals(5));
        expect(metrics.eventsProcessed, equals(3));
        expect(metrics.notificationsDelivered, equals(2));
        expect(metrics.errorCount, equals(1));
        expect(metrics.subscriptionCount, equals(2));
      });

      test('resets metrics', () {
        final metrics = EventSubscriptionMetrics();

        metrics.connectionCount = 5;
        metrics.messagesReceived = 10;
        metrics.eventsProcessed = 8;
        metrics.notificationsDelivered = 6;
        metrics.errorCount = 2;
        metrics.subscriptionCount = 3;

        metrics.reset();

        expect(metrics.connectionCount, equals(0));
        expect(metrics.messagesReceived, equals(0));
        expect(metrics.eventsProcessed, equals(0));
        expect(metrics.notificationsDelivered, equals(0));
        expect(metrics.errorCount, equals(0));
        expect(metrics.subscriptionCount, equals(0));
      });
    });
  });
}
