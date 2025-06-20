import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

/// Test suite for Program class event integration API surface
///
/// Tests that the Program class properly exposes event management
/// functionality and provides the expected API surface for events.
///
/// Note: These are unit tests that test the API surface without requiring
/// actual network connections or a running Solana validator.
void main() {
  group('Program Events API Surface', () {
    late Program program;
    late Idl mockIdl;

    setUp(() {
      // Create a test event definition
      final testEventDef = IdlEvent(
        name: 'TestEvent',
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
        fields: [
          IdlField(name: 'id', type: IdlType(kind: 'u64')),
          IdlField(name: 'data', type: IdlType(kind: 'string')),
          IdlField(name: 'timestamp', type: IdlType(kind: 'u64')),
        ],
      );

      // Create a type definition for the event
      final testTypeDef = IdlTypeDef(
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

      // Create a mock provider
      final mockWallet = MockWallet();
      final connection = Connection('http://localhost:8899');
      final provider = AnchorProvider(connection, mockWallet);

      // Create the program instance
      program = Program(mockIdl, provider: provider);
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

    test('Program event management API is type-safe', () {
      // Test that the API methods exist and have correct signatures
      // This is mainly a compile-time test to ensure the API surface is correct

      // addEventListener should accept event name and callback
      expect(() => program.addEventListener, returnsNormally);

      // removeEventListener should accept subscription
      expect(() => program.removeEventListener, returnsNormally);

      // subscribeToLogs should accept callback
      expect(() => program.subscribeToLogs, returnsNormally);

      // dispose should be available
      expect(() => program.dispose, returnsNormally);
    });

    test('Event API matches TypeScript SDK interface', () {
      // Verify that the Dart API surface matches the TypeScript SDK
      // This ensures parity between the two implementations

      // TypeScript: program.addEventListener(eventName, callback, commitment?)
      expect(program.addEventListener, isA<Function>());

      // TypeScript: program.removeEventListener(listener)
      expect(program.removeEventListener, isA<Function>());

      // Additional Dart-specific methods that extend the TS API
      expect(program.subscribeToLogs, isA<Function>());
      expect(program.dispose, isA<Function>());
      expect(program.eventStats, isA<EventStats>());
      expect(program.eventConnectionState, isA<WebSocketState>());
      expect(program.eventConnectionStateStream, isA<Stream<WebSocketState>>());
    });
  });
}

/// Mock wallet implementation for testing
class MockWallet implements Wallet {
  @override
  PublicKey get publicKey =>
      PublicKey.fromBase58('11111111111111111111111111111112');

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    // Mock implementation - just return the transaction with a dummy signature
    final signature = Uint8List.fromList(List.filled(64, 0));
    transaction.addSignature(publicKey, signature);
    return transaction;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions) async {
    return Future.wait(transactions.map(signTransaction));
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    // Mock implementation
    return Uint8List.fromList(List.filled(64, 0));
  }
}
