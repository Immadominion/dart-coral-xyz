/// Execution result types for the Quasar SVM.
///
/// Mirrors the Rust ProgramError enum and ExecutionResult struct.
/// Status codes match `program_error_to_i32` in `ffi/src/wire.rs`.
library;

import 'dart:typed_data';

import '../types/public_key.dart';
import '../types/transaction.dart';

// ---------------------------------------------------------------------------
// ProgramError — mirrors Rust ProgramError enum (named SvmProgramError in Dart)
// ---------------------------------------------------------------------------

/// Base class for all program errors returned by the SVM.
sealed class SvmProgramError {
  const SvmProgramError();
}

class InvalidArgument extends SvmProgramError {
  const InvalidArgument();
  @override
  String toString() => 'ProgramError::InvalidArgument';
}

class InvalidInstructionData extends SvmProgramError {
  const InvalidInstructionData();
  @override
  String toString() => 'ProgramError::InvalidInstructionData';
}

class InvalidAccountData extends SvmProgramError {
  const InvalidAccountData();
  @override
  String toString() => 'ProgramError::InvalidAccountData';
}

class AccountDataTooSmall extends SvmProgramError {
  const AccountDataTooSmall();
  @override
  String toString() => 'ProgramError::AccountDataTooSmall';
}

class InsufficientFunds extends SvmProgramError {
  const InsufficientFunds();
  @override
  String toString() => 'ProgramError::InsufficientFunds';
}

class IncorrectProgramId extends SvmProgramError {
  const IncorrectProgramId();
  @override
  String toString() => 'ProgramError::IncorrectProgramId';
}

class MissingRequiredSignature extends SvmProgramError {
  const MissingRequiredSignature();
  @override
  String toString() => 'ProgramError::MissingRequiredSignature';
}

class AccountAlreadyInitialized extends SvmProgramError {
  const AccountAlreadyInitialized();
  @override
  String toString() => 'ProgramError::AccountAlreadyInitialized';
}

class UninitializedAccount extends SvmProgramError {
  const UninitializedAccount();
  @override
  String toString() => 'ProgramError::UninitializedAccount';
}

class MissingAccount extends SvmProgramError {
  const MissingAccount();
  @override
  String toString() => 'ProgramError::MissingAccount';
}

class AccountBorrowFailed extends SvmProgramError {
  const AccountBorrowFailed();
  @override
  String toString() => 'ProgramError::AccountBorrowFailed';
}

class MaxSeedLengthExceeded extends SvmProgramError {
  const MaxSeedLengthExceeded();
  @override
  String toString() => 'ProgramError::MaxSeedLengthExceeded';
}

class InvalidSeeds extends SvmProgramError {
  const InvalidSeeds();
  @override
  String toString() => 'ProgramError::InvalidSeeds';
}

class BorshIoError extends SvmProgramError {
  const BorshIoError();
  @override
  String toString() => 'ProgramError::BorshIoError';
}

class AccountNotRentExempt extends SvmProgramError {
  const AccountNotRentExempt();
  @override
  String toString() => 'ProgramError::AccountNotRentExempt';
}

class UnsupportedSysvar extends SvmProgramError {
  const UnsupportedSysvar();
  @override
  String toString() => 'ProgramError::UnsupportedSysvar';
}

class IllegalOwner extends SvmProgramError {
  const IllegalOwner();
  @override
  String toString() => 'ProgramError::IllegalOwner';
}

class MaxAccountsDataAllocationsExceeded extends SvmProgramError {
  const MaxAccountsDataAllocationsExceeded();
  @override
  String toString() => 'ProgramError::MaxAccountsDataAllocationsExceeded';
}

class InvalidRealloc extends SvmProgramError {
  const InvalidRealloc();
  @override
  String toString() => 'ProgramError::InvalidRealloc';
}

class MaxInstructionTraceLengthExceeded extends SvmProgramError {
  const MaxInstructionTraceLengthExceeded();
  @override
  String toString() => 'ProgramError::MaxInstructionTraceLengthExceeded';
}

