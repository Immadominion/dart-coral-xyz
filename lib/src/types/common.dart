/// Common types and utilities used throughout the Anchor client
///
/// This module contains shared types, constants, and utility functions
/// that are used across multiple modules in the Anchor client.

library;

import 'dart:typed_data';

/// Common constants used throughout the Anchor client
class AnchorConstants {
  /// Standard size of a Solana public key in bytes
  static const int publicKeyLength = 32;

  /// Standard size of a Solana signature in bytes
  static const int signatureLength = 64;

  /// Size of Anchor's account discriminator in bytes
  static const int accountDiscriminatorLength = 8;

  /// Size of Anchor's instruction discriminator in bytes
  static const int instructionDiscriminatorLength = 8;

  /// Maximum size of a Solana transaction in bytes
  static const int maxTransactionSize = 1232;

  /// Maximum number of accounts in a single transaction
  static const int maxAccountsPerTransaction = 64;

  /// Size of a lamport value in bytes
  static const int lamportsLength = 8;

  /// Number of lamports per SOL
  static const int lamportsPerSol = 1000000000;
}

/// Utility functions for working with bytes
class ByteUtils {
  /// Convert a 64-bit unsigned integer to little-endian bytes
  static Uint8List uint64ToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  /// Convert little-endian bytes to a 64-bit unsigned integer
  static int bytesToUint64(Uint8List bytes) {
    if (bytes.length != 8) {
      throw ArgumentError('Expected 8 bytes for uint64, got ${bytes.length}');
    }

    int value = 0;
    for (int i = 0; i < 8; i++) {
      value |= bytes[i] << (i * 8);
    }
    return value;
  }

