import 'dart:convert';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('EventLogParser IDL Delegation', () {
    late PublicKey testProgramId;
    late Idl testIdl;

    setUp(() {
      testProgramId = PublicKey.fromBase58('11111111111111111111111111111111');

      // Create IDL with events
      testIdl = const Idl(
        instructions: [],
        events: [
          IdlEvent(
            name: 'TestEvent',
            fields: [
              IdlField(
                name: 'flag',
                type: IdlType(kind: 'bool'),
              ),
            ],
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'TestEvent',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'flag',
                  type: IdlType(kind: 'bool'),
                ),
              ],
            ),
          ),
        ],
      );
    });

    group('IDL-based Constructor', () {
      test('creates parser from IDL with BorshEventCoder delegation', () {
        final parser = EventLogParser.fromIdl(testProgramId, testIdl);

        expect(parser.programId, equals(testProgramId));
        expect(parser.eventsByName.length, equals(1));
        expect(parser.eventsByName.containsKey('TestEvent'), isTrue);
      });

      test('handles IDL with no events gracefully', () {
        final emptyIdl = const Idl(instructions: []);
        final parser = EventLogParser.fromIdl(testProgramId, emptyIdl);

        expect(parser.eventsByName.isEmpty, isTrue);
        expect(parser.eventsByDiscriminator.isEmpty, isTrue);
      });
    });

    group('BorshEventCoder Delegation', () {
      test('uses BorshEventCoder for decoding when available', () {
        final parser = EventLogParser.fromIdl(testProgramId, testIdl);

        // Create test data: discriminator + bool true
        final testData = [1, 2, 3, 4, 5, 6, 7, 8, 1]; // discriminator + true
        final base64Data = base64Encode(testData);

        final result = parser.parseEvent(base64Data);

        expect(result, isNotNull);
        expect(result!.name, equals('TestEvent'));
        expect(result.data['flag'], equals(true));
        expect(result.isValid, isTrue);
      });

      test('falls back to manual parsing when BorshEventCoder fails', () {
        final parser = EventLogParser.fromIdl(testProgramId, testIdl);

        // Create invalid data that BorshEventCoder can't decode
        final invalidData = 'invalid-base64!!!';

        final result = parser.parseEvent(invalidData);

        // Should return null gracefully
        expect(result, isNull);
      });

      test('preserves context from BorshEventCoder decoding', () {
        final parser = EventLogParser.fromIdl(testProgramId, testIdl);

        final testData = [1, 2, 3, 4, 5, 6, 7, 8, 1];
        final base64Data = base64Encode(testData);

        final result = parser.parseEvent(base64Data);

        expect(result, isNotNull);
        expect(result!.rawData, isNotNull);
        expect(result.discriminator, isNotNull);
        expect(result.definition, isNotNull);
        expect(result.definition!.name, equals('TestEvent'));
      });
    });

    group('Backward Compatibility', () {
      test('legacy fromEvents constructor still works', () {
        final events = [
          EventDefinition.fromIdl(
            testIdl.events!.first,
            customTypes: {
              'TestEvent': testIdl.types!.first,
            },
          ),
        ];

        final parser = EventLogParser.fromEvents(testProgramId, events);

        final testData = [1, 2, 3, 4, 5, 6, 7, 8, 1];
        final base64Data = base64Encode(testData);

        final result = parser.parseEvent(base64Data);

        expect(result, isNotNull);
        expect(result!.name, equals('TestEvent'));
        expect(result.data['flag'], equals(true));
      });

      test('both paths produce equivalent results', () {
        // IDL-based parser (with BorshEventCoder)
        final idlParser = EventLogParser.fromIdl(testProgramId, testIdl);

        // Legacy parser (manual parsing)
        final events = [
          EventDefinition.fromIdl(
            testIdl.events!.first,
            customTypes: {
              'TestEvent': testIdl.types!.first,
            },
          ),
        ];
        final legacyParser = EventLogParser.fromEvents(testProgramId, events);

        final testData = [1, 2, 3, 4, 5, 6, 7, 8, 1];
        final base64Data = base64Encode(testData);

        final idlResult = idlParser.parseEvent(base64Data);
        final legacyResult = legacyParser.parseEvent(base64Data);

        expect(idlResult, isNotNull);
        expect(legacyResult, isNotNull);
        expect(idlResult!.name, equals(legacyResult!.name));
        expect(idlResult.data['flag'], equals(legacyResult.data['flag']));
        expect(idlResult.isValid, equals(legacyResult.isValid));
      });
    });

    group('TypeScript Pattern Compliance', () {
      test('matches TypeScript EventParser delegation pattern', () {
        final parser = EventLogParser.fromIdl(testProgramId, testIdl);

        // This should use the exact same pattern as TypeScript:
        // const event = this.coder.events.decode(logStr);
        final testData = [1, 2, 3, 4, 5, 6, 7, 8, 0]; // false
        final base64Data = base64Encode(testData);

        final result = parser.parseEvent(base64Data);

        expect(result, isNotNull);
        expect(result!.name, equals('TestEvent'));
        expect(result.data['flag'], equals(false));

        // The TypeScript pattern delegates to coder.events.decode()
        // Our pattern delegates to _eventCoder.decode()
        // Both should produce the same result
      });
    });
  });
}
