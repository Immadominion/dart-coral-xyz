/// Exception classes for the Anchor library
///
/// This file defines the exception hierarchy used throughout the Anchor library
/// for consistent error handling.
library;

/// Base exception class for all Anchor-related exceptions
class AnchorException implements Exception {
  /// Creates a new [AnchorException] with the provided [message]
  AnchorException(this.message);

  /// The error message
  final String message;

  @override
  String toString() => 'AnchorException: $message';
}

/// Exception thrown when there's an error related to instruction coding
class InstructionCoderException extends AnchorException {
  /// Creates a new [InstructionCoderException] with the provided [message]
  InstructionCoderException(super.message);

  @override
  String toString() => 'InstructionCoderException: $message';
}

/// Exception thrown when there's an error related to account coding
class AccountCoderException extends AnchorException {
  /// Creates a new [AccountCoderException] with the provided [message]
  AccountCoderException(super.message);

  @override
  String toString() => 'AccountCoderException: $message';
}

/// Exception thrown when there's an error related to event coding
class EventCoderException extends AnchorException {
  /// Creates a new [EventCoderException] with the provided [message]
  EventCoderException(super.message);

  @override
  String toString() => 'EventCoderException: $message';
}

/// Exception thrown when there's an error related to types coding
class TypesCoderException extends AnchorException {
  /// Creates a new [TypesCoderException] with the provided [message]
  TypesCoderException(super.message);

  @override
  String toString() => 'TypesCoderException: $message';
}
