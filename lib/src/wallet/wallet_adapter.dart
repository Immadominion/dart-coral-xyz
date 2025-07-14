/// Advanced wallet adapter interface following Solana wallet standards
///
/// This module provides a comprehensive wallet adapter interface that matches
/// the TypeScript Solana wallet adapter ecosystem, enabling standardized
/// wallet integration across different wallet providers.

library;

import 'dart:async';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';

/// Standard wallet adapter interface following Solana wallet adapter standards
///
/// This interface defines the contract that all wallet adapter implementations
/// must follow to be compatible with the Solana ecosystem. It provides
/// standardized methods for connection, signing, and event handling.
abstract class WalletAdapter {
  /// The unique name identifier for this wallet adapter
  String get name;

  /// The display icon URL or asset path for this wallet
  String? get icon;

  /// The website URL for this wallet provider
  String? get url;

  /// Current readiness state of the wallet adapter
  WalletReadyState get readyState;

  /// The public key of the currently connected account, or null if not connected
  PublicKey? get publicKey;

  /// Whether the wallet is currently connected and ready to use
  bool get connected;

  /// Whether this wallet adapter supports the current environment/platform
  bool get supported;

  /// Additional properties specific to the wallet implementation
  Map<String, dynamic> get properties;

  /// Connect to the wallet and request user authorization
  ///
  /// This method initiates the connection process with the wallet. For mobile
  /// wallets, this may launch the wallet app. For browser extensions, this
  /// may show a connection popup.
  ///
  /// Throws [WalletConnectionException] if connection fails
  /// Throws [WalletUserRejectedException] if user rejects connection
  Future<void> connect();

  /// Disconnect from the wallet and clean up any active sessions
  ///
  /// This method closes the connection with the wallet and should clean up
  /// any resources or active sessions.
  Future<void> disconnect();

  /// Sign a single transaction using the connected wallet
  ///
  /// [transaction] - The transaction to sign
  /// Returns the transaction with signatures applied
  ///
  /// Throws [WalletNotConnectedException] if wallet is not connected
  /// Throws [WalletUserRejectedException] if user rejects signing
  /// Throws [WalletSigningException] if signing fails
  Future<Transaction> signTransaction(Transaction transaction);

  /// Sign multiple transactions using the connected wallet
  ///
  /// [transactions] - The list of transactions to sign
  /// Returns the list of transactions with signatures applied
  ///
  /// Throws [WalletNotConnectedException] if wallet is not connected
  /// Throws [WalletUserRejectedException] if user rejects signing
  /// Throws [WalletSigningException] if signing fails
  Future<List<Transaction>> signAllTransactions(List<Transaction> transactions);

  /// Sign an arbitrary message using the connected wallet
  ///
  /// [message] - The message bytes to sign
  /// Returns the signature bytes
  ///
  /// Throws [WalletNotConnectedException] if wallet is not connected
  /// Throws [WalletUserRejectedException] if user rejects signing
  /// Throws [WalletSigningException] if signing fails
  Future<Uint8List> signMessage(Uint8List message);

  /// Event stream for connection status changes
  Stream<bool> get onConnect;

  /// Event stream for disconnection events
  Stream<void> get onDisconnect;

  /// Event stream for account changes (when user switches accounts)
  Stream<PublicKey?> get onAccountChange;

  /// Event stream for wallet ready state changes
  Stream<WalletReadyState> get onReadyStateChange;

  /// Event stream for general wallet errors
  Stream<WalletException> get onError;
}

/// Wallet readiness states following Solana wallet adapter standards
enum WalletReadyState {
  /// Wallet adapter is supported but not yet ready
  notDetected,

  /// Wallet is detected and ready to be used
  installed,

  /// Wallet is loading or initializing
  loading,

  /// Wallet is not supported on this platform/environment
  unsupported,
}

/// Base wallet adapter implementation providing common functionality
///
/// This abstract class provides common implementations for wallet adapter
/// functionality, allowing concrete implementations to focus on wallet-specific
/// logic while maintaining consistency across different wallet types.
abstract class BaseWalletAdapter implements WalletAdapter {
  /// Internal connection state
  bool _connected = false;

  /// Internal ready state
  WalletReadyState _readyState = WalletReadyState.notDetected;

  /// Internal public key storage
  PublicKey? _publicKey;

  /// Internal properties storage
  final Map<String, dynamic> _properties = {};

  /// Stream controllers for events
  final StreamController<bool> _connectController =
      StreamController<bool>.broadcast();
  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();
  final StreamController<PublicKey?> _accountChangeController =
      StreamController<PublicKey?>.broadcast();
  final StreamController<WalletReadyState> _readyStateController =
      StreamController<WalletReadyState>.broadcast();
  final StreamController<WalletException> _errorController =
      StreamController<WalletException>.broadcast();

