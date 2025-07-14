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
import 'package:web_socket_channel/io.dart';

import '../types/commitment.dart';
import '../types/connection_config.dart';
import '../types/public_key.dart';
import '../utils/rpc_errors.dart';

/// Connection to a Solana cluster for RPC communication
///
/// This class provides the primary interface for communicating with
/// Solana validators. It handles connection management, endpoint
/// configuration, commitment levels, and retry logic.
class Connection {
  final String _endpoint;
  final ConnectionConfig _config;
  final http.Client _httpClient;

  /// WebSocket connections for subscriptions
  final Map<String, IOWebSocketChannel> _subscriptions = {};

  /// Subscription ID counter
  int _subscriptionIdCounter = 1;

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
        _httpClient = httpClient ?? http.Client();

  /// Get the endpoint URL
  String get endpoint => _endpoint;

  /// Get the RPC URL (alias for endpoint, for backward compatibility)
  String get rpcUrl => _endpoint;

  /// Get the connection configuration
  ConnectionConfig get config => _config;

  /// Get the commitment level (for backward compatibility)
  String get commitment => _config.commitment.commitment.value;

  /// Send and confirm transaction
  ///
  /// [transaction] - Transaction data to send
  /// [commitment] - Optional commitment level
  ///
  /// Returns the transaction signature
  Future<String> sendAndConfirmTransaction(
    dynamic transaction, {
    CommitmentConfig? commitment,
  }) async {
    // Implement retry logic for blockhash-related errors
    const maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print(
            'DEBUG: Connection sendAndConfirmTransaction attempt ${attempt + 1}/$maxRetries');

        // Handle both Map and Uint8List transaction formats
        final txData = transaction is Uint8List
            ? transaction
            : transaction is Map<String, dynamic>
                ? transaction
                : throw ArgumentError('Transaction must be a Map or Uint8List');

        // Convert Uint8List to base64 if needed
        print('DEBUG: txData type: ${txData.runtimeType}');
        print('DEBUG: txData is Uint8List: ${txData is Uint8List}');

        final List<dynamic> params =
            txData is Uint8List ? [base64.encode(txData)] : [txData];
        print('DEBUG: params after base64 encode: $params');

        // Add options
        final commitmentValue =
            (commitment ?? _config.commitment).commitment.value;
        print('DEBUG: commitment param: $commitment');
        print('DEBUG: _config.commitment: ${_config.commitment}');
        print('DEBUG: final commitment value: $commitmentValue');

        final options = <String, dynamic>{
          'encoding': 'base64',
          'commitment': commitmentValue,
          'skipPreflight':
              true, // Skip simulation to avoid blockhash timing issues
        };
        params.add(options);
        print('DEBUG: Added options to params: $options');

        String signature;
        try {
          print('DEBUG: About to call _makeRpcRequest for sendTransaction');
          final result = await _makeRpcRequest('sendTransaction', params);
          print('DEBUG: sendTransaction successful, result: $result');
          print('DEBUG: sendTransaction result type: ${result.runtimeType}');

          // Handle different response formats
          if (result is String) {
            // Direct string response (most common for sendTransaction)
            signature = result;
            print('DEBUG: Got direct string signature: $signature');
          } else if (result is Map<String, dynamic>) {
            // RPC response might have the signature in different fields
            print('DEBUG: Got Map response, keys: ${result.keys.toList()}');
            if (result.containsKey('value')) {
              final value = result['value'];
              print(
                  'DEBUG: Found value field: $value (type: ${value.runtimeType})');

              // Handle case where value might be a Map instead of String
              if (value is String) {
                signature = value;
              } else if (value is Map<String, dynamic>) {
                // Look for signature field in the nested map
                if (value.containsKey('signature')) {
                  signature = value['signature'] as String;
                  print('DEBUG: Found signature in nested map: $signature');
                } else {
                  print('DEBUG: No signature field in nested map: $value');
                  throw RpcException(
                      'No signature field found in nested response map: $value');
                }
              } else {
                throw RpcException(
                    'Unexpected value type in response: ${value.runtimeType}');
              }
            } else if (result.containsKey('signature')) {
              signature = result['signature'] as String;
            } else {
              // If it's a simple map, try to extract string value
              final values = result.values.where((v) => v is String);
              if (values.isNotEmpty) {
                signature = values.first as String;
              } else {
                throw RpcException(
                    'Unexpected sendTransaction response format: $result');
              }
            }
          } else {
            throw RpcException(
                'Unexpected sendTransaction response type: ${result.runtimeType}');
          }

          print('DEBUG: Extracted signature: $signature');

          // Confirm the transaction
          print(
              'DEBUG: About to confirm transaction with signature: $signature');
          try {
            await _confirmTransaction(signature, commitment);
            print('DEBUG: Transaction confirmation completed successfully');
          } catch (confirmError) {
            print(
                'DEBUG: Error during transaction confirmation: $confirmError');
            print(
                'DEBUG: Confirmation error type: ${confirmError.runtimeType}');
            rethrow;
          }
        } catch (e) {
          print('DEBUG: Exception in sendTransaction: $e');
          print('DEBUG: Exception type: ${e.runtimeType}');
          print('DEBUG: Exception stack trace: ${StackTrace.current}');
          rethrow;
        }

        print(
            'DEBUG: Connection sendAndConfirmTransaction success on attempt ${attempt + 1}');
        return signature;
      } catch (e) {
        final errorString = e.toString();
        final isBlockhashError = errorString.contains('Blockhash not found') ||
            errorString.contains('BlockhashNotFound') ||
            errorString.contains('Invalid blockhash');

        if (isBlockhashError && attempt < maxRetries - 1) {
          print(
              'DEBUG: Blockhash error at connection level on attempt ${attempt + 1}, retrying...');
          // Wait a bit before retry
          await Future<void>.delayed(Duration(milliseconds: 500));
          continue;
        }

        // If it's not a blockhash error or we've exhausted retries, rethrow
        print(
            'DEBUG: Connection sendAndConfirmTransaction failed on attempt ${attempt + 1}: $e');
        rethrow;
      }
    }

    // This should never be reached due to the loop structure, but just in case
    throw Exception(
        'Connection sendAndConfirmTransaction: Maximum retry attempts exceeded');
  }

  /// Internal method to confirm a transaction
  Future<void> _confirmTransaction(
    String signature,
    CommitmentConfig? commitment,
  ) async {
    print('DEBUG: _confirmTransaction called with signature: $signature');
    final maxRetries = 30;
    final delayMs = 1000;

    for (int i = 0; i < maxRetries; i++) {
      try {
        print('DEBUG: _confirmTransaction attempt ${i + 1}/$maxRetries');
        final result = await _makeRpcRequest('getSignatureStatuses', [
          [signature],
          {'searchTransactionHistory': true}
        ]);

        print('DEBUG: getSignatureStatuses result: $result');
        final resultMap = result as Map<String, dynamic>;
        print('DEBUG: resultMap: $resultMap');
        final statuses = resultMap['value'] as List<dynamic>;
        print('DEBUG: statuses: $statuses');
        if (statuses.isNotEmpty && statuses[0] != null) {
          final status = statuses[0] as Map<String, dynamic>;
          print('DEBUG: status: $status');
          if (status['confirmationStatus'] != null) {
            final confirmationStatus = status['confirmationStatus'] as String;
            final targetCommitment =
                (commitment ?? _config.commitment).commitment.value;

            print(
                'DEBUG: confirmationStatus: $confirmationStatus, targetCommitment: $targetCommitment');
            if (_isCommitmentSatisfied(confirmationStatus, targetCommitment)) {
              if (status['err'] != null) {
                throw RpcException(
                    'Transaction failed: ${status['err'].toString()}');
              }
              print('DEBUG: Transaction confirmed successfully');
              return; // Transaction confirmed successfully
            }
          }
        }
      } catch (e) {
        print('DEBUG: Exception in _confirmTransaction: $e');
        if (e is RpcException) rethrow;
        // Continue retrying on other errors
      }

      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    throw RpcException('Transaction confirmation timeout');
  }

  /// Check if the given confirmation status satisfies the target commitment
  bool _isCommitmentSatisfied(String current, String target) {
    const commitmentLevels = ['processed', 'confirmed', 'finalized'];
    final currentIndex = commitmentLevels.indexOf(current);
    final targetIndex = commitmentLevels.indexOf(target);
    return currentIndex >= targetIndex;
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

    final resultMap = result as Map<String, dynamic>;
    if (resultMap['value'] is int) {
      return resultMap['value'] as int;
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

    final resultMap = result as Map<String, dynamic>;
    if (resultMap['value'] == null) {
      return null;
    }

    final accountData = resultMap['value'] as Map<String, dynamic>;
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

    final resultMap = result as Map<String, dynamic>;
    final value = resultMap['value'] as Map<String, dynamic>;
    return LatestBlockhash(
      blockhash: value['blockhash'] as String,
      lastValidBlockHeight: value['lastValidBlockHeight'] as int,
    );
  }

  /// Get multiple account information for given public keys
  ///
  /// [publicKeys] - List of public keys to query
  /// [commitment] - Optional commitment level
  ///
  /// Returns list of account information (null for non-existent accounts)
  Future<List<AccountInfo?>> getMultipleAccountsInfo(
    List<PublicKey> publicKeys, {
    CommitmentConfig? commitment,
  }) async {
    final result = await _makeRpcRequest('getMultipleAccounts', [
      publicKeys.map((pk) => pk.toBase58()).toList(),
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
        'encoding': 'base64',
      }
    ]);

    final resultMap = result as Map<String, dynamic>;
    final value = resultMap['value'] as List<dynamic>;
    return value.map((accountData) {
      if (accountData == null) return null;
      return AccountInfo.fromJson(accountData as Map<String, dynamic>);
    }).toList();
  }

  /// Get program accounts for a given program ID
  ///
  /// [programId] - The program ID to query accounts for
  /// [filters] - Optional filters to apply
  /// [commitment] - Optional commitment level
  ///
  /// Returns list of program accounts
  Future<List<ProgramAccountInfo>> getProgramAccounts(
    PublicKey programId, {
    List<AccountFilter>? filters,
    CommitmentConfig? commitment,
  }) async {
    final params = <dynamic>[
      programId.toBase58(),
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
        'encoding': 'base64',
        if (filters != null && filters.isNotEmpty)
          'filters': filters.map((f) => f.toJson()).toList(),
      }
    ];

    final result = await _makeRpcRequest('getProgramAccounts', params);
    final accounts = result as List<dynamic>;

    return accounts.map((account) {
      final accountData = account as Map<String, dynamic>;
      return ProgramAccountInfo.fromJson(accountData);
    }).toList();
  }

  /// Get minimum balance for rent exemption
  ///
  /// [dataLength] - Length of data for the account
  /// [commitment] - Optional commitment level
  ///
  /// Returns minimum balance in lamports
  Future<int> getMinimumBalanceForRentExemption(
    int dataLength, {
    CommitmentConfig? commitment,
  }) async {
    final result = await _makeRpcRequest('getMinimumBalanceForRentExemption', [
      dataLength,
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
      }
    ]);

    return result as int;
  }

  /// Check health of the RPC node
  ///
  /// Returns 'ok' if healthy, throws exception if not
  Future<String> checkHealth() async {
    final result = await _makeRpcRequest('getHealth', []);
    return result.toString();
  }

  /// Request airdrop for a public key (devnet and testnet only)
  ///
  /// [publicKey] - The public key to receive the airdrop
  /// [lamports] - Amount of lamports to airdrop
  /// [commitment] - Optional commitment level
  ///
  /// Returns the transaction signature of the airdrop
  Future<String> requestAirdrop(
    PublicKey publicKey,
    int lamports, {
    CommitmentConfig? commitment,
  }) async {
    final result = await _makeRpcRequest('requestAirdrop', [
      publicKey.toBase58(),
      lamports,
      {
        'commitment': (commitment ?? _config.commitment).commitment.value,
      }
    ]);

    return result as String;
  }

  /// Create connection from configuration
  ///
  /// [config] - Connection configuration
  ///
  /// Returns new connection instance
  static Connection fromConfig(ConnectionConfig config) {
    return Connection(config.rpcUrl, config: config);
  }

  /// Close the connection and cleanup resources
  void close() {
    _httpClient.close();
  }

  /// Subscribe to logs for a program or account
  ///
  /// [filter] - Either a program ID or "all" for all logs
  /// [callback] - Function to call when logs are received
  /// [commitment] - Optional commitment level
  ///
  /// Returns a subscription ID that can be used to unsubscribe
  Future<String> onLogs(
    dynamic filter, // Can be PublicKey, String, or "all"
    void Function(LogsNotification) callback, {
    CommitmentConfig? commitment,
  }) async {
    final subscriptionId = 'logs_${_subscriptionIdCounter++}';

    // Create WebSocket connection
    final wsUrl = _endpoint.replaceFirst('http', 'ws');
    final channel = IOWebSocketChannel.connect(wsUrl);

    // Prepare subscription request
    String filterValue;
    if (filter is PublicKey) {
      filterValue = filter.toBase58();
    } else if (filter is String) {
      filterValue = filter;
    } else {
      throw ArgumentError('Filter must be PublicKey, String, or "all"');
    }

    final subscribeRequest = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'logsSubscribe',
      'params': [
        filterValue,
        {
          'commitment': (commitment ?? _config.commitment).commitment.value,
          'encoding': 'jsonParsed',
        },
      ],
    };

    // Send subscription request
    channel.sink.add(jsonEncode(subscribeRequest));

    // Listen for messages
    channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;

          if (data.containsKey('method') &&
              data['method'] == 'logsNotification') {
            final params = data['params'] as Map<String, dynamic>;
            final result = params['result'] as Map<String, dynamic>;
            final context = result['context'] as Map<String, dynamic>;
            final value = result['value'] as Map<String, dynamic>;

            final notification = LogsNotification(
              signature: value['signature'] as String,
              logs: (value['logs'] as List<dynamic>).cast<String>(),
              err: value['err'] as String?,
              slot: context['slot'] as int,
            );

            callback(notification);
          }
        } catch (e) {
          // Log error but continue processing
          // TODO: Use proper logging framework instead of print
          print('Error processing logs notification: $e');
        }
      },
      onError: (Object error) {
        // TODO: Use proper logging framework instead of print
        print('WebSocket error: $error');
      },
      onDone: () {
        _subscriptions.remove(subscriptionId);
      },
    );

    _subscriptions[subscriptionId] = channel;
    return subscriptionId;
  }

  /// Remove a logs subscription
  ///
  /// [subscriptionId] - The subscription ID returned from onLogs
  Future<void> removeOnLogsListener(String subscriptionId) async {
    final channel = _subscriptions.remove(subscriptionId);
    if (channel != null) {
      await channel.sink.close();
    }
  }

  /// Internal helper to make RPC requests
  Future<dynamic> _makeRpcRequest(
    String method,
    List<dynamic> params,
  ) async {
    final requestBody = {
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': method,
      'params': params,
    };

    print('DEBUG: _makeRpcRequest called with method: $method');
    print('DEBUG: _makeRpcRequest params: $params');

    try {
      final response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('DEBUG: HTTP response status: ${response.statusCode}');
      print('DEBUG: HTTP response body: ${response.body}');

      if (response.statusCode != 200) {
        throw RpcException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      print('DEBUG: Parsed response data: $responseData');

      if (responseData['error'] != null) {
        final error = responseData['error'] as Map<String, dynamic>;
        throw RpcException(
          'RPC Error ${error['code']}: ${error['message']}',
        );
      }

      final result = responseData['result'];
      print('DEBUG: Result from RPC: $result');
      print('DEBUG: Result type: ${result.runtimeType}');

      return result;
    } catch (e) {
      print('DEBUG: Exception in _makeRpcRequest: $e');
      if (e is RpcException) rethrow;
      throw RpcException('Failed to make RPC request: $e');
    }
  }
}

