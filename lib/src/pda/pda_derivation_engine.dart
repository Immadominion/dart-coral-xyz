/// Core PDA Derivation Engine
///
/// This module implements comprehensive Program Derived Address (PDA) derivation
/// matching TypeScript's PublicKey.findProgramAddress capabilities with
/// optimization and caching.
library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Exception thrown during PDA derivation operations
class PdaDerivationException implements Exception {

  const PdaDerivationException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'PdaDerivationException: $message';
}

/// Represents a seed used in PDA derivation
abstract class PdaSeed {
  /// Convert this seed to bytes for derivation
  Uint8List toBytes();

  /// Get a string representation for debugging
  String toDebugString();
}

/// String seed implementation
class StringSeed implements PdaSeed {

  const StringSeed(this.value);
  final String value;

  @override
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(value));

  @override
  String toDebugString() => 'String("$value")';
}

/// Bytes seed implementation
class BytesSeed implements PdaSeed {

  BytesSeed(this.value) {
    if (value.length > 32) {
      throw PdaDerivationException(
          'Seed too long: ${value.length} bytes (max 32)');
    }
  }
  final Uint8List value;

  @override
  Uint8List toBytes() => value;

  @override
  String toDebugString() =>
      'Bytes([${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(', ')}])';
}

/// PublicKey seed implementation
class PublicKeySeed implements PdaSeed {

  const PublicKeySeed(this.value);
  final PublicKey value;

  @override
  Uint8List toBytes() => value.toBytes();

  @override
  String toDebugString() => 'PublicKey(${value.toBase58()})';
}

/// Number seed implementation (supports various integer types)
class NumberSeed implements PdaSeed {

  const NumberSeed(this.value,
      {this.byteLength = 4, this.endianness = Endian.little});
  final int value;
  final int byteLength;
  final Endian endianness;

  @override
  Uint8List toBytes() {
    final byteData = ByteData(byteLength);

    switch (byteLength) {
      case 1:
        byteData.setUint8(0, value);
        break;
      case 2:
        byteData.setUint16(0, value, endianness);
        break;
      case 4:
        byteData.setUint32(0, value, endianness);
        break;
      case 8:
        byteData.setUint64(0, value, endianness);
        break;
      default:
        throw PdaDerivationException('Unsupported byte length: $byteLength');
    }

    return byteData.buffer.asUint8List();
  }

  @override
  String toDebugString() => 'Number($value, ${byteLength}bytes, $endianness)';
}

/// Result of PDA derivation containing the address and bump seed
class PdaResult {

  const PdaResult(this.address, this.bump);
  final PublicKey address;
  final int bump;

  @override
  String toString() => 'PdaResult(address: ${address.toBase58()}, bump: $bump)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdaResult &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          bump == other.bump;

  @override
  int get hashCode => address.hashCode ^ bump.hashCode;
}

/// Core engine for PDA derivation with optimization and validation
class PdaDerivationEngine {
  static const String _pdaMarker = 'ProgramDerivedAddress';
  static const int _maxSeedLength = 32;
  static const int _maxTotalSeedLength =
      64; // Total concatenated seed length limit

  /// Find a valid Program Derived Address for the given seeds and program ID
  ///
  /// This method implements the same algorithm as TypeScript's PublicKey.findProgramAddress,
  /// searching for a valid PDA by trying bump seeds from 255 down to 0.
  static PdaResult findProgramAddress(
      List<PdaSeed> seeds, PublicKey programId,) {
    final seedBytes = _concatenateSeeds(seeds);

    // Validate total seed length
    if (seedBytes.length > _maxTotalSeedLength) {
      throw PdaDerivationException(
        'Total seed length exceeds maximum: ${seedBytes.length} > $_maxTotalSeedLength',
      );
    }

    // Search for valid bump seed from 255 to 0
    for (int bump = 255; bump >= 0; bump--) {
      try {
        final address = _deriveProgramAddress(
            [...seeds, NumberSeed(bump, byteLength: 1)], programId,);

        // Check if the derived address is on the curve (invalid for PDA)
        if (!_isValidPda(address)) {
          continue; // Try next bump
        }

        return PdaResult(address, bump);
      } on PdaDerivationException {
        // Continue searching with next bump value
        continue;
      }
    }

    throw PdaDerivationException(
      'Unable to find a valid program address for seeds: ${_debugSeeds(seeds)}',
      code: 'PDA_NOT_FOUND',
    );
  }

