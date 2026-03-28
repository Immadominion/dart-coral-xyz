/// Zero-Copy Account Coder for Quasar Programs
///
/// Quasar accounts use `#[repr(C)]` memory layout with alignment 1 — fields
/// are packed sequentially with no padding. This coder reads them directly
/// from the byte buffer at computed offsets, matching the on-chain pointer-cast
/// pattern used by the Quasar runtime.
///
/// Wire layout:
///   [discriminator (N bytes)] [field₁] [field₂] … [fieldₙ]
///
/// Dynamic types (`DynString`, `DynVec`) use a 4-byte LE length prefix
/// followed by the content, identical to Borsh encoding. `Tail` consumes
/// all remaining bytes without a length prefix.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../error/account_errors.dart';
import '../idl/idl.dart';
import '../types/public_key.dart';
import 'borsh_accounts_coder.dart';

/// Zero-copy accounts coder for Quasar `#[repr(C)]` accounts.
///
/// Implements the same [AccountsCoder] interface as [BorshAccountsCoder]
/// so the two can be swapped transparently via a factory.
class ZeroCopyAccountsCoder<A extends String> implements AccountsCoder<A> {
  ZeroCopyAccountsCoder(this.idl) {
    _buildLayouts();
  }

  final Idl idl;

  late final Map<A, AccountLayout> _layouts;

  // ---------------------------------------------------------------------------
  // Layout building
  // ---------------------------------------------------------------------------

  void _buildLayouts() {
    final accounts = idl.accounts;
    if (accounts == null || accounts.isEmpty) {
      _layouts = {};
      return;
    }

    final types = idl.types ?? [];
    final layouts = <A, AccountLayout>{};

    for (final acc in accounts) {
      final typeDef = types.cast<IdlTypeDef?>().firstWhere(
        (t) => t?.name == acc.name,
        orElse: () => throw AccountCoderError(
          'Account type definition not found for ${acc.name}',
        ),
      )!;

      layouts[acc.name as A] = AccountLayout(
        discriminator: Uint8List.fromList(acc.discriminator),
        typeDef: typeDef,
      );
    }

    _layouts = layouts;
  }

  // ---------------------------------------------------------------------------
  // AccountsCoder interface
  // ---------------------------------------------------------------------------

  @override
  Future<Uint8List> encode<T>(A accountName, T account) async {
    final layout = _requireLayout(accountName);

    if (account is! Map<String, dynamic>) {
      throw AccountCoderError(
        'Expected Map<String, dynamic> for encoding, '
        'got ${account.runtimeType}',
      );
    }

    final types = idl.types ?? [];
    final buffer = <int>[...layout.discriminator];
    _encodeStruct(account, layout.typeDef.type, types, buffer);
    return Uint8List.fromList(buffer);
  }

  @override
  T decode<T>(A accountName, Uint8List data, {PublicKey? accountAddress}) {
    final disc = accountDiscriminator(accountName);
    if (data.length < disc.length) {
      throw AccountDiscriminatorMismatchError(
        expectedDiscriminator: disc.toList(),
        actualDiscriminator: data.toList(),
        accountAddress: accountAddress,
        errorLogs: ['Account data too short for discriminator'],
        logs: ['Data length: ${data.length}, Required: ${disc.length}'],
      );
    }

    for (int i = 0; i < disc.length; i++) {
      if (data[i] != disc[i]) {
        throw AccountDiscriminatorMismatchError(
          expectedDiscriminator: disc.toList(),
          actualDiscriminator: data.sublist(0, disc.length).toList(),
          accountAddress: accountAddress,
          errorLogs: ['Invalid account discriminator'],
          logs: ['Mismatch at byte $i'],
        );
      }
    }

    return decodeUnchecked(accountName, data);
  }

  @override
  T decodeUnchecked<T>(A accountName, Uint8List data) {
    final layout = _requireLayout(accountName);
    final discLen = layout.discriminator.length;
    final body = ByteData.sublistView(data, discLen);

    final types = idl.types ?? [];
    final (result, _) = _readStruct(body, 0, layout.typeDef.type, types);
    return result as T;
  }

