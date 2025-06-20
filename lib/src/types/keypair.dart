/// Keypair implementation for Solana key management
///
/// This class represents a Solana keypair (public/private key pair) and provides
/// utilities for key generation, signing, and serialization.

library;

import 'dart:typed_data';
import 'public_key.dart';
import '../external/crypto_wrapper.dart';
import '../external/encoding_wrapper.dart';

/// A Solana keypair containing both public and private keys
///
/// This class provides functionality for:
/// - Key generation and restoration
/// - Transaction signing
/// - Key serialization and deserialization
/// - Secure key management
class Keypair {
  final Uint8List _secretKey;
  final PublicKey _publicKey;

  /// Private constructor to ensure proper validation
  Keypair._(this._secretKey, this._publicKey);

  /// Generate a new random keypair
  static Future<Keypair> generate() async {
    final keyData = await CryptoWrapper.generateKeypair();
    return Keypair._(
      keyData.secretKey,
      PublicKey.fromBytes(keyData.publicKey),
    );
  }

  /// Create a keypair from a secret key
  factory Keypair.fromSecretKey(Uint8List secretKey) {
    if (secretKey.length != 64) {
      throw ArgumentError(
        'Invalid secret key length. Expected 64 bytes, got ${secretKey.length}',
      );
    }

    // Extract public key from secret key (last 32 bytes)
    final publicKeyBytes = secretKey.sublist(32, 64);
    final publicKey = PublicKey.fromBytes(publicKeyBytes);

    return Keypair._(secretKey, publicKey);
  }

  /// Create a keypair from a seed (for deterministic key generation)
  static Future<Keypair> fromSeed(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError(
        'Invalid seed length. Expected 32 bytes, got ${seed.length}',
      );
    }

    final keyData = await CryptoWrapper.fromSeed(seed);
    return Keypair._(
      keyData.secretKey,
      PublicKey.fromBytes(keyData.publicKey),
    );
  }

  /// Create a keypair from a base58-encoded secret key
  factory Keypair.fromBase58(String secretKeyBase58) {
    try {
      final secretKey = EncodingWrapper.decodeBase58(secretKeyBase58);
      return Keypair.fromSecretKey(secretKey);
    } catch (e) {
      throw ArgumentError('Invalid base58 secret key: $e');
    }
  }

  /// Create a keypair from a JSON array (as used by Solana CLI)
  factory Keypair.fromJson(List<int> secretKeyArray) {
    if (secretKeyArray.length != 64) {
      throw ArgumentError(
        'Invalid secret key array length. Expected 64 elements, '
        'got ${secretKeyArray.length}',
      );
    }

    final secretKey = Uint8List.fromList(secretKeyArray);
    return Keypair.fromSecretKey(secretKey);
  }

  /// Get the public key
  PublicKey get publicKey => _publicKey;

  /// Get the secret key bytes
  Uint8List get secretKey => Uint8List.fromList(_secretKey);

  /// Export the secret key as base58 string
  String secretKeyToBase58() {
    return EncodingWrapper.encodeBase58(_secretKey);
  }

  /// Export the secret key as JSON array (compatible with Solana CLI)
  List<int> secretKeyToJson() {
    return _secretKey.toList();
  }

  /// Sign a message with this keypair
  Future<Uint8List> sign(Uint8List message) async {
    return await CryptoWrapper.sign(message, _secretKey);
  }

  /// Verify a signature against this keypair's public key
  Future<bool> verify(Uint8List message, Uint8List signature) async {
    return await CryptoWrapper.verify(message, signature, _publicKey.bytes);
  }

  @override
  String toString() {
    return 'Keypair(publicKey: ${_publicKey.toBase58()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Keypair) return false;

    return _publicKey == other._publicKey;
  }

  @override
  int get hashCode => _publicKey.hashCode;
}
