/// Wrapper for Borsh serialization functionality
///
/// This module provides a consistent interface to Borsh serialization
/// by wrapping external borsh packages and providing additional
/// Anchor-specific functionality.

library;

import 'dart:typed_data';
import '../coder/borsh_types.dart';
import '../coder/borsh_utils.dart';

/// Wrapper around Borsh serialization with Anchor-specific enhancements
class BorshWrapper {
  /// Serialize data to bytes using Borsh format
  static Uint8List serialize(dynamic data) {
    if (data is BorshSerializable) {
      return data.serialize();
    }

    // For basic types, create a serializer and handle them
    final serializer = BorshSerializer();

    if (data is int) {
      if (data >= 0 && data <= 255) {
        serializer.writeU8(data);
      } else if (data >= 0 && data <= 65535) {
        serializer.writeU16(data);
      } else if (data >= 0 && data <= 4294967295) {
        serializer.writeU32(data);
      } else {
        serializer.writeU64(data);
      }
    } else if (data is bool) {
      serializer.writeBool(data);
    } else if (data is String) {
      serializer.writeString(data);
    } else if (data is List<int>) {
      serializer.writeArray(data, (item) => serializer.writeU8(item));
    } else {
      throw BorshException(
          'Unsupported data type for serialization: ${data.runtimeType}');
    }

    return serializer.toBytes();
  }

  /// Deserialize bytes from Borsh format
  static T deserialize<T>(
      Uint8List data, T Function(BorshDeserializer) deserializeFunc) {
    final deserializer = BorshDeserializer(data);
    return deserializeFunc(deserializer);
  }

  /// Create discriminator for Anchor accounts (8 bytes)
  static Uint8List createAccountDiscriminator(String name) {
    return BorshUtils.createAccountDiscriminator(name);
  }

  /// Create discriminator for Anchor instructions (8 bytes)
  static Uint8List createInstructionDiscriminator(String name) {
    return BorshUtils.createInstructionDiscriminator(name);
  }
}
