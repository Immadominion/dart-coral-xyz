/// Instruction coder implementation for Anchor programs
///
/// This module provides the InstructionCoder interface and implementations
/// for encoding and decoding program instructions using Borsh serialization.
library;

import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/coder/borsh_types.dart';
import 'package:coral_xyz/src/coder/discriminator_computer.dart';
import 'package:coral_xyz/src/types/common.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/types/transaction.dart'; // <-- Add this import for AccountMeta
import 'dart:typed_data';

/// Interface for encoding and decoding program instructions
abstract class InstructionCoder {
  /// Encode a program instruction
  ///
  /// [ixName] - The name of the instruction
  /// [ix] - The instruction data to encode
  /// Returns the encoded instruction as a byte buffer
  Uint8List encode(String ixName, Map<String, dynamic> ix);

  /// Decode a program instruction
  ///
  /// [data] - The instruction data to decode
  /// [encoding] - The encoding format ('hex' or 'base58')
  /// Returns the decoded instruction or null if not recognized
  Instruction? decode(Uint8List data, {String encoding = 'hex'});

  /// Format an instruction for display
  ///
  /// [ix] - The instruction to format
  /// [accountMetas] - Account metadata for the instruction
  /// Returns a formatted instruction display or null
  InstructionDisplay? format(Instruction ix, List<AccountMeta> accountMetas);
}

/// A decoded program instruction
class Instruction {
  const Instruction({required this.name, required this.data});

  /// The name of the instruction
  final String name;

  /// The decoded instruction data
  final Map<String, dynamic> data;

  @override
  String toString() => 'Instruction(name: $name, data: $data)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Instruction &&
        other.name == name &&
        _mapEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hash(name, data);

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Formatted instruction display for debugging and analysis
class InstructionDisplay {
  const InstructionDisplay({required this.args, required this.accounts});

  /// Formatted instruction arguments
  final List<InstructionArg> args;

  /// Formatted account information
  final List<InstructionAccount> accounts;

  @override
  String toString() => 'InstructionDisplay(args: $args, accounts: $accounts)';
}

/// Formatted instruction argument
class InstructionArg {
  const InstructionArg({
    required this.name,
    required this.type,
    required this.data,
  });

  /// The name of the argument
  final String name;

  /// The type of the argument
  final String type;

  /// The formatted data
  final String data;

  @override
  String toString() => 'InstructionArg(name: $name, type: $type, data: $data)';
}

/// Formatted instruction account
class InstructionAccount {
  const InstructionAccount({
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
    this.name,
  });

  /// The name of the account (if known)
  final String? name;

  /// The public key of the account
  final String pubkey;

  /// Whether the account is a signer
  final bool isSigner;

  /// Whether the account is writable
  final bool isWritable;

  @override
  String toString() =>
      'InstructionAccount(name: $name, pubkey: $pubkey, '
      'isSigner: $isSigner, isWritable: $isWritable)';
}

/// Borsh-based implementation of InstructionCoder
class BorshInstructionCoder implements InstructionCoder {
  /// Create a new BorshInstructionCoder
  BorshInstructionCoder(this.idl) {
    _ixLayouts = _buildInstructionLayouts();
  }

  /// The IDL containing instruction definitions
  final Idl idl;

  /// Cached instruction layouts with discriminators
  late final Map<String, InstructionLayout> _ixLayouts;

  /// Logger for instruction encoding/decoding operations

  @override
  Uint8List encode(String ixName, Map<String, dynamic> ix) {
    final layout = _ixLayouts[ixName];
    if (layout == null) {
      throw InstructionCoderException('Unknown instruction: $ixName');
    }

    try {
      // Encode the instruction arguments using a basic Borsh serializer
      final serializer = BorshSerializer();
      _encodeInstructionArgs(ix, layout.instruction, serializer);
      final argsData = serializer.toBytes();

      // Prepend the discriminator
      final discriminator = Uint8List.fromList(layout.discriminator);
      final result = Uint8List(discriminator.length + argsData.length);
      result.setRange(0, discriminator.length, discriminator);
      result.setRange(discriminator.length, result.length, argsData);

      return result;
    } catch (e) {
      throw InstructionCoderException(
        'Failed to encode instruction $ixName: $e',
      );
    }
  }

