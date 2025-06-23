/// Wallet discovery and management system for automatic wallet detection
///
/// This module provides comprehensive wallet discovery functionality that
/// automatically detects available wallets across different environments
/// and provides a unified interface for wallet management.

library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/transaction.dart';
import 'wallet_adapter.dart';
import 'mobile_wallet_adapter.dart';

/// Wallet discovery service for automatic wallet detection and management
///
/// This service provides centralized wallet discovery, connection management,
/// and automatic failover between different wallet types. It follows the
/// TypeScript wallet adapter ecosystem patterns.
class WalletDiscoveryService {
  /// List of registered wallet adapters
  final List<WalletAdapter> _adapters = [];

  /// Currently active wallet adapter
  WalletAdapter? _activeWallet;

  /// Discovery configuration
  final WalletDiscoveryConfig _config;

  /// Stream controllers for events
  final StreamController<List<WalletAdapter>> _walletsController =
      StreamController<List<WalletAdapter>>.broadcast();
  final StreamController<WalletAdapter?> _activeWalletController =
      StreamController<WalletAdapter?>.broadcast();
  final StreamController<WalletDiscoveryEvent> _eventsController =
      StreamController<WalletDiscoveryEvent>.broadcast();

  /// Constructor for wallet discovery service
  WalletDiscoveryService({
    WalletDiscoveryConfig? config,
  }) : _config = config ?? WalletDiscoveryConfig.defaultConfig() {
    _initialize();
  }

  /// List of all registered wallet adapters
  List<WalletAdapter> get wallets => List.unmodifiable(_adapters);

  /// Currently active wallet adapter
  WalletAdapter? get activeWallet => _activeWallet;

  /// Stream of available wallets
  Stream<List<WalletAdapter>> get onWalletsChanged => _walletsController.stream;

  /// Stream of active wallet changes
  Stream<WalletAdapter?> get onActiveWalletChanged =>
      _activeWalletController.stream;

  /// Stream of discovery events
  Stream<WalletDiscoveryEvent> get onDiscoveryEvent => _eventsController.stream;

  /// Initialize the discovery service
  void _initialize() {
    if (_config.autoRegisterWallets) {
      _registerDefaultWallets();
    }

    if (_config.autoDiscovery) {
      _startAutoDiscovery();
    }
  }

  /// Register default wallets based on environment
  void _registerDefaultWallets() {
    // Register mobile wallet adapter for mobile environments
    if (_isMobileEnvironment()) {
      registerWallet(MobileWalletAdapter(
        config: MobileWalletAdapterConfig.defaultConfig(),
      ));
    }

    // PC/Desktop environment - could add desktop wallet adapters here in the future
    if (_isDesktopEnvironment()) {
      // Future: Add desktop wallet adapters (Sollet, etc.)
      // For now, we can use mobile wallet adapter with custom configuration
      registerWallet(MobileWalletAdapter(
        config: MobileWalletAdapterConfig(
          appName: 'Coral XYZ Dart SDK (Desktop)',
          platform: const MobileWalletPlatform.universal(),
        ),
      ));
    }
  }

