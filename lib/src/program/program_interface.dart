/// Manual Program Interface Definition API
///
/// Provides a builder-pattern API for defining Solana program interfaces
/// without an IDL file. This is useful for Pinocchio programs or any
/// on-chain program that doesn't ship an IDL.
///
/// ```dart
/// final idl = ProgramInterface.define(
///   name: 'counter',
///   address: 'CounterProgramAddress...',
/// )
///   .instruction('initialize', discriminator: [0])
///     .account('counter', writable: true, signer: true)
///     .account('user', signer: true)
///     .account('systemProgram')
///     .arg('initialValue', 'u64')
///     .done()
///   .instruction('increment', discriminator: [1])
///     .account('counter', writable: true)
///     .account('user', signer: true)
///     .arg('amount', 'u64')
///     .done()
///   .account('Counter', discriminator: [0])
///     .field('authority', 'pubkey')
///     .field('count', 'u64')
///     .done()
///   .build();
///
/// final program = Program(idl, provider: provider);
/// ```
library;

import '../idl/idl.dart';

/// Entry point for manually defining a program interface.
///
/// Produces an [Idl] with `format: IdlFormat.manual`.
class ProgramInterface {
  ProgramInterface._();

  /// Start defining a program interface.
  static ProgramInterfaceBuilder define({
    required String name,
    String? address,
    String version = '0.0.0',
  }) =>
      ProgramInterfaceBuilder._(name: name, address: address, version: version);
}

/// Builder for constructing a complete [Idl] from manual definitions.
class ProgramInterfaceBuilder {
  ProgramInterfaceBuilder._({
    required this.name,
    this.address,
    this.version = '0.0.0',
  });

  final String name;
  final String? address;
  final String version;

  final List<Map<String, dynamic>> _instructions = [];
  final List<Map<String, dynamic>> _accounts = [];
  final List<Map<String, dynamic>> _types = [];
  final List<Map<String, dynamic>> _events = [];
  final List<Map<String, dynamic>> _errors = [];

  /// Define an instruction.
  InstructionDefBuilder instruction(String name, {List<int>? discriminator}) =>
      InstructionDefBuilder._(this, name, discriminator);

  /// Define an account type (data layout).
  AccountDefBuilder account(String name, {List<int>? discriminator}) =>
      AccountDefBuilder._(this, name, discriminator);

  /// Define a custom type (struct or enum).
  TypeDefBuilder type(String name) => TypeDefBuilder._(this, name);

  /// Define an event.
  ProgramInterfaceBuilder event(String name, {List<int>? discriminator}) {
    _events.add({
      'name': name,
      if (discriminator != null) 'discriminator': discriminator,
    });
    return this;
  }

  /// Define an error code.
  ProgramInterfaceBuilder error(int code, String name, {String? msg}) {
    _errors.add({'code': code, 'name': name, if (msg != null) 'msg': msg});
    return this;
  }

  /// Build the final [Idl] from all definitions.
  Idl build() {
    return Idl.fromJson({
      'name': name,
      'version': version,
      'address': address ?? '',
      'metadata': {'name': name, 'version': version, 'spec': 'manual'},
      'instructions': _instructions,
      'accounts': _accounts,
      'types': _types,
      if (_events.isNotEmpty) 'events': _events,
      if (_errors.isNotEmpty) 'errors': _errors,
    });
  }
}

/// Builder for defining a single instruction.
class InstructionDefBuilder {
  InstructionDefBuilder._(this._parent, this._name, this._discriminator);

  final ProgramInterfaceBuilder _parent;
  final String _name;
  final List<int>? _discriminator;
  final List<Map<String, dynamic>> _accounts = [];
  final List<Map<String, dynamic>> _args = [];

  /// Add an account to this instruction.
  InstructionDefBuilder account(
    String name, {
    bool writable = false,
    bool signer = false,
    bool optional = false,
  }) {
    _accounts.add({
      'name': name,
      'writable': writable,
      'signer': signer,
      'optional': optional,
    });
    return this;
  }

  /// Add an argument to this instruction.
  ///
  /// [type] can be a simple string like `'u64'`, `'pubkey'`, `'string'`,
  /// or a complex type map like `{'vec': 'u8'}`, `{'option': 'pubkey'}`.
  InstructionDefBuilder arg(String name, dynamic type) {
    _args.add({'name': name, 'type': type});
    return this;
  }

  /// Finalize this instruction and return to the parent builder.
  ProgramInterfaceBuilder done() {
    _parent._instructions.add({
      'name': _name,
      if (_discriminator != null) 'discriminator': _discriminator,
      'accounts': _accounts,
      'args': _args,
    });
    return _parent;
  }
}

/// Builder for defining an account data layout.
class AccountDefBuilder {
  AccountDefBuilder._(this._parent, this._name, this._discriminator);

  final ProgramInterfaceBuilder _parent;
  final String _name;
  final List<int>? _discriminator;
  final List<Map<String, dynamic>> _fields = [];

  /// Add a field to this account's data layout.
  ///
  /// [type] can be a simple string like `'u64'`, `'pubkey'`, `'bool'`,
  /// or a complex type map like `{'vec': 'u8'}`, `{'array': ['u8', 32]}`.
  AccountDefBuilder field(String name, dynamic type) {
    _fields.add({'name': name, 'type': type});
    return this;
  }

  /// Finalize this account and return to the parent builder.
  ProgramInterfaceBuilder done() {
    _parent._accounts.add({
      'name': _name,
      'discriminator': _discriminator ?? <int>[],
    });
    // Also add to types so the coder knows the data layout
    _parent._types.add({
      'name': _name,
      'type': {'kind': 'struct', 'fields': _fields},
    });
    return _parent;
  }
}

/// Builder for defining a custom type (struct or enum).
class TypeDefBuilder {
  TypeDefBuilder._(this._parent, this._name);

  final ProgramInterfaceBuilder _parent;
  final String _name;
  final List<Map<String, dynamic>> _fields = [];
  final List<Map<String, dynamic>> _variants = [];

  /// Add a field (for struct types).
  TypeDefBuilder field(String name, dynamic type) {
    _fields.add({'name': name, 'type': type});
    return this;
  }

  /// Add an enum variant (for enum types).
  TypeDefBuilder variant(String name, {List<Map<String, dynamic>>? fields}) {
    _variants.add({'name': name, if (fields != null) 'fields': fields});
    return this;
  }

  /// Finalize this type as a struct.
  ProgramInterfaceBuilder doneAsStruct() {
    _parent._types.add({
      'name': _name,
      'type': {'kind': 'struct', 'fields': _fields},
    });
    return _parent;
  }

  /// Finalize this type as an enum.
  ProgramInterfaceBuilder doneAsEnum() {
    _parent._types.add({
      'name': _name,
      'type': {'kind': 'enum', 'variants': _variants},
    });
    return _parent;
  }

  /// Finalize this type. Uses struct if fields are defined, enum if variants.
  ProgramInterfaceBuilder done() {
    if (_variants.isNotEmpty) return doneAsEnum();
    return doneAsStruct();
  }
}
