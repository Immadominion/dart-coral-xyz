/// Unified provider interface matching TypeScript Anchor's provider abstraction
///
/// This module provides the core provider interface that abstracts implementation
/// details and enables flexible provider switching, factory patterns, and
/// comprehensive wallet integration capabilities.

library;

import 'dart:async';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart'
    show TransactionSimulationResult;
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';

/// Unified provider interface abstracting implementation details
///
/// This interface matches TypeScript's Provider interface and provides a
/// consistent API surface across different provider implementations including
/// keypair-based, mobile wallet, and hardware wallet providers.
abstract class ProviderInterface {
  /// The connection to the Solana cluster
  Connection get connection;

  /// The wallet used for signing transactions (optional)
  Wallet? get wallet;

  /// The public key of the wallet, if available
  PublicKey? get publicKey;

  /// Send and confirm a transaction
  ///
  /// Signs the transaction with the provider's wallet and sends it to the
  /// network, waiting for confirmation according to the specified options.
  ///
  /// [transaction] - The transaction to send
  /// [signers] - Additional signers for the transaction
  /// [options] - Transaction confirmation options
  /// Returns the transaction signature
  Future<String> sendAndConfirm(
    Transaction transaction, {
    List<Keypair>? signers,
    ConfirmOptions? options,
  });

  /// Send multiple transactions and confirm them
  ///
  /// Signs and sends multiple transactions in batch, waiting for all to
  /// confirm. This is more efficient than sending transactions individually.
  ///
  /// [transactions] - List of transactions with their additional signers
  /// [options] - Transaction confirmation options
  /// Returns list of transaction signatures
  Future<List<String>> sendAll(
    List<TransactionWithSigners> transactions, {
    ConfirmOptions? options,
  });

  /// Simulate a transaction without sending it
  ///
  /// Executes the transaction against the current state to check for errors
  /// and preview the results without committing to the blockchain.
  ///
  /// [transaction] - The transaction to simulate
  /// [signers] - Additional signers for simulation
  /// [commitment] - Commitment level for simulation
  /// [includeAccounts] - Accounts to include in simulation result
  /// Returns simulation result with logs and account changes
  Future<TransactionSimulationResult> simulate(
    Transaction transaction, {
    List<Keypair>? signers,
    CommitmentConfig? commitment,
    List<PublicKey>? includeAccounts,
  });

  /// Get provider type identifier
  ProviderType get providerType;

  /// Get provider configuration
  ProviderConfig get config;

  /// Check if provider is connected and ready
  bool get isConnected;

  /// Connect the provider (for wallet-based providers)
  Future<void> connect();

  /// Disconnect the provider and cleanup resources
  Future<void> disconnect();

  /// Listen to provider connection status changes
  Stream<ProviderConnectionStatus> get connectionStatus;
}

/// Provider type enumeration
enum ProviderType {
  /// Keypair-based provider (for testing and development)
  keypair,

  /// Mobile wallet provider (Phantom, Solflare, etc.)
  mobileWallet,

  /// Hardware wallet provider (Ledger, etc.)
  hardwareWallet,

  /// Custom provider implementation
  custom,
}

/// Provider configuration
class ProviderConfig {

  const ProviderConfig({
    required this.type,
    required this.name,
    required this.version,
    this.capabilities = const {},
    this.properties = const {},
  });
  /// Provider type
  final ProviderType type;

  /// Provider name/identifier
  final String name;

  /// Provider version
  final String version;

  /// Provider capabilities
  final Set<ProviderCapability> capabilities;

  /// Custom configuration properties
  final Map<String, dynamic> properties;

  /// Copy configuration with overrides
  ProviderConfig copyWith({
    ProviderType? type,
    String? name,
    String? version,
    Set<ProviderCapability>? capabilities,
    Map<String, dynamic>? properties,
  }) => ProviderConfig(
      type: type ?? this.type,
      name: name ?? this.name,
      version: version ?? this.version,
      capabilities: capabilities ?? this.capabilities,
      properties: properties ?? this.properties,
    );

