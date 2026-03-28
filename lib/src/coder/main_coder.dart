import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/coder/instruction_coder.dart';
import 'package:coral_xyz/src/coder/borsh_accounts_coder.dart';
import 'package:coral_xyz/src/coder/accounts_coder_factory.dart';
import 'package:coral_xyz/src/coder/event_coder.dart';
import 'package:coral_xyz/src/coder/types_coder.dart';
import 'package:coral_xyz/src/types/public_key.dart';

/// Main coder interface for all serialization/deserialization operations
///
/// This interface provides a unified facade for all coding operations,
/// combining instruction, account, event, and types coders.
abstract class Coder<A extends String, T extends String> {
  /// Instruction coder for encoding/decoding program instructions
  InstructionCoder get instructions;

  /// Account coder for encoding/decoding account data
  AccountsCoder<A> get accounts;

  /// Event coder for encoding/decoding program events
  EventCoder get events;

  /// Types coder for encoding/decoding user-defined types
  TypesCoder<T> get types;
}

/// Borsh-based implementation of the main Coder interface
///
/// This class provides a concrete implementation of the Coder interface
/// using Borsh serialization for all operations.
class BorshCoder<A extends String, T extends String> implements Coder<A, T> {
  /// Creates a new BorshCoder from an IDL
  ///
  /// [idl] The IDL definition to create coders from
  /// [programId] Optional program ID to associate with events
  BorshCoder(Idl idl, [PublicKey? programId])
    : _instructions = BorshInstructionCoder(idl),
      _accounts = BorshAccountsCoder<A>(idl),
      _events = BorshEventCoder(idl, programId),
      _types = BorshTypesCoder<T>(idl);
  final InstructionCoder _instructions;
  final AccountsCoder<A> _accounts;
  final EventCoder _events;
  final TypesCoder<T> _types;

  @override
  InstructionCoder get instructions => _instructions;

  @override
  AccountsCoder<A> get accounts => _accounts;

  @override
  EventCoder get events => _events;

  @override
  TypesCoder<T> get types => _types;
}

/// Auto-detecting Coder that dispatches to the correct implementations
/// based on the IDL format.
///
/// - **Anchor**: BorshAccountsCoder, BorshInstructionCoder, BorshEventCoder
/// - **Quasar**: ZeroCopyAccountsCoder, BorshInstructionCoder, BorshEventCoder
/// - **Manual**: ZeroCopyAccountsCoder, BorshInstructionCoder, BorshEventCoder
///
/// The instruction and event coders already support both frameworks internally
/// (they handle explicit discriminators, `0xFF` prefix, Quasar types, etc.).
/// Only the accounts coder differs (Borsh vs zero-copy layout).
class AutoCoder<A extends String, T extends String> implements Coder<A, T> {
  /// Creates an AutoCoder that selects sub-coders based on [idl.format].
  AutoCoder(Idl idl, [PublicKey? programId])
    : _instructions = BorshInstructionCoder(idl),
      _accounts = AccountsCoderFactory.create(idl) as AccountsCoder<A>,
      _events = BorshEventCoder(idl, programId),
      _types = BorshTypesCoder<T>(idl);

  final InstructionCoder _instructions;
  final AccountsCoder<A> _accounts;
  final EventCoder _events;
  final TypesCoder<T> _types;

  @override
  InstructionCoder get instructions => _instructions;

  @override
  AccountsCoder<A> get accounts => _accounts;

  @override
  EventCoder get events => _events;

  @override
  TypesCoder<T> get types => _types;
}

/// Factory for creating the appropriate [Coder] based on the IDL.
///
/// ```dart
/// final coder = CoderFactory.fromIdl(idl, programId);
/// ```
class CoderFactory {
  CoderFactory._();

  /// Auto-detect the IDL format and return the matching coder.
  static Coder<String, String> fromIdl(Idl idl, [PublicKey? programId]) =>
      AutoCoder<String, String>(idl, programId);

  /// Force a Borsh-only coder (Anchor programs).
  static Coder<String, String> borsh(Idl idl, [PublicKey? programId]) =>
      BorshCoder<String, String>(idl, programId);
}