  /// Convert a 32-bit unsigned integer to little-endian bytes
  static Uint8List uint32ToBytes(int value) {
    final bytes = Uint8List(4);
    for (int i = 0; i < 4; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  /// Convert little-endian bytes to a 32-bit unsigned integer
  static int bytesToUint32(Uint8List bytes) {
    if (bytes.length != 4) {
      throw ArgumentError('Expected 4 bytes for uint32, got ${bytes.length}');
    }

    int value = 0;
    for (int i = 0; i < 4; i++) {
      value |= bytes[i] << (i * 8);
    }
    return value;
  }

  /// Convert a 16-bit unsigned integer to little-endian bytes
  static Uint8List uint16ToBytes(int value) {
    final bytes = Uint8List(2);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    return bytes;
  }

  /// Convert little-endian bytes to a 16-bit unsigned integer
  static int bytesToUint16(Uint8List bytes) {
    if (bytes.length != 2) {
      throw ArgumentError('Expected 2 bytes for uint16, got ${bytes.length}');
    }

    return bytes[0] | (bytes[1] << 8);
  }

  /// Convert an 8-bit unsigned integer to bytes
  static Uint8List uint8ToBytes(int value) => Uint8List.fromList([value & 0xFF]);

  /// Convert bytes to an 8-bit unsigned integer
  static int bytesToUint8(Uint8List bytes) {
    if (bytes.length != 1) {
      throw ArgumentError('Expected 1 byte for uint8, got ${bytes.length}');
    }

    return bytes[0];
  }

  /// Concatenate multiple byte arrays
  static Uint8List concat(List<Uint8List> arrays) {
    int totalLength = 0;
    for (final array in arrays) {
      totalLength += array.length;
    }

    final result = Uint8List(totalLength);
    int offset = 0;

    for (final array in arrays) {
      result.setRange(offset, offset + array.length, array);
      offset += array.length;
    }

    return result;
  }

  /// Compare two byte arrays for equality
  static bool equals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  /// Convert bytes to hexadecimal string
  static String toHex(Uint8List bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Convert hexadecimal string to bytes
  static Uint8List fromHex(String hex) {
    // Remove 0x prefix if present
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;

    if (cleanHex.length % 2 != 0) {
      throw ArgumentError('Hex string must have even length');
    }

    final bytes = Uint8List(cleanHex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return bytes;
  }
}

/// Utility functions for working with strings
class StringUtils {
  /// Convert camelCase to snake_case
  static String camelToSnake(String input) => input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );

  /// Convert snake_case to camelCase
  static String snakeToCamel(String input) {
    if (input.isEmpty) return input;

    final parts = input.split('_');
    if (parts.length == 1) return input;

    final result = StringBuffer(parts.first);
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        result.write(parts[i][0].toUpperCase());
        if (parts[i].length > 1) {
          result.write(parts[i].substring(1));
        }
      }
    }

    return result.toString();
  }

  /// Convert PascalCase to camelCase
  static String pascalToCamel(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }

  /// Convert camelCase to PascalCase
  static String camelToPascal(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  /// Truncate a string to a maximum length with ellipsis
  static String truncate(
    String input,
    int maxLength, {
    String ellipsis = '...',
  }) {
    if (input.length <= maxLength) return input;
    return input.substring(0, maxLength - ellipsis.length) + ellipsis;
  }
}

/// Utility functions for working with numbers and precision
class NumberUtils {
  /// Convert lamports to SOL with proper decimal precision
  static double lamportsToSol(int lamports) => lamports / AnchorConstants.lamportsPerSol;

  /// Convert SOL to lamports
  static int solToLamports(double sol) => (sol * AnchorConstants.lamportsPerSol).round();

  /// Format lamports as a human-readable SOL amount
  static String formatSol(int lamports, {int decimals = 9}) {
    final sol = lamportsToSol(lamports);
    return sol.toStringAsFixed(decimals).replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Parse a SOL amount string to lamports
  static int parseSol(String solString) {
    final sol = double.tryParse(solString);
    if (sol == null) {
      throw ArgumentError('Invalid SOL amount: $solString');
    }
    return solToLamports(sol);
  }

  /// Clamp a value between min and max
  static T clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// Result type for operations that can fail
class Result<T, E> {

  const Result._(this._value, this._error, this._isSuccess);

  /// Create a successful result
  factory Result.success(T value) {
    return Result._(value, null, true);
  }

  /// Create a failed result
  factory Result.failure(E error) {
    return Result._(null, error, false);
  }
  final T? _value;
  final E? _error;
  final bool _isSuccess;

  /// Check if the result is successful
  bool get isSuccess => _isSuccess;

  /// Check if the result is a failure
  bool get isFailure => !_isSuccess;

  /// Get the value (throws if failure)
  T get value {
    if (!_isSuccess) {
      throw StateError('Cannot get value from failed result');
    }
    return _value!;
  }

  /// Get the error (throws if success)
  E get error {
    if (_isSuccess) {
      throw StateError('Cannot get error from successful result');
    }
    return _error!;
  }

  /// Get the value or return a default
  T valueOr(T defaultValue) => _isSuccess ? _value! : defaultValue;

  /// Map the value if successful
  Result<U, E> map<U>(U Function(T) mapper) {
    if (_isSuccess) {
      return Result.success(mapper(_value as T));
    }
    return Result.failure(_error as E);
  }

  /// Map the error if failed
  Result<T, U> mapError<U>(U Function(E) mapper) {
    if (_isSuccess) {
      return Result.success(_value as T);
    }
    return Result.failure(mapper(_error as E));
  }

  @override
  String toString() {
    if (_isSuccess) {
      return 'Result.success($_value)';
    }
    return 'Result.failure($_error)';
  }
}

/// Exception base class for Anchor-related errors
abstract class AnchorException implements Exception {

  const AnchorException(this.message, [this.cause]);
  final String message;
  final dynamic cause;

  @override
  String toString() => 'AnchorException: $message';
}

/// Exception thrown when a public key is invalid
class InvalidPublicKeyException extends AnchorException {
  const InvalidPublicKeyException(super.message, [super.cause]);

  @override
  String toString() => 'InvalidPublicKeyException: $message';
}

/// Exception thrown when a transaction fails
class TransactionException extends AnchorException {
  const TransactionException(super.message, [super.cause]);

  @override
  String toString() => 'TransactionException: $message';
}

/// Exception thrown when an account is not found
class AccountNotFoundException extends AnchorException {
  const AccountNotFoundException(super.message, [super.cause]);

  @override
  String toString() => 'AccountNotFoundException: $message';
}

/// Exception thrown when serialization fails
class SerializationException extends AnchorException {
  const SerializationException(super.message, [super.cause]);

  @override
  String toString() => 'SerializationException: $message';
}
