/// Core Discriminator Computation Engine
///
/// This module provides byte-perfect discriminator computation compatibility
/// with TypeScript Anchor client's discriminator algorithm.
///
/// Implements the exact discriminator computation algorithm used by TypeScript
/// Anchor client, ensuring byte-perfect compatibility for account, global,
/// and event discriminators.

library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Core discriminator computation engine that matches TypeScript Anchor client
/// discriminator computation byte-for-byte.
///
/// This class provides static methods for computing discriminators for:
/// - Account discriminators: SHA256("account:" + name) → first 8 bytes
/// - Instruction discriminators: SHA256("global:" + name) → first 8 bytes
/// - Event discriminators: SHA256("event:" + name) → first 8 bytes
///
/// The computation algorithm exactly matches the TypeScript Anchor client
/// implementation to ensure byte-perfect compatibility.
class DiscriminatorComputer {
  /// Size of Anchor discriminators in bytes
  static const int discriminatorSize = 8;

  /// Prefix for account discriminators
  static const String accountPrefix = 'account:';

  /// Prefix for instruction discriminators (global namespace)
  static const String globalPrefix = 'global:';

  /// Prefix for event discriminators
  static const String eventPrefix = 'event:';

  /// Compute discriminator for Anchor accounts.
  ///
  /// Uses SHA256 hash of "account:{name}" and takes first 8 bytes.
  /// This matches the TypeScript Anchor client's account discriminator computation.
  ///
  /// [name] The account name to compute discriminator for
  ///
  /// Returns 8-byte Uint8List containing the discriminator
  ///
  /// Throws [ArgumentError] if name is null or empty
  static Uint8List computeAccountDiscriminator(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Account name cannot be empty');
    }

    return _computeDiscriminator(accountPrefix, name);
  }

  /// Compute discriminator for Anchor instructions.
  ///
  /// Uses SHA256 hash of "global:{name}" and takes first 8 bytes.
  /// This matches the TypeScript Anchor client's instruction discriminator computation.
  ///
  /// [name] The instruction name to compute discriminator for
  ///
  /// Returns 8-byte Uint8List containing the discriminator
  ///
  /// Throws [ArgumentError] if name is null or empty
  static Uint8List computeInstructionDiscriminator(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Instruction name cannot be empty');
    }

    return _computeDiscriminator(globalPrefix, name);
  }

  /// Compute discriminator for Anchor events.
  ///
  /// Uses SHA256 hash of "event:{name}" and takes first 8 bytes.
  /// This matches the TypeScript Anchor client's event discriminator computation.
  ///
  /// [name] The event name to compute discriminator for
  ///
  /// Returns 8-byte Uint8List containing the discriminator
  ///
  /// Throws [ArgumentError] if name is null or empty
  static Uint8List computeEventDiscriminator(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Event name cannot be empty');
    }

    return _computeDiscriminator(eventPrefix, name);
  }

  /// Internal method to compute discriminator with given prefix and name.
  ///
  /// This method implements the core algorithm:
  /// 1. Concatenate prefix + name
  /// 2. Encode as UTF-8 bytes (matching TypeScript Buffer.from() behavior)
  /// 3. Compute SHA256 hash
  /// 4. Take first 8 bytes (matching TypeScript Uint8Array.slice(0, 8))
  ///
  /// [prefix] The discriminator prefix ("account:", "global:", or "event:")
  /// [name] The name to compute discriminator for
  ///
  /// Returns 8-byte Uint8List containing the discriminator
  static Uint8List _computeDiscriminator(String prefix, String name) {
    // Concatenate prefix and name exactly as TypeScript does
    final input = prefix + name;

    // Encode as UTF-8 bytes, matching TypeScript Buffer.from() behavior
    final inputBytes = utf8.encode(input);

    // Compute SHA256 hash
    final hash = sha256.convert(inputBytes);

    // Take first 8 bytes, matching TypeScript Uint8Array.slice(0, 8)
    return Uint8List.fromList(hash.bytes.take(discriminatorSize).toList());
  }

  /// Validate that a discriminator has the correct size.
  ///
  /// [discriminator] The discriminator to validate
  ///
  /// Throws [ArgumentError] if discriminator is not exactly 8 bytes
  static void validateDiscriminatorSize(Uint8List discriminator) {
    if (discriminator.length != discriminatorSize) {
      throw ArgumentError(
        'Discriminator must be exactly $discriminatorSize bytes, '
        'got ${discriminator.length}',
      );
    }
  }

  /// Convert discriminator to hexadecimal string for debugging.
  ///
  /// [discriminator] The discriminator to convert
  ///
  /// Returns hexadecimal string representation
  static String discriminatorToHex(Uint8List discriminator) => discriminator
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');

  /// Create discriminator from hexadecimal string.
  ///
  /// [hex] Hexadecimal string (with or without 0x prefix)
  ///
  /// Returns Uint8List discriminator
  ///
  /// Throws [ArgumentError] if hex string is invalid or wrong length
  static Uint8List discriminatorFromHex(String hex) {
    // Remove 0x prefix if present
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }

    // Validate hex string length
    if (hex.length != discriminatorSize * 2) {
      throw ArgumentError(
        'Hex string must represent exactly $discriminatorSize bytes '
        '(${discriminatorSize * 2} hex characters), got ${hex.length}',
      );
    }

    // Convert hex string to bytes
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final byteString = hex.substring(i, i + 2);
      final byte = int.tryParse(byteString, radix: 16);
      if (byte == null) {
        throw ArgumentError('Invalid hex character in: $byteString');
      }
      bytes.add(byte);
    }

    return Uint8List.fromList(bytes);
  }

  /// Compare two discriminators for equality.
  ///
  /// [expected] The expected discriminator
  /// [actual] The actual discriminator
  ///
  /// Returns true if discriminators match exactly
  static bool compareDiscriminators(Uint8List expected, Uint8List actual) {
    if (expected.length != actual.length) {
      return false;
    }

    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) {
        return false;
      }
    }

    return true;
  }
}