  @override
  T decodeAny<T>(Uint8List data) {
    for (final entry in _layouts.entries) {
      final disc = entry.value.discriminator;
      if (data.length < disc.length) continue;

      bool match = true;
      for (int i = 0; i < disc.length; i++) {
        if (data[i] != disc[i]) {
          match = false;
          break;
        }
      }
      if (match) return decodeUnchecked(entry.key, data);
    }

    throw AccountCoderError('No matching account discriminator found');
  }

  @override
  Map<String, dynamic> memcmp(A accountName, {Uint8List? appendData}) {
    final disc = accountDiscriminator(accountName);
    final bytes = appendData != null
        ? Uint8List.fromList([...disc, ...appendData])
        : disc;
    return {'offset': 0, 'bytes': base64.encode(bytes)};
  }

  @override
  int size(A accountName) {
    final layout = _requireLayout(accountName);
    final types = idl.types ?? [];
    return layout.discriminator.length +
        _structSize(layout.typeDef.type, types);
  }

  @override
  int sizeFromTypeDef(IdlTypeDef idlAccount) {
    final disc = idl.accounts
        ?.firstWhere((a) => a.name == idlAccount.name)
        .discriminator;
    final types = idl.types ?? [];
    return (disc?.length ?? 1) + _structSize(idlAccount.type, types);
  }

  @override
  Uint8List accountDiscriminator(A accountName) =>
      _requireLayout(accountName).discriminator;

  // ---------------------------------------------------------------------------
  // Reading values from raw bytes (zero-copy decode)
  // ---------------------------------------------------------------------------

