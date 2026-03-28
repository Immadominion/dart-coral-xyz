/// Low-level FFI bindings for the quasar-svm native library.
///
/// This file mirrors the C API from `quasar_svm.h` exactly — 10 functions.
/// All functions are looked up from the native dynamic library at load time.
library;

import 'dart:ffi';
import 'dart:io' show File, Platform;

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Error codes (match quasar_svm.h)
// ---------------------------------------------------------------------------

const int quasarOk = 0;
const int quasarErrNullPointer = -1;
const int quasarErrInvalidUtf8 = -2;
const int quasarErrProgramLoad = -3;
const int quasarErrExecution = -4;
const int quasarErrOutOfBounds = -5;
const int quasarErrInternal = -99;

// ---------------------------------------------------------------------------
// Native type signatures (C → Dart)
// ---------------------------------------------------------------------------

// quasar_last_error() -> const char*
typedef _QuasarLastErrorNative = Pointer<Utf8> Function();
typedef _QuasarLastErrorDart = Pointer<Utf8> Function();

// quasar_svm_new() -> QuasarSvm*
typedef _QuasarSvmNewNative = Pointer<Void> Function();
typedef _QuasarSvmNewDart = Pointer<Void> Function();

// quasar_svm_free(QuasarSvm*)
typedef _QuasarSvmFreeNative = Void Function(Pointer<Void>);
typedef _QuasarSvmFreeDart = void Function(Pointer<Void>);

// quasar_svm_add_program(svm, program_id, elf_data, elf_len, loader_version)
typedef _QuasarSvmAddProgramNative =
    Int32 Function(
      Pointer<Void>, // svm
      Pointer<Uint8>, // program_id (32 bytes)
      Pointer<Uint8>, // elf_data
      Uint64, // elf_len
      Uint8, // loader_version
    );
typedef _QuasarSvmAddProgramDart =
    int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, int, int);

// quasar_svm_set_clock(svm, slot, epoch_start_ts, epoch, leader_epoch, unix_ts)
typedef _QuasarSvmSetClockNative =
    Int32 Function(Pointer<Void>, Uint64, Int64, Uint64, Uint64, Int64);
typedef _QuasarSvmSetClockDart =
    int Function(Pointer<Void>, int, int, int, int, int);

// quasar_svm_warp_to_slot(svm, slot)
typedef _QuasarSvmWarpToSlotNative = Int32 Function(Pointer<Void>, Uint64);
typedef _QuasarSvmWarpToSlotDart = int Function(Pointer<Void>, int);

// quasar_svm_set_rent(svm, lamports_per_byte_year)
typedef _QuasarSvmSetRentNative = Int32 Function(Pointer<Void>, Uint64);
typedef _QuasarSvmSetRentDart = int Function(Pointer<Void>, int);

// quasar_svm_set_epoch_schedule(svm, slots, offset, warmup, first_epoch, first_slot)
typedef _QuasarSvmSetEpochScheduleNative =
    Int32 Function(Pointer<Void>, Uint64, Uint64, Bool, Uint64, Uint64);
typedef _QuasarSvmSetEpochScheduleDart =
    int Function(Pointer<Void>, int, int, bool, int, int);

// quasar_svm_set_compute_budget(svm, max_units)
typedef _QuasarSvmSetComputeBudgetNative =
    Int32 Function(Pointer<Void>, Uint64);
typedef _QuasarSvmSetComputeBudgetDart = int Function(Pointer<Void>, int);

// quasar_svm_process_transaction(svm, ix, ix_len, acct, acct_len, result_out, result_len_out)
typedef _QuasarSvmProcessTransactionNative =
    Int32 Function(
      Pointer<Void>, // svm
      Pointer<Uint8>, // instructions
      Uint64, // instructions_len
      Pointer<Uint8>, // accounts
      Uint64, // accounts_len
      Pointer<Pointer<Uint8>>, // result_out
      Pointer<Uint64>, // result_len_out
    );
typedef _QuasarSvmProcessTransactionDart =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Pointer<Uint8>>,
      Pointer<Uint64>,
    );

// quasar_result_free(result, result_len)
typedef _QuasarResultFreeNative = Void Function(Pointer<Uint8>, Uint64);
typedef _QuasarResultFreeDart = void Function(Pointer<Uint8>, int);

// ---------------------------------------------------------------------------
// Library loading
// ---------------------------------------------------------------------------

