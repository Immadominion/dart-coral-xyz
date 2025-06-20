/// Anchor-specific Borsh serialization extensions
///
/// This module provides enhanced Borsh serialization specifically designed
/// for Anchor programs, including account/instruction discriminators,
/// PublicKey integration, and Anchor-specific data types.

import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'borsh_types.dart';
import 'borsh_utils.dart';
import '../types/public_key.dart';

/// Anchor-specific Borsh serialization extensions
class AnchorBorsh {
  /// Serialize an Anchor account with discriminator
  ///
  /// Anchor accounts always start with an 8-byte discriminator followed
  /// by the account data serialized with Borsh.
  static Uint8List serializeAccount<T extends BorshSerializable>(
    String accountName,
    T accountData,
  ) {
    final serializer = BorshSerializer();

    // Write the discriminator first
    final discriminator = BorshUtils.createAccountDiscriminator(accountName);
    serializer.writeDiscriminator(discriminator);

    // Write the account data
    final accountBytes = accountData.serialize();
    serializer.writeFixedArray(accountBytes);

    return serializer.toBytes();
  }

  /// Deserialize an Anchor account with discriminator verification
  ///
  /// Verifies the discriminator matches the expected account type and
  /// then deserializes the account data.
  static T deserializeAccount<T>(
    String expectedAccountName,
    Uint8List data,
    T Function(BorshDeserializer) deserializeFunc,
  ) {
    final deserializer = BorshDeserializer(data);

    // Read and verify discriminator
    final discriminator = deserializer.readDiscriminator();
    final expectedDiscriminator =
        BorshUtils.createAccountDiscriminator(expectedAccountName);

    if (!_arraysEqual(discriminator, expectedDiscriminator)) {
      throw BorshException(
        'Account discriminator mismatch. Expected discriminator for "$expectedAccountName"',
      );
    }

    // Deserialize the remaining data
    return deserializeFunc(deserializer);
  }

  /// Serialize an Anchor instruction with discriminator
  ///
  /// Anchor instructions always start with an 8-byte discriminator followed
  /// by the instruction arguments serialized with Borsh.
  static Uint8List serializeInstruction(
    String instructionName,
    void Function(BorshSerializer) serializeArgs,
  ) {
    final serializer = BorshSerializer();

    // Write the discriminator first
    final discriminator =
        BorshUtils.createInstructionDiscriminator(instructionName);
    serializer.writeDiscriminator(discriminator);

    // Write the instruction arguments
    serializeArgs(serializer);

    return serializer.toBytes();
  }

  /// Deserialize an Anchor instruction with discriminator verification
  ///
  /// Verifies the discriminator matches the expected instruction and
  /// then deserializes the instruction arguments.
  static T deserializeInstruction<T>(
    String expectedInstructionName,
    Uint8List data,
    T Function(BorshDeserializer) deserializeFunc,
  ) {
    final deserializer = BorshDeserializer(data);

    // Read and verify discriminator
    final discriminator = deserializer.readDiscriminator();
    final expectedDiscriminator =
        BorshUtils.createInstructionDiscriminator(expectedInstructionName);

    if (!_arraysEqual(discriminator, expectedDiscriminator)) {
      throw BorshException(
        'Instruction discriminator mismatch. Expected discriminator for "$expectedInstructionName"',
      );
    }

    // Deserialize the remaining data
    return deserializeFunc(deserializer);
  }

  /// Serialize a PublicKey using Borsh format
  static Uint8List serializePublicKey(PublicKey publicKey) {
    final serializer = BorshSerializer();
    BorshUtils.writePublicKey(serializer, publicKey.bytes);
    return serializer.toBytes();
  }

  /// Deserialize a PublicKey from Borsh format
  static PublicKey deserializePublicKey(Uint8List data) {
    final deserializer = BorshDeserializer(data);
    final keyBytes = deserializer.readPublicKey();
    return PublicKey.fromBytes(keyBytes);
  }

  /// Serialize an event with discriminator (Anchor events)
  ///
  /// Anchor events use a discriminator similar to instructions but with
  /// a different namespace prefix.
  static Uint8List serializeEvent(
    String eventName,
    void Function(BorshSerializer) serializeData,
  ) {
    final serializer = BorshSerializer();

    // Create event discriminator using "event:{name}" format
    final input = 'event:$eventName';
    final hash = sha256.convert(utf8.encode(input));
    final discriminator = Uint8List.fromList(
      hash.bytes.take(BorshUtils.discriminatorSize).toList(),
    );

    serializer.writeDiscriminator(discriminator);
    serializeData(serializer);

    return serializer.toBytes();
  }

  /// Create a discriminator for a custom Anchor namespace
  ///
  /// Allows creation of discriminators for custom namespaces beyond
  /// the standard "account:", "global:", and "event:" prefixes.
  static Uint8List createCustomDiscriminator(String namespace, String name) {
    final input = '$namespace:$name';
    final hash = sha256.convert(utf8.encode(input));
    return Uint8List.fromList(
      hash.bytes.take(BorshUtils.discriminatorSize).toList(),
    );
  }

  /// Helper function to compare byte arrays
  static bool _arraysEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Extension methods for PublicKey to add Borsh serialization support
extension PublicKeyBorsh on PublicKey {
  /// Serialize this PublicKey using Borsh format
  Uint8List serializeBorsh() {
    return AnchorBorsh.serializePublicKey(this);
  }
}

/// Extension methods for BorshSerializer to add Anchor-specific types
extension AnchorBorshSerializer on BorshSerializer {
  /// Write a PublicKey from PublicKey object
  void writePublicKeyObject(PublicKey publicKey) {
    BorshUtils.writePublicKey(this, publicKey.bytes);
  }

  /// Write an account discriminator
  void writeAccountDiscriminator(String accountName) {
    final discriminator = BorshUtils.createAccountDiscriminator(accountName);
    writeDiscriminator(discriminator);
  }

  /// Write an instruction discriminator
  void writeInstructionDiscriminator(String instructionName) {
    final discriminator =
        BorshUtils.createInstructionDiscriminator(instructionName);
    writeDiscriminator(discriminator);
  }
}

/// Extension methods for BorshDeserializer to add Anchor-specific types
extension AnchorBorshDeserializer on BorshDeserializer {
  /// Read a PublicKey
  Uint8List readPublicKeyBytes() {
    return BorshUtils.readPublicKey(this);
  }

  /// Read a PublicKey as PublicKey object
  PublicKey readPublicKeyObject() {
    final keyBytes = readPublicKeyBytes();
    return PublicKey.fromBytes(keyBytes);
  }

  /// Verify an account discriminator
  bool verifyAccountDiscriminator(String expectedAccountName) {
    final discriminator = readDiscriminator();
    final expectedDiscriminator =
        BorshUtils.createAccountDiscriminator(expectedAccountName);
    return AnchorBorsh._arraysEqual(discriminator, expectedDiscriminator);
  }

  /// Verify an instruction discriminator
  bool verifyInstructionDiscriminator(String expectedInstructionName) {
    final discriminator = readDiscriminator();
    final expectedDiscriminator =
        BorshUtils.createInstructionDiscriminator(expectedInstructionName);
    return AnchorBorsh._arraysEqual(discriminator, expectedDiscriminator);
  }
}
