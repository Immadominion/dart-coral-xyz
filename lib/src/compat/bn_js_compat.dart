/// BN.js compatibility utilities for Dart/Coral
/// Provides TypeScript-like BigNumber functionality for working with large integers
library;

import 'dart:typed_data';

/// BN.js compatible BigNumber class for Dart
/// Provides TypeScript/JavaScript-like APIs for working with large integers
class BN {

  /// Create a BN from various input types
  BN(dynamic value, {int? base}) : _value = _parseValue(value, base);

  /// Create a BN from a BigInt
  BN.fromBigInt(BigInt value) : _value = value;

  /// Create a BN from bytes (big-endian)
  BN.fromBytes(Uint8List bytes, {bool littleEndian = false})
      : _value = _fromBytes(bytes, littleEndian);

  /// Create a BN from hex string
  BN.fromHex(String hex)
      : _value = BigInt.parse(hex.replaceFirst('0x', ''), radix: 16);
  final BigInt _value;

  /// Zero constant
  static final BN zero = BN(0);

  /// One constant
  static final BN one = BN(1);

  /// Get the underlying BigInt value
  BigInt get value => _value;

  /// TypeScript-like number conversion
  int toNumber() {
    if (_value > BigInt.from(0x1FFFFFFFFFFFFF) ||
        _value < BigInt.from(-0x1FFFFFFFFFFFFF)) {
      throw ArgumentError('BN value too large for JavaScript number precision');
    }
    return _value.toInt();
  }

  /// Convert to string with optional base
  @override
  String toString([int base = 10]) => _value.toRadixString(base);

  /// Convert to hex string
  String toHex() => '0x${_value.toRadixString(16)}';

  /// Convert to bytes (big-endian by default)
  Uint8List toBytes({int? length, bool littleEndian = false}) => _toBytes(_value, length: length, littleEndian: littleEndian);

  /// TypeScript-like arithmetic operations
  BN add(dynamic other) => BN.fromBigInt(_value + _toBigInt(other));
  BN sub(dynamic other) => BN.fromBigInt(_value - _toBigInt(other));
  BN mul(dynamic other) => BN.fromBigInt(_value * _toBigInt(other));
  BN div(dynamic other) => BN.fromBigInt(_value ~/ _toBigInt(other));
  BN mod(dynamic other) => BN.fromBigInt(_value % _toBigInt(other));
  BN pow(dynamic exponent) =>
      BN.fromBigInt(_value.pow(_toBigInt(exponent).toInt()));

  /// Bitwise operations
  BN and(dynamic other) => BN.fromBigInt(_value & _toBigInt(other));
  BN or(dynamic other) => BN.fromBigInt(_value | _toBigInt(other));
  BN xor(dynamic other) => BN.fromBigInt(_value ^ _toBigInt(other));
  BN not() => BN.fromBigInt(~_value);
  BN shiftLeft(int bits) => BN.fromBigInt(_value << bits);
  BN shiftRight(int bits) => BN.fromBigInt(_value >> bits);

  /// Comparison operations
  bool eq(dynamic other) => _value == _toBigInt(other);
  bool lt(dynamic other) => _value < _toBigInt(other);
  bool lte(dynamic other) => _value <= _toBigInt(other);
  bool gt(dynamic other) => _value > _toBigInt(other);
  bool gte(dynamic other) => _value >= _toBigInt(other);

  /// Other utility methods
  BN abs() => BN.fromBigInt(_value.abs());
  BN neg() => BN.fromBigInt(-_value);
  bool get isZero => _value == BigInt.zero;
  bool get isNeg => _value.isNegative;

  /// Clone this BN
  BN clone() => BN.fromBigInt(_value);

  // Helper methods
  static BigInt _parseValue(dynamic value, int? base) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      if (base != null) {
        return BigInt.parse(value, radix: base);
      }
      if (value.startsWith('0x')) {
        return BigInt.parse(value.substring(2), radix: 16);
      }
      return BigInt.parse(value);
    }
    if (value is BN) return value._value;
    throw ArgumentError('Unsupported value type for BN: ${value.runtimeType}');
  }

  static BigInt _toBigInt(dynamic value) {
    if (value is BN) return value._value;
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) return BigInt.parse(value);
    throw ArgumentError('Cannot convert to BigInt: ${value.runtimeType}');
  }

  static BigInt _fromBytes(Uint8List bytes, bool littleEndian) {
    if (bytes.isEmpty) return BigInt.zero;

    BigInt result = BigInt.zero;
    if (littleEndian) {
      for (int i = bytes.length - 1; i >= 0; i--) {
        result = (result << 8) + BigInt.from(bytes[i]);
      }
    } else {
      for (final int byte in bytes) {
        result = (result << 8) + BigInt.from(byte);
      }
    }
    return result;
  }

  static Uint8List _toBytes(BigInt value,
      {int? length, bool littleEndian = false,}) {
    if (value == BigInt.zero) {
      return Uint8List(length ?? 1);
    }

    // Calculate required bytes
    BigInt temp = value.abs();
    int byteCount = 0;
    while (temp > BigInt.zero) {
      temp >>= 8;
      byteCount++;
    }

    final actualLength = length ?? byteCount;
    final bytes = Uint8List(actualLength);

    BigInt remaining = value.abs();
    if (littleEndian) {
      for (int i = 0; i < actualLength && remaining > BigInt.zero; i++) {
        bytes[i] = (remaining & BigInt.from(0xFF)).toInt();
        remaining >>= 8;
      }
    } else {
      for (int i = actualLength - 1; i >= 0 && remaining > BigInt.zero; i--) {
        bytes[i] = (remaining & BigInt.from(0xFF)).toInt();
        remaining >>= 8;
      }
    }

    return bytes;
  }

  @override
  bool operator ==(Object other) {
    if (other is BN) return _value == other._value;
    if (other is BigInt) return _value == other;
    if (other is int) return _value == BigInt.from(other);
    return false;
  }

  @override
  int get hashCode => _value.hashCode;

  // Operator overloads for convenience
  BN operator +(dynamic other) => add(other);
  BN operator -(dynamic other) => sub(other);
  BN operator *(dynamic other) => mul(other);
  BN operator ~/(dynamic other) => div(other);
  BN operator %(dynamic other) => mod(other);
  BN operator -() => neg();
  bool operator <(dynamic other) => lt(other);
  bool operator <=(dynamic other) => lte(other);
  bool operator >(dynamic other) => gt(other);
  bool operator >=(dynamic other) => gte(other);
}

/// Maximum safe JavaScript integer as BN
final BN maxSafeInteger = BN(0x1FFFFFFFFFFFFF);

/// Minimum safe JavaScript integer as BN
final BN minSafeInteger = BN(-0x1FFFFFFFFFFFFF);

/// Utility function to create BN from various types (TypeScript-like)
BN toBN(dynamic value, {int? base}) => BN(value, base: base);

/// Check if a value is a BN
bool isBN(dynamic value) => value is BN;
