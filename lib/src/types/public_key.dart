// Copyright 2024 Dart Coral XYZ
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/base58.dart';

/// Re-export Ed25519HDPublicKey as PublicKey for compatibility
typedef PublicKey = solana.Ed25519HDPublicKey;

/// Extensions for PublicKey to maintain API compatibility
extension PublicKeyExtensions on PublicKey {
  /// Get the raw bytes of the public key as Uint8List
  Uint8List toBytes() => Uint8List.fromList(bytes);

  /// Check if this is the default public key (all zeros)
  bool get isDefault => bytes.every((byte) => byte == 0);

  /// Convert to hex string
  String toHex() =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Convert to base58 string (compatibility method)
  String toBase58String() => toBase58();

  // Static getters and methods for compatibility
  static PublicKey get systemProgram => PublicKeyUtils.systemProgram;
  static PublicKey get defaultPubkey => PublicKeyUtils.defaultPubkey;
  static PublicKey fromBytes(List<int> bytes) =>
      PublicKeyUtils.fromBytes(bytes);
  static PublicKey fromHex(String hex) => PublicKeyUtils.fromHex(hex);
  static bool isOnCurve(List<int> bytes) => PublicKeyUtils.isOnCurve(bytes);
  static bool isValidBase58(String value) =>
      PublicKeyUtils.isValidBase58(value);
  static Future<PdaResult> findProgramAddress(
          List<List<int>> seeds, PublicKey programId) =>
      PublicKeyUtils.findProgramAddress(seeds, programId);
  static Future<PublicKey> createProgramAddress(
          List<List<int>> seeds, PublicKey programId) =>
      PublicKeyUtils.createProgramAddress(seeds, programId);
}

/// Static utilities for PublicKey operations
///
/// This class provides all the static methods that would normally be on PublicKey
/// in the TypeScript SDK, building on top of espresso-cash-public implementation.
class PublicKeyUtils {
  /// System Program PublicKey
  static PublicKey get systemProgram => solana.SystemProgram.id;

  /// Default PublicKey (all zeros)
  static final PublicKey defaultPubkey =
      solana.Ed25519HDPublicKey(Uint8List(32));

  /// Create PublicKey from base58 string
  static PublicKey fromBase58(String base58) {
    try {
      return solana.Ed25519HDPublicKey.fromBase58(base58);
    } catch (e) {
      throw ArgumentError('Invalid base58 string: $e');
    }
  }

  /// Create PublicKey from bytes
  static PublicKey fromBytes(List<int> bytes) {
    try {
      if (bytes is Uint8List) {
        return solana.Ed25519HDPublicKey(bytes);
      }
      return solana.Ed25519HDPublicKey(Uint8List.fromList(bytes));
    } catch (e) {
      throw ArgumentError('Invalid bytes for PublicKey: $e');
    }
  }

