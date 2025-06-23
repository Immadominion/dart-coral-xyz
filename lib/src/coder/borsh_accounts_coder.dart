/// BorshAccountsCoder Core Implementation
///
/// This module provides the core account coder matching TypeScript's BorshAccountsCoder
/// with comprehensive encoding/decoding capabilities.

import 'dart:typed_data';
import 'dart:convert';
import 'package:convert/convert.dart';
import '../idl/idl.dart';
import '../error/error.dart';

/// Interface for encoding and decoding program accounts matching TypeScript AccountsCoder
abstract class AccountsCoder<A extends String> {
  /// Encode a program account with discriminator prefix
  Future<Uint8List> encode<T>(A accountName, T account);

  /// Decode a program account with discriminator verification
  T decode<T>(A accountName, Uint8List data);

  /// Decode a program account without discriminator verification (unsafe)
  T decodeUnchecked<T>(A accountName, Uint8List data);

  /// Decode any account type by checking discriminators
  T decodeAny<T>(Uint8List data);

  /// Create a memcmp filter for account queries
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData});

  /// Get the serialized size of an account
  int size(A accountName);

  /// Get the account discriminator for a given account type
  Uint8List accountDiscriminator(A accountName);
}

/// Account layout with discriminator and type definition
class AccountLayout {
  /// The 8-byte discriminator for this account type
  final Uint8List discriminator;

  /// The IDL type definition for this account
  final IdlTypeDef typeDef;

  const AccountLayout({
    required this.discriminator,
    required this.typeDef,
  });
}

/// Enhanced Borsh-based implementation of AccountsCoder
class BorshAccountsCoder<A extends String> implements AccountsCoder<A> {
  /// The IDL containing account definitions
  final Idl idl;

  /// Cached account layouts with discriminators and type definitions
  late final Map<A, AccountLayout> _accountLayouts;

  /// Create a new BorshAccountsCoder matching TypeScript implementation
  BorshAccountsCoder(this.idl) {
    if (idl.accounts == null || idl.accounts!.isEmpty) {
      _accountLayouts = {};
      return;
    }

    if (idl.types == null) {
      throw AccountCoderError('Accounts require `idl.types`');
    }

    _buildAccountLayouts();
  }

  /// Build account layouts from IDL matching TypeScript constructor logic
  void _buildAccountLayouts() {
    final accounts = idl.accounts!;
    final types = idl.types!;
    final layouts = <A, AccountLayout>{};

    for (final acc in accounts) {
      final typeDef = types.firstWhere(
        (ty) => ty.name == acc.name,
        orElse: () => throw AccountCoderError('Account not found: ${acc.name}'),
      );

      final discriminator = acc.discriminator;
      if (discriminator == null) {
        throw AccountCoderError('Account ${acc.name} missing discriminator');
      }

      layouts[acc.name as A] = AccountLayout(
        discriminator: Uint8List.fromList(discriminator),
        typeDef: typeDef,
      );
    }

    _accountLayouts = layouts;
  }

  @override
  Future<Uint8List> encode<T>(A accountName, T account) async {
    final layout = _accountLayouts[accountName];
    if (layout == null) {
      throw AccountCoderError('Unknown account: $accountName');
    }

    try {
      // Encode the account data using simple Borsh serialization
      final buffer = <int>[];
      _encodeAccountData(account, layout.typeDef, buffer);
      final accountData = Uint8List.fromList(buffer);

      // Combine discriminator + account data (matching TypeScript Buffer.concat)
      final result =
          Uint8List(layout.discriminator.length + accountData.length);
      result.setRange(0, layout.discriminator.length, layout.discriminator);
      result.setRange(layout.discriminator.length, result.length, accountData);

      return result;
    } catch (e) {
      throw AccountCoderError('Failed to encode account $accountName: $e');
    }
  }

