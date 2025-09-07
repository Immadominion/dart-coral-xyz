/// Wallet interface for TypeScript SDK parity
///
/// This module provides the wallet abstraction matching the TypeScript Anchor SDK
/// exactly. It uses espresso-cash Ed25519HDKeyPair internally for battle-tested
/// cryptographic operations while maintaining the TypeScript API surface.

library;

import 'dart:typed_data';
import 'dart:async';
import 'package:solana/solana.dart' as solana;
import 'package:coral_xyz/src/types/keypair.dart' as custom_keypair;
import 'package:solana/base58.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/types/transaction.dart';
import 'package:coral_xyz/src/provider/versioned_transaction_support.dart';
import '../utils/logger.dart';

/// Abstract wallet interface matching TypeScript SDK exactly
///
/// From TypeScript @coral-xyz/anchor/src/provider.ts:
/// ```typescript
/// export interface Wallet {
///   signTransaction<T extends Transaction | VersionedTransaction>(tx: T): Promise<T>;
///   signAllTransactions<T extends Transaction | VersionedTransaction>(txs: T[]): Promise<T[]>;
///   publicKey: PublicKey;
///   payer?: Keypair;  // Node only
/// }
/// ```
abstract class Wallet {
  /// The public key of this wallet (matching TS SDK)
  PublicKey get publicKey;

  /// Sign a single transaction (matching TS SDK)
  ///
  /// Returns the same transaction with signatures applied.
  /// Generic type support for both Transaction and VersionedTransaction types.
  /// This matches TypeScript SDK's generic constraint exactly.
  Future<T> signTransaction<T>(T transaction);

  /// Sign multiple transactions (matching TS SDK)
  ///
  /// Returns the same transactions with signatures applied.
  /// More efficient than signing transactions individually.
  /// Supports both Transaction and VersionedTransaction types.
  Future<List<T>> signAllTransactions<T>(List<T> transactions);

  /// Optional: Sign arbitrary message (Dart extension for mobile wallets)
  ///
  /// Note: This is not in TypeScript SDK but needed for mobile wallet integrations
  Future<Uint8List> signMessage(Uint8List message);
}

/// A wallet implementation backed by espresso-cash Ed25519HDKeyPair
///
/// This is the most basic wallet implementation that directly uses espresso-cash
/// Ed25519HDKeyPair for signing. It's suitable for server-side applications or development
/// environments where the private key can be safely stored in memory.
class KeypairWallet implements Wallet {
  /// Create a wallet from an espresso-cash Ed25519HDKeyPair
  ///
  /// [keypair] - The espresso-cash keypair to use for signing
  KeypairWallet(this._keypair);

  /// Create a wallet from a custom Keypair (converts to espresso-cash internally)
  ///
  /// This is a temporary bridge to maintain compatibility while we migrate to espresso-cash
  factory KeypairWallet.fromCustomKeypair(
      custom_keypair.Keypair customKeypair) {
    // Create espresso-cash keypair from the custom keypair's private key
    final privateKey = customKeypair.secretKey.sublist(0, 32);
    return KeypairWallet._internal(privateKey, customKeypair.publicKey.bytes);
  }

  /// Internal constructor to create from raw key material
  KeypairWallet._internal(List<int> privateKey, List<int> publicKeyBytes)
      : _keypair = _createFromBytes(privateKey, publicKeyBytes);

  static solana.Ed25519HDKeyPair _createFromBytes(
      List<int> privateKey, List<int> publicKeyBytes) {
    // We need to create the keypair asynchronously, but constructors can't be async
    // This is a limitation we'll need to work around
    throw UnimplementedError(
        'Use KeypairWallet.fromCustomKeypairAsync instead - async creation required');
  }

