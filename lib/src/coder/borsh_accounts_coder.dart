/// BorshAccountsCoder Core Implementation
///
/// This module provides the core account coder matching TypeScript's BorshAccountsCoder
/// with comprehensive encoding/decoding capabilities.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import '../idl/idl.dart';
import '../error/account_errors.dart';
import '../types/public_key.dart';
import '../coder/discriminator_computer.dart';
import '../coder/idl_coder.dart';
import 'borsh_types.dart';

/// Interface for encoding and decoding program accounts matching TypeScript AccountsCoder
abstract class AccountsCoder<A extends String> {
  /// Encode a program account with discriminator prefix
  Future<Uint8List> encode<T>(A accountName, T account);

  /// Decode a program account with discriminator verification
  ///
  /// [accountAddress] is optional; when provided it is included in the error
  /// if the discriminator check fails, which aids debugging.
  T decode<T>(A accountName, Uint8List data, {PublicKey? accountAddress});

  /// Decode a program account without discriminator verification (unsafe)
  T decodeUnchecked<T>(A accountName, Uint8List data);

  /// Decode any account type by checking discriminators
  T decodeAny<T>(Uint8List data);

  /// Create a memcmp filter for account queries
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData});

  /// Get the serialized size of an account by name
  int size(A accountName);

  /// Get the serialized size of an account by IDL type definition (TypeScript compatibility)
  int sizeFromTypeDef(IdlTypeDef idlAccount);

  /// Get the account discriminator for a given account type
  Uint8List accountDiscriminator(A accountName);
}

/// Account layout with discriminator and type definition
class AccountLayout {
  const AccountLayout({required this.discriminator, required this.typeDef});

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
      // In modern IDL format, account type definitions are in idl.types
      // and matched by name, not embedded in the account definition
      final typeDef = types.cast<IdlTypeDef?>().firstWhere(
        (ty) => ty?.name == acc.name,
        orElse: () => throw AccountCoderError(
          'Account type definition not found for ${acc.name}. '
          'Available types: ${types.map((t) => t.name).join(', ')}',
        ),
      )!;

      // Use discriminator from account definition, or compute it for legacy IDLs
      final Uint8List discriminator = acc.discriminator.isNotEmpty
          ? Uint8List.fromList(acc.discriminator)
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
      final result = Uint8List(
        layout.discriminator.length + accountData.length,
      );
      result.setRange(0, layout.discriminator.length, layout.discriminator);
      result.setRange(layout.discriminator.length, result.length, accountData);

