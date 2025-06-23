/// Tests for Step 8.5: Mobile and Web Platform Optimization
///
/// This test suite validates all platform-specific optimizations including
/// mobile features, web integrations, Flutter widgets, and platform detection.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/platform/mobile_optimization.dart'
    as mobile;
import 'package:coral_xyz_anchor/src/platform/platform_optimization.dart';
import 'package:coral_xyz_anchor/src/platform/platform_integration.dart';
import 'package:coral_xyz_anchor/src/platform/web_optimization.dart';
import 'package:coral_xyz_anchor/src/platform/mobile_optimization.dart';
import 'package:coral_xyz_anchor/src/platform/flutter_widgets.dart';

void main() {
  group('Step 8.5: Mobile and Web Platform Optimization', () {
    group('Platform Detection and Optimization', () {
      test('should detect platform correctly', () {
        final platform = PlatformOptimization.currentPlatform;
        expect(platform, isA<PlatformType>());

        // Should have valid configuration for any platform
        final config = PlatformPerformanceConfig.forPlatform(platform);
        expect(config.connectionPoolSize, greaterThan(0));
        expect(config.requestTimeout.inMilliseconds, greaterThan(0));
      });

      test('should provide platform-specific timeouts', () {
        final timeout = PlatformOptimization.connectionTimeout;
        expect(timeout.inSeconds, greaterThan(0));
        expect(timeout.inSeconds, lessThanOrEqualTo(30)); // Reasonable timeout
      });

      test('should provide platform-specific retry configuration', () {
        final retryDelay = PlatformOptimization.retryDelay;
        expect(retryDelay.inMilliseconds, greaterThan(0));
        expect(retryDelay.inSeconds,
            lessThanOrEqualTo(5)); // Reasonable retry delay
      });

      test('should provide platform-specific connection limits', () {
        final maxConnections = PlatformOptimization.maxConcurrentConnections;
        expect(maxConnections, greaterThan(0));
        expect(maxConnections, lessThanOrEqualTo(20)); // Reasonable limit
      });

      test('should handle platform capabilities correctly', () {
        // These should return boolean values without throwing
        expect(PlatformOptimization.supportsBackgroundProcessing, isA<bool>());
        expect(PlatformOptimization.supportsLocalStorage, isA<bool>());
        expect(PlatformOptimization.isMobile, isA<bool>());
        expect(PlatformOptimization.isWeb, isA<bool>());
        expect(PlatformOptimization.isDesktop, isA<bool>());
      });
    });

    group('Platform Error Handling', () {
      test('should provide platform-specific error messages', () {
        final networkError = Exception('network connection failed');
        final timeoutError = Exception('request timeout');
        final walletError = Exception('wallet operation failed');

        for (final platform in PlatformType.values) {
          final networkMsg =
              PlatformErrorHandler.getErrorMessage(networkError, platform);
          final timeoutMsg =
              PlatformErrorHandler.getErrorMessage(timeoutError, platform);
          final walletMsg =
              PlatformErrorHandler.getErrorMessage(walletError, platform);

          expect(networkMsg, isA<String>());
          expect(networkMsg, isNotEmpty);
          expect(timeoutMsg, isA<String>());
          expect(timeoutMsg, isNotEmpty);
          expect(walletMsg, isA<String>());
          expect(walletMsg, isNotEmpty);
        }
      });

      test('should provide user-friendly error messages', () {
        final error = Exception('connection timeout');
        final message = PlatformUtils.getErrorMessage(error);

        expect(message, isA<String>());
        expect(message, isNotEmpty);
        // Should not contain raw exception text
        expect(message.toLowerCase(), isNot(contains('exception')));
      });
    });

    group('Background Task Management', () {
      test('should manage background tasks correctly', () {
        const taskId = 'test_task';

        void testCallback() {
          // Task callback
        }

        // Register task
        BackgroundTaskManager.registerTask(
          taskId,
          const Duration(milliseconds: 10),
          testCallback,
        );

        expect(BackgroundTaskManager.isTaskActive(taskId), isTrue);
        expect(BackgroundTaskManager.activeTaskIds, contains(taskId));

        // Cancel task
        BackgroundTaskManager.cancelTask(taskId);
        expect(BackgroundTaskManager.isTaskActive(taskId), isFalse);
        expect(BackgroundTaskManager.activeTaskIds, isNot(contains(taskId)));
      });

      test('should cancel all tasks', () {
        void testCallback() {/* Task callback */}

        // Register multiple tasks
        BackgroundTaskManager.registerTask(
            'task1', const Duration(milliseconds: 10), testCallback);
        BackgroundTaskManager.registerTask(
            'task2', const Duration(milliseconds: 10), testCallback);

        expect(BackgroundTaskManager.activeTaskIds.length, equals(2));

        // Cancel all
        BackgroundTaskManager.cancelAllTasks();
        expect(BackgroundTaskManager.activeTaskIds, isEmpty);
      });
    });

    group('Platform Storage', () {
      test('should create appropriate storage for platform', () {
        final storage = PlatformStorageFactory.instance;
        expect(storage, isA<PlatformStorage>());
        expect(storage.isAvailable, isTrue);
      });

      test('should store and retrieve data correctly', () async {
        final storage = MemoryStorage();

        // Test storage operations
        await storage.store('test_key', 'test_value');
        final retrieved = await storage.retrieve('test_key');
        expect(retrieved, equals('test_value'));

        // Test removal
        await storage.remove('test_key');
        final removed = await storage.retrieve('test_key');
        expect(removed, isNull);

        // Test clear
        await storage.store('key1', 'value1');
        await storage.store('key2', 'value2');
        await storage.clear();

        expect(await storage.retrieve('key1'), isNull);
        expect(await storage.retrieve('key2'), isNull);
      });
    });

    group('Web Platform Optimization', () {
      test('should provide web connection configuration', () {
        final config = WebConnectionOptimizer.getWebOptimizedConfig();

        expect(config, isA<Map<String, dynamic>>());
        expect(config['keepAlive'], isA<bool>());
        expect(config['timeout'], isA<int>());
        expect(config['maxConcurrentRequests'], isA<int>());
        expect(config['headers'], isA<Map<String, String>>());
      });

      test('should provide web retry configuration', () {
        final config = WebConnectionOptimizer.getRetryConfig();

        expect(config, isA<Map<String, dynamic>>());
        expect(config['maxRetries'], isA<int>());
        expect(config['retryDelay'], isA<int>());
        expect(config['exponentialBackoff'], isA<bool>());
        expect(config['retryOn'], isA<List<dynamic>>());
      });

      test('should handle web storage operations', () async {
        final storage = WebStorage.instance;

        await storage.store('web_test', 'web_value');
        final value = await storage.retrieve('web_test');
        expect(value, equals('web_value'));

        await storage.remove('web_test');
        final removed = await storage.retrieve('web_test');
        expect(removed, isNull);
      });

      test('should manage web cache correctly', () async {
        // Store data in cache
        await WebCacheManager.store('test_key', 'test_data');

        // Retrieve data
        final retrieved = await WebCacheManager.retrieve<String>('test_key');
        expect(retrieved, equals('test_data'));

        // Get cache stats
        final stats = WebCacheManager.getStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['totalEntries'], greaterThan(0));

        // Clear cache
        await WebCacheManager.clear();
        final statsAfterClear = WebCacheManager.getStats();
        expect(statsAfterClear['totalEntries'], equals(0));
      });

      test('should discover web wallets', () {
        final wallets = WebWalletDiscovery.availableWallets;
        expect(wallets, isA<List<BrowserWalletAdapter>>());
        expect(wallets, isNotEmpty);

        // Should have Phantom and Solflare
        final walletNames = wallets.map((w) => w.name).toList();
        expect(walletNames, contains('Phantom'));
        expect(walletNames, contains('Solflare'));
      });

      test('should handle web wallet operations', () async {
        final phantom = PhantomWalletAdapter();

        expect(phantom.name, equals('Phantom'));
        expect(phantom.isInstalled, isTrue); // Mock implementation
        expect(phantom.connected, isFalse);

        // Test connection
        await phantom.connect();
        expect(phantom.connected, isTrue);
        expect(phantom.publicKey, isNotNull);

        // Test disconnection
        await phantom.disconnect();
        expect(phantom.connected, isFalse);
      });

      test('should track web performance', () {
        final endpoint = 'test_endpoint';

        // Record some requests
        WebPerformanceMonitor.recordRequest(
            endpoint, const Duration(milliseconds: 100));
        WebPerformanceMonitor.recordRequest(
            endpoint, const Duration(milliseconds: 200));
        WebPerformanceMonitor.recordRequest(
            endpoint, const Duration(milliseconds: 150),
            success: false);

        // Check stats
        final avgTime = WebPerformanceMonitor.getAverageRequestTime(endpoint);
        expect(avgTime, isNotNull);
        expect(avgTime!.inMilliseconds, equals(150)); // (100 + 200 + 150) / 3

        final errorRate = WebPerformanceMonitor.getErrorRate(endpoint);
        expect(errorRate, closeTo(0.33, 0.01)); // 1 error out of 3 requests

        final stats = WebPerformanceMonitor.getPerformanceStats();
        expect(stats.containsKey(endpoint), isTrue);
        expect(stats[endpoint]!['requestCount'], equals(3));
        expect(stats[endpoint]!['errorCount'], equals(1));

        // Clear stats
        WebPerformanceMonitor.clearStats();
        final clearedStats = WebPerformanceMonitor.getPerformanceStats();
        expect(clearedStats, isEmpty);
      });
    });

    group('Mobile Platform Optimization', () {
      test('should handle mobile secure storage', () async {
        final storage = MobileSecureStorage.instance;

        await storage.store('secure_key', 'secure_value');
        final value = await storage.retrieve('secure_key');
        expect(value, equals('secure_value'));

        await storage.remove('secure_key');
        final removed = await storage.retrieve('secure_key');
        expect(removed, isNull);
      });

      test('should handle deep links correctly', () async {
        var receivedLink = false;
        DeepLinkData? receivedData;

        // Listen for deep links
        final subscription =
            MobileDeepLinkHandler.deepLinkStream.listen((data) {
          receivedLink = true;
          receivedData = data;
        });

        // Simulate incoming deep link
        const testUrl = 'solana://wallet/connect?param1=value1&param2=value2';
        MobileDeepLinkHandler.handleDeepLink(testUrl);

        // Wait for async processing
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(receivedLink, isTrue);
        expect(receivedData, isNotNull);
        expect(receivedData!.scheme, equals('solana'));
        expect(receivedData!.host, equals('wallet'));
        expect(receivedData!.isWalletLink, isTrue);
        expect(receivedData!.action, equals('connect'));
        expect(receivedData!.parameters['param1'], equals('value1'));

        subscription.cancel();
      });

      test('should generate deep links correctly', () {
        final deepLink = MobileDeepLinkHandler.generateWalletDeepLink(
          action: 'sign',
          parameters: {
            'transaction': 'abc123',
            'return_url': 'myapp://callback'
          },
        );

        expect(deepLink, startsWith('solana://wallet/sign'));
        expect(deepLink, contains('transaction=abc123'));
        expect(deepLink, contains('return_url=myapp%3A%2F%2Fcallback'));
      });

      test('should manage mobile connection health', () async {
        final connection = Connection('http://localhost:8899');
        final manager = MobileConnectionManager(connection);

        expect(manager.health, equals(ConnectionHealth.unknown));

        var healthUpdates = 0;
        final subscription = manager.healthStream.listen((_) {
          healthUpdates++;
        });

        manager.startHealthMonitoring();

        // Wait for health check
        await Future<void>.delayed(const Duration(milliseconds: 100));

        manager.stopHealthMonitoring();
        manager.dispose();
        subscription.cancel();

        // Should have received at least one health update
        expect(healthUpdates, greaterThan(0));
      });

      test('should handle mobile wallet sessions', () async {
        final session = mobile.MobileWalletSession();
        final testAddress =
            PublicKey.fromBase58('11111111111111111111111111111112');

        // Initially no session
        expect(await session.isSessionActive(), isFalse);

        // Start session
        await session.startSession(testAddress);
        expect(await session.isSessionActive(), isTrue);

        // End session
        await session.endSession();
        expect(await session.isSessionActive(), isFalse);

        session.dispose();
      });

      test('should manage background sync tasks', () async {
        final connection = Connection('http://localhost:8899');
        final wallet = await KeypairWallet.generate();
        final provider = AnchorProvider(connection, wallet);
        final backgroundSync = MobileBackgroundSync(provider);

        var taskExecuted = false;
        final task = TestBackgroundSyncTask(() {
          taskExecuted = true;
        });

        backgroundSync.addSyncTask(task);
        await backgroundSync.forceSync();

        expect(taskExecuted, isTrue);

        backgroundSync.dispose();
      });
    });

    group('Flutter Widget Integration', () {
      test('should create Solana wallet widget correctly', () {
        final widget = SolanaWalletWidget();

        expect(
            widget.connectionState, equals(WalletConnectionState.disconnected));
        expect(widget.wallet, isNull);
        expect(widget.provider, isNull);
        expect(widget.publicKey, isNull);
      });

      test('should create Solana program widget correctly', () async {
        final connection = Connection('http://localhost:8899');
        final wallet = await KeypairWallet.generate();
        final provider = AnchorProvider(connection, wallet);

        final idl = Idl.fromJson({
          'address': '11111111111111111111111111111112',
          'metadata': {'name': 'test', 'version': '1.0.0', 'spec': '0.1.0'},
          'instructions': <String>[],
          'accounts': <String>[],
          'types': <String>[],
        });

        final widget = SolanaProgramWidget(
          provider: provider,
          idl: idl,
        );

        expect(widget.state, equals(ProgramState.uninitialized));
        expect(widget.program, isNull);

        await widget.initialize();
        expect(widget.state, equals(ProgramState.ready));
        expect(widget.program, isNotNull);

        widget.dispose();
      });

      test('should create transaction widget correctly', () async {
        final connection = Connection('http://localhost:8899');
        final wallet = await KeypairWallet.generate();
        final provider = AnchorProvider(connection, wallet);

        final widget = SolanaTransactionWidget(provider: provider);

        expect(widget.state, equals(TransactionState.empty));
        expect(widget.transaction, isNull);

        await widget.initialize();

        widget.createTransaction();
        expect(widget.state, equals(TransactionState.building));
        expect(widget.transaction, isNotNull);

        widget.clearTransaction();
        expect(widget.state, equals(TransactionState.empty));
        expect(widget.transaction, isNull);

        widget.dispose();
      });

      test('should create account monitor widget correctly', () async {
        final connection = Connection('http://localhost:8899');
        final monitor = SolanaAccountMonitor(connection: connection);

        expect(monitor.monitoredAddresses, isEmpty);

        await monitor.initialize();

        final testAddress =
            PublicKey.fromBase58('11111111111111111111111111111112');
        monitor.monitorAccount(testAddress);

        expect(monitor.monitoredAddresses, contains(testAddress));

        monitor.stopMonitoring(testAddress);
        expect(monitor.monitoredAddresses, isNot(contains(testAddress)));

        monitor.dispose();
      });
    });

    group('Platform Manager Integration', () {
      test('should initialize platform manager correctly', () {
        final manager = PlatformManager.instance;

        expect(manager.configuration, isA<PlatformConfiguration>());
        expect(manager.storage, isA<PlatformStorage>());
      });

      test('should create optimized connections and providers', () async {
        final manager = PlatformManager.instance;

        final connection =
            manager.createOptimizedConnection('http://localhost:8899');
        expect(connection, isA<Connection>());

        final wallet = await KeypairWallet.generate();
        final provider = manager.createOptimizedProvider(connection, wallet);
        expect(provider, isA<AnchorProvider>());
        expect(provider.wallet, equals(wallet));
        expect(provider.connection, equals(connection));
      });

      test('should handle platform-specific features', () async {
        final manager = PlatformManager.instance;

        await manager.initializePlatformFeatures();

        // Test wallet session (mobile-specific)
        final testAddress =
            PublicKey.fromBase58('11111111111111111111111111111112');
        await manager.startWalletSession(testAddress);

        // These should work without throwing on any platform
        final isActive = await manager.isWalletSessionActive();
        expect(isActive, isA<bool>());

        await manager.endWalletSession();
      });

      test('should provide platform utilities', () {
        // Test feature support detection
        expect(PlatformUtils.isFeatureSupported(PlatformFeature.localStorage),
            isA<bool>());
        expect(
            PlatformUtils.isFeatureSupported(
                PlatformFeature.backgroundProcessing),
            isA<bool>());
        expect(PlatformUtils.isFeatureSupported(PlatformFeature.deepLinks),
            isA<bool>());
        expect(PlatformUtils.isFeatureSupported(PlatformFeature.webWallets),
            isA<bool>());

        // Test configuration recommendations
        final recommendations = PlatformUtils.getConfigurationRecommendations();
        expect(recommendations, isA<Map<String, dynamic>>());
        expect(recommendations.containsKey('platform'), isTrue);
        expect(recommendations.containsKey('connectionTimeout'), isTrue);
        expect(recommendations.containsKey('maxConnections'), isTrue);
      });

      test('should handle different platform configurations', () {
        for (final platform in PlatformType.values) {
          final config = PlatformConfiguration.forPlatform(platform);
          expect(config, isA<PlatformConfiguration>());
          expect(config.enableOptimizations, isA<bool>());
        }

        final devConfig = PlatformConfiguration.development;
        expect(devConfig.enableOptimizations, isTrue);

        final prodConfig = PlatformConfiguration.production;
        expect(prodConfig, isA<PlatformConfiguration>());
      });
    });
  });
}

/// Test implementation of BackgroundSyncTask
class TestBackgroundSyncTask implements BackgroundSyncTask {
  final VoidCallback onExecute;

  const TestBackgroundSyncTask(this.onExecute);

  @override
  String get id => 'test_task';

  @override
  Future<void> execute(AnchorProvider provider) async {
    onExecute();
  }
}