  /// Check if running in mobile environment
  bool _isMobileEnvironment() {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  /// Check if running in desktop environment
  bool _isDesktopEnvironment() {
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Start automatic wallet discovery
  void _startAutoDiscovery() {
    Timer.periodic(_config.discoveryInterval, (_) {
      _performDiscovery();
    });

    // Perform initial discovery
    _performDiscovery();
  }

  /// Perform wallet discovery
  Future<void> _performDiscovery() async {
    final discoveredWallets = <WalletAdapter>[];

    for (final adapter in _adapters) {
      if (adapter.supported &&
          adapter.readyState == WalletReadyState.installed) {
        discoveredWallets.add(adapter);
      }
    }

    _emitEvent(WalletDiscoveryEvent.walletsDiscovered(discoveredWallets));
  }

  /// Register a wallet adapter
  void registerWallet(WalletAdapter adapter) {
    if (!_adapters.contains(adapter)) {
      _adapters.add(adapter);

      // Listen for wallet state changes
      adapter.onReadyStateChange.listen((state) {
        _walletsController.add(wallets);
        _emitEvent(WalletDiscoveryEvent.walletStateChanged(adapter, state));
      });

      _walletsController.add(wallets);
      _emitEvent(WalletDiscoveryEvent.walletRegistered(adapter));
    }
  }

  /// Unregister a wallet adapter
  void unregisterWallet(WalletAdapter adapter) {
    if (_adapters.remove(adapter)) {
      if (_activeWallet == adapter) {
        _setActiveWallet(null);
      }

      _walletsController.add(wallets);
      _emitEvent(WalletDiscoveryEvent.walletUnregistered(adapter));
    }
  }

  /// Get wallets by ready state
  List<WalletAdapter> getWalletsByState(WalletReadyState state) {
    return _adapters.where((adapter) => adapter.readyState == state).toList();
  }

  /// Get installed and ready wallets
  List<WalletAdapter> getAvailableWallets() {
    return getWalletsByState(WalletReadyState.installed)
        .where((adapter) => adapter.supported)
        .toList();
  }

  /// Get connected wallets
  List<WalletAdapter> getConnectedWallets() {
    return _adapters.where((adapter) => adapter.connected).toList();
  }

  /// Find wallet by name
  WalletAdapter? findWalletByName(String name) {
    try {
      return _adapters.firstWhere(
        (adapter) => adapter.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Set the active wallet
  Future<void> setActiveWallet(WalletAdapter? wallet) async {
    if (wallet == _activeWallet) return;

    // Disconnect current active wallet if connected
    if (_activeWallet?.connected == true) {
      await _activeWallet!.disconnect();
    }

    _setActiveWallet(wallet);
  }

  /// Internal method to set active wallet
  void _setActiveWallet(WalletAdapter? wallet) {
    _activeWallet = wallet;
    _activeWalletController.add(wallet);
    _emitEvent(WalletDiscoveryEvent.activeWalletChanged(wallet));
  }

  /// Connect to a wallet by name
  Future<void> connectToWallet(String walletName) async {
    final wallet = findWalletByName(walletName);
    if (wallet == null) {
      throw WalletNotAvailableException('Wallet "$walletName" not found');
    }

    if (!wallet.supported) {
      throw WalletNotSupportedException(
          'Wallet "$walletName" is not supported');
    }

    if (wallet.readyState != WalletReadyState.installed) {
      throw WalletNotAvailableException(
          'Wallet "$walletName" is not installed');
    }

    await wallet.connect();
    await setActiveWallet(wallet);
  }

  /// Auto-connect to the best available wallet
  Future<WalletAdapter?> autoConnect() async {
    final availableWallets = getAvailableWallets();

    if (availableWallets.isEmpty) {
      _emitEvent(WalletDiscoveryEvent.noWalletsAvailable());
      return null;
    }

    // Try wallets in priority order
    final prioritizedWallets = _prioritizeWallets(availableWallets);

    for (final wallet in prioritizedWallets) {
      try {
        await wallet.connect();
        await setActiveWallet(wallet);
        _emitEvent(WalletDiscoveryEvent.autoConnectSuccess(wallet));
        return wallet;
      } catch (e) {
        _emitEvent(WalletDiscoveryEvent.autoConnectFailed(wallet, e));
        // Continue to next wallet
      }
    }

    _emitEvent(WalletDiscoveryEvent.autoConnectExhausted());
    return null;
  }

  /// Prioritize wallets for auto-connection
  List<WalletAdapter> _prioritizeWallets(List<WalletAdapter> wallets) {
    final prioritizedWallets = <WalletAdapter>[];

    // Add wallets in priority order from config
    for (final priorityWallet in _config.walletPriority) {
      final wallet = wallets.firstWhere(
        (w) => w.name.toLowerCase() == priorityWallet.toLowerCase(),
        orElse: () =>
            wallets.first, // This will be ignored due to contains check
      );
      if (wallets.contains(wallet) && !prioritizedWallets.contains(wallet)) {
        prioritizedWallets.add(wallet);
      }
    }

    // Add remaining wallets
    for (final wallet in wallets) {
      if (!prioritizedWallets.contains(wallet)) {
        prioritizedWallets.add(wallet);
      }
    }

    return prioritizedWallets;
  }

  /// Disconnect from current active wallet
  Future<void> disconnect() async {
    if (_activeWallet?.connected == true) {
      await _activeWallet!.disconnect();
    }
    await setActiveWallet(null);
  }

  /// Emit a discovery event
  void _emitEvent(WalletDiscoveryEvent event) {
    _eventsController.add(event);
  }

  /// Clean up resources
  void dispose() {
    for (final adapter in _adapters) {
      if (adapter is BaseWalletAdapter) {
        adapter.dispose();
      }
    }
    _adapters.clear();

    _walletsController.close();
    _activeWalletController.close();
    _eventsController.close();
  }
}

/// Configuration for wallet discovery service
class WalletDiscoveryConfig {
  /// Whether to automatically register default wallets
  final bool autoRegisterWallets;

  /// Whether to enable automatic wallet discovery
  final bool autoDiscovery;

  /// Interval for wallet discovery checks
  final Duration discoveryInterval;

  /// List of enabled wallet names (empty means all wallets enabled)
  final List<String> enabledWallets;

  /// Priority order for wallet auto-connection
  final List<String> walletPriority;

  /// Maximum time to wait for wallet operations
  final Duration operationTimeout;

  const WalletDiscoveryConfig({
    this.autoRegisterWallets = true,
    this.autoDiscovery = true,
    this.discoveryInterval = const Duration(seconds: 5),
    this.enabledWallets = const [],
    this.walletPriority = const ['Mobile Wallet Adapter'],
    this.operationTimeout = const Duration(minutes: 2),
  });

  /// Default configuration
  static WalletDiscoveryConfig defaultConfig() {
    return const WalletDiscoveryConfig();
  }

  /// Mobile-optimized configuration
  static WalletDiscoveryConfig mobile() {
    return const WalletDiscoveryConfig(
      discoveryInterval: Duration(seconds: 10),
      walletPriority: ['Mobile Wallet Adapter'],
      operationTimeout: Duration(minutes: 5),
    );
  }

  /// Desktop/PC-optimized configuration
  static WalletDiscoveryConfig desktop() {
    return const WalletDiscoveryConfig(
      discoveryInterval: Duration(seconds: 5),
      walletPriority: ['Mobile Wallet Adapter'], // Use MWA for desktop too
      operationTimeout: Duration(minutes: 2),
    );
  }
}

/// Wallet discovery events
class WalletDiscoveryEvent {
  /// Event type
  final WalletDiscoveryEventType type;

  /// Associated wallet adapter (if applicable)
  final WalletAdapter? wallet;

  /// Additional event data
  final Map<String, dynamic> data;

  /// Event timestamp
  final DateTime timestamp;

  WalletDiscoveryEvent({
    required this.type,
    this.wallet,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Wallet registered event
  factory WalletDiscoveryEvent.walletRegistered(WalletAdapter wallet) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.walletRegistered,
      wallet: wallet,
      data: {'walletName': wallet.name},
    );
  }

  /// Wallet unregistered event
  factory WalletDiscoveryEvent.walletUnregistered(WalletAdapter wallet) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.walletUnregistered,
      wallet: wallet,
      data: {'walletName': wallet.name},
    );
  }

  /// Wallet state changed event
  factory WalletDiscoveryEvent.walletStateChanged(
    WalletAdapter wallet,
    WalletReadyState state,
  ) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.walletStateChanged,
      wallet: wallet,
      data: {'walletName': wallet.name, 'state': state.name},
    );
  }

  /// Wallets discovered event
  factory WalletDiscoveryEvent.walletsDiscovered(List<WalletAdapter> wallets) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.walletsDiscovered,
      data: {
        'walletCount': wallets.length,
        'walletNames': wallets.map((w) => w.name).toList(),
      },
    );
  }

  /// Active wallet changed event
  factory WalletDiscoveryEvent.activeWalletChanged(WalletAdapter? wallet) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.activeWalletChanged,
      wallet: wallet,
      data: {'walletName': wallet?.name},
    );
  }

  /// Auto-connect success event
  factory WalletDiscoveryEvent.autoConnectSuccess(WalletAdapter wallet) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.autoConnectSuccess,
      wallet: wallet,
      data: {'walletName': wallet.name},
    );
  }

  /// Auto-connect failed event
  factory WalletDiscoveryEvent.autoConnectFailed(
    WalletAdapter wallet,
    dynamic error,
  ) {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.autoConnectFailed,
      wallet: wallet,
      data: {'walletName': wallet.name, 'error': error.toString()},
    );
  }

  /// Auto-connect exhausted event
  factory WalletDiscoveryEvent.autoConnectExhausted() {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.autoConnectExhausted,
    );
  }

  /// No wallets available event
  factory WalletDiscoveryEvent.noWalletsAvailable() {
    return WalletDiscoveryEvent(
      type: WalletDiscoveryEventType.noWalletsAvailable,
    );
  }

  @override
  String toString() {
    return 'WalletDiscoveryEvent(type: $type, wallet: ${wallet?.name}, data: $data)';
  }
}

