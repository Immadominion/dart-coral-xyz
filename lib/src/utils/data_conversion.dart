/// Data conversion utilities for the Anchor Dart client
///
/// This module provides a comprehensive set of utilities for converting between
/// different data formats commonly used in Solana/Anchor development, including:
/// - Byte buffer manipulation and validation
/// - Base58/Base64/Hex encoding and decoding
/// - Number conversion utilities (including BigInt support)
/// - Endianness handling utilities
/// - Data validation functions
///
/// Inspired by the TypeScript anchor utils/bytes module and extends it with
/// Dart-specific functionality for robust data handling.

library;

import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:bs58/bs58.dart' as bs58_lib;

/// Exception thrown by data conversion utilities
class DataConversionException implements Exception {
  final String message;
  const DataConversionException(this.message);

  @override
  String toString() => 'DataConversionException: $message';
}

/// Comprehensive data conversion utilities
class DataConverter {
  // ============================================================================
  // Bytes/Buffer Manipulation Utilities
  // ============================================================================

  /// Create a buffer with the specified size, optionally filled with a value
  static Uint8List createBuffer(int size, [int fillValue = 0]) {
    if (size < 0) {
      throw DataConversionException('Buffer size cannot be negative');
    }
    final buffer = Uint8List(size);
    if (fillValue != 0) {
      buffer.fillRange(0, size, fillValue);
    }
    return buffer;
  }

  /// Concatenate multiple byte arrays
  static Uint8List concat(List<Uint8List> arrays) {
    if (arrays.isEmpty) return Uint8List(0);

    final totalLength = arrays.fold<int>(0, (sum, arr) => sum + arr.length);
    final result = Uint8List(totalLength);

    int offset = 0;
    for (final array in arrays) {
      result.setRange(offset, offset + array.length, array);
      offset += array.length;
    }

    return result;
  }

  /// Copy bytes from source to destination with optional offset and length
  static void copyBytes(
    Uint8List source,
    Uint8List destination, {
    int sourceStart = 0,
    int? sourceEnd,
    int destinationStart = 0,
  }) {
    sourceEnd ??= source.length;

    if (sourceStart < 0 ||
        sourceEnd > source.length ||
        sourceStart > sourceEnd) {
      throw DataConversionException('Invalid source range');
    }

    final length = sourceEnd - sourceStart;
    if (destinationStart < 0 ||
        destinationStart + length > destination.length) {
      throw DataConversionException('Invalid destination range');
    }

    destination.setRange(
      destinationStart,
      destinationStart + length,
      source,
      sourceStart,
    );
  }

  /// Slice bytes from the given array
  static Uint8List slice(Uint8List source, int start, [int? end]) {
    end ??= source.length;

    if (start < 0) start = math.max(0, source.length + start);
    if (end < 0) end = math.max(0, source.length + end);

    start = math.max(0, math.min(start, source.length));
    end = math.max(start, math.min(end, source.length));

    return source.sublist(start, end);
  }

  /// Compare two byte arrays for equality
  static bool equals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Check if array starts with the given prefix
  static bool startsWith(Uint8List array, Uint8List prefix) {
    if (prefix.length > array.length) return false;
    return equals(slice(array, 0, prefix.length), prefix);
  }

  /// Pad bytes to the specified length (left padding with zeros)
  static Uint8List padLeft(Uint8List bytes, int length, [int padValue = 0]) {
    if (bytes.length >= length) return bytes;

    final result = Uint8List(length);
    result.fillRange(0, length - bytes.length, padValue);
    result.setRange(length - bytes.length, length, bytes);
    return result;
  }

  /// Pad bytes to the specified length (right padding with zeros)
  static Uint8List padRight(Uint8List bytes, int length, [int padValue = 0]) {
    if (bytes.length >= length) return bytes;

    final result = Uint8List(length);
    result.setRange(0, bytes.length, bytes);
    result.fillRange(bytes.length, length, padValue);
    return result;
  }

  // ============================================================================
  // Base58 Encoding/Decoding Utilities
  // ============================================================================

  /// Encode bytes to Base58 string using Bitcoin alphabet
  static String encodeBase58(Uint8List bytes) {
    try {
      return bs58_lib.base58.encode(bytes);
    } catch (e) {
      throw DataConversionException('Failed to encode Base58: $e');
    }
  }

