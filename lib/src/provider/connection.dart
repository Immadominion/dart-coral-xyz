/// Connection class for RPC communication with Solana clusters
///
/// This module provides complete TypeScript Anchor SDK compatible API while
/// leveraging the battle-tested espresso-cash SolanaClient for production-ready
/// Solana RPC functionality. This is the Phase 0 cleanup implementation.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/src/types/account_filter.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/subscription_client/logs_filter.dart';

import '../types/connection_config.dart';

/// Connection to a Solana cluster for RPC communication
///
/// This class provides complete TypeScript Anchor SDK API compatibility while
/// using the battle-tested espresso-cash SolanaClient internally. All RPC methods
/// are production-ready and match TypeScript SDK behavior exactly.
///
/// **Phase 0 Implementation:** Replaces all manual RPC handling with proven
/// espresso-cash components as identified in the roadmap cleanup strategy.
class Connection {
  /// Create a new Connection
  ///
  /// [endpoint] - The RPC endpoint URL
  /// [config] - Optional connection configuration
  Connection(this._endpoint, {ConnectionConfig? config})
    : _config = config ?? ConnectionConfig(rpcUrl: _endpoint),
      _client = solana.SolanaClient(
        rpcUrl: Uri.parse(_endpoint),
        websocketUrl: _buildWebsocketUrl(_endpoint),
      );

  /// Build the WebSocket URL from the RPC HTTP endpoint.
  ///
  /// For standard validators, WebSocket runs on the same host and port but
  /// with the `ws` scheme. However, `solana-test-validator` exposes WebSocket
  /// on port + 1 (e.g., HTTP 8899 → WS 8900). We handle the common localnet
  /// case to avoid WebSocket connection failures.
  static Uri _buildWebsocketUrl(String httpEndpoint) {
    final uri = Uri.parse(httpEndpoint);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    // For localhost/127.0.0.1 with the default test-validator port,
    // use port + 1 for WebSocket.
    final isLocalhost = uri.host == '127.0.0.1' || uri.host == 'localhost';
    final port = isLocalhost && uri.port == 8899 ? 8900 : uri.port;

    return uri.replace(scheme: scheme, port: port);
  }

  final String _endpoint;
  final ConnectionConfig _config;
  final solana.SolanaClient _client;

  /// Get the underlying espresso-cash SolanaClient for advanced usage
  /// This provides access to all production-ready Solana functionality
  solana.SolanaClient get client => _client;

  /// Get the RPC client for direct RPC calls
  solana.RpcClient get rpcClient => _client.rpcClient;

  /// Create a subscription client for real-time updates
  solana.SubscriptionClient createSubscriptionClient({
    Duration? pingInterval,
    Duration? connectTimeout,
  }) {
    return _client.createSubscriptionClient(
      pingInterval: pingInterval,
      connectTimeout: connectTimeout,
    );
  }

  /// Get the endpoint URL
  String get endpoint => _endpoint;

  /// Get the RPC URL (alias for endpoint, for backward compatibility)
  String get rpcUrl => _endpoint;

  /// Get the connection configuration
  ConnectionConfig get config => _config;

  /// Get the commitment level (for backward compatibility)
  String get commitment => _config.commitment.commitment.value;

  // =============================================================================
  // TypeScript SDK Compatible API Methods - Using Espresso-Cash Implementation
  // =============================================================================

