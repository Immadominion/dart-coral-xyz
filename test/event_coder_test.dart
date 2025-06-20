import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  group('EventCoder Tests', () {
    late Idl testIdl;
    late BorshEventCoder eventCoder;

    setUp(() {
      // Create a test IDL with event definitions
      testIdl = Idl(
        address: 'EVENT123456789012345678901234567890ABCDEF',
        metadata: IdlMetadata(
          name: 'test_events',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [],
        events: [
          IdlEvent(
            name: 'transferEvent',
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            fields: [],
          ),
          IdlEvent(
            name: 'depositEvent',
            discriminator: [10, 20, 30, 40, 50, 60, 70, 80],
            fields: [],
          ),
          IdlEvent(
            name: 'complexEvent',
            discriminator: [100, 101, 102, 103, 104, 105, 106, 107],
            fields: [],
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'transferEvent',
            type: IdlTypeDefType(
              // Changed from IdlType to IdlTypeDefType
              kind: 'struct',
              fields: [
                IdlField(
                    name: 'from', type: const IdlType(kind: 'pubkey')), // Fixed
                IdlField(
                    name: 'to', type: const IdlType(kind: 'pubkey')), // Fixed
                IdlField(
                    name: 'amount', type: const IdlType(kind: 'u64')), // Fixed
              ],
            ),
          ),
          IdlTypeDef(
            name: 'depositEvent',
            type: IdlTypeDefType(
              // Changed from IdlType to IdlTypeDefType
              kind: 'struct',
              fields: [
                IdlField(
                    name: 'user', type: const IdlType(kind: 'pubkey')), // Fixed
                IdlField(
                    name: 'amount', type: const IdlType(kind: 'u64')), // Fixed
                IdlField(
                    name: 'timestamp',
                    type: const IdlType(kind: 'i64')), // Fixed
              ],
            ),
          ),
          IdlTypeDef(
            name: 'complexEvent',
            type: IdlTypeDefType(
              // Changed from IdlType to IdlTypeDefType
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'data',
                  type: const IdlType(
                      kind: 'vec',
                      inner: IdlType(kind: 'u32')), // Fixed complex type
                ),
                IdlField(
                  name: 'optionalMessage',
                  type: const IdlType(
                      kind: 'option',
                      inner: IdlType(kind: 'string')), // Fixed complex type
                ),
                IdlField(
                  name: 'flags',
                  type: const IdlType(
                      kind: 'array',
                      inner: IdlType(kind: 'bool'),
                      size: 3), // Fixed complex type
                ),
              ],
            ),
          ),
        ],
      );

      eventCoder = BorshEventCoder(testIdl);
    });

    group('Event Decoding', () {
      test('should decode simple transfer event correctly', () {
        // Create test event data: discriminator + borsh-encoded data
        final discriminator = [1, 2, 3, 4, 5, 6, 7, 8];

        // Manually create borsh-encoded event data
        final serializer = BorshSerializer();
        serializer.writeString(
            'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'); // from
        serializer
            .writeString('So11111111111111111111111111111111111111112'); // to
        serializer.writeU64(1000000); // amount

        final eventData = serializer.toBytes();
        final fullData = Uint8List.fromList([...discriminator, ...eventData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);

        expect(event, isNotNull);
        expect(event!.name, equals('transferEvent'));
        expect(event.data['from'],
            equals('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'));
        expect(event.data['to'],
            equals('So11111111111111111111111111111111111111112'));
        expect(event.data['amount'], equals(1000000));
      });

      test('should decode deposit event with timestamp', () {
        final discriminator = [10, 20, 30, 40, 50, 60, 70, 80];

        final serializer = BorshSerializer();
        serializer.writeString('11111111111111111111111111111112'); // user
        serializer.writeU64(500000); // amount
        serializer.writeI64(1640995200); // timestamp

        final eventData = serializer.toBytes();
        final fullData = Uint8List.fromList([...discriminator, ...eventData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);

        expect(event, isNotNull);
        expect(event!.name, equals('depositEvent'));
        expect(event.data['user'], equals('11111111111111111111111111111112'));
        expect(event.data['amount'], equals(500000));
        expect(event.data['timestamp'], equals(1640995200));
      });

      test('should decode complex event with vectors and options', () {
        final discriminator = [100, 101, 102, 103, 104, 105, 106, 107];

        final serializer = BorshSerializer();

        // Encode vector of u32
        final dataList = [1, 2, 3, 4, 5];
        serializer.writeU32(dataList.length);
        for (final item in dataList) {
          serializer.writeU32(item);
        }

        // Encode optional string (Some)
        serializer.writeU8(1); // Some
        serializer.writeString('test message');

        // Encode array of booleans
        final flags = [true, false, true];
        for (final flag in flags) {
          serializer.writeBool(flag);
        }

        final eventData = serializer.toBytes();
        final fullData = Uint8List.fromList([...discriminator, ...eventData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);

        expect(event, isNotNull);
        expect(event!.name, equals('complexEvent'));
        expect(event.data['data'], equals(dataList));
        expect(event.data['optionalMessage'], equals('test message'));
        expect(event.data['flags'], equals(flags));
      });

      test('should decode complex event with null optional field', () {
        final discriminator = [100, 101, 102, 103, 104, 105, 106, 107];

        final serializer = BorshSerializer();

        // Encode vector of u32
        final dataList = [10, 20];
        serializer.writeU32(dataList.length);
        for (final item in dataList) {
          serializer.writeU32(item);
        }

        // Encode optional string (None)
        serializer.writeU8(0); // None

        // Encode array of booleans
        final flags = [false, false, false];
        for (final flag in flags) {
          serializer.writeBool(flag);
        }

        final eventData = serializer.toBytes();
        final fullData = Uint8List.fromList([...discriminator, ...eventData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);

        expect(event, isNotNull);
        expect(event!.name, equals('complexEvent'));
        expect(event.data['data'], equals(dataList));
        expect(event.data['optionalMessage'], isNull);
        expect(event.data['flags'], equals(flags));
      });

      test('should return null for unrecognized discriminator', () {
        final unknownDiscriminator = [255, 254, 253, 252, 251, 250, 249, 248];
        final fakeData =
            Uint8List.fromList([...unknownDiscriminator, 1, 2, 3, 4]);
        final base64Log = base64.encode(fakeData);

        final event = eventCoder.decode(base64Log);
        expect(event, isNull);
      });

      test('should return null for invalid base64 log', () {
        final invalidBase64 = 'this is not valid base64';

        final event = eventCoder.decode(invalidBase64);
        expect(event, isNull);
      });

      test('should return null for empty log', () {
        final emptyLog = '';

        final event = eventCoder.decode(emptyLog);
        expect(event, isNull);
      });

      test('should return null for log too short for discriminator', () {
        final shortData = Uint8List.fromList([1, 2, 3]); // Less than 8 bytes
        final base64Log = base64.encode(shortData);

        final event = eventCoder.decode(base64Log);
        expect(event, isNull);
      });

      test('should handle corrupted event data gracefully', () {
        final discriminator = [1, 2, 3, 4, 5, 6, 7, 8];
        final corruptedData = [255, 255, 255]; // Invalid data for the event
        final fullData =
            Uint8List.fromList([...discriminator, ...corruptedData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);
        expect(event, isNull); // Should fail gracefully
      });
    });

    group('Event Coder Edge Cases', () {
      test('should handle IDL with no events', () {
        final emptyEventsIdl = Idl(
          address: 'EMPTY123456789012345678901234567890ABCDEF',
          metadata: IdlMetadata(
            name: 'empty_events',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [],
          events: null,
          types: null,
        );

        final emptyCoder = BorshEventCoder(emptyEventsIdl);

        final someData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        final base64Log = base64.encode(someData);

        final event = emptyCoder.decode(base64Log);
        expect(event, isNull);
      });

      test('should throw on IDL with events but no types', () {
        final invalidIdl = Idl(
          address: 'INVALID123456789012345678901234567890ABCDEF',
          metadata: IdlMetadata(
            name: 'invalid_events',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [],
          events: [
            IdlEvent(
              name: 'testEvent',
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
              fields: [],
            ),
          ],
          types: null, // Missing types
        );

        expect(
          () => BorshEventCoder(invalidIdl),
          throwsA(isA<EventCoderException>()),
        );
      });

      test('should throw on event with missing type definition', () {
        final invalidIdl = Idl(
          address: 'INVALID123456789012345678901234567890ABCDEF',
          metadata: IdlMetadata(
            name: 'missing_type_events',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [],
          events: [
            IdlEvent(
              name: 'missingEvent',
              discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
              fields: [],
            ),
          ],
          types: [
            IdlTypeDef(
              name: 'differentEvent',
              type: IdlTypeDefType(
                // Changed from IdlType to IdlTypeDefType
                kind: 'struct',
                fields: [
                  IdlField(
                      name: 'data', type: const IdlType(kind: 'u32')), // Fixed
                ],
              ),
            ),
          ],
        );

        expect(
          () => BorshEventCoder(invalidIdl),
          throwsA(isA<EventCoderException>()),
        );
      });
    });

    group('Event Data Types', () {
      test('should create Event object with correct properties', () {
        final discriminator = [1, 2, 3, 4, 5, 6, 7, 8];

        final serializer = BorshSerializer();
        serializer.writeString('TestFromAddress');
        serializer.writeString('TestToAddress');
        serializer.writeU64(12345);

        final eventData = serializer.toBytes();
        final fullData = Uint8List.fromList([...discriminator, ...eventData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);

        expect(event, isNotNull);
        expect(event, isA<Event>());
        expect(event!.name, isA<String>());
        expect(event.data, isA<Map<String, dynamic>>());
        expect(event.eventDef, isA<IdlEvent>());
        expect(event.eventDef.name, equals('transferEvent'));
      });

      test('should provide meaningful toString representation', () {
        final discriminator = [10, 20, 30, 40, 50, 60, 70, 80];

        final serializer = BorshSerializer();
        serializer.writeString('TestUser');
        serializer.writeU64(999);
        serializer.writeI64(1234567890);

        final eventData = serializer.toBytes();
        final fullData = Uint8List.fromList([...discriminator, ...eventData]);
        final base64Log = base64.encode(fullData);

        final event = eventCoder.decode(base64Log);

        expect(event, isNotNull);
        final stringRep = event.toString();
        expect(stringRep, contains('depositEvent'));
        expect(stringRep, contains('Event'));
      });
    });

    group('Event Log Parsing', () {
      test('should handle multiple events with same structure', () {
        // Create two transfer events with different data
        final events = [
          {
            'from': 'Address1',
            'to': 'Address2',
            'amount': 100,
          },
          {
            'from': 'Address3',
            'to': 'Address4',
            'amount': 200,
          },
        ];

        final discriminator = [1, 2, 3, 4, 5, 6, 7, 8];
        final decodedEvents = <Event>[];

        for (final eventData in events) {
          final serializer = BorshSerializer();
          serializer.writeString(eventData['from'] as String);
          serializer.writeString(eventData['to'] as String);
          serializer.writeU64(eventData['amount'] as int);

          final encodedData = serializer.toBytes();
          final fullData =
              Uint8List.fromList([...discriminator, ...encodedData]);
          final base64Log = base64.encode(fullData);

          final event = eventCoder.decode(base64Log);
          expect(event, isNotNull);
          decodedEvents.add(event!);
        }

        expect(decodedEvents.length, equals(2));
        expect(decodedEvents[0].data['amount'], equals(100));
        expect(decodedEvents[1].data['amount'], equals(200));
      });

      test('should filter events by discriminator correctly', () {
        final logs = <String>[];

        // Create transfer event
        final transferDiscriminator = [1, 2, 3, 4, 5, 6, 7, 8];
        final transferSerializer = BorshSerializer();
        transferSerializer.writeString('From1');
        transferSerializer.writeString('To1');
        transferSerializer.writeU64(100);
        final transferData = Uint8List.fromList(
            [...transferDiscriminator, ...transferSerializer.toBytes()]);
        logs.add(base64.encode(transferData));

        // Create deposit event
        final depositDiscriminator = [10, 20, 30, 40, 50, 60, 70, 80];
        final depositSerializer = BorshSerializer();
        depositSerializer.writeString('User1');
        depositSerializer.writeU64(200);
        depositSerializer.writeI64(1640995200);
        final depositData = Uint8List.fromList(
            [...depositDiscriminator, ...depositSerializer.toBytes()]);
        logs.add(base64.encode(depositData));

        // Create unknown event
        final unknownData = Uint8List.fromList(
            [255, 254, 253, 252, 251, 250, 249, 248, 1, 2, 3]);
        logs.add(base64.encode(unknownData));

        final decodedEvents = logs
            .map((log) => eventCoder.decode(log))
            .where((event) => event != null)
            .toList();

        expect(decodedEvents.length, equals(2));
        expect(decodedEvents[0]!.name, equals('transferEvent'));
        expect(decodedEvents[1]!.name, equals('depositEvent'));
      });
    });
  });
}
