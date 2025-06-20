/// Wallet interface and implementations for Solana transaction signing
///
/// This module provides the wallet abstraction that enables different wallet
/// implementations to be used with the Anchor provider system. It includes
/// both a basic keypair-based wallet and extension points for external wallets.

library;

import 'dart:typed_data';
import 'dart:async';
import '../types/keypair.dart';
import '../types/public_key.dart';
import '../types/transaction.dart';

/// Abstract wallet interface for signing Solana transactions
///
/// This interface defines the contract that all wallet implementations must
/// follow to be compatible with the Anchor provider system. It supports both
/// regular transactions and message signing.
abstract class Wallet {
  /// The public key of this wallet
  PublicKey get publicKey;

  /// Sign a single transaction
  ///
  /// Takes a transaction and returns the same transaction with signatures applied.
  /// The transaction may already contain partial signatures from other signers.
  ///
  /// [transaction] - The transaction to sign
  /// Returns the signed transaction
  Future<Transaction> signTransaction(Transaction transaction);

  /// Sign multiple transactions
  ///
  /// Takes a list of transactions and returns the same transactions with
  /// signatures applied. This is more efficient than signing transactions
  /// individually when multiple transactions need to be signed.
  ///
  /// [transactions] - The list of transactions to sign
  /// Returns the list of signed transactions
  Future<List<Transaction>> signAllTransactions(List<Transaction> transactions);

  /// Sign an arbitrary message
  ///
  /// This method signs raw message bytes. It's typically used for authentication
  /// or for signing data that isn't a transaction.
  ///
  /// [message] - The message bytes to sign
  /// Returns the signature bytes
  Future<Uint8List> signMessage(Uint8List message);
}

/// A wallet implementation backed by a Keypair
///
/// This is the most basic wallet implementation that directly uses a Keypair
/// for signing. It's suitable for server-side applications or development
/// environments where the private key can be safely stored in memory.
class KeypairWallet implements Wallet {
  final Keypair _keypair;

  /// Create a wallet from a keypair
  ///
  /// [keypair] - The keypair to use for signing
  KeypairWallet(this._keypair);

