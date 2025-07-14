/// Connection configuration types for Solana RPC
///
/// This module defines configuration options for connecting to
/// Solana RPC endpoints, including timeouts, retry logic, and
/// connection parameters.

library;

import 'package:coral_xyz_anchor/src/types/commitment.dart';

/// Configuration for Solana RPC connection
class ConnectionConfig {

  const ConnectionConfig({
    required this.rpcUrl,
    this.websocketUrl,
    this.commitment = CommitmentConfigs.finalized,
    this.timeoutMs = 30000,
    this.retryAttempts = 3,
    this.retryDelayMs = 1000,
    this.confirmTransactions = true,
    this.skipPreflight = false,
    this.preflightCommitment = CommitmentConfigs.processed,
    this.maxRetries = 30,
    this.headers = const {},
  });

  /// Create a connection config for devnet
  factory ConnectionConfig.devnet({
    CommitmentConfig? commitment,
    int? timeoutMs,
  }) {
    return ConnectionConfig(
      rpcUrl: 'https://api.devnet.solana.com',
      websocketUrl: 'wss://api.devnet.solana.com',
      commitment: commitment ?? CommitmentConfigs.confirmed,
      timeoutMs: timeoutMs ?? 30000,
    );
  }

  /// Create a connection config for testnet
  factory ConnectionConfig.testnet({
    CommitmentConfig? commitment,
    int? timeoutMs,
  }) {
    return ConnectionConfig(
      rpcUrl: 'https://api.testnet.solana.com',
      websocketUrl: 'wss://api.testnet.solana.com',
      commitment: commitment ?? CommitmentConfigs.confirmed,
      timeoutMs: timeoutMs ?? 30000,
    );
  }

  /// Create a connection config for mainnet-beta
  factory ConnectionConfig.mainnet({
    CommitmentConfig? commitment,
    int? timeoutMs,
  }) {
    return ConnectionConfig(
      rpcUrl: 'https://api.mainnet-beta.solana.com',
      websocketUrl: 'wss://api.mainnet-beta.solana.com',
      commitment: commitment ?? CommitmentConfigs.finalized,
      timeoutMs: timeoutMs ?? 30000,
    );
  }

  /// Create a connection config for localhost
  factory ConnectionConfig.localhost({
    int port = 8899,
    CommitmentConfig? commitment,
    int? timeoutMs,
  }) {
    return ConnectionConfig(
      rpcUrl: 'http://localhost:$port',
      websocketUrl: 'ws://localhost:${port + 1}',
      commitment: commitment ?? CommitmentConfigs.processed,
      timeoutMs: timeoutMs ?? 30000,
    );
  }

