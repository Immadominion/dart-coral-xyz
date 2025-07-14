import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('MultisigUtils Tests', () {
    late PublicKey multisigKey;
    late PublicKey programId;
    late List<PublicKey> owners;

    setUpAll(() {
      multisigKey = PublicKey.fromBase58('11111111111111111111111111111112');
      programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
      owners = [
        PublicKey.fromBase58('So11111111111111111111111111111111111111112'),
        PublicKey.fromBase58('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'),
        PublicKey.fromBase58('9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM'),
      ];
    });

    test('createMultisigSeeds should create proper seeds', () {
      final seeds = MultisigUtils.createMultisigSeeds(multisigKey);

      expect(seeds, hasLength(1));
      expect(seeds[0], equals(multisigKey.bytes));
    });

    test('findMultisigSigner should derive PDA', () async {
      final result =
          await MultisigUtils.findMultisigSigner(multisigKey, programId);

      expect(result.address, isA<PublicKey>());
      expect(result.bump, greaterThanOrEqualTo(0));
      expect(result.bump, lessThan(256));
    });

    test('validateThreshold should validate correctly', () {
      expect(MultisigUtils.validateThreshold(1, 3), isTrue);
      expect(MultisigUtils.validateThreshold(3, 3), isTrue);
      expect(MultisigUtils.validateThreshold(0, 3), isFalse);
      expect(MultisigUtils.validateThreshold(4, 3), isFalse);
    });

    test('hasThresholdSignatures should check signatures correctly', () {
      expect(
          MultisigUtils.hasThresholdSignatures([true, true, false], 2), isTrue,);
      expect(MultisigUtils.hasThresholdSignatures([true, false, false], 2),
          isFalse,);
      expect(MultisigUtils.hasThresholdSignatures([false, false, false], 1),
          isFalse,);
    });

    test('createTransaction should create proper transaction', () {
      final accounts = [
        TransactionAccount(
          pubkey: multisigKey,
          isSigner: false,
          isWritable: true,
        ),
      ];
      final data = Uint8List.fromList([1, 2, 3, 4]);

      final transaction = MultisigUtils.createTransaction(
        multisig: multisigKey,
        programId: programId,
        accounts: accounts,
        data: data,
        ownerCount: 3,
      );

      expect(transaction.multisig, equals(multisigKey));
      expect(transaction.programId, equals(programId));
      expect(transaction.accounts, equals(accounts));
      expect(transaction.data, equals(data));
      expect(transaction.signers, hasLength(3));
      expect(transaction.signers.every((s) => !s), isTrue);
      expect(transaction.didExecute, isFalse);
    });

    test('signTransaction should update signers', () {
      final transaction = MultisigUtils.createTransaction(
        multisig: multisigKey,
        programId: programId,
        accounts: [],
        data: Uint8List(0),
        ownerCount: 3,
      );

      final signedTransaction = MultisigUtils.signTransaction(transaction, 1);

      expect(signedTransaction.signers[0], isFalse);
      expect(signedTransaction.signers[1], isTrue);
      expect(signedTransaction.signers[2], isFalse);
    });

    test('signTransaction should validate owner index', () {
      final transaction = MultisigUtils.createTransaction(
        multisig: multisigKey,
        programId: programId,
        accounts: [],
        data: Uint8List(0),
        ownerCount: 3,
      );

      expect(() => MultisigUtils.signTransaction(transaction, -1),
          throwsA(isA<ArgumentError>()),);
      expect(() => MultisigUtils.signTransaction(transaction, 3),
          throwsA(isA<ArgumentError>()),);
    });

    test('canExecuteTransaction should check execution readiness', () {
      var transaction = MultisigUtils.createTransaction(
        multisig: multisigKey,
        programId: programId,
        accounts: [],
        data: Uint8List(0),
        ownerCount: 3,
      );

      // Not enough signatures
      expect(MultisigUtils.canExecuteTransaction(transaction, 2), isFalse);

      // Add signatures
      transaction = MultisigUtils.signTransaction(transaction, 0);
      transaction = MultisigUtils.signTransaction(transaction, 1);

      // Now has enough signatures
      expect(MultisigUtils.canExecuteTransaction(transaction, 2), isTrue);

      // Mark as executed
      transaction = MultisigTransaction(
        multisig: transaction.multisig,
        programId: transaction.programId,
        accounts: transaction.accounts,
        data: transaction.data,
        signers: transaction.signers,
        didExecute: true,
      );

      // Should not be executable anymore
      expect(MultisigUtils.canExecuteTransaction(transaction, 2), isFalse);
    });

    test('getOwnerIndex should find owner position', () {
      expect(MultisigUtils.getOwnerIndex(owners, owners[0]), equals(0));
      expect(MultisigUtils.getOwnerIndex(owners, owners[1]), equals(1));
      expect(MultisigUtils.getOwnerIndex(owners, owners[2]), equals(2));

      final nonOwner = PublicKey.fromBase58('11111111111111111111111111111113');
      expect(MultisigUtils.getOwnerIndex(owners, nonOwner), equals(-1));
    });

    test('isValidOwner should validate ownership', () {
      expect(MultisigUtils.isValidOwner(owners, owners[0]), isTrue);
      expect(MultisigUtils.isValidOwner(owners, owners[1]), isTrue);
      expect(MultisigUtils.isValidOwner(owners, owners[2]), isTrue);

      final nonOwner = PublicKey.fromBase58('11111111111111111111111111111113');
      expect(MultisigUtils.isValidOwner(owners, nonOwner), isFalse);
    });

    test('createExecutionAccountMetas should handle multisig signer', () async {
      final signerPda =
          await MultisigUtils.findMultisigSigner(multisigKey, programId);

      final accounts = [
        TransactionAccount(
          pubkey: multisigKey,
          isSigner: false,
          isWritable: true,
        ),
        TransactionAccount(
          pubkey: signerPda.address,
          isSigner: true,
          isWritable: false,
        ),
      ];

      final metas = MultisigUtils.createExecutionAccountMetas(
          accounts, signerPda.address,);

      expect(metas, hasLength(2));
      expect(metas[0].isSigner, isFalse);
      expect(metas[1].isSigner,
          isFalse,); // Multisig signer should not be client-signed
    });

    test('createTransactionSeeds should create proper seeds', () {
      const transactionId = 'tx-1';
      final seeds =
          MultisigUtils.createTransactionSeeds(multisigKey, transactionId);

      expect(seeds, hasLength(2));
      expect(seeds[0], equals(multisigKey.bytes));
      expect(seeds[1], equals(Uint8List.fromList(transactionId.codeUnits)));
    });

    test('encodeInstructionData should encode instruction info', () {
      final data = MultisigUtils.encodeInstructionData(
        'testInstruction',
        {'arg1': 'value1', 'arg2': 42},
      );

      expect(data, isA<Uint8List>());
      expect(data.length, greaterThan(0));
    });
  });

  group('TransactionAccount Tests', () {
    test('toAccountMeta should convert properly', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');
      final account = TransactionAccount(
        pubkey: pubkey,
        isSigner: true,
        isWritable: false,
      );

      final meta = account.toAccountMeta();

      expect(meta.pubkey, equals(pubkey));
      expect(meta.isSigner, isTrue);
      expect(meta.isWritable, isFalse);
    });

    test('equality should work correctly', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111112');

      final account1 =
          TransactionAccount(pubkey: pubkey, isSigner: true, isWritable: false);
      final account2 =
          TransactionAccount(pubkey: pubkey, isSigner: true, isWritable: false);
      final account3 = TransactionAccount(
          pubkey: pubkey, isSigner: false, isWritable: false,);

      expect(account1, equals(account2));
      expect(account1, isNot(equals(account3)));
    });
  });

  group('MultisigTransaction Tests', () {
    test('signatureCount should count correctly', () {
      final transaction = MultisigTransaction(
        multisig: PublicKey.fromBase58('11111111111111111111111111111112'),
        programId:
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
        accounts: [],
        data: Uint8List(0),
        signers: [true, false, true],
        didExecute: false,
      );

      expect(transaction.signatureCount, equals(2));
    });

    test('hasOwnerSigned should check individual owner', () {
      final transaction = MultisigTransaction(
        multisig: PublicKey.fromBase58('11111111111111111111111111111112'),
        programId:
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
        accounts: [],
        data: Uint8List(0),
        signers: [true, false, true],
        didExecute: false,
      );

      expect(transaction.hasOwnerSigned(0), isTrue);
      expect(transaction.hasOwnerSigned(1), isFalse);
      expect(transaction.hasOwnerSigned(2), isTrue);
      expect(transaction.hasOwnerSigned(-1), isFalse);
      expect(transaction.hasOwnerSigned(3), isFalse);
    });

    test('signerIndices should return correct indices', () {
      final transaction = MultisigTransaction(
        multisig: PublicKey.fromBase58('11111111111111111111111111111112'),
        programId:
            PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
        accounts: [],
        data: Uint8List(0),
        signers: [true, false, true, false],
        didExecute: false,
      );

      expect(transaction.signerIndices, equals([0, 2]));
    });
  });

  group('MultisigConfig Tests', () {
    test('isValid should validate configuration', () {
      final owners = [
        PublicKey.fromBase58('So11111111111111111111111111111111111111112'),
        PublicKey.fromBase58('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'),
      ];

      final validConfig =
          MultisigConfig(owners: owners, threshold: 2, nonce: 1);
      final invalidConfig =
          MultisigConfig(owners: owners, threshold: 3, nonce: 1);

      expect(validConfig.isValid, isTrue);
      expect(invalidConfig.isValid, isFalse);
    });

    test('getSignerPda should derive PDA', () async {
      final owners = [
        PublicKey.fromBase58('So11111111111111111111111111111111111111112'),
      ];
      final config = MultisigConfig(owners: owners, threshold: 1, nonce: 1);
      final multisigKey =
          PublicKey.fromBase58('11111111111111111111111111111112');
      final programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

      final result = await config.getSignerPda(multisigKey, programId);

      expect(result.address, isA<PublicKey>());
      expect(result.bump, greaterThanOrEqualTo(0));
    });
  });

  group('MultisigAccountBuilder Tests', () {
    late MultisigAccountBuilder builder;
    late PublicKey multisigKey;
    late PublicKey programId;

    setUpAll(() {
      multisigKey = PublicKey.fromBase58('11111111111111111111111111111112');
      programId =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
      builder = MultisigAccountBuilder(
          multisigKey: multisigKey, programId: programId,);
    });

    test('createMultisigAccounts should build correct accounts', () {
      final accounts = builder.createMultisigAccounts();

      expect(accounts['multisig'], equals(multisigKey));
    });

    test('createTransactionAccounts should build correct accounts', () {
      final transaction =
          PublicKey.fromBase58('So11111111111111111111111111111111111111112');
      final proposer =
          PublicKey.fromBase58('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');

      final accounts = builder.createTransactionAccounts(
        transaction: transaction,
        proposer: proposer,
      );

      expect(accounts['multisig'], equals(multisigKey));
      expect(accounts['transaction'], equals(transaction));
      expect(accounts['proposer'], equals(proposer));
    });

    test('approveAccounts should build correct accounts', () {
      final transaction =
          PublicKey.fromBase58('So11111111111111111111111111111111111111112');
      final owner =
          PublicKey.fromBase58('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');

      final accounts = builder.approveAccounts(
        transaction: transaction,
        owner: owner,
      );

      expect(accounts['multisig'], equals(multisigKey));
      expect(accounts['transaction'], equals(transaction));
      expect(accounts['owner'], equals(owner));
    });

    test('executeAccounts should build correct accounts with PDA', () async {
      final transaction =
          PublicKey.fromBase58('So11111111111111111111111111111111111111112');

      final accounts = await builder.executeAccounts(transaction: transaction);

      expect(accounts['multisig'], equals(multisigKey));
      expect(accounts['multisigSigner'], isA<PublicKey>());
      expect(accounts['transaction'], equals(transaction));
    });
  });
}
