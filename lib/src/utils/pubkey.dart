/// PublicKey utilities for Anchor programs
///
/// This module provides utilities similar to the TypeScript Anchor SDK's
/// utils.publicKey module for working with PublicKeys, PDAs, and derived addresses.

library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Utilities for working with PublicKeys and derived addresses
class PublicKeyUtils {
  /// Sync version of PublicKey.createWithSeed
  ///
  /// Creates a PublicKey from a base key, seed string, and program ID.
  /// This is equivalent to the TypeScript SDK's createWithSeedSync function.
  static PublicKey createWithSeedSync(
    PublicKey fromPublicKey,
    String seed,
    PublicKey programId,
  ) {
    final buffer = Uint8List.fromList([
      ...fromPublicKey.bytes,
      ...seed.codeUnits,
      ...programId.bytes,
    ]);

    final hash = sha256.convert(buffer).bytes;
    return PublicKey.fromBytes(hash);
  }

  /// Find a valid Program Derived Address (PDA) and its bump seed
  ///
  /// This is a convenience wrapper around PublicKey.findProgramAddress
  /// that provides the same interface as the TypeScript SDK.
  static Future<PdaResult> findProgramAddress(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async => PublicKey.findProgramAddress(seeds, programId);

  /// Create a program address directly (without finding bump)
  ///
  /// This creates a program address from the exact seeds provided,
  /// including the bump seed. Used when you already know the bump.
  static Future<PublicKey> createProgramAddress(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async => PublicKey.createProgramAddress(seeds, programId);

  /// Check if a PublicKey is on the ed25519 curve
  ///
  /// Returns true if the key is on the curve (not a PDA), false otherwise.
  /// Note: This is a simplified check - in practice, PDAs are off-curve
  static bool isOnCurve(PublicKey publicKey) {
    // This is a simplified implementation - for a full implementation,
    // you would need to check if the point is on the ed25519 curve
    // For now, we assume all non-default keys are potentially on curve
    return !isDefault(publicKey);
  }

  /// Validate that a string is a valid base58-encoded PublicKey
  static bool isValidBase58(String address) => PublicKey.isValidBase58(address);

  /// Create a PublicKey from a byte array with validation
  static PublicKey fromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('PublicKey must be 32 bytes, got ${bytes.length}');
    }
    return PublicKey.fromBytes(bytes);
  }

  /// Create a PublicKey from a base58 string with validation
  static PublicKey fromBase58(String base58) {
    try {
      return PublicKey.fromBase58(base58);
    } catch (e) {
      throw ArgumentError('Invalid base58 PublicKey: $base58');
    }
  }

  /// Convert a PublicKey to its base58 string representation
  static String toBase58(PublicKey publicKey) => publicKey.toBase58();

  /// Convert a PublicKey to its byte array representation
  static Uint8List toBytes(PublicKey publicKey) => publicKey.bytes;

  /// Create a unique PublicKey using a random seed
  ///
  /// This creates a deterministic but unique PublicKey from a base key
  /// and some unique data (like a timestamp or counter).
  static PublicKey unique(PublicKey base, [String? uniqueData]) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = (timestamp * 31 + base.hashCode) % 1000000;
    final seed = uniqueData ?? '${timestamp}_$random';
    // Use the system program ID as the program ID for derived addresses
    final systemProgramId =
        PublicKey.fromBase58('11111111111111111111111111111111');
    return createWithSeedSync(base, seed, systemProgramId);
  }

  /// Compare two PublicKeys for equality
  static bool equals(PublicKey a, PublicKey b) => a == b;

  /// Get the default PublicKey (all zeros)
  static PublicKey get defaultKey => PublicKey.defaultPubkey;

  /// Check if a PublicKey is the default (all zeros)
  static bool isDefault(PublicKey publicKey) => equals(publicKey, defaultKey);
}