  /// Returns (value, bytesConsumed).
  (dynamic, int) _readValue(
    ByteData data,
    int offset,
    IdlType type,
    List<IdlTypeDef> types,
  ) {
    switch (type.kind) {
      case 'bool':
        return (data.getUint8(offset) != 0, 1);
      case 'u8':
        return (data.getUint8(offset), 1);
      case 'i8':
        return (data.getInt8(offset), 1);
      case 'u16':
        return (data.getUint16(offset, Endian.little), 2);
      case 'i16':
        return (data.getInt16(offset, Endian.little), 2);
      case 'u32':
        return (data.getUint32(offset, Endian.little), 4);
      case 'i32':
        return (data.getInt32(offset, Endian.little), 4);
      case 'f32':
        return (data.getFloat32(offset, Endian.little), 4);
      case 'u64':
        return (BigInt.from(data.getUint64(offset, Endian.little)), 8);
      case 'i64':
        return (BigInt.from(data.getInt64(offset, Endian.little)), 8);
      case 'f64':
        return (data.getFloat64(offset, Endian.little), 8);
      case 'u128':
        final lo = BigInt.from(
          data.getUint64(offset, Endian.little),
        ).toUnsigned(64);
        final hi = BigInt.from(
          data.getUint64(offset + 8, Endian.little),
        ).toUnsigned(64);
        return ((hi << 64) | lo, 16);
      case 'i128':
        final lo = BigInt.from(
          data.getUint64(offset, Endian.little),
        ).toUnsigned(64);
        final hi = BigInt.from(data.getInt64(offset + 8, Endian.little));
        return ((hi << 64) | lo, 16);

      case 'publicKey':
      case 'pubkey':
        final bytes = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          bytes[i] = data.getUint8(offset + i);
        }
        return (bytes, 32);

      case 'string':
      case 'dynString':
        // 4-byte LE length prefix + UTF-8 bytes
        final len = data.getUint32(offset, Endian.little);
        final strBytes = Uint8List(len);
        for (int i = 0; i < len; i++) {
          strBytes[i] = data.getUint8(offset + 4 + i);
        }
        return (utf8.decode(strBytes), 4 + len);

      case 'vec':
      case 'dynVec':
        // 4-byte LE length prefix + elements
        final count = data.getUint32(offset, Endian.little);
        var pos = offset + 4;
        final list = <dynamic>[];
        for (int i = 0; i < count; i++) {
          final (val, consumed) = _readValue(data, pos, type.inner!, types);
          list.add(val);
          pos += consumed;
        }
        return (list, pos - offset);

      case 'option':
        final tag = data.getUint8(offset);
        if (tag == 0) return (null, 1);
        final (val, consumed) = _readValue(
          data,
          offset + 1,
          type.inner!,
          types,
        );
        return (val, 1 + consumed);

      case 'coption':
        // COption uses 4-byte tag
        final tag = data.getUint32(offset, Endian.little);
        if (tag == 0) {
          final innerSize = _typeSize(type.inner!, types);
          return (null, 4 + innerSize);
        }
        final (val, consumed) = _readValue(
          data,
          offset + 4,
          type.inner!,
          types,
        );
        return (val, 4 + consumed);

      case 'array':
        final count = type.size ?? 0;
        var pos = offset;
        final list = <dynamic>[];
        for (int i = 0; i < count; i++) {
          final (val, consumed) = _readValue(data, pos, type.inner!, types);
          list.add(val);
          pos += consumed;
        }
        return (list, pos - offset);

      case 'tail':
        // Consume all remaining bytes
        final remaining = data.lengthInBytes - offset;
        final bytes = Uint8List(remaining);
        for (int i = 0; i < remaining; i++) {
          bytes[i] = data.getUint8(offset + i);
        }
        return (bytes, remaining);

      case 'defined':
        final typeName = type.defined?.name;
        if (typeName == null) {
          throw AccountCoderError('Defined type missing name');
        }
        final typeDef = types.firstWhere(
          (t) => t.name == typeName,
          orElse: () => throw AccountCoderError('Type not found: $typeName'),
        );
        return _readDefinedType(data, offset, typeDef, types);

      default:
        throw AccountCoderError(
          'ZeroCopy: unsupported type kind "${type.kind}"',
        );
    }
  }

  /// Read a struct type, returning (Map, bytesConsumed).
  (Map<String, dynamic>, int) _readStruct(
    ByteData data,
    int offset,
    IdlTypeDefType typeDef,
    List<IdlTypeDef> types,
  ) {
    final fields = typeDef.fields;
    if (fields == null) {
      throw AccountCoderError('Struct missing fields');
    }

    final result = <String, dynamic>{};
    var pos = offset;
    for (final field in fields) {
      final (val, consumed) = _readValue(data, pos, field.type, types);
      result[field.name] = val;
      pos += consumed;
    }
    return (result, pos - offset);
  }

  /// Read a defined type (struct or enum).
  (dynamic, int) _readDefinedType(
    ByteData data,
    int offset,
    IdlTypeDef typeDef,
    List<IdlTypeDef> types,
  ) {
    switch (typeDef.type.kind) {
      case 'struct':
        return _readStruct(data, offset, typeDef.type, types);
      case 'enum':
        return _readEnum(data, offset, typeDef.type, types);
      default:
        throw AccountCoderError(
          'Unsupported defined type kind: ${typeDef.type.kind}',
        );
    }
  }

  /// Read a Borsh/repr(C) enum: 1-byte variant discriminator + fields.
  (dynamic, int) _readEnum(
    ByteData data,
    int offset,
    IdlTypeDefType typeDef,
    List<IdlTypeDef> types,
  ) {
    final variants = typeDef.variants;
    if (variants == null) {
      throw AccountCoderError('Enum type missing variants');
    }

    final variantIdx = data.getUint8(offset);
    if (variantIdx >= variants.length) {
      throw AccountCoderError('Invalid enum variant index: $variantIdx');
    }

    final variant = variants[variantIdx];
    if (variant.fields == null || variant.fields!.isEmpty) {
      return ({variant.name: null}, 1);
    }

    final variantData = <String, dynamic>{};
    var pos = offset + 1;
    for (final field in variant.fields!) {
      final (val, consumed) = _readValue(data, pos, field.type, types);
      variantData[field.name] = val;
      pos += consumed;
    }
    return ({variant.name: variantData}, pos - offset);
  }

  // ---------------------------------------------------------------------------
  // Writing values (zero-copy encode)
  // ---------------------------------------------------------------------------

  void _encodeStruct(
    Map<String, dynamic> values,
    IdlTypeDefType typeDef,
    List<IdlTypeDef> types,
    List<int> buffer,
  ) {
    final fields = typeDef.fields;
    if (fields == null) {
      throw AccountCoderError('Struct missing fields for encoding');
    }

    for (final field in fields) {
      _writeValue(values[field.name], field.type, types, buffer);
    }
  }

  void _writeValue(
    dynamic value,
    IdlType type,
    List<IdlTypeDef> types,
    List<int> buffer,
  ) {
    switch (type.kind) {
      case 'bool':
        buffer.add((value as bool) ? 1 : 0);
      case 'u8':
        buffer.add((value as int) & 0xFF);
      case 'i8':
        final v = value as int;
        buffer.add(v < 0 ? v + 256 : v);
      case 'u16':
        _writeU16LE(value as int, buffer);
      case 'i16':
        _writeU16LE(value as int, buffer);
      case 'u32':
        _writeU32LE(value as int, buffer);
      case 'i32':
        _writeU32LE(value as int, buffer);
      case 'f32':
        final bd = ByteData(4)
          ..setFloat32(0, (value as num).toDouble(), Endian.little);
        buffer.addAll(bd.buffer.asUint8List());
      case 'u64':
        final v = value is BigInt ? value.toInt() : value as int;
        _writeU64LE(v, buffer);
      case 'i64':
        final v = value is BigInt ? value.toInt() : value as int;
        _writeU64LE(v, buffer);
      case 'f64':
        final bd = ByteData(8)
          ..setFloat64(0, (value as num).toDouble(), Endian.little);
        buffer.addAll(bd.buffer.asUint8List());
      case 'u128' || 'i128':
        final v = value is BigInt ? value : BigInt.from(value as int);
        final u64Mask = (BigInt.one << 64) - BigInt.one;
        _writeU64LE((v & u64Mask).toSigned(64).toInt(), buffer);
        _writeU64LE(((v >> 64) & u64Mask).toSigned(64).toInt(), buffer);

      case 'publicKey' || 'pubkey':
        if (value is Uint8List) {
          buffer.addAll(value);
        } else if (value is List<int>) {
          buffer.addAll(value);
        } else {
          throw AccountCoderError(
            'publicKey must be Uint8List or List<int>, got ${value.runtimeType}',
          );
        }

      case 'string' || 'dynString':
        final bytes = utf8.encode(value as String);
        _writeU32LE(bytes.length, buffer);
        buffer.addAll(bytes);

      case 'vec' || 'dynVec':
        final list = value as List;
        _writeU32LE(list.length, buffer);
        for (final item in list) {
          _writeValue(item, type.inner!, types, buffer);
        }

      case 'option':
        if (value == null) {
          buffer.add(0);
        } else {
          buffer.add(1);
          _writeValue(value, type.inner!, types, buffer);
        }

      case 'coption':
        if (value == null) {
          _writeU32LE(0, buffer);
          // Pad with zeros for the inner type size
          final innerSize = _typeSize(type.inner!, types);
          buffer.addAll(List.filled(innerSize, 0));
        } else {
          _writeU32LE(1, buffer);
          _writeValue(value, type.inner!, types, buffer);
        }

      case 'array':
        final list = value as List;
        for (final item in list) {
          _writeValue(item, type.inner!, types, buffer);
        }

      case 'tail':
        if (value is List<int>) {
          buffer.addAll(value);
        } else {
          throw AccountCoderError(
            'tail must be List<int>, got ${value.runtimeType}',
          );
        }

      case 'defined':
        final typeName = type.defined?.name;
        if (typeName == null) {
          throw AccountCoderError('Defined type missing name');
        }
        final typeDef = types.firstWhere(
          (t) => t.name == typeName,
          orElse: () => throw AccountCoderError('Type not found: $typeName'),
        );
        _writeDefinedType(value, typeDef, types, buffer);

      default:
        throw AccountCoderError(
          'ZeroCopy: unsupported type for encoding "${type.kind}"',
        );
    }
  }

  void _writeDefinedType(
    dynamic value,
    IdlTypeDef typeDef,
    List<IdlTypeDef> types,
    List<int> buffer,
  ) {
    switch (typeDef.type.kind) {
      case 'struct':
        if (value is! Map<String, dynamic>) {
          throw AccountCoderError(
            'Expected Map for struct ${typeDef.name}, got ${value.runtimeType}',
          );
        }
        _encodeStruct(value, typeDef.type, types, buffer);
      case 'enum':
        _writeEnum(value, typeDef.type, types, buffer);
      default:
        throw AccountCoderError(
          'Unsupported defined type kind: ${typeDef.type.kind}',
        );
    }
  }

  void _writeEnum(
    dynamic value,
    IdlTypeDefType typeDef,
    List<IdlTypeDef> types,
    List<int> buffer,
  ) {
    final variants = typeDef.variants;
    if (variants == null) {
      throw AccountCoderError('Enum type missing variants');
    }

    if (value is! Map<String, dynamic> || value.length != 1) {
      throw AccountCoderError(
        'Enum value must be a single-entry Map, got $value',
      );
    }

    final variantName = value.keys.first;
    final variantIdx = variants.indexWhere((v) => v.name == variantName);
    if (variantIdx < 0) {
      throw AccountCoderError('Unknown enum variant: $variantName');
    }

    buffer.add(variantIdx);

    final variant = variants[variantIdx];
    final variantData = value[variantName];
    if (variant.fields != null && variant.fields!.isNotEmpty) {
      if (variantData is! Map<String, dynamic>) {
        throw AccountCoderError(
          'Enum variant $variantName fields must be a Map',
        );
      }
      for (final field in variant.fields!) {
        _writeValue(variantData[field.name], field.type, types, buffer);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Size calculation (alignment 1, no padding)
  // ---------------------------------------------------------------------------

  int _typeSize(IdlType type, List<IdlTypeDef> types) {
    switch (type.kind) {
      case 'bool' || 'u8' || 'i8':
        return 1;
      case 'u16' || 'i16':
        return 2;
      case 'u32' || 'i32' || 'f32':
        return 4;
      case 'u64' || 'i64' || 'f64':
        return 8;
      case 'u128' || 'i128':
        return 16;
      case 'publicKey' || 'pubkey':
        return 32;
      case 'option':
        return 1 + _typeSize(type.inner!, types);
      case 'coption':
        return 4 + _typeSize(type.inner!, types);
      case 'array':
        return _typeSize(type.inner!, types) * (type.size ?? 0);
      case 'defined':
        final name = type.defined?.name;
        if (name == null) return 0;
        final td = types.cast<IdlTypeDef?>().firstWhere(
          (t) => t?.name == name,
          orElse: () => null,
        );
        if (td == null) return 0;
        return _structSize(td.type, types);
      // Dynamic types — return minimum size (length prefix only)
      case 'string' || 'dynString':
        return 4;
      case 'vec' || 'dynVec':
        return 4;
      case 'tail':
        return 0;
      default:
        return 0;
    }
  }

  int _structSize(IdlTypeDefType typeDef, List<IdlTypeDef> types) {
    switch (typeDef.kind) {
      case 'struct':
        final fields = typeDef.fields ?? [];
        int total = 0;
        for (final f in fields) {
          total += _typeSize(f.type, types);
        }
        return total;
      case 'enum':
        final variants = typeDef.variants ?? [];
        int maxSize = 0;
        for (final v in variants) {
          int vSize = 0;
          if (v.fields != null) {
            for (final f in v.fields!) {
              vSize += _typeSize(f.type, types);
            }
          }
          if (vSize > maxSize) maxSize = vSize;
        }
        return 1 + maxSize; // 1-byte variant tag + largest variant
      default:
        return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // LE write helpers
  // ---------------------------------------------------------------------------

  static void _writeU16LE(int v, List<int> buf) {
    buf.add(v & 0xFF);
    buf.add((v >> 8) & 0xFF);
  }

  static void _writeU32LE(int v, List<int> buf) {
    buf.add(v & 0xFF);
    buf.add((v >> 8) & 0xFF);
    buf.add((v >> 16) & 0xFF);
    buf.add((v >> 24) & 0xFF);
  }

  static void _writeU64LE(int v, List<int> buf) {
    for (int i = 0; i < 8; i++) {
      buf.add((v >> (i * 8)) & 0xFF);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AccountLayout _requireLayout(A accountName) {
    final layout = _layouts[accountName];
    if (layout == null) {
      throw AccountCoderError('Unknown account: $accountName');
    }
    return layout;
  }
}