      return result;
    } catch (e) {
      throw AccountCoderError('Failed to encode account $accountName: $e');
    }
  }

  @override
  T decode<T>(A accountName, Uint8List data, {PublicKey? accountAddress}) {
    // Assert the account discriminator is correct (matching TypeScript implementation)
    final discriminator = accountDiscriminator(accountName);

    if (data.length < discriminator.length) {
      throw AccountDiscriminatorMismatchError(
        expectedDiscriminator: discriminator.toList(),
        actualDiscriminator: data.toList(),
        accountAddress: accountAddress,
        errorLogs: ['Account data too short for discriminator'],
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
        accountAddress: accountAddress,
        errorLogs: ['Invalid account discriminator'],
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

    return {'offset': 0, 'bytes': base64.encode(bytes)};
  }

  @override
  int size(A accountName) {
    final discriminator = accountDiscriminator(accountName);

    // Find the account definition in IDL
    final account = idl.accounts?.firstWhere(
      (acc) => acc.name == accountName,
      orElse: () => throw AccountCoderError('Account not found: $accountName'),
    );

    if (account == null) {
      throw AccountCoderError('Account not found: $accountName');
    }

    // Use IdlCoder.typeSize for proper struct field size calculation
    final typeSize = IdlCoder.typeSize(
      IdlType(
        kind: 'defined',
        defined: IdlDefinedType(name: accountName),
      ),
      idl,
    );

    return discriminator.length + typeSize;
  }

  @override
  int sizeFromTypeDef(IdlTypeDef idlAccount) {
    // Use actual discriminator length (8 for Anchor, variable for Quasar)
    final disc = accountDiscriminator(idlAccount.name as A);
    final discriminatorSize = disc.length;

    // Use IdlCoder.typeSize for precise type size calculation
    final typeSize = IdlCoder.typeSize(
      IdlType(
        kind: 'defined',
        defined: IdlDefinedType(name: idlAccount.name),
      ),
      idl,
    );

    return discriminatorSize + typeSize;
  }

  @override
  Uint8List accountDiscriminator(A accountName) {
    final account = idl.accounts?.firstWhere(
      (acc) => acc.name == accountName,
      orElse: () => throw AccountCoderError('Account not found: $accountName'),
    );

    if (account != null && account.discriminator.isNotEmpty) {
      return Uint8List.fromList(account.discriminator);
    }

    // Generate discriminator when missing (legacy IDLs without explicit discriminators)
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
    if (account is! Map<String, dynamic>) {
      throw AccountCoderError(
        'Expected Map for account encoding, got ${account.runtimeType}',
      );
    }

    final serializer = BorshSerializer();
    _encodeStruct(serializer, account, typeDef.type, idl.types ?? []);
    buffer.addAll(serializer.toBytes());
  }

  /// Encode a struct type from its field definitions
  void _encodeStruct(
    BorshSerializer serializer,
    Map<String, dynamic> data,
    IdlTypeDefType typeDefType,
    List<IdlTypeDef> types,
  ) {
    final fields = typeDefType.fields;
    if (fields == null) {
      throw AccountCoderError('Struct type missing fields');
    }
    for (final field in fields) {
      _encodeFieldValue(serializer, data[field.name], field.type, types);
    }
  }

  /// Encode a single field value based on its IDL type
  void _encodeFieldValue(
    BorshSerializer serializer,
    dynamic value,
    IdlType idlType,
    List<IdlTypeDef> types,
  ) {
    switch (idlType.kind) {
      case 'bool':
        serializer.writeU8((value as bool) ? 1 : 0);
      case 'u8':
        serializer.writeU8(value as int);
      case 'i8':
        serializer.writeI8(value as int);
      case 'u16':
        serializer.writeU16(value as int);
      case 'i16':
        serializer.writeI16(value as int);
      case 'u32':
        serializer.writeU32(value as int);
      case 'i32':
        serializer.writeI32(value as int);
      case 'u64':
        if (value is BigInt) {
          serializer.writeU64(value);
        } else {
          serializer.writeU64(value as int);
        }
      case 'i64':
        if (value is BigInt) {
          serializer.writeI64(value.toInt());
        } else {
          serializer.writeI64(value as int);
        }
      case 'u128' || 'i128':
        final bigVal = value is BigInt ? value : BigInt.from(value as int);
        final bytes = Uint8List(16);
        for (int i = 0; i < 16; i++) {
          bytes[i] = (bigVal >> (8 * i) & BigInt.from(0xFF)).toInt();
        }
        serializer.writeFixedArray(bytes);
      case 'f32':
        serializer.writeF32(value as double);
      case 'f64':
        serializer.writeF64(value as double);
      case 'string':
        serializer.writeString(value as String);
      case 'pubkey' || 'publicKey':
        if (value is String) {
          final pk = PublicKey.fromBase58(value);
          serializer.writeFixedArray(Uint8List.fromList(pk.bytes));
        } else if (value is Uint8List) {
          serializer.writeFixedArray(value);
        } else if (value is List<int>) {
          serializer.writeFixedArray(Uint8List.fromList(value));
        } else {
          // Ed25519HDPublicKey or similar
          serializer.writeFixedArray(
            Uint8List.fromList((value as PublicKey).bytes),
          );
        }
      case 'bytes':
        final bytesList = value is Uint8List
            ? value
            : Uint8List.fromList(value as List<int>);
        serializer.writeU32(bytesList.length);
        serializer.writeFixedArray(bytesList);
      case 'vec':
        final list = value as List;
        serializer.writeU32(list.length);
        for (final item in list) {
          _encodeFieldValue(serializer, item, idlType.inner!, types);
        }
      case 'option':
        if (value == null) {
          serializer.writeU8(0);
        } else {
          serializer.writeU8(1);
          _encodeFieldValue(serializer, value, idlType.inner!, types);
        }
      case 'array':
        final list = value as List;
        for (final item in list) {
          _encodeFieldValue(serializer, item, idlType.inner!, types);
        }
      case 'defined':
        final definedType = idlType.defined;
        if (definedType == null) {
          throw AccountCoderError('Defined type missing name');
        }
        final typeDef = types.firstWhere(
          (t) => t.name == definedType.name,
          orElse: () =>
              throw AccountCoderError('Type not found: ${definedType.name}'),
        );
        if (typeDef.type.kind == 'struct') {
          _encodeStruct(
            serializer,
            value as Map<String, dynamic>,
            typeDef.type,
            types,
          );
        } else if (typeDef.type.kind == 'enum') {
          _encodeEnum(serializer, value, typeDef.type, types);
        } else {
          throw AccountCoderError(
            'Unsupported defined type kind: ${typeDef.type.kind}',
          );
        }
      default:
        throw AccountCoderError(
          'Unsupported type for account encoding: ${idlType.kind}',
        );
    }
  }

  /// Encode an enum value
  void _encodeEnum(
    BorshSerializer serializer,
    dynamic value,
    IdlTypeDefType typeDefType,
    List<IdlTypeDef> types,
  ) {
    final variants = typeDefType.variants;
    if (variants == null) {
      throw AccountCoderError('Enum type missing variants');
    }
    if (value is Map<String, dynamic> && value.length == 1) {
      final variantName = value.keys.first;
      final variantIndex = variants.indexWhere((v) => v.name == variantName);
      if (variantIndex < 0) {
        throw AccountCoderError('Unknown enum variant: $variantName');
      }
      serializer.writeU8(variantIndex);
      final variant = variants[variantIndex];
      final variantData = value.values.first;
      if (variant.fields != null && variant.fields!.isNotEmpty) {
        // Named fields
        if (variantData is Map<String, dynamic>) {
          for (final field in variant.fields!) {
            _encodeFieldValue(
              serializer,
              variantData[field.name],
              field.type,
              types,
            );
          }
        } else if (variantData is List) {
          for (int i = 0; i < variant.fields!.length; i++) {
            _encodeFieldValue(
              serializer,
              variantData[i],
              variant.fields![i].type,
              types,
            );
          }
        }
      } else if (variant.tupleFields != null &&
          variant.tupleFields!.isNotEmpty) {
        // Tuple fields
        final tuple = variantData is List ? variantData : [variantData];
        for (int i = 0; i < variant.tupleFields!.length; i++) {
          _encodeFieldValue(
            serializer,
            tuple[i],
            variant.tupleFields![i],
            types,
          );
        }
      }
    } else {
      throw AccountCoderError(
        'Enum value must be a Map with exactly one key (the variant name)',
      );
    }
  }

  /// Generic account data decoding using IDL type definition
  void _decodeAccountData(
    Uint8List data,
    IdlTypeDef typeDef,
    Map<String, dynamic> result,
    int offset,
  ) {
    final deserializer = BorshDeserializer(data);
    final decoded = _decodeType(deserializer, typeDef.type, idl.types ?? []);

    if (decoded is Map<String, dynamic>) {
      result.addAll(decoded);
    } else {
      throw AccountDidNotDeserializeError(
        errorLogs: ['Decoded value is not a Map'],
        logs: ['Got: ${decoded.runtimeType}'],
        accountDataSize: data.length,
      );
    }
  }

  /// Generic type decoding based on IDL type definition
  dynamic _decodeType(
    BorshDeserializer deserializer,
    IdlTypeDefType typeDefType,
    List<IdlTypeDef> types,
  ) {
    switch (typeDefType.kind) {
      case 'struct':
        return _decodeStruct(deserializer, typeDefType, types);
      case 'enum':
        return _decodeEnum(deserializer, typeDefType, types);
      default:
        throw AccountCoderError('Unsupported type kind: ${typeDefType.kind}');
    }
  }

  /// Decode a struct type
  Map<String, dynamic> _decodeStruct(
    BorshDeserializer deserializer,
    IdlTypeDefType typeDefType,
    List<IdlTypeDef> types,
  ) {
    final fields = typeDefType.fields;
    if (fields == null) {
      throw AccountCoderError('Struct type missing fields');
    }

    final result = <String, dynamic>{};
    for (final field in fields) {
      result[field.name] = _decodeValue(deserializer, field.type, types);
    }
    return result;
  }

  /// Decode an enum type
  dynamic _decodeEnum(
    BorshDeserializer deserializer,
    IdlTypeDefType typeDefType,
    List<IdlTypeDef> types,
  ) {
    final variants = typeDefType.variants;
    if (variants == null) {
      throw AccountCoderError('Enum type missing variants');
    }

    final discriminator = deserializer.readU8();
    if (discriminator >= variants.length) {
      throw AccountCoderError('Invalid enum discriminator: $discriminator');
    }

    final variant = variants[discriminator];
    if (variant.fields == null || variant.fields!.isEmpty) {
      return {variant.name: null};
    }

    final variantData = <String, dynamic>{};
    for (final field in variant.fields!) {
      variantData[field.name] = _decodeValue(deserializer, field.type, types);
    }
    return {variant.name: variantData};
  }

  /// Decode a single value based on its IDL type
  dynamic _decodeValue(
    BorshDeserializer deserializer,
    IdlType idlType,
    List<IdlTypeDef> types,
  ) {
    switch (idlType.kind) {
      case 'bool':
        return deserializer.readU8() != 0;
      case 'u8':
        return deserializer.readU8();
      case 'u16':
        return deserializer.readU16();
      case 'u32':
        final value = deserializer.readU32();
        return value;
      case 'u64':
        return BigInt.from(deserializer.readU64());
      case 'i8':
        return deserializer.readI8();
      case 'i16':
        return deserializer.readI16();
      case 'i32':
        return deserializer.readI32();
      case 'i64':
        return BigInt.from(deserializer.readI64());
      case 'f32':
        return deserializer.readF32();
      case 'f64':
        return deserializer.readF64();
      case 'string':
        final value = deserializer.readString();
        return value;
      case 'publicKey':
        final bytes = deserializer.readBytes(32);
        return PublicKeyUtils.fromBytes(bytes);
      case 'defined':
        final definedType = idlType.defined;
        if (definedType == null) {
          throw AccountCoderError('Defined type missing name');
        }
        final typeDef = types.firstWhere(
          (t) => t.name == definedType.name,
          orElse: () =>
              throw AccountCoderError('Type not found: ${definedType.name}'),
        );
        return _decodeType(deserializer, typeDef.type, types);
      case 'array':
        return _decodeArray(deserializer, idlType, types);
      case 'vec':
        return _decodeVec(deserializer, idlType, types);
      case 'option':
        return _decodeOption(deserializer, idlType, types);
      default:
        throw AccountCoderError('Unsupported type: ${idlType.kind}');
    }
  }

  /// Decode an array type
  List<dynamic> _decodeArray(
    BorshDeserializer deserializer,
    IdlType idlType,
    List<IdlTypeDef> types,
  ) {
    final elementType = idlType.inner;
    final length = idlType.size;
    if (elementType == null || length == null) {
      throw AccountCoderError('Array type missing element type or length');
    }

    final result = <dynamic>[];
    for (int i = 0; i < length; i++) {
      result.add(_decodeValue(deserializer, elementType, types));
    }
    return result;
  }

  /// Decode a vec type
  List<dynamic> _decodeVec(
    BorshDeserializer deserializer,
    IdlType idlType,
    List<IdlTypeDef> types,
  ) {
    final length = deserializer.readU32();
    final elementType = idlType.inner;
    if (elementType == null) {
      throw AccountCoderError('Vec type missing element type');
    }

    final result = <dynamic>[];
    for (int i = 0; i < length; i++) {
      result.add(_decodeValue(deserializer, elementType, types));
    }
    return result;
  }

  /// Decode an option type
  dynamic _decodeOption(
    BorshDeserializer deserializer,
    IdlType idlType,
    List<IdlTypeDef> types,
  ) {
    final hasValue = deserializer.readU8() != 0;
    if (!hasValue) {
      return null;
    }

    final innerType = idlType.inner;
    if (innerType == null) {
      throw AccountCoderError('Option type missing inner type');
    }
    return _decodeValue(deserializer, innerType, types);
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
        final hasTypeDefinition =
            idl.types?.any((t) => t.name == account.name) ?? false;

        String typeSource;
        if (hasTypeDefinition) {
          typeSource = 'types section';
        } else {
          typeSource = 'MISSING';
        }

        print(
          '  ${account.name}: ${typeSource} (discriminator: ${account.discriminator})',
        );
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
        final hasTypeDefinition =
            idl.types?.any((t) => t.name == account.name) ?? false;

        if (!hasTypeDefinition) {
          issues.add(
            'Account ${account.name} has no type definition in types section',
          );
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
