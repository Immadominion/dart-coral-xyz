/// Connection class for RPC communication with Solana clusters
///
/// This module provides the core Connection class that handles RPC
/// communication with Solana validators, manages endpoint configuration,
/// and provides health checking and retry logic.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../types/commitment.dart';
import '../types/connection_config.dart';
import '../types/public_key.dart';
import '../utils/logger.dart';
import '../utils/rpc_errors.dart';

/// Connection to a Solana cluster for RPC communication
///
/// This class provides the primary interface for communicating with
/// Solana validators. It handles connection management, endpoint
/// configuration, commitment levels, and retry logic.
class Connection {
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
  final String _endpoint;
  final ConnectionConfig _config;
  final http.Client _httpClient;
  static final AnchorLogger _logger = AnchorLogger.getLogger('Connection');

  /// WebSocket connections for subscriptions
  final Map<String, IOWebSocketChannel> _subscriptions = {};

  /// Subscription ID counter
  int _subscriptionIdCounter = 1;

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
        _logger.info(
          'Connection sendAndConfirmTransaction attempt ${attempt + 1}/$maxRetries',
        );

        // Handle both Map and Uint8List transaction formats
        final txData = transaction is Uint8List
            ? transaction
            : transaction is Map<String, dynamic>
                ? transaction
                : throw ArgumentError('Transaction must be a Map or Uint8List');

        // Convert Uint8List to base64 if needed
        _logger.debug('txData type: ${txData.runtimeType}');
        _logger.debug('txData is Uint8List: ${txData is Uint8List}');

        final List<dynamic> params =
            txData is Uint8List ? [base64.encode(txData)] : [txData];
        _logger.debug('params after base64 encode: $params');

        // Add options
        final commitmentValue =
            (commitment ?? _config.commitment).commitment.value;
        _logger.debug('commitment param: $commitment');
        _logger.debug('_config.commitment: ${_config.commitment}');
        _logger.debug('final commitment value: $commitmentValue');

        final options = <String, dynamic>{
          'encoding': 'base64',
          'commitment': commitmentValue,
          'skipPreflight':
              true, // Skip simulation to avoid blockhash timing issues
        };
        params.add(options);
        _logger.debug('Added options to params: $options');

        String signature;
        try {
          _logger.debug('About to call _makeRpcRequest for sendTransaction');
          final result = await _makeRpcRequest('sendTransaction', params);
          _logger.debug('sendTransaction successful, result: $result');
          _logger.debug('sendTransaction result type: ${result.runtimeType}');

          // Handle different response formats
          if (result is String) {
            // Direct string response (most common for sendTransaction)
            signature = result;
            _logger.debug('Got direct string signature: $signature');
          } else if (result is Map<String, dynamic>) {
            // RPC response might have the signature in different fields
            _logger.debug('Got Map response, keys: ${result.keys.toList()}');
            if (result.containsKey('value')) {
              final value = result['value'];
              _logger.debug(
                'Found value field: $value (type: ${value.runtimeType})',
              );

              // Handle case where value might be a Map instead of String
              if (value is String) {
                signature = value;
              } else if (value is Map<String, dynamic>) {
                // Look for signature field in the nested map
                if (value.containsKey('signature')) {
                  signature = value['signature'] as String;
                  _logger.debug('Found signature in nested map: $signature');
                } else {
                  _logger.debug('No signature field in nested map: $value');
                  throw RpcException(
                    'No signature field found in nested response map: $value',
                  );
                }
              } else {
                throw RpcException(
                  'Unexpected value type in response: ${value.runtimeType}',
                );
              }
            } else if (result.containsKey('signature')) {
              signature = result['signature'] as String;
            } else {
              // If it's a simple map, try to extract string value
              final values = result.values.whereType<String>();
              if (values.isNotEmpty) {
                signature = values.first;
              } else {
                throw RpcException(
                  'Unexpected sendTransaction response format: $result',
                );
              }
            }
          } else {
            throw RpcException(
              'Unexpected sendTransaction response type: ${result.runtimeType}',
            );
          }

          _logger.debug('Extracted signature: $signature');

          // Confirm the transaction
          _logger.debug(
            'About to confirm transaction with signature: $signature',
          );
          try {
            await _confirmTransaction(signature, commitment);
            _logger.info('Transaction confirmation completed successfully');
          } catch (confirmError) {
            _logger.error(
              'Error during transaction confirmation: $confirmError',
            );
            _logger.debug(
              'Confirmation error type: ${confirmError.runtimeType}',
            );
            rethrow;
          }
        } catch (e) {
          _logger.error('Exception in sendTransaction: $e');
          _logger.debug('Exception type: ${e.runtimeType}');
          _logger.debug('Exception stack trace: ${StackTrace.current}');
          rethrow;
        }

