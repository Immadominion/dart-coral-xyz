/// Connection class for RPC communication with Solana clusters
///
/// This module provides the core Connection class that handles RPC
/// communication with Solana validators, manages endpoint configuration,
/// and provides health checking and retry logic.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../types/commitment.dart';
import '../types/connection_config.dart';
import '../types/public_key.dart';
import '../utils/rpc_errors.dart';
import '../external/solana_rpc_wrapper.dart';

/// Connection to a Solana cluster for RPC communication
///
/// This class provides the primary interface for communicating with
/// Solana validators. It handles connection management, endpoint
/// configuration, commitment levels, and retry logic.
class Connection {
  final String _endpoint;
  final ConnectionConfig _config;
  final SolanaRpcWrapper _rpcWrapper;
  final http.Client _httpClient;

  /// Create a new Connection
  ///
  /// [endpoint] - The RPC endpoint URL
  /// [config] - Optional connection configuration
  /// [httpClient] - Optional HTTP client (for testing)
  Connection(
    this._endpoint, {
    ConnectionConfig? config,
    http.Client? httpClient,
  })  : _config = config ?? ConnectionConfig(rpcUrl: _endpoint),
        _httpClient = httpClient ?? http.Client(),
        _rpcWrapper = SolanaRpcWrapper(_endpoint);

  /// Get the endpoint URL
  String get endpoint => _endpoint;

  /// Get the connection configuration
  ConnectionConfig get config => _config;

  /// Send and confirm transaction
  ///
  /// [transaction] - Transaction data to send
  /// [commitment] - Optional commitment level
  ///
  /// Returns the transaction signature
  Future<String> sendAndConfirmTransaction(
    Map<String, dynamic> transaction, {
    CommitmentConfig? commitment,
  }) async {
    return await _rpcWrapper.sendAndConfirmTransaction(
      transaction,
      commitment: (commitment ?? _config.commitment).commitment.value,
    );
  }

  /// Get account balance in lamports
  ///
  /// [publicKey] - The public key of the account to query
  /// [commitment] - Optional commitment level
  ///
  /// Returns the balance in lamports
  Future<int> getBalance(
    PublicKey publicKey, {
    CommitmentConfig? commitment,
  }) async {
    final result = await _makeRpcRequest('getBalance', [
      publicKey.toBase58(),
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
      }
    ]);

    if (result['value'] is int) {
      return result['value'] as int;
    }
    throw RpcException('Invalid balance response: $result');
  }

  /// Get account information for a given public key
  ///
  /// [publicKey] - The public key of the account to query
  /// [commitment] - Optional commitment level
  ///
  /// Returns account information or null if account doesn't exist
  Future<AccountInfo?> getAccountInfo(
    PublicKey publicKey, {
    CommitmentConfig? commitment,
  }) async {
    final result = await _makeRpcRequest('getAccountInfo', [
      publicKey.toBase58(),
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
        'encoding': 'base64',
      }
    ]);

    if (result['value'] == null) {
      return null;
    }

    final accountData = result['value'] as Map<String, dynamic>;
    return AccountInfo.fromJson(accountData);
  }

  /// Get the latest blockhash
  ///
  /// [commitment] - Optional commitment level
  ///
  /// Returns latest blockhash information
  Future<LatestBlockhash> getLatestBlockhash({
    CommitmentConfig? commitment,
  }) async {
    final result = await _makeRpcRequest('getLatestBlockhash', [
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
      }
    ]);

    final value = result['value'] as Map<String, dynamic>;
    return LatestBlockhash(
      blockhash: value['blockhash'] as String,
      lastValidBlockHeight: value['lastValidBlockHeight'] as int,
    );
  }

  /// Internal helper to make RPC requests
  Future<Map<String, dynamic>> _makeRpcRequest(
    String method,
    List<dynamic> params,
  ) async {
    final requestBody = {
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': method,
      'params': params,
    };

    try {
      final response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw RpcException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (responseData['error'] != null) {
        final error = responseData['error'] as Map<String, dynamic>;
        throw RpcException(
          'RPC Error ${error['code']}: ${error['message']}',
        );
      }

      return responseData['result'] as Map<String, dynamic>;
    } catch (e) {
      if (e is RpcException) rethrow;
      throw RpcException('Failed to make RPC request: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _httpClient.close();
  }
}

/// Account information returned by getAccountInfo
class AccountInfo {
  final bool executable;
  final int lamports;
  final PublicKey owner;
  final Uint8List? data;
  final int rentEpoch;

  const AccountInfo({
    required this.executable,
    required this.lamports,
    required this.owner,
    this.data,
    required this.rentEpoch,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      executable: json['executable'] as bool,
      lamports: json['lamports'] as int,
      owner: PublicKey.fromBase58(json['owner'] as String),
      data: json['data'] != null
          ? Uint8List.fromList((json['data'] as List<dynamic>).cast<int>())
          : null,
      rentEpoch: json['rentEpoch'] as int,
    );
  }
}

/// Latest blockhash information
class LatestBlockhash {
  final String blockhash;
  final int lastValidBlockHeight;

  const LatestBlockhash({
    required this.blockhash,
    required this.lastValidBlockHeight,
  });
}