  /// Create PublicKey from hex string
  static PublicKey fromHex(String hex) {
    try {
      final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
      if (cleanHex.length != 64) {
        throw ArgumentError(
            'Expected 64 hex characters, got ${cleanHex.length}');
      }

      final bytes = Uint8List.fromList(
        List<int>.generate(
          cleanHex.length ~/ 2,
          (i) => int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );
      return solana.Ed25519HDPublicKey(bytes);
    } catch (e) {
      throw ArgumentError('Invalid hex string: $e');
    }
  }

  /// Check if a point is on the Ed25519 curve
  static bool isOnCurve(List<int> bytes) {
    try {
      // Try to create a PublicKey - if it fails, it's not on curve
      solana.Ed25519HDPublicKey(Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate if a string is valid base58
  static bool isValidBase58(String value) {
    try {
      if (value.isEmpty) return false;
      base58decode(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create PublicKey with seed - sync version matching TypeScript utils.pubkey.createWithSeedSync
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
    return solana.Ed25519HDPublicKey(Uint8List.fromList(hash));
  }

  /// Create PublicKey with seed - async version using espresso-cash implementation
  static Future<PublicKey> createWithSeed({
    required PublicKey fromPublicKey,
    required String seed,
    required PublicKey programId,
  }) =>
      solana.Ed25519HDPublicKey.createWithSeed(
        fromPublicKey: fromPublicKey,
        seed: seed,
        programId: programId,
      );

  /// Find a program derived address with bump seed tracking
  static Future<PdaResult> findProgramAddress(
    List<List<int>> seeds,
    PublicKey programId,
  ) async {
    try {
      // Use espresso-cash findProgramAddress with proper format
      // Convert List<List<int>> to List<Iterable<int>> as expected by espresso-cash
      final seedsAsIterables = seeds.cast<Iterable<int>>();

      final address = await solana.Ed25519HDPublicKey.findProgramAddress(
        seeds: seedsAsIterables,
        programId: programId,
      );

      // Find the bump that was used by espresso-cash
      // We need to iterate to find which bump produces the same address
      for (int bump = 255; bump >= 0; bump--) {
        try {
          final testSeeds = [...seeds.expand((s) => s), bump];
          final testAddress =
              await solana.Ed25519HDPublicKey.createProgramAddress(
            seeds: testSeeds,
            programId: programId,
          );
          if (testAddress == address) {
            return PdaResult(address, bump);
          }
        } catch (e) {
          // Continue searching
        }
      }

      // Fallback - return with bump 0 if we can't determine it
      return PdaResult(address, 0);
    } catch (e) {
      throw ArgumentError('Failed to find PDA: $e');
    }
  }

  /// Create program address from seeds and program ID (async version)
  static Future<PublicKey> createProgramAddress(
    List<List<int>> seeds,
    PublicKey programId,
  ) async {
    try {
      // Convert to proper format for espresso-cash
      final flatSeeds = seeds.expand((seed) => seed).toList();
      return await solana.Ed25519HDPublicKey.createProgramAddress(
        seeds: flatSeeds,
        programId: programId,
      );
    } catch (e) {
      throw ArgumentError('Failed to create program address: $e');
    }
  }

  /// Create program address from seeds and program ID (sync version)
  static PublicKey createProgramAddressSync(
    List<List<int>> seeds,
    PublicKey programId,
  ) {
    try {
      final flatSeeds = seeds.expand((seed) => seed).toList();
      return _createProgramAddressSync(flatSeeds, programId);
    } catch (e) {
      throw ArgumentError('Failed to create program address: $e');
    }
  }

  /// Find program address synchronously - matches TypeScript SDK
  static PdaResult findProgramAddressSync(
    List<List<int>> seeds,
    PublicKey programId,
  ) {
    try {
      if (seeds.length > 16) {
        throw ArgumentError('You can provide up to 16 seeds');
      }

      for (final seedList in seeds) {
        if (seedList.length > 32) {
          throw ArgumentError('One or more of the seeds provided is too big');
        }
      }

      int bumpSeed = 255;
      while (bumpSeed >= 0) {
        try {
          final flatSeeds = seeds.expand((seed) => seed).toList()
            ..add(bumpSeed);
          final address = _createProgramAddressSync(flatSeeds, programId);
          return PdaResult(address, bumpSeed);
        } catch (e) {
          bumpSeed--;
        }
      }
      throw ArgumentError('Cannot find valid program address');
    } catch (e) {
      throw ArgumentError('Failed to find PDA: $e');
    }
  }

  /// Create program address synchronously - internal helper
  static PublicKey _createProgramAddressSync(
    List<int> seeds,
    PublicKey programId,
  ) {
    final seedBytes = [
      ...seeds,
      ...programId.bytes,
      ...'ProgramDerivedAddress'.codeUnits,
    ];

    final hash = sha256.convert(seedBytes).bytes;

    // Check if point is on curve (invalid for PDA)
    if (isOnCurve(hash)) {
      throw ArgumentError('Invalid seeds: address must fall off the curve');
    }

    return solana.Ed25519HDPublicKey(Uint8List.fromList(hash));
  }
}

/// Result of PDA derivation containing address and bump seed
class PdaResult {
  const PdaResult(this.address, this.bump);

  /// The derived program address
  final PublicKey address;

  /// The bump seed used for derivation
  final int bump;

  @override
  String toString() => 'PdaResult(address: $address, bump: $bump)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdaResult && address == other.address && bump == other.bump;

  @override
  int get hashCode => address.hashCode ^ bump.hashCode;
}
