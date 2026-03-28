import 'dart:typed_data';
import 'package:coral_xyz/src/provider/wallet.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/types/transaction.dart';

/// Abstract interface for a Mobile Wallet Adapter client.
/// This should be implemented by the actual MWA client integration.
abstract class MobileWalletAdapterClient {
  Future<List<Uint8List>> signTransactions(List<Uint8List> messages);
  Future<Uint8List> signMessage(Uint8List message);
  Future<PublicKey> getPublicKey();
}

/// Wallet implementation that wraps a Mobile Wallet Adapter client.
class MobileWalletAdapterWallet implements Wallet {
  MobileWalletAdapterWallet(this._client, this._publicKey);
  final MobileWalletAdapterClient _client;
  final PublicKey _publicKey;

  /// Factory to create and initialize the wallet with the public key from the client.
  static Future<MobileWalletAdapterWallet> create(
    MobileWalletAdapterClient client,
  ) async {
    final pubkey = await client.getPublicKey();
    return MobileWalletAdapterWallet(client, pubkey);
  }

  @override
  PublicKey get publicKey => _publicKey;

  @override
  Future<T> signTransaction<T>(T transaction) async {
    if (transaction is Transaction) {
      final unsigned = _buildUnsignedWireFormat(transaction);
      final signedPayloads = await _client.signTransactions([unsigned]);
      if (signedPayloads.isEmpty) {
        throw Exception('No signature returned from MWA client');
      }
      final signed = signedPayloads.first;
      final signature = _extractWalletSignature(signed, transaction);
      transaction.addSignature(publicKey, signature);
      // Store raw MWA-signed bytes so serialize() returns them directly
      // instead of re-building (avoids mismatch if wallet modified the tx)
      transaction.setSerializedOverride(signed);
      return transaction as T;
    }
    throw ArgumentError(
      'Unsupported transaction type: ${transaction.runtimeType}',
    );
  }

  @override
  Future<List<T>> signAllTransactions<T>(List<T> transactions) async {
    if (transactions.isEmpty) return [];

    // Verify all transactions are of supported type
    for (final tx in transactions) {
      if (tx is! Transaction) {
        throw ArgumentError('Unsupported transaction type: ${tx.runtimeType}');
      }
    }

    final unsignedList = transactions
        .cast<Transaction>()
        .map(_buildUnsignedWireFormat)
        .toList();
    final signedPayloads = await _client.signTransactions(unsignedList);
    if (signedPayloads.length != transactions.length) {
      throw Exception('MWA client returned wrong number of signatures');
    }

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i] as Transaction;
      final signature = _extractWalletSignature(signedPayloads[i], tx);
      tx.addSignature(publicKey, signature);
      tx.setSerializedOverride(signedPayloads[i]);
    }
    return transactions;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    // Try to delegate to the MWA client
    try {
      return await _client.signMessage(message);
    } catch (e) {
      // If the client doesn't support message signing, provide a clearer error
      throw UnsupportedError(
        'Message signing is not supported by this Mobile Wallet Adapter client: $e',
      );
    }
  }

  /// Build Solana transaction wire-format bytes with zero-filled signature
  /// placeholders: compact-u16(numSigs) + numSigs*64 zeroes + messageBytes
  Uint8List _buildUnsignedWireFormat(Transaction tx) {
    final messageBytes = tx.compileMessage();
    final int numSigs = messageBytes[0]; // numRequiredSignatures from header

    // compact-u16 for values < 128 is a single byte
    final sigBlock = 64 * numSigs;
    final unsigned = Uint8List(1 + sigBlock + messageBytes.length);
    unsigned[0] = numSigs;
    // signature slots are already zero-filled by Uint8List constructor
    unsigned.setRange(1 + sigBlock, unsigned.length, messageBytes);
    return unsigned;
  }

  /// Extract our wallet's signature from the MWA-signed transaction bytes.
  /// The fee payer (first signer) signature is at bytes [1..65).
  Uint8List _extractWalletSignature(Uint8List signed, Transaction tx) {
    // Fee payer signature is the first 64-byte slot after the compact-u16 count
    return Uint8List.fromList(signed.sublist(1, 65));
  }
}