  @override
  bool get connected => _connected;

  @override
  WalletReadyState get readyState => _readyState;

  @override
  PublicKey? get publicKey => _publicKey;

  @override
  Map<String, dynamic> get properties => Map.unmodifiable(_properties);

  @override
  Stream<bool> get onConnect => _connectController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<PublicKey?> get onAccountChange => _accountChangeController.stream;

  @override
  Stream<WalletReadyState> get onReadyStateChange =>
      _readyStateController.stream;

  @override
  Stream<WalletException> get onError => _errorController.stream;

  /// Update the connection state and notify listeners
  void setConnected(bool connected) {
    if (_connected != connected) {
      _connected = connected;
      _connectController.add(connected);
    }
  }

  /// Update the ready state and notify listeners
  void setReadyState(WalletReadyState state) {
    if (_readyState != state) {
      _readyState = state;
      _readyStateController.add(state);
    }
  }

  /// Update the public key and notify listeners if it changed
  void setPublicKey(PublicKey? publicKey) {
    if (_publicKey != publicKey) {
      _publicKey = publicKey;
      _accountChangeController.add(publicKey);
    }
  }

  /// Set a property value
  void setProperty(String key, dynamic value) {
    _properties[key] = value;
  }

  /// Emit a disconnect event
  void emitDisconnect() {
    _disconnectController.add(null);
  }

  /// Emit an error event
  void emitError(WalletException error) {
    _errorController.add(error);
  }

  /// Clean up resources and close streams
  void dispose() {
    _connectController.close();
    _disconnectController.close();
    _accountChangeController.close();
    _readyStateController.close();
    _errorController.close();
  }
}

/// Exception thrown when wallet operations fail
class WalletException implements Exception {

  const WalletException(
    this.message, {
    this.code,
    this.cause,
    this.context,
  });
  /// The error message describing what went wrong
  final String message;

  /// The error code for programmatic handling
  final String? code;

  /// Optional underlying cause of the error
  final dynamic cause;

  /// Additional context data for debugging
  final Map<String, dynamic>? context;

  @override
  String toString() {
    final buffer = StringBuffer('WalletException: $message');
    if (code != null) {
      buffer.write(' (code: $code)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    if (context != null && context!.isNotEmpty) {
      buffer.write('\nContext: $context');
    }
    return buffer.toString();
  }
}

/// Exception thrown when wallet connection fails
class WalletConnectionException extends WalletException {
  const WalletConnectionException(
    super.message, {
    String? code,
    super.cause,
    super.context,
  }) : super(code: code ?? 'CONNECTION_FAILED',);
}

/// Exception thrown when user rejects a wallet operation
class WalletUserRejectedException extends WalletException {
  const WalletUserRejectedException([
    String? message,
    Map<String, dynamic>? context,
  ]) : super(
          message ?? 'User rejected the wallet operation',
          code: 'USER_REJECTED',
          context: context,
        );
}

/// Exception thrown when wallet is not connected
class WalletNotConnectedException extends WalletException {
  const WalletNotConnectedException([
    String? message,
    Map<String, dynamic>? context,
  ]) : super(
          message ?? 'Wallet is not connected',
          code: 'NOT_CONNECTED',
          context: context,
        );
}

/// Exception thrown when wallet signing operations fail
class WalletSigningException extends WalletException {
  const WalletSigningException(
    super.message, {
    super.cause,
    super.context,
  }) : super(code: 'SIGNING_FAILED');
}

/// Exception thrown when requested wallet is not available
class WalletNotAvailableException extends WalletException {
  const WalletNotAvailableException([
    String? message,
    Map<String, dynamic>? context,
  ]) : super(
          message ?? 'Requested wallet is not available',
          code: 'NOT_AVAILABLE',
          context: context,
        );
}

/// Exception thrown when wallet adapter is not supported on current platform
class WalletNotSupportedException extends WalletException {
  const WalletNotSupportedException([
    String? message,
    Map<String, dynamic>? context,
  ]) : super(
          message ?? 'Wallet is not supported on this platform',
          code: 'NOT_SUPPORTED',
          context: context,
        );
}

/// Exception thrown when wallet operation times out
class WalletTimeoutException extends WalletException {

  WalletTimeoutException(
    this.timeout, [
    String? message,
    Map<String, dynamic>? context,
  ]) : super(
          message ??
              'Wallet operation timed out after ${timeout.inMilliseconds}ms',
          code: 'TIMEOUT',
          context: context,
        );
  final Duration timeout;
}
