/// Flutter-specific widgets and integrations for the Coral XYZ Anchor client
///
/// This module provides Flutter widgets and utilities that make it easy to
/// integrate Solana blockchain functionality into Flutter applications with
/// proper state management, error handling, and UI patterns.

library;

import 'dart:async';
import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/keypair.dart';
import '../types/transaction.dart';
import '../provider/wallet.dart';
import '../provider/anchor_provider.dart';
import '../provider/connection.dart';
import '../program/program.dart';
import '../idl/idl.dart';
import 'platform_optimization.dart';

/// Abstract widget interface for Flutter integration
/// This would extend StatefulWidget in a real Flutter environment
abstract class SolanaWidget {
  /// Initialize the widget
  Future<void> initialize();

  /// Dispose resources
  void dispose();
}

/// Wallet connection widget for Flutter applications
class SolanaWalletWidget implements SolanaWidget {
  /// Connection state stream
  final StreamController<WalletConnectionState> _connectionStateController =
      StreamController<WalletConnectionState>.broadcast();

  /// Current wallet state
  WalletConnectionState _currentState = WalletConnectionState.disconnected;

  /// Current wallet instance
  Wallet? _wallet;

  /// Current provider instance
  AnchorProvider? _provider;

  /// Connection instance
  Connection? _connection;

  /// Configuration for the widget
  final SolanaWalletConfig config;

  SolanaWalletWidget({
    SolanaWalletConfig? config,
  }) : config = config ?? SolanaWalletConfig.defaultConfig();

  /// Get current connection state
  WalletConnectionState get connectionState => _currentState;

  /// Stream of connection state changes
  Stream<WalletConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Get current wallet
  Wallet? get wallet => _wallet;

  /// Get current provider
  AnchorProvider? get provider => _provider;

  /// Get current connection
  Connection? get connection => _connection;

  /// Get current public key
  PublicKey? get publicKey => _wallet?.publicKey;

  @override
  Future<void> initialize() async {
    _updateState(WalletConnectionState.initializing);

    try {
      // Initialize connection
      _connection = Connection(config.rpcUrl);

      // Platform-specific initialization
      if (PlatformOptimization.isMobile) {
        await _initializeMobileWallet();
      } else if (PlatformOptimization.isWeb) {
        await _initializeWebWallet();
      } else {
        await _initializeDesktopWallet();
      }

      _updateState(WalletConnectionState.connected);
    } catch (e) {
      _updateState(WalletConnectionState.error);
      rethrow;
    }
  }

  /// Initialize mobile wallet (simplified - would use actual MWA in production)
  Future<void> _initializeMobileWallet() async {
    // For demo purposes, create a keypair wallet
    // In production, this would integrate with Mobile Wallet Adapter
    final keypair = await Keypair.generate();
    _wallet = KeypairWallet(keypair);
    _provider = AnchorProvider(_connection!, _wallet!);
  }

  /// Initialize web wallet (placeholder)
  Future<void> _initializeWebWallet() async {
    // This would integrate with browser wallet adapters like Phantom, Sollet, etc.
    // For demo, create a keypair wallet
    final keypair = await Keypair.generate();
    _wallet = KeypairWallet(keypair);
    _provider = AnchorProvider(_connection!, _wallet!);
  }

  /// Initialize desktop wallet (simplified)
  Future<void> _initializeDesktopWallet() async {
    // This would load from local storage or prompt for wallet file
    // For demo, create a keypair wallet
    final keypair = await Keypair.generate();
    _wallet = KeypairWallet(keypair);
    _provider = AnchorProvider(_connection!, _wallet!);
  }

  /// Connect to wallet
  Future<void> connect() async {
    if (_currentState == WalletConnectionState.connected) return;

    _updateState(WalletConnectionState.connecting);

    try {
      if (_wallet == null) {
        await initialize();
      }

      // If wallet has connect method, call it
      if (_wallet is AdapterWallet) {
        await (_wallet as AdapterWallet).connect();
      }

      _updateState(WalletConnectionState.connected);
    } catch (e) {
      _updateState(WalletConnectionState.error);
      rethrow;
    }
  }