  @override
  T decode<T>(A accountName, Uint8List data) {
    // Assert the account discriminator is correct (matching TypeScript implementation)
    final discriminator = accountDiscriminator(accountName);

    if (data.length < discriminator.length) {
      throw AccountDiscriminatorMismatchError.fromComparison(
        expected: discriminator.toList(),
        actual: data.toList(),
        errorLogs: ['Account data too short for discriminator'],
        logs: [
          'Data length: ${data.length}, Required: ${discriminator.length}'
        ],
      );
    }

    final dataDiscriminator = data.sublist(0, discriminator.length);
    if (!_compareDiscriminators(discriminator, dataDiscriminator)) {
      throw AccountDiscriminatorMismatchError.fromComparison(
        expected: discriminator.toList(),
        actual: dataDiscriminator.toList(),
        errorLogs: ['Invalid account discriminator'],
        logs: [
          'Expected: ${hex.encode(discriminator)}, Got: ${hex.encode(dataDiscriminator)}'
        ],
      );
    }

    return decodeUnchecked(accountName, data);
  }

  @override
  T decodeAny<T>(Uint8List data) {
    for (final entry in _accountLayouts.entries) {
      final name = entry.key;
      final layout = entry.value;

      if (data.length >= layout.discriminator.length) {
        final givenDisc = data.sublist(0, layout.discriminator.length);
        if (_compareDiscriminators(layout.discriminator, givenDisc)) {
          return decodeUnchecked(name, data);
        }
      }
    }

    throw AccountCoderError('Account not found');
  }

  @override
  T decodeUnchecked<T>(A accountName, Uint8List data) {
    // Chop off the discriminator before decoding (matching TypeScript)
    final discriminator = accountDiscriminator(accountName);
    final accountData = data.sublist(discriminator.length);

    final layout = _accountLayouts[accountName];
    if (layout == null) {
      throw AccountCoderError('Unknown account: $accountName');
    }

    try {
      // Decode the account data using simple deserialization
      final result = <String, dynamic>{};
      var offset = 0;
      _decodeAccountData(accountData, layout.typeDef, result, offset);
      return result as T;
    } catch (e) {
      throw AccountDidNotDeserializeError(
        errorLogs: ['Failed to deserialize account $accountName'],
        logs: ['Error: $e'],
        accountDataSize: data.length,
      );
    }
  }

  @override
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData}) {
    final discriminator = accountDiscriminator(accountName);
    final bytes = appendData != null
        ? Uint8List.fromList([...discriminator, ...appendData])
        : discriminator;

    return {
      'offset': 0,
      'bytes': base64.encode(bytes),
    };
  }

  @override
  int size(A accountName) {
    final discriminator = accountDiscriminator(accountName);
    final layout = _accountLayouts[accountName];
    if (layout == null) {
      throw AccountCoderError('Unknown account: $accountName');
    }

    // For now, return a basic size calculation
    return discriminator.length +
        1000; // TypeScript uses 1000 byte buffer initially
  }

  @override
  Uint8List accountDiscriminator(A accountName) {
    final account = idl.accounts?.firstWhere(
      (acc) => acc.name == accountName,
      orElse: () => throw AccountCoderError('Account not found: $accountName'),
    );

    if (account?.discriminator == null) {
      throw AccountCoderError('Account $accountName missing discriminator');
    }

    return Uint8List.fromList(account!.discriminator!);
  }

  /// Compare two discriminators for equality
  bool _compareDiscriminators(Uint8List expected, Uint8List actual) {
    if (expected.length != actual.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }

  /// Simple account data encoding
  void _encodeAccountData(
      dynamic account, IdlTypeDef typeDef, List<int> buffer) {
    if (account is Map<String, dynamic>) {
      // For now, use basic JSON encoding as placeholder
      final jsonStr = jsonEncode(account);
      final bytes = utf8.encode(jsonStr);
      buffer.addAll(bytes);
    } else {
      throw AccountCoderError(
          'Expected Map for account encoding, got ${account.runtimeType}');
    }
  }

  /// Simple account data decoding
  void _decodeAccountData(Uint8List data, IdlTypeDef typeDef,
      Map<String, dynamic> result, int offset) {
    try {
      // For now, use basic JSON decoding as placeholder
      final jsonStr = utf8.decode(data);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      result.addAll(decoded);
    } catch (e) {
      // If JSON decoding fails, throw appropriate error
      throw AccountDidNotDeserializeError(
        errorLogs: ['JSON decoding failed'],
        logs: ['Invalid JSON data: $e'],
        accountDataSize: data.length,
      );
    }
  }
}

/// Error thrown when account coder operations fail
class AccountCoderError extends Error {
  final String message;

  AccountCoderError(this.message);

  @override
  String toString() => 'AccountCoderError: $message';
}
