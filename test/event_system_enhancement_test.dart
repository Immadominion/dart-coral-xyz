import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Tests for the enhanced event system (Step 7.3)
///
/// This test suite validates the new event persistence, debugging,
/// and aggregation features to ensure complete TypeScript parity.
void main() {
  group('Event System Enhancement Tests (Step 7.3)', () {
    group('Event Persistence', () {
      test('EventPersistenceService basic functionality', () async {
        final service = EventPersistenceService(
          storageDirectory: './test_logs',
          enableCompression: false,
          maxFileSize: 1024,
        );

        final testEvent = ParsedEvent(
          name: 'TestEvent',
          data: {'value': 42},
          context: EventContext(signature: 'test', slot: 1),
          eventDef: IdlEvent(name: 'TestEvent', fields: []),
        );

        await service.persistEvent(testEvent);

        final stats = await service.getStatistics();
        expect(stats.totalEvents, equals(1));

        await service.dispose();
      });

      test('EventPersistenceConfig presets', () {
        final devConfig = EventPersistenceConfig.development();
        expect(devConfig.enableCompression, isFalse);
        expect(devConfig.maxFileSize, equals(1024 * 1024));

        final prodConfig = EventPersistenceConfig.production();
        expect(prodConfig.enableCompression, isTrue);
        expect(prodConfig.maxFileSize, equals(50 * 1024 * 1024));
      });

      test('Event restoration and filtering', () async {
        final service = EventPersistenceService(
          storageDirectory: './test_logs_restore',
          enableCompression: false,
        );

        // Persist multiple events
        for (int i = 0; i < 5; i++) {
          final event = ParsedEvent(
            name: 'Event$i',
            data: {'index': i},
            context: EventContext(signature: 'test$i', slot: i),
            eventDef: IdlEvent(name: 'Event$i', fields: []),
          );
          await service.persistEvent(event);
        }

        // Restore events with filtering
        final events =
            await service.restoreEvents(eventName: 'Event2').toList();
        expect(events.length, equals(1));
        expect(events.first.name, equals('Event2'));

        await service.dispose();
      });
    });

    group('Event Debugging and Monitoring', () {
      test('EventDebugMonitor performance tracking', () async {
        final monitor = EventDebugMonitor(
          config: EventMonitorConfig.development(),
        );

        // Start tracking an event
        final trackingId = monitor.startEventProcessing(
          'TestEvent',
          {'test': true},
        );

        // Simulate processing time
        await Future.delayed(Duration(milliseconds: 10));

        // Complete tracking
        monitor.completeEventProcessing(
          trackingId,
          success: true,
          resultMetadata: {'result': 'success'},
        );

        // Check metrics
        final metrics = monitor.getEventMetrics('TestEvent');
        expect(metrics, isNotNull);
        expect(metrics!.totalProcessed, equals(1));
        expect(metrics.averageProcessingTime.inMilliseconds, greaterThan(0));

        await monitor.dispose();
      });

      test('EventDebugMonitor alert generation', () async {
        final monitor = EventDebugMonitor(
          config: EventMonitorConfig(
            slowProcessingThreshold: Duration(milliseconds: 1),
          ),
        );

        final alerts = <EventAlert>[];
        monitor.alerts.listen(alerts.add);

        // Process a slow event
        final trackingId = monitor.startEventProcessing('SlowEvent', {});
        await Future.delayed(Duration(milliseconds: 5));
        monitor.completeEventProcessing(trackingId, success: true);

        // Wait for alert processing
        await Future.delayed(Duration(milliseconds: 10));

        expect(alerts.length, greaterThan(0));
        expect(alerts.first.type, equals(AlertType.performance));
        expect(alerts.first.eventName, equals('SlowEvent'));

        await monitor.dispose();
      });

      test('EventDebugMonitor statistics collection', () async {
        final monitor = EventDebugMonitor();

        // Process multiple events
        for (int i = 0; i < 10; i++) {
          final trackingId = monitor.startEventProcessing('TestEvent$i', {});
          monitor.completeEventProcessing(trackingId, success: i % 2 == 0);
        }

        final stats = monitor.currentStats;
        expect(stats.totalEvents, equals(10));
        expect(stats.totalErrors, equals(5)); // Half failed
        expect(stats.errorRate, equals(0.5));

        await monitor.dispose();
      });
    });

    group('Event Aggregation and Processing', () {
      test('EventAggregationService basic aggregation', () async {
        final service = EventAggregationService(
          config: EventAggregationConfig.realTime(),
        );

        // Register a count aggregator
        final countAggregator = CountAggregator();
        service.registerAggregator('Test*', countAggregator);

        final aggregatedEvents = <AggregatedEvent>[];
        service.getAggregatedEvents('Test*').listen(aggregatedEvents.add);

        // Process events
        for (int i = 0; i < 5; i++) {
          service.processEvent('TestEvent', {'value': i}, DateTime.now());
        }

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 200));

        expect(aggregatedEvents.length, greaterThan(0));
        final firstAggregation = aggregatedEvents.first;
        expect(firstAggregation.type, equals(AggregationType.count));
        expect(firstAggregation.eventCount, equals(5));

        await service.dispose();
      });

      test('SumAggregator functionality', () {
        final aggregator = SumAggregator(fieldName: 'amount');

        final events = [
          ProcessedEvent(
            eventName: 'Transaction',
            data: {'amount': 10.5},
            timestamp: DateTime.now(),
          ),
          ProcessedEvent(
            eventName: 'Transaction',
            data: {'amount': 5.25},
            timestamp: DateTime.now(),
          ),
        ];

        final result = aggregator.aggregate(events);
        expect(result, isNotNull);
        expect(result!.type, equals(AggregationType.sum));
        expect(result.data['amount'], equals(15.75));
      });

      test('AverageAggregator functionality', () {
        final aggregator = AverageAggregator(fieldName: 'response_time');

        final events = [
          ProcessedEvent(
            eventName: 'Request',
            data: {'response_time': 100},
            timestamp: DateTime.now(),
          ),
          ProcessedEvent(
            eventName: 'Request',
            data: {'response_time': 200},
            timestamp: DateTime.now(),
          ),
          ProcessedEvent(
            eventName: 'Request',
            data: {'response_time': 300},
            timestamp: DateTime.now(),
          ),
        ];

        final result = aggregator.aggregate(events);
        expect(result, isNotNull);
        expect(result!.type, equals(AggregationType.average));
        expect(result.data['response_time_average'], equals(200.0));
        expect(result.data['response_time_min'], equals(100.0));
        expect(result.data['response_time_max'], equals(300.0));
      });

      test('EventProcessingPipeline with processors', () async {
        final pipeline = EventProcessingPipeline();

        // Add a filter processor
        pipeline.addProcessor(
            FilterProcessor((event) => event.eventName.startsWith('Keep')));

        // Add a transform processor
        pipeline.addProcessor(TransformProcessor((event) => event
            .copyWith(data: {'transformed': true, 'original': event.data})));

        final outputEvents = <ProcessedEvent>[];
        pipeline.output.listen(outputEvents.add);

        // Process events
        pipeline.input.add(ProcessedEvent(
          eventName: 'KeepThis',
          data: {'value': 1},
          timestamp: DateTime.now(),
        ));

        pipeline.input.add(ProcessedEvent(
          eventName: 'FilterThis',
          data: {'value': 2},
          timestamp: DateTime.now(),
        ));

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 10));

        expect(outputEvents.length, equals(1));
        expect(outputEvents.first.eventName, equals('KeepThis'));
        expect(outputEvents.first.data['transformed'], isTrue);
        expect(outputEvents.first.data['original']['value'], equals(1));

        await pipeline.dispose();
      });

      test('EnrichmentProcessor functionality', () async {
        final processor = EnrichmentProcessor((event) => {
              'enriched_at': DateTime.now().toIso8601String(),
              'event_type': event.eventName.toLowerCase(),
            });

        final event = ProcessedEvent(
          eventName: 'TestEvent',
          data: {'original': true},
          timestamp: DateTime.now(),
        );

        final result = await processor.process(event);
        expect(result, isNotNull);
        expect(result!.metadata['enriched_at'], isNotNull);
        expect(result.metadata['event_type'], equals('testevent'));
      });
    });

    group('Integration Tests', () {
      test('Complete event system workflow', () async {
        // Set up all components
        final persistenceService = EventPersistenceService(
          storageDirectory: './test_complete_workflow',
          enableCompression: false,
        );

        final debugMonitor = EventDebugMonitor(
          config: EventMonitorConfig.development(),
        );

        final aggregationService = EventAggregationService(
          config: EventAggregationConfig.realTime(),
        );

        // Register aggregator
        aggregationService.registerAggregator('*', CountAggregator());

        final aggregatedEvents = <AggregatedEvent>[];
        aggregationService
            .getAggregatedEvents('*')
            .listen(aggregatedEvents.add);

        // Process events through the complete workflow
        for (int i = 0; i < 3; i++) {
          final event = ParsedEvent(
            name: 'WorkflowEvent$i',
            data: {'index': i},
            context: EventContext(signature: 'test$i', slot: i),
            eventDef: IdlEvent(name: 'WorkflowEvent$i', fields: []),
          );

          // Track with debug monitor
          final trackingId = debugMonitor.startEventProcessing(
            event.name,
            {'workflow_test': true},
          );

          // Persist event
          await persistenceService.persistEvent(event);

          // Process for aggregation
          aggregationService.processEvent(
              event.name, event.data, DateTime.now());

          // Complete tracking
          debugMonitor.completeEventProcessing(trackingId, success: true);
        }

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 200));

        // Verify all components worked
        final persistenceStats = await persistenceService.getStatistics();
        expect(persistenceStats.totalEvents, equals(3));

        final debugStats = debugMonitor.currentStats;
        expect(debugStats.totalEvents, equals(3));

        expect(aggregatedEvents.length, greaterThan(0));

        // Cleanup
        await persistenceService.dispose();
        await debugMonitor.dispose();
        await aggregationService.dispose();
      });
    });
  });
}
