/// Main QuasarSvm class — the public API for in-process Solana program execution.
///
/// Usage:
/// ```dart
/// final svm = QuasarSvm();
/// final result = svm.processInstruction(instruction, accounts);
/// result.assertSuccess();
/// print('Used ${result.computeUnits} CU');
/// svm.free();
/// ```
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../types/public_key.dart';
import '../types/transaction.dart';
import 'execution_result.dart';
import 'ffi_bindings.dart';
import 'programs.dart';
import 'quasar_svm_base.dart';
import 'wire.dart' as wire;

/// In-process Solana Virtual Machine for deterministic program testing.
///
/// Creates a lightweight SVM instance that can load BPF programs and
/// execute instructions without a running validator.
class QuasarSvm extends QuasarSvmBase {
  /// Create a new QuasarSvm instance.
  ///
  /// By default, loads SPL Token, Token-2022, and Associated Token programs.
  /// Pass a custom [config] to control which programs are loaded.
  QuasarSvm({QuasarSvmConfig config = quasarSvmConfigFull}) {
    if (config.token) {
      addProgram(splTokenProgramId, loadElf('spl_token.so'), loaderVersion: loaderV2);
    }
    if (config.token2022) {
      addProgram(splToken2022ProgramId, loadElf('spl_token_2022.so'), loaderVersion: loaderV3);
    }
    if (config.associatedToken) {
      addProgram(splAssociatedTokenProgramId, loadElf('spl_associated_token.so'), loaderVersion: loaderV2);
    }
  }

  /// Create a QuasarSvm without loading any programs.
  QuasarSvm.empty() : super();

  /// Load a BPF program from ELF bytes.
  ///
  /// [programId] - The program's public key.
  /// [elf] - The compiled program ELF binary.
  /// [loaderVersion] - BPF loader version (2 or 3). Default: 3.
  void addProgram(
    PublicKey programId,
    Uint8List elf, {
    int loaderVersion = loaderV3,
  }) {
    final bindings = QuasarSvmBindings.instance;

    // Allocate and copy program ID (32 bytes) to native memory
    final programIdNative = malloc<Uint8>(32);
    final elfNative = malloc<Uint8>(elf.length);

    try {
      programIdNative.asTypedList(32).setAll(0, programId.bytes);
      elfNative.asTypedList(elf.length).setAll(0, elf);

      final code = bindings.svmAddProgram(
        ptr,
        programIdNative,
        elfNative,
        elf.length,
        loaderVersion,
      );

      if (code != quasarOk) {
        final error = bindings.getLastError();
        throw StateError(
          'Failed to add program ${programId.toBase58()}: ${error ?? "unknown"}',
        );
      }
    } finally {
      malloc.free(programIdNative);
      malloc.free(elfNative);
    }
  }

  // ---------- Execution ----------

  /// Execute a single instruction atomically.
  ExecutionResult processInstruction(
    TransactionInstruction instruction,
    List<KeyedAccount> accounts,
  ) {
    return processInstructionChain([instruction], accounts);
  }

  /// Execute multiple instructions as a single atomic chain.
  ExecutionResult processInstructionChain(
    List<TransactionInstruction> instructions,
    List<KeyedAccount> accounts,
  ) {
    final ixBuf = wire.serializeInstructions(instructions);
    final acctBuf = wire.serializeAccounts(accounts);
    final rawResult = execRaw(ixBuf, acctBuf);
    return wire.deserializeResult(rawResult);
  }
}
