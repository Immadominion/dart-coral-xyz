/// Address and key utilities for Solana and Anchor programs
///
/// This module provides comprehensive utilities for working with Solana addresses,
/// including PDA derivation, address validation, key format conversion,
/// and address formatting utilities.

library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';

/// Address utilities for Solana and Anchor programs
class AddressUtils {
  /// Standard seed string used in many Anchor programs
  static const String anchorSeed = 'anchor';

  /// Convert a string to bytes for use as a PDA seed
  ///
  /// This converts a string to UTF-8 bytes for use in PDA derivation.
  static Uint8List stringToSeedBytes(String seed) => Uint8List.fromList(utf8.encode(seed));

  /// Convert an integer to bytes for use as a PDA seed
  ///
  /// Converts an integer to little-endian bytes. The [size] parameter
  /// determines how many bytes to use (1, 2, 4, or 8).
  static Uint8List intToSeedBytes(int value, {int size = 8}) {
    switch (size) {
      case 1:
        return Uint8List.fromList([value & 0xFF]);
      case 2:
        return Uint8List(2)
          ..buffer.asByteData().setUint16(0, value, Endian.little);
      case 4:
        return Uint8List(4)
          ..buffer.asByteData().setUint32(0, value, Endian.little);
      case 8:
        return Uint8List(8)
          ..buffer.asByteData().setUint64(0, value, Endian.little);
      default:
        throw ArgumentError('Unsupported size: $size. Use 1, 2, 4, or 8.');
    }
  }

  /// Convert a big integer to bytes for use as a PDA seed
  ///
  /// For very large numbers that don't fit in a standard int.
  static Uint8List bigIntToSeedBytes(BigInt value, {int size = 8}) {
    final bytes = Uint8List(size);
    var tempValue = value;

    for (int i = 0; i < size; i++) {
      bytes[i] = (tempValue & BigInt.from(0xFF)).toInt();
      tempValue = tempValue >> 8;
    }

    return bytes;
  }

