import 'dart:typed_data';

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart' as tx;
import 'package:test/test.dart';

void main() {
  group('InstructionBuilder concepts', () {
    late PublicKey userKey;

    setUp(() {
      userKey = PublicKey.fromBase58('11111111111111111111111111111111');
    });

    test('basic transaction instruction creation', () {
      // Test basic transaction instruction creation without complex builder
      final instruction = tx.TransactionInstruction(
        programId: userKey,
        accounts: [
          tx.AccountMeta(
            pubkey: userKey,
            isSigner: true,
            isWritable: true,
          ),
        ],
        data: Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(instruction.programId, equals(userKey));
      expect(instruction.accounts, hasLength(1));
      expect(instruction.accounts.first.pubkey, equals(userKey));
      expect(instruction.accounts.first.isSigner, isTrue);
      expect(instruction.accounts.first.isWritable, isTrue);
      expect(instruction.data, equals([1, 2, 3, 4]));
    });

    test('account meta creation', () {
      final accountMeta = tx.AccountMeta(
        pubkey: userKey,
        isSigner: false,
        isWritable: true,
      );

      expect(accountMeta.pubkey, equals(userKey));
      expect(accountMeta.isSigner, isFalse);
      expect(accountMeta.isWritable, isTrue);
    });

    test('context creation', () {
      final accounts = DynamicAccounts();
      final context = Context<DynamicAccounts>(accounts: accounts);
      expect(context.accounts, isNotNull);
    });

    test('basic IDL structure', () {
      // Test basic IDL creation for instruction building concepts
      const idl = Idl(
        address: 'TestAddress',
        metadata: IdlMetadata(
          name: 'TestProgram',
          version: '0.0.1',
          spec: 'anchor-idl/0.0.1',
        ),
        instructions: [
          IdlInstruction(
            name: 'testMethod',
            accounts: [
              IdlInstructionAccount(
                name: 'user',
                writable: true,
                signer: true,
              ),
            ],
            args: [
              IdlField(name: 'amount', type: IdlType(kind: 'u64')),
            ],
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
          ),
        ],
      );

      expect(idl.instructions, hasLength(1));
      expect(idl.instructions.first.name, equals('testMethod'));
      expect(idl.instructions.first.accounts, hasLength(1));
      expect(idl.instructions.first.args, hasLength(1));
    });
  });
}
