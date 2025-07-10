/// Clean Solana RPC Wrapper
///
/// This wrapper provides RPC functionality using the espresso-cash solana package
/// with working transaction serialization, replacing all broken stubs.

import 'package:solana/solana.dart' as solana;
import '../transaction/transaction.dart';

/// Clean RPC wrapper using espresso-cash solana package
class SolanaRpcClient {
  final solana.SolanaClient _client;

  SolanaRpcClient(String rpcUrl)
      : _client = solana.SolanaClient(
          rpcUrl: Uri.parse(rpcUrl),
          websocketUrl: Uri.parse(rpcUrl.replaceFirst('http', 'ws')),
        );

  /// Get the underlying Solana client for direct access when needed
  solana.SolanaClient get client => _client;

  /// Get account information
  Future<Map<String, dynamic>?> getAccountInfo(String address) async {
    try {
      final result = await _client.rpcClient.getAccountInfo(address);
      return result as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to get account info for $address: $e');
    }
  }

  /// Get recent blockhash
  Future<String> getRecentBlockhash() async {
    try {
      final result = await _client.rpcClient.getLatestBlockhash();
      return result.value.blockhash;
    } catch (e) {
      throw Exception('Failed to get recent blockhash: $e');
    }
  }

  /// Send transaction using working serialization
  Future<String> sendTransaction({
    required Transaction transaction,
    required solana.Ed25519HDKeyPair signer,
    solana.Commitment? commitment,
  }) async {
    try {
      // Get recent blockhash
      final recentBlockhash = await getRecentBlockhash();

      // Serialize transaction using working implementation
      final serializedTx = await transaction.serialize(
        signer: signer,
        recentBlockhash: recentBlockhash,
      );

      // Send using working implementation
      return await Transaction.sendTransaction(
        client: _client,
        serializedTransaction: serializedTx,
        commitment: commitment,
      );
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// Get balance
  Future<int> getBalance(String address,
      [solana.Commitment? commitment]) async {
    try {
      final result = await _client.rpcClient.getBalance(
        address,
        commitment: commitment ?? solana.Commitment.confirmed,
      );
      return result.value;
    } catch (e) {
      throw Exception('Failed to get balance for $address: $e');
    }
  }
}