        _logger.info(
          'Connection sendAndConfirmTransaction success on attempt ${attempt + 1}',
        );
        return signature;
      } catch (e) {
        final errorString = e.toString();
        final isBlockhashError = errorString.contains('Blockhash not found') ||
            errorString.contains('BlockhashNotFound') ||
            errorString.contains('Invalid blockhash');

        if (isBlockhashError && attempt < maxRetries - 1) {
          _logger.warn(
            'Blockhash error at connection level on attempt ${attempt + 1}, retrying...',
          );
          // Wait a bit before retry
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }

        // If it's not a blockhash error or we've exhausted retries, rethrow
        _logger.error(
          'Connection sendAndConfirmTransaction failed on attempt ${attempt + 1}: $e',
        );
        rethrow;
      }
    }

    // This should never be reached due to the loop structure, but just in case
    throw Exception(
      'Connection sendAndConfirmTransaction: Maximum retry attempts exceeded',
    );
  }

  /// Internal method to confirm a transaction
  Future<void> _confirmTransaction(
    String signature,
    CommitmentConfig? commitment,
  ) async {
    _logger.debug('_confirmTransaction called with signature: $signature');
    final maxRetries = 30;
    final delayMs = 1000;

    for (int i = 0; i < maxRetries; i++) {
      try {
        _logger.debug('_confirmTransaction attempt ${i + 1}/$maxRetries');
        final result = await _makeRpcRequest('getSignatureStatuses', [
          [signature],
          {'searchTransactionHistory': true},
        ]);

        _logger.debug('getSignatureStatuses result: $result');
        final resultMap = result as Map<String, dynamic>;
        _logger.debug('resultMap: $resultMap');
        final statuses = resultMap['value'] as List<dynamic>;
        _logger.debug('statuses: $statuses');
        if (statuses.isNotEmpty && statuses[0] != null) {
          final status = statuses[0] as Map<String, dynamic>;
          _logger.debug('status: $status');
          if (status['confirmationStatus'] != null) {
            final confirmationStatus = status['confirmationStatus'] as String;
            final targetCommitment =
                (commitment ?? _config.commitment).commitment.value;

            _logger.debug(
              'confirmationStatus: $confirmationStatus, targetCommitment: $targetCommitment',
            );
            if (_isCommitmentSatisfied(confirmationStatus, targetCommitment)) {
              if (status['err'] != null) {
                throw RpcException(
                  'Transaction failed: ${status['err'].toString()}',
                );
              }
              _logger.info('Transaction confirmed successfully');
              return; // Transaction confirmed successfully
            }
          }
        }
      } catch (e) {
        _logger.error('Exception in _confirmTransaction: $e');
        if (e is RpcException) rethrow;
        // Continue retrying on other errors
      }

      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    throw const RpcException('Transaction confirmation timeout');
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
  static Connection fromConfig(ConnectionConfig config) =>
      Connection(config.rpcUrl, config: config);

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
          _logger.error('Error processing logs notification', error: e);
        }
      },
      onError: (Object error) {
        _logger.error('WebSocket error', error: error);
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

    _logger.debug('_makeRpcRequest called with method: $method');
    _logger.debug('_makeRpcRequest params: $params');

    try {
      final response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      _logger.debug('HTTP response status: ${response.statusCode}');
      _logger.debug('HTTP response body: ${response.body}');

      if (response.statusCode != 200) {
        throw RpcException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      _logger.debug('Parsed response data: $responseData');

      if (responseData['error'] != null) {
        final error = responseData['error'] as Map<String, dynamic>;
        throw RpcException(
          'RPC Error ${error['code']}: ${error['message']}',
        );
      }

      final result = responseData['result'];
      _logger.debug('Result from RPC: $result');
      _logger.debug('Result type: ${result.runtimeType}');

      return result;
    } catch (e) {
      _logger.error('Exception in _makeRpcRequest: $e');
      if (e is RpcException) rethrow;
      throw RpcException('Failed to make RPC request: $e');
    }
  }
}