  /// Create a wallet by generating a new random keypair
  static Future<KeypairWallet> generate() async {
    final keypair = await Keypair.generate();
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a secret key
  ///
  /// [secretKey] - The 64-byte secret key
  factory KeypairWallet.fromSecretKey(Uint8List secretKey) {
    final keypair = Keypair.fromSecretKey(secretKey);
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a base58-encoded secret key
  ///
  /// [secretKeyBase58] - The base58-encoded secret key
  factory KeypairWallet.fromBase58(String secretKeyBase58) {
    final keypair = Keypair.fromBase58(secretKeyBase58);
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a JSON array (Solana CLI format)
  ///
  /// [secretKeyArray] - Array of 64 integers representing the secret key
  factory KeypairWallet.fromJson(List<int> secretKeyArray) {
    final keypair = Keypair.fromJson(secretKeyArray);
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a seed for deterministic key generation
  ///
  /// [seed] - The 32-byte seed
  static Future<KeypairWallet> fromSeed(Uint8List seed) async {
    final keypair = await Keypair.fromSeed(seed);
    return KeypairWallet(keypair);
  }

  @override
  PublicKey get publicKey => _keypair.publicKey;

  /// Get the underlying keypair (for compatibility with existing code)
  Keypair get keypair => _keypair;

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    // Create a transaction serializer/signer helper
    return await _signTransactionInternal(transaction);
  }

  @override
  Future<List<Transaction>> signAllTransactions(
    List<Transaction> transactions,
  ) async {
    final signedTransactions = <Transaction>[];

    for (final transaction in transactions) {
      final signedTransaction = await signTransaction(transaction);
      signedTransactions.add(signedTransaction);
    }

    return signedTransactions;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    return await _keypair.sign(message);
  }

  /// Internal method to sign a transaction
  ///
  /// This method handles the transaction signing logic. Since the actual Solana
  /// message format will be created later in the RPC layer, we just add our
  /// public key as a signer and the signature will be computed later.
  Future<Transaction> _signTransactionInternal(Transaction transaction) async {
    print(
        'DEBUG: Wallet signing transaction with public key: ${publicKey.toBase58()}');

    // Ensure feePayer is set if not already set
    if (transaction.feePayer == null) {
      final newTx = Transaction(
        instructions: transaction.instructions,
        feePayer: publicKey,
        recentBlockhash: transaction.recentBlockhash,
      );
      // Copy existing signatures
      for (final entry in transaction.signatures.entries) {
        newTx.addSignature(PublicKey.fromBase58(entry.key), entry.value);
      }
      transaction = newTx;
    }

    // Compile the transaction message bytes for signing
    final messageBytes = transaction.compileMessage();
    // Sign the message bytes with our keypair
    final signatureBytes = await _keypair.sign(messageBytes);

    // Attach the signature to the transaction
    transaction.addSignature(publicKey, signatureBytes);

    return transaction;
  }

  /// Sign a Solana transaction message using the proper wire format
  ///
  /// This method signs the actual transaction message bytes that will be sent
  /// to the Solana network.
  Future<Uint8List> signTransactionMessage(Uint8List messageBytes) async {
    print(
        'DEBUG: Wallet signing transaction message (${messageBytes.length} bytes)');
    final signatureBytes = await _keypair.sign(messageBytes);
    print('DEBUG: Generated signature (${signatureBytes.length} bytes)');
    return signatureBytes;
  }

  @override
  String toString() {
    return 'KeypairWallet(publicKey: $publicKey)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeypairWallet && other.publicKey == publicKey;
  }

  @override
  int get hashCode => publicKey.hashCode;
}

/// Wallet adapter interface for external wallet integrations
///
/// This interface defines the contract for wallet adapters that can be used
/// to integrate external wallets (like browser extensions, mobile apps, etc.)
/// with the Anchor provider system.
abstract class WalletAdapter {
  /// The name of this wallet adapter
  String get name;

  /// The icon URL for this wallet (optional)
  String? get icon;

  /// The URL for this wallet's website (optional)
  String? get url;

  /// Whether this wallet adapter is ready to be used
  bool get readyState;

  /// The public key of the connected wallet, or null if not connected
  PublicKey? get publicKey;

  /// Whether the wallet is currently connected
  bool get connected;

  /// Connect to the wallet
  Future<void> connect();

  /// Disconnect from the wallet
  Future<void> disconnect();

  /// Sign a transaction using the external wallet
  Future<Transaction> signTransaction(Transaction transaction);

  /// Sign multiple transactions using the external wallet
  Future<List<Transaction>> signAllTransactions(List<Transaction> transactions);

  /// Sign an arbitrary message using the external wallet
  Future<Uint8List> signMessage(Uint8List message);

  /// Event stream for connection status changes
  Stream<bool> get onConnect;

  /// Event stream for disconnection events
  Stream<void> get onDisconnect;

  /// Event stream for account changes (when user switches accounts)
  Stream<PublicKey?> get onAccountChange;
}

/// Adapter wallet implementation that wraps external wallet adapters
///
/// This class allows external wallet adapters to be used with the standard
/// Wallet interface, providing a bridge between the two systems.
class AdapterWallet implements Wallet {
  final WalletAdapter _adapter;

  /// Create a wallet from a wallet adapter
  AdapterWallet(this._adapter);

  /// Get the underlying adapter
  WalletAdapter get adapter => _adapter;

  @override
  PublicKey get publicKey {
    final pubkey = _adapter.publicKey;
    if (pubkey == null) {
      throw const WalletNotConnectedException(
          'Wallet adapter is not connected or has no public key');
    }
    return pubkey;
  }

  /// Whether the wallet is connected
  bool get connected => _adapter.connected;

  /// Connect to the wallet
  Future<void> connect() => _adapter.connect();

  /// Disconnect from the wallet
  Future<void> disconnect() => _adapter.disconnect();

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (!_adapter.connected) {
      throw const WalletNotConnectedException();
    }

    try {
      return await _adapter.signTransaction(transaction);
    } catch (e) {
      if (e.toString().contains('rejected') ||
          e.toString().contains('denied')) {
        throw const WalletUserRejectedException();
      }
      throw WalletException('Failed to sign transaction', e);
    }
  }

  @override
  Future<List<Transaction>> signAllTransactions(
    List<Transaction> transactions,
  ) async {
    if (!_adapter.connected) {
      throw const WalletNotConnectedException();
    }

    try {
      return await _adapter.signAllTransactions(transactions);
    } catch (e) {
      if (e.toString().contains('rejected') ||
          e.toString().contains('denied')) {
        throw const WalletUserRejectedException();
      }
      throw WalletException('Failed to sign transactions', e);
    }
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (!_adapter.connected) {
      throw const WalletNotConnectedException();
    }

    try {
      return await _adapter.signMessage(message);
    } catch (e) {
      if (e.toString().contains('rejected') ||
          e.toString().contains('denied')) {
        throw const WalletUserRejectedException();
      }
      throw WalletException('Failed to sign message', e);
    }
  }

  /// Event stream for connection status changes
  Stream<bool> get onConnect => _adapter.onConnect;

  /// Event stream for disconnection events
  Stream<void> get onDisconnect => _adapter.onDisconnect;

  /// Event stream for account changes
  Stream<PublicKey?> get onAccountChange => _adapter.onAccountChange;

  @override
  String toString() {
    return 'AdapterWallet(${_adapter.name}, connected: ${_adapter.connected})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdapterWallet && other._adapter == _adapter;
  }

  @override
  int get hashCode => _adapter.hashCode;
}

/// Exception thrown when wallet operations fail
class WalletException implements Exception {
  /// The error message describing what went wrong
  final String message;

  /// Optional underlying cause of the error
  final dynamic cause;

  const WalletException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'WalletException: $message\nCaused by: $cause';
    }
    return 'WalletException: $message';
  }
}

