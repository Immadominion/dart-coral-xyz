/// Type adapters for systematic PublicKey/String conversion across modules
///
/// This module provides consistent conversion utilities between different
/// type systems used throughout the package, ensuring seamless integration
/// with espresso-cash components while maintaining type safety.
library;

import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/utils/logger.dart';
import 'package:solana/solana.dart' as solana;

/// Systematic type adapters for PublicKey/String conversions
class TypeAdapters {
  static final _logger = AnchorLogger('TypeAdapters');

  /// Convert dart-coral-xyz PublicKey to espresso-cash Ed25519HDPublicKey
  static solana.Ed25519HDPublicKey toEspressoPublicKey(PublicKey publicKey) {
    try {
      return solana.Ed25519HDPublicKey.fromBase58(publicKey.toBase58());
    } catch (e) {
      _logger.error('Failed to convert PublicKey to Ed25519HDPublicKey',
          error: e, context: {'publicKey': publicKey.toBase58()});
      rethrow;
    }
  }

  /// Convert espresso-cash Ed25519HDPublicKey to dart-coral-xyz PublicKey
  static PublicKey fromEspressoPublicKey(
      solana.Ed25519HDPublicKey espressoKey) {
    try {
      return PublicKey.fromBase58(espressoKey.toBase58());
    } catch (e) {
      _logger.error('Failed to convert Ed25519HDPublicKey to PublicKey',
          error: e, context: {'espressoKey': espressoKey.toBase58()});
      rethrow;
    }
  }

  /// Convert any PublicKey-like object to dart-coral-xyz PublicKey
  static PublicKey toPublicKey(dynamic value) {
    if (value is PublicKey) {
      return value;
    } else if (value is String) {
      try {
        return PublicKey.fromBase58(value);
      } catch (e) {
        _logger.error('Failed to convert String to PublicKey',
            error: e, context: {'value': value});
        rethrow;
      }
    } else if (value is solana.Ed25519HDPublicKey) {
      return fromEspressoPublicKey(value);
    } else {
      throw ArgumentError.value(
          value, 'value', 'Must be PublicKey, String, or Ed25519HDPublicKey');
    }
  }

  /// Convert any PublicKey-like object to String
  static String toBase58String(dynamic value) {
    if (value is String) {
      // Validate that it's a proper base58 address
      try {
        PublicKey.fromBase58(value);
        return value;
      } catch (e) {
        _logger.error('Invalid base58 string provided',
            error: e, context: {'value': value});
        rethrow;
      }
    } else if (value is PublicKey) {
      return value.toBase58();
    } else if (value is solana.Ed25519HDPublicKey) {
      return value.toBase58();
    } else {
      throw ArgumentError.value(
          value, 'value', 'Must be PublicKey, String, or Ed25519HDPublicKey');
    }
  }

  /// Convert Map<String, dynamic> to Map<String, PublicKey>
  static Map<String, PublicKey> toPublicKeyMap(Map<String, dynamic> map) {
    final result = <String, PublicKey>{};

    for (final entry in map.entries) {
      try {
        result[entry.key] = toPublicKey(entry.value);
      } catch (e) {
        _logger.warn('Failed to convert map entry to PublicKey', context: {
          'key': entry.key,
          'value': entry.value,
          'error': e.toString(),
        });
        rethrow;
      }
    }

    return result;
  }

  /// Convert Map<String, PublicKey> to Map<String, String>
  static Map<String, String> toStringMap(Map<String, PublicKey> map) {
    final result = <String, String>{};

    for (final entry in map.entries) {
      try {
        result[entry.key] = entry.value.toBase58();
      } catch (e) {
        _logger.warn('Failed to convert PublicKey to string', context: {
          'key': entry.key,
          'publicKey': entry.value.toString(),
          'error': e.toString(),
        });
        rethrow;
      }
    }

    return result;
  }

  /// Convert List<dynamic> to List<PublicKey>
  static List<PublicKey> toPublicKeyList(List<dynamic> list) {
    final result = <PublicKey>[];

    for (int i = 0; i < list.length; i++) {
      try {
        result.add(toPublicKey(list[i]));
      } catch (e) {
        _logger.warn('Failed to convert list item to PublicKey', context: {
          'index': i,
          'value': list[i],
          'error': e.toString(),
        });
        rethrow;
      }
    }

    return result;
  }

