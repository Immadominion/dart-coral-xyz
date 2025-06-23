import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';

import '../lib/src/event/event_log_parser.dart';
import '../lib/src/event/event_definition.dart';
import '../lib/src/types/public_key.dart';

void main() {
  group('EventLogParser', () {
    late PublicKey testProgramId;
    late List<EventDefinition> testEvents;
    late EventLogParser parser;

    setUp(() {
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111111');

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
            EventFieldDefinition(
              name: 'name',
              typeInfo: EventFieldTypeInfo(
                typeName: 'string',
                isPrimitive: true,
                isComplex: false,
                isOptional: false,
                hasNestedStructures: false,
                estimatedSize: 32,
              ),
            ),
          ],
          metadata: EventMetadata(
            totalFields: 2,
            hasOptionalFields: false,
            hasNestedStructures: false,
            estimatedSize: 40,
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
        EventDefinition(
          name: 'SimpleEvent',
          discriminator: [9, 10, 11, 12, 13, 14, 15, 16],
          fields: [
            EventFieldDefinition(
              name: 'flag',
              typeInfo: EventFieldTypeInfo(
                typeName: 'bool',
                isPrimitive: true,
                isComplex: false,
                isOptional: false,
                hasNestedStructures: false,
                estimatedSize: 1,
              ),
            ),
          ],
          metadata: EventMetadata(
            totalFields: 1,
            hasOptionalFields: false,
            hasNestedStructures: false,
            estimatedSize: 1,
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

      parser = EventLogParser.fromEvents(testProgramId, testEvents);
    });

    group('Constructor', () {
      test('creates parser from events', () {
        expect(parser.programId, equals(testProgramId));
        expect(parser.eventsByName.length, equals(2));
        expect(parser.eventsByDiscriminator.length, equals(2));
      });

      test('handles empty events list', () {
        final emptyParser = EventLogParser.fromEvents(testProgramId, []);
        expect(emptyParser.eventsByName.isEmpty, isTrue);
        expect(emptyParser.eventsByDiscriminator.isEmpty, isTrue);
      });
    });

    group('parseEvent', () {
      test('parses valid event with correct discriminator', () {
        // Create test data: discriminator + u64 value + string
        final discriminator = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final value = Uint8List(8);
        ByteData.view(value.buffer).setUint64(0, 12345, Endian.little);

        final stringData = utf8.encode('test');
        final stringLength = Uint8List(4);
        ByteData.view(stringLength.buffer)
            .setUint32(0, stringData.length, Endian.little);

        final eventData = Uint8List.fromList([
          ...discriminator,
          ...value,
          ...stringLength,
          ...stringData,
        ]);

        final base64Data = base64.encode(eventData);

        final result = parser.parseEvent(base64Data);

        expect(result, isNotNull);
        expect(result!.name, equals('TestEvent'));
        expect(result.data['value'], equals(12345));
        expect(result.data['name'], equals('test'));
        expect(result.isValid, isTrue);
      });

      test('returns null for unknown discriminator', () {
        final unknownData =
            Uint8List.fromList([99, 98, 97, 96, 95, 94, 93, 92, 1, 2, 3]);
        final base64Data = base64.encode(unknownData);

        final result = parser.parseEvent(base64Data);

        // Should return unknown event if allowUnknownEvents is true (default)
        expect(result, isNotNull);
        expect(result!.name, equals('unknown'));
      });

      test('handles invalid base64 data', () {
        final result = parser.parseEvent('invalid-base64!!!');
        expect(result, isNull);
      });

      test('handles malformed event data gracefully', () {
        // Valid discriminator but insufficient data
        final discriminator = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final incompleteData =
            Uint8List.fromList([...discriminator, 1, 2]); // Missing data
        final base64Data = base64.encode(incompleteData);

        final result = parser.parseEvent(base64Data);

        expect(result, isNotNull);
        expect(result!.name, equals('TestEvent'));
        // Should have partial data or null values for missing fields
      });

      test('validates event data when requested', () {
        final discriminator =
            Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16]);
        final eventData = Uint8List.fromList([
          ...discriminator,
          1, // bool true
        ]);

        final base64Data = base64.encode(eventData);

        final result = parser.parseEvent(base64Data, validate: true);

        expect(result, isNotNull);
        expect(result!.name, equals('SimpleEvent'));
        expect(result.data['flag'], equals(true));
        expect(result.isValid, isTrue);
      });
    });

    group('parseLogs', () {
      test('parses events from transaction logs', () {
        final discriminator =
            Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16]);
        final eventData = Uint8List.fromList([
          ...discriminator,
          1, // bool true
        ]);
        final base64Data = base64.encode(eventData);

        final logs = [
          'Program ${testProgramId.toString()} invoke [1]',
          'Program log: $base64Data',
          'Program ${testProgramId.toString()} success',
        ];

        final events = parser.parseLogs(logs).toList();

        expect(events.length, equals(1));
        expect(events[0].name, equals('SimpleEvent'));
        expect(events[0].data['flag'], equals(true));
      });

      test('handles CPI program context correctly', () {
        final otherProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

        final logs = [
          'Program ${testProgramId.toString()} invoke [1]',
          'Program log: test message', // Not an event
          'Program $otherProgramId invoke [2]', // CPI call
          'Program log: cpi message', // From other program
          'Program $otherProgramId success',
          'Program ${testProgramId.toString()} success',
        ];

        final events = parser.parseLogs(logs).toList();
        expect(events.length, equals(0)); // No valid events
      });

      test('handles multiple events in single transaction', () {
        final discriminator1 =
            Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16]);
        final eventData1 = Uint8List.fromList([...discriminator1, 1]);
        final base64Data1 = base64.encode(eventData1);

        final discriminator2 =
            Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16]);
        final eventData2 = Uint8List.fromList([...discriminator2, 0]);
        final base64Data2 = base64.encode(eventData2);

        final logs = [
          'Program ${testProgramId.toString()} invoke [1]',
          'Program log: $base64Data1',
          'Program log: $base64Data2',
          'Program ${testProgramId.toString()} success',
        ];

        final events = parser.parseLogs(logs).toList();

        expect(events.length, equals(2));
        expect(events[0].data['flag'], equals(true));
        expect(events[1].data['flag'], equals(false));
      });

      test('handles malformed first log gracefully', () {
        final logs = [
          'Invalid first log',
          'Program log: test',
        ];

        final events = parser.parseLogs(logs).toList();
        expect(events.length, equals(0));
      });

      test('filters non-program logs correctly', () {
        final logs = [
          'Program ${testProgramId.toString()} invoke [1]',
          'Random log message',
          'Another non-program log',
          'Program ${testProgramId.toString()} success',
        ];

        final events = parser.parseLogs(logs).toList();
        expect(events.length, equals(0));
      });
    });

    group('Field Parsing', () {
      test('parses basic types correctly', () {
        final testCases = [
          {
            'type': 'bool',
            'data': [1],
            'expected': true,
          },
          {
            'type': 'u8',
            'data': [255],
            'expected': 255,
          },
          {
            'type': 'u16',
            'data': [0xFF, 0xFF], // Little endian
            'expected': 65535,
          },
          {
            'type': 'u32',
            'data': [0xFF, 0xFF, 0xFF, 0xFF],
            'expected': 4294967295,
          },
        ];

        for (final testCase in testCases) {
          final field = EventFieldDefinition(
            name: 'test',
            typeInfo: EventFieldTypeInfo(
              typeName: testCase['type'] as String,
              isPrimitive: true,
              isComplex: false,
              isOptional: false,
              hasNestedStructures: false,
              estimatedSize: (testCase['data'] as List).length,
            ),
          );

          final data = Uint8List.fromList(testCase['data'] as List<int>);
          final result = parser.parseFieldValue(field, data, 0);

          expect(result.value, equals(testCase['expected']),
              reason: 'Failed for type ${testCase['type']}');
        }
      });

      test('parses string type correctly', () {
        final stringContent = 'Hello, World!';
        final stringBytes = utf8.encode(stringContent);
        final lengthBytes = Uint8List(4);
        ByteData.view(lengthBytes.buffer)
            .setUint32(0, stringBytes.length, Endian.little);

        final data = Uint8List.fromList([...lengthBytes, ...stringBytes]);

        final field = EventFieldDefinition(
          name: 'test',
          typeInfo: EventFieldTypeInfo(
            typeName: 'string',
            isPrimitive: true,
            isComplex: false,
            isOptional: false,
            hasNestedStructures: false,
            estimatedSize: data.length,
          ),
        );

        final result = parser.parseFieldValue(field, data, 0);

        expect(result.value, equals(stringContent));
        expect(result.bytesConsumed, equals(4 + stringBytes.length));
      });

      test('parses publicKey type correctly', () {
        final keyBytes = Uint8List.fromList(List.generate(32, (i) => i % 256));

        final field = EventFieldDefinition(
          name: 'test',
          typeInfo: EventFieldTypeInfo(
            typeName: 'publicKey',
            isPrimitive: true,
            isComplex: false,
            isOptional: false,
            hasNestedStructures: false,
            estimatedSize: 32,
          ),
        );

        final result = parser.parseFieldValue(field, keyBytes, 0);

        expect(result.value, isA<PublicKey>());
        expect(result.bytesConsumed, equals(32));
      });

      test('handles insufficient data gracefully', () {
        final field = EventFieldDefinition(
          name: 'test',
          typeInfo: EventFieldTypeInfo(
            typeName: 'u64',
            isPrimitive: true,
            isComplex: false,
            isOptional: false,
            hasNestedStructures: false,
            estimatedSize: 8,
          ),
        );

        final data = Uint8List.fromList([1, 2, 3]); // Only 3 bytes, need 8
        final result = parser.parseFieldValue(field, data, 0);

        expect(result.value, isNull); // Should handle gracefully
        expect(result.bytesConsumed, equals(0));
      });
    });

    group('Configuration', () {
      test('strict parsing throws on errors', () {
        final strictParser = EventLogParser.fromEvents(
          testProgramId,
          testEvents,
          config: EventLogParserConfig.strict(),
        );

        expect(
          () => strictParser.parseEvent('invalid-base64!!!'),
          throwsA(isA<EventParsingException>()),
        );
      });

      test('lenient parsing recovers from errors', () {
        final lenientParser = EventLogParser.fromEvents(
          testProgramId,
          testEvents,
          config: EventLogParserConfig.lenient(),
        );

        final result = lenientParser.parseEvent('invalid-base64!!!');
        expect(result, isNull); // Should not throw
      });

      test('unknown events handling respects configuration', () {
        final strictParser = EventLogParser.fromEvents(
          testProgramId,
          testEvents,
          config: EventLogParserConfig(allowUnknownEvents: false),
        );

        final unknownData =
            Uint8List.fromList([99, 98, 97, 96, 95, 94, 93, 92]);
        final base64Data = base64.encode(unknownData);

        final result = strictParser.parseEvent(base64Data);
        expect(result, isNull); // Should not return unknown event
      });
    });

    group('Filtering', () {
      test('filters events by name', () {
        final events = [
          ParsedEvent(
            name: 'TestEvent',
            data: {},
            definition: testEvents[0],
            rawData: Uint8List(0),
            discriminator: [],
            isValid: true,
          ),
          ParsedEvent(
            name: 'SimpleEvent',
            data: {},
            definition: testEvents[1],
            rawData: Uint8List(0),
            discriminator: [],
            isValid: true,
          ),
        ];

        final filtered =
            parser.filterEventsByName(events, {'TestEvent'}).toList();

        expect(filtered.length, equals(1));
        expect(filtered[0].name, equals('TestEvent'));
      });

      test('filters events by custom predicate', () {
        final events = [
          ParsedEvent(
            name: 'TestEvent',
            data: {'value': 100},
            definition: testEvents[0],
            rawData: Uint8List(0),
            discriminator: [],
            isValid: true,
          ),
          ParsedEvent(
            name: 'TestEvent',
            data: {'value': 50},
            definition: testEvents[0],
            rawData: Uint8List(0),
            discriminator: [],
            isValid: true,
          ),
        ];

        final filtered = parser
            .filterEvents(
              events,
              (event) => (event.data['value'] as int) > 75,
            )
            .toList();

        expect(filtered.length, equals(1));
        expect(filtered[0].data['value'], equals(100));
      });
    });

    group('Error Handling', () {
      test('throws EventParsingException for stack underflow', () {
        final context = ExecutionContext();

        expect(
          () => context.program(),
          throwsA(isA<EventParsingException>()),
        );

        expect(
          () => context.pop(),
          throwsA(isA<EventParsingException>()),
        );
      });

      test('handles execution context correctly', () {
        final context = ExecutionContext();

        context.push('program1');
        expect(context.program(), equals('program1'));

        context.push('program2');
        expect(context.program(), equals('program2'));

        context.pop();
        expect(context.program(), equals('program1'));
      });

      test('LogScanner filters non-program logs', () {
        final logs = [
          'Program abc invoke [1]',
          'Random log',
          'Another message',
          'Program def success',
        ];

        final scanner = LogScanner(logs);
        final filtered = <String>[];

        String? log;
        while ((log = scanner.next()) != null) {
          filtered.add(log!);
        }

        expect(filtered.length, equals(2));
        expect(filtered[0], startsWith('Program abc'));
        expect(filtered[1], startsWith('Program def'));
      });
    });

    group('TypeScript Parity', () {
      test('matches TypeScript log constants', () {
        expect(programLog, equals('Program log: '));
        expect(programData, equals('Program data: '));
        expect(programLogStartIndex, equals(13));
        expect(programDataStartIndex, equals(14));
      });

      test('matches TypeScript invoke regex behavior', () {
        final testCases = [
          {
            'log': 'Program 11111111111111111111111111111111 invoke [1]',
            'shouldMatch': true,
            'programId': '11111111111111111111111111111111',
            'depth': '1',
          },
          {
            'log':
                'Program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA invoke [2]',
            'shouldMatch': true,
            'programId': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
            'depth': '2',
          },
          {
            'log': 'Program 11111111111111111111111111111111 success',
            'shouldMatch': false,
          },
          {
            'log': 'Invalid log format',
            'shouldMatch': false,
          },
        ];

        for (final testCase in testCases) {
          final match =
              EventLogParser.invokeRegex.firstMatch(testCase['log'] as String);

          if (testCase['shouldMatch'] as bool) {
            expect(match, isNotNull,
                reason: 'Should match: ${testCase['log']}');
            expect(match!.group(1), equals(testCase['programId']));
            expect(match.group(2), equals(testCase['depth']));
          } else {
            expect(match, isNull,
                reason: 'Should not match: ${testCase['log']}');
          }
        }
      });

      test('handles program data vs program log correctly', () {
        final testData = 'SGVsbG8gV29ybGQ='; // "Hello World" in base64

        final programLogLine = 'Program log: $testData';
        final programDataLine = 'Program data: $testData';

        expect(programLogLine.startsWith(programLog), isTrue);
        expect(programDataLine.startsWith(programData), isTrue);

        final logData = programLogLine.substring(programLogStartIndex);
        final dataData = programDataLine.substring(programDataStartIndex);

        expect(logData, equals(testData));
        expect(dataData, equals(testData));
      });
    });
  });
}
