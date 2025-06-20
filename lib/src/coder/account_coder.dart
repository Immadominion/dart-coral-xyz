/// Account coder implementation for Anchor programs
///
/// This module provides the AccountsCoder interface and implementations
/// for encoding and decoding program account data using Borsh serialization.

import '../idl/idl.dart';
import '../coder/borsh_types.dart';
import '../coder/borsh_utils.dart';
import '../types/common.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Interface for encoding and decoding program accounts
abstract class AccountsCoder<A extends String> {
  /// Encode a program account
  ///
  /// [accountName] - The name of the account type
  /// [account] - The account data to encode
  /// Returns the encoded account data as a byte buffer
  Future<Uint8List> encode<T>(A accountName, T account);

  /// Decode a program account with discriminator verification
  ///
  /// [accountName] - The name of the account type
  /// [data] - The account data to decode
  /// Returns the decoded account data
  T decode<T>(A accountName, Uint8List data);

  /// Decode a program account without discriminator verification
  ///
  /// [accountName] - The name of the account type
  /// [data] - The account data to decode
  /// Returns the decoded account data
  T decodeUnchecked<T>(A accountName, Uint8List data);

  /// Decode any account type by checking discriminators
  ///
  /// [data] - The account data to decode
  /// Returns the decoded account data
  T decodeAny<T>(Uint8List data);

  /// Create a memcmp filter for account queries
  ///
  /// [accountName] - The name of the account type
  /// [appendData] - Optional additional data to append
  /// Returns a memcmp filter object
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData});

  /// Get the serialized size of an account
  ///
  /// [accountName] - The name of the account type
  /// Returns the size in bytes
  int size(A accountName);

  /// Get the account discriminator for a given account type
  ///
  /// [accountName] - The name of the account type
  /// Returns the discriminator bytes
  Uint8List accountDiscriminator(A accountName);
}

/// Borsh-based implementation of AccountsCoder
class BorshAccountsCoder<A extends String> implements AccountsCoder<A> {
  /// The IDL containing account definitions
  final Idl idl;

  /// Cached account layouts with discriminators
  late final Map<A, AccountLayout> _accountLayouts;

  /// Create a new BorshAccountsCoder
  BorshAccountsCoder(this.idl) {
    _accountLayouts = _buildAccountLayouts();
  }

  @override
  Future<Uint8List> encode<T>(A accountName, T account) async {
    final layout = _accountLayouts[accountName];
    if (layout == null) {
      throw AccountCoderException('Unknown account: $accountName');
    }

    try {
      // Get the account type definition
      final typeDef = _getAccountTypeDef(accountName);

      // Encode the account data using Borsh serializer
      final serializer = BorshSerializer();
      _encodeAccountData(account, typeDef, serializer);
      final accountData = serializer.toBytes();

      // Prepend the discriminator
      final discriminator = Uint8List.fromList(layout.discriminator);
      final result = Uint8List(discriminator.length + accountData.length);
      result.setRange(0, discriminator.length, discriminator);
      result.setRange(discriminator.length, result.length, accountData);

      return result;
    } catch (e) {
      throw AccountCoderException('Failed to encode account $accountName: $e');
    }
  }

  @override
  T decode<T>(A accountName, Uint8List data) {
    // Verify the account discriminator
    final expectedDiscriminator = accountDiscriminator(accountName);
    if (data.length < expectedDiscriminator.length) {
      throw AccountCoderException(
          'Account data too short for discriminator verification');
    }

    for (int i = 0; i < expectedDiscriminator.length; i++) {
      if (data[i] != expectedDiscriminator[i]) {
        throw AccountCoderException('Invalid account discriminator');
      }
    }

    return decodeUnchecked(accountName, data);
  }

  @override
  T decodeUnchecked<T>(A accountName, Uint8List data) {
    final layout = _accountLayouts[accountName];
    if (layout == null) {
      throw AccountCoderException('Unknown account: $accountName');
    }

    try {
      // Skip the discriminator
      final discriminatorLength = layout.discriminator.length;
      final accountData = data.sublist(discriminatorLength);

      // Get the account type definition
      final typeDef = _getAccountTypeDef(accountName);

      // Decode using Borsh deserializer
      final deserializer = BorshDeserializer(accountData);
      return _decodeAccountData<T>(typeDef, deserializer);
    } catch (e) {
      throw AccountCoderException('Failed to decode account $accountName: $e');
    }
  }

  @override
  T decodeAny<T>(Uint8List data) {
    for (final entry in _accountLayouts.entries) {
      final accountName = entry.key;
      final layout = entry.value;

      if (data.length < layout.discriminator.length) continue;

      // Check discriminator match
      bool matches = true;
      for (int i = 0; i < layout.discriminator.length; i++) {
        if (data[i] != layout.discriminator[i]) {
          matches = false;
          break;
        }
      }

      if (matches) {
        try {
          return decodeUnchecked<T>(accountName, data);
        } catch (e) {
          // Continue trying other account types
          continue;
        }
      }
    }

    throw AccountCoderException('Account type not found');
  }

