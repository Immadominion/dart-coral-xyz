import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';

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
      MobileWalletAdapterClient client,) async {
    final pubkey = await client.getPublicKey();
    return MobileWalletAdapterWallet(client, pubkey);
  }

  @override
  PublicKey get publicKey => _publicKey;

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    final message = transaction.compileMessage();
    final signatures = await _client.signTransactions([message]);
    if (signatures.isEmpty) {
      throw Exception('No signature returned from MWA client');
    }
    transaction.addSignature(publicKey, signatures.first);
    return transaction;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions,) async {
    if (transactions.isEmpty) return [];
    final messages = transactions.map((tx) => tx.compileMessage()).toList();
    final signatures = await _client.signTransactions(messages);
    if (signatures.length != transactions.length) {
      throw Exception('MWA client returned wrong number of signatures');
    }
    for (int i = 0; i < transactions.length; i++) {
      transactions[i].addSignature(publicKey, signatures[i]);
    }
    return transactions;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    // If not supported, throw. Otherwise, delegate to client.
    try {
      return await _client.signMessage(message);
    } catch (_) {
      throw UnimplementedError('signMessage is not supported by this wallet');
    }
  }
}
