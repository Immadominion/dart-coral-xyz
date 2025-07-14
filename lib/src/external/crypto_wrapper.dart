/// Wrapper for cryptographic functionality
///
/// This module provides a consistent interface to cryptographic operations
/// by wrapping external crypto packages and providing additional
/// Anchor-specific functionality.

library;

import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto;

/// Wrapper around cryptographic operations with Anchor-specific enhancements
class CryptoWrapper {
  /// The ED25519 algorithm instance
  static final _algorithm = crypto.Ed25519();

  /// Generate a new ED25519 keypair
  static Future<KeypairData> generateKeypair() async {
    final keyPair = await _algorithm.newKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;

    // Solana secret key format is [private_key_32_bytes + public_key_32_bytes]
    final secretKey = Uint8List(64);
    secretKey.setRange(0, 32, privateKeyBytes);
    secretKey.setRange(32, 64, publicKeyBytes);

    return KeypairData(
      publicKey: Uint8List.fromList(publicKeyBytes),
      privateKey: secretKey,
    );
  }

  /// Create keypair from secret key bytes
  static Future<KeypairData> fromSecretKey(Uint8List secretKey) async {
    if (secretKey.length != 64) {
      throw const CryptoException('Secret key must be 64 bytes');
    }

    // Private key is the first 32 bytes (validation purposes)
    final publicKeyBytes = secretKey.sublist(32, 64);

    return KeypairData(
      publicKey: publicKeyBytes,
      privateKey: secretKey,
    );
  }

  /// Sign data with a private key
  static Future<Uint8List> sign(Uint8List data, Uint8List privateKey) async {
    if (privateKey.length != 64) {
      throw const CryptoException('Private key must be 64 bytes (Solana format)');
    }

    // Extract the actual private key (first 32 bytes)
    final actualPrivateKey = privateKey.sublist(0, 32);

    // Create a SimpleKeyPair from the private key
    final keyPair = await _algorithm.newKeyPairFromSeed(actualPrivateKey);

    // Sign the data
    final signature = await _algorithm.sign(data, keyPair: keyPair);

    return Uint8List.fromList(signature.bytes);
  }

  /// Verify signature
  static Future<bool> verify(
    Uint8List data,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    try {
      final publicKeyObj =
          crypto.SimplePublicKey(publicKey, type: crypto.KeyPairType.ed25519);
      final signatureObj = crypto.Signature(signature, publicKey: publicKeyObj);

      return await _algorithm.verify(data, signature: signatureObj);
    } catch (e) {
      return false;
    }
  }

  /// Create keypair from seed bytes
  static Future<KeypairData> fromSeed(Uint8List seed) async {
    if (seed.length != 32) {
      throw const CryptoException('Seed must be 32 bytes');
    }

    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;

    // Solana secret key format is [private_key_32_bytes + public_key_32_bytes]
    final secretKey = Uint8List(64);
    secretKey.setRange(0, 32, privateKeyBytes);
    secretKey.setRange(32, 64, publicKeyBytes);

    return KeypairData(
      publicKey: Uint8List.fromList(publicKeyBytes),
      privateKey: secretKey,
    );
  }

  /// Derive HD key from seed
  static Future<KeypairData> deriveFromSeed(
    Uint8List seed,
    String derivationPath,
  ) async {
    // For now, just use the seed directly
    // TODO: Implement proper HD key derivation when ed25519_hd_key is available
    return fromSeed(seed);
  }
}

/// Data class representing a cryptographic keypair
class KeypairData {

  const KeypairData({required this.publicKey, required this.privateKey});
  final Uint8List publicKey;
  final Uint8List privateKey;

  /// Alias for privateKey to match Solana terminology
  Uint8List get secretKey => privateKey;

  @override
  String toString() =>
      'KeypairData(publicKey: ${publicKey.length} bytes, privateKey: ${privateKey.length} bytes)';
}

/// Exception thrown by cryptographic operations
class CryptoException implements Exception {

  const CryptoException(this.message);
  final String message;

  @override
  String toString() => 'CryptoException: $message';
}
