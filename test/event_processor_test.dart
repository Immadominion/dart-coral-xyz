import 'package:test/test.dart';
import 'dart:async';
import 'dart:typed_data';

import '../lib/src/event/event_processor.dart';
import '../lib/src/event/event_definition.dart';
import '../lib/src/event/event_log_parser.dart';

void main() {
  group('EventProcessor', () {
    late EventProcessor processor;
    late List<EventDefinition> testEvents;
    late ParsedEvent testEvent;

    setUp(() {
      // Create test event definitions
      testEvents = [
        EventDefinition(
          name: 'TestEvent',
          discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          fields: [
            EventFieldDefinition(
              name: 'value',
              typeInfo: EventFieldTypeInfo(
                typeName: 'u64',
                isPrimitive: true,
                isComplex: false,
                isOptional: false,
                hasNestedStructures: false,
                estimatedSize: 8,
              ),
            ),
          ],
          metadata: EventMetadata(
            totalFields: 1,
            hasOptionalFields: false,
            hasNestedStructures: false,
            estimatedSize: 8,
            complexity: EventComplexity.low,
            tags: [],
          ),
          validationRules: EventValidationRules(
            enforceRequiredFields: true,
            typeStrictness: TypeValidationStrictness.strict,
            enforceFieldConstraints: true,
            customValidators: [],
          ),
        ),
      ];

      processor = EventProcessor(eventDefinitions: testEvents);

      testEvent = ParsedEvent(
        name: 'TestEvent',
        data: {'value': 12345},
        definition: testEvents.first,
        rawData: Uint8List.fromList(
            [1, 2, 3, 4, 5, 6, 7, 8, 57, 48, 0, 0, 0, 0, 0, 0]),
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        isValid: true,
      );
    });

    tearDown(() {
      processor.dispose();
    });

    group('Handler Management', () {
      test('registers and executes handlers', () async {
        var handlerCalled = false;

        final handler = _TestHandler((event, context) async {
          handlerCalled = true;
          return EventHandlerResult.success();
        });

        processor.registerHandler('TestEvent', handler);
        expect(processor.metrics.handlersRegistered, equals(1));

        final result = await processor.processEvent(testEvent);

        expect(result.isSuccess, isTrue);
        expect(handlerCalled, isTrue);
        expect(processor.metrics.handlersExecuted, equals(1));
      });

      test('removes handlers correctly', () {
        final handler = _TestHandler(
            (event, context) async => EventHandlerResult.success());

        processor.registerHandler('TestEvent', handler);
        expect(processor.metrics.handlersRegistered, equals(1));

        processor.removeHandler('TestEvent', handler);
        expect(processor.metrics.handlersRegistered, equals(0));
      });

      test('removes all handlers for an event', () {
        final handler1 = _TestHandler(
            (event, context) async => EventHandlerResult.success());
        final handler2 = _TestHandler(
            (event, context) async => EventHandlerResult.success());

        processor.registerHandler('TestEvent', handler1);
        processor.registerHandler('TestEvent', handler2);
        expect(processor.metrics.handlersRegistered, equals(2));

        processor.removeAllHandlers('TestEvent');
        expect(processor.metrics.handlersRegistered, equals(0));
      });

      test('registers multiple handlers', () {
        final handler1 = _TestHandler(
            (event, context) async => EventHandlerResult.success());
        final handler2 = _TestHandler(
            (event, context) async => EventHandlerResult.success());

        processor.registerHandlers({
          'TestEvent': [handler1, handler2],
        });

        expect(processor.metrics.handlersRegistered, equals(2));
      });
    });

    group('Middleware', () {
      test('registers and executes middleware', () async {
        var middlewareCalled = false;

        final middleware = _TestMiddleware((event, context) async {
          middlewareCalled = true;
          return event;
        });

        processor.registerMiddleware(middleware);
        expect(processor.metrics.middlewareRegistered, equals(1));

        await processor.processEvent(testEvent);

        expect(middlewareCalled, isTrue);
      });

      test('removes middleware correctly', () {
        final middleware = _TestMiddleware((event, context) async => event);

        processor.registerMiddleware(middleware);
        expect(processor.metrics.middlewareRegistered, equals(1));

        final removed = processor.removeMiddleware(middleware);
        expect(removed, isTrue);
        expect(processor.metrics.middlewareRegistered, equals(0));
      });

      test('middleware can stop processing', () async {
        final middleware = _TestMiddleware((event, context) async {
          context.stop();
          return event;
        });

        processor.registerMiddleware(middleware);

        final result = await processor.processEvent(testEvent);

        expect(result.status, equals(ProcessingStatus.stopped));
      });
    });

    group('Event Processing', () {
      test('processes events successfully', () async {
        final handler = _TestHandler((event, context) async {
          return EventHandlerResult.success(data: {'processed': true});
        });

        processor.registerHandler('TestEvent', handler);

        final result = await processor.processEvent(testEvent);

        expect(result.isSuccess, isTrue);
        expect(result.handlerResults.length, equals(1));
        expect(result.handlerResults.first.isSuccess, isTrue);
        expect(result.handlerResults.first.data['processed'], isTrue);
      });

      test('handles handler errors gracefully with continueOnHandlerError',
          () async {
        final config = EventProcessingConfig(continueOnHandlerError: true);
        final processor =
            EventProcessor(eventDefinitions: testEvents, config: config);

        final handler1 = _TestHandler((event, context) async {
          throw Exception('Handler error');
        });

        final handler2 = _TestHandler((event, context) async {
          return EventHandlerResult.success(data: {'processed': true});
        });

        processor.registerHandler('TestEvent', handler1);
        processor.registerHandler('TestEvent', handler2);

        final result = await processor.processEvent(testEvent);

        expect(result.isSuccess, isTrue);
        expect(result.handlerResults.length, equals(2));
        expect(result.handlerResults.first.isSuccess, isFalse);
        expect(result.handlerResults.last.isSuccess, isTrue);
        expect(processor.metrics.handlerErrors, equals(1));

        processor.dispose();
      });

      test('stops on handler errors when continueOnHandlerError is false',
          () async {
        final config = EventProcessingConfig(continueOnHandlerError: false);
        final processor =
            EventProcessor(eventDefinitions: testEvents, config: config);

        final handler1 = _TestHandler((event, context) async {
          throw Exception('Handler error');
        });

        final handler2 = _TestHandler((event, context) async {
          return EventHandlerResult.success();
        });

        processor.registerHandler('TestEvent', handler1);
        processor.registerHandler('TestEvent', handler2);

        final result = await processor.processEvent(testEvent);

        expect(result.isSuccess, isTrue);
        expect(result.handlerResults.length,
            equals(1)); // Only first handler executed
        expect(processor.metrics.handlerErrors, equals(1));

        processor.dispose();
      });

      test('stops propagation when handler requests it', () async {
        final handler1 = _TestHandler((event, context) async {
          return EventHandlerResult.success(shouldStopPropagation: true);
        });

        final handler2 = _TestHandler((event, context) async {
          return EventHandlerResult.success();
        });

        processor.registerHandler('TestEvent', handler1);
        processor.registerHandler('TestEvent', handler2);

        final result = await processor.processEvent(testEvent);

        expect(result.isSuccess, isTrue);
        expect(result.handlerResults.length,
            equals(1)); // Only first handler executed
        expect(processor.metrics.handlersExecuted, equals(1));
      });
    });

    group('Batch Processing', () {
      test('queues events when batching is enabled', () async {
        final config =
            EventProcessingConfig(enableBatching: true, maxBatchSize: 5);
        final processor =
            EventProcessor(eventDefinitions: testEvents, config: config);

        final result = await processor.processEvent(testEvent);

        expect(result.status, equals(ProcessingStatus.queued));
        expect(processor.metrics.eventsQueued, equals(1));

        processor.dispose();
      });

      test('processes batch when max size is reached', () async {
        final config = EventProcessingConfig(
          enableBatching: true,
          maxBatchSize: 2,
          batchTimeout: 10000, // High timeout to avoid timer triggering
        );
        final processor =
            EventProcessor(eventDefinitions: testEvents, config: config);

        var handlerCallCount = 0;
        final handler = _TestHandler((event, context) async {
          handlerCallCount++;
          return EventHandlerResult.success();
        });

        processor.registerHandler('TestEvent', handler);
        processor.start();

        // Add first event (should be queued)
        await processor.processEvent(testEvent);
        expect(processor.metrics.eventsQueued, equals(1));

        // Add second event (should trigger batch processing)
        await processor.processEvent(testEvent);

        // Give some time for batch processing
        await Future.delayed(Duration(milliseconds: 100));

        expect(processor.metrics.batchesProcessed, greaterThanOrEqualTo(1));
        expect(handlerCallCount, greaterThanOrEqualTo(2));

        processor.dispose();
      });
    });

    group('Lifecycle', () {
      test('starts and stops correctly', () {
        processor.start();
        expect(processor.metrics.processorStarted, equals(1));

        processor.stop();
        expect(processor.metrics.processorStopped, equals(1));
      });

      test('processes stream emits results', () async {
        final streamResults = <ProcessedEventResult>[];
        final subscription =
            processor.processedEvents.listen(streamResults.add);

        final handler = _TestHandler(
            (event, context) async => EventHandlerResult.success());
        processor.registerHandler('TestEvent', handler);

        await processor.processEvent(testEvent);

        // Give some time for stream to emit
        await Future.delayed(Duration(milliseconds: 10));

        expect(streamResults.length, equals(1));
        expect(streamResults.first.isSuccess, isTrue);

        await subscription.cancel();
      });
    });

    group('Metrics', () {
      test('tracks metrics correctly', () async {
        final handler = _TestHandler(
            (event, context) async => EventHandlerResult.success());
        final middleware = _TestMiddleware((event, context) async => event);

        processor.registerHandler('TestEvent', handler);
        processor.registerMiddleware(middleware);
        processor.start();

        await processor.processEvent(testEvent);

        expect(processor.metrics.handlersRegistered, equals(1));
        expect(processor.metrics.middlewareRegistered, equals(1));
        expect(processor.metrics.processorStarted, equals(1));
        expect(processor.metrics.eventsProcessed, equals(1));
        expect(processor.metrics.handlersExecuted, equals(1));
      });

      test('resets metrics correctly', () async {
        final handler = _TestHandler(
            (event, context) async => EventHandlerResult.success());
        processor.registerHandler('TestEvent', handler);

        await processor.processEvent(testEvent);

        expect(processor.metrics.eventsProcessed, equals(1));

        processor.metrics.reset();

        expect(processor.metrics.eventsProcessed, equals(0));
        expect(processor.metrics.handlersRegistered, equals(0));
      });
    });

    group('Context', () {
      test('provides processing context to handlers', () async {
        String? contextId;

        final handler = _TestHandler((event, context) async {
          contextId = context.processingId;
          context.addMetadata('test', 'value');
          return EventHandlerResult.success();
        });

        processor.registerHandler('TestEvent', handler);

        await processor.processEvent(testEvent);

        expect(contextId, isNotNull);
      });
    });
  });
}

/// Test implementation of EventHandler
class _TestHandler implements EventHandler {
  final Future<EventHandlerResult> Function(ParsedEvent, EventProcessingContext)
      _handler;

  _TestHandler(this._handler);

  @override
  Future<EventHandlerResult> handle(
      ParsedEvent event, EventProcessingContext context) {
    return _handler(event, context);
  }
}

/// Test implementation of EventMiddleware
class _TestMiddleware implements EventMiddleware {
  final Future<ParsedEvent> Function(ParsedEvent, EventProcessingContext)
      _processor;

  _TestMiddleware(this._processor);

  @override
  Future<ParsedEvent> process(
      ParsedEvent event, EventProcessingContext context) {
    return _processor(event, context);
  }
}
