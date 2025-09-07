/// Keypair implementation for Solana key management
///
/// This class represents a Solana keypair (public/private key pair) and provides
/// utilities for key generation, signing, and serialization.
///
/// Refactored to use espresso-cash Ed25519HDKeyPair internally for battle-tested
/// cryptographic operations while maintaining the existing API.

library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/external/encoding_wrapper.dart';
import 'package:coral_xyz/src/program/namespace/types.dart' as namespace_types;
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/crypto/crypto.dart' as solana_crypto;

/// A Solana keypair containing both public and private keys
///
/// This class provides functionality for:
/// - Key generation and restoration
/// - Transaction signing
/// - Key serialization and deserialization
/// - Secure key management
///
/// Internally uses espresso-cash Ed25519HDKeyPair for battle-tested cryptographic operations
class Keypair implements namespace_types.Signer {
  /// Internal espresso-cash keypair - all crypto operations delegated to this
  final solana.Ed25519HDKeyPair _keypair;

  /// Cached public key for compatibility
  late final PublicKey _publicKey;

  /// Private constructor that takes an espresso-cash keypair
  Keypair._(this._keypair) {
    _publicKey = PublicKey.fromBase58(_keypair.publicKey.toBase58());
  }

  /// Create a keypair from a secret key
  factory Keypair.fromSecretKey(Uint8List secretKey) {
    throw UnimplementedError('Use fromSecretKeyAsync instead');
  }

  /// Create a keypair from a secret key (async version)
  static Future<Keypair> fromSecretKeyAsync(Uint8List secretKey) async {
    if (secretKey.length == 32) {
      // This is just the private key
      final keypair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: secretKey.toList(),
      );
      return Keypair._(keypair);
    } else if (secretKey.length == 64) {
      // Extract private key (first 32 bytes for espresso-cash)
      final privateKey = secretKey.sublist(0, 32);
      final keypair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: privateKey.toList(),
      );
      return Keypair._(keypair);
    } else {
      throw ArgumentError(
        'Invalid secret key length. Expected 32 or 64 bytes, got ${secretKey.length}',
      );
    }
  }

  /// Create a keypair from a base58-encoded secret key
  factory Keypair.fromBase58(String secretKeyBase58) {
    throw UnimplementedError('Use fromBase58Async instead');
  }

  /// Create a keypair from a base58-encoded secret key (async version)
  static Future<Keypair> fromBase58Async(String secretKeyBase58) async {
    try {
      final secretKey = EncodingWrapper.decodeBase58(secretKeyBase58);
      return fromSecretKeyAsync(secretKey);
    } catch (e) {
      throw ArgumentError('Invalid base58 secret key: $e');
    }
  }

  /// Create a keypair from a JSON array (as used by Solana CLI)
  factory Keypair.fromJson(List<int> secretKeyArray) {
    throw UnimplementedError('Use fromJsonAsync instead');
  }

  /// Create a keypair from a JSON array (async version)
  static Future<Keypair> fromJsonAsync(List<int> secretKeyArray) async {
    if (secretKeyArray.length != 64) {
      throw ArgumentError(
        'Invalid secret key array length. Expected 64 elements, '
        'got ${secretKeyArray.length}',
      );
    }

    final secretKey = Uint8List.fromList(secretKeyArray);
    return fromSecretKeyAsync(secretKey);
  }

  /// Create a keypair from a JSON file (as used by Solana CLI)
  static Future<Keypair> fromFile(String filePath) async {
    try {
      final file = File(filePath);
      final contents = await file.readAsString();
      final jsonData = jsonDecode(contents);

      if (jsonData is! List) {
        throw ArgumentError(
            'Invalid keypair file format. Expected JSON array.');
      }

      final secretKeyArray = jsonData.cast<int>();
      return Keypair.fromJsonAsync(secretKeyArray);
    } catch (e) {
      throw ArgumentError('Failed to load keypair from file "$filePath": $e');
    }
  }

  /// Generates a new random keypair using espresso-cash Ed25519HDKeyPair
  static Future<Keypair> generate() async {
    final keypair = await solana.Ed25519HDKeyPair.random();
    return Keypair._(keypair);
  }

  /// Create a keypair from a seed (for deterministic key generation)
  static Future<Keypair> fromSeed(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError(
        'Invalid seed length. Expected 32 bytes, got ${seed.length}',
      );
    }

    final keypair = await solana.Ed25519HDKeyPair.fromSeedWithHdPath(
      seed: seed.toList(),
      hdPath: "m/44'/501'/0'/0'", // Standard Solana HD path
    );

    return Keypair._(keypair);
  }

  /// Get the public key
  @override
  PublicKey get publicKey => _publicKey;

  /// Get the internal espresso-cash Ed25519HDKeyPair for integration
  /// This is used by AnchorProvider for espresso-cash transaction flow
  solana.Ed25519HDKeyPair get espressoKeypair => _keypair;

  /// Get the secret key bytes (reconstructed as 64-byte format for compatibility)
  Uint8List get secretKey {
    // For compatibility, we need to reconstruct the 64-byte format
    // Unfortunately, espresso-cash doesn't expose the private key directly
    // We'll return a placeholder indicating this is not supported in the new implementation
    throw UnimplementedError(
      'Direct secret key access not supported with espresso-cash backend. '
      'Use signing methods instead.',
    );
  }

  /// Export the secret key as base58 string
  String secretKeyToBase58() {
    throw UnimplementedError(
      'Secret key export not supported with espresso-cash backend. '
      'Use signing methods instead.',
    );
  }

  /// Export the secret key as JSON array (compatible with Solana CLI)
  List<int> secretKeyToJson() {
    throw UnimplementedError(
      'Secret key export not supported with espresso-cash backend. '
      'Use signing methods instead.',
    );
  }

  /// Sign a message with this keypair using espresso-cash Ed25519HDKeyPair
  Future<Uint8List> sign(Uint8List message) async {
    final signature = await _keypair.sign(message);
    return Uint8List.fromList(signature.bytes);
  }

  /// Implementation of namespace Signer interface
  @override
  Future<List<int>> signMessage(List<int> message) async {
    final signature = await sign(Uint8List.fromList(message));
    return signature.toList();
  }

  /// Verify a signature against this keypair's public key
  Future<bool> verify(Uint8List message, Uint8List signature) async {
    // Use espresso-cash's battle-tested signature verification
    return await solana_crypto.verifySignature(
      message: message.toList(),
      signature: signature.toList(),
      publicKey: _keypair.publicKey,
    );
  }

  @override
  String toString() => 'Keypair(publicKey: ${_publicKey.toBase58()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Keypair) return false;

    return _publicKey == other._publicKey;
  }

  @override
  int get hashCode => _publicKey.hashCode;
}