class ComputeBudgetExceeded extends SvmProgramError {
  const ComputeBudgetExceeded();
  @override
  String toString() => 'ProgramError::ComputeBudgetExceeded';
}

class InvalidAccountOwner extends SvmProgramError {
  const InvalidAccountOwner();
  @override
  String toString() => 'ProgramError::InvalidAccountOwner';
}

class ArithmeticOverflow extends SvmProgramError {
  const ArithmeticOverflow();
  @override
  String toString() => 'ProgramError::ArithmeticOverflow';
}

class Immutable extends SvmProgramError {
  const Immutable();
  @override
  String toString() => 'ProgramError::Immutable';
}

class IncorrectAuthority extends SvmProgramError {
  const IncorrectAuthority();
  @override
  String toString() => 'ProgramError::IncorrectAuthority';
}

class CustomError extends SvmProgramError {
  const CustomError(this.code);
  final int code;
  @override
  String toString() => 'ProgramError::Custom($code)';
}

class RuntimeError extends SvmProgramError {
  const RuntimeError(this.message);
  final String message;
  @override
  String toString() => 'ProgramError::Runtime($message)';
}

/// Map a wire status code to a [SvmProgramError].
/// Codes match Rust `program_error_to_i32`: known errors are negative, Custom(n) is positive.
SvmProgramError svmProgramErrorFromStatus(int status, String? errorMessage) {
  if (status > 0) return CustomError(status);

  return switch (status) {
    -1 => const InvalidArgument(),
    -2 => const InvalidInstructionData(),
    -3 => const InvalidAccountData(),
    -4 => const AccountDataTooSmall(),
    -5 => const InsufficientFunds(),
    -6 => const IncorrectProgramId(),
    -7 => const MissingRequiredSignature(),
    -8 => const AccountAlreadyInitialized(),
    -9 => const UninitializedAccount(),
    -10 => const MissingAccount(),
    -11 => const AccountBorrowFailed(),
    -12 => const MaxSeedLengthExceeded(),
    -13 => const InvalidSeeds(),
    -14 => const BorshIoError(),
    -15 => const AccountNotRentExempt(),
    -16 => const UnsupportedSysvar(),
    -17 => const IllegalOwner(),
    -18 => const MaxAccountsDataAllocationsExceeded(),
    -19 => const InvalidRealloc(),
    -20 => const MaxInstructionTraceLengthExceeded(),
    -21 => const ComputeBudgetExceeded(),
    -22 => const InvalidAccountOwner(),
    -23 => const ArithmeticOverflow(),
    -24 => const Immutable(),
    -25 => const IncorrectAuthority(),
    _ => RuntimeError(errorMessage ?? 'unknown error'),
  };
}

// ---------------------------------------------------------------------------
// ExecutionStatus — sealed union for pattern matching
// ---------------------------------------------------------------------------

sealed class ExecutionStatus {
  const ExecutionStatus();
  bool get ok;
}

class ExecutionSuccess extends ExecutionStatus {
  const ExecutionSuccess();
  @override
  bool get ok => true;
}

class ExecutionFailure extends ExecutionStatus {
  const ExecutionFailure({required this.error});
  final SvmProgramError error;
  @override
  bool get ok => false;
}

// ---------------------------------------------------------------------------
// KeyedAccount — account with an address
// ---------------------------------------------------------------------------

/// An account with an address — the universal type for passing state into the VM.
class KeyedAccount {
  const KeyedAccount({
    required this.address,
    required this.owner,
    required this.lamports,
    required this.data,
    this.executable = false,
  });

  final PublicKey address;
  final PublicKey owner;
  final int lamports;
  final Uint8List data;
  final bool executable;

  @override
  String toString() =>
      'KeyedAccount(${address.toBase58()}, lamports: $lamports, '
      'data: ${data.length} bytes, owner: ${owner.toBase58()})';
}