  /// Create a Program Derived Address for the given seeds and program ID
  ///
  /// This method directly computes the PDA without bump seed search.
  /// Use this when you already know the correct bump seed.
  static PublicKey createProgramAddress(
      List<PdaSeed> seeds, PublicKey programId,) => _deriveProgramAddress(seeds, programId);

  /// Validate that the given address is a valid PDA for the seeds and program ID
  static bool validateProgramAddress(
    PublicKey address,
    List<PdaSeed> seeds,
    PublicKey programId,
  ) {
    try {
      final derived = _deriveProgramAddress(seeds, programId);
      return derived == address && _isValidPda(address);
    } on PdaDerivationException {
      return false;
    }
  }

  /// Derive multiple PDAs in batch for different seed combinations
  static List<PdaResult> findProgramAddressBatch(
    List<List<PdaSeed>> seedCombinations,
    PublicKey programId,
  ) => seedCombinations
        .map((seeds) => findProgramAddress(seeds, programId))
        .toList();

  /// Get detailed information about seed structure for debugging
  static String debugSeeds(List<PdaSeed> seeds) => _debugSeeds(seeds);

  /// Internal method to derive program address from seeds
  static PublicKey _deriveProgramAddress(
      List<PdaSeed> seeds, PublicKey programId,) {
    // Validate individual seed lengths
    for (final seed in seeds) {
      final seedBytes = seed.toBytes();
      if (seedBytes.length > _maxSeedLength) {
        throw PdaDerivationException(
          'Seed too long: ${seedBytes.length} bytes (max $_maxSeedLength)',
          code: 'SEED_TOO_LONG',
        );
      }
    }

    final seedBytes = _concatenateSeeds(seeds);
    final programIdBytes = programId.toBytes();
    final markerBytes = utf8.encode(_pdaMarker);

    // Concatenate: seeds + program_id + "ProgramDerivedAddress"
    final input = Uint8List.fromList([
      ...seedBytes,
      ...programIdBytes,
      ...markerBytes,
    ]);

    // SHA256 hash
    final digest = sha256.convert(input);
    final hashBytes = Uint8List.fromList(digest.bytes);

    try {
      return PublicKey.fromBytes(hashBytes);
    } catch (e) {
      throw PdaDerivationException(
        'Failed to create PublicKey from derived bytes: $e',
        code: 'INVALID_DERIVED_KEY',
      );
    }
  }

  /// Concatenate seed bytes following TypeScript's Buffer.concat behavior
  static Uint8List _concatenateSeeds(List<PdaSeed> seeds) {
    final buffer = <int>[];

    for (final seed in seeds) {
      final seedBytes = seed.toBytes();
      buffer.addAll(seedBytes);
    }

    return Uint8List.fromList(buffer);
  }

  /// Check if the address is a valid PDA (not on the ed25519 curve)
  static bool _isValidPda(PublicKey address) {
    try {
      // A valid PDA should NOT be on the ed25519 curve
      // This is equivalent to TypeScript's !PublicKey.isOnCurve()
      return !address.isOnCurve();
    } catch (e) {
      // If we can't determine curve status, assume invalid
      return false;
    }
  }

  /// Generate debug string for seeds
  static String _debugSeeds(List<PdaSeed> seeds) => '[${seeds.map((s) => s.toDebugString()).join(', ')}]';
}

/// Utility functions for common PDA operations
class PdaUtils {
  /// Create a string seed
  static StringSeed string(String value) => StringSeed(value);

  /// Create a bytes seed
  static BytesSeed bytes(Uint8List value) => BytesSeed(value);

  /// Create a PublicKey seed
  static PublicKeySeed publicKey(PublicKey value) => PublicKeySeed(value);

  /// Create a number seed (defaults to u32 little endian)
  static NumberSeed u32(int value) =>
      NumberSeed(value);

  /// Create a u8 number seed
  static NumberSeed u8(int value) => NumberSeed(value, byteLength: 1);

  /// Create a u16 number seed
  static NumberSeed u16(int value) =>
      NumberSeed(value, byteLength: 2);

  /// Create a u64 number seed
  static NumberSeed u64(int value) =>
      NumberSeed(value, byteLength: 8);

  /// Create a big endian number seed
  static NumberSeed numberBigEndian(int value, int byteLength) =>
      NumberSeed(value, byteLength: byteLength, endianness: Endian.big);
}