  /// Create from JSON
  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      rpcUrl: json['rpcUrl'] as String,
      websocketUrl: json['websocketUrl'] as String?,
      commitment: CommitmentConfig.fromJson(
        json['commitment'] as Map<String, dynamic>? ?? {},
      ),
      timeoutMs: json['timeoutMs'] as int? ?? 30000,
      retryAttempts: json['retryAttempts'] as int? ?? 3,
      retryDelayMs: json['retryDelayMs'] as int? ?? 1000,
      confirmTransactions: json['confirmTransactions'] as bool? ?? true,
      skipPreflight: json['skipPreflight'] as bool? ?? false,
      preflightCommitment: CommitmentConfig.fromJson(
        json['preflightCommitment'] as Map<String, dynamic>? ?? {},
      ),
      maxRetries: json['maxRetries'] as int? ?? 30,
      headers: Map<String, String>.from(
        json['headers'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
  /// The RPC endpoint URL
  final String rpcUrl;

  /// The WebSocket endpoint URL (optional)
  final String? websocketUrl;

  /// Default commitment level for requests
  final CommitmentConfig commitment;

  /// Request timeout in milliseconds
  final int timeoutMs;

  /// Number of retry attempts for failed requests
  final int retryAttempts;

  /// Delay between retry attempts in milliseconds
  final int retryDelayMs;

  /// Whether to confirm transactions automatically
  final bool confirmTransactions;

  /// Skip preflight checks for transactions
  final bool skipPreflight;

  /// Preflight commitment level
  final CommitmentConfig preflightCommitment;

  /// Maximum number of retries for transaction confirmation
  final int maxRetries;

  /// Custom HTTP headers
  final Map<String, String> headers;

  /// Copy this config with some fields changed
  ConnectionConfig copyWith({
    String? rpcUrl,
    String? websocketUrl,
    CommitmentConfig? commitment,
    int? timeoutMs,
    int? retryAttempts,
    int? retryDelayMs,
    bool? confirmTransactions,
    bool? skipPreflight,
    CommitmentConfig? preflightCommitment,
    int? maxRetries,
    Map<String, String>? headers,
  }) => ConnectionConfig(
      rpcUrl: rpcUrl ?? this.rpcUrl,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      commitment: commitment ?? this.commitment,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelayMs: retryDelayMs ?? this.retryDelayMs,
      confirmTransactions: confirmTransactions ?? this.confirmTransactions,
      skipPreflight: skipPreflight ?? this.skipPreflight,
      preflightCommitment: preflightCommitment ?? this.preflightCommitment,
      maxRetries: maxRetries ?? this.maxRetries,
      headers: headers ?? this.headers,
    );

  /// Convert to JSON representation
  Map<String, dynamic> toJson() => {
      'rpcUrl': rpcUrl,
      'websocketUrl': websocketUrl,
      'commitment': commitment.toJson(),
      'timeoutMs': timeoutMs,
      'retryAttempts': retryAttempts,
      'retryDelayMs': retryDelayMs,
      'confirmTransactions': confirmTransactions,
      'skipPreflight': skipPreflight,
      'preflightCommitment': preflightCommitment.toJson(),
      'maxRetries': maxRetries,
      'headers': headers,
    };

  @override
  String toString() => 'ConnectionConfig(rpcUrl: $rpcUrl, commitment: ${commitment.commitment.value})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionConfig &&
        other.rpcUrl == rpcUrl &&
        other.websocketUrl == websocketUrl &&
        other.commitment == commitment &&
        other.timeoutMs == timeoutMs &&
        other.retryAttempts == retryAttempts &&
        other.retryDelayMs == retryDelayMs &&
        other.confirmTransactions == confirmTransactions &&
        other.skipPreflight == skipPreflight &&
        other.preflightCommitment == preflightCommitment &&
        other.maxRetries == maxRetries;
  }

  @override
  int get hashCode => Object.hash(
      rpcUrl,
      websocketUrl,
      commitment,
      timeoutMs,
      retryAttempts,
      retryDelayMs,
      confirmTransactions,
      skipPreflight,
      preflightCommitment,
      maxRetries,
    );
}

/// Configuration for transaction sending
class SendTransactionConfig {

  const SendTransactionConfig({
    this.skipPreflight = false,
    this.preflightCommitment = CommitmentConfigs.processed,
    this.maxRetries = 3,
    this.minContextSlot = 0,
  });
  /// Skip preflight transaction verification
  final bool skipPreflight;

  /// Preflight commitment level
  final CommitmentConfig preflightCommitment;

  /// Maximum number of times for the RPC node to retry sending the transaction
  final int maxRetries;

  /// Minimum number of slot confirmations for the transaction
  final int minContextSlot;

  /// Convert to JSON for RPC calls
  Map<String, dynamic> toJson() => {
      'skipPreflight': skipPreflight,
      'preflightCommitment': preflightCommitment.commitment.value,
      'maxRetries': maxRetries,
      'minContextSlot': minContextSlot,
    };

  @override
  String toString() => 'SendTransactionConfig(skipPreflight: $skipPreflight, maxRetries: $maxRetries)';
}
