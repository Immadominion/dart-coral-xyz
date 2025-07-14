import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Example demonstrating how to use the Dart Anchor event system
///
/// This example shows how to:
/// - Set up event listening for an Anchor program
/// - Filter events by type and criteria
/// - Handle event callbacks with different listener types
/// - Parse event data from transaction logs
void main() async {
  // Create a program ID (replace with your actual program ID)
  final programId = PublicKey.fromBase58('11111111111111111111111111111112');

  // Create a sample IDL event definition
  final transferEvent = const IdlEvent(
    name: 'Transfer',
    fields: [
      IdlField(name: 'from', type: IdlType(kind: 'publicKey')),
      IdlField(name: 'to', type: IdlType(kind: 'publicKey')),
      IdlField(name: 'amount', type: IdlType(kind: 'u64')),
    ],
  );

  // Create type definition for the event
  final transferTypeDef = const IdlTypeDef(
    name: 'Transfer',
    type: IdlTypeDefType(
      kind: 'struct',
      fields: [
        IdlField(name: 'from', type: IdlType(kind: 'publicKey')),
        IdlField(name: 'to', type: IdlType(kind: 'publicKey')),
        IdlField(name: 'amount', type: IdlType(kind: 'u64')),
      ],
    ),
  );

  // Create a mock IDL with our event
  final idl = Idl(
    address: programId.toBase58(),
    metadata: const IdlMetadata(
      name: 'token_program',
      version: '0.1.0',
      spec: '0.1.0',
    ),
    instructions: [],
    events: [transferEvent],
    types: [transferTypeDef],
  );

  // Create a coder for parsing events
  final coder = BorshCoder(idl);

  // Create an event parser
  final parser = EventParser(
    programId: programId,
    coder: coder,
  );

  print('=== Basic Event Parsing ===');

  // Example: Parse events from transaction logs
  final sampleLogs = [
    'Program $programId invoke [1]',
    'Program log: Instruction: Transfer',
    'Program data: base64encodedEventData', // In reality, this would contain actual event data
    'Program $programId success',
  ];

  final events = parser.parseLogs(sampleLogs);
  print('Parsed ${events.length} events from logs');

  print(r'\n=== Event Filtering ===');

  // Create event filters
  final transferFilter = EventFilter(
    eventNames: {'Transfer'},
    programIds: {programId},
  );

  // Create a slot range filter (for demonstration)
  final recentFilter = const EventFilter(
    minSlot: 1000,
    maxSlot: 2000,
  );
  print(
      'Created slot range filter: ${recentFilter.minSlot} - ${recentFilter.maxSlot}',);

  // Example usage of filtered listener
  print('Setting up filtered event listener...');

  // This would normally connect to a WebSocket and listen for real events
  // For demonstration, we'll create mock events
  final mockEvents = [
    ParsedEvent(
      name: 'Transfer',
      data: {
        'from': 'SenderPublicKey...',
        'to': 'ReceiverPublicKey...',
        'amount': 1000000, // 1 SOL in lamports
      },
      context: EventContext(
        signature: 'mockTransactionSignature',
        slot: 1500,
        blockTime: DateTime.now(),
      ),
      eventDef: transferEvent,
    ),
    ParsedEvent(
      name: 'Mint',
      data: {
        'authority': 'AuthorityPublicKey...',
        'amount': 500000,
      },
      context: EventContext(
        signature: 'anotherMockSignature',
        slot: 1600,
        blockTime: DateTime.now(),
      ),
      eventDef: transferEvent, // Using same def for simplicity
    ),
  ];

  print(r'\n=== Event Listener Examples ===');

  // Example 1: Simple event handler
  print('1. Simple event processing:');
  for (final event in mockEvents) {
    if (transferFilter.matches(event, programId)) {
      print('  Transfer Event: ${event.data}');
    }
  }

  // Example 2: Batched event processing
  print(r'\n2. Batched event processing:');
  final batchedEvents = <ParsedEvent>[];
  for (final event in mockEvents) {
    batchedEvents.add(event);
  }

  if (batchedEvents.length >= 2) {
    print('  Processing batch of ${batchedEvents.length} events');
    for (final event in batchedEvents) {
      print('    - ${event.name}: ${event.context.slot}');
    }
  }

  print(r'\n=== Event Configuration ===');

  // Example subscription configuration
  final config = const EventSubscriptionConfig(
    includeFailed: false,
    maxBufferSize: 1000,
    reconnectTimeout: Duration(seconds: 30),
  );

  print('Subscription config:');
  print('  Commitment: ${config.commitment}');
  print('  Include failed: ${config.includeFailed}');
  print('  Max buffer size: ${config.maxBufferSize}');
  print('  Reconnect timeout: ${config.reconnectTimeout}');

  print(r'\n=== Event Replay ===');

  // Example replay configuration
  final replayConfig = EventReplayConfig(
    fromSlot: 1000,
    toSlot: 2000,
    maxEvents: 100,
    filter: transferFilter,
  );

  print('Replay config:');
  print('  From slot: ${replayConfig.fromSlot}');
  print('  To slot: ${replayConfig.toSlot}');
  print('  Max events: ${replayConfig.maxEvents}');
  print('  Include failed: ${replayConfig.includeFailed}');

  print(r'\n=== Event Stats ===');

  // Example event statistics
  final stats = EventStats(
    totalEvents: 1000,
    parsedEvents: 950,
    parseErrors: 25,
    filteredEvents: 25,
    lastProcessed: DateTime.now(),
    eventsPerSecond: 15.5,
  );

  print('Event processing stats:');
  print('  Total events: ${stats.totalEvents}');
  print('  Parsed events: ${stats.parsedEvents}');
  print('  Parse errors: ${stats.parseErrors}');
  print('  Filtered events: ${stats.filteredEvents}');
  print('  Events per second: ${stats.eventsPerSecond}');

  print(r'\n=== Event System Ready! ===');
  print(
      'The Dart Anchor event system is now fully implemented and ready to use.',);
  print(
      'Connect to a real Solana RPC WebSocket endpoint to start listening for live events.',);
}
