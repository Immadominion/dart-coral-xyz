import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Test for Step 7.3 Program class event system integration
void main() {
  group('Step 7.3 Program Event System Integration', () {
    test('Program class event system properties', () {
      // Create a simple IDL for testing
      final testIdl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            IdlMetadata(name: 'TestProgram', version: '1.0.0', spec: '0.1.0'),
        instructions: [],
        accounts: [],
        events: [],
        errors: [],
        types: [],
      );

      // Create program instance
      final program = Program(testIdl);

      // Verify event system properties
      expect(program.isPersistenceEnabled, isFalse);
      expect(program.isDebuggingEnabled, isFalse);
      expect(program.isAggregationEnabled, isFalse);
      expect(program.eventStats, isNotNull);
      expect(program.eventConnectionState, isNotNull);
      expect(program.eventConnectionStateStream, isNotNull);
    });

    test('Program class event system enablement', () async {
      final testIdl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            IdlMetadata(name: 'TestProgram', version: '1.0.0', spec: '0.1.0'),
        instructions: [],
        accounts: [],
        events: [],
        errors: [],
        types: [],
      );

      final program = Program(testIdl);

      // Enable event services
      await program.enableEventPersistence();
      await program.enableEventDebugging();
      await program.enableEventAggregation();

      // Verify services are enabled
      expect(program.isPersistenceEnabled, isTrue);
      expect(program.isDebuggingEnabled, isTrue);
      expect(program.isAggregationEnabled, isTrue);

      // Test statistics methods
      final persistenceStats = await program.getEventPersistenceStats();
      expect(persistenceStats, isNotNull);

      final debugStats = await program.getEventDebuggingStats();
      expect(debugStats, isNotNull);

      final aggregationResults = await program.getEventAggregationResults();
      expect(aggregationResults, isNotNull);
      expect(aggregationResults, isList);

      // Clean up
      await program.dispose();
    });

    test('Program class event processing pipeline', () async {
      final testIdl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            IdlMetadata(name: 'TestProgram', version: '1.0.0', spec: '0.1.0'),
        instructions: [],
        accounts: [],
        events: [],
        errors: [],
        types: [],
      );

      final program = Program(testIdl);

      // Enable aggregation service
      await program.enableEventAggregation();

      // Create a simple processing pipeline
      final pipeline = await program.createEventPipeline([
        FilterProcessor((event) => event.eventName == 'TestEvent'),
      ]);

      expect(pipeline, isNotNull);

      // Clean up
      await program.dispose();
    });

    test('Program class advanced event methods', () async {
      final testIdl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            IdlMetadata(name: 'TestProgram', version: '1.0.0', spec: '0.1.0'),
        instructions: [],
        accounts: [],
        events: [],
        errors: [],
        types: [],
      );

      final program = Program(testIdl);

      // Test basic event methods (already implemented)
      expect(
          () async => await program.addEventListener<Map<String, dynamic>>(
                'TestEvent',
                (event, slot, signature) {},
              ),
          returnsNormally);

      // Test error conditions for advanced features
      expect(
        () async => await program.restoreEvents(),
        throwsA(isA<StateError>()),
      );

      expect(
        () async => await program.createEventPipeline([]),
        throwsA(isA<StateError>()),
      );

      // Clean up
      await program.dispose();
    });
  });
}
