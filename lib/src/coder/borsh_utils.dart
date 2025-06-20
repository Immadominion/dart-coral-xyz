/// Borsh utilities for Solana and Anchor-specific types
///
/// This module provides Borsh serialization support for common types
/// used in Solana and Anchor programs, including PublicKeys, signatures,
/// and Anchor-specific data structures.

import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'borsh_types.dart';

/// Borsh utilities for Anchor-specific serialization
class BorshUtils {
  /// Size of a Solana PublicKey in bytes
  static const int publicKeySize = 32;

  /// Size of Anchor account/instruction discriminators
  static const int discriminatorSize = 8;

  /// Create discriminator for Anchor accounts (8 bytes)
  /// Uses SHA256 hash of "account:{name}" and takes first 8 bytes
  static Uint8List createAccountDiscriminator(String name) {
    final input = 'account:$name';
    final hash = sha256.convert(utf8.encode(input));
    return Uint8List.fromList(hash.bytes.take(discriminatorSize).toList());
  }

  /// Create discriminator for Anchor instructions (8 bytes)
  /// Uses SHA256 hash of "global:{name}" and takes first 8 bytes
  static Uint8List createInstructionDiscriminator(String name) {
    final input = 'global:$name';
    final hash = sha256.convert(utf8.encode(input));
    return Uint8List.fromList(hash.bytes.take(discriminatorSize).toList());
  }

  /// Serialize a Solana PublicKey (32 bytes)
  static void writePublicKey(BorshSerializer serializer, Uint8List publicKey) {
    if (publicKey.length != publicKeySize) {
      throw BorshException(
        'PublicKey must be exactly $publicKeySize bytes, got ${publicKey.length}',
      );
    }
    serializer.writeFixedArray(publicKey);
  }

  /// Deserialize a Solana PublicKey (32 bytes)
  static Uint8List readPublicKey(BorshDeserializer deserializer) {
    return deserializer.readFixedArray(publicKeySize);
  }

  /// Calculate the size needed for a Vec<T> where each T has a known size
  static int vecSize(int itemSize, int itemCount) {
    return 4 + (itemSize * itemCount); // 4 bytes for length + items
  }

  /// Calculate the size needed for a String
  static int stringSize(String str) {
    return 4 + utf8.encode(str).length; // 4 bytes for length + UTF-8 bytes
  }

  /// Calculate the size needed for an Option<T>
  static int optionSize(int? itemSize) {
    return 1 + (itemSize ?? 0); // 1 byte for tag + optional item
  }
}

/// A Borsh-serializable struct base class
abstract class BorshStruct implements BorshSerializable {
  @override
  Uint8List serialize() {
    final serializer = BorshSerializer();
    serializeInternal(serializer);
    return serializer.toBytes();
  }

  /// Override this to implement struct-specific serialization
  void serializeInternal(BorshSerializer serializer);

  /// Override this to calculate the serialized size
  @override
  int get serializedSize;
}

/// A helper for creating Borsh-serializable data classes
mixin BorshSerializableMixin {
  /// Serialize using a provided serialization function
  Uint8List serializeWith(void Function(BorshSerializer) serialize) {
    final serializer = BorshSerializer();
    serialize(serializer);
    return serializer.toBytes();
  }

  /// Deserialize using a provided deserialization function
  T deserializeWith<T>(
    Uint8List data,
    T Function(BorshDeserializer) deserialize,
  ) {
    final deserializer = BorshDeserializer(data);
    return deserialize(deserializer);
  }
}

/// Extension methods for common Borsh operations
extension BorshSerializerExtensions on BorshSerializer {
  /// Write a PublicKey
  void writePublicKey(Uint8List publicKey) {
    BorshUtils.writePublicKey(this, publicKey);
  }

  /// Write a discriminator (for Anchor accounts/instructions)
  void writeDiscriminator(Uint8List discriminator) {
    if (discriminator.length != BorshUtils.discriminatorSize) {
      throw BorshException(
        'Discriminator must be exactly ${BorshUtils.discriminatorSize} bytes',
      );
    }
    writeFixedArray(discriminator);
  }
}

extension BorshDeserializerExtensions on BorshDeserializer {
  /// Read a PublicKey
  Uint8List readPublicKey() {
    return BorshUtils.readPublicKey(this);
  }

  /// Read a discriminator (for Anchor accounts/instructions)
  Uint8List readDiscriminator() {
    return readFixedArray(BorshUtils.discriminatorSize);
  }
}
