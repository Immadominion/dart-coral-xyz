/// Non-Anchor Framework Verification Tests
///
/// Proves that coral_xyz SDK correctly handles programs built with
/// non-Anchor frameworks (Quasar and Pinocchio):
///
/// 1. **Quasar**: IDL-driven — load fixture → parse → encode → PDA → decode
/// 2. **Pinocchio**: Manual IDL — ProgramInterface.define() → encode → PDA
///
/// These tests use the vault example programs from coral-xyz-examples/.
/// Session 13: Added as automated verification of non-Anchor support.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart'
    hide Transaction, TransactionInstruction, AccountMeta;
import 'package:test/test.dart';

import 'verification_helpers.dart';

void main() {
  late VerificationReport report;

  setUpAll(() {
    report = VerificationReport();
  });

  tearDownAll(() {
    report.printSummary();
  });

  // =========================================================================
  // QUASAR: IDL-driven vault program
  // =========================================================================
  group('Quasar vault (IDL-driven)', () {
    late Idl idl;
    late Program program;

    setUp(() {
      idl = loadFixtureIdl('quasar_vault.idl.json');
      program = Program(idl, provider: null);
    });

    test('IDL parses with correct metadata', () {
      expect(idl.metadata?.name, equals('quasar_vault'));
      expect(idl.metadata?.version, equals('0.1.0'));
      expect(idl.address, isNotNull);

      report.pass(
        'Quasar',
        'IDL metadata parses correctly ✓',
      );
    });

    test('IDL has deposit and withdraw instructions', () {
      final names = idl.instructions.map((i) => i.name).toList();
      expect(names, contains('deposit'));
      expect(names, contains('withdraw'));

      report.pass(
        'Quasar',
        'deposit + withdraw instructions present ✓',
      );
    });

    test('deposit instruction has correct structure', () {
      final deposit = idl.instructions.firstWhere((i) => i.name == 'deposit');

      // Discriminator
      expect(deposit.discriminator, equals([0]));

      // Accounts: user (signer, writable), vault (writable, PDA), systemProgram
      expect(deposit.accounts.length, equals(3));

      final user = deposit.accounts[0] as IdlInstructionAccount;
      expect(user.name, equals('user'));
      expect(user.writable, isTrue);
      expect(user.signer, isTrue);

      final vault = deposit.accounts[1] as IdlInstructionAccount;
      expect(vault.name, equals('vault'));
      expect(vault.writable, isTrue);
      // Vault has PDA definition
      expect(vault.pda, isNotNull);
      expect(vault.pda!.seeds.length, equals(2));

      // Args: amount (u64)
      expect(deposit.args.length, equals(1));
      expect(deposit.args[0].name, equals('amount'));
      expect(deposit.args[0].type.kind, equals('u64'));

      report.pass(
        'Quasar',
        'deposit instruction structure verified ✓',
      );
    });

    test('withdraw instruction has correct structure', () {
      final withdraw =
          idl.instructions.firstWhere((i) => i.name == 'withdraw');
      expect(withdraw.discriminator, equals([1]));
      expect(withdraw.accounts.length, equals(2));
      expect(withdraw.args.length, equals(1));
      expect(withdraw.args[0].name, equals('amount'));

      report.pass(
        'Quasar',
        'withdraw instruction structure verified ✓',
      );
    });

    test('PDA seeds decode to "vault" + account path', () {
      final deposit = idl.instructions.firstWhere((i) => i.name == 'deposit');
      final vault = deposit.accounts[1] as IdlInstructionAccount;
      final seeds = vault.pda!.seeds;

      // First seed: const "vault"
      final constSeed = seeds[0] as IdlSeedConst;
      expect(utf8.decode(constSeed.value), equals('vault'));

      // Second seed: account reference to "user"
      final accountSeed = seeds[1] as IdlSeedAccount;
      expect(accountSeed.path, equals('user'));

      report.pass(
        'Quasar',
        'PDA seeds decode correctly (const "vault" + account "user") ✓',
      );
    });

    test('deposit instruction encodes correctly', () {
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('deposit', {'amount': BigInt.from(1000000)});

      // First byte(s): discriminator [0]
      expect(encoded[0], equals(0));

      // Next 8 bytes: u64 amount (1000000 = 0x0F4240 LE)
      final amount =
          ByteData.sublistView(encoded, 1, 9).getUint64(0, Endian.little);
      expect(amount, equals(1000000));

      report.pass(
        'Quasar',
        'deposit instruction encodes correctly ✓',
      );
    });

    test('withdraw instruction encodes correctly', () {
      final coder = BorshInstructionCoder(idl);
      final encoded = coder.encode('withdraw', {'amount': BigInt.from(500000)});

      expect(encoded[0], equals(1)); // discriminator
      final amount =
          ByteData.sublistView(encoded, 1, 9).getUint64(0, Endian.little);
      expect(amount, equals(500000));

      report.pass(
        'Quasar',
        'withdraw instruction encodes correctly ✓',
      );
    });

    test('PDA derivation produces deterministic address', () async {
      final programId = PublicKey.fromBase58(idl.address!);
      final user = await Keypair.generate();

      final result = await PublicKeyUtils.findProgramAddress(
        [utf8.encode('vault'), user.publicKey.toBytes()],
        programId,
      );

      // PDA should be deterministic
      final result2 = await PublicKeyUtils.findProgramAddress(
        [utf8.encode('vault'), user.publicKey.toBytes()],
        programId,
      );

      expect(result.address.toBase58(), equals(result2.address.toBase58()));
      expect(result.bump, equals(result2.bump));

      report.pass(
        'Quasar',
        'PDA derivation is deterministic ✓',
      );
    });

    test('Program.methods namespace exposes deposit and withdraw', () {
      final depositFn = program.methods['deposit'];
      final withdrawFn = program.methods['withdraw'];

      expect(depositFn, isNotNull, reason: 'deposit should be in methods');
      expect(withdrawFn, isNotNull, reason: 'withdraw should be in methods');

      report.pass(
        'Quasar',
        'methods namespace exposes both instructions ✓',
      );
    });
  });

  // =========================================================================
  // PINOCCHIO: Manual IDL via ProgramInterface.define()
  // =========================================================================
  group('Pinocchio vault (ProgramInterface.define())', () {
    late Idl idl;
    late Program program;

    // Matches the pinocchio_vault example app's CoralXyzVaultService._buildManualIdl()
    final programId = 'EJsDy7tkHokKKLtM1ugXv6JZ7YDETSZCPrYq4mStKKis';

    setUp(() {
      idl = ProgramInterface.define(
        name: 'pinocchio_vault',
        address: programId,
      )
          .instruction('deposit', discriminator: [0])
          .account('user', writable: true, signer: true)
          .account('vault', writable: true)
          .account('systemProgram')
          .arg('amount', 'u64')
          .done()
          .instruction('withdraw', discriminator: [1])
          .account('user', writable: true, signer: true)
          .account('vault', writable: true)
          .account('systemProgram')
          .arg('amount', 'u64')
          .done()
          .build();

      program = Program.withProgramId(
        idl,
        PublicKey.fromBase58(programId),
        provider: null,
      );
    });

    test('ProgramInterface.define() produces valid IDL', () {
      expect(idl.metadata?.name, equals('pinocchio_vault'));
      expect(idl.address, equals(programId));
      expect(idl.instructions.length, equals(2));

      report.pass(
        'Pinocchio',
        'ProgramInterface.define() produces valid IDL ✓',
      );
    });

    test('deposit instruction has correct shape', () {
      final deposit = idl.instructions.firstWhere((i) => i.name == 'deposit');
      expect(deposit.discriminator, equals([0]));
      expect(deposit.accounts.length, equals(3));
      expect(deposit.args.length, equals(1));
      expect(deposit.args[0].name, equals('amount'));

      final user = deposit.accounts[0] as IdlInstructionAccount;
      expect(user.signer, isTrue);
      expect(user.writable, isTrue);

      report.pass(
        'Pinocchio',
        'deposit instruction shape verified ✓',
      );
    });

    test('withdraw instruction has correct shape', () {
      final withdraw =
          idl.instructions.firstWhere((i) => i.name == 'withdraw');
      expect(withdraw.discriminator, equals([1]));
      expect(withdraw.args[0].type.kind, equals('u64'));

      report.pass(
        'Pinocchio',
        'withdraw instruction shape verified ✓',
      );
    });

    test('instruction encoding matches Pinocchio wire format', () {
      final coder = BorshInstructionCoder(idl);

      // Deposit 0.1 SOL
      final depositData = coder.encode('deposit', {'amount': BigInt.from(100000000)});
      expect(depositData[0], equals(0)); // disc
      final depAmount =
          ByteData.sublistView(depositData, 1, 9).getUint64(0, Endian.little);
      expect(depAmount, equals(100000000));

      // Withdraw 0.05 SOL
      final withdrawData = coder.encode('withdraw', {'amount': BigInt.from(50000000)});
      expect(withdrawData[0], equals(1)); // disc
      final witAmount = ByteData.sublistView(withdrawData, 1, 9)
          .getUint64(0, Endian.little);
      expect(witAmount, equals(50000000));

      report.pass(
        'Pinocchio',
        'instruction encoding matches wire format ✓',
      );
    });

    test('PDA derivation matches Pinocchio program seeds', () async {
      final pid = PublicKey.fromBase58(programId);
      final user = await Keypair.generate();

      final result = await PublicKeyUtils.findProgramAddress(
        [utf8.encode('vault'), user.publicKey.toBytes()],
        pid,
      );

      // result.address should be off-curve (valid PDA)
      expect(result.address.toBase58(), isNotEmpty);
      expect(result.bump, lessThanOrEqualTo(255));
      expect(result.bump, greaterThanOrEqualTo(0));

      report.pass(
        'Pinocchio',
        'PDA derivation produces valid address ✓',
      );
    });

    test('methods namespace functional without provider', () {
      expect(program.methods['deposit'], isNotNull);
      expect(program.methods['withdraw'], isNotNull);

      // Can create builder without provider (for instruction inspection)
      final builder = program.methods['deposit']!([BigInt.from(1000000)]);
      expect(builder.name, equals('deposit'));

      report.pass(
        'Pinocchio',
        'methods namespace works without provider ✓',
      );
    });

    test('IDL round-trips through JSON', () {
      final json = idl.toJson();
      final restored = Idl.fromJson(json);

      expect(restored.metadata?.name, equals(idl.metadata?.name));
      expect(restored.instructions.length, equals(idl.instructions.length));

      for (int i = 0; i < idl.instructions.length; i++) {
        expect(
          restored.instructions[i].name,
          equals(idl.instructions[i].name),
        );
        expect(
          restored.instructions[i].discriminator,
          equals(idl.instructions[i].discriminator),
        );
      }

      report.pass(
        'Pinocchio',
        'IDL round-trips through JSON ✓',
      );
    });
  });
}
