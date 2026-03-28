/// Low-level base class managing the native QuasarSvm lifecycle.
///
/// Handles construction, destruction, NativeFinalizer, and sysvar setters.
/// The public [QuasarSvm] class extends this.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'execution_result.dart';
import 'ffi_bindings.dart';

/// Configuration for QuasarSvm creation.
class QuasarSvmConfig {
  const QuasarSvmConfig({
    this.token = true,
    this.token2022 = true,
    this.associatedToken = true,
  });

  /// Load SPL Token program on creation.
  final bool token;

  /// Load SPL Token-2022 program on creation.
  final bool token2022;

  /// Load SPL Associated Token Account program on creation.
  final bool associatedToken;
}

/// Default config that loads all SPL programs.
const quasarSvmConfigFull = QuasarSvmConfig();

/// Base class for native QuasarSvm lifecycle management.
///
/// Implements [Finalizable] for automatic cleanup via [NativeFinalizer].
abstract class QuasarSvmBase implements Finalizable {
  QuasarSvmBase() {
    final bindings = QuasarSvmBindings.instance;
    _ptr = bindings.svmNew();
    if (_ptr == nullptr) {
      final error = bindings.getLastError();
      throw StateError(
        'Failed to create QuasarSvm: ${error ?? "unknown error"}',
      );
    }
    bindings.finalizer.attach(this, _ptr, detach: this);
  }

  late final Pointer<Void> _ptr;
  bool _freed = false;

  /// The raw native pointer. Exposed for subclass use.
  Pointer<Void> get ptr {
    if (_freed) throw StateError('QuasarSvm has been freed');
    return _ptr;
  }

  /// Free native resources. Called automatically by NativeFinalizer
  /// on garbage collection, but should be called manually for prompt cleanup.
  void free() {
    if (!_freed) {
      _freed = true;
      final bindings = QuasarSvmBindings.instance;
      bindings.finalizer.detach(this);
      bindings.svmFree(_ptr);
    }
  }

  // ---------- Sysvars ----------

  /// Set the Clock sysvar.
  void setClock(Clock clock) {
    _check(
      QuasarSvmBindings.instance.svmSetClock(
        ptr,
        clock.slot,
        clock.epochStartTimestamp,
        clock.epoch,
        clock.leaderScheduleEpoch,
        clock.unixTimestamp,
      ),
    );
  }

  /// Advance the slot number.
  void warpToSlot(int slot) {
    _check(QuasarSvmBindings.instance.svmWarpToSlot(ptr, slot));
  }

  /// Set the Rent sysvar's lamports_per_byte_year.
  void setRent({required int lamportsPerByteYear}) {
    _check(QuasarSvmBindings.instance.svmSetRent(ptr, lamportsPerByteYear));
  }

  /// Set the EpochSchedule sysvar.
  void setEpochSchedule(EpochSchedule schedule) {
    _check(
      QuasarSvmBindings.instance.svmSetEpochSchedule(
        ptr,
        schedule.slotsPerEpoch,
        schedule.leaderScheduleSlotOffset,
        schedule.warmup,
        schedule.firstNormalEpoch,
        schedule.firstNormalSlot,
      ),
    );
  }

  /// Set the compute budget limit.
  void setComputeBudget(int maxUnits) {
    _check(QuasarSvmBindings.instance.svmSetComputeBudget(ptr, maxUnits));
  }

  // ---------- Internal ----------

  /// Check a return code and throw if non-zero.
  void _check(int code) {
    if (code != quasarOk) {
      final error = QuasarSvmBindings.instance.getLastError();
      throw StateError('QuasarSvm error ($code): ${error ?? "unknown"}');
    }
  }

  /// Execute raw serialized instructions + accounts and return the raw result buffer.
  Uint8List execRaw(Uint8List ixBuf, Uint8List acctBuf) {
    final bindings = QuasarSvmBindings.instance;

    // Allocate native memory for instruction and account buffers
    final ixNative = malloc<Uint8>(ixBuf.length);
    final acctNative = malloc<Uint8>(acctBuf.length);
    final resultOut = malloc<Pointer<Uint8>>();
    final resultLenOut = malloc<Uint64>();

    try {
      // Copy Dart data to native memory
      ixNative.asTypedList(ixBuf.length).setAll(0, ixBuf);
      acctNative.asTypedList(acctBuf.length).setAll(0, acctBuf);

      final code = bindings.svmProcessTransaction(
        ptr,
        ixNative,
        ixBuf.length,
        acctNative,
        acctBuf.length,
        resultOut,
        resultLenOut,
      );

      if (code != quasarOk) {
        final error = bindings.getLastError();
        throw StateError('Execution error ($code): ${error ?? "unknown"}');
      }

      final resultPtr = resultOut.value;
      final resultLen = resultLenOut.value;

      // Copy result to Dart-managed memory
      final result = Uint8List.fromList(resultPtr.asTypedList(resultLen));

      // Free the native result buffer
      bindings.resultFree(resultPtr, resultLen);

      return result;
    } finally {
      malloc.free(ixNative);
      malloc.free(acctNative);
      malloc.free(resultOut);
      malloc.free(resultLenOut);
    }
  }
}