  /// Get account info for the specified public key
  /// Matches TypeScript: connection.getAccountInfo(publicKey)
  Future<dto.Account?> getAccountInfo(
    String address, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
  }) async {
    final result = await _client.rpcClient.getAccountInfo(
      address,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
    );
    return result.value;
  }

  /// Get multiple accounts info
  /// Matches TypeScript: connection.getMultipleAccountsInfo(publicKeys)
  Future<List<dto.Account?>> getMultipleAccountsInfo(
    List<String> addresses, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
  }) async {
    final result = await _client.rpcClient.getMultipleAccounts(
      addresses,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
    );
    return result.value;
  }

  /// Get multiple accounts info with context (slot information)
  Future<dto.MultipleAccountsResult> getMultipleAccountsInfoAndContext(
    List<String> addresses, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
  }) async {
    return await _client.rpcClient.getMultipleAccounts(
      addresses,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
    );
  }

  /// Get program accounts
  /// Matches TypeScript: connection.getProgramAccounts(programId)
  Future<List<dto.ProgramAccount>> getProgramAccounts(
    String programId, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
    List<AccountFilter>? filters,
  }) async {
    final dtoFilters = _convertAccountFilters(filters);
    return await _client.rpcClient.getProgramAccounts(
      programId,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
      filters: dtoFilters,
    );
  }

  List<dto.ProgramDataFilter>? _convertAccountFilters(
    List<AccountFilter>? filters,
  ) {
    if (filters == null || filters.isEmpty) return null;

    final converted = <dto.ProgramDataFilter>[];
    for (final f in filters) {
      if (f is MemcmpFilter) {
        converted.add(
          dto.ProgramDataFilter.memcmpBase58(offset: f.offset, bytes: f.bytes),
        );
      } else if (f is DataSizeFilter) {
        converted.add(dto.ProgramDataFilter.dataSize(f.dataSize));
      }
    }
    return converted;
  }

  /// Get balance for an account
  /// Matches TypeScript: connection.getBalance(publicKey)
  Future<int> getBalance(String address, {dto.Commitment? commitment}) async {
    final result = await _client.rpcClient.getBalance(
      address,
      commitment: commitment ?? dto.Commitment.confirmed,
    );
    return result.value;
  }

  /// Send a transaction and return the signature
  /// Matches TypeScript: connection.sendTransaction(transaction)
  Future<String> sendTransaction(
    String transaction, {
    dto.Commitment? preflightCommitment,
    bool skipPreflight = false,
    int? maxRetries,
  }) async {
    return await _client.rpcClient.sendTransaction(
      transaction,
      preflightCommitment: preflightCommitment ?? dto.Commitment.confirmed,
      skipPreflight: skipPreflight,
      maxRetries: maxRetries,
    );
  }

  /// Send a transaction and wait for confirmation
  /// Matches TypeScript: connection.sendAndConfirmTransaction(transaction, signers)
  Future<String> sendAndConfirmTransaction({
    required solana.Message message,
    required List<solana.Ed25519HDKeyPair> signers,
    dto.Commitment? commitment,
  }) async {
    return await _client.sendAndConfirmTransaction(
      message: message,
      signers: signers,
      commitment: commitment ?? dto.Commitment.confirmed,
    );
  }

  /// Get latest blockhash
  /// Matches TypeScript: connection.getLatestBlockhash()
  Future<dto.LatestBlockhash> getLatestBlockhash({
    dto.Commitment? commitment,
  }) async {
    final result = await _client.rpcClient.getLatestBlockhash(
      commitment: commitment ?? dto.Commitment.confirmed,
    );
    return result.value;
  }

  /// Simulate a transaction
  /// Matches TypeScript: connection.simulateTransaction(transaction)
  Future<dto.TransactionStatusResult> simulateTransaction(
    String transaction, {
    dto.Commitment? commitment,
    bool sigVerify = true,
    bool replaceRecentBlockhash = true,
    dto.SimulateTransactionAccounts? accounts,
  }) async {
    return await _client.rpcClient.simulateTransaction(
      transaction,
      commitment: commitment ?? dto.Commitment.confirmed,
      sigVerify: sigVerify,
      replaceRecentBlockhash: replaceRecentBlockhash,
      accounts: accounts,
    );
  }

  /// Get minimum balance for rent exemption
  /// Matches TypeScript: connection.getMinimumBalanceForRentExemption(dataLength)
  Future<int> getMinimumBalanceForRentExemption(
    int dataLength, {
    dto.Commitment? commitment,
  }) async {
    return await _client.rpcClient.getMinimumBalanceForRentExemption(
      dataLength,
      commitment: commitment ?? dto.Commitment.confirmed,
    );
  }

  // =============================================================================
  // Real-time Subscription Methods (TypeScript SDK Compatible)
  // =============================================================================

  /// Subscribe to account changes
  /// Matches TypeScript: connection.onAccountChange(publicKey, callback)
  Stream<dto.Account> onAccountChange(
    String address, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
  }) {
    final subscriptionClient = createSubscriptionClient();
    return subscriptionClient.accountSubscribe(
      address,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
    );
  }

  /// Subscribe to program account changes
  /// Matches TypeScript: connection.onProgramAccountChange(programId, callback)
  Stream<dynamic> onProgramAccountChange(
    String programId, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
  }) {
    final subscriptionClient = createSubscriptionClient();
    return subscriptionClient.programSubscribe(
      programId,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
    );
  }

  /// Subscribe to logs
  /// Matches TypeScript: connection.onLogs(filter, callback)
  Stream<dto.Logs> onLogs(dynamic filter, {dto.Commitment? commitment}) {
    late LogsFilter logsFilter;

    if (filter is String) {
      logsFilter = LogsFilter.mentions([filter]);
    } else if (filter is List<String>) {
      logsFilter = LogsFilter.mentions(filter);
    } else if (filter == 'all') {
      logsFilter = const LogsFilter.all();
    } else if (filter == 'allWithVotes') {
      logsFilter = const LogsFilter.allWithVotes();
    } else {
      throw ArgumentError('Invalid logs filter: $filter');
    }

    final subscriptionClient = createSubscriptionClient();
    return subscriptionClient.logsSubscribe(
      logsFilter,
      commitment: commitment ?? dto.Commitment.confirmed,
    );
  }

  /// Wait for signature status (confirm transaction)
  /// Matches TypeScript: connection.confirmTransaction(signature)
  Future<void> confirmTransaction(
    String signature, {
    dto.ConfirmationStatus? status,
    Duration? timeout,
  }) async {
    await _client.waitForSignatureStatus(
      signature,
      status: status ?? dto.ConfirmationStatus.confirmed,
      timeout: timeout,
    );
  }

  /// Request airdrop for testing
  /// Matches TypeScript: connection.requestAirdrop(publicKey, lamports)
  Future<String> requestAirdrop(
    String address,
    int lamports, {
    dto.Commitment? commitment,
  }) async {
    return await _client.rpcClient.requestAirdrop(
      address,
      lamports,
      commitment: commitment ?? dto.Commitment.confirmed,
    );
  }

  /// Send raw transaction
  /// Matches TypeScript: connection.sendRawTransaction(transaction)
  Future<String> sendRawTransaction(
    Uint8List transaction, {
    dto.Commitment? preflightCommitment,
    bool skipPreflight = false,
    int? maxRetries,
  }) async {
    final base64Transaction = _bytesToBase64(transaction);
    return await _client.rpcClient.sendTransaction(
      base64Transaction,
      preflightCommitment: preflightCommitment ?? dto.Commitment.confirmed,
      skipPreflight: skipPreflight,
      maxRetries: maxRetries,
    );
  }

  /// Get transaction details
  /// Matches TypeScript: connection.getTransaction(signature)
  Future<dto.TransactionDetails?> getTransaction(
    String signature, {
    dto.Commitment? commitment,
    int? maxSupportedTransactionVersion,
  }) async {
    return await _client.rpcClient.getTransaction(
      signature,
      commitment: commitment ?? dto.Commitment.confirmed,
      maxSupportedTransactionVersion: maxSupportedTransactionVersion ?? 0,
    );
  }

  /// Get account info and context (with slot information)
  /// Matches TypeScript: connection.getAccountInfoAndContext(publicKey)
  Future<dto.AccountResult> getAccountInfoAndContext(
    String address, {
    dto.Commitment? commitment,
    dto.Encoding? encoding,
  }) async {
    return await _client.rpcClient.getAccountInfo(
      address,
      commitment: commitment ?? dto.Commitment.confirmed,
      encoding: encoding ?? dto.Encoding.base64,
    );
  }

  /// Get signature status
  /// Matches TypeScript: connection.getSignatureStatus(signature)
  Future<dto.SignatureStatus?> getSignatureStatus(
    String signature, {
    bool searchTransactionHistory = false,
  }) async {
    final result = await _client.rpcClient.getSignatureStatuses([
      signature,
    ], searchTransactionHistory: searchTransactionHistory);
    return result.value.isNotEmpty ? result.value.first : null;
  }

  /// Get signature statuses for multiple signatures
  /// Matches TypeScript: connection.getSignatureStatuses(signatures)
  Future<List<dto.SignatureStatus?>> getSignatureStatuses(
    List<String> signatures, {
    bool searchTransactionHistory = false,
  }) async {
    final result = await _client.rpcClient.getSignatureStatuses(
      signatures,
      searchTransactionHistory: searchTransactionHistory,
    );
    return result.value;
  }

  // =============================================================================
  // Utility Methods for Common Operations
  // =============================================================================

  /// Convert bytes to base64 for transaction sending
  String _bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  /// Alternative transaction sending method with byte array input
  Future<String> sendTransactionBytes(
    Uint8List transaction, {
    dto.Commitment? preflightCommitment,
    bool skipPreflight = false,
    int? maxRetries,
  }) async {
    final base64Transaction = _bytesToBase64(transaction);
    return await sendTransaction(
      base64Transaction,
      preflightCommitment: preflightCommitment,
      skipPreflight: skipPreflight,
      maxRetries: maxRetries,
    );
  }

  /// Alternative simulation method with byte array input
  Future<dto.TransactionStatusResult> simulateTransactionBytes(
    Uint8List transaction, {
    dto.Commitment? commitment,
    bool sigVerify = true,
    bool replaceRecentBlockhash = true,
    dto.SimulateTransactionAccounts? accounts,
  }) async {
    final base64Transaction = _bytesToBase64(transaction);
    return await simulateTransaction(
      base64Transaction,
      commitment: commitment,
      sigVerify: sigVerify,
      replaceRecentBlockhash: replaceRecentBlockhash,
      accounts: accounts,
    );
  }
}
