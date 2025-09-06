import 'dart:io';
import '../types/public_key.dart';

/// Translation utilities for addresses - matches TypeScript program/common
class ProgramCommon {
  /// Translates various address formats to PublicKey
  ///
  /// Matches TypeScript: translateAddress(address)
  /// Accepts: String, PublicKey, or PublicKey-like object
  static PublicKey translateAddress(dynamic address) {
    if (address is PublicKey) {
      return address;
    }

    if (address is String) {
      try {
        return PublicKey.fromBase58(address);
      } catch (e) {
        throw ArgumentError('Invalid string address: $address');
      }
    }

    // Handle PublicKey-like object with _bn property (like TypeScript)
    if (address is Map && address['_bn'] != null) {
      try {
        // Convert from the _bn format back to base58 then to PublicKey
        return PublicKey.fromBase58(address['_bn'].toString());
      } catch (e) {
        throw ArgumentError('Invalid PublicKey object: $address');
      }
    }

    throw ArgumentError('Invalid address type: ${address.runtimeType}');
  }
}

/// Node wallet functionality - matches TypeScript NodeWallet
class NodeWallet {
  /// Creates a local wallet from ANCHOR_WALLET environment variable
  ///
  /// Matches TypeScript: NodeWallet.local()
  /// Throws if ANCHOR_WALLET environment variable is not set
  static NodeWallet local() {
    final walletPath = Platform.environment['ANCHOR_WALLET'];
    if (walletPath == null) {
      throw StateError(
          'expected environment variable `ANCHOR_WALLET` is not set.');
    }

    // For now, return a minimal implementation
    // In full implementation, this would read the wallet file
    return NodeWallet._();
  }

  NodeWallet._();
}