/// Account information returned by getAccountInfo
class AccountInfo {
  final bool executable;
  final int lamports;
  final PublicKey owner;
  final dynamic data; // Can be String (base64) or Uint8List
  final int rentEpoch;

  const AccountInfo({
    required this.executable,
    required this.lamports,
    required this.owner,
    this.data,
    required this.rentEpoch,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    dynamic data;
    if (json['data'] != null) {
      final rawData = json['data'];
      if (rawData is String) {
        // Keep string format as-is for backward compatibility
        data = rawData;
      } else if (rawData is List && rawData.isNotEmpty) {
        // Handle array format like ['base64-encoded-data', 'base64']
        // Take the first element which is typically the data
        data = rawData.first;
      }
    }

    return AccountInfo(
      executable: json['executable'] as bool,
      lamports: (json['lamports'] as num).toInt(),
      owner: PublicKey.fromBase58(json['owner'] as String),
      data: data,
      rentEpoch: (json['rentEpoch'] as num).toInt(),
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

  factory LatestBlockhash.fromJson(Map<String, dynamic> json) {
    return LatestBlockhash(
      blockhash: json['blockhash'] as String,
      lastValidBlockHeight: json['lastValidBlockHeight'] as int,
    );
  }
}

/// Base class for account filters
abstract class AccountFilter {
  Map<String, dynamic> toJson();
}

/// Memory comparison filter
class MemcmpFilter extends AccountFilter {
  final int offset;
  final String bytes;

  MemcmpFilter({
    required this.offset,
    required this.bytes,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'memcmp': {
        'offset': offset,
        'bytes': bytes,
      },
    };
  }
}

/// Data size filter
class DataSizeFilter extends AccountFilter {
  final int dataSize;

  DataSizeFilter(this.dataSize);

  /// Named constructor for backward compatibility
  DataSizeFilter.named({required this.dataSize});

  @override
  Map<String, dynamic> toJson() {
    return {
      'dataSize': dataSize,
    };
  }
}

/// Token account filter
class TokenAccountFilter extends AccountFilter {
  final String mint;

  TokenAccountFilter(this.mint);

  @override
  Map<String, dynamic> toJson() {
    return {
      'tokenAccountState': 'initialized',
      'mint': mint,
    };
  }
}

/// Program account information returned by getProgramAccounts
class ProgramAccountInfo {
  final PublicKey pubkey;
  final AccountInfo account;

  const ProgramAccountInfo({
    required this.pubkey,
    required this.account,
  });

  factory ProgramAccountInfo.fromJson(Map<String, dynamic> json) {
    return ProgramAccountInfo(
      pubkey: PublicKey.fromBase58(json['pubkey'] as String),
      account: AccountInfo.fromJson(json['account'] as Map<String, dynamic>),
    );
  }
}

/// Send transaction options
class SendTransactionOptions {
  final bool skipPreflight;
  final String preflightCommitment;
  final int maxRetries;

  const SendTransactionOptions({
    this.skipPreflight = false,
    this.preflightCommitment = 'processed',
    this.maxRetries = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'skipPreflight': skipPreflight,
      'preflightCommitment': preflightCommitment,
      'maxRetries': maxRetries,
    };
  }
}

/// RPC transaction confirmation
class RpcTransactionConfirmation {
  final String signature;
  final String? err;
  final Map<String, dynamic>? meta;
  final int? slot;
  final int? confirmations;
  final String? confirmationStatus;
  final bool isSuccess;

  const RpcTransactionConfirmation({
    required this.signature,
    this.err,
    this.meta,
    this.slot,
    this.confirmations,
    this.confirmationStatus,
  }) : isSuccess = err == null;

  factory RpcTransactionConfirmation.fromJson(Map<String, dynamic> json) {
    return RpcTransactionConfirmation(
      signature: json['signature'] as String? ??
          '', // Default to empty string if not provided
      err: json['err'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
      slot: json['slot'] as int?,
      confirmations: json['confirmations'] as int?,
      confirmationStatus: json['confirmationStatus'] as String?,
    );
  }
}

/// Helper functions for creating account filters

/// Create a memory comparison filter
MemcmpFilter memcmpFilter({required int offset, required String bytes}) {
  return MemcmpFilter(offset: offset, bytes: bytes);
}

/// Create a data size filter
DataSizeFilter dataSizeFilter(int dataSize) {
  return DataSizeFilter(dataSize);
}

/// Create a token account filter
TokenAccountFilter tokenAccountFilter(String mint) {
  return TokenAccountFilter(mint);
}

/// Logs notification data
class LogsNotification {
  final String signature;
  final List<String> logs;
  final String? err;
  final int slot;

  LogsNotification({
    required this.signature,
    required this.logs,
    this.err,
    required this.slot,
  });

  /// Whether the transaction succeeded
  bool get isSuccess => err == null;
}