  @override
  Instruction? decode(Uint8List data, {String encoding = 'hex'}) {
    final Uint8List bytes = data;

    // Handle hex encoding
    if (encoding == 'hex' && data.isEmpty) {
      return null;
    }

    // Try to match discriminator and decode
    for (final entry in _ixLayouts.entries) {
      final name = entry.key;
      final layout = entry.value;

      if (bytes.length < layout.discriminator.length) continue;

      // Check discriminator match
      bool matches = true;
      for (int i = 0; i < layout.discriminator.length; i++) {
        if (bytes[i] != layout.discriminator[i]) {
          matches = false;
          break;
        }
      }

      if (matches) {
        try {
          // Extract instruction data (after discriminator)
          final instructionData = bytes.sublist(layout.discriminator.length);

          // Decode using Borsh deserializer
          final deserializer = BorshDeserializer(instructionData);
          final decodedData = _decodeInstructionArgs(
            layout.instruction,
            deserializer,
          );

          return Instruction(name: name, data: decodedData);
        } catch (e) {
          // Continue trying other instructions
          continue;
        }
      }
    }

    return null;
  }

  @override
  InstructionDisplay? format(Instruction ix, List<AccountMeta> accountMetas) {
    final instruction = idl.instructions.firstWhere(
      (instr) => instr.name == ix.name,
      orElse: () =>
          throw InstructionCoderException('Unknown instruction: ${ix.name}'),
    );

    // Format arguments
    final args = <InstructionArg>[];
    for (final arg in instruction.args) {
      final value = ix.data[arg.name];
      args.add(
        InstructionArg(
          name: arg.name,
          type: _formatIdlType(arg.type),
          data: _formatValue(value, arg.type),
        ),
      );
    }

    // Format accounts
    final accounts = <InstructionAccount>[];
    for (int i = 0; i < accountMetas.length; i++) {
      final meta = accountMetas[i];
      String? name;

      // Try to match account name from IDL
      if (i < instruction.accounts.length) {
        final account = instruction.accounts[i];
        name = account.name;
      }

      accounts.add(
        InstructionAccount(
          name: name,
          pubkey: meta.pubkey.toBase58(),
          isSigner: meta.isSigner,
          isWritable: meta.isWritable,
        ),
      );
    }

    return InstructionDisplay(args: args, accounts: accounts);
  }

  /// Build instruction layouts from IDL
  Map<String, InstructionLayout> _buildInstructionLayouts() {
    final layouts = <String, InstructionLayout>{};

    for (final instruction in idl.instructions) {
      List<int> discriminator;

      if (instruction.discriminator != null &&
          instruction.discriminator!.isNotEmpty) {
        discriminator = instruction.discriminator!;
      } else {
        // Compute discriminator from instruction name (Anchor convention)
        discriminator = _computeDiscriminator(instruction.name);
      }

      layouts[instruction.name] = InstructionLayout(
        discriminator: discriminator,
        instruction: instruction,
      );
    }

    return layouts;
  }

  /// Compute discriminator for an instruction name using Anchor convention
  /// The discriminator is the first 8 bytes of SHA256("global:<instruction_name>")
  /// Note: Must use the original snake_case function name, not the camelCase IDL name
  List<int> _computeDiscriminator(String instructionName) {
    // Convert camelCase back to snake_case for discriminator computation
    // since Anchor computes discriminators from original Rust function names
    final snakeCaseName = _toSnakeCase(instructionName);
    final discriminator = DiscriminatorComputer.computeInstructionDiscriminator(
      snakeCaseName,
    );
    return discriminator.toList();
  }

  /// Convert camelCase to snake_case
  /// This is needed to convert IDL instruction names back to original Rust function names
  /// for correct discriminator computation
  String _toSnakeCase(String camelCase) {
    if (camelCase.isEmpty) return camelCase;

    // Handle transitions between lowercase→uppercase and uppercase→lowercase
    // e.g. "parseIDLField" → "parse_idl_field", "myMethod" → "my_method"
    return camelCase
        .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'),
          (m) => '${m.group(1)!.toLowerCase()}_${m.group(2)!.toLowerCase()}',
        )
        .replaceAllMapped(
          RegExp(r'([a-z\d])([A-Z])'),
          (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
        )
        .toLowerCase();
  }