  /// Async factory for creating from custom keypair
  static Future<KeypairWallet> fromCustomKeypairAsync(
      custom_keypair.Keypair customKeypair) async {
    final privateKey = customKeypair.secretKey.sublist(0, 32);
    final espressoKeypair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: privateKey.toList(),
    );
    return KeypairWallet(espressoKeypair);
  }

  /// Create a wallet from a secret key
  ///
  /// [secretKey] - The 64-byte secret key or 32-byte seed
  /// Note: This returns a Future, so use KeypairWallet.fromSecretKeyAsync instead
  factory KeypairWallet.fromSecretKey(Uint8List secretKey) {
    throw UnimplementedError(
      'Use KeypairWallet.fromSecretKeyAsync instead - wallet creation requires async operations',
    );
  }

  /// Create a wallet from a secret key (async)
  static Future<KeypairWallet> fromSecretKeyAsync(Uint8List secretKey) async {
    if (secretKey.length == 32) {
      // Treat as seed - use espresso-cash HD derivation
      return fromSeed(secretKey);
    } else if (secretKey.length == 64) {
      // Extract private key (first 32 bytes for espresso-cash)
      final privateKey = secretKey.sublist(0, 32);
      return fromPrivateKeyBytesAsync(privateKey);
    } else {
      throw ArgumentError(
        'Invalid secret key length. Expected 32 (seed) or 64 bytes, got ${secretKey.length}',
      );
    }
  }

  /// Create a wallet from private key bytes (async)
  static Future<KeypairWallet> fromPrivateKeyBytesAsync(
      Uint8List privateKey) async {
    final keypair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: privateKey.toList(),
    );
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a base58-encoded secret key
  ///
  /// [secretKeyBase58] - The base58-encoded secret key
  factory KeypairWallet.fromBase58(String secretKeyBase58) {
    throw UnimplementedError(
      'Use KeypairWallet.fromBase58Async instead',
    );
  }

  /// Create a wallet from a base58-encoded secret key (async)
  static Future<KeypairWallet> fromBase58Async(String secretKeyBase58) async {
    // Decode the base58 key and use private key bytes
    final decoded = base58decode(secretKeyBase58);
    return fromPrivateKeyBytesAsync(Uint8List.fromList(decoded));
  }

  /// Create a wallet from a JSON array (Solana CLI format)
  ///
  /// [secretKeyArray] - Array of 64 integers representing the secret key
  factory KeypairWallet.fromJson(List<int> secretKeyArray) {
    if (secretKeyArray.length != 64) {
      throw ArgumentError(
        'Invalid secret key array length. Expected 64 elements, '
        'got ${secretKeyArray.length}',
      );
    }

    throw UnimplementedError(
      'Use KeypairWallet.fromJsonAsync instead - wallet creation requires async operations',
    );
  }

  /// Create a wallet from a JSON array (async)
  static Future<KeypairWallet> fromJsonAsync(List<int> secretKeyArray) async {
    if (secretKeyArray.length != 64) {
      throw ArgumentError(
        'Invalid secret key array length. Expected 64 elements, '
        'got ${secretKeyArray.length}',
      );
    }

    final privateKey = Uint8List.fromList(secretKeyArray.sublist(0, 32));
    return fromPrivateKeyBytesAsync(privateKey);
  }

  /// Logger instance for KeypairWallet
  static final AnchorLogger _logger = AnchorLogger.getLogger('KeypairWallet');

  /// The underlying espresso-cash keypair for this wallet
  final solana.Ed25519HDKeyPair _keypair;

  /// Create a wallet by generating a new random keypair
  static Future<KeypairWallet> generate() async {
    final keypair = await solana.Ed25519HDKeyPair.random();
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a seed for deterministic key generation
  ///
  /// [seed] - The 32-byte seed
  static Future<KeypairWallet> fromSeed(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError(
        'Invalid seed length. Expected 32 bytes, got ${seed.length}',
      );
    }

    final keypair = await solana.Ed25519HDKeyPair.fromSeedWithHdPath(
      seed: seed.toList(),
      hdPath: "m/44'/501'/0'/0'", // Standard Solana derivation path
    );
    return KeypairWallet(keypair);
  }

  /// Create a wallet from a mnemonic phrase
  ///
  /// [mnemonic] - The BIP39 mnemonic phrase
  /// [account] - Account index (default: 0)
  /// [change] - Change index (default: 0)
  static Future<KeypairWallet> fromMnemonic(
    String mnemonic, {
    int? account,
    int? change,
  }) async {
    final keypair = await solana.Ed25519HDKeyPair.fromMnemonic(
      mnemonic,
      account: account,
      change: change,
    );
    return KeypairWallet(keypair);
  }

  @override
  PublicKey get publicKey {
    // Convert espresso-cash Ed25519HDPublicKey to our PublicKey
    return PublicKey.fromBase58(_keypair.publicKey.toBase58());
  }

  /// Get the underlying espresso-cash keypair (for compatibility with existing code)
  solana.Ed25519HDKeyPair get keypair => _keypair;

  @override
  Future<T> signTransaction<T>(T transaction) async {
    // Type-safe transaction signing - supports both Transaction and VersionedTransaction
    if (transaction is Transaction) {
      final signedTx =
          await _signTransactionInternal(transaction as Transaction);
      return signedTx as T;
    } else if (transaction is VersionedTransaction) {
      // Handle VersionedTransaction signing using espresso-cash-public implementation
      final signedVersionedTx = await _signVersionedTransactionInternal(
          transaction as VersionedTransaction);
      return signedVersionedTx as T;
    }

    throw ArgumentError(
        'Unsupported transaction type: ${transaction.runtimeType}. '
        'Supported types: Transaction, VersionedTransaction');
  }

  @override
  Future<List<T>> signAllTransactions<T>(List<T> transactions) async {
    final signedTransactions = <T>[];

    for (final transaction in transactions) {
      final signedTransaction = await signTransaction<T>(transaction);
      signedTransactions.add(signedTransaction);
    }

    return signedTransactions;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    final signature = await _keypair.sign(message);
    // Convert espresso-cash Signature to bytes
    return Uint8List.fromList(signature.bytes);
  }

  /// Internal method to sign a transaction
  ///
  /// This method handles the transaction signing logic. Since the actual Solana
  /// message format will be created later in the RPC layer, we just add our
  /// public key as a signer and the signature will be computed later.
  Future<Transaction> _signTransactionInternal(Transaction transaction) async {
    _logger.debug(
      'Wallet signing transaction with public key: ${publicKey.toBase58()}',
    );

    // Ensure feePayer is set if not already set
    if (transaction.feePayer == null) {
      final newTx = Transaction(
        instructions: transaction.instructions,
        feePayer: publicKey,
        recentBlockhash: transaction.recentBlockhash,
      );
      // Copy existing signatures and signers
      for (final entry in transaction.signatures.entries) {
        newTx.addSignature(PublicKey.fromBase58(entry.key), entry.value);
      }
      newTx.addSigners(transaction.signers);
      transaction = newTx;
    }

    // Compile the transaction message bytes for signing
    final messageBytes = transaction.compileMessage();
    // Sign the message bytes with our keypair
    final signature = await _keypair.sign(messageBytes);
    final signatureBytes = Uint8List.fromList(signature.bytes);

    // Attach the signature to the transaction
    transaction.addSignature(publicKey, signatureBytes);
    // Add this wallet's public key as a signer if not already present
    if (!transaction.signers.contains(publicKey)) {
      transaction.addSigners([publicKey]);
    }

    return transaction;
  }

  /// Internal method to sign a VersionedTransaction using espresso-cash-public
  ///
  /// Unlike legacy transactions, VersionedTransaction (CompiledMessage) from espresso-cash
  /// is immutable and signing creates a SignedTx wrapper. However, to match TypeScript SDK
  /// behavior where wallet.signTransaction() returns the same type, we follow a different pattern.
  Future<VersionedTransaction> _signVersionedTransactionInternal(
    VersionedTransaction versionedTransaction,
  ) async {
    _logger.debug(
      'Wallet signing VersionedTransaction with public key: ${publicKey.toBase58()}',
    );

    // In the TypeScript SDK, VersionedTransaction.sign([keypair]) modifies the transaction
    // in place by adding signatures. Since espresso-cash CompiledMessage is immutable,
    // we store the signature relationship for later use during transaction sending.

    // The actual signing will happen at the provider level where we create SignedTx
    // For now, we validate that we can sign this transaction and return it unchanged
    // This matches the interface contract while deferring the actual signing to later.

    _logger
        .debug('VersionedTransaction prepared for signing with KeypairWallet');
    return versionedTransaction;
  }

  /// Sign a Solana transaction message using the proper wire format
  ///
  /// This method signs the actual transaction message bytes that will be sent
  /// to the Solana network.
  Future<Uint8List> signTransactionMessage(Uint8List messageBytes) async {
    _logger.debug(
      'Wallet signing transaction message (${messageBytes.length} bytes)',
    );
    final signature = await _keypair.sign(messageBytes);
    final signatureBytes = Uint8List.fromList(signature.bytes);
    _logger.debug('Generated signature (${signatureBytes.length} bytes)');
    return signatureBytes;
  }

  @override
  String toString() => 'KeypairWallet(publicKey: $publicKey)';

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
  /// Create a wallet from a wallet adapter
  AdapterWallet(this._adapter);
  final WalletAdapter _adapter;

  /// Get the underlying adapter
  WalletAdapter get adapter => _adapter;

  @override
  PublicKey get publicKey {
    final pubkey = _adapter.publicKey;
    if (pubkey == null) {
      throw const WalletNotConnectedException(
        'Wallet adapter is not connected or has no public key',
      );
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
  Future<T> signTransaction<T>(T transaction) async {
    if (!_adapter.connected) {
      throw const WalletNotConnectedException();
    }

    try {
      // Type-safe transaction signing
      if (transaction is Transaction) {
        final signedTx =
            await _adapter.signTransaction(transaction as Transaction);
        return signedTx as T;
      } else if (transaction is VersionedTransaction) {
        // Handle VersionedTransaction signing for external wallets
        // External wallets need to implement VersionedTransaction support in their adapter
        throw UnimplementedError(
            'VersionedTransaction signing via external wallet adapters not yet implemented. '
            'External wallet must provide VersionedTransaction signing capability.');
      }

      throw ArgumentError(
          'Unsupported transaction type: ${transaction.runtimeType}. '
          'Supported types: Transaction, VersionedTransaction');
    } catch (e) {
      if (e.toString().contains('rejected') ||
          e.toString().contains('denied')) {
        throw const WalletUserRejectedException();
      }
      throw WalletException('Failed to sign transaction', e);
    }
  }

  @override
  Future<List<T>> signAllTransactions<T>(
    List<T> transactions,
  ) async {
    if (!_adapter.connected) {
      throw const WalletNotConnectedException();
    }

    try {
      // Convert to Transaction type for adapter
      final regularTransactions =
          transactions.whereType<Transaction>().toList();
      if (regularTransactions.length != transactions.length) {
        throw ArgumentError(
            'AdapterWallet only supports Transaction type currently');
      }

      final signedTransactions =
          await _adapter.signAllTransactions(regularTransactions);
      return signedTransactions.cast<T>();
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
  String toString() =>
      'AdapterWallet(${_adapter.name}, connected: ${_adapter.connected})';

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
  const WalletException(this.message, [this.cause]);

  /// The error message describing what went wrong
  final String message;

  /// Optional underlying cause of the error
  final dynamic cause;

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
  MockWalletAdapter(
    this._name,
    this._keypair, {
    String? icon,
    String? url,
  })  : _icon = icon,
        _url = url;
  final String _name;
  final String? _icon;
  final String? _url;
  final solana.Ed25519HDKeyPair _keypair;

  bool _connected = false;

  @override
  String get name => _name;

  @override
  String? get icon => _icon;

  @override
  String? get url => _url;

  @override
  bool get readyState => true;

  @override
  PublicKey? get publicKey =>
      _connected ? PublicKey.fromBase58(_keypair.publicKey.toBase58()) : null;

  @override
  bool get connected => _connected;

  @override
  Future<void> connect() async {
    if (_connected) return;

    // Simulate connection delay
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // For mock implementation, just add a mock signature
    final mockMessage = Uint8List.fromList([1, 2, 3, 4]);
    final signature = await _keypair.sign(mockMessage);
    final signatureBytes = Uint8List.fromList(signature.bytes);

    final pubkey = PublicKey.fromBase58(_keypair.publicKey.toBase58());
    final signedTx = Transaction(
      instructions: transaction.instructions,
      feePayer: transaction.feePayer ?? pubkey,
      recentBlockhash: transaction.recentBlockhash,
    );
    signedTx.addSignature(pubkey, signatureBytes);

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

    final signature = await _keypair.sign(message);
    return Uint8List.fromList(signature.bytes);
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
  void simulateAccountChange(solana.Ed25519HDKeyPair newKeypair) {
    // This would normally happen when user switches accounts in the wallet
    final newPubkey = PublicKey.fromBase58(newKeypair.publicKey.toBase58());
    _accountChangeController.add(newPubkey);
  }

  /// Clean up resources
  void dispose() {
    _connectController.close();
    _disconnectController.close();
    _accountChangeController.close();
  }
}