  /// Decode Base58 string to bytes
  static Uint8List decodeBase58(String encoded) {
    try {
      return Uint8List.fromList(bs58_lib.base58.decode(encoded));
    } catch (e) {
      throw DataConversionException('Failed to decode Base58: $e');
    }
  }

  /// Validate Base58 string format
  static bool isValidBase58(String input) {
    try {
      decodeBase58(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================================
  // Base64 Encoding/Decoding Utilities
  // ============================================================================

  /// Encode bytes to Base64 string
  static String encodeBase64(Uint8List bytes) {
    try {
      return base64.encode(bytes);
    } catch (e) {
      throw DataConversionException('Failed to encode Base64: $e');
    }
  }

  /// Decode Base64 string to bytes
  static Uint8List decodeBase64(String encoded) {
    try {
      return base64.decode(encoded);
    } catch (e) {
      throw DataConversionException('Failed to decode Base64: $e');
    }
  }

  /// Validate Base64 string format
  static bool isValidBase64(String input) {
    try {
      decodeBase64(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Encode bytes to Base64 URL-safe string
  static String encodeBase64Url(Uint8List bytes) {
    try {
      return base64Url.encode(bytes);
    } catch (e) {
      throw DataConversionException('Failed to encode Base64 URL: $e');
    }
  }

  /// Decode Base64 URL-safe string to bytes
  static Uint8List decodeBase64Url(String encoded) {
    try {
      return base64Url.decode(encoded);
    } catch (e) {
      throw DataConversionException('Failed to decode Base64 URL: $e');
    }
  }

  // ============================================================================
  // Hex Encoding/Decoding Utilities
  // ============================================================================

  /// Encode bytes to hexadecimal string with optional '0x' prefix
  static String encodeHex(Uint8List bytes, {bool prefix = false}) {
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return prefix ? '0x$hex' : hex;
  }

  /// Decode hexadecimal string to bytes (handles optional '0x' prefix)
  static Uint8List decodeHex(String hex) {
    // Remove '0x' prefix if present
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }

    if (hex.length % 2 != 0) {
      throw DataConversionException('Hex string must have even length');
    }

    try {
      final result = Uint8List(hex.length ~/ 2);
      for (int i = 0; i < hex.length; i += 2) {
        final byte = int.parse(hex.substring(i, i + 2), radix: 16);
        result[i ~/ 2] = byte;
      }
      return result;
    } catch (e) {
      throw DataConversionException('Invalid hex string: $e');
    }
  }

  /// Validate hexadecimal string format
  static bool isValidHex(String input) {
    try {
      decodeHex(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================================
  // UTF-8 Encoding/Decoding Utilities
  // ============================================================================

  /// Encode string to UTF-8 bytes
  static Uint8List encodeUtf8(String text) {
    try {
      return Uint8List.fromList(utf8.encode(text));
    } catch (e) {
      throw DataConversionException('Failed to encode UTF-8: $e');
    }
  }

  /// Decode UTF-8 bytes to string
  static String decodeUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      throw DataConversionException('Failed to decode UTF-8: $e');
    }
  }

  /// Validate UTF-8 byte sequence
  static bool isValidUtf8(Uint8List bytes) {
    try {
      utf8.decode(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================================
  // Number Conversion Utilities (Little Endian)
  // ============================================================================

  /// Convert 8-bit unsigned integer to bytes
  static Uint8List u8ToBytes(int value) {
    if (value < 0 || value > 255) {
      throw DataConversionException('u8 value must be between 0 and 255');
    }
    return Uint8List.fromList([value]);
  }

  /// Convert bytes to 8-bit unsigned integer
  static int bytesToU8(Uint8List bytes) {
    if (bytes.length != 1) {
      throw DataConversionException('u8 requires exactly 1 byte');
    }
    return bytes[0];
  }

  /// Convert 16-bit unsigned integer to little-endian bytes
  static Uint8List u16ToBytes(int value) {
    if (value < 0 || value > 65535) {
      throw DataConversionException('u16 value must be between 0 and 65535');
    }
    return Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);
  }

  /// Convert little-endian bytes to 16-bit unsigned integer
  static int bytesToU16(Uint8List bytes) {
    if (bytes.length != 2) {
      throw DataConversionException('u16 requires exactly 2 bytes');
    }
    return bytes.buffer.asByteData().getUint16(0, Endian.little);
  }

  /// Convert 32-bit unsigned integer to little-endian bytes
  static Uint8List u32ToBytes(int value) {
    if (value < 0 || value > 4294967295) {
      throw DataConversionException(
          'u32 value must be between 0 and 4294967295');
    }
    return Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
  }

  /// Convert little-endian bytes to 32-bit unsigned integer
  static int bytesToU32(Uint8List bytes) {
    if (bytes.length != 4) {
      throw DataConversionException('u32 requires exactly 4 bytes');
    }
    return bytes.buffer.asByteData().getUint32(0, Endian.little);
  }

  /// Convert 64-bit unsigned integer to little-endian bytes
  static Uint8List u64ToBytes(int value) {
    if (value < 0) {
      throw DataConversionException('u64 value must be non-negative');
    }
    return Uint8List(8)..buffer.asByteData().setUint64(0, value, Endian.little);
  }

  /// Convert little-endian bytes to 64-bit unsigned integer
  static int bytesToU64(Uint8List bytes) {
    if (bytes.length != 8) {
      throw DataConversionException('u64 requires exactly 8 bytes');
    }
    return bytes.buffer.asByteData().getUint64(0, Endian.little);
  }

  /// Convert 8-bit signed integer to bytes
  static Uint8List i8ToBytes(int value) {
    if (value < -128 || value > 127) {
      throw DataConversionException('i8 value must be between -128 and 127');
    }
    return Uint8List(1)..buffer.asByteData().setInt8(0, value);
  }

  /// Convert bytes to 8-bit signed integer
  static int bytesToI8(Uint8List bytes) {
    if (bytes.length != 1) {
      throw DataConversionException('i8 requires exactly 1 byte');
    }
    return bytes.buffer.asByteData().getInt8(0);
  }

  /// Convert 16-bit signed integer to little-endian bytes
  static Uint8List i16ToBytes(int value) {
    if (value < -32768 || value > 32767) {
      throw DataConversionException(
          'i16 value must be between -32768 and 32767');
    }
    return Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);
  }

  /// Convert little-endian bytes to 16-bit signed integer
  static int bytesToI16(Uint8List bytes) {
    if (bytes.length != 2) {
      throw DataConversionException('i16 requires exactly 2 bytes');
    }
    return bytes.buffer.asByteData().getInt16(0, Endian.little);
  }

  /// Convert 32-bit signed integer to little-endian bytes
  static Uint8List i32ToBytes(int value) {
    if (value < -2147483648 || value > 2147483647) {
      throw DataConversionException(
          'i32 value must be between -2147483648 and 2147483647');
    }
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);
  }

  /// Convert little-endian bytes to 32-bit signed integer
  static int bytesToI32(Uint8List bytes) {
    if (bytes.length != 4) {
      throw DataConversionException('i32 requires exactly 4 bytes');
    }
    return bytes.buffer.asByteData().getInt32(0, Endian.little);
  }

  /// Convert 64-bit signed integer to little-endian bytes
  static Uint8List i64ToBytes(int value) {
    return Uint8List(8)..buffer.asByteData().setInt64(0, value, Endian.little);
  }

  /// Convert little-endian bytes to 64-bit signed integer
  static int bytesToI64(Uint8List bytes) {
    if (bytes.length != 8) {
      throw DataConversionException('i64 requires exactly 8 bytes');
    }
    return bytes.buffer.asByteData().getInt64(0, Endian.little);
  }

  /// Convert double to little-endian bytes (IEEE 754 format)
  static Uint8List f64ToBytes(double value) {
    return Uint8List(8)
      ..buffer.asByteData().setFloat64(0, value, Endian.little);
  }

  /// Convert little-endian bytes to double (IEEE 754 format)
  static double bytesToF64(Uint8List bytes) {
    if (bytes.length != 8) {
      throw DataConversionException('f64 requires exactly 8 bytes');
    }
    return bytes.buffer.asByteData().getFloat64(0, Endian.little);
  }

  /// Convert float to little-endian bytes (IEEE 754 format)
  static Uint8List f32ToBytes(double value) {
    return Uint8List(4)
      ..buffer.asByteData().setFloat32(0, value, Endian.little);
  }

  /// Convert little-endian bytes to float (IEEE 754 format)
  static double bytesToF32(Uint8List bytes) {
    if (bytes.length != 4) {
      throw DataConversionException('f32 requires exactly 4 bytes');
    }
    return bytes.buffer.asByteData().getFloat32(0, Endian.little);
  }

  // ============================================================================
  // BigInt Conversion Utilities
  // ============================================================================

  /// Convert BigInt to little-endian bytes with specified size
  static Uint8List bigIntToBytes(BigInt value, int byteLength) {
    if (byteLength <= 0) {
      throw DataConversionException('Byte length must be positive');
    }

    if (value.isNegative) {
      throw DataConversionException(
          'BigInt must be non-negative for unsigned conversion');
    }

    final bytes = Uint8List(byteLength);
    BigInt tempValue = value;

    for (int i = 0; i < byteLength; i++) {
      bytes[i] = (tempValue & BigInt.from(0xFF)).toInt();
      tempValue = tempValue >> 8;
    }

    // Check for overflow
    if (tempValue > BigInt.zero) {
      throw DataConversionException(
          'BigInt value too large for $byteLength bytes');
    }

    return bytes;
  }

  /// Convert little-endian bytes to BigInt
  static BigInt bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;

    for (int i = bytes.length - 1; i >= 0; i--) {
      result = result << 8;
      result = result + BigInt.from(bytes[i]);
    }

    return result;
  }

  /// Convert signed BigInt to little-endian bytes using two's complement
  static Uint8List bigIntToSignedBytes(BigInt value, int byteLength) {
    if (byteLength <= 0) {
      throw DataConversionException('Byte length must be positive');
    }

    // Calculate the range for signed integers
    final maxPositive = (BigInt.one << (byteLength * 8 - 1)) - BigInt.one;
    final minNegative = -(BigInt.one << (byteLength * 8 - 1));

    if (value > maxPositive || value < minNegative) {
      throw DataConversionException(
          'BigInt value out of range for signed $byteLength bytes');
    }

    BigInt tempValue = value;

    // Handle negative values using two's complement
    if (value.isNegative) {
      tempValue = (BigInt.one << (byteLength * 8)) + value;
    }

    final bytes = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      bytes[i] = (tempValue & BigInt.from(0xFF)).toInt();
      tempValue = tempValue >> 8;
    }

    return bytes;
  }

  /// Convert little-endian bytes to signed BigInt using two's complement
  static BigInt bytesToSignedBigInt(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw DataConversionException('Bytes array cannot be empty');
    }

    BigInt result = BigInt.zero;

    for (int i = bytes.length - 1; i >= 0; i--) {
      result = result << 8;
      result = result + BigInt.from(bytes[i]);
    }

    // Check if the number is negative (MSB is set)
    final signBit = BigInt.one << (bytes.length * 8 - 1);
    if (result >= signBit) {
      // Convert from two's complement
      result = result - (BigInt.one << (bytes.length * 8));
    }

    return result;
  }

  // ============================================================================
  // Endianness Utilities
  // ============================================================================

  /// Reverse the byte order of a byte array
  static Uint8List reverseBytes(Uint8List bytes) {
    return Uint8List.fromList(bytes.reversed.toList());
  }

  /// Convert little-endian bytes to big-endian
  static Uint8List littleToBigEndian(Uint8List bytes) {
    return reverseBytes(bytes);
  }

  /// Convert big-endian bytes to little-endian
  static Uint8List bigToLittleEndian(Uint8List bytes) {
    return reverseBytes(bytes);
  }

  /// Read a 16-bit value from bytes with specified endianness
  static int read16(Uint8List bytes,
      {Endian endian = Endian.little, int offset = 0}) {
    if (offset + 2 > bytes.length) {
      throw DataConversionException('Not enough bytes to read 16-bit value');
    }
    return bytes.buffer.asByteData().getUint16(offset, endian);
  }

  /// Read a 32-bit value from bytes with specified endianness
  static int read32(Uint8List bytes,
      {Endian endian = Endian.little, int offset = 0}) {
    if (offset + 4 > bytes.length) {
      throw DataConversionException('Not enough bytes to read 32-bit value');
    }
    return bytes.buffer.asByteData().getUint32(offset, endian);
  }

  /// Read a 64-bit value from bytes with specified endianness
  static int read64(Uint8List bytes,
      {Endian endian = Endian.little, int offset = 0}) {
    if (offset + 8 > bytes.length) {
      throw DataConversionException('Not enough bytes to read 64-bit value');
    }
    return bytes.buffer.asByteData().getUint64(offset, endian);
  }

  /// Write a 16-bit value to bytes with specified endianness
  static void write16(Uint8List bytes, int value,
      {Endian endian = Endian.little, int offset = 0}) {
    if (offset + 2 > bytes.length) {
      throw DataConversionException('Not enough bytes to write 16-bit value');
    }
    bytes.buffer.asByteData().setUint16(offset, value, endian);
  }

  /// Write a 32-bit value to bytes with specified endianness
  static void write32(Uint8List bytes, int value,
      {Endian endian = Endian.little, int offset = 0}) {
    if (offset + 4 > bytes.length) {
      throw DataConversionException('Not enough bytes to write 32-bit value');
    }
    bytes.buffer.asByteData().setUint32(offset, value, endian);
  }

  /// Write a 64-bit value to bytes with specified endianness
  static void write64(Uint8List bytes, int value,
      {Endian endian = Endian.little, int offset = 0}) {
    if (offset + 8 > bytes.length) {
      throw DataConversionException('Not enough bytes to write 64-bit value');
    }
    bytes.buffer.asByteData().setUint64(offset, value, endian);
  }

  // ============================================================================
  // Data Validation Utilities
  // ============================================================================

  /// Validate that bytes array has expected length
  static void validateLength(Uint8List bytes, int expectedLength,
      [String? context]) {
    if (bytes.length != expectedLength) {
      final contextStr = context != null ? ' for $context' : '';
      throw DataConversionException(
          'Expected $expectedLength bytes$contextStr, got ${bytes.length}');
    }
  }

  /// Validate that bytes array has minimum length
  static void validateMinLength(Uint8List bytes, int minLength,
      [String? context]) {
    if (bytes.length < minLength) {
      final contextStr = context != null ? ' for $context' : '';
      throw DataConversionException(
          'Expected at least $minLength bytes$contextStr, got ${bytes.length}');
    }
  }

  /// Validate integer is within range
  static void validateIntRange(int value, int min, int max, [String? context]) {
    if (value < min || value > max) {
      final contextStr = context != null ? ' for $context' : '';
      throw DataConversionException(
          'Value $value out of range [$min, $max]$contextStr');
    }
  }

  /// Validate BigInt is within range
  static void validateBigIntRange(BigInt value, BigInt min, BigInt max,
      [String? context]) {
    if (value < min || value > max) {
      final contextStr = context != null ? ' for $context' : '';
      throw DataConversionException(
          'Value $value out of range [$min, $max]$contextStr');
    }
  }

  /// Check if bytes array is all zeros
  static bool isZeroBytes(Uint8List bytes) {
    return bytes.every((byte) => byte == 0);
  }

  /// Check if string contains only valid characters for the specified encoding
  static bool isValidEncoding(String input, String encoding) {
    switch (encoding.toLowerCase()) {
      case 'base58':
        return isValidBase58(input);
      case 'base64':
        return isValidBase64(input);
      case 'hex':
        return isValidHex(input);
      case 'utf8':
        try {
          utf8.encode(input);
          return true;
        } catch (_) {
          return false;
        }
      default:
        throw DataConversionException('Unknown encoding: $encoding');
    }
  }

  /// Generate a summary of bytes for debugging
  static String bytesToDebugString(Uint8List bytes, {int maxLength = 32}) {
    if (bytes.isEmpty) return '[]';

    final length = math.min(bytes.length, maxLength);
    final hex = bytes
        .take(length)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final truncated =
        bytes.length > maxLength ? '...(${bytes.length - maxLength} more)' : '';

    return '[$hex$truncated] (${bytes.length} bytes)';
  }
}