  /// Encode instruction arguments
  void _encodeInstructionArgs(
    Map<String, dynamic> data,
    IdlInstruction instruction,
    BorshSerializer serializer,
  ) {
    for (final arg in instruction.args) {
      if (!data.containsKey(arg.name)) {
        throw InstructionCoderException(
          'Missing required argument: ${arg.name}',
        );
      }
      final value = data[arg.name];
      _encodeValue(value, arg.type, serializer);
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
        // Accept int or BigInt for u64
        if (value is BigInt) {
          serializer.writeU64(value);
        } else if (value is int) {
          serializer.writeU64(value);
        } else {
          throw InstructionCoderException(
            'Invalid u64 value type: ${value.runtimeType}',
          );
        }
        break;
      case 'i64':
        // Accept int or BigInt for i64
        if (value is BigInt) {
          serializer.writeI64(value.toInt());
        } else if (value is int) {
          serializer.writeI64(value);
        } else {
          throw InstructionCoderException(
            'Invalid i64 value type: ${value.runtimeType}',
          );
        }
        break;
      case 'u128':
        final u128Bytes = Uint8List(16);
        final u128Val = value is BigInt ? value : BigInt.from(value as int);
        for (int i = 0; i < 16; i++) {
          u128Bytes[i] = (u128Val >> (8 * i) & BigInt.from(0xFF)).toInt();
        }
        serializer.writeFixedArray(u128Bytes);
        break;
      case 'i128':
        final i128Bytes = Uint8List(16);
        final i128Val = value is BigInt ? value : BigInt.from(value as int);
        for (int i = 0; i < 16; i++) {
          i128Bytes[i] = (i128Val >> (8 * i) & BigInt.from(0xFF)).toInt();
        }
        serializer.writeFixedArray(i128Bytes);
        break;
      case 'f32':
        serializer.writeF32(value as double);
        break;
      case 'f64':
        serializer.writeF64(value as double);
        break;
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'bytes':
        // Length-prefixed byte array
        final bytesList = value is Uint8List
            ? value
            : Uint8List.fromList(value as List<int>);
        serializer.writeU32(bytesList.length);
        serializer.writeFixedArray(bytesList);
        break;
      case 'pubkey':
      case 'publicKey':
        // Encode as 32-byte public key
        if (value is String) {
          // Accept base58-encoded public key string
          final pk = PublicKey.fromBase58(value);
          serializer.writeFixedArray(Uint8List.fromList(pk.bytes));
        } else if (value is Uint8List) {
          if (value.length != 32) {
            throw InstructionCoderException(
              'Public key must be exactly 32 bytes, got ${value.length}',
            );
          }
          serializer.writeFixedArray(value);
        } else if (value is List<int>) {
          if (value.length != 32) {
            throw InstructionCoderException(
              'Public key must be exactly 32 bytes, got ${value.length}',
            );
          }
          serializer.writeFixedArray(Uint8List.fromList(value));
        } else {
          throw InstructionCoderException(
            'Public key must be a base58 String, Uint8List, or List<int>, got ${value.runtimeType}',
          );
        }
        break;
      case 'dynString':
        // Quasar bounded string: 4-byte length prefix + UTF-8 bytes
        serializer.writeString(value as String);
        break;
      case 'dynVec':
        // Quasar bounded vec: 4-byte length prefix + items
        final dynVecList = value as List;
        serializer.writeU32(dynVecList.length);
        for (final item in dynVecList) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      case 'tail':
        // Quasar tail bytes: raw bytes appended at end (no length prefix)
        if (value is Uint8List) {
          for (final b in value) {
            serializer.writeU8(b);
          }
        } else if (value is List<int>) {
          for (final b in value) {
            serializer.writeU8(b);
          }
        } else {
          throw InstructionCoderException(
            'Tail value must be Uint8List or List<int>, got ${value.runtimeType}',
          );
        }
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
          throw InstructionCoderException(
            'Array length mismatch: expected ${type.size}, got ${list.length}',
          );
        }
        for (final item in list) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      case 'defined':
        _encodeDefinedType(value, type.defined!.name, serializer);
        break;
      default:
        throw InstructionCoderException(
          'Unsupported type for encoding: ${type.kind}',
        );
    }
  }

