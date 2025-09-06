/// Hex encoding/decoding utilities matching TypeScript Anchor SDK utils.bytes.hex
///
/// Provides hex encoding and decoding functionality with exact compatibility
/// to the TypeScript Anchor SDK's utils.bytes.hex module.
library;

import 'dart:typed_data';

/// Hex encoding and decoding utilities
class HexUtils {
  /// Encode bytes to hex string with 0x prefix
  ///
  /// Matches TypeScript: utils.bytes.hex.encode(data: Buffer): string
  static String encode(Uint8List data) {
    return '0x${data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Decode hex string to bytes
  ///
  /// Matches TypeScript: utils.bytes.hex.decode(data: string): Buffer
  static Uint8List decode(String data) {
    // Remove 0x prefix if present
    if (data.indexOf('0x') == 0) {
      data = data.substring(2);
    }

    // Pad with leading zero if odd length
    if (data.length % 2 == 1) {
      data = '0$data';
    }

    // Handle empty string
    if (data.isEmpty) {
      return Uint8List(0);
    }

    // Split into pairs and convert
    final List<String> pairs = [];
    for (int i = 0; i < data.length; i += 2) {
      pairs.add(data.substring(i, i + 2));
    }

    return Uint8List.fromList(
      pairs.map((pair) => int.parse(pair, radix: 16)).toList(),
    );
  }

  /// Encode bytes to hex string without 0x prefix
  ///
  /// Additional utility for plain hex encoding
  static String encodeWithoutPrefix(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Check if a string is valid hex
  ///
  /// Additional utility for validation
  static bool isValid(String hex) {
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    return RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex);
  }
}
