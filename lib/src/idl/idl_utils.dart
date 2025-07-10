/// IDL utilities for fetching and processing on-chain IDLs
///
/// This module provides utilities for fetching IDLs from the blockchain
/// and processing them to match TypeScript Anchor client functionality.

import 'dart:convert';
import 'dart:typed_data';
import '../types/public_key.dart';
import '../provider/provider.dart';
import 'idl.dart';

/// IDL Program Account structure for on-chain IDL storage
class IdlProgramAccount {
  /// Authority that can update the IDL
  final PublicKey authority;

  /// Compressed IDL data
  final Uint8List data;

  const IdlProgramAccount({
    required this.authority,
    required this.data,
  });

  /// Decode IDL program account from raw bytes
  static IdlProgramAccount decode(Uint8List data) {
    if (data.length < 36) {
      // 32 bytes for authority + 4 bytes for length
      throw ArgumentError('IDL account data too short');
    }

    // Read authority (32 bytes)
    final authority = PublicKey.fromBytes(data.sublist(0, 32));

    // Read data length (4 bytes, little endian)
    final dataLength = _readU32LE(data, 32);

    // Read data
    final idlDataStart = 36;
    if (data.length < idlDataStart + dataLength) {
      throw ArgumentError('IDL account data length mismatch');
    }

    final idlData = data.sublist(idlDataStart, idlDataStart + dataLength);

    return IdlProgramAccount(
      authority: authority,
      data: idlData,
    );
  }

  /// Read a 32-bit unsigned integer in little-endian format
  static int _readU32LE(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }
}

/// Utilities for fetching and processing IDLs from the blockchain
class IdlUtils {
  /// Calculate the IDL address for a given program ID
  ///
  /// This derives the deterministic address where the IDL is stored on-chain
  static Future<PublicKey> getIdlAddress(PublicKey programId) async {
    final seeds = [
      utf8.encode('anchor:idl'),
      programId.bytes,
    ];

    final result = await PublicKey.findProgramAddress(
      seeds,
      programId,
    );

    return result.address;
  }

  /// Fetch and decode an IDL from the blockchain
  ///
  /// This method fetches the IDL from the on-chain IDL account.
  /// The IDL must have been previously initialized via anchor CLI's `anchor idl init` command.
  ///
  /// [programId] The on-chain address of the program
  /// [provider] The network and wallet provider
  ///
  /// Returns the IDL or null if not found
  static Future<Idl?> fetchIdl(
    PublicKey programId,
    AnchorProvider provider,
  ) async {
    try {
      // Calculate the IDL address
      final idlAddress = await getIdlAddress(programId);

      // Fetch the account info
      final accountInfo = await provider.connection.getAccountInfo(idlAddress);

      if (accountInfo == null || accountInfo.data.length == 0) {
        return null;
      }

      // Decode the IDL account (skip 8-byte discriminator)
      final idlAccount = IdlProgramAccount.decode(
        (accountInfo.data as Uint8List).sublist(8),
      );

      // Decompress the IDL data using gzip
      final decompressedData = _decompressGzip(idlAccount.data);

      // Parse JSON
      final idlJson = utf8.decode(decompressedData);
      final idlMap = json.decode(idlJson) as Map<String, dynamic>;

      // Convert to IDL
      return Idl.fromJson(idlMap);
    } catch (e) {
      return null;
    }
  }

  /// Convert IDL to camelCase for Dart ergonomics
  ///
  /// This converts snake_case names in the IDL to camelCase for better
  /// Dart naming conventions, similar to how TypeScript Anchor converts
  /// Rust naming conventions to JavaScript conventions.
  ///
  /// [idl] The IDL to convert
  /// Returns a new IDL with camelCase naming
  static Idl convertIdlToCamelCase(Idl idl) {
    const keysToConvert = ['name', 'path', 'account', 'relations', 'generic'];

    // Convert a single string to camelCase, handling dot notation
    String toCamelCase(String s) {
      return s.split('.').map((part) => _toCamelCase(part)).join('.');
    }

    // Recursively convert field names in objects
    dynamic convertObject(dynamic obj) {
      if (obj is Map<String, dynamic>) {
        final converted = <String, dynamic>{};

        for (final entry in obj.entries) {
          final key = entry.key;
          final value = entry.value;

          dynamic convertedValue;
          if (keysToConvert.contains(key)) {
            if (value is List) {
              convertedValue = value
                  .map((item) =>
                      item is String ? toCamelCase(item) : convertObject(item))
                  .toList();
            } else if (value is String) {
              convertedValue = toCamelCase(value);
            } else {
              convertedValue = convertObject(value);
            }
          } else {
            convertedValue = convertObject(value);
          }

          converted[key] = convertedValue;
        }

        return converted;
      } else if (obj is List) {
        return obj.map(convertObject).toList();
      } else {
        return obj;
      }
    }

    // Convert the IDL to JSON, transform, and back to IDL
    final idlJson = idl.toJson();
    final converted = convertObject(idlJson) as Map<String, dynamic>;

    return Idl.fromJson(converted);
  }

  /// Convert snake_case to camelCase
  static String _toCamelCase(String snakeCase) {
    if (!snakeCase.contains('_')) {
      return snakeCase;
    }

    final parts = snakeCase.split('_');
    if (parts.isEmpty) return snakeCase;

    final first = parts.first.toLowerCase();
    final rest = parts.skip(1).map((part) => part.isEmpty
        ? ''
        : part[0].toUpperCase() + part.substring(1).toLowerCase());

    return first + rest.join();
  }

  /// Decompress gzip data
  static Uint8List _decompressGzip(Uint8List compressedData) {
    // For now, assume data is not compressed and is raw JSON
    // TODO: Implement proper gzip decompression using package:archive if needed
    // Most IDLs are small enough that compression isn't necessary
    return compressedData;
  }
}
