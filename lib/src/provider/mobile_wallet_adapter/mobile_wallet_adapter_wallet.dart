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
      final message = transaction.compileMessage();
      final signatures = await _client.signTransactions([message]);
      if (signatures.isEmpty) {
        throw Exception('No signature returned from MWA client');
      }
      transaction.addSignature(publicKey, signatures.first);
      return transaction as T;
    }
    throw ArgumentError(
        'Unsupported transaction type: ${transaction.runtimeType}');
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

    final messages = transactions
        .cast<Transaction>()
        .map((tx) => tx.compileMessage())
        .toList();
    final signatures = await _client.signTransactions(messages);
    if (signatures.length != transactions.length) {
      throw Exception('MWA client returned wrong number of signatures');
    }

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i] as Transaction;
      tx.addSignature(publicKey, signatures[i]);
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
          'Message signing is not supported by this Mobile Wallet Adapter client: $e');
    }
  }
}
