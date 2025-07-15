import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart' as tx;

void main() {
  group('InstructionBuilder', () {
    late Idl idl;
    late InstructionCoder instructionCoder;
    late AccountsResolver accountsResolver;
    late PublicKey userKey;

    setUp(() {
      // Set up test IDL
      idl = const Idl(
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
              IdlInstructionAccount(
                name: 'optionalAccount',
                optional: true,
              ),
            ],
            args: [
              IdlField(name: 'amount', type: IdlType(kind: 'u64')),
              IdlField(name: 'data', type: IdlType(kind: 'string')),
            ],
            discriminator: [],
          ),
        ],
      );

      instructionCoder = BorshInstructionCoder(idl);
      userKey = PublicKey.fromBase58('11111111111111111111111111111111');
      accountsResolver = AccountsResolver(
        args: [42, 'test'],
        accounts: {'user': userKey},
        provider: AnchorProvider.defaultProvider(),
        programId: userKey,
        idlInstruction: idl.instructions.first,
        idlTypes: [],
      );
    });

    test('builds instruction with required args and accounts', () async {
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      // Add required arguments and accounts
      builder.args({
        'amount': 42,
        'data': 'test',
      }).accounts({
        'user': userKey,
      }).addSigner(userKey);

      final result = await builder.build();

      expect(result.data, isNotEmpty);
      expect(result.metas, hasLength(1));
      expect(result.metas.first.pubkey, equals(userKey));
      expect(result.metas.first.isSigner, isTrue);
      expect(result.metas.first.isWritable, isTrue);
      expect(result.signers, contains(userKey));
    });

    test('handles optional accounts properly', () async {
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      // Only add required accounts and args
      builder.args({
        'amount': 42,
        'data': 'test',
      }).accounts({
        'user': userKey,
      }).addSigner(userKey);

      final result = await builder.build();

      // Should not include optional account
      expect(result.metas, hasLength(1));
    });

    test('validates missing required arguments', () async {
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      // Missing 'data' argument
      builder.args({
        'amount': 42,
      }).accounts({
        'user': userKey,
      }).addSigner(userKey);

      expect(builder.build, throwsA(isA<IdlError>()));
    });

    test('validates missing required accounts', () async {
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      // Missing 'user' account
      builder.args({
        'amount': 42,
        'data': 'test',
      });

      expect(builder.build, throwsA(isA<IdlError>()));
    });

    test('validates missing required signers', () async {
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      // Account marked as signer but not added to signers
      builder.args({
        'amount': 42,
        'data': 'test',
      }).accounts({
        'user': userKey,
      });

      expect(builder.build, throwsA(isA<IdlError>()));
    });

    test('supports remaining accounts', () async {
      final extraAccount =
          PublicKey.fromBase58('So11111111111111111111111111111111111111112');
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      builder
          .args({
            'amount': 42,
            'data': 'test',
          })
          .accounts({
            'user': userKey,
          })
          .addSigner(userKey)
          .remainingAccounts([
            tx.AccountMeta(
              pubkey: extraAccount,
              isWritable: true,
              isSigner: false,
            ),
          ]);

      final result = await builder.build();

      expect(result.metas, hasLength(2));
      expect(result.metas.last.pubkey, equals(extraAccount));
      expect(result.metas.last.isWritable, isTrue);
      expect(result.metas.last.isSigner, isFalse);
    });

    test('supports instruction context', () async {
      const context = Context<DynamicAccounts>();
      final builder = InstructionBuilder(
        idl: idl,
        methodName: 'testMethod',
        instructionCoder: instructionCoder,
        accountsResolver: accountsResolver,
      );

      builder
          .args({
            'amount': 42,
            'data': 'test',
          })
          .accounts({
            'user': userKey,
          })
          .addSigner(userKey)
          .context(context);

      final result = await builder.build();

      expect(result.context, equals(context));
    });
  });
}
