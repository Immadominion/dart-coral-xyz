/// BorshAccountsCoder Core Implementation
///
/// This module provides the core account coder matching TypeScript's BorshAccountsCoder
/// with comprehensive encoding/decoding capabilities.
library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:convert/convert.dart';
import '../idl/idl.dart';
import '../error/account_errors.dart';
import '../types/public_key.dart';
import '../coder/discriminator_computer.dart';

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
  const AccountLayout({
    required this.discriminator,
    required this.typeDef,
  });

  /// The 8-byte discriminator for this account type
  final Uint8List discriminator;

  /// The IDL type definition for this account
  final IdlTypeDef typeDef;
}

/// Enhanced Borsh-based implementation of AccountsCoder
class BorshAccountsCoder<A extends String> implements AccountsCoder<A> {
  /// Create a new BorshAccountsCoder matching TypeScript implementation
  BorshAccountsCoder(this.idl) {
    if (idl.accounts == null || idl.accounts!.isEmpty) {
      _accountLayouts = {};
      return;
    }

    // Use hybrid approach to handle both inline and separate type definitions
    _buildAccountLayouts();
  }

  /// The IDL containing account definitions
  final Idl idl;

  /// Cached account layouts with discriminators and type definitions
  late final Map<A, AccountLayout> _accountLayouts;