  @override
  String toString() => 'ProviderConfig(type: $type, name: $name, version: $version, '
        'capabilities: $capabilities, properties: ${properties.keys})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProviderConfig &&
        other.type == type &&
        other.name == name &&
        other.version == version &&
        other.capabilities == capabilities &&
        _mapEquals(other.properties, properties);
  }

  @override
  int get hashCode => Object.hash(type, name, version, capabilities, properties);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Provider capability enumeration
enum ProviderCapability {
  /// Can sign transactions
  signTransaction,

  /// Can sign multiple transactions in batch
  signAllTransactions,

  /// Can sign arbitrary messages
  signMessage,

  /// Supports transaction simulation
  simulateTransaction,

  /// Supports connection management
  connectionManagement,

  /// Supports session persistence
  sessionPersistence,

  /// Supports hardware security
  hardwareSecurity,

  /// Supports mobile deep linking
  mobileDeepLinking,
}

/// Provider connection status
class ProviderConnectionStatus {

  const ProviderConnectionStatus({
    required this.isConnected,
    required this.timestamp,
    this.error,
    this.metadata = const {},
  });

  /// Create connected status
  factory ProviderConnectionStatus.connected({
    Map<String, dynamic> metadata = const {},
  }) {
    return ProviderConnectionStatus(
      isConnected: true,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Create disconnected status
  factory ProviderConnectionStatus.disconnected({
    Exception? error,
    Map<String, dynamic> metadata = const {},
  }) {
    return ProviderConnectionStatus(
      isConnected: false,
      timestamp: DateTime.now(),
      error: error,
      metadata: metadata,
    );
  }
  /// Whether the provider is connected
  final bool isConnected;

  /// Connection timestamp
  final DateTime timestamp;

  /// Connection error, if any
  final Exception? error;

  /// Additional status information
  final Map<String, dynamic> metadata;

  @override
  String toString() => 'ProviderConnectionStatus(isConnected: $isConnected, '
        'timestamp: $timestamp, error: $error, metadata: $metadata)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProviderConnectionStatus &&
        other.isConnected == isConnected &&
        other.timestamp == timestamp &&
        other.error == error &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(isConnected, timestamp, error, metadata);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Base provider implementation with common functionality
abstract class BaseProvider implements ProviderInterface {

  BaseProvider({
    required this.connection,
    required this.config,
  })  : _connectionStatusController =
            StreamController<ProviderConnectionStatus>.broadcast(),
        _currentStatus = ProviderConnectionStatus.disconnected();
  /// Connection instance
  @override
  final Connection connection;

  /// Provider configuration
  @override
  final ProviderConfig config;

  /// Connection status controller
  final StreamController<ProviderConnectionStatus> _connectionStatusController;

  /// Current connection status
  ProviderConnectionStatus _currentStatus;

  @override
  ProviderType get providerType => config.type;

  @override
  bool get isConnected => _currentStatus.isConnected;

  @override
  Stream<ProviderConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  /// Update connection status
  void updateConnectionStatus(ProviderConnectionStatus status) {
    _currentStatus = status;
    _connectionStatusController.add(status);
  }

  @override
  Future<void> disconnect() async {
    updateConnectionStatus(ProviderConnectionStatus.disconnected());
    await _connectionStatusController.close();
  }

  /// Default implementation for simulation
  @override
  Future<TransactionSimulationResult> simulate(
    Transaction transaction, {
    List<Keypair>? signers,
    CommitmentConfig? commitment,
    List<PublicKey>? includeAccounts,
  }) async {
    // For now, return a mock simulation result
    // This should be overridden by concrete provider implementations
    return const TransactionSimulationResult(
      success: true,
      logs: ['Program log: Simulation not yet implemented in base provider'],
    );
  }
}