  /// Decode instruction arguments
  Map<String, dynamic> _decodeInstructionArgs(
    IdlInstruction instruction,
    BorshDeserializer deserializer,
  ) {
    final data = <String, dynamic>{};

    for (final arg in instruction.args) {
      data[arg.name] = _decodeValue(arg.type, deserializer);
    }

    return data;
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
      case 'u128':
      case 'i128':
        final u128Bytes = deserializer.readFixedArray(16);
        BigInt result = BigInt.zero;
        for (int i = 0; i < 16; i++) {
          result |= BigInt.from(u128Bytes[i]) << (8 * i);
        }
        return result;
      case 'f32':
        return deserializer.readF32();
      case 'f64':
        return deserializer.readF64();
      case 'string':
        return deserializer.readString();
      case 'bytes':
        final bytesLen = deserializer.readU32();
        return deserializer.readBytes(bytesLen);
      case 'pubkey':
      case 'publicKey':
        return deserializer.readBytes(32);
      case 'dynString':
        // Quasar bounded string: same wire format as string
        return deserializer.readString();
      case 'dynVec':
        // Quasar bounded vec: same wire format as vec
        final dynVecLen = deserializer.readU32();
        final dynVecList = <dynamic>[];
        for (int i = 0; i < dynVecLen; i++) {
          dynVecList.add(_decodeValue(type.inner!, deserializer));
        }
        return dynVecList;
      case 'tail':
        // Quasar tail: consume remaining bytes
        final remaining = <int>[];
        try {
          while (true) {
            remaining.add(deserializer.readU8());
          }
        } catch (_) {
          // End of data reached
        }
        return Uint8List.fromList(remaining);
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
        return _decodeDefinedType(type.defined!.name, deserializer);
      default:
        throw InstructionCoderException(
          'Unsupported type for decoding: ${type.kind}',
        );
    }
  }

  /// Format IDL type for display
  String _formatIdlType(IdlType type) {
    switch (type.kind) {
      case 'vec':
        return 'Vec<${_formatIdlType(type.inner!)}>';
      case 'option':
        return 'Option<${_formatIdlType(type.inner!)}>';
      case 'array':
        return 'Array<${_formatIdlType(type.inner!)}; ${type.size}>';
      case 'defined':
        return type.defined?.name ?? 'Unknown';
      case 'dynString':
        return 'DynString<${type.size}>';
      case 'dynVec':
        return 'DynVec<${_formatIdlType(type.inner!)}, ${type.size}>';
      case 'tail':
        return 'Tail<${_formatIdlType(type.inner!)}>';
      default:
        return type.kind;
    }
  }

  /// Format a value for display
  String _formatValue(dynamic value, IdlType type) {
    if (value == null) {
      return 'null';
    }

    if (value is String || value is num || value is bool) {
      return value.toString();
    }

    if (value is List) {
      return '[${value.map((v) => _formatValue(v, type.inner ?? const IdlType(kind: 'unknown'))).join(', ')}]';
    }

    if (value is Map) {
      final entries = value.entries
          .map(
            (e) =>
                '${e.key}: ${_formatValue(e.value, const IdlType(kind: 'unknown'))}',
          )
          .join(', ');
      return '{$entries}';
    }

    return value.toString();
  }

  /// Resolve and find a type definition
  IdlTypeDef _findTypeDef(String typeName) {
    final typeDef = idl.types?.firstWhere(
      (t) => t.name == typeName,
      orElse: () => throw InstructionCoderException(
        'Type definition not found: $typeName',
      ),
    );
    if (typeDef == null) {
      throw InstructionCoderException('Type definition not found: $typeName');
    }
    return typeDef;
  }

  /// Encode a defined (named) type
  void _encodeDefinedType(
    dynamic value,
    String typeName,
    BorshSerializer serializer,
  ) {
    final typeDef = _findTypeDef(typeName);

    switch (typeDef.type.kind) {
      case 'type':
        // Type alias — delegate to the aliased type
        if (typeDef.type.alias == null) {
          throw InstructionCoderException(
            'Type alias missing alias field: $typeName',
          );
        }
        _encodeValue(value, typeDef.type.alias!, serializer);
      case 'struct':
        final fields = typeDef.type.fields;
        if (fields == null) {
          throw InstructionCoderException(
            'Struct type missing fields: $typeName',
          );
        }
        final map = value as Map<String, dynamic>;
        for (final field in fields) {
          _encodeValue(map[field.name], field.type, serializer);
        }
      case 'enum':
        final variants = typeDef.type.variants;
        if (variants == null) {
          throw InstructionCoderException(
            'Enum type missing variants: $typeName',
          );
        }
        if (value is! Map<String, dynamic> || value.length != 1) {
          throw InstructionCoderException(
            'Enum value must be a Map with one key (the variant name), '
            'got ${value.runtimeType}',
          );
        }
        final variantName = value.keys.first;
        final variantIndex = variants.indexWhere((v) => v.name == variantName);
        if (variantIndex < 0) {
          throw InstructionCoderException(
            'Unknown enum variant: $variantName in $typeName',
          );
        }
        serializer.writeU8(variantIndex);
        final variant = variants[variantIndex];
        final variantData = value.values.first;
        if (variant.fields != null && variant.fields!.isNotEmpty) {
          // Named fields
          if (variantData is Map<String, dynamic>) {
            for (final field in variant.fields!) {
              _encodeValue(variantData[field.name], field.type, serializer);
            }
          } else if (variantData is List) {
            for (int i = 0; i < variant.fields!.length; i++) {
              _encodeValue(variantData[i], variant.fields![i].type, serializer);
            }
          }
        } else if (variant.tupleFields != null &&
            variant.tupleFields!.isNotEmpty) {
          // Tuple fields
          final tuple = variantData is List ? variantData : [variantData];
          for (int i = 0; i < variant.tupleFields!.length; i++) {
            _encodeValue(tuple[i], variant.tupleFields![i], serializer);
          }
        }
      // No fields = unit variant, nothing more to encode
      default:
        throw InstructionCoderException(
          'Unknown type definition kind: ${typeDef.type.kind}',
        );
    }
  }

  /// Decode a defined (named) type
  dynamic _decodeDefinedType(String typeName, BorshDeserializer deserializer) {
    final typeDef = _findTypeDef(typeName);

    switch (typeDef.type.kind) {
      case 'type':
        if (typeDef.type.alias == null) {
          throw InstructionCoderException(
            'Type alias missing alias field: $typeName',
          );
        }
        return _decodeValue(typeDef.type.alias!, deserializer);
      case 'struct':
        final fields = typeDef.type.fields;
        if (fields == null) {
          throw InstructionCoderException(
            'Struct type missing fields: $typeName',
          );
        }
        final result = <String, dynamic>{};
        for (final field in fields) {
          result[field.name] = _decodeValue(field.type, deserializer);
        }
        return result;
      case 'enum':
        final variants = typeDef.type.variants;
        if (variants == null) {
          throw InstructionCoderException(
            'Enum type missing variants: $typeName',
          );
        }
        final variantIndex = deserializer.readU8();
        if (variantIndex >= variants.length) {
          throw InstructionCoderException(
            'Enum variant index out of range: $variantIndex for $typeName',
          );
        }
        final variant = variants[variantIndex];
        if (variant.fields != null && variant.fields!.isNotEmpty) {
          // Named fields
          final data = <String, dynamic>{};
          for (final field in variant.fields!) {
            data[field.name] = _decodeValue(field.type, deserializer);
          }
          return {variant.name: data};
        } else if (variant.tupleFields != null &&
            variant.tupleFields!.isNotEmpty) {
          // Tuple fields
          final data = <dynamic>[];
          for (final tupleType in variant.tupleFields!) {
            data.add(_decodeValue(tupleType, deserializer));
          }
          return {variant.name: data};
        }
        // Unit variant
        return {variant.name: {}};
      default:
        throw InstructionCoderException(
          'Unknown type definition kind: ${typeDef.type.kind}',
        );
    }
  }
}

/// Internal instruction layout information
class InstructionLayout {
  const InstructionLayout({
    required this.discriminator,
    required this.instruction,
  });

  /// The instruction discriminator bytes
  final List<int> discriminator;

  /// The IDL instruction definition
  final IdlInstruction instruction;
}

/// Exception thrown by instruction coder operations
class InstructionCoderException extends AnchorException {
  const InstructionCoderException(super.message, [super.cause]);
}