/// Types of wallet discovery events
enum WalletDiscoveryEventType {
  walletRegistered,
  walletUnregistered,
  walletStateChanged,
  walletsDiscovered,
  activeWalletChanged,
  autoConnectSuccess,
  autoConnectFailed,
  autoConnectExhausted,
  noWalletsAvailable,
}

/// Universal wallet interface that provides access to discovery service
///
/// This class provides a simplified interface for wallet operations while
/// leveraging the discovery service for automatic wallet management.
class UniversalWallet {
  /// Discovery service instance
  final WalletDiscoveryService _discoveryService;

  /// Constructor
  UniversalWallet({
    WalletDiscoveryConfig? config,
  }) : _discoveryService = WalletDiscoveryService(config: config);

  /// Get the discovery service
  WalletDiscoveryService get discoveryService => _discoveryService;

  /// Currently active wallet
  WalletAdapter? get activeWallet => _discoveryService.activeWallet;

  /// Whether a wallet is connected
  bool get connected => activeWallet?.connected ?? false;

  /// Public key of connected wallet
  PublicKey? get publicKey => activeWallet?.publicKey;

  /// Connect to any available wallet automatically
  Future<void> connect() async {
    await _discoveryService.autoConnect();
  }

  /// Connect to a specific wallet by name
  Future<void> connectToWallet(String walletName) async {
    await _discoveryService.connectToWallet(walletName);
  }

