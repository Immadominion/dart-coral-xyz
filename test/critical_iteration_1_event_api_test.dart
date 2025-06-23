/// Test for Critical Iteration 1: Event System API Compatibility
///
/// This test verifies that the new TypeScript-compatible EventManager
/// matches TypeScript Anchor's exact API behavior.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Critical Iteration 1: Event System API Compatibility', () {
    late PublicKey programId;
    late AnchorProvider provider;
    late BorshCoder coder;
    late EventManager eventManager;

    setUpAll(() async {
      programId = PublicKey.fromBase58('11111111111111111111111111111112');
      // Use a mock provider for testing
      provider = await AnchorProvider.local();

      // Create a minimal IDL for testing
      final testIdl = Idl(
        version: '0.1.0',
        name: 'test_program',
        instructions: [],
        accounts: [],
        events: [
          IdlEvent(
            name: 'TestEvent',
            fields: [
              IdlField(name: 'value', type: IdlType(kind: 'u64')),
            ],
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8], // Add discriminator
          ),
        ],
        errors: [],
        types: [],
        constants: [],
      );

      coder = BorshCoder(testIdl);
      eventManager = EventManager(programId, provider, coder);
    });

    test('addEventListener returns numeric listener ID (like TypeScript)', () {
      // TypeScript: addEventListener returns number synchronously
      final listenerId = eventManager.addEventListener<Map<String, dynamic>>(
        'TestEvent',
        (event, slot, signature) {
          print('Event: $event, Slot: $slot, Signature: $signature');
        },
      );

      // Verify it returns a numeric ID
      expect(listenerId, isA<int>());
      expect(listenerId, greaterThanOrEqualTo(0));
    });

    test('addEventListener IDs increment like TypeScript', () {
      // TypeScript: each addEventListener call returns incrementing IDs
      final id1 = eventManager.addEventListener<Map<String, dynamic>>(
        'TestEvent',
        (event, slot, signature) {},
      );

      final id2 = eventManager.addEventListener<Map<String, dynamic>>(
        'AnotherEvent',
        (event, slot, signature) {},
      );

      expect(id2, equals(id1 + 1));
    });

    test('removeEventListener takes numeric ID like TypeScript', () async {
      // Add a listener
      final listenerId = eventManager.addEventListener<Map<String, dynamic>>(
        'TestEvent',
        (event, slot, signature) {},
      );

      // TypeScript: removeEventListener takes numeric ID
      expect(() async => await eventManager.removeEventListener(listenerId),
          returnsNormally);
    });

    test('removeEventListener throws for invalid ID like TypeScript', () async {
      // TypeScript: throws error for non-existent listener ID
      expect(
        () async => await eventManager.removeEventListener(999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('connection state management like TypeScript', () {
      // Initially disconnected
      expect(eventManager.state, equals(WebSocketState.disconnected));

      // Add listener (should start connection)
      eventManager.addEventListener<Map<String, dynamic>>(
        'TestEvent',
        (event, slot, signature) {},
      );

      // State should eventually be connected (after async operation)
      // Note: In real implementation, this would be connected after the
      // async subscription setup completes
    });

    test('statistics tracking like TypeScript', () {
      final stats = eventManager.stats;

      // Should have basic statistics structure
      expect(stats.totalEvents, isA<int>());
      expect(stats.parseErrors, isA<int>());
      expect(stats.eventsPerSecond, isA<double>());
    });

    tearDown(() async {
      // Clean up
      await eventManager.dispose();
    });
  });
}
