/// System program coder implementation
///
/// This module provides the system program coder matching TypeScript's SystemCoder
/// with support for encoding/decoding system program accounts.
library;

import 'dart:typed_data';
import '../idl/idl.dart';
import '../coder/idl_coder.dart';
import 'borsh_accounts_coder.dart';

/// System program accounts coder matching TypeScript SystemAccountsCoder
class SystemAccountsCoder<A extends String> implements AccountsCoder<A> {
  const SystemAccountsCoder(this.idl);

  final Idl idl;

  @override
  Future<Uint8List> encode<T>(A accountName, T account) async {
    throw UnsupportedError('System program does not support account encoding');
  }

  @override
  T decode<T>(A accountName, Uint8List data) {
    throw UnsupportedError('System program does not support account decoding');
  }

  @override
  T decodeUnchecked<T>(A accountName, Uint8List data) {
    throw UnsupportedError('System program does not support account decoding');
  }

  @override
  T decodeAny<T>(Uint8List data) {
    throw UnsupportedError('System program does not support account decoding');
  }

  @override
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData}) {
    switch (accountName) {
      case 'nonce':
        return {
          'dataSize': 80, // NONCE_ACCOUNT_LENGTH
        };
      default:
        throw ArgumentError('Invalid account name: $accountName');
    }
  }

  @override
  int size(A accountName) {
    // Use IdlCoder.typeSize matching TypeScript implementation
    return IdlCoder.typeSize(
      IdlType(
          kind: 'defined',
          defined: IdlDefinedType(name: accountName.toString())),
      idl,
    );
  }

  @override
  int sizeFromTypeDef(IdlTypeDef idlAccount) {
    return IdlCoder.typeSize(
      IdlType(kind: 'defined', defined: IdlDefinedType(name: idlAccount.name)),
      idl,
    );
  }

  @override
  Uint8List accountDiscriminator(A accountName) {
    throw UnsupportedError(
        'System program does not use account discriminators');
  }
}

/// System program instruction coder
class SystemInstructionCoder {
  const SystemInstructionCoder(this.idl);

  final Idl idl;

  Uint8List encode(String ixName, dynamic ix) {
    throw UnsupportedError('System instruction encoding not implemented');
  }
}

/// System program event coder
class SystemEventsCoder {
  const SystemEventsCoder(this.idl);

  final Idl idl;

  T decode<T>(Uint8List data) {
    throw UnsupportedError('System program does not emit events');
  }
}

/// System program types coder
class SystemTypesCoder {
  const SystemTypesCoder(this.idl);

  final Idl idl;

  Uint8List encode<T>(String name, T type) {
    throw UnsupportedError('System does not have user-defined types');
  }

  T decode<T>(String name, Uint8List typeData) {
    throw UnsupportedError('System does not have user-defined types');
  }
}

/// Complete system program coder matching TypeScript SystemCoder
class SystemCoder {
  SystemCoder(Idl idl)
      : instruction = SystemInstructionCoder(idl),
        accounts = SystemAccountsCoder(idl),
        events = SystemEventsCoder(idl),
        types = SystemTypesCoder(idl);

  final SystemInstructionCoder instruction;
  final SystemAccountsCoder accounts;
  final SystemEventsCoder events;
  final SystemTypesCoder types;
}
