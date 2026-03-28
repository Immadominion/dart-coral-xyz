/// Address and key utilities for Solana and Anchor programs
///
/// This module provides comprehensive utilities for working with Solana addresses,
/// including PDA derivation, address validation, key format conversion,
/// and address formatting utilities.

library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/idl/idl.dart';

/// Address utilities for Solana and Anchor programs
class AddressUtils {
  /// Standard seed string used in many Anchor programs
  static const String anchorSeed = 'anchor';

  /// Convert a string to bytes for use as a PDA seed
  ///
  /// This converts a string to UTF-8 bytes for use in PDA derivation.
  static Uint8List stringToSeedBytes(String seed) =>
      Uint8List.fromList(utf8.encode(seed));

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
      return Uint8List.fromList(seed.bytes);
    } else if (seed is Uint8List) {
      return seed;
    } else if (seed is List<int>) {
      return Uint8List.fromList(seed);
    } else {
      throw ArgumentError('Unsupported seed type: ${seed.runtimeType}');
    }
  }

  /// Convert multiple seeds to byte arrays
  static List<Uint8List> toSeedBytesList(List<dynamic> seeds) =>
      seeds.map(toSeedBytes).toList();

  /// Derive a PDA from seeds and program ID
  ///
  /// This is a convenience method for PDA derivation that accepts mixed seed types.
  static Future<PdaResult> derivePda(
    List<dynamic> seeds,
    PublicKey programId,
  ) async {
    final seedBytes = toSeedBytesList(seeds);
    return PublicKeyUtils.findProgramAddress(seedBytes, programId);
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

    return PublicKeyUtils.findProgramAddress(seedBytes, programId);
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
        return Uint8List.fromList(account.bytes);
      } else if (account is String) {
        return Uint8List.fromList(PublicKey.fromBase58(account).bytes);
      } else {
        throw ArgumentError(
          'Invalid account type for seed: ${account.runtimeType}',
        );
      }
    } else {
      throw ArgumentError('Unknown seed type: ${seed.runtimeType}');
    }
  }
}

/// Address formatting and display utilities
class AddressFormatter {
  /// Shorten an address for display purposes
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
}