  /// Convert any object to PDA seed bytes
  ///
  /// This is a general-purpose seed converter that handles common types:
  /// - String: UTF-8 encoded
  /// - int: Little-endian bytes
  /// - BigInt: Little-endian bytes
  /// - PublicKey: 32-byte address
  /// - Uint8List: As-is
  /// - `List<int>`: Converted to Uint8List
  static Uint8List toSeedBytes(dynamic seed) {
    if (seed is String) {
      return stringToSeedBytes(seed);
    } else if (seed is int) {
      return intToSeedBytes(seed);
    } else if (seed is BigInt) {
      return bigIntToSeedBytes(seed);
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

  /// Convert multiple seeds to byte arrays
  static List<Uint8List> toSeedBytesList(List<dynamic> seeds) => seeds.map(toSeedBytes).toList();

  /// Derive a PDA from seeds and program ID
  ///
  /// This is a convenience method for PDA derivation that accepts mixed seed types.
  static Future<PdaResult> derivePda(
    List<dynamic> seeds,
    PublicKey programId,
  ) async {
    final seedBytes = toSeedBytesList(seeds);
    return PublicKey.findProgramAddress(seedBytes, programId);
  }

  /// Derive a PDA from IDL seed specifications
  ///
  /// This method uses IDL seed definitions to derive PDAs automatically.
  static Future<PdaResult> derivePdaFromIdl(
    IdlPda pdaSpec,
    PublicKey programId, {
    Map<String, dynamic>? context,
  }) async {
    final seedBytes = <Uint8List>[];

    for (final seed in pdaSpec.seeds) {
      final bytes = await _convertIdlSeedToBytes(seed, context);
      seedBytes.add(bytes);
    }

    return PublicKey.findProgramAddress(seedBytes, programId);
  }

  /// Convert an IDL seed specification to bytes
  static Future<Uint8List> _convertIdlSeedToBytes(
    IdlSeed seed,
    Map<String, dynamic>? context,
  ) async {
    if (seed is IdlSeedConst) {
      return toSeedBytes(seed.value);
    } else if (seed is IdlSeedArg) {
      if (context == null || !context.containsKey(seed.path)) {
        throw ArgumentError('Missing seed argument: ${seed.path}');
      }
      return toSeedBytes(context[seed.path]);
    } else if (seed is IdlSeedAccount) {
      if (context == null || !context.containsKey(seed.path)) {
        throw ArgumentError('Missing seed account: ${seed.path}');
      }
      final account = context[seed.path];
      if (account is PublicKey) {
        return account.bytes;
      } else if (account is String) {
        return PublicKey.fromBase58(account).bytes;
      } else {
        throw ArgumentError(
            'Invalid account type for seed: ${account.runtimeType}',);
      }
    } else {
      throw ArgumentError('Unknown seed type: ${seed.runtimeType}');
    }
  }
}

/// Address validation utilities
class AddressValidator {
  /// Validate a base58 address string
  ///
  /// Returns true if the string is a valid base58-encoded Solana address.
  static bool isValidBase58(String address) {
    try {
      PublicKey.fromBase58(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate a hex address string
  ///
  /// Returns true if the string is a valid hex-encoded Solana address.
  static bool isValidHex(String address) {
    try {
      PublicKey.fromHex(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if an address is the system program
  static bool isSystemProgram(PublicKey address) => address == PublicKey.systemProgram;

  /// Check if an address is the default (all zeros) address
  static bool isDefaultAddress(PublicKey address) => address == PublicKey.defaultPubkey;

  /// Validate that an address matches expected PDA derivation
  ///
  /// This method derives a PDA from the given seeds and checks if it matches
  /// the provided address.
  static Future<bool> validatePda(
    PublicKey address,
    List<dynamic> seeds,
    PublicKey programId,
  ) async {
    try {
      final result = await AddressUtils.derivePda(seeds, programId);
      return result.address == address;
    } catch (e) {
      return false;
    }
  }

  /// Validate that an address matches IDL PDA specification
  static Future<bool> validatePdaFromIdl(
    PublicKey address,
    IdlPda pdaSpec,
    PublicKey programId, {
    Map<String, dynamic>? context,
  }) async {
    try {
      final result = await AddressUtils.derivePdaFromIdl(pdaSpec, programId,
          context: context,);
      return result.address == address;
    } catch (e) {
      return false;
    }
  }
}

/// Address formatting and display utilities
class AddressFormatter {
  /// Shorten an address for display purposes
  ///
  /// Shows the first [prefixLength] and last [suffixLength] characters
  /// with an ellipsis in between.
  static String shortenAddress(
    String address, {
    int prefixLength = 4,
    int suffixLength = 4,
    String separator = '...',
  }) {
    if (address.length <= prefixLength + suffixLength) {
      return address;
    }

    return '${address.substring(0, prefixLength)}'
        '$separator'
        '${address.substring(address.length - suffixLength)}';
  }

  /// Format an address as a shortened base58 string
  static String formatShortBase58(
    PublicKey address, {
    int prefixLength = 4,
    int suffixLength = 4,
  }) => shortenAddress(
      address.toBase58(),
      prefixLength: prefixLength,
      suffixLength: suffixLength,
    );

  /// Format an address for display with optional shortening
  static String formatAddress(
    PublicKey address, {
    AddressFormat format = AddressFormat.base58,
    bool shorten = false,
    int prefixLength = 4,
    int suffixLength = 4,
  }) {
    String formatted;

    switch (format) {
      case AddressFormat.base58:
        formatted = address.toBase58();
        break;
      case AddressFormat.hex:
        formatted = '0x${address.toHex()}';
        break;
      case AddressFormat.hexNoPrefix:
        formatted = address.toHex();
        break;
    }

    if (shorten) {
      return shortenAddress(
        formatted,
        prefixLength: prefixLength,
        suffixLength: suffixLength,
      );
    }

    return formatted;
  }

  /// Create a human-readable label for common addresses
  static String labelAddress(PublicKey address) {
    if (address == PublicKey.systemProgram) {
      return 'System Program';
    } else if (address == PublicKey.defaultPubkey) {
      return 'Default Address';
    } else {
      return formatShortBase58(address);
    }
  }
}

/// Key conversion utilities
class KeyConverter {
  /// Convert a base58 address to hex
  static String base58ToHex(String base58Address, {bool includePrefix = true}) {
    final publicKey = PublicKey.fromBase58(base58Address);
    final hex = publicKey.toHex();
    return includePrefix ? '0x$hex' : hex;
  }

  /// Convert a hex address to base58
  static String hexToBase58(String hexAddress) {
    // Remove 0x prefix if present
    final cleanHex =
        hexAddress.startsWith('0x') ? hexAddress.substring(2) : hexAddress;
    final publicKey = PublicKey.fromHex(cleanHex);
    return publicKey.toBase58();
  }

  /// Convert bytes to base58 address
  static String bytesToBase58(Uint8List bytes) {
    final publicKey = PublicKey.fromBytes(bytes);
    return publicKey.toBase58();
  }

  /// Convert bytes to hex address
  static String bytesToHex(Uint8List bytes, {bool includePrefix = true}) {
    final publicKey = PublicKey.fromBytes(bytes);
    final hex = publicKey.toHex();
    return includePrefix ? '0x$hex' : hex;
  }

  /// Parse an address string in any supported format
  static PublicKey parseAddress(String address) {
    // Try base58 first (most common)
    try {
      return PublicKey.fromBase58(address);
    } catch (e) {
      // Try hex format
      try {
        return PublicKey.fromHex(address);
      } catch (e) {
        throw ArgumentError('Invalid address format: $address');
      }
    }
  }
}

/// Seed generation utilities for common patterns
class SeedGenerator {
  /// Generate seeds for a user account PDA
  ///
  /// Common pattern: `["user", user_pubkey]`
  static List<dynamic> userSeeds(PublicKey userPubkey) => ['user', userPubkey];

  /// Generate seeds for a token account PDA
  ///
  /// Common pattern: `["token", mint_pubkey, owner_pubkey]`
  static List<dynamic> tokenAccountSeeds(PublicKey mint, PublicKey owner) => ['token', mint, owner];

  /// Generate seeds for a metadata account
  ///
  /// Common pattern: `["metadata", program_id, mint_pubkey]`
  static List<dynamic> metadataSeeds(PublicKey programId, PublicKey mint) => ['metadata', programId, mint];

  /// Generate seeds for a vault account
  ///
  /// Common pattern: `["vault", authority_pubkey]`
  static List<dynamic> vaultSeeds(PublicKey authority) => ['vault', authority];

  /// Generate seeds for a numbered account
  ///
  /// Common pattern: `["account", number]`
  static List<dynamic> numberedSeeds(String prefix, int number) => [prefix, number];

  /// Generate seeds with custom prefix and dynamic components
  static List<dynamic> customSeeds(String prefix, List<dynamic> components) => [prefix, ...components];
}

/// Address format options
enum AddressFormat {
  /// Base58 encoding (standard Solana format)
  base58,

  /// Hex encoding with 0x prefix
  hex,

  /// Hex encoding without prefix
  hexNoPrefix,
}
