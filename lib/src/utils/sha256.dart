/// SHA256 utilities matching TypeScript Anchor SDK utils.sha256
///
/// Provides SHA256 hashing functionality with exact compatibility
/// to the TypeScript Anchor SDK's utils.sha256 module.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// SHA256 utilities class
class SHA256Utils {
  /// Hash a string and return the result as a string
  ///
  /// Matches TypeScript: utils.sha256.hash(data: string): string
  static String hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return utf8.decode(digest.bytes);
  }

  /// Hash bytes and return the result as bytes
  ///
  /// Additional utility for working with binary data
  static Uint8List hashBytes(Uint8List data) {
    final digest = sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Hash a string and return the result as hex string
  ///
  /// Additional utility for hex output
  static String hashToHex(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
