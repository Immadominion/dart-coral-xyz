/// Wrapper for encoding functionality (Base58, Base64, etc.)
///
/// This module provides a consistent interface to various encoding operations
/// by wrapping external encoding packages and providing additional
/// Anchor-specific functionality.

library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:bs58/bs58.dart' as bs58_lib;

/// Wrapper around encoding operations with Anchor-specific enhancements
class EncodingWrapper {
  /// Encode bytes to Base58 string (Bitcoin alphabet)
  static String encodeBase58(Uint8List bytes) {
    try {
      return bs58_lib.base58.encode(bytes);
    } catch (e) {
      throw EncodingException('Failed to encode Base58: $e');
    }
  }

  /// Decode Base58 string to bytes
  static Uint8List decodeBase58(String encoded) {
    try {
      return Uint8List.fromList(bs58_lib.base58.decode(encoded));
    } catch (e) {
      throw EncodingException('Failed to decode Base58: $e');
    }
  }

  /// Encode bytes to Base64 string
  static String encodeBase64(Uint8List bytes) {
    return base64.encode(bytes);
  }

  /// Decode Base64 string to bytes
  static Uint8List decodeBase64(String encoded) {
    return base64.decode(encoded);
  }

  /// Encode bytes to hexadecimal string
  static String encodeHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Decode hexadecimal string to bytes
  static Uint8List decodeHex(String hex) {
    if (hex.length % 2 != 0) {
      throw EncodingException('Hex string must have even length');
    }

    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      final byte = int.parse(hex.substring(i, i + 2), radix: 16);
      result[i ~/ 2] = byte;
    }
    return result;
  }

  /// Convert string to UTF-8 bytes
  static Uint8List stringToBytes(String str) {
    return Uint8List.fromList(utf8.encode(str));
  }

  /// Convert UTF-8 bytes to string
  static String bytesToString(Uint8List bytes) {
    return utf8.decode(bytes);
  }

  /// Validate Base58 string format
  static bool isValidBase58(String str) {
    // TODO: Implement proper Base58 validation
    return str.isNotEmpty && !str.contains(RegExp(r'[0OIl]')); // Basic check
  }
}

/// Exception thrown by encoding operations
class EncodingException implements Exception {
  final String message;

  const EncodingException(this.message);

  @override
  String toString() => 'EncodingException: $message';
}
