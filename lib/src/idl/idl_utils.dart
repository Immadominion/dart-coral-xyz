/// IDL utilities for fetching and processing on-chain IDLs
///
/// This module provides utilities for fetching IDLs from the blockchain
/// and processing them to match TypeScript Anchor client functionality.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show zlib; // For zlib inflate to match pako.inflate
import 'package:solana/dto.dart' as dto; // Espresso-cash DTOs for account data
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/provider/provider.dart';
import 'package:coral_xyz/src/idl/idl.dart';

/// IDL Program Account structure for on-chain IDL storage
class IdlProgramAccount {
  const IdlProgramAccount({required this.authority, required this.data});

  /// Authority that can update the IDL
  final PublicKey authority;

  /// Compressed IDL data
  final Uint8List data;

  /// Decode IDL program account from raw bytes (without the 8-byte discriminator)
  static IdlProgramAccount decode(Uint8List data) {
    if (data.length < 36) {
      // 32 bytes for authority + 4 bytes for length
      throw ArgumentError('IDL account data too short');
    }

    // Read authority (32 bytes)
    final authority = PublicKeyUtils.fromBytes(data.sublist(0, 32));

    // Read data length (4 bytes, little endian)
    final dataLength = _readU32LE(data, 32);

    // Read data
    const idlDataStart = 36;
    if (data.length < idlDataStart + dataLength) {
      throw ArgumentError('IDL account data length mismatch');
    }

    final idlData = data.sublist(idlDataStart, idlDataStart + dataLength);

    return IdlProgramAccount(authority: authority, data: idlData);
  }

  /// Read a 32-bit unsigned integer in little-endian format
  static int _readU32LE(Uint8List data, int offset) =>
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}

/// Utilities for fetching and processing IDLs from the blockchain
class IdlUtils {
  /// Calculate the IDL address for a given program ID
  ///
  /// This derives the deterministic address where the IDL is stored on-chain
  /// following the TypeScript implementation exactly:
  /// 1. Find program address with empty seeds
  /// 2. Create with seed using the base address
  static Future<PublicKey> getIdlAddress(PublicKey programId) async {
    // Step 1: Find the base address (like TypeScript findProgramAddress([], programId))
    final baseResult = await PublicKeyUtils.findProgramAddress(
      const <List<int>>[],
      programId,
    );
    final base = baseResult.address;

    // Step 2: Create with seed (like TypeScript createWithSeed(base, "anchor:idl", programId))
    return PublicKeyUtils.createWithSeedSync(base, 'anchor:idl', programId);
  }

  /// Fetch and decode an IDL from the blockchain
  ///
  /// This matches TypeScript Program.fetchIdl exactly:
  /// - derive idlAddress
  /// - getAccountInfo(idlAddress)
  /// - slice off 8-byte discriminator
  /// - decode IdlProgramAccount (authority, vec<u8> data)
  /// - inflate data (zlib)
  /// - parse JSON
  static Future<Idl?> fetchIdl(
    PublicKey programId,
    AnchorProvider provider,
  ) async {
    try {
      // Calculate the IDL address
      final idlAddress = await getIdlAddress(programId);

      // Fetch the account info (espresso-cash Connection expects base58 string)
      final accountInfo = await provider.connection.getAccountInfo(
        idlAddress.toBase58(),
      );

      if (accountInfo == null || accountInfo.data == null) {
        return null;
      }

      // Extract raw bytes from account data
      late final Uint8List dataBytes;
      final accData = accountInfo.data;
      if (accData is dto.BinaryAccountData) {
        dataBytes = Uint8List.fromList(accData.data);
      } else {
        // Unsupported or empty encoding
        return null;
      }

      if (dataBytes.length < 8) {
        return null; // Not enough bytes for discriminator
      }

      // Chop off 8-byte discriminator, then decode the IDL account layout
      final idlAccount = IdlProgramAccount.decode(dataBytes.sublist(8));

      // Inflate (zlib) the IDL JSON bytes; fallback to raw if not compressed
      final inflated = _inflateZlib(idlAccount.data);

      // Parse JSON to Idl
      final idlJson = utf8.decode(inflated);
      final idlMap = json.decode(idlJson) as Map<String, dynamic>;
      return Idl.fromJson(idlMap);
    } catch (e) {
      // Mirror TS: return null if not found or failed to decode
      return null;
    }
  }

  /// Convert the given IDL to camelCase (TypeScript parity)
  static Idl convertIdlToCamelCase(Idl idl) {
    const keysToConvert = ['name', 'path', 'account', 'relations', 'generic'];

    // `my_account.field` -> `myAccount.field` (preserve dots)
    String toCamelCase(dynamic s) =>
        s.toString().split('.').map(_toCamelCase).join('.');

    void recursivelyConvertNamesToCamelCase(Map<String, dynamic> obj) {
      for (final key in obj.keys.toList()) {
        final val = obj[key];
        if (keysToConvert.contains(key)) {
          if (val is List) {
            obj[key] = val.map(toCamelCase).toList();
          } else {
            obj[key] = toCamelCase(val);
          }
        } else if (val is Map<String, dynamic>) {
          recursivelyConvertNamesToCamelCase(val);
        } else if (val is List) {
          for (var i = 0; i < val.length; i++) {
            final item = val[i];
            if (item is Map<String, dynamic>) {
              recursivelyConvertNamesToCamelCase(item);
            }
          }
        }
      }
    }

    // Clone via JSON round-trip to avoid mutating original
    final idlJson = idl.toJson();
    final cloned = json.decode(json.encode(idlJson)) as Map<String, dynamic>;
    recursivelyConvertNamesToCamelCase(cloned);
    return Idl.fromJson(cloned);
  }

  /// Convert snake_case to camelCase
  static String _toCamelCase(String snakeCase) {
    if (!snakeCase.contains('_')) return snakeCase;
    final parts = snakeCase.split('_');
    final first = parts.first.toLowerCase();
    final rest = parts
        .skip(1)
        .map(
          (p) => p.isEmpty
              ? ''
              : p[0].toUpperCase() + p.substring(1).toLowerCase(),
        );
    return first + rest.join();
  }

  /// Inflate zlib-compressed bytes (like pako.inflate).
  /// Returns the decompressed data, or the original bytes if they are not
  /// zlib-compressed (e.g. already raw JSON). Throws on genuinely corrupt data.
  static Uint8List _inflateZlib(Uint8List compressed) {
    // zlib streams start with 0x78 (CMF byte with deflate method)
    if (compressed.isEmpty || compressed[0] != 0x78) {
      // Not a zlib stream — assume raw (uncompressed) data
      return compressed;
    }
    // Data looks zlib-compressed — decompress or fail
    final decoded = zlib.decode(compressed);
    return Uint8List.fromList(decoded);
  }
}