  @override
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData}) {
    final discriminator = accountDiscriminator(accountName);
    Uint8List bytes;

    if (appendData != null) {
      bytes = Uint8List(discriminator.length + appendData.length);
      bytes.setRange(0, discriminator.length, discriminator);
      bytes.setRange(discriminator.length, bytes.length, appendData);
    } else {
      bytes = discriminator;
    }

    return {
      'offset': 0,
      'bytes':
          base64.encode(bytes), // Using base64 for Dart/Solana compatibility
    };
  }

  @override
  int size(A accountName) {
    final discriminatorSize = accountDiscriminator(accountName).length;
    final typeDef = _getAccountTypeDef(accountName);
    final accountSize = _calculateTypeSize(typeDef);
    return discriminatorSize + accountSize;
  }

  @override
  Uint8List accountDiscriminator(A accountName) {
    final account = idl.accounts?.firstWhere(
      (acc) => acc.name == accountName,
      orElse: () =>
          throw AccountCoderException('Account not found: $accountName'),
    );

    if (account == null) {
      throw AccountCoderException('Account not found: $accountName');
    }

    final discriminator = account.discriminator;
    if (discriminator == null || discriminator.isEmpty) {
      // Generate discriminator using Anchor's algorithm: sha256("account:$accountName")
      print('INFO: Generating missing discriminator for account $accountName');
      return BorshUtils.createAccountDiscriminator(accountName);
    }

    return Uint8List.fromList(discriminator);
  }

  /// Build account layouts from IDL
  Map<A, AccountLayout> _buildAccountLayouts() {
    final layouts = <A, AccountLayout>{};

    if (idl.accounts == null || idl.accounts!.isEmpty) {
      return layouts;
    }

    for (final account in idl.accounts!) {
      // Create a type def from the account's type definition
      // Modern IDL format always has inline type definitions
      final typeDef = IdlTypeDef(
        name: account.name,
        type: account.type,
      );
      print('DEBUG: Created typeDef for account ${account.name}');

      // Ensure discriminator is not null, generate if missing
      List<int> discriminator = account.discriminator ?? [];
      if (discriminator.isEmpty) {
        // Generate discriminator using Anchor's algorithm: sha256("account:$accountName")
        print(
            'INFO: Generating missing discriminator for account ${account.name}');
        discriminator =
            BorshUtils.createAccountDiscriminator(account.name).toList();
      }

      layouts[account.name as A] = AccountLayout(
        discriminator: discriminator,
        account: account,
        typeDef: typeDef,
      );

      print(
          'DEBUG: Added account layout for ${account.name} with discriminator $discriminator');
    }

    print(
        'DEBUG: Built ${layouts.length} account layouts: ${layouts.keys.toList()}');
    return layouts;
  }

  /// Get the type definition for an account
  IdlTypeDef _getAccountTypeDef(A accountName) {
    final layout = _accountLayouts[accountName];
    if (layout == null) {
      throw AccountCoderException('Unknown account: $accountName');
    }
    return layout.typeDef;
  }

  /// Encode account data based on its type definition
  void _encodeAccountData(
      dynamic data, IdlTypeDef typeDef, BorshSerializer serializer) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) {
        throw AccountCoderException('Struct type missing fields');
      }

      if (data is! Map<String, dynamic>) {
        throw AccountCoderException('Expected Map for struct type');
      }

      for (final field in fields) {
        final value = data[field.name];
        if (value == null && field.type.kind != 'option') {
          throw AccountCoderException('Missing required field: ${field.name}');
        }
        _encodeValue(value, field.type, serializer);
      }
    } else {
      throw AccountCoderException('Unsupported account type: ${typeSpec.kind}');
    }
  }

  /// Decode account data based on its type definition
  T _decodeAccountData<T>(IdlTypeDef typeDef, BorshDeserializer deserializer) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) {
        throw AccountCoderException('Struct type missing fields');
      }

      final data = <String, dynamic>{};
      for (final field in fields) {
        data[field.name] = _decodeValue(field.type, deserializer);
      }
      return data as T;
    } else {
      throw AccountCoderException('Unsupported account type: ${typeSpec.kind}');
    }
  }

  /// Encode a single value based on its IDL type
  void _encodeValue(dynamic value, IdlType type, BorshSerializer serializer) {
    switch (type.kind) {
      case 'bool':
        serializer.writeBool(value as bool);
        break;
      case 'u8':
        serializer.writeU8(value as int);
        break;
      case 'i8':
        serializer.writeI8(value as int);
        break;
      case 'u16':
        serializer.writeU16(value as int);
        break;
      case 'i16':
        serializer.writeI16(value as int);
        break;
      case 'u32':
        serializer.writeU32(value as int);
        break;
      case 'i32':
        serializer.writeI32(value as int);
        break;
      case 'u64':
        serializer.writeU64(value as int);
        break;
      case 'i64':
        serializer.writeI64(value as int);
        break;
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'pubkey':
        serializer.writeString(value as String);
        break;
      case 'vec':
        final list = value as List;
        serializer.writeU32(list.length);
        for (final item in list) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      case 'option':
        if (value == null) {
          serializer.writeU8(0); // None
        } else {
          serializer.writeU8(1); // Some
          _encodeValue(value, type.inner!, serializer);
        }
        break;
      case 'array':
        final list = value as List;
        if (list.length != type.size) {
          throw AccountCoderException(
            'Array length mismatch: expected ${type.size}, got ${list.length}',
          );
        }
        for (final item in list) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      case 'defined':
        // Handle user-defined types (nested structs)
        final typeName = type.defined;
        if (typeName == null) {
          throw AccountCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == typeName,
          orElse: () =>
              throw AccountCoderException('Type not found: $typeName'),
        );
        if (nestedTypeDef != null) {
          _encodeAccountData(value, nestedTypeDef, serializer);
        }
        break;
      default:
        throw AccountCoderException(
            'Unsupported type for encoding: ${type.kind}');
    }
  }

  /// Decode a single value based on its IDL type
  dynamic _decodeValue(IdlType type, BorshDeserializer deserializer) {
    switch (type.kind) {
      case 'bool':
        return deserializer.readBool();
      case 'u8':
        return deserializer.readU8();
      case 'i8':
        return deserializer.readI8();
      case 'u16':
        return deserializer.readU16();
      case 'i16':
        return deserializer.readI16();
      case 'u32':
        return deserializer.readU32();
      case 'i32':
        return deserializer.readI32();
      case 'u64':
        return deserializer.readU64();
      case 'i64':
        return deserializer.readI64();
      case 'string':
        return deserializer.readString();
      case 'pubkey':
        return deserializer.readString();
      case 'vec':
        final length = deserializer.readU32();
        final list = <dynamic>[];
        for (int i = 0; i < length; i++) {
          list.add(_decodeValue(type.inner!, deserializer));
        }
        return list;
      case 'option':
        final hasValue = deserializer.readU8();
        if (hasValue == 0) {
          return null;
        } else {
          return _decodeValue(type.inner!, deserializer);
        }
      case 'array':
        final list = <dynamic>[];
        for (int i = 0; i < type.size!; i++) {
          list.add(_decodeValue(type.inner!, deserializer));
        }
        return list;
      case 'defined':
        // Handle user-defined types (nested structs)
        final typeName = type.defined;
        if (typeName == null) {
          throw AccountCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == typeName,
          orElse: () =>
              throw AccountCoderException('Type not found: $typeName'),
        );
        if (nestedTypeDef != null) {
          return _decodeAccountData(nestedTypeDef, deserializer);
        }
        return null;
      default:
        throw AccountCoderException(
            'Unsupported type for decoding: ${type.kind}');
    }
  }

  /// Calculate the size of a type in bytes
  int _calculateTypeSize(IdlTypeDef typeDef) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) return 0;

      int totalSize = 0;
      for (final field in fields) {
        totalSize += _calculateFieldSize(field.type);
      }
      return totalSize;
    }

    return 0; // Unknown size for non-struct types
  }

  /// Calculate the size of a field type in bytes
  int _calculateFieldSize(IdlType type) {
    switch (type.kind) {
      case 'bool':
      case 'u8':
      case 'i8':
        return 1;
      case 'u16':
      case 'i16':
        return 2;
      case 'u32':
      case 'i32':
        return 4;
      case 'u64':
      case 'i64':
        return 8;
      case 'pubkey':
        return 32; // Solana public keys are 32 bytes
      case 'string':
        return 4; // Length prefix + variable content (minimum)
      case 'vec':
        return 4; // Length prefix + variable content (minimum)
      case 'option':
        return 1 + (type.inner != null ? _calculateFieldSize(type.inner!) : 0);
      case 'array':
        final innerSize =
            type.inner != null ? _calculateFieldSize(type.inner!) : 0;
        return innerSize * (type.size ?? 0);
      case 'defined':
        // For nested types, we'd need to look up the definition
        return 0; // Placeholder - would need recursive calculation
      default:
        return 0;
    }
  }
}

/// Internal account layout information
class AccountLayout {
  /// The account discriminator bytes
  final List<int> discriminator;

  /// The IDL account definition
  final IdlAccount account;

  /// The IDL type definition for this account
  final IdlTypeDef typeDef;

  const AccountLayout({
    required this.discriminator,
    required this.account,
    required this.typeDef,
  });
}

/// Exception thrown by account coder operations
class AccountCoderException extends AnchorException {
  const AccountCoderException(String message, [dynamic cause])
      : super(message, cause);
}
