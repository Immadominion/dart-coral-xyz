/// Tests for Context and Address Resolution system
///
/// This test suite verifies that the Context class and address resolution
/// utilities work correctly for Anchor program interactions.
library;

import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/program/context.dart';
import 'package:coral_xyz_anchor/src/program/pda_utils.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

void main() {
  group('Context Tests', () {
    test('should create empty context', () {
      const context = Context<DynamicAccounts>();
      expect(context.accounts, isNull);
      expect(context.signers, isNull);
      expect(context.preInstructions, isNull);
      expect(context.postInstructions, isNull);
      expect(context.commitment, isNull);
      expect(context.options, isNull);
    });

    test('should create context with accounts', () {
      final accounts = DynamicAccounts({
        'myAccount': PublicKey.fromBase58('11111111111111111111111111111111'),
      });

      final context = Context<DynamicAccounts>(accounts: accounts);
      expect(context.accounts, equals(accounts));
    });

    test('should create context with all properties', () async {
      final accounts = DynamicAccounts();
      accounts.setAccount(
        'testAccount',
        AccountMeta(
          pubkey: PublicKey.fromBase58('11111111111111111111111111111111'),
          isWritable: true,
          isSigner: false,
        ),
      );

      final signers = [await Keypair.generate()];
      final preInstructions = [TransactionInstruction.empty()];
      final postInstructions = [TransactionInstruction.empty()];
      const commitment = CommitmentConfigs.confirmed;
      final options = const ConfirmOptions(skipPreflight: true);

      final context = Context<DynamicAccounts>(
        accounts: accounts,
        signers: signers,
        preInstructions: preInstructions,
        postInstructions: postInstructions,
        commitment: commitment,
        options: options,
      );

      expect(context.accounts, equals(accounts));
      expect(context.signers, equals(signers));
      expect(context.preInstructions, equals(preInstructions));
      expect(context.postInstructions, equals(postInstructions));
      expect(context.commitment, equals(commitment));
      expect(context.options, equals(options));
    });

    test('should copy context with changes', () {
      const originalContext = Context<DynamicAccounts>();
      final newAccounts = DynamicAccounts();

      final newContext = originalContext.copyWith(accounts: newAccounts);
      expect(newContext.accounts, equals(newAccounts));
      expect(newContext.signers, isNull);
    });
  });

  group('DynamicAccounts Tests', () {
    test('should set and get accounts', () {
      final accounts = DynamicAccounts();
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');

      accounts.setAccount('testAccount', pubkey);
      expect(accounts.getAccount('testAccount'), equals(pubkey));
      expect(accounts.hasAccount('testAccount'), isTrue);
      expect(accounts.hasAccount('nonExistent'), isFalse);
    });

    test('should handle account metadata', () {
      final accounts = DynamicAccounts({
        'account1': PublicKey.fromBase58('11111111111111111111111111111111'),
      });

      expect(accounts.getAccountNames(), contains('account1'));
      expect(accounts.getAccountNames().isNotEmpty, isTrue);
    });

    test('should iterate over accounts', () {
      final accounts = DynamicAccounts({
        'account1': PublicKey.fromBase58('11111111111111111111111111111111'),
        'account2': PublicKey.fromBase58('11111111111111111111111111111112'),
      });

      final accountMap = accounts.toMap();
      final names = accountMap.keys.toList();

      expect(names, containsAll(['account1', 'account2']));
    });
  });

  group('AccountMeta Tests', () {
    test('should create account meta', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final meta = AccountMeta(
        pubkey: pubkey,
        isWritable: true,
        isSigner: false,
      );

      expect(meta.pubkey, equals(pubkey));
      expect(meta.isWritable, isTrue);
      expect(meta.isSigner, isFalse);
    });

    test('should implement equality for account meta', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final meta1 = AccountMeta(
        pubkey: pubkey,
        isWritable: true,
        isSigner: false,
      );
      final meta2 = AccountMeta(
        pubkey: pubkey,
        isWritable: true,
        isSigner: false,
      );

      expect(meta1, equals(meta2));
      expect(meta1.hashCode, equals(meta2.hashCode));
    });
  });

  group('Context and Arguments Splitting Tests', () {
    test('should split arguments and context correctly', () {
      final instruction = _createTestInstruction(['arg1', 'arg2']);
      final args = ['value1', 'value2'];

      final result = splitArgsAndContext(instruction, args);
      expect(result.args, equals(['value1', 'value2']));
      expect(result.context.accounts, isNull);
    });

    test('should handle context in arguments', () {
      final instruction = _createTestInstruction(['arg1']);
      final context = Context<DynamicAccounts>(
        accounts: DynamicAccounts({'test': 'account'}),
      );
      final args = ['value1', context];

      final result = splitArgsAndContext(instruction, args);
      expect(result.args, equals(['value1']));
      final dynamicAccounts = result.context.accounts as DynamicAccounts?;
      expect(dynamicAccounts!.hasAccount('test'), isTrue);
    });

    test('should handle special context properties', () {
      final instruction = _createTestInstruction(['arg1']);
      final args = [
        'value1',
        {
          'signers': <Keypair>[],
        }
      ];

      final result = splitArgsAndContext(instruction, args);
      expect(result.args, equals(['value1']));
      expect(result.context.signers, isEmpty);
    });

    test('should throw on excess arguments', () {
      final instruction = _createTestInstruction(['arg1']);
      final args = ['value1', 'value2', 'value3'];

      expect(
        () => splitArgsAndContext(instruction, args),
        throwsArgumentError,
      );
    });

    test('should handle unknown context property gracefully', () {
      final instruction = _createTestInstruction(['arg1']);
      final args = [
        'value1',
        {'unknownProperty': 'value'},
      ];

      final result = splitArgsAndContext(instruction, args);
      expect(result.args, equals(['value1']));
      expect(result.context.accounts, isNull);
    });
  });

  group('PDA Utils Tests', () {
    test('should convert seed to bytes', () {
      // Test string seed
      final stringBytes = PdaUtils.seedToBytes('hello');
      expect(stringBytes, isA<Uint8List>());
      expect(stringBytes.length, greaterThan(0));

      // Test int seed
      final intBytes = PdaUtils.seedToBytes(42);
      expect(intBytes, isA<Uint8List>());

      // Test PublicKey seed
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final pubkeyBytes = PdaUtils.seedToBytes(pubkey);
      expect(pubkeyBytes, equals(pubkey.bytes));

      // Test Uint8List seed
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bytesResult = PdaUtils.seedToBytes(bytes);
      expect(bytesResult, equals(bytes));
    });

    test('should convert multiple seeds to bytes', () {
      final seeds = [
        'hello',
        42,
        PublicKey.fromBase58('11111111111111111111111111111111'),
      ];
      final seedBytes = PdaUtils.seedsToBytes(seeds);

      expect(seedBytes, hasLength(3));
      expect(seedBytes[0], isA<Uint8List>());
      expect(seedBytes[1], isA<Uint8List>());
      expect(seedBytes[2], isA<Uint8List>());
    });

    test('should throw on unsupported seed type', () {
      expect(
        () => PdaUtils.seedToBytes(DateTime.now()),
        throwsArgumentError,
      );
    });
  });

  group('Address Resolution Tests', () {
    test('should return null for null PDA spec', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      const String? pdaSpec = null;

      final result =
          await AddressResolver.resolvePdaFromString(pdaSpec, programId);
      expect(result, isNull);
    });

    test('should resolve accounts from specifications', () async {
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final accounts = <String, dynamic>{
        'account1': PublicKey.fromBase58('11111111111111111111111111111111'),
      };
      final specs = [
        const IdlInstructionAccount(
            name: 'account1',),
        const IdlInstructionAccount(
            name: 'account2',),
      ];

      final resolved = await AddressResolver.resolveAccounts(
        specs,
        accounts,
        programId,
      );

      expect(resolved['account1'], isA<PublicKey>());
      // account2 may be null if it cannot be resolved
      expect(resolved.containsKey('account1'), isTrue);
    });
  });

  group('Address Validation Tests', () {
    test('should validate public keys', () {
      expect(
        AddressValidator.validatePublicKey('11111111111111111111111111111111'),
        isTrue,
      );
      expect(
        AddressValidator.validatePublicKey('invalid'),
        isFalse,
      );
    });

    test('should identify missing required accounts', () {
      final accounts = <String, dynamic>{'account1': 'value'};
      final specs = [
        const IdlInstructionAccount(
            name: 'account1',),
        const IdlInstructionAccount(
            name: 'account2',), // Missing
        const IdlInstructionAccount(
            name: 'account3',
            optional: true,), // Optional
      ];

      final missing =
          AddressValidator.getMissingRequiredAccounts(accounts, specs);
      expect(missing, equals(['account2']));
    });
  });
}

/// Helper function to create test IDL instruction
IdlInstruction _createTestInstruction(List<String> argNames) => IdlInstruction(
    name: 'testInstruction',
    discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
    accounts: [
      const IdlInstructionAccount(
          name: 'testAccount', writable: false, signer: false),
    ],
    args: argNames
        .map(
            (name) => IdlField(name: name, type: const IdlType(kind: 'string')))
        .toList(),
  );
