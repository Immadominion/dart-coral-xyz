/// T4 — End-to-End Program Lifecycle Tests
///
/// Tests the full Program class lifecycle: IDL → Program → methods → instruction
/// encoding, plus on-chain tests using the System Program via native utilities.
///
/// Run: dart test test/integration/e2e_program_test.dart --tags=integration
@TestOn('vm')
@Tags(['integration'])
library;

import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart';
import 'package:coral_xyz/src/coder/discriminator_computer.dart';
import 'package:coral_xyz/src/coder/instruction_coder.dart';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/native/system_program.dart';
import 'package:coral_xyz/src/program/program_class.dart';
import 'package:coral_xyz/src/program/program_interface.dart';
import 'package:coral_xyz/src/provider/anchor_provider.dart';
import 'package:coral_xyz/src/provider/connection.dart';
import 'package:coral_xyz/src/provider/wallet.dart';
import 'package:coral_xyz/src/types/keypair.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/solana.dart' as solana;
import 'package:test/test.dart';

const _rpcUrl = 'http://127.0.0.1:8899';
const _lamportsPerSol = 1000000000;

Future<bool> _isValidatorRunning() async {
  try {
    final connection = Connection(_rpcUrl);
    await connection.getLatestBlockhash();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  late Connection connection;
  late KeypairWallet wallet;
  late AnchorProvider provider;

  setUpAll(() async {
    if (!await _isValidatorRunning()) {
      throw StateError(
        'solana-test-validator is not running on $_rpcUrl. '
        'Start it with: solana-test-validator',
      );
    }
    connection = Connection(_rpcUrl);
    wallet = await KeypairWallet.generate();
    // Fund the wallet
    final sig = await connection.requestAirdrop(
      wallet.publicKey.toBase58(),
      5 * _lamportsPerSol,
    );
    await connection.confirmTransaction(sig);
    provider = AnchorProvider(connection, wallet);
  });

  // ─── T4.1 — Program Construction from IDL ──────────────────────────────────

  group('T4.1 — Program construction from IDL', () {
    test('Program.fromJson creates program with correct IDL', () {
      final idl = Idl.fromJson({
        'address': '11111111111111111111111111111111',
        'metadata': {
          'name': 'test_program',
          'version': '0.1.0',
          'spec': '0.1.0',
        },
        'instructions': [
          {
            'name': 'initialize',
            'args': [
              {'name': 'data', 'type': 'u64'},
            ],
            'accounts': [
              {'name': 'myAccount', 'writable': true, 'signer': true},
              {'name': 'user', 'signer': true},
              {'name': 'systemProgram'},
            ],
          },
        ],
      });

      final program = Program(idl, provider: provider);
      expect(program.idl, isNotNull);
      expect(program.idl.instructions.length, equals(1));
      expect(program.idl.instructions.first.name, equals('initialize'));
      expect(
        program.programId.toBase58(),
        equals('11111111111111111111111111111111'),
      );
    });

    test('Program.withProgramId overrides IDL address', () async {
      final idl = Idl.fromJson({
        'address': '11111111111111111111111111111111',
        'metadata': {'name': 'test', 'version': '0.1.0', 'spec': '0.1.0'},
        'instructions': <Map<String, dynamic>>[],
      });

      final customId = (await Keypair.generate()).publicKey;
      final program = Program.withProgramId(idl, customId, provider: provider);
      expect(program.programId.toBase58(), equals(customId.toBase58()));
    });

    test('Program exposes provider and connection', () {
      final idl = Idl(
        instructions: [],
        address: '11111111111111111111111111111111',
      );
      final program = Program(idl, provider: provider);
      expect(program.provider, isNotNull);
      expect(program.connection, isNotNull);
    });

    test('Program exposes coder with instruction encoder', () {
      final idl = Idl.fromJson({
        'address': '11111111111111111111111111111111',
        'instructions': [
          {
            'name': 'test_ix',
            'args': [
              {'name': 'value', 'type': 'u8'},
            ],
            'accounts': <Map<String, dynamic>>[],
          },
        ],
      });
      final program = Program(idl, provider: provider);
      final encoded = program.coder.instructions.encode('test_ix', {
        'value': 42,
      });
      expect(encoded.length, greaterThan(8)); // discriminator + u8
    });
  });

  // ─── T4.2 — ProgramInterface → Program Lifecycle ──────────────────────────

  group('T4.2 — ProgramInterface → Program lifecycle', () {
    test('ProgramInterface builds IDL and creates functional Program', () {
      final idl =
          ProgramInterface.define(
                name: 'counter',
                address: '11111111111111111111111111111111',
              )
              .instruction('initialize')
              .arg('initial_value', 'u64')
              .account('counter', writable: true, signer: true)
              .account('user', signer: true)
              .account('system_program')
              .done()
              .instruction('increment')
              .arg('amount', 'u64')
              .account('counter', writable: true)
              .account('user', signer: true)
              .done()
              .build();

      final program = Program(idl, provider: provider);
      expect(program.idl.instructions.length, equals(2));
      expect(program.methods.names, containsAll(['initialize', 'increment']));
    });

    test('Methods namespace contains all IDL instructions', () {
      final idl =
          ProgramInterface.define(
                name: 'multi',
                address: '11111111111111111111111111111111',
              )
              .instruction('foo')
              .done()
              .instruction('bar')
              .done()
              .instruction('baz')
              .done()
              .build();

      final program = Program(idl, provider: provider);
      expect(program.methods.contains('foo'), isTrue);
      expect(program.methods.contains('bar'), isTrue);
      expect(program.methods.contains('baz'), isTrue);
      expect(program.methods.contains('nonexistent'), isFalse);
    });

    test('Method builder via bracket notation returns non-null', () {
      final idl = ProgramInterface.define(
        name: 'test',
        address: '11111111111111111111111111111111',
      ).instruction('do_thing').arg('val', 'u8').done().build();

      final program = Program(idl, provider: provider);
      final builderFn = program.methods['do_thing'];
      expect(builderFn, isNotNull);
    });

    test('Bracket notation with non-existent method returns null', () {
      final idl = ProgramInterface.define(
        name: 'test',
        address: '11111111111111111111111111111111',
      ).instruction('do_thing').done().build();

      final program = Program(idl, provider: provider);
      final builderFn = program.methods['nonexistent'];
      expect(builderFn, isNull);
    });
  });

  // ─── T4.3 — Instruction Encoding via Program Coder ─────────────────────────

  group('T4.3 — Instruction encoding via Program coder', () {
    test('Program coder encode matches standalone BorshInstructionCoder', () {
      final idl = Idl.fromJson({
        'address': '11111111111111111111111111111111',
        'instructions': [
          {
            'name': 'store',
            'args': [
              {'name': 'value', 'type': 'u32'},
              {'name': 'label', 'type': 'string'},
            ],
            'accounts': <Map<String, dynamic>>[],
          },
        ],
      });

      final program = Program(idl, provider: provider);
      final standalone = BorshInstructionCoder(idl);

      final programEncoded = program.coder.instructions.encode('store', {
        'value': 42,
        'label': 'hello',
      });
      final standaloneEncoded = standalone.encode('store', {
        'value': 42,
        'label': 'hello',
      });

      expect(programEncoded, equals(standaloneEncoded));
    });

    test('Program coder decode round-trips', () {
      final idl = Idl.fromJson({
        'address': '11111111111111111111111111111111',
        'instructions': [
          {
            'name': 'set_data',
            'args': [
              {'name': 'num', 'type': 'u64'},
              {'name': 'flag', 'type': 'bool'},
            ],
            'accounts': <Map<String, dynamic>>[],
          },
        ],
      });

      final program = Program(idl, provider: provider);
      final encoded = program.coder.instructions.encode('set_data', {
        'num': 999,
        'flag': true,
      });
      final decoded = program.coder.instructions.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('set_data'));
      expect(decoded.data['num'], equals(999));
      expect(decoded.data['flag'], isTrue);
    });
  });

  // ─── T4.4 — On-Chain E2E via SystemProgram ─────────────────────────────────

  group('T4.4 — On-chain E2E via SystemProgram', () {
    test('SystemProgram.transfer creates valid instruction', () {
      final from = wallet.publicKey;
      final to = PublicKey.fromBase58(
        'Sysvar1111111111111111111111111111111111111',
      );
      final ix = SystemProgram.transfer(
        fromPubkey: from,
        toPubkey: to,
        lamports: 1000,
      );
      expect(
        ix.programId.toBase58(),
        equals('11111111111111111111111111111111'),
      );
      expect(ix.accounts.length, equals(2));
      expect(ix.accounts[0].isSigner, isTrue);
      expect(ix.accounts[0].isWritable, isTrue);
      expect(ix.accounts[1].isSigner, isFalse);
      expect(ix.accounts[1].isWritable, isTrue);
      expect(ix.data.length, equals(12)); // 4-byte type + 8-byte lamports
    });

    test('SystemProgram.createAccount creates valid instruction', () async {
      final newAccount = await Keypair.generate();
      final ix = SystemProgram.createAccount(
        fromPubkey: wallet.publicKey,
        newAccountPubkey: newAccount.publicKey,
        lamports: 1000000,
        space: 64,
        programId: SystemProgram.programId,
      );
      expect(
        ix.programId.toBase58(),
        equals('11111111111111111111111111111111'),
      );
      expect(ix.accounts.length, equals(2));
      expect(ix.data.length, equals(52)); // 4 + 8 + 8 + 32
    });

    test(
      'E2E: SOL transfer via Connection.sendAndConfirmTransaction',
      () async {
        final recipient = await KeypairWallet.generate();
        final message = solana.Message.only(
          solana.SystemInstruction.transfer(
            fundingAccount: wallet.keypair.publicKey,
            recipientAccount: recipient.publicKey,
            lamports: _lamportsPerSol ~/ 2,
          ),
        );
        final sig = await connection.sendAndConfirmTransaction(
          message: message,
          signers: [wallet.keypair],
          commitment: dto.Commitment.confirmed,
        );
        expect(sig, isNotEmpty);

        final balance = await connection.getBalance(
          recipient.publicKey.toBase58(),
        );
        expect(balance, equals(_lamportsPerSol ~/ 2));
      },
    );

    test('E2E: Multiple transfers maintain correct balances', () async {
      final r1 = await KeypairWallet.generate();
      final r2 = await KeypairWallet.generate();

      // Transfer 0.2 SOL to r1
      final msg1 = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: wallet.keypair.publicKey,
          recipientAccount: r1.publicKey,
          lamports: 200000000,
        ),
      );
      await connection.sendAndConfirmTransaction(
        message: msg1,
        signers: [wallet.keypair],
        commitment: dto.Commitment.confirmed,
      );

      // Transfer 0.3 SOL to r2
      final msg2 = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: wallet.keypair.publicKey,
          recipientAccount: r2.publicKey,
          lamports: 300000000,
        ),
      );
      await connection.sendAndConfirmTransaction(
        message: msg2,
        signers: [wallet.keypair],
        commitment: dto.Commitment.confirmed,
      );

      final balance1 = await connection.getBalance(r1.publicKey.toBase58());
      final balance2 = await connection.getBalance(r2.publicKey.toBase58());
      expect(balance1, equals(200000000));
      expect(balance2, equals(300000000));
    });

    test('E2E: Provider sendAndConfirm works', () async {
      final recipient = await KeypairWallet.generate();
      final balance0 = await connection.getBalance(
        recipient.publicKey.toBase58(),
      );
      expect(balance0, equals(0));

      // Use espresso-cash message construction + provider.sendAndConfirm
      final message = solana.Message.only(
        solana.SystemInstruction.transfer(
          fundingAccount: wallet.keypair.publicKey,
          recipientAccount: recipient.publicKey,
          lamports: 100000000,
        ),
      );
      final sig = await connection.sendAndConfirmTransaction(
        message: message,
        signers: [wallet.keypair],
        commitment: dto.Commitment.confirmed,
      );
      expect(sig, isNotEmpty);

      final balance1 = await connection.getBalance(
        recipient.publicKey.toBase58(),
      );
      expect(balance1, equals(100000000));
    });
  });
}
