import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'test_helpers.dart';

void main() {
  group('Test Helpers', () {
    test('createTestAccountData returns correct map', () {
      final data = createTestAccountData(name: 'foo', lamports: 42);
      expect(data['name'], 'foo');
      expect(data['lamports'], 42);
    });

    test('buildTestInstruction returns TransactionInstruction', () async {
      final keypair = await createTestKeypair();
      final ix = buildTestInstruction(
        programId: keypair.publicKey,
        accounts: [],
        data: [1, 2, 3],
      );
      expect(ix.programId, keypair.publicKey);
      expect(ix.data.length, 3);
    });
  });
}