/// Exception thrown when user rejects a signing request
class WalletUserRejectedException extends WalletException {
  const WalletUserRejectedException([String? message])
      : super(message ?? 'User rejected the signing request');
}

/// Exception thrown when wallet is not connected
class WalletNotConnectedException extends WalletException {
  const WalletNotConnectedException([String? message])
      : super(message ?? 'Wallet is not connected');
}

/// Exception thrown when requested wallet is not available
class WalletNotAvailableException extends WalletException {
  const WalletNotAvailableException([String? message])
      : super(message ?? 'Requested wallet is not available');
}

/// Mock wallet adapter for testing and development
///
/// This is a simple implementation of WalletAdapter that can be used for
/// testing and development purposes. It simulates the behavior of an
/// external wallet without requiring actual wallet software.
class MockWalletAdapter implements WalletAdapter {
  final String _name;
  final String? _icon;
  final String? _url;
  final Keypair _keypair;

  bool _connected = false;

  MockWalletAdapter(
    this._name,
    this._keypair, {
    String? icon,
    String? url,
  })  : _icon = icon,
        _url = url;

  @override
  String get name => _name;

  @override
  String? get icon => _icon;

  @override
  String? get url => _url;

  @override
  bool get readyState => true;

  @override
  PublicKey? get publicKey => _connected ? _keypair.publicKey : null;

  @override
  bool get connected => _connected;

  @override
  Future<void> connect() async {
    if (_connected) return;

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 100));
    _connected = true;
    _connectController.add(true);
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;

    _connected = false;
    _disconnectController.add(null);
    _connectController.add(false);
  }

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (!_connected) {
      throw const WalletNotConnectedException();
    }

    // Simulate signing delay
    await Future.delayed(const Duration(milliseconds: 50));

    // For mock implementation, just add a mock signature
    final mockMessage = Uint8List.fromList([1, 2, 3, 4]);
    final signatureBytes = await _keypair.sign(mockMessage);

    final signedTx = Transaction(
      instructions: transaction.instructions,
      feePayer: transaction.feePayer ?? _keypair.publicKey,
      recentBlockhash: transaction.recentBlockhash,
    );
    signedTx.addSignature(_keypair.publicKey, signatureBytes);

    return signedTx;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
    List<Transaction> transactions,
  ) async {
    final signed = <Transaction>[];
    for (final tx in transactions) {
      signed.add(await signTransaction(tx));
    }
    return signed;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (!_connected) {
      throw const WalletNotConnectedException();
    }

    return await _keypair.sign(message);
  }

  // Event streams
  final _connectController = StreamController<bool>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _accountChangeController = StreamController<PublicKey?>.broadcast();

  @override
  Stream<bool> get onConnect => _connectController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<PublicKey?> get onAccountChange => _accountChangeController.stream;

  /// Simulate account change (for testing)
  void simulateAccountChange(Keypair newKeypair) {
    // This would normally happen when user switches accounts in the wallet
    _accountChangeController.add(newKeypair.publicKey);
  }

  /// Clean up resources
  void dispose() {
    _connectController.close();
    _disconnectController.close();
    _accountChangeController.close();
  }
}
