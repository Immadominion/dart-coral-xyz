/// Anchor-specific utilities and helper functions.
/// Provides TypeScript-like functionality for common Anchor operations.
library;

import 'dart:typed_data';
import '../types/public_key.dart';
import '../external/encoding_wrapper.dart';

/// Anchor utility functions similar to TypeScript @coral-xyz/anchor utils
class AnchorUtils {
  /// Convert a string to bytes (similar to TypeScript Buffer.from)
  static Uint8List stringToBytes(String input) {
    return Uint8List.fromList(input.codeUnits);
  }

  /// Convert bytes to string (similar to TypeScript Buffer.toString)
  static String bytesToString(Uint8List bytes) {
    return String.fromCharCodes(bytes);
  }

  /// Convert hex string to bytes
  static Uint8List hexToBytes(String hex) {
    if (hex.startsWith('0x')) hex = hex.substring(2);
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  /// Convert bytes to hex string
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert base58 string to bytes
  static Uint8List base58ToBytes(String base58) {
    return EncodingWrapper.decodeBase58(base58);
  }

  /// Convert bytes to base58 string
  static String bytesToBase58(Uint8List bytes) {
    return EncodingWrapper.encodeBase58(bytes);
  }

  /// TypeScript-like sleep function
  static Future<void> sleep(int milliseconds) {
    return Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Generate a random keypair (for testing)
  static Future<PublicKey> generateRandomPublicKey() async {
    // Generate 32 random bytes for a public key
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return PublicKey.fromBytes(bytes);
  }

  /// Check if a string is a valid base58 public key
  static bool isValidPublicKey(String publicKey) {
    try {
      final decoded = base58ToBytes(publicKey);
      return decoded.length == 32;
    } catch (e) {
      return false;
    }
  }

  /// Get instruction discriminator for a method name
  static Uint8List getInstructionDiscriminator(String methodName) {
    // Create a basic discriminator based on method name hash
    // This is a simplified version - real implementation would use proper hashing
    final hash = methodName.hashCode;
    return Uint8List.fromList([
      hash & 0xFF,
      (hash >> 8) & 0xFF,
      (hash >> 16) & 0xFF,
      (hash >> 24) & 0xFF,
      0, 0, 0, 0, // Pad to 8 bytes
    ]);
  }

  /// Calculate account discriminator
  static Uint8List getAccountDiscriminator(String accountName) {
    // Similar to TypeScript anchor's account discriminator calculation
    return getInstructionDiscriminator('account:$accountName');
  }

  /// TypeScript-like array utility functions
  static List<T> arrayUnique<T>(List<T> array) {
    return array.toSet().toList();
  }

  /// TypeScript-like array flatten
  static List<T> arrayFlatten<T>(List<List<T>> arrays) {
    return arrays.expand((array) => array).toList();
  }

  /// TypeScript-like object merge
  static Map<String, dynamic> mergeObjects(
    Map<String, dynamic> obj1,
    Map<String, dynamic> obj2,
  ) {
    return {...obj1, ...obj2};
  }

  /// Deep clone an object (simplified version)
  static Map<String, dynamic> deepClone(Map<String, dynamic> original) {
    final Map<String, dynamic> clone = {};
    for (final entry in original.entries) {
      if (entry.value is Map<String, dynamic>) {
        clone[entry.key] = deepClone(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        clone[entry.key] = List<dynamic>.from(entry.value as List);
      } else {
        clone[entry.key] = entry.value;
      }
    }
    return clone;
  }

  /// Check if value is null or undefined (TypeScript-like)
  static bool isNullOrUndefined(dynamic value) {
    return value == null;
  }

  /// TypeScript-like typeof operator
  static String typeOf(dynamic value) {
    if (value == null) return 'undefined';
    if (value is bool) return 'boolean';
    if (value is int || value is double) return 'number';
    if (value is String) return 'string';
    if (value is Function) return 'function';
    if (value is List) return 'array';
    return 'object';
  }

  /// Format lamports to SOL (similar to TypeScript utilities)
  static double lamportsToSol(int lamports) {
    return lamports / 1000000000; // 1 SOL = 1B lamports
  }

  /// Format SOL to lamports
  static int solToLamports(double sol) {
    return (sol * 1000000000).round();
  }

  /// Create a delay (TypeScript-like)
  static Future<T> delay<T>(T value, int milliseconds) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
    return value;
  }

  /// Retry function with exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
    double multiplier = 2.0,
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * multiplier).round(),
        );
      }
    }

    throw StateError('Should not reach here');
  }

  /// TypeScript-like Promise.all
  static Future<List<T>> promiseAll<T>(List<Future<T>> futures) {
    return Future.wait(futures);
  }

  /// TypeScript-like Promise.allSettled
  static Future<List<dynamic>> promiseAllSettled<T>(List<Future<T>> futures) {
    return Future.wait(
      futures.map((future) async {
        try {
          final result = await future;
          return {'status': 'fulfilled', 'value': result};
        } catch (error) {
          return {'status': 'rejected', 'reason': error};
        }
      }),
    );
  }

  /// Chunk array into smaller arrays
  static List<List<T>> chunk<T>(List<T> array, int size) {
    final List<List<T>> chunks = [];
    for (int i = 0; i < array.length; i += size) {
      chunks.add(array.sublist(i, (i + size).clamp(0, array.length)));
    }
    return chunks;
  }

  /// Get current timestamp in milliseconds (TypeScript-like Date.now())
  static int now() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Format duration in human-readable format
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
