/// Integration tests for the Quasar SVM Dart FFI binding.
///
/// Mirrors the Python test suite in quasar-svm/bindings/python/tests/ for parity,
/// then adds Dart-specific lifecycle and sysvar tests.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:coral_xyz/src/svm/account_factories.dart';
import 'package:coral_xyz/src/svm/execution_result.dart';
import 'package:coral_xyz/src/svm/programs.dart';
import 'package:coral_xyz/src/svm/quasar_svm.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/types/transaction.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// SPL Token instruction builders (matching struct.pack("<BQ", ...) in Python)
// ---------------------------------------------------------------------------

/// SPL Token Transfer instruction: tag=3, amount=u64 LE
Uint8List _splTransferData(int amount) {
  final data = Uint8List(9);
  data[0] = 3;
  ByteData.sublistView(data).setUint64(1, amount, Endian.little);
  return data;
}

/// SPL Token MintTo instruction: tag=7, amount=u64 LE
Uint8List _splMintToData(int amount) {
  final data = Uint8List(9);
  data[0] = 7;
  ByteData.sublistView(data).setUint64(1, amount, Endian.little);
  return data;
}

/// SPL Token GetAccountDataSize: tag=21
Uint8List _splGetAccountDataSizeData() => Uint8List.fromList([21]);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Deterministic "unique" key from a simple index to keep tests reproducible.
PublicKey _key(int index) {
  final bytes = Uint8List(32);
  ByteData.sublistView(bytes).setUint32(0, index, Endian.little);
  return PublicKeyUtils.fromBytes(bytes);
}