String _libraryName() {
  if (Platform.isMacOS) return 'libquasar_svm.dylib';
  if (Platform.isLinux) return 'libquasar_svm.so';
  if (Platform.isWindows) return 'quasar_svm.dll';
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

DynamicLibrary _loadLibrary() {
  final libName = _libraryName();

  // 1. Explicit env var
  final envPath = Platform.environment['QUASAR_SVM_LIB'];
  if (envPath != null && envPath.isNotEmpty) {
    return DynamicLibrary.open(envPath);
  }

  // 2. <package_root>/native/
  // Resolve from this file's location: lib/src/svm/ → package root
  final scriptUri = Platform.script;
  if (scriptUri.scheme == 'file') {
    // Running from the package via `dart test` or `dart run`
    final scriptDir = p.dirname(scriptUri.toFilePath());
    // Try to find the package root by walking up
    var dir = scriptDir;
    for (var i = 0; i < 10; i++) {
      final candidate = p.join(dir, 'native', libName);
      if (File(candidate).existsSync()) {
        return DynamicLibrary.open(candidate);
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
  }

  // Also try current directory's native/ folder
  final nativePath = p.join(p.current, 'native', libName);
  try {
    return DynamicLibrary.open(nativePath);
  } on ArgumentError {
    // Fall through to monorepo sibling
  }

  // 3. Monorepo sibling: <cwd>/../quasar-svm/target/release/
  final siblingPath = p.join(
    p.current,
    '..',
    'quasar-svm',
    'target',
    'release',
    libName,
  );
  try {
    return DynamicLibrary.open(siblingPath);
  } on ArgumentError {
    // Fall through to error
  }

  // Also try the quasar-svm as a direct sibling (if cwd is dart-coral-xyz parent)
  final sibling2 = p.join(
    p.current,
    'quasar-svm',
    'target',
    'release',
    libName,
  );
  try {
    return DynamicLibrary.open(sibling2);
  } on ArgumentError {
    // Final fallback
  }

  throw StateError(
    'Could not find $libName. Searched:\n'
    '  1. QUASAR_SVM_LIB env var\n'
    '  2. <package>/native/$libName\n'
    '  3. ../quasar-svm/target/release/$libName\n'
    '\n'
    'Build it with:\n'
    '  cd quasar-svm && cargo build --release -p quasar-svm-ffi\n'
    '\n'
    'Then either:\n'
    '  - Set QUASAR_SVM_LIB=/path/to/$libName\n'
    '  - Symlink: ln -sf ../../quasar-svm/target/release/$libName native/$libName',
  );
}

// ---------------------------------------------------------------------------
// Bindings class — lazy singleton
// ---------------------------------------------------------------------------

class QuasarSvmBindings {
  QuasarSvmBindings._(DynamicLibrary lib)
    : lastError = lib
          .lookupFunction<_QuasarLastErrorNative, _QuasarLastErrorDart>(
            'quasar_last_error',
          ),
      svmNew = lib.lookupFunction<_QuasarSvmNewNative, _QuasarSvmNewDart>(
        'quasar_svm_new',
      ),
      svmFree = lib.lookupFunction<_QuasarSvmFreeNative, _QuasarSvmFreeDart>(
        'quasar_svm_free',
      ),
      svmAddProgram = lib
          .lookupFunction<_QuasarSvmAddProgramNative, _QuasarSvmAddProgramDart>(
            'quasar_svm_add_program',
          ),
      svmSetClock = lib
          .lookupFunction<_QuasarSvmSetClockNative, _QuasarSvmSetClockDart>(
            'quasar_svm_set_clock',
          ),
      svmWarpToSlot = lib
          .lookupFunction<_QuasarSvmWarpToSlotNative, _QuasarSvmWarpToSlotDart>(
            'quasar_svm_warp_to_slot',
          ),
      svmSetRent = lib
          .lookupFunction<_QuasarSvmSetRentNative, _QuasarSvmSetRentDart>(
            'quasar_svm_set_rent',
          ),
      svmSetEpochSchedule = lib
          .lookupFunction<
            _QuasarSvmSetEpochScheduleNative,
            _QuasarSvmSetEpochScheduleDart
          >('quasar_svm_set_epoch_schedule'),
      svmSetComputeBudget = lib
          .lookupFunction<
            _QuasarSvmSetComputeBudgetNative,
            _QuasarSvmSetComputeBudgetDart
          >('quasar_svm_set_compute_budget'),
      svmProcessTransaction = lib
          .lookupFunction<
            _QuasarSvmProcessTransactionNative,
            _QuasarSvmProcessTransactionDart
          >('quasar_svm_process_transaction'),
      resultFree = lib
          .lookupFunction<_QuasarResultFreeNative, _QuasarResultFreeDart>(
            'quasar_result_free',
          ),
      _svmFreePtr = lib.lookup<NativeFunction<_QuasarSvmFreeNative>>(
        'quasar_svm_free',
      );

  static QuasarSvmBindings? _instance;

  static QuasarSvmBindings get instance {
    return _instance ??= QuasarSvmBindings._(_loadLibrary());
  }

  // The 10 FFI functions

  final _QuasarLastErrorDart lastError;
  final _QuasarSvmNewDart svmNew;
  final _QuasarSvmFreeDart svmFree;
  final _QuasarSvmAddProgramDart svmAddProgram;
  final _QuasarSvmSetClockDart svmSetClock;
  final _QuasarSvmWarpToSlotDart svmWarpToSlot;
  final _QuasarSvmSetRentDart svmSetRent;
  final _QuasarSvmSetEpochScheduleDart svmSetEpochSchedule;
  final _QuasarSvmSetComputeBudgetDart svmSetComputeBudget;
  final _QuasarSvmProcessTransactionDart svmProcessTransaction;
  final _QuasarResultFreeDart resultFree;

  /// Raw pointer to quasar_svm_free for NativeFinalizer.
  final Pointer<NativeFunction<_QuasarSvmFreeNative>> _svmFreePtr;

  /// NativeFinalizer that calls quasar_svm_free on garbage collection.
  late final NativeFinalizer finalizer = NativeFinalizer(_svmFreePtr.cast());

  /// Get the last error message from the native library, or null.
  String? getLastError() {
    final ptr = lastError();
    if (ptr == nullptr) return null;
    return ptr.toDartString();
  }
}