  /// Convert List<PublicKey> to List<String>
  static List<String> toStringList(List<PublicKey> list) {
    final result = <String>[];

    for (int i = 0; i < list.length; i++) {
      try {
        result.add(list[i].toBase58());
      } catch (e) {
        _logger.warn('Failed to convert PublicKey to string', context: {
          'index': i,
          'publicKey': list[i].toString(),
          'error': e.toString(),
        });
        rethrow;
      }
    }

    return result;
  }

  /// Validate that a string is a valid base58 PublicKey
  static bool isValidBase58PublicKey(String value) {
    try {
      PublicKey.fromBase58(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Safe conversion with null handling
  static PublicKey? toPublicKeyNullable(dynamic value) {
    if (value == null) return null;
    try {
      return toPublicKey(value);
    } catch (e) {
      _logger.warn('Failed to convert value to PublicKey, returning null',
          context: {
            'value': value,
            'error': e.toString(),
          });
      return null;
    }
  }

  /// Safe conversion with null handling
  static String? toBase58StringNullable(dynamic value) {
    if (value == null) return null;
    try {
      return toBase58String(value);
    } catch (e) {
      _logger.warn('Failed to convert value to base58 string, returning null',
          context: {
            'value': value,
            'error': e.toString(),
          });
      return null;
    }
  }

  /// Convert accounts for espresso-cash compatibility
  static Map<String, solana.Ed25519HDPublicKey> toEspressoAccountMap(
      Map<String, dynamic> accounts) {
    final result = <String, solana.Ed25519HDPublicKey>{};

    for (final entry in accounts.entries) {
      try {
        final publicKey = toPublicKey(entry.value);
        result[entry.key] = toEspressoPublicKey(publicKey);
      } catch (e) {
        _logger.warn('Failed to convert account to espresso format', context: {
          'accountName': entry.key,
          'value': entry.value,
          'error': e.toString(),
        });
        rethrow;
      }
    }

    return result;
  }

  /// Convert from espresso-cash account map to dart-coral-xyz format
  static Map<String, PublicKey> fromEspressoAccountMap(
      Map<String, solana.Ed25519HDPublicKey> accounts) {
    final result = <String, PublicKey>{};

    for (final entry in accounts.entries) {
      try {
        result[entry.key] = fromEspressoPublicKey(entry.value);
      } catch (e) {
        _logger
            .warn('Failed to convert account from espresso format', context: {
          'accountName': entry.key,
          'value': entry.value.toBase58(),
          'error': e.toString(),
        });
        rethrow;
      }
    }

    return result;
  }

  /// Ensure consistent account format for method calls
  static Map<String, dynamic> normalizeAccounts(dynamic accounts) {
    if (accounts == null) return <String, dynamic>{};

    if (accounts is Map<String, dynamic>) {
      // Already in correct format, validate values
      final result = <String, dynamic>{};
      for (final entry in accounts.entries) {
        if (entry.value is PublicKey ||
            entry.value is String ||
            entry.value == null) {
          result[entry.key] = entry.value;
        } else {
          throw ArgumentError.value(entry.value, 'accounts[${entry.key}]',
              'Must be PublicKey, String, or null');
        }
      }
      return result;
    } else if (accounts is Map<String, PublicKey>) {
      // Convert to Map<String, dynamic> maintaining PublicKey objects
      return Map<String, dynamic>.from(accounts);
    } else if (accounts is Map<String, String>) {
      // Convert strings to PublicKeys for internal consistency
      final result = <String, dynamic>{};
      for (final entry in accounts.entries) {
        result[entry.key] = PublicKey.fromBase58(entry.value);
      }
      return result;
    } else {
      // Try to extract accounts using toMap() method
      try {
        final dynamic toMapMethod = accounts.toMap;
        if (toMapMethod != null) {
          final map = toMapMethod() as Map<String, dynamic>;
          return normalizeAccounts(map);
        }
      } catch (e) {
        // Fall through to error
      }

      throw ArgumentError.value(accounts, 'accounts',
          'Must be Map<String, dynamic>, Map<String, PublicKey>, Map<String, String>, or object with toMap() method');
    }
  }

  /// Log type conversion for debugging
  static void logConversion(String operation, dynamic from, dynamic to) {
    _logger.debug('Type conversion performed', context: {
      'operation': operation,
      'fromType': from.runtimeType.toString(),
      'toType': to.runtimeType.toString(),
      'fromValue': from.toString(),
      'toValue': to.toString(),
    });
  }
}