  /// Disconnect from wallet
  Future<void> disconnect() async {
    if (_currentState == WalletConnectionState.disconnected) return;

    _updateState(WalletConnectionState.disconnecting);

    try {
      // If wallet has disconnect method, call it
      if (_wallet is AdapterWallet) {
        await (_wallet as AdapterWallet).disconnect();
      }

      _wallet = null;
      _provider = null;

      _updateState(WalletConnectionState.disconnected);
    } catch (e) {
      _updateState(WalletConnectionState.error);
      rethrow;
    }
  }

  /// Sign and send transaction
  Future<String> sendTransaction(Transaction transaction) async {
    if (_provider == null) {
      throw Exception('Provider not initialized');
    }

    return await _provider!.sendAndConfirm(transaction);
  }

  /// Get account balance
  Future<int> getBalance([PublicKey? address]) async {
    if (_connection == null) {
      throw Exception('Connection not initialized');
    }

    final targetAddress = address ?? publicKey;
    if (targetAddress == null) {
      throw Exception('No address provided and wallet not connected');
    }

    return await _connection!.getBalance(targetAddress);
  }

  /// Update connection state and notify listeners
  void _updateState(WalletConnectionState newState) {
    _currentState = newState;
    _connectionStateController.add(newState);
  }

  @override
  void dispose() {
    _connectionStateController.close();
    _connection?.close();
  }
}

/// Configuration for Solana wallet widget
class SolanaWalletConfig {
  /// RPC URL for connection
  final String rpcUrl;

  /// Wallet adapter options
  final Map<String, dynamic> walletOptions;

  /// Auto-connect on initialization
  final bool autoConnect;

  /// Retry configuration
  final int maxRetries;
  final Duration retryDelay;

  /// Platform-specific optimizations
  final bool enablePlatformOptimizations;

  const SolanaWalletConfig({
    required this.rpcUrl,
    this.walletOptions = const {},
    this.autoConnect = false,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enablePlatformOptimizations = true,
  });

  /// Default configuration for development
  factory SolanaWalletConfig.defaultConfig() {
    return const SolanaWalletConfig(
      rpcUrl: 'https://api.devnet.solana.com',
      autoConnect: false,
      maxRetries: 3,
      retryDelay: Duration(seconds: 1),
      enablePlatformOptimizations: true,
    );
  }

  /// Configuration for mainnet
  factory SolanaWalletConfig.mainnet() {
    return const SolanaWalletConfig(
      rpcUrl: 'https://api.mainnet-beta.solana.com',
      autoConnect: false,
      maxRetries: 5,
      retryDelay: Duration(seconds: 2),
      enablePlatformOptimizations: true,
    );
  }

  /// Configuration for local development
  factory SolanaWalletConfig.local() {
    return const SolanaWalletConfig(
      rpcUrl: 'http://127.0.0.1:8899',
      autoConnect: true,
      maxRetries: 1,
      retryDelay: Duration(milliseconds: 500),
      enablePlatformOptimizations: false,
    );
  }
}

/// Wallet connection states
enum WalletConnectionState {
  /// Not connected to any wallet
  disconnected,

  /// Currently establishing connection
  connecting,

  /// Successfully connected
  connected,

  /// Currently disconnecting
  disconnecting,

  /// Initializing wallet system
  initializing,

  /// Error state
  error,
}

/// Program interaction widget for Flutter applications
class SolanaProgramWidget implements SolanaWidget {
  /// The program instance
  Program? _program;

  /// The provider to use
  final AnchorProvider provider;

  /// The program IDL
  final Idl idl;

  /// Program ID (derived from IDL or provided)
  final PublicKey? programId;

  /// Event subscriptions
  final Map<String, StreamSubscription<dynamic>> _eventSubscriptions = {};

  /// Program state stream
  final StreamController<ProgramState> _stateController =
      StreamController<ProgramState>.broadcast();

  /// Current program state
  ProgramState _currentState = ProgramState.uninitialized;

  SolanaProgramWidget({
    required this.provider,
    required this.idl,
    this.programId,
  });

  /// Get current program
  Program? get program => _program;

  /// Get current state
  ProgramState get state => _currentState;

