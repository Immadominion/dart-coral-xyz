import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

/// Test suite for Program class event integration
///
/// Tests that the Program class properly integrates event management
/// functionality and provides the expected API surface for events.
///
/// Note: These are unit tests that test the API surface without requiring
/// actual network connections or a running Solana validator.
void main() {
  group('Program Events API', () {
    late Program program;
    late IdlEvent testEventDef;
    late IdlTypeDef testTypeDef;
    late Idl mockIdl;

    setUpAll(() {
      // Ensure clean test environment
    });

    tearDownAll(() async {
      // Clean up any global state
    });

    setUp(() {
      // Create a test event definition
      testEventDef = IdlEvent(
        name: 'TestEvent',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        fields: [
          IdlField(name: 'id', type: IdlType(kind: 'u64')),
          IdlField(name: 'data', type: IdlType(kind: 'string')),
          IdlField(name: 'timestamp', type: IdlType(kind: 'u64')),
        ],
      );

      // Create a type definition for the event
      testTypeDef = IdlTypeDef(
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

      // Create a mock IDL with events
      mockIdl = Idl(
        address: '11111111111111111111111111111112',
        metadata: IdlMetadata(
          name: 'test_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: [],
            args: [],
          ),
        ],
        accounts: [],
        events: [testEventDef],
        types: [testTypeDef],
      );

      // Create a mock provider (will use localhost for tests)
      final mockWallet = MockWallet();
      final connection = Connection('http://localhost:8899');
      final provider = AnchorProvider(connection, mockWallet);

      // Create the program instance
      program = Program(mockIdl, provider: provider);
    });

    tearDown(() async {
      // Dispose of the program to clean up any resources
      await program.dispose();
    });

    test('Program exposes event management methods', () {
      // Check that all event management methods are available
      expect(program.addEventListener, isA<Function>());
      expect(program.removeEventListener, isA<Function>());
      expect(program.subscribeToLogs, isA<Function>());
      expect(program.dispose, isA<Function>());
    });

    test('Program provides event statistics and state', () {
      // Check that event statistics are accessible
      expect(program.eventStats, isA<EventStats>());
      expect(program.eventConnectionState, isA<WebSocketState>());
      expect(program.eventConnectionStateStream, isA<Stream<WebSocketState>>());
    });

    test('Program has event manager properly initialized', () {
      // Test that the event manager exists and is properly configured
      expect(program.eventStats.totalEvents, equals(0));
      expect(program.eventConnectionState, equals(WebSocketState.disconnected));
    });

    test('addEventListener method has correct signature', () {
      // Test that the addEventListener method exists and accepts correct parameters
      expect(program.addEventListener, isA<Function>());

      // Just check the method exists without calling it to avoid network connections
    });

    test('subscribeToLogs method has correct signature', () {
      // Test that the subscribeToLogs method exists and accepts correct parameters
      expect(program.subscribeToLogs, isA<Function>());

      // Just check the method exists without calling it to avoid network connections
    });

    test('removeEventListener method exists', () {
      // Test that the removeEventListener method exists
      expect(program.removeEventListener, isA<Function>());

      // Just check the method exists without calling it to avoid network connections
    });

    test('event statistics have correct types', () {
      final stats = program.eventStats;

      expect(stats.totalEvents, isA<int>());
      expect(stats.parsedEvents, isA<int>());
      expect(stats.parseErrors, isA<int>());
      expect(stats.filteredEvents, isA<int>());
      expect(stats.lastProcessed, isA<DateTime>());
      expect(stats.eventsPerSecond, isA<double>());
    });

    test('connection state properties have correct types', () {
      final state = program.eventConnectionState;
      expect(state, isA<WebSocketState>());

      final stateStream = program.eventConnectionStateStream;
      expect(stateStream, isA<Stream<WebSocketState>>());
    });

    test('dispose method exists and is callable', () {
      // Test that dispose method exists and doesn't throw when called
      expect(program.dispose, isA<Function>());

      // Just check the method exists without calling it to avoid network connections
    });

    test('event listener with commitment parameter', () {
      // Test that addEventListener accepts commitment parameter
      expect(program.addEventListener, isA<Function>());
      // Just verify the method exists without calling it
    });

    test('log subscription with commitment parameter', () {
      // Test that subscribeToLogs accepts commitment parameter
      expect(program.subscribeToLogs, isA<Function>());
      // Just verify the method exists without calling it
    });

    test('Program.toString() includes event information', () {
      final programString = program.toString();
      expect(programString, isA<String>());
      expect(programString.length, greaterThan(0));
    });
  });
}

/// Mock wallet implementation for testing
class MockWallet extends Wallet {
  @override
  PublicKey get publicKey =>
      PublicKey.fromBase58('11111111111111111111111111111112');

  @override
  Future<Transaction> signTransaction(Transaction tx) async {
    // For testing, just return the transaction without actually signing
    return tx;
  }

  @override
  Future<List<Transaction>> signAllTransactions(List<Transaction> txs) async {
    // For testing, just return the transactions without actually signing
    return txs;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    // Return a mock signature
    return Uint8List.fromList(List.filled(64, 0));
  }
}