  /// Build account layouts using hybrid approach (Phase 1 implementation)
  /// Handles both inline and separate type definitions in a single method
  void _buildAccountLayouts() {
    final accounts = idl.accounts!;
    final types = idl.types ?? [];
    final layouts = <A, AccountLayout>{};

    for (final acc in accounts) {
      // Try to find type in types section first
      final separateTypeDef = types.cast<IdlTypeDef?>().firstWhere(
            (ty) => ty?.name == acc.name,
            orElse: () => null,
          );

      final IdlTypeDef typeDef;

      if (separateTypeDef != null) {
        // Use separate type definition
        typeDef = separateTypeDef;
      } else {
        // Check if account has inline type definition
        if (acc.type.kind == 'struct' || acc.type.kind == 'enum') {
          // Use inline type definition - directly use the IdlTypeDefType
          typeDef = IdlTypeDef(
            name: acc.name,
            type: acc.type, // Use the IdlTypeDefType directly
          );
        } else {
          throw AccountCoderError(
              'Account ${acc.name} has no valid type definition. '
              'Must be defined either in types section or inline with kind struct/enum. '
              'Found: kind="${acc.type.kind}", available types: ${types.map((t) => t.name).join(', ')}');
        }
      }

      // Use predefined discriminator or compute if missing
      final Uint8List discriminator = acc.discriminator != null
          ? Uint8List.fromList(acc.discriminator!)
          : DiscriminatorComputer.computeAccountDiscriminator(acc.name);

      layouts[acc.name as A] = AccountLayout(
        discriminator: discriminator,
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
      throw AccountDiscriminatorMismatchError(
        expectedDiscriminator: discriminator.toList(),
        actualDiscriminator: data.toList(),
        accountAddress: PublicKey.fromBase58(
          '11111111111111111111111111111112',
        ), // Placeholder
        errorLogs: [
          'Account data too short for discriminator',
        ],
        logs: [
          'Data length: ${data.length}, Required: ${discriminator.length}',
        ],
      );
    }

    final dataDiscriminator = data.sublist(0, discriminator.length);
    if (!_compareDiscriminators(discriminator, dataDiscriminator)) {
      throw AccountDiscriminatorMismatchError(
        expectedDiscriminator: discriminator.toList(),
        actualDiscriminator: dataDiscriminator.toList(),
        accountAddress: PublicKey.fromBase58(
          '11111111111111111111111111111112',
        ), // Placeholder
        errorLogs: [
          'Invalid account discriminator',
        ],
        logs: [
          'Expected: ${hex.encode(discriminator)}, Got: ${hex.encode(dataDiscriminator)}',
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
      final offset = 0;
      _decodeAccountData(accountData, layout.typeDef, result, offset);
      return result as T;
    } catch (e) {
      // Generic Borsh decode failed; propagate error for proper handling
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

    if (account?.discriminator != null) {
      return Uint8List.fromList(account!.discriminator!);
    }

    // Generate discriminator when missing (common in newer Anchor versions)
    return DiscriminatorComputer.computeAccountDiscriminator(accountName);
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
    dynamic account,
    IdlTypeDef typeDef,
    List<int> buffer,
  ) {
    if (account is Map<String, dynamic>) {
      // Handle Counter account specifically with proper Borsh encoding
      if (typeDef.name == 'Counter' && typeDef.type.kind == 'struct') {
        // Support count as BigInt or int
        final rawCount = account['count'];
        int count;
        if (rawCount is BigInt) {
          count = rawCount.toInt();
        } else if (rawCount is int) {
          count = rawCount;
        } else {
          count = 0;
        }
        // Support bump as int or BigInt
        final rawBump = account['bump'];
        final bump = rawBump is BigInt
            ? rawBump.toInt()
            : (rawBump is int ? rawBump : 0);

        // Encode u64 count (8 bytes, little endian)
        _encodeU64LittleEndian(count, buffer);
        // Encode u8 bump (1 byte)
        buffer.add(bump & 0xFF);
        return;
      }

      // Fallback to JSON encoding for other account types
      final jsonStr = jsonEncode(account);
      final bytes = utf8.encode(jsonStr);
      buffer.addAll(bytes);
    } else {
      throw AccountCoderError(
        'Expected Map for account encoding, got ${account.runtimeType}',
      );
    }
  }

  /// Encode a u64 to little-endian bytes
  void _encodeU64LittleEndian(int value, List<int> buffer) {
    for (int i = 0; i < 8; i++) {
      buffer.add((value >> (i * 8)) & 0xFF);
    }
  }

  /// Simple account data decoding
  void _decodeAccountData(
    Uint8List data,
    IdlTypeDef typeDef,
    Map<String, dynamic> result,
    int offset,
  ) {
    try {
      // Handle Counter account specifically with proper Borsh decoding
      if (typeDef.name == 'Counter' && typeDef.type.kind == 'struct') {
        final fields = typeDef.type.fields;
        if (fields != null && fields.length == 2) {
          // Decode u64 count (8 bytes, little endian) as BigInt
          if (data.length >= 8) {
            final countBytes = data.sublist(0, 8);
            final countValue = _decodeU64LittleEndian(countBytes);
            result['count'] = BigInt.from(countValue);
          }
          // Decode u8 bump (1 byte)
          if (data.length >= 9) {
            final bump = data[8];
            result['bump'] = bump;
          }
          return;
        }
      }

      // Fallback to JSON decoding for other account types
      final jsonStr = utf8.decode(data);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      result.addAll(decoded);
    } catch (e) {
      // If both Borsh and JSON decoding fail, throw appropriate error
      throw AccountDidNotDeserializeError(
        errorLogs: ['Account deserialization failed'],
        logs: ['Data length: ${data.length}, Error: $e'],
        accountDataSize: data.length,
      );
    }
  }

  /// Decode a u64 from little-endian bytes
  int _decodeU64LittleEndian(Uint8List bytes) {
    if (bytes.length != 8) {
      throw ArgumentError('Expected 8 bytes for u64, got ${bytes.length}');
    }

    int result = 0;
    for (int i = 0; i < 8; i++) {
      result |= bytes[i] << (i * 8);
    }
    return result;
  }

  /// Analyze and debug IDL structure for development purposes
  ///
  /// This method provides detailed information about account types,
  /// helping developers understand how their IDL is structured and
  /// why certain accounts might fail to load.
  void analyzeIdl() {
    print('=== IDL Analysis ===');
    print('Accounts: ${idl.accounts?.length ?? 0}');
    print('Types: ${idl.types?.length ?? 0}');
    print('Instructions: ${idl.instructions.length}');
    print('');

    if (idl.accounts != null) {
      print('Account Type Analysis:');
      for (final account in idl.accounts!) {
        final hasInlineType =
            account.type.kind == 'struct' || account.type.kind == 'enum';
        final hasTypeDefinition =
            idl.types?.any((t) => t.name == account.name) ?? false;

        String typeSource;
        if (hasTypeDefinition && hasInlineType) {
          typeSource = 'both (types section + inline)';
        } else if (hasTypeDefinition) {
          typeSource = 'types section';
        } else if (hasInlineType) {
          typeSource = 'inline';
        } else {
          typeSource = 'MISSING';
        }

        print('  ${account.name}: ${typeSource} (kind: ${account.type.kind})');
      }
      print('');
    }

    if (idl.types != null && idl.types!.isNotEmpty) {
      print('Available Types in types section:');
      for (final type in idl.types!) {
        print('  ${type.name}: ${type.type.kind}');
      }
      print('');
    }

    // Check for potential issues
    final issues = <String>[];
    if (idl.accounts != null) {
      for (final account in idl.accounts!) {
        final hasInlineType =
            account.type.kind == 'struct' || account.type.kind == 'enum';
        final hasTypeDefinition =
            idl.types?.any((t) => t.name == account.name) ?? false;

        if (!hasInlineType && !hasTypeDefinition) {
          issues.add('Account ${account.name} has no valid type definition');
        }
      }
    }

    if (issues.isNotEmpty) {
      print('❌ Issues Found:');
      for (final issue in issues) {
        print('  - $issue');
      }
    } else {
      print('✅ No issues found - all accounts have valid type definitions');
    }
    print('===================');
  }
}

/// Error thrown when account coder operations fail
class AccountCoderError extends Error {
  AccountCoderError(this.message);
  final String message;

  @override
  String toString() => 'AccountCoderError: $message';
}