/// Account information returned by getAccountInfo
class AccountInfo {
  const AccountInfo({
    required this.executable,
    required this.lamports,
    required this.owner,
    required this.rentEpoch,
    this.data,
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
  final bool executable;
  final int lamports;
  final PublicKey owner;
  final dynamic data; // Can be String (base64) or Uint8List
  final int rentEpoch;
}

/// Latest blockhash information
class LatestBlockhash {
  const LatestBlockhash({
    required this.blockhash,
    required this.lastValidBlockHeight,
  });

  factory LatestBlockhash.fromJson(Map<String, dynamic> json) =>
      LatestBlockhash(
        blockhash: json['blockhash'] as String,
        lastValidBlockHeight: json['lastValidBlockHeight'] as int,
      );
  final String blockhash;
  final int lastValidBlockHeight;
}

/// Base class for account filters
abstract class AccountFilter {
  Map<String, dynamic> toJson();
}

/// Memory comparison filter
class MemcmpFilter extends AccountFilter {
  MemcmpFilter({
    required this.offset,
    required this.bytes,
  });
  final int offset;
  final String bytes;

  @override
  Map<String, dynamic> toJson() => {
        'memcmp': {
          'offset': offset,
          'bytes': bytes,
        },
      };
}

/// Data size filter
class DataSizeFilter extends AccountFilter {
  DataSizeFilter(this.dataSize);

  /// Named constructor for backward compatibility
  DataSizeFilter.named({required this.dataSize});
  final int dataSize;

  @override
  Map<String, dynamic> toJson() => {
        'dataSize': dataSize,
      };
}

/// Token account filter
class TokenAccountFilter extends AccountFilter {
  TokenAccountFilter(this.mint);
  final String mint;

  @override
  Map<String, dynamic> toJson() => {
        'tokenAccountState': 'initialized',
        'mint': mint,
      };
}

/// Program account information returned by getProgramAccounts
class ProgramAccountInfo {
  const ProgramAccountInfo({
    required this.pubkey,
    required this.account,
  });

  factory ProgramAccountInfo.fromJson(Map<String, dynamic> json) =>
      ProgramAccountInfo(
        pubkey: PublicKey.fromBase58(json['pubkey'] as String),
        account: AccountInfo.fromJson(json['account'] as Map<String, dynamic>),
      );
  final PublicKey pubkey;
  final AccountInfo account;
}

/// Send transaction options
class SendTransactionOptions {
  const SendTransactionOptions({
    this.skipPreflight = false,
    this.preflightCommitment = 'processed',
    this.maxRetries = 0,
  });
  final bool skipPreflight;
  final String preflightCommitment;
  final int maxRetries;

  Map<String, dynamic> toJson() => {
        'skipPreflight': skipPreflight,
        'preflightCommitment': preflightCommitment,
        'maxRetries': maxRetries,
      };
}

/// RPC transaction confirmation
class RpcTransactionConfirmation {
  const RpcTransactionConfirmation({
    required this.signature,
    this.err,
    this.meta,
    this.slot,
    this.confirmations,
    this.confirmationStatus,
  }) : isSuccess = err == null;

  factory RpcTransactionConfirmation.fromJson(Map<String, dynamic> json) =>
      RpcTransactionConfirmation(
        signature: json['signature'] as String? ??
            '', // Default to empty string if not provided
        err: json['err'] as String?,
        meta: json['meta'] as Map<String, dynamic>?,
        slot: json['slot'] as int?,
        confirmations: json['confirmations'] as int?,
        confirmationStatus: json['confirmationStatus'] as String?,
      );
  final String signature;
  final String? err;
  final Map<String, dynamic>? meta;
  final int? slot;
  final int? confirmations;
  final String? confirmationStatus;
  final bool isSuccess;
}

/// Helper functions for creating account filters

/// Create a memory comparison filter
MemcmpFilter memcmpFilter({required int offset, required String bytes}) =>
    MemcmpFilter(offset: offset, bytes: bytes);

/// Create a data size filter
DataSizeFilter dataSizeFilter(int dataSize) => DataSizeFilter(dataSize);

/// Create a token account filter
TokenAccountFilter tokenAccountFilter(String mint) => TokenAccountFilter(mint);

/// Logs notification data
class LogsNotification {
  LogsNotification({
    required this.signature,
    required this.logs,
    required this.slot,
    this.err,
  });
  final String signature;
  final List<String> logs;
  final String? err;
  final int slot;

  /// Whether the transaction succeeded
  bool get isSuccess => err == null;
}
