import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('AccountsCoder Tests', () {
    late Idl testIdl;
    late BorshAccountsCoder<String> accountsCoder;

    setUp(() {
      testIdl = Idl(
        address: 'test_address',
        metadata: IdlMetadata(name: 'test', version: '0.1.0', spec: '0.1.0'),
        instructions: [],
        accounts: [
          IdlAccount(
            name: 'user',
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'authority', type: IdlType(kind: 'pubkey')),
                IdlField(name: 'name', type: IdlType(kind: 'string')),
                IdlField(name: 'age', type: IdlType(kind: 'u32')),
                IdlField(name: 'isActive', type: IdlType(kind: 'bool')),
              ],
            ),
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'user',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'authority', type: IdlType(kind: 'pubkey')),
                IdlField(name: 'name', type: IdlType(kind: 'string')),
                IdlField(name: 'age', type: IdlType(kind: 'u32')),
                IdlField(name: 'isActive', type: IdlType(kind: 'bool')),
              ],
            ),
          ),
        ],
      );
      accountsCoder = BorshAccountsCoder(testIdl);
    });

    test('encode should encode user account correctly', () async {
      final userData = {
        'authority': 'ED1zJJZEkGpw3Zx3XNDFpJN7EGF4Q7z9Z9Y2Z9Z9Z9Z9Z9Z9',
        'name': 'Alice',
        'age': 25,
        'isActive': true,
      };
      final encoded = await accountsCoder.encode('user', userData);
      expect(encoded, isA<Uint8List>());
      expect(encoded.length, greaterThan(0));
    });
  });
}
