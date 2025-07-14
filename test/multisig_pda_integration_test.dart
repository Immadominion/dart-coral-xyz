import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/utils/multisig.dart';
import 'package:coral_xyz_anchor/src/utils/pubkey.dart';
import 'package:coral_xyz_anchor/src/program/pda_utils.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

void main() {
  group('Multisig and PDA Integration Tests', () {
    late PublicKey multisigProgramId;
    late List<PublicKey> owners;

    setUpAll(() {
      multisigProgramId =
          PublicKey.fromBase58('Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS');
      owners = [
        PublicKey.fromBase58('So11111111111111111111111111111111111111112'),
        PublicKey.fromBase58('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'),
        PublicKey.fromBase58('9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM'),
      ];
    });

    test('full multisig workflow with PDA derivation', () async {
      // Step 1: Create a multisig account
      final multisigKeypair = PublicKeyUtils.unique(owners[0]);

      // Step 2: Derive the multisig signer PDA
      final signerPda = await MultisigUtils.findMultisigSigner(
        multisigKeypair,
        multisigProgramId,
      );
      expect(signerPda.address, isA<PublicKey>());
      expect(signerPda.bump, greaterThanOrEqualTo(0));

      // Step 3: Create a multisig configuration
      final config = MultisigConfig(
        owners: owners,
        threshold: 2,
        nonce: signerPda.bump,
      );
      expect(config.isValid, isTrue);

      // Step 4: Create a transaction to execute
      final targetProgram =
          PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
      final accounts = [
        TransactionAccount(
          pubkey: multisigKeypair,
          isSigner: false,
          isWritable: true,
        ),
        TransactionAccount(
          pubkey: signerPda.address,
          isSigner: true,
          isWritable: false,
        ),
      ];

      // Create instruction data using enhanced seed conversion
      final instructionData = PdaUtils.seedToBytesEnhanced('setOwners');

      var transaction = MultisigUtils.createTransaction(
        multisig: multisigKeypair,
        programId: targetProgram,
        accounts: accounts,
        data: instructionData,
        ownerCount: owners.length,
      );

      // Step 5: Simulate owner approvals
      expect(MultisigUtils.canExecuteTransaction(transaction, config.threshold),
          isFalse,);

      // First owner approves
      final owner1Index = MultisigUtils.getOwnerIndex(owners, owners[0]);
      transaction = MultisigUtils.signTransaction(transaction, owner1Index);
      expect(transaction.signatureCount, equals(1));
      expect(MultisigUtils.canExecuteTransaction(transaction, config.threshold),
          isFalse,);

      // Second owner approves
      final owner2Index = MultisigUtils.getOwnerIndex(owners, owners[1]);
      transaction = MultisigUtils.signTransaction(transaction, owner2Index);
      expect(transaction.signatureCount, equals(2));
      expect(MultisigUtils.canExecuteTransaction(transaction, config.threshold),
          isTrue,);

      // Step 6: Prepare execution accounts
      final executionMetas = MultisigUtils.createExecutionAccountMetas(
        accounts,
        signerPda.address,
      );

      // The multisig signer should not be client-signed in execution
      final signerMeta = executionMetas.firstWhere(
        (meta) => meta.pubkey == signerPda.address,
      );
      expect(signerMeta.isSigner, isFalse);

      // Step 7: Verify transaction derivation with seeds
      const transactionId = 'tx-001';
      final txSeeds =
          MultisigUtils.createTransactionSeeds(multisigKeypair, transactionId);
      expect(txSeeds, hasLength(2));
      expect(txSeeds[0], equals(multisigKeypair.bytes));
      expect(txSeeds[1], equals(Uint8List.fromList(transactionId.codeUnits)));

      // Optionally derive a transaction account PDA
      final txPda =
          await PdaUtils.findProgramAddress(txSeeds, multisigProgramId);
      expect(txPda.address, isA<PublicKey>());
    });

    test('PDA utilities with multisig context', () async {
      final multisigKey = PublicKeyUtils.unique(owners[0]);

      // Test various seed types for PDA derivation
      final mixedSeeds = [
        'multisig',
        multisigKey,
        owners.length,
        true, // active flag
      ];

      final seedBytes = PdaUtils.seedsToBytes(mixedSeeds);
      expect(seedBytes, hasLength(4));

      final pda = await PdaUtils.deriveAddress(mixedSeeds, multisigProgramId);
      expect(pda.address, isA<PublicKey>());

      // Test deterministic derivation
      final pda2 = await PdaUtils.deriveAddress(mixedSeeds, multisigProgramId);
      expect(pda.address, equals(pda2.address));
      expect(pda.bump, equals(pda2.bump));
    });

    test('multisig account builder with PDA integration', () async {
      final multisigKey = PublicKeyUtils.unique(owners[0]);
      final builder = MultisigAccountBuilder(
        multisigKey: multisigKey,
        programId: multisigProgramId,
      );

      // Test account generation for all multisig operations
      final createAccounts = builder.createMultisigAccounts();
      expect(createAccounts['multisig'], equals(multisigKey));

      final transactionKey = PublicKeyUtils.unique(owners[1]);
      final proposerKey = owners[0];

      final createTxAccounts = builder.createTransactionAccounts(
        transaction: transactionKey,
        proposer: proposerKey,
      );
      expect(createTxAccounts['multisig'], equals(multisigKey));
      expect(createTxAccounts['transaction'], equals(transactionKey));
      expect(createTxAccounts['proposer'], equals(proposerKey));

      final approveAccounts = builder.approveAccounts(
        transaction: transactionKey,
        owner: owners[1],
      );
      expect(approveAccounts['multisig'], equals(multisigKey));
      expect(approveAccounts['transaction'], equals(transactionKey));
      expect(approveAccounts['owner'], equals(owners[1]));

      final executeAccounts = await builder.executeAccounts(
        transaction: transactionKey,
      );
      expect(executeAccounts['multisig'], equals(multisigKey));
      expect(executeAccounts['transaction'], equals(transactionKey));
      expect(executeAccounts['multisigSigner'], isA<PublicKey>());

      // Verify the signer is the expected PDA
      final expectedSigner = await MultisigUtils.findMultisigSigner(
        multisigKey,
        multisigProgramId,
      );
      expect(executeAccounts['multisigSigner'], equals(expectedSigner.address));
    });

    test('address validation with multisig PDAs', () async {
      final multisigKey = PublicKeyUtils.unique(owners[0]);
      final seeds = MultisigUtils.createMultisigSeeds(multisigKey);

      // Derive the PDA
      final pda = await PdaUtils.findProgramAddress(seeds, multisigProgramId);

      // Validate it was derived correctly
      final isValid = await AddressValidator.validatePda(
        pda.address,
        seeds,
        multisigProgramId,
      );
      expect(isValid, isTrue);

      // Test with wrong seeds should fail
      final wrongSeeds = [Uint8List.fromList('wrong'.codeUnits)];
      final isValidWrong = await AddressValidator.validatePda(
        pda.address,
        wrongSeeds,
        multisigProgramId,
      );
      expect(isValidWrong, isFalse);
    });

    test('enhanced seed conversion for multisig data', () {
      // Test converting multisig configuration to seeds
      final config = MultisigConfig(
        owners: owners.take(2).toList(),
        threshold: 2,
        nonce: 1,
      );

      // Convert various multisig data to seeds
      final thresholdSeed = PdaUtils.seedToBytesEnhanced(config.threshold);
      expect(thresholdSeed, hasLength(8));
      expect(thresholdSeed[0], equals(2));

      final nonceSeed = PdaUtils.seedToBytesEnhanced(config.nonce, intSize: 1);
      expect(nonceSeed, hasLength(1));
      expect(nonceSeed[0], equals(1));

      final activeSeed = PdaUtils.seedToBytesEnhanced(config.isValid);
      expect(activeSeed, equals(Uint8List.fromList([1])));

      // Test seed from account data structure
      final accountData = {
        'owners': config.owners.map((o) => o.toBase58()).toList(),
        'threshold': config.threshold,
        'nonce': config.nonce,
      };

      final thresholdFromAccount =
          PdaUtils.seedFromAccount(accountData, 'threshold');
      expect(thresholdFromAccount, equals(thresholdSeed));

      final nonceFromAccount = PdaUtils.seedFromAccount(accountData, 'nonce');
      expect(nonceFromAccount, hasLength(8)); // Default int size
      expect(nonceFromAccount[0], equals(1));
    });

    test('createWithSeedSync compatibility', () {
      final baseKey = owners[0];
      const seed = 'multisig-member';
      final systemProgram =
          PublicKey.fromBase58('11111111111111111111111111111112');

      // Test both PdaUtils and PublicKeyUtils versions
      final address1 =
          PdaUtils.createWithSeedSync(baseKey, seed, systemProgram);
      final address2 =
          PublicKeyUtils.createWithSeedSync(baseKey, seed, systemProgram);

      expect(address1, equals(address2));
      expect(address1.toBase58(), isNotEmpty);
    });
  });
}
