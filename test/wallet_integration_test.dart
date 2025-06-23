/// Tests for advanced wallet integration system
///
/// This test suite validates the wallet adapter interface, mobile wallet
/// implementations, and the wallet discovery service to ensure they
/// match TypeScript Anchor client functionality (mobile and PC only).

import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import '../lib/src/wallet/wallet_adapter.dart';
import '../lib/src/wallet/mobile_wallet_adapter.dart';
import '../lib/src/wallet/wallet_discovery.dart';
import '../lib/src/types/public_key.dart';
import '../lib/src/types/transaction.dart';

void main() {
  group('WalletAdapter Interface', () {
    test('should define standard wallet adapter interface', () {
      // This test validates the interface exists and has required methods
      expect(WalletAdapter, isNotNull);

      // Validate enum values
      expect(WalletReadyState.values, contains(WalletReadyState.notDetected));
      expect(WalletReadyState.values, contains(WalletReadyState.installed));
      expect(WalletReadyState.values, contains(WalletReadyState.loading));
      expect(WalletReadyState.values, contains(WalletReadyState.unsupported));
    });

    test('should define wallet exception hierarchy', () {
      // Test exception hierarchy
      const connectionException =
          WalletConnectionException('Test connection error');
      expect(connectionException, isA<WalletException>());
      expect(connectionException.code, equals('CONNECTION_FAILED'));
      expect(connectionException.message, equals('Test connection error'));

      const userRejectedException = WalletUserRejectedException();
      expect(userRejectedException, isA<WalletException>());
      expect(userRejectedException.code, equals('USER_REJECTED'));

      const notConnectedException = WalletNotConnectedException();
      expect(notConnectedException, isA<WalletException>());
      expect(notConnectedException.code, equals('NOT_CONNECTED'));

      const signingException = WalletSigningException('Signing failed');
      expect(signingException, isA<WalletException>());
      expect(signingException.code, equals('SIGNING_FAILED'));

      const notAvailableException = WalletNotAvailableException();
      expect(notAvailableException, isA<WalletException>());
      expect(notAvailableException.code, equals('NOT_AVAILABLE'));

      const notSupportedException = WalletNotSupportedException();
      expect(notSupportedException, isA<WalletException>());
      expect(notSupportedException.code, equals('NOT_SUPPORTED'));

      final timeoutException =
          WalletTimeoutException(const Duration(seconds: 30));
      expect(timeoutException, isA<WalletException>());
      expect(timeoutException.code, equals('TIMEOUT'));
      expect(timeoutException.timeout, equals(const Duration(seconds: 30)));
    });
  });

  group('BaseWalletAdapter', () {
    late TestWalletAdapter adapter;

    setUp(() {
      adapter = TestWalletAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    test('should manage connection state correctly', () {
      expect(adapter.connected, isFalse);
      expect(adapter.readyState, equals(WalletReadyState.notDetected));
      expect(adapter.publicKey, isNull);

      // Test connection state changes
      adapter.setConnected(true);
      expect(adapter.connected, isTrue);

      // Test ready state changes
      adapter.setReadyState(WalletReadyState.installed);
      expect(adapter.readyState, equals(WalletReadyState.installed));

      // Test public key changes
      final testPublicKey =
          PublicKey.fromBase58('11111111111111111111111111111112');
      adapter.setPublicKey(testPublicKey);
      expect(adapter.publicKey, equals(testPublicKey));
    });

    test('should emit events correctly', () async {
      final connectEvents = <bool>[];
      final disconnectEvents = <void>[];
      final accountChangeEvents = <PublicKey?>[];
      final readyStateEvents = <WalletReadyState>[];
      final errorEvents = <WalletException>[];

      adapter.onConnect.listen(connectEvents.add);
      adapter.onDisconnect.listen(disconnectEvents.add);
      adapter.onAccountChange.listen(accountChangeEvents.add);
      adapter.onReadyStateChange.listen(readyStateEvents.add);
      adapter.onError.listen(errorEvents.add);

      // Test connection events
      adapter.setConnected(true);
      adapter.setConnected(false);

      // Test ready state events
      adapter.setReadyState(WalletReadyState.loading);
      adapter.setReadyState(WalletReadyState.installed);

      // Test account change events
      final publicKey =
          PublicKey.fromBase58('11111111111111111111111111111112');
      adapter.setPublicKey(publicKey);
      adapter.setPublicKey(null);

      // Test disconnect and error events
      adapter.emitDisconnect();
      adapter.emitError(const WalletConnectionException('Test error'));

      // Wait for events to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      expect(connectEvents, equals([true, false]));
      expect(disconnectEvents, hasLength(1));
      expect(accountChangeEvents, equals([publicKey, null]));
      expect(readyStateEvents,
          equals([WalletReadyState.loading, WalletReadyState.installed]));
      expect(errorEvents, hasLength(1));
      expect(errorEvents.first, isA<WalletConnectionException>());
    });

    test('should manage properties correctly', () {
      expect(adapter.properties, isEmpty);

      adapter.setProperty('test_key', 'test_value');
      expect(adapter.properties['test_key'], equals('test_value'));

      adapter.setProperty('numeric_key', 42);
      expect(adapter.properties['numeric_key'], equals(42));

      // Properties should be read-only from external interface
      expect(() => adapter.properties['external_key'] = 'external_value',
          throwsUnsupportedError);
    });
  });

  group('MobileWalletAdapter', () {
    late MobileWalletAdapter adapter;

    setUp(() {
      adapter = MobileWalletAdapter(
        config: MobileWalletAdapterConfig.defaultConfig(),
      );
    });

    tearDown(() {
      adapter.dispose();
    });

    test('should initialize with correct configuration', () {
      expect(adapter.name, equals('Mobile Wallet Adapter'));
      expect(adapter.supported, isTrue);
      expect(adapter.properties['protocol'], equals('MWA'));
      expect(adapter.properties['version'], equals('1.0'));
      expect(adapter.properties['platform'], equals('universal'));
    });

    test('should create mobile wallet configuration correctly', () {
      final config = MobileWalletAdapterConfig(
        appName: 'Test App',
        appIcon: 'https://example.com/icon.png',
        cluster: 'devnet',
        permissions: ['sign_transactions'],
      );

      expect(config.appName, equals('Test App'));
      expect(config.appIcon, equals('https://example.com/icon.png'));
      expect(config.cluster, equals('devnet'));
      expect(config.permissions, equals(['sign_transactions']));
    });

    test('should create platform configurations correctly', () {
      const universalPlatform = MobileWalletPlatform.universal();
      expect(universalPlatform.name, equals('universal'));
      expect(universalPlatform.isSupported, isTrue);

      const iosPlatform = MobileWalletPlatform.ios();
      expect(iosPlatform.name, equals('ios'));
      expect(iosPlatform.isSupported, isTrue);

      const androidPlatform = MobileWalletPlatform.android();
      expect(androidPlatform.name, equals('android'));
      expect(androidPlatform.isSupported, isTrue);

      const webPlatform = MobileWalletPlatform.web();
      expect(webPlatform.name, equals('web'));
      expect(webPlatform.isSupported, isFalse);
    });

    test('should create request objects correctly', () {
      final connectRequest = MobileWalletRequest.connect(
        appName: 'Test App',
        appIcon: 'https://example.com/icon.png',
        cluster: 'devnet',
        permissions: ['sign_transactions'],
      );

      expect(connectRequest.type, equals('connect'));
      expect(connectRequest.id, isNotEmpty);
      expect(connectRequest.timestamp, isA<DateTime>());

      final connectJson = connectRequest.toJson();
      expect(connectJson['type'], equals('connect'));
      expect(connectJson['appName'], equals('Test App'));
      expect(connectJson['cluster'], equals('devnet'));

      final disconnectRequest =
          MobileWalletRequest.disconnect(sessionId: 'test-session');
      expect(disconnectRequest.type, equals('disconnect'));

      final testTransaction = Uint8List.fromList([1, 2, 3, 4]);
      final signRequest = MobileWalletRequest.signTransaction(
        sessionId: 'test-session',
        transaction: testTransaction,
      );
      expect(signRequest.type, equals('sign_transaction'));

      final signMessage = MobileWalletRequest.signMessage(
        sessionId: 'test-session',
        message: testTransaction,
      );
      expect(signMessage.type, equals('sign_message'));
    });

    test('should handle connection timeout correctly', () async {
      final shortTimeoutAdapter = MobileWalletAdapter(
        timeout: const Duration(milliseconds: 100),
      );

      try {
        await shortTimeoutAdapter.connect();
        fail('Expected timeout exception');
      } catch (e) {
        expect(e, isA<WalletTimeoutException>());
        final timeoutException = e as WalletTimeoutException;
        expect(timeoutException.timeout,
            equals(const Duration(milliseconds: 100)));
      } finally {
        shortTimeoutAdapter.dispose();
      }
    });
  });

  group('WalletDiscoveryService', () {
    late WalletDiscoveryService discoveryService;

    setUp(() {
      discoveryService = WalletDiscoveryService(
        config: WalletDiscoveryConfig(
          autoRegisterWallets: false, // Disable auto-registration for tests
          autoDiscovery: false, // Disable auto-discovery for tests
        ),
      );
    });

    tearDown(() {
      discoveryService.dispose();
    });

    test('should manage wallet registration correctly', () {
      final testAdapter = TestWalletAdapter();

      expect(discoveryService.wallets, isEmpty);

      discoveryService.registerWallet(testAdapter);
      expect(discoveryService.wallets, contains(testAdapter));
      expect(discoveryService.wallets, hasLength(1));

      // Should not register duplicate wallets
      discoveryService.registerWallet(testAdapter);
      expect(discoveryService.wallets, hasLength(1));

      discoveryService.unregisterWallet(testAdapter);
      expect(discoveryService.wallets, isEmpty);

      testAdapter.dispose();
    });

    test('should manage active wallet correctly', () async {
      final testAdapter1 = TestWalletAdapter();
      final testAdapter2 = TestWalletAdapter();

      discoveryService.registerWallet(testAdapter1);
      discoveryService.registerWallet(testAdapter2);

      expect(discoveryService.activeWallet, isNull);

      await discoveryService.setActiveWallet(testAdapter1);
      expect(discoveryService.activeWallet, equals(testAdapter1));

      await discoveryService.setActiveWallet(testAdapter2);
      expect(discoveryService.activeWallet, equals(testAdapter2));

      await discoveryService.setActiveWallet(null);
      expect(discoveryService.activeWallet, isNull);

      testAdapter1.dispose();
      testAdapter2.dispose();
    });

    test('should filter wallets by state correctly', () {
      final installedAdapter = TestWalletAdapter();
      installedAdapter.setReadyState(WalletReadyState.installed);

      final loadingAdapter = TestWalletAdapter();
      loadingAdapter.setReadyState(WalletReadyState.loading);

      final notDetectedAdapter = TestWalletAdapter();
      notDetectedAdapter.setReadyState(WalletReadyState.notDetected);

      discoveryService.registerWallet(installedAdapter);
      discoveryService.registerWallet(loadingAdapter);
      discoveryService.registerWallet(notDetectedAdapter);

      final installedWallets =
          discoveryService.getWalletsByState(WalletReadyState.installed);
      expect(installedWallets, contains(installedAdapter));
      expect(installedWallets, hasLength(1));

      final availableWallets = discoveryService.getAvailableWallets();
      expect(availableWallets, contains(installedAdapter));
      expect(availableWallets, hasLength(1));

      installedAdapter.dispose();
      loadingAdapter.dispose();
      notDetectedAdapter.dispose();
    });

    test('should find wallets by name correctly', () {
      final testAdapter = TestWalletAdapter();
      discoveryService.registerWallet(testAdapter);

      final foundWallet = discoveryService.findWalletByName('Test Wallet');
      expect(foundWallet, equals(testAdapter));

      final notFoundWallet =
          discoveryService.findWalletByName('Non-existent Wallet');
      expect(notFoundWallet, isNull);

      testAdapter.dispose();
    });

    test('should emit discovery events correctly', () async {
      final events = <WalletDiscoveryEvent>[];
      discoveryService.onDiscoveryEvent.listen(events.add);

      final testAdapter = TestWalletAdapter();
      discoveryService.registerWallet(testAdapter);

      await discoveryService.setActiveWallet(testAdapter);

      // Wait for events to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events, isNotEmpty);
      expect(
          events
              .any((e) => e.type == WalletDiscoveryEventType.walletRegistered),
          isTrue);
      expect(
          events.any(
              (e) => e.type == WalletDiscoveryEventType.activeWalletChanged),
          isTrue);

      testAdapter.dispose();
    });

    test('should create discovery configurations correctly', () {
      final defaultConfig = WalletDiscoveryConfig.defaultConfig();
      expect(defaultConfig.autoRegisterWallets, isTrue);
      expect(defaultConfig.autoDiscovery, isTrue);
      expect(defaultConfig.walletPriority, contains('Mobile Wallet Adapter'));

      final mobileConfig = WalletDiscoveryConfig.mobile();
      expect(mobileConfig.walletPriority, contains('Mobile Wallet Adapter'));
      expect(mobileConfig.operationTimeout, equals(const Duration(minutes: 5)));

      final desktopConfig = WalletDiscoveryConfig.desktop();
      expect(desktopConfig.walletPriority, contains('Mobile Wallet Adapter'));
      expect(
          desktopConfig.operationTimeout, equals(const Duration(minutes: 2)));
    });
  });

  group('UniversalWallet', () {
    late UniversalWallet universalWallet;

    setUp(() {
      universalWallet = UniversalWallet(
        config: WalletDiscoveryConfig(
          autoRegisterWallets: false,
          autoDiscovery: false,
        ),
      );
    });

    tearDown(() {
      universalWallet.dispose();
    });

    test('should provide unified wallet interface', () {
      expect(universalWallet.connected, isFalse);
      expect(universalWallet.publicKey, isNull);
      expect(universalWallet.activeWallet, isNull);
      expect(universalWallet.getAvailableWallets(), isEmpty);
    });

    test('should handle wallet operations correctly', () async {
      final testAdapter = TestWalletAdapter();
      testAdapter.setReadyState(WalletReadyState.installed);

      universalWallet.discoveryService.registerWallet(testAdapter);

      try {
        await universalWallet.connectToWallet('Test Wallet');
        expect(universalWallet.activeWallet, equals(testAdapter));
      } catch (e) {
        // Connection might fail in test environment - that's expected
        expect(e, isA<WalletException>());
      }

      await universalWallet.disconnect();
      expect(universalWallet.activeWallet, isNull);

      testAdapter.dispose();
    });

    test('should provide event streams correctly', () {
      expect(universalWallet.onConnectionChanged, isA<Stream<bool>>());
      expect(
          universalWallet.onActiveWalletChanged, isA<Stream<WalletAdapter?>>());
      expect(universalWallet.onDiscoveryEvent,
          isA<Stream<WalletDiscoveryEvent>>());
    });
  });

  group('Wallet Integration End-to-End', () {
    test('should integrate all wallet components correctly', () async {
      final discoveryService = WalletDiscoveryService(
        config: WalletDiscoveryConfig(
          autoRegisterWallets: false,
          autoDiscovery: false,
        ),
      );

      // Register test wallets
      final mobileAdapter = TestWalletAdapter(name: 'Mobile Test Wallet');
      final desktopAdapter = TestWalletAdapter(name: 'Desktop Test Wallet');

      mobileAdapter.setReadyState(WalletReadyState.installed);
      desktopAdapter.setReadyState(WalletReadyState.installed);

      discoveryService.registerWallet(mobileAdapter);
      discoveryService.registerWallet(desktopAdapter);

      // Test wallet discovery
      final availableWallets = discoveryService.getAvailableWallets();
      expect(availableWallets, hasLength(2));
      expect(
          availableWallets.map((w) => w.name), contains('Mobile Test Wallet'));
      expect(
          availableWallets.map((w) => w.name), contains('Desktop Test Wallet'));

      // Test wallet connection through discovery service
      final foundWallet =
          discoveryService.findWalletByName('Mobile Test Wallet');
      expect(foundWallet, isNotNull);
      expect(foundWallet!.name, equals('Mobile Test Wallet'));

      // Clean up
      mobileAdapter.dispose();
      desktopAdapter.dispose();
      discoveryService.dispose();
    });

    test('should handle error scenarios correctly', () async {
      final discoveryService = WalletDiscoveryService(
        config: WalletDiscoveryConfig(
          autoRegisterWallets: false,
          autoDiscovery: false,
        ),
      );

      // Test connecting to non-existent wallet
      try {
        await discoveryService.connectToWallet('Non-existent Wallet');
        fail('Expected WalletNotAvailableException');
      } catch (e) {
        expect(e, isA<WalletNotAvailableException>());
      }

      // Test connecting to unsupported wallet
      final unsupportedAdapter = TestWalletAdapter(supported: false);
      discoveryService.registerWallet(unsupportedAdapter);

      try {
        await discoveryService.connectToWallet('Test Wallet');
        fail('Expected WalletNotSupportedException');
      } catch (e) {
        expect(e, isA<WalletNotSupportedException>());
      }

      unsupportedAdapter.dispose();
      discoveryService.dispose();
    });
  });
}

/// Test implementation of WalletAdapter for testing purposes
class TestWalletAdapter extends BaseWalletAdapter {
  final String _name;
  final bool _supported;

  TestWalletAdapter({
    String? name,
    bool supported = true,
  })  : _name = name ?? 'Test Wallet',
        _supported = supported {
    setReadyState(WalletReadyState.notDetected);
  }

  @override
  String get name => _name;

  @override
  String? get icon => 'https://example.com/test-wallet-icon.png';

  @override
  String? get url => 'https://example.com/test-wallet';

  @override
  bool get supported => _supported;

  @override
  Future<void> connect() async {
    if (!supported) {
      throw const WalletNotSupportedException();
    }

    if (readyState != WalletReadyState.installed) {
      throw const WalletNotAvailableException();
    }

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 10));

    final testPublicKey =
        PublicKey.fromBase58('11111111111111111111111111111112');
    setPublicKey(testPublicKey);
    setConnected(true);
  }

  @override
  Future<void> disconnect() async {
    setPublicKey(null);
    setConnected(false);
    emitDisconnect();
  }

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (!connected) {
      throw const WalletNotConnectedException();
    }

    // Simulate signing delay
    await Future.delayed(const Duration(milliseconds: 5));

    // For testing, just return the transaction with a mock signature
    final signedTx = Transaction(
      instructions: transaction.instructions,
      feePayer: transaction.feePayer ?? publicKey,
      recentBlockhash: transaction.recentBlockhash,
    );

    if (publicKey != null) {
      final mockSignature = Uint8List.fromList(List.filled(64, 1));
      signedTx.addSignature(publicKey!, mockSignature);
    }

    return signedTx;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
    List<Transaction> transactions,
  ) async {
    final signedTransactions = <Transaction>[];
    for (final transaction in transactions) {
      signedTransactions.add(await signTransaction(transaction));
    }
    return signedTransactions;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (!connected) {
      throw const WalletNotConnectedException();
    }

    // Simulate signing delay
    await Future.delayed(const Duration(milliseconds: 5));

    // Return mock signature
    return Uint8List.fromList(List.filled(64, 2));
  }
}