  /// Disconnect from current wallet
  Future<void> disconnect() async {
    await _discoveryService.disconnect();
  }

  /// Sign a transaction using the active wallet
  Future<Transaction> signTransaction(Transaction transaction) async {
    final wallet = activeWallet;
    if (wallet == null || !wallet.connected) {
      throw const WalletNotConnectedException();
    }
    return await wallet.signTransaction(transaction);
  }

  /// Sign multiple transactions using the active wallet
  Future<List<Transaction>> signAllTransactions(
    List<Transaction> transactions,
  ) async {
    final wallet = activeWallet;
    if (wallet == null || !wallet.connected) {
      throw const WalletNotConnectedException();
    }
    return await wallet.signAllTransactions(transactions);
  }

  /// Sign a message using the active wallet
  Future<Uint8List> signMessage(Uint8List message) async {
    final wallet = activeWallet;
    if (wallet == null || !wallet.connected) {
      throw const WalletNotConnectedException();
    }
    return await wallet.signMessage(message);
  }

  /// Get list of available wallets
  List<WalletAdapter> getAvailableWallets() {
    return _discoveryService.getAvailableWallets();
  }

  /// Stream of wallet connection events
  Stream<bool> get onConnectionChanged {
    return _discoveryService.onActiveWalletChanged
        .map((wallet) => wallet?.connected ?? false);
  }

  /// Stream of active wallet changes
  Stream<WalletAdapter?> get onActiveWalletChanged {
    return _discoveryService.onActiveWalletChanged;
  }

  /// Stream of discovery events
  Stream<WalletDiscoveryEvent> get onDiscoveryEvent {
    return _discoveryService.onDiscoveryEvent;
  }

  /// Clean up resources
  void dispose() {
    _discoveryService.dispose();
  }
}