  /// Stream of program state changes
  Stream<ProgramState> get stateStream => _stateController.stream;

  @override
  Future<void> initialize() async {
    _updateState(ProgramState.initializing);

    try {
      // Create program instance
      _program = Program(idl, provider: provider);

      _updateState(ProgramState.ready);
    } catch (e) {
      _updateState(ProgramState.error);
      rethrow;
    }
  }

  /// Call a program method
  Future<String> callMethod(
    String methodName,
    List<dynamic> args, {
    Map<String, PublicKey>? accounts,
    List<Keypair>? signers,
  }) async {
    if (_program == null) {
      throw Exception('Program not initialized');
    }

    final methodBuilder = _program!.methods[methodName];
    if (methodBuilder == null) {
      throw Exception('Method $methodName not found');
    }

    // Build method call
    var builder = methodBuilder.call(args);

    if (accounts != null) {
      builder = builder.accounts(accounts);
    }

    if (signers != null) {
      // Convert Keypair to expected type or handle differently
      // For now, we'll skip signers to avoid type mismatch
      // builder = builder.signers(signers);
    }

    // Execute transaction
    return await builder.rpc();
  }

  /// Fetch account data
  Future<Map<String, dynamic>?> fetchAccount(
    String accountType,
    PublicKey address,
  ) async {
    if (_program == null) {
      throw Exception('Program not initialized');
    }

    final accountClient = _program!.account[accountType];
    if (accountClient == null) {
      throw Exception('Account type $accountType not found');
    }

    return await accountClient.fetch(address) as Map<String, dynamic>?;
  }

  /// Subscribe to program events
  void subscribeToEvent(
    String eventName,
    void Function(dynamic event, int slot) callback,
  ) {
    if (_program == null) {
      throw Exception('Program not initialized');
    }

    // Cancel existing subscription
    _eventSubscriptions[eventName]?.cancel();

    // Create new subscription (simplified - actual implementation would use program events)
    final subscription = Stream.periodic(
      const Duration(seconds: 5),
      (i) => {
        'mockEvent': 'data',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      },
    ).listen((event) {
      callback(event, 0); // Mock slot
    });

    _eventSubscriptions[eventName] = subscription;
  }

  /// Unsubscribe from event
  void unsubscribeFromEvent(String eventName) {
    _eventSubscriptions[eventName]?.cancel();
    _eventSubscriptions.remove(eventName);
  }

  /// Update program state
  void _updateState(ProgramState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  void dispose() {
    // Cancel all event subscriptions
    for (final subscription in _eventSubscriptions.values) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();

    _stateController.close();
  }
}

/// Program states
enum ProgramState {
  /// Program not initialized
  uninitialized,

  /// Currently initializing
  initializing,

  /// Ready for interaction
  ready,

  /// Error state
  error,
}

/// Transaction builder widget for Flutter applications
class SolanaTransactionWidget implements SolanaWidget {
  /// Current transaction being built
  Transaction? _transaction;

  /// Transaction state
  TransactionState _state = TransactionState.empty;

  /// Transaction state stream
  final StreamController<TransactionState> _stateController =
      StreamController<TransactionState>.broadcast();

  /// Provider for sending transactions
  final AnchorProvider provider;

  SolanaTransactionWidget({required this.provider});

  /// Get current transaction
  Transaction? get transaction => _transaction;

  /// Get current state
  TransactionState get state => _state;

  /// Stream of transaction state changes
  Stream<TransactionState> get stateStream => _stateController.stream;

  @override
  Future<void> initialize() async {
    _updateState(TransactionState.empty);
  }

  /// Create new transaction
  void createTransaction({
    PublicKey? feePayer,
    String? recentBlockhash,
  }) {
    _transaction = Transaction(
      instructions: [],
      feePayer: feePayer,
      recentBlockhash: recentBlockhash,
    );
    _updateState(TransactionState.building);
  }

  /// Add instruction to transaction
  void addInstruction(TransactionInstruction instruction) {
    if (_transaction == null) {
      createTransaction();
    }

    _transaction!.instructions.add(instruction);
    _updateState(TransactionState.building);
  }

