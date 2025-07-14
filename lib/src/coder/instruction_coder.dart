/// Instruction coder implementation for Anchor programs
///
/// This module provides the InstructionCoder interface and implementations
/// for encoding and decoding program instructions using Borsh serialization.
library;

import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/coder/borsh_types.dart';
import 'package:coral_xyz_anchor/src/coder/discriminator_computer.dart';
import 'package:coral_xyz_anchor/src/types/common.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart'; // <-- Add this import for AccountMeta
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

  const Instruction({
    required this.name,
    required this.data,
  });
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

  const InstructionDisplay({
    required this.args,
    required this.accounts,
  });
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
    this.name,
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
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
  String toString() => 'InstructionAccount(name: $name, pubkey: $pubkey, '
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

  @override
  Uint8List encode(String ixName, Map<String, dynamic> ix) {
    final layout = _ixLayouts[ixName];
    if (layout == null) {
      throw InstructionCoderException('Unknown instruction: $ixName');
    }

    try {
      print('InstructionCoder: Encoding instruction: $ixName');
      print('InstructionCoder: Discriminator: ${layout.discriminator}');

      // Encode the instruction arguments using a basic Borsh serializer
      final serializer = BorshSerializer();
      _encodeInstructionArgs(ix, layout.instruction, serializer);
      final argsData = serializer.toBytes();

      print('InstructionCoder: Args data length: ${argsData.length}');

      // Prepend the discriminator
      final discriminator = Uint8List.fromList(layout.discriminator);
      final result = Uint8List(discriminator.length + argsData.length);
      result.setRange(0, discriminator.length, discriminator);
      result.setRange(discriminator.length, result.length, argsData);

      print(
          'InstructionCoder: Final instruction data length: ${result.length}',);
      print('InstructionCoder: Final instruction data: ${result.toList()}');

      return result;
    } catch (e) {
      print('InstructionCoder: Error encoding instruction $ixName: $e');
      throw InstructionCoderException(
          'Failed to encode instruction $ixName: $e',);
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
          final decodedData =
              _decodeInstructionArgs(layout.instruction, deserializer);

          return Instruction(
            name: name,
            data: decodedData,
          );
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
      args.add(InstructionArg(
        name: arg.name,
        type: _formatIdlType(arg.type),
        data: _formatValue(value, arg.type),
      ),);
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

      accounts.add(InstructionAccount(
        name: name,
        pubkey: meta.pubkey.toBase58(),
        isSigner: meta.isSigner,
        isWritable: meta.isWritable,
      ),);
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
  List<int> _computeDiscriminator(String instructionName) {
    final discriminator =
        DiscriminatorComputer.computeInstructionDiscriminator(instructionName);
    return discriminator.toList();
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
            'Missing required argument: ${arg.name}',);
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
        serializer.writeU64(value as int);
        break;
      case 'i64':
        serializer.writeI64(value as int);
        break;
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'pubkey':
        // For now, treat pubkey as a string
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
          throw InstructionCoderException(
            'Array length mismatch: expected ${type.size}, got ${list.length}',
          );
        }
        for (final item in list) {
          _encodeValue(item, type.inner!, serializer);
        }
        break;
      default:
        throw InstructionCoderException(
            'Unsupported type for encoding: ${type.kind}',);
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
      case 'string':
        return deserializer.readString();
      case 'pubkey':
        // For now, treat pubkey as a string
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
      default:
        throw InstructionCoderException(
            'Unsupported type for decoding: ${type.kind}',);
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
        return type.defined ?? 'Unknown';
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
          .map((e) =>
              '${e.key}: ${_formatValue(e.value, const IdlType(kind: 'unknown'))}',)
          .join(', ');
      return '{$entries}';
    }

    return value.toString();
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
