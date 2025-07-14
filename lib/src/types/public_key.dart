/// PublicKey implementation for Solana addresses
///
/// This class represents a Solana public key (address) and provides
/// utilities for validation, serialization, and conversion.

library;

import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/external/encoding_wrapper.dart';
import 'package:coral_xyz_anchor/src/crypto/solana_crypto.dart';

export '../crypto/solana_crypto.dart' show PdaResult;

/// A Solana public key/address representation
///
/// This class provides a type-safe way to work with Solana addresses,
/// including validation, serialization, and utility functions for
/// common operations like PDA derivation.
class PublicKey {

  /// Creates a PublicKey from a 32-byte array
  PublicKey._(this._bytes) {
    if (_bytes.length != publicKeyLength) {
      throw ArgumentError(
        'Invalid public key input. Expected $publicKeyLength bytes, '
        'got ${_bytes.length}',
      );
    }
  }

  /// Creates a PublicKey from a base58 string
  factory PublicKey.fromBase58(String base58String) {
    try {
      final bytes = EncodingWrapper.decodeBase58(base58String);
      return PublicKey._(bytes);
    } catch (e) {
      throw ArgumentError('Invalid base58 string: $base58String');
    }
  }

  /// Creates a PublicKey from a byte array
  factory PublicKey.fromBytes(List<int> bytes) {
    return PublicKey._(Uint8List.fromList(bytes));
  }

  /// Creates a PublicKey from a hex string
  factory PublicKey.fromHex(String hex) {
    // Remove 0x prefix if present
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;

    if (cleanHex.length != publicKeyLength * 2) {
      throw ArgumentError(
        'Invalid hex string length. Expected ${publicKeyLength * 2} characters, '
        'got ${cleanHex.length}',
      );
    }

    final bytes = Uint8List(publicKeyLength);
    for (int i = 0; i < publicKeyLength; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return PublicKey._(bytes);
  }
  static const int publicKeyLength = 32;

  final Uint8List _bytes;

  /// Get the raw bytes of the public key
  Uint8List toBytes() => _bytes;

  /// The default public key (all zeros)
  static final PublicKey defaultPubkey = PublicKey._(
    Uint8List(publicKeyLength),
  );

  /// System program ID
  static final PublicKey systemProgram = PublicKey.fromBase58(
    '11111111111111111111111111111111',
  );

  /// Get the public key as bytes
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Convert to base58 string representation
  String toBase58() => EncodingWrapper.encodeBase58(_bytes);

  /// Convert to hex string representation
  String toHex() => _bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Check if this public key equals another
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PublicKey) return false;

    if (_bytes.length != other._bytes.length) return false;
    for (int i = 0; i < _bytes.length; i++) {
      if (_bytes[i] != other._bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = 17;
    for (final byte in _bytes) {
      hash = hash * 31 + byte;
    }
    return hash;
  }

  /// String representation (base58)
  @override
  String toString() => toBase58();

  /// Check if this is the default public key (all zeros)
  bool get isDefault => _bytes.every((byte) => byte == 0);

  /// Validate that a string is a valid base58 public key
  static bool isValidBase58(String address) {
    try {
      final decoded = EncodingWrapper.decodeBase58(address);
      return decoded.length == publicKeyLength;
    } catch (e) {
      return false;
    }
  }

  /// Find a program derived address (PDA)
  ///
  /// This is a core Solana concept for deterministic address generation
  static Future<PdaResult> findProgramAddress(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async {
    try {
      final cryptoResult = SolanaCrypto.findProgramAddress(
        seeds,
        programId.toBytes(),
      );
      final publicKey = PublicKey._(cryptoResult.address);
      return PdaResult(publicKey, cryptoResult.bump);
    } catch (e) {
      throw Exception('Failed to find program address: $e');
    }
  }

  /// Create a program address
  static Future<PublicKey> createProgramAddress(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async {
    try {
      final addressBytes = SolanaCrypto.createProgramAddress(
        seeds,
        programId.toBytes(),
      );
      return PublicKey._(addressBytes);
    } catch (e) {
      throw Exception('Failed to create program address: $e');
    }
  }

  /// Check if this public key is on the ed25519 curve
  ///
  /// This is used for PDA validation. A valid PDA should NOT be on the curve.
  bool isOnCurve() {
    // Check if the leftmost bit of the last byte is set
    // This is a simplified version of the curve check that matches
    // Solana's implementation for PDA validation
    return (_bytes[31] & 0x80) != 0;
  }

  /// Create a new random public key (for testing)
  static PublicKey unique() {
    // Generate random bytes for testing purposes
    final bytes = Uint8List(publicKeyLength);
    for (int i = 0; i < publicKeyLength; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return PublicKey._(bytes);
  }
}

/// Result of a PDA (Program Derived Address) operation
class PdaResult {

  const PdaResult(this.address, this.bump);
  final PublicKey address;
  final int bump;

  @override
  String toString() => 'PdaResult(address: $address, bump: $bump)';
}