  /// Sign and send transaction
  Future<String> sendTransaction() async {
    if (_transaction == null) {
      throw Exception('No transaction to send');
    }

    _updateState(TransactionState.sending);

    try {
      final signature = await provider.sendAndConfirm(_transaction!);
      _updateState(TransactionState.confirmed);
      return signature;
    } catch (e) {
      _updateState(TransactionState.failed);
      rethrow;
    }
  }

  /// Simulate transaction
  Future<void> simulateTransaction() async {
    if (_transaction == null) {
      throw Exception('No transaction to simulate');
    }

    _updateState(TransactionState.simulating);

    try {
      await provider.simulate(_transaction!);
      _updateState(TransactionState.building);
    } catch (e) {
      _updateState(TransactionState.failed);
      rethrow;
    }
  }

  /// Clear current transaction
  void clearTransaction() {
    _transaction = null;
    _updateState(TransactionState.empty);
  }

  /// Update transaction state
  void _updateState(TransactionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  void dispose() {
    _stateController.close();
  }
}

/// Transaction states
enum TransactionState {
  /// No transaction
  empty,

  /// Building transaction
  building,

  /// Simulating transaction
  simulating,

  /// Sending transaction
  sending,

  /// Transaction confirmed
  confirmed,

  /// Transaction failed
  failed,
}

/// Account monitor widget for real-time account updates
class SolanaAccountMonitor implements SolanaWidget {
  /// Accounts being monitored
  final Map<PublicKey, StreamSubscription<dynamic>> _monitoredAccounts = {};

  /// Account data stream
  final StreamController<AccountUpdate> _accountUpdateController =
      StreamController<AccountUpdate>.broadcast();

  /// Connection for monitoring
  final Connection connection;

  /// Update interval for polling
  final Duration updateInterval;

  SolanaAccountMonitor({
    required this.connection,
    this.updateInterval = const Duration(seconds: 5),
  });

  /// Stream of account updates
  Stream<AccountUpdate> get accountUpdates => _accountUpdateController.stream;

  @override
  Future<void> initialize() async {
    // Initialization complete
  }

  /// Start monitoring an account
  void monitorAccount(PublicKey address) {
    if (_monitoredAccounts.containsKey(address)) {
      return; // Already monitoring
    }

    // Create periodic subscription to check account
    final subscription =
        Stream.periodic(updateInterval, (int _) => _).asyncMap((_) async {
      try {
        final balance = await connection.getBalance(address);
        return AccountUpdate(
          address: address,
          balance: balance,
          timestamp: DateTime.now(),
        );
      } catch (e) {
        return AccountUpdate(
          address: address,
          error: e.toString(),
          timestamp: DateTime.now(),
        );
      }
    }).listen((update) {
      _accountUpdateController.add(update);
    });

    _monitoredAccounts[address] = subscription;
  }

  /// Stop monitoring an account
  void stopMonitoring(PublicKey address) {
    _monitoredAccounts[address]?.cancel();
    _monitoredAccounts.remove(address);
  }

  /// Stop monitoring all accounts
  void stopAllMonitoring() {
    for (final subscription in _monitoredAccounts.values) {
      subscription.cancel();
    }
    _monitoredAccounts.clear();
  }

  /// Get list of monitored addresses
  List<PublicKey> get monitoredAddresses => _monitoredAccounts.keys.toList();

  @override
  void dispose() {
    stopAllMonitoring();
    _accountUpdateController.close();
  }
}

/// Account update data
class AccountUpdate {
  /// Account address
  final PublicKey address;

  /// Current balance (if available)
  final int? balance;

  /// Account data (if available)
  final Uint8List? data;

  /// Error message (if error occurred)
  final String? error;

  /// Update timestamp
  final DateTime timestamp;

  const AccountUpdate({
    required this.address,
    this.balance,
    this.data,
    this.error,
    required this.timestamp,
  });

  /// Whether this update contains an error
  bool get hasError => error != null;

  @override
  String toString() {
    if (hasError) {
      return 'AccountUpdate(${address.toBase58()}, error: $error)';
    }
    return 'AccountUpdate(${address.toBase58()}, balance: $balance)';
  }
}
