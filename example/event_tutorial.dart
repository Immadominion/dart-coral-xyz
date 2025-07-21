/// Event Tutorial Example - TypeScript Anchor "events" Tutorial Equivalent
///
/// This example shows how to use the Dart Anchor event system to:
/// - Define custom IdlEvent and IdlTypeDef
/// - Parse mock transaction logs via EventParser
/// - Filter events using EventFilter
/// - Batch process ParsedEvent lists
/// - Configure subscription and replay patterns

import 'package:coral_xyz/coral_xyz_anchor.dart';

Future<void> main() async {
  print('🎉 Event Tutorial Example');
  print('===========================\n');

  // Program ID (replace with actual program ID when deploying)
  final programId = PublicKey.fromBase58(
    'EvT111111111111111111111111111111111111',
  );

  // Define an event in IDL
  final myEvent = const IdlEvent(
    name: 'MyEvent',
    fields: [
      IdlField(name: 'user', type: IdlType(kind: 'publicKey')),
      IdlField(name: 'value', type: IdlType(kind: 'u64')),
    ],
  );

  // Define event type for parsing
  final myEventType = const IdlTypeDef(
    name: 'MyEvent',
    type: IdlTypeDefType(
      kind: 'struct',
      fields: [
        IdlField(name: 'user', type: IdlType(kind: 'publicKey')),
        IdlField(name: 'value', type: IdlType(kind: 'u64')),
      ],
    ),
  );

  // Build minimal IDL with the event
  final idl = Idl(
    address: programId.toBase58(),
    metadata: const IdlMetadata(
      name: 'event_program',
      version: '0.1.0',
      spec: '0.1.0',
    ),
    instructions: [],
    events: [myEvent],
    types: [myEventType],
  );

  // Create parser
  final coder = BorshCoder(idl);
  final parser = EventParser(
    programId: programId,
    coder: coder,
  );

  print('1. Parsing mock transaction logs');
  final sampleLogs = [
    'Program $programId invoke [1]',
    'Program log: Instruction: MyEvent',
    'Program data: AAAA... (base64)',
    'Program $programId success',
  ];
  final events = parser.parseLogs(sampleLogs);
  print('   ✓ Parsed ${events.length} events');

  print('\n2. Filtering events by name');
  final filter = EventFilter(eventNames: {'MyEvent'});
  final filtered = events.where((e) => filter.matches(e, programId)).toList();
  print('   ✓ Filtered ${filtered.length} MyEvent occurrences');

  print('\n3. Batch processing');
  if (filtered.isNotEmpty) {
    print('   Processing ${filtered.length} events in batch');
    for (final evt in filtered) {
      print('   - ${evt.name} value: ${evt.data['value']}');
    }
  }

  print('\n4. Subscription & replay configs');
  const subConfig = EventSubscriptionConfig(maxBufferSize: 500);
  final replayConfig = EventReplayConfig(
    fromSlot: 100,
    toSlot: 200,
    maxEvents: 10,
    filter: filter,
  );
  print('   ✓ Subscription max buffer: ${subConfig.maxBufferSize}');
  print('   ✓ Replay slots: ${replayConfig.fromSlot}-${replayConfig.toSlot}');

  print('\n5. Event stats example');
  final stats = EventStats(
    totalEvents: 100,
    parsedEvents: 80,
    parseErrors: 5,
    filteredEvents: 75,
    lastProcessed: DateTime.now(),
    eventsPerSecond: 12.5,
  );
  print('   Total: ${stats.totalEvents}, Filtered: ${stats.filteredEvents}');

  print('\n✅ Event tutorial completed!');
}
