import 'dart:convert';
import 'package:test/test.dart';
import '../lib/src/event/borsh_event_coder.dart';
import '../lib/src/idl/idl.dart';

void main() {
  group('BorshEventCoder Integration', () {
    test('should integrate with IDL event definitions', () {
      // Create a simple IDL with events
      final idl = Idl(
        address: '11111111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'test_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [], // Required but empty for event testing
        events: [
          IdlEvent(
            name: 'TestEvent',
            fields: [
              IdlField(
                name: 'value',
                type: IdlType(kind: 'u64'),
              ),
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
                  name: 'value',
                  type: IdlType(kind: 'u64'),
                ),
                IdlField(
                  name: 'flag',
                  type: IdlType(kind: 'bool'),
                ),
              ],
            ),
          ),
        ],
      );

      // This should work without errors
      expect(() => BorshEventCoder(idl), returnsNormally);
    });

    test('should decode simple event correctly', () {
      final idl = Idl(
        instructions: [], // Required but empty
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

      final coder = BorshEventCoder(idl);

      // Create test data: discriminator + bool true
      final testData = [1, 2, 3, 4, 5, 6, 7, 8, 1]; // discriminator + true
      final base64Data = base64Encode(testData);

      final result = coder.decode(base64Data);

      expect(result, isNotNull);
      expect(result!.name, equals('TestEvent'));
      expect(result.data['flag'], equals(true));
    });
  });
}
