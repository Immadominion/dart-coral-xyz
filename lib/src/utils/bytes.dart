/// Bytes utilities matching TypeScript Anchor SDK utils.bytes
///
/// Provides encoding and decoding utilities with exact compatibility
/// to the TypeScript Anchor SDK's utils.bytes module structure.
library;

// Export all byte-related utilities
export 'hex.dart';
export '../external/encoding_wrapper.dart' show EncodingWrapper;

import 'dart:convert';
import 'dart:typed_data';
import 'hex.dart';
import '../external/encoding_wrapper.dart';

/// Combined bytes utilities namespace
class BytesUtils {
  /// Hex encoding/decoding utilities
  static HexUtils get hex => HexUtils();

  /// UTF-8 encoding/decoding utilities
  static const Utf8Utils utf8 = Utf8Utils();

  /// Base58 encoding/decoding utilities
  static const Bs58Utils bs58 = Bs58Utils();

  /// Base64 encoding/decoding utilities
  static const Base64Utils base64 = Base64Utils();
}

/// UTF-8 utilities class
class Utf8Utils {
  const Utf8Utils();

  /// Decode bytes to UTF-8 string
  ///
  /// Matches TypeScript: utils.bytes.utf8.decode(array: Uint8Array): string
  String decode(Uint8List array) {
    return utf8.decode(array);
  }

  /// Encode string to UTF-8 bytes
  ///
  /// Matches TypeScript: utils.bytes.utf8.encode(input: string): Uint8Array
  Uint8List encode(String input) {
    return Uint8List.fromList(utf8.encode(input));
  }
}

/// Base58 utilities class
class Bs58Utils {
  const Bs58Utils();

  /// Encode bytes to base58 string
  ///
  /// Matches TypeScript: utils.bytes.bs58.encode(data: Buffer | number[] | Uint8Array)
  String encode(Uint8List data) {
    return EncodingWrapper.encodeBase58(data);
  }

  /// Decode base58 string to bytes
  ///
  /// Matches TypeScript: utils.bytes.bs58.decode(data: string)
  Uint8List decode(String data) {
    return EncodingWrapper.decodeBase58(data);
  }
}

/// Base64 utilities class
class Base64Utils {
  const Base64Utils();

  /// Encode bytes to base64 string
  ///
  /// Matches TypeScript: utils.bytes.base64.encode(data: Buffer): string
  String encode(Uint8List data) {
    return base64.encode(data);
  }

  /// Decode base64 string to bytes
  ///
  /// Matches TypeScript: utils.bytes.base64.decode(data: string): Buffer
  Uint8List decode(String data) {
    return Uint8List.fromList(base64.decode(data));
  }
}