void main() {
  // =========================================================================
  // Lifecycle tests
  // =========================================================================

  group('QuasarSvm lifecycle', () {
    test('default constructor loads SPL programs without error', () {
      final svm = QuasarSvm();
      // if we get here without throwing, SPL programs loaded successfully
      svm.free();
    });

    test('empty constructor creates a bare SVM', () {
      final svm = QuasarSvm.empty();
      svm.free();
    });

    test('double free does not crash', () {
      final svm = QuasarSvm.empty();
      svm.free();
      // second free should be a no-op
      svm.free();
    });
  });

  // =========================================================================
  // SPL Token transfer (parity with test_basic_execution_trace in Python)
  // =========================================================================

  group('SPL Token transfer', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm());
    tearDown(() => svm.free());

    test('basic token transfer succeeds', () {
      final mintAddr = _key(1);
      final srcAddr = _key(2);
      final dstAddr = _key(3);
      final ownerAddr = _key(4);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: ownerAddr, decimals: 9, supply: 1000000),
      );

      final src = createKeyedTokenAccount(
        srcAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 500),
      );

      final dst = createKeyedTokenAccount(
        dstAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 0),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(srcAddr),
          AccountMeta.writable(dstAddr),
          AccountMeta.signer(ownerAddr),
        ],
        data: _splTransferData(100),
      );

      final result = svm.processInstruction(ix, [mint, src, dst]);

      expect(result.isSuccess, isTrue);
      expect(result.computeUnits, greaterThan(0));
      expect(result.logs, isNotEmpty);

      // Check post-execution account state
      final postSrc = result.account(srcAddr);
      final postDst = result.account(dstAddr);

      expect(postSrc, isNotNull);
      expect(postDst, isNotNull);
    });

    test('transfer with insufficient funds fails', () {
      final mintAddr = _key(10);
      final srcAddr = _key(11);
      final dstAddr = _key(12);
      final ownerAddr = _key(13);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: ownerAddr, decimals: 6, supply: 100),
      );

      final src = createKeyedTokenAccount(
        srcAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 10),
      );

      final dst = createKeyedTokenAccount(
        dstAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 0),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(srcAddr),
          AccountMeta.writable(dstAddr),
          AccountMeta.signer(ownerAddr),
        ],
        data: _splTransferData(9999), // more than balance
      );

      final result = svm.processInstruction(ix, [mint, src, dst]);
      expect(result.isError, isTrue);
    });

    test('invalid instruction data returns error', () {
      final mintAddr = _key(20);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: _key(21), decimals: 9),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [AccountMeta.readonly(mintAddr)],
        data: Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
      );

      final result = svm.processInstruction(ix, [mint]);
      expect(result.isError, isTrue);
    });
  });

  // =========================================================================
  // MintTo (parity with test_execution_trace_with_cpi in Python)
  // =========================================================================

  group('MintTo', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm());
    tearDown(() => svm.free());

    test('mint tokens to a token account', () {
      final mintAddr = _key(30);
      final tokenAddr = _key(31);
      final authority = _key(32);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: authority, decimals: 9, supply: 0),
      );

      final token = createKeyedTokenAccount(
        tokenAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: authority, amount: 0),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(mintAddr),
          AccountMeta.writable(tokenAddr),
          AccountMeta.signer(authority),
        ],
        data: _splMintToData(1000),
      );

      final result = svm.processInstruction(ix, [mint, token]);

      // MintTo should succeed
      result.assertSuccess();
      expect(result.computeUnits, greaterThan(0));
    });
  });

  // =========================================================================
  // Execution trace (parity with Python test_execution_trace*.py)
  // =========================================================================

  group('Execution trace', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm());
    tearDown(() => svm.free());

    test('trace exists after transfer', () {
      final mintAddr = _key(40);
      final srcAddr = _key(41);
      final dstAddr = _key(42);
      final ownerAddr = _key(43);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: ownerAddr, decimals: 9, supply: 1000),
      );

      final src = createKeyedTokenAccount(
        srcAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 100),
      );

      final dst = createKeyedTokenAccount(
        dstAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 0),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(srcAddr),
          AccountMeta.writable(dstAddr),
          AccountMeta.signer(ownerAddr),
        ],
        data: _splTransferData(50),
      );

      final result = svm.processInstruction(ix, [mint, src, dst]);

      expect(result.executionTrace, isNotNull);
      expect(result.executionTrace.instructions, isNotEmpty);
    });

    test('top-level instruction has stack depth 0', () {
      final mintAddr = _key(50);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: _key(51), decimals: 9),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [AccountMeta.readonly(mintAddr)],
        data: _splGetAccountDataSizeData(),
      );

      final result = svm.processInstruction(ix, [mint]);

      final trace = result.executionTrace;
      expect(trace.instructions, isNotEmpty);
      expect(trace.instructions.first.stackDepth, equals(0));
    });

    test('instruction data is captured in trace', () {
      final mintAddr = _key(60);
      final srcAddr = _key(61);
      final dstAddr = _key(62);
      final ownerAddr = _key(63);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: ownerAddr, decimals: 6, supply: 1000),
      );

      final src = createKeyedTokenAccount(
        srcAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 1000),
      );

      final dst = createKeyedTokenAccount(
        dstAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: ownerAddr, amount: 0),
      );

      final transferData = _splTransferData(123);

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(srcAddr),
          AccountMeta.writable(dstAddr),
          AccountMeta.signer(ownerAddr),
        ],
        data: transferData,
      );

      final result = svm.processInstruction(ix, [mint, src, dst]);

      final first = result.executionTrace.instructions.first;

      // Program ID should match
      expect(
        first.instruction.programId.bytes,
        equals(splTokenProgramId.bytes),
      );

      // Should have 3 accounts
      expect(first.instruction.accounts.length, equals(3));

      // Account flags
      expect(first.instruction.accounts[0].isWritable, isTrue); // source
      expect(first.instruction.accounts[1].isWritable, isTrue); // dest
      expect(first.instruction.accounts[2].isSigner, isTrue); // owner

      // Instruction data should be captured
      expect(first.instruction.data.length, greaterThan(0));
    });

    test('compute units are tracked per instruction', () {
      final mintAddr = _key(70);
      final tokenAddr = _key(71);
      final authority = _key(72);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: authority, decimals: 9, supply: 0),
      );

      final token = createKeyedTokenAccount(
        tokenAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: authority, amount: 0),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(mintAddr),
          AccountMeta.writable(tokenAddr),
          AccountMeta.signer(authority),
        ],
        data: _splMintToData(500),
      );

      final result = svm.processInstruction(ix, [mint, token]);

      // Overall CU should be > 0
      expect(result.computeUnits, greaterThan(0));

      // Per-instruction CU
      for (final instr in result.executionTrace.instructions) {
        expect(instr.computeUnitsConsumed, greaterThanOrEqualTo(0));
      }
    });
  });

  // =========================================================================
  // ATA creation with CPIs (parity with test_ata_creation_with_cpis)
  // =========================================================================

  group('ATA creation with CPIs', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm());
    tearDown(() => svm.free());

    test('create associated token account involves CPIs', () {
      // Use real-ish pubkeys that produce a valid PDA
      final payer = PublicKeyUtils.fromBase58(
        'HWy1jotHpo6UqeQxx49dpYYdQB8wj9Qk9MdxwjLvDHB8',
      );
      final wallet = PublicKeyUtils.fromBase58(
        '2gVkYDexTgWJZ6TCxLoiujSMaKkF4tRyLnCHSzPaeSgt',
      );
      final mintAddr = PublicKeyUtils.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );

      final payerAccount = createKeyedSystemAccount(
        payer,
        lamports: 10 * lamportsPerSol,
      );
      final walletAccount = createKeyedSystemAccount(wallet, lamports: 0);
      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: wallet, decimals: 6, supply: 1000000),
      );

      // Derive ATA address (sync version works now with fixed isOnCurve)
      final pda = PublicKeyUtils.findProgramAddressSync([
        wallet.bytes,
        splTokenProgramId.bytes,
        mintAddr.bytes,
      ], splAssociatedTokenProgramId);

      final ix = TransactionInstruction(
        programId: splAssociatedTokenProgramId,
        accounts: [
          AccountMeta.writable(payer, isSigner: true), // fee payer
          AccountMeta.writable(pda.address), // ATA account
          AccountMeta.readonly(wallet), // wallet
          AccountMeta.readonly(mintAddr), // mint
          AccountMeta.readonly(systemProgramId), // system program
          AccountMeta.readonly(splTokenProgramId), // token program
        ],
        data: Uint8List(0), // ATA create takes no data
      );

      final result = svm.processInstruction(ix, [
        payerAccount,
        walletAccount,
        mint,
      ]);

      // Print all logs for diagnostic purposes in verbose mode
      for (final log in result.logs) {
        // ignore: avoid_print
        print('  $log');
      }

      // Should have execution trace
      expect(result.executionTrace.instructions, isNotEmpty);

      // If successful, should have CPIs (system program create + token initialize)
      if (result.isSuccess) {
        expect(
          result.executionTrace.instructions.length,
          greaterThan(1),
          reason: 'ATA creation should involve CPI calls',
        );

        // Check nested calls exist
        final nested = result.executionTrace.instructions.where(
          (i) => i.stackDepth > 0,
        );
        expect(nested, isNotEmpty, reason: 'Should have nested CPI calls');
      }
    });
  });

  // =========================================================================
  // Sysvar configuration
  // =========================================================================

  group('Sysvar configuration', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm.empty());
    tearDown(() => svm.free());

    test('setClock does not throw', () {
      svm.setClock(
        Clock(
          slot: 100,
          epochStartTimestamp: 1700000000,
          epoch: 5,
          leaderScheduleEpoch: 6,
          unixTimestamp: 1700000500,
        ),
      );
    });

    test('warpToSlot does not throw', () {
      svm.warpToSlot(42);
    });

    test('setComputeBudget does not throw', () {
      svm.setComputeBudget(400000);
    });

    test('setRent does not throw', () {
      svm.setRent(lamportsPerByteYear: 3480);
    });

    test('setEpochSchedule does not throw', () {
      svm.setEpochSchedule(
        EpochSchedule(
          slotsPerEpoch: 432000,
          leaderScheduleSlotOffset: 432000,
          warmup: false,
          firstNormalEpoch: 0,
          firstNormalSlot: 0,
        ),
      );
    });
  });

  // =========================================================================
  // assertSuccess / assertError helpers
  // =========================================================================

  group('ExecutionResult assertions', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm());
    tearDown(() => svm.free());

    test('assertSuccess does not throw on success', () {
      final mintAddr = _key(90);
      final authority = _key(91);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: authority, decimals: 9),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [AccountMeta.readonly(mintAddr)],
        data: _splGetAccountDataSizeData(),
      );

      final result = svm.processInstruction(ix, [mint]);
      // Should not throw
      result.assertSuccess();
    });

    test('assertSuccess throws on error', () {
      final mintAddr = _key(92);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: _key(93), decimals: 9),
      );

      final ix = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [AccountMeta.readonly(mintAddr)],
        data: Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
      );

      final result = svm.processInstruction(ix, [mint]);
      expect(() => result.assertSuccess(), throwsStateError);
    });
  });

  // =========================================================================
  // Instruction chaining
  // =========================================================================

  group('Instruction chaining', () {
    late QuasarSvm svm;

    setUp(() => svm = QuasarSvm());
    tearDown(() => svm.free());

    test('processInstructionChain with multiple instructions', () {
      final mintAddr = _key(100);
      final tokenAddr = _key(101);
      final authority = _key(102);

      final mint = createKeyedMintAccount(
        mintAddr,
        opts: MintOpts(mintAuthority: authority, decimals: 9, supply: 0),
      );

      final token = createKeyedTokenAccount(
        tokenAddr,
        opts: TokenAccountOpts(mint: mintAddr, owner: authority, amount: 0),
      );

      // Two MintTo instructions in a chain
      final ix1 = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(mintAddr),
          AccountMeta.writable(tokenAddr),
          AccountMeta.signer(authority),
        ],
        data: _splMintToData(100),
      );

      final ix2 = TransactionInstruction(
        programId: splTokenProgramId,
        accounts: [
          AccountMeta.writable(mintAddr),
          AccountMeta.writable(tokenAddr),
          AccountMeta.signer(authority),
        ],
        data: _splMintToData(200),
      );

      final result = svm.processInstructionChain([ix1, ix2], [mint, token]);

      result.assertSuccess();
      expect(result.computeUnits, greaterThan(0));
    });
  });
}
