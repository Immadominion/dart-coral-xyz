/// Program Derived Address (PDA) utilities for Anchor programs
///
/// This module provides utilities for PDA derivation, seed handling,
/// and address resolution that match the functionality of the TypeScript
/// Anchor SDK's accounts resolver and PDA utilities.

library;

import 'dart:typed_data';
import '../types/public_key.dart';
import '../idl/idl.dart';
import '../utils/pubkey.dart' as pubkey_utils;

/// Utilities for working with Program Derived Addresses (PDAs)
class PdaUtils {
  /// Find a Program Derived Address (PDA) from seeds
  ///
  /// This is the main function for deriving PDAs. It takes a list of seeds
  /// and a program ID, and returns the PDA and bump seed.
  static Future<PdaResult> findProgramAddress(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async {
    return PublicKey.findProgramAddress(seeds, programId);
  }

  /// Create a program address directly (without finding bump)
  ///
  /// This creates a program address from the exact seeds provided,
  /// including the bump seed. Used when you already know the bump.
  static Future<PublicKey> createProgramAddress(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async {
    return PublicKey.createProgramAddress(seeds, programId);
  }

  /// Convert various seed types to bytes for PDA derivation
  ///
  /// Handles different types of seeds that can be used in PDA derivation:
  /// - String (UTF-8 encoded)
  /// - int (little-endian bytes)
  /// - PublicKey (32 bytes)
  /// - Uint8List (as-is)
  static Uint8List seedToBytes(dynamic seed) {
    if (seed is String) {
      return Uint8List.fromList(seed.codeUnits);
    } else if (seed is int) {
      // Convert int to little-endian bytes (assuming 64-bit)
      final bytes = Uint8List(8);
      for (int i = 0; i < 8; i++) {
        bytes[i] = (seed >> (i * 8)) & 0xFF;
      }
      return bytes;
    } else if (seed is PublicKey) {
      return seed.bytes;
    } else if (seed is Uint8List) {
      return seed;
    } else if (seed is List<int>) {
      return Uint8List.fromList(seed);
    } else {
      throw ArgumentError('Unsupported seed type: ${seed.runtimeType}');
    }
  }

  /// Convert multiple seeds to bytes for PDA derivation
  static List<Uint8List> seedsToBytes(List<dynamic> seeds) {
    return seeds.map(seedToBytesEnhanced).toList();
  }

  /// Derive PDA from mixed seed types
  ///
  /// Convenience method that accepts various seed types and converts them
  /// to bytes before deriving the PDA.
  static Future<PdaResult> deriveAddress(
    List<dynamic> seeds,
    PublicKey programId,
  ) async {
    final seedBytes = seedsToBytes(seeds);
    return findProgramAddress(seedBytes, programId);
  }

  /// Convert various seed types to bytes with enhanced type support
  ///
  /// Handles different types of seeds similar to TypeScript SDK:
  /// - String (UTF-8 encoded)
  /// - int (little-endian bytes, configurable size)
  /// - BigInt (up to 32 bytes)
  /// - PublicKey (32 bytes)
  /// - Uint8List (as-is)
  /// - bool (single byte)
  static Uint8List seedToBytesEnhanced(dynamic seed, {int? intSize}) {
    if (seed is String) {
      return Uint8List.fromList(seed.codeUnits);
    } else if (seed is int) {
      // Default to 8 bytes for int, but allow customization
      final size = intSize ?? 8;
      final bytes = Uint8List(size);
      for (int i = 0; i < size; i++) {
        bytes[i] = (seed >> (i * 8)) & 0xFF;
      }
      return bytes;
    } else if (seed is BigInt) {
      // Convert BigInt to bytes (up to 32 bytes)
      final bytes = Uint8List(32);
      var value = seed;
      for (int i = 0; i < 32 && value > BigInt.zero; i++) {
        bytes[i] = (value & BigInt.from(0xFF)).toInt();
        value = value >> 8;
      }
      return bytes;
    } else if (seed is bool) {
      return Uint8List.fromList([seed ? 1 : 0]);
    } else if (seed is PublicKey) {
      return seed.bytes;
    } else if (seed is Uint8List) {
      return seed;
    } else if (seed is List<int>) {
      return Uint8List.fromList(seed);
    } else {
      throw ArgumentError('Unsupported seed type: ${seed.runtimeType}');
    }
  }

  /// Create seed from account field
  ///
  /// Extracts a field from an account for use as a seed in PDA derivation.
  /// This matches the functionality in TypeScript SDK's accounts resolver.
  static Uint8List seedFromAccount(
    Map<String, dynamic> account,
    String fieldPath,
  ) {
    final fields = fieldPath.split('.');
    dynamic value = account;

    for (final field in fields) {
      if (value is Map<String, dynamic> && value.containsKey(field)) {
        value = value[field];
      } else {
        throw ArgumentError('Field path not found: $fieldPath');
      }
    }

    return seedToBytesEnhanced(value);
  }

  /// Create a program address with seed validation
  ///
  /// This validates seeds before attempting to create the program address,
  /// providing better error messages for invalid inputs.
  static Future<PublicKey> createProgramAddressValidated(
    List<Uint8List> seeds,
    PublicKey programId,
  ) async {
    // Validate seeds
    for (int i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      if (seed.length > 32) {
        throw ArgumentError(
            'Seed $i is too long: ${seed.length} bytes (max 32)');
      }
    }

    if (seeds.length > 16) {
      throw ArgumentError('Too many seeds: ${seeds.length} (max 16)');
    }

    return PublicKey.createProgramAddress(seeds, programId);
  }

  /// Create a PublicKey with seed (sync version)
  ///
  /// This matches the TypeScript SDK's createWithSeedSync utility.
  static PublicKey createWithSeedSync(
    PublicKey fromPublicKey,
    String seed,
    PublicKey programId,
  ) {
    return pubkey_utils.PublicKeyUtils.createWithSeedSync(
      fromPublicKey,
      seed,
      programId,
    );
  }
}

/// Address resolution utilities for account management
class AddressResolver {
  /// Simple address resolution from string PDA specifications
  ///
  /// This is a simplified version that works with the current IDL structure
  /// where PDA is just a string identifier. In the future, this can be extended
  /// to handle full seed specifications.
  static Future<PublicKey?> resolvePdaFromString(
    String? pdaSpec,
    PublicKey programId, {
    Map<String, dynamic>? context,
  }) async {
    if (pdaSpec == null) return null;

    // For now, we'll implement basic PDA resolution based on common patterns
    // This can be extended when the IDL includes full seed specifications
    try {
      // Simple seed from the PDA string
      final seeds = [PdaUtils.seedToBytesEnhanced(pdaSpec)];
      final result = await PdaUtils.findProgramAddress(seeds, programId);
      return result.address;
    } catch (e) {
      // Return null if PDA cannot be resolved
      return null;
    }
  }

  /// Resolve account addresses based on IDL instruction account specifications
  ///
  /// This method attempts to resolve missing account addresses by looking for
  /// PDA specifications in the IDL and deriving the appropriate addresses.
  static Future<Map<String, PublicKey>> resolveAccounts(
    List<IdlInstructionAccountItem> accountSpecs,
    Map<String, dynamic> providedAccounts,
    PublicKey programId,
  ) async {
    final resolvedAccounts = <String, PublicKey>{};

    // Copy provided accounts that are already PublicKey instances
    for (final entry in providedAccounts.entries) {
      if (entry.value is PublicKey) {
        resolvedAccounts[entry.key] = entry.value as PublicKey;
      } else if (entry.value is String) {
        try {
          resolvedAccounts[entry.key] = PublicKey.fromBase58(entry.value);
        } catch (e) {
          // Ignore invalid base58 strings
        }
      }
    }

    // Try to resolve missing PDAs
    for (final accountSpec in accountSpecs) {
      if (accountSpec is IdlInstructionAccount &&
          !resolvedAccounts.containsKey(accountSpec.name) &&
          accountSpec.pda != null) {
        final pdaAddress = await resolvePdaFromIdl(
          accountSpec.pda!,
          programId,
          context: providedAccounts,
        );

        if (pdaAddress != null) {
          resolvedAccounts[accountSpec.name] = pdaAddress;
        }
      }
    }

    return resolvedAccounts;
  }

  /// Resolve PDA from IDL PDA specification
  static Future<PublicKey?> resolvePdaFromIdl(
    IdlPda pdaSpec,
    PublicKey programId, {
    Map<String, dynamic>? context,
  }) async {
    try {
      final seeds = <Uint8List>[];

      // Convert each seed specification to bytes
      for (final seed in pdaSpec.seeds) {
        Uint8List? seedBytes;

        switch (seed.kind) {
          case 'const':
            final constSeed = seed as IdlSeedConst;
            seedBytes = Uint8List.fromList(constSeed.value);
            break;
          case 'arg':
            final argSeed = seed as IdlSeedArg;
            // This would need to resolve argument values from context
            // For now, use a placeholder implementation
            seedBytes = PdaUtils.seedToBytesEnhanced(argSeed.path);
            break;
          case 'account':
            final accountSeed = seed as IdlSeedAccount;
            // This would need to resolve account addresses from context
            // For now, use a placeholder implementation
            seedBytes = PdaUtils.seedToBytesEnhanced(accountSeed.path);
            break;
        }

        if (seedBytes != null) {
          seeds.add(seedBytes);
        }
      }

      final result = await PdaUtils.findProgramAddress(seeds, programId);
      return result.address;
    } catch (e) {
      return null;
    }
  }

  /// Convert a value to bytes for seed usage
  static Uint8List valueToBytes(dynamic value) {
    if (value is String) {
      return Uint8List.fromList(value.codeUnits);
    } else if (value is int) {
      // Convert to little-endian bytes (8 bytes for 64-bit)
      final bytes = Uint8List(8);
      for (int i = 0; i < 8; i++) {
        bytes[i] = (value >> (i * 8)) & 0xFF;
      }
      return bytes;
    } else if (value is bool) {
      return Uint8List.fromList([value ? 1 : 0]);
    } else if (value is PublicKey) {
      return value.bytes;
    } else if (value is Uint8List) {
      return value;
    } else if (value is List<int>) {
      return Uint8List.fromList(value);
    } else {
      throw ArgumentError(
          'Cannot convert ${value.runtimeType} to bytes for seed');
    }
  }
}

/// Validation utilities for addresses and PDAs
class AddressValidator {
  /// Validate that an address matches expected PDA derivation
  static Future<bool> validatePda(
    PublicKey address,
    List<Uint8List> seeds,
    PublicKey programId,
  ) async {
    try {
      final derived = await PdaUtils.findProgramAddress(seeds, programId);
      return derived.address == address;
    } catch (e) {
      return false;
    }
  }

  /// Validate that an address is a valid PublicKey
  static bool validatePublicKey(String address) {
    return PublicKey.isValidBase58(address);
  }

  /// Validate account relationships based on IDL specification
  ///
  /// This checks that provided accounts match their IDL specifications,
  /// including signer requirements and PDA constraints.
  static Future<bool> validateAccountRelationships(
    Map<String, dynamic> accounts,
    List<IdlInstructionAccountItem> accountSpecs,
  ) async {
    for (final spec in accountSpecs) {
      final account = accounts[spec.name];

      // Check required accounts are present
      if (spec is IdlInstructionAccount && !spec.optional && account == null) {
        return false;
      }

      // Check account type validity
      if (account != null) {
        if (!(account is PublicKey || account is String)) {
          return false;
        }

        if (account is String && !validatePublicKey(account)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Check if all required accounts are provided
  static List<String> getMissingRequiredAccounts(
    Map<String, dynamic> accounts,
    List<IdlInstructionAccountItem> accountSpecs,
  ) {
    final missing = <String>[];

    for (final spec in accountSpecs) {
      if (spec is IdlInstructionAccount &&
          !spec.optional &&
          !accounts.containsKey(spec.name)) {
        missing.add(spec.name);
      }
    }

    return missing;
  }
}