// ---------------------------------------------------------------------------
// TokenBalance — token balance snapshot from execution result
// ---------------------------------------------------------------------------

class TokenBalance {
  const TokenBalance({
    required this.accountIndex,
    required this.mint,
    this.owner,
    required this.decimals,
    required this.amount,
    this.uiAmount,
  });

  final int accountIndex;
  final String mint;
  final String? owner;
  final int decimals;
  final String amount;
  final double? uiAmount;
}

// ---------------------------------------------------------------------------
// ExecutionTrace — full instruction trace for CPI debugging
// ---------------------------------------------------------------------------

class ExecutionTrace {
  const ExecutionTrace({required this.instructions});
  final List<ExecutedInstruction> instructions;
}

class ExecutedInstruction {
  const ExecutedInstruction({
    required this.stackDepth,
    required this.instruction,
    required this.computeUnitsConsumed,
    required this.result,
  });

  final int stackDepth;
  final TransactionInstruction instruction;
  final int computeUnitsConsumed;

  /// 0 = success, non-zero = error
  final int result;
}

// ---------------------------------------------------------------------------
// Sysvar types
// ---------------------------------------------------------------------------

class Clock {
  const Clock({
    required this.slot,
    required this.epochStartTimestamp,
    required this.epoch,
    required this.leaderScheduleEpoch,
    required this.unixTimestamp,
  });

  final int slot;
  final int epochStartTimestamp;
  final int epoch;
  final int leaderScheduleEpoch;
  final int unixTimestamp;
}

class EpochSchedule {
  const EpochSchedule({
    required this.slotsPerEpoch,
    required this.leaderScheduleSlotOffset,
    required this.warmup,
    required this.firstNormalEpoch,
    required this.firstNormalSlot,
  });

  final int slotsPerEpoch;
  final int leaderScheduleSlotOffset;
  final bool warmup;
  final int firstNormalEpoch;
  final int firstNormalSlot;
}

// ---------------------------------------------------------------------------
// ExecutionResult
// ---------------------------------------------------------------------------

/// Result returned by `QuasarSvm.processInstruction` and `processInstructionChain`.
class ExecutionResult {
  const ExecutionResult({
    required this.status,
    required this.computeUnits,
    required this.executionTimeUs,
    required this.returnData,
    required this.accounts,
    required this.logs,
    required this.preBalances,
    required this.postBalances,
    required this.preTokenBalances,
    required this.postTokenBalances,
    required this.executionTrace,
  });

  final ExecutionStatus status;
  final int computeUnits;
  final int executionTimeUs;
  final Uint8List returnData;
  final List<KeyedAccount> accounts;
  final List<String> logs;
  final List<int> preBalances;
  final List<int> postBalances;
  final List<TokenBalance> preTokenBalances;
  final List<TokenBalance> postTokenBalances;
  final ExecutionTrace executionTrace;

  bool get isSuccess => status.ok;
  bool get isError => !status.ok;

  /// Throws [StateError] if execution failed, including logs in the message.
  void assertSuccess() {
    if (status case ExecutionFailure(:final error)) {
      final logsStr = logs.isNotEmpty ? '\nLogs:\n  ${logs.join('\n  ')}' : '';
      throw StateError('Execution failed: $error$logsStr');
    }
  }

  /// Throws [StateError] if execution didn't fail with the expected error type.
  void assertError<T extends SvmProgramError>() {
    if (status.ok) {
      throw StateError('Expected error of type $T but execution succeeded');
    }
    final failure = status as ExecutionFailure;
    if (failure.error is! T) {
      throw StateError('Expected error of type $T but got ${failure.error}');
    }
  }

  /// Look up a resulting account by address.
  KeyedAccount? account(PublicKey address) {
    final addressBytes = address.bytes;
    for (final acct in accounts) {
      if (_bytesEqual(acct.address.bytes, addressBytes)) return acct;
    }
    return null;
  }

  /// Print all logs to stdout.
  void printLogs() {
    for (final log in logs) {
      // ignore: avoid_print
      print(log);
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
