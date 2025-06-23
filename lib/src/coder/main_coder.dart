import '../idl/idl.dart';
import 'instruction_coder.dart';
import 'borsh_accounts_coder.dart';
import 'event_coder.dart';
import 'types_coder.dart';

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
  final InstructionCoder _instructions;
  final AccountsCoder<A> _accounts;
  final EventCoder _events;
  final TypesCoder<T> _types;

  /// Creates a new BorshCoder from an IDL
  ///
  /// [idl] The IDL definition to create coders from
  BorshCoder(Idl idl)
      : _instructions = BorshInstructionCoder(idl),
        _accounts = BorshAccountsCoder<A>(idl),
        _events = BorshEventCoder(idl),
        _types = BorshTypesCoder<T>(idl);

  @override
  InstructionCoder get instructions => _instructions;

  @override
  AccountsCoder<A> get accounts => _accounts;

  @override
  EventCoder get events => _events;

  @override
  TypesCoder<T> get types => _types;
}
