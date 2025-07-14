/// Tests for provider interface and factory system
///
/// This test suite validates the provider abstraction, factory patterns,
/// and provider lifecycle management to ensure TypeScript compatibility.
library;

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/src/provider/provider_interface.dart';
import 'package:coral_xyz_anchor/src/provider/provider_factory.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/types/connection_config.dart';

void main() {
  group('ProviderInterface', () {
    test('should define unified provider interface', () {
      // Verify interface exists and has required methods
      expect(ProviderInterface, isNotNull);

      // Interface defines abstract contract - testing concrete implementations
    });

    test('should support provider configuration', () {
      final config = const ProviderConfig(
        type: ProviderType.keypair,
        name: 'TestProvider',
        version: '1.0.0',
        capabilities: {
          ProviderCapability.signTransaction,
          ProviderCapability.simulateTransaction,
        },
      );

      expect(config.type, equals(ProviderType.keypair));
      expect(config.name, equals('TestProvider'));
      expect(config.version, equals('1.0.0'));
      expect(config.capabilities.length, equals(2));
      expect(
        config.capabilities.contains(ProviderCapability.signTransaction),
        isTrue,
      );
    });

    test('should support provider connection status', () {
      final connectedStatus = ProviderConnectionStatus.connected(
        metadata: {'timestamp': DateTime.now().toIso8601String()},
      );
      final disconnectedStatus = ProviderConnectionStatus.disconnected(
        error: Exception('Connection failed'),
        metadata: {'reason': 'network_error'},
      );

      expect(connectedStatus.isConnected, isTrue);
      expect(connectedStatus.error, isNull);
      expect(connectedStatus.metadata.isNotEmpty, isTrue);

      expect(disconnectedStatus.isConnected, isFalse);
      expect(disconnectedStatus.error, isNotNull);
      expect(disconnectedStatus.metadata['reason'], equals('network_error'));
    });

    test('should support provider capability checking', () {
      final capabilities = <ProviderCapability>{
        ProviderCapability.signTransaction,
        ProviderCapability.signAllTransactions,
        ProviderCapability.signMessage,
        ProviderCapability.simulateTransaction,
      };

      expect(capabilities.contains(ProviderCapability.signTransaction), isTrue);
      expect(
          capabilities.contains(ProviderCapability.hardwareSecurity), isFalse,);
      expect(capabilities.length, equals(4));
    });
  });

  group('ProviderFactory', () {
    test('should support environment provider creation', () async {
      final provider = await ProviderFactory.createEnvironmentProvider(
        options: const ProviderOptions(),
      );

      expect(provider, isNotNull);
      expect(provider.providerType, equals(ProviderType.keypair));
      expect(provider.connection, isNotNull);
      expect(provider.wallet, isNotNull);
      expect(provider.publicKey, isNotNull);
    });

    test('should support local provider creation', () async {
      final provider = await ProviderFactory.createLocalProvider(
        endpoint: 'http://127.0.0.1:8899',
        options: const ProviderOptions(),
      );

      expect(provider, isNotNull);
      expect(provider.providerType, equals(ProviderType.keypair));
      expect(provider.isConnected, isTrue);
      expect(provider.config.type, equals(ProviderType.keypair));
    });

    test('should support different endpoint environments', () async {
      final localProvider = await ProviderFactory.createEnvironmentProvider(
        
      );
      final devnetProvider = await ProviderFactory.createEnvironmentProvider(
        environment: 'devnet',
      );

      expect(localProvider.connection, isNotNull);
      expect(devnetProvider.connection, isNotNull);
      expect(localProvider.providerType, equals(ProviderType.keypair));
      expect(devnetProvider.providerType, equals(ProviderType.keypair));
    });

    test('should support custom provider configuration', () async {
      final config = const ProviderCreationConfig(
        type: ProviderType.keypair,
        connectionConfig: ConnectionConfig(
          rpcUrl: 'http://127.0.0.1:8899',
          commitment: CommitmentConfigs.confirmed,
        ),
        walletConfig: WalletConfig(
          type: WalletType.keypair,
          autoGenerate: true,
        ),
        options: ProviderOptions(),
      );

      final provider = await ProviderFactory.createProvider(config);

      expect(provider, isNotNull);
      expect(provider.providerType, equals(ProviderType.keypair));
      expect(provider.isConnected, isTrue);
    });

    test('should validate provider requirements', () async {
      final config = const ProviderCreationConfig(
        type: ProviderType.keypair,
        connectionConfig: ConnectionConfig(
          rpcUrl: 'http://127.0.0.1:8899',
        ),
        walletConfig: WalletConfig(
          type: WalletType.keypair,
          autoGenerate: true,
        ),
        options: ProviderOptions(),
        requiredCapabilities: {
          ProviderCapability.signTransaction,
          ProviderCapability.simulateTransaction,
        },
      );

      final provider = await ProviderFactory.createProvider(config);

      expect(
          provider.config.capabilities.contains(
            ProviderCapability.signTransaction,
          ),
          isTrue,);
      expect(
          provider.config.capabilities.contains(
            ProviderCapability.simulateTransaction,
          ),
          isTrue,);
    });

    test('should throw on missing capabilities', () async {
      final config = const ProviderCreationConfig(
        type: ProviderType.keypair,
        connectionConfig: ConnectionConfig(
          rpcUrl: 'http://127.0.0.1:8899',
        ),
        walletConfig: WalletConfig(
          type: WalletType.keypair,
          autoGenerate: true,
        ),
        options: ProviderOptions(),
        requiredCapabilities: {
          ProviderCapability
              .hardwareSecurity, // Not supported by keypair provider
        },
      );

      expect(
        () async => ProviderFactory.createProvider(config),
        throwsA(isA<ProviderValidationException>()),
      );
    });

    test('should list available provider types', () {
      final availableTypes = ProviderFactory.getAvailableProviderTypes();

      expect(availableTypes, isNotEmpty);
      expect(availableTypes.contains(ProviderType.keypair), isTrue);
    });

    test('should support custom provider builder registration', () {
      // Mock builder function
      Future<ProviderInterface> customBuilder(
        ProviderCreationConfig config,
      ) async {
        final connection = Connection(config.connectionConfig.rpcUrl);
        final wallet = await KeypairWallet.generate();
        return KeypairProvider(connection: connection, wallet: wallet);
      }

      ProviderFactory.registerProviderBuilder(
        ProviderType.custom,
        customBuilder,
      );

      final availableTypes = ProviderFactory.getAvailableProviderTypes();
      expect(availableTypes.contains(ProviderType.custom), isTrue);
    });
  });

  group('KeypairProvider', () {
    late KeypairProvider provider;
    late Connection connection;
    late Wallet wallet;

    setUp(() async {
      connection = Connection('http://127.0.0.1:8899');
      wallet = await KeypairWallet.generate();
      provider = KeypairProvider(connection: connection, wallet: wallet);
    });

    test('should be immediately connected', () {
      expect(provider.isConnected, isTrue);
      expect(provider.providerType, equals(ProviderType.keypair));
      expect(provider.publicKey, isNotNull);
      expect(provider.wallet, equals(wallet));
    });

    test('should support connection status stream', () async {
      bool receivedStatus = false;

      provider.connectionStatus.listen((status) {
        receivedStatus = true;
        expect(status.isConnected, isTrue);
      });

      // Connect should emit status
      await provider.connect();

      // Give time for stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(receivedStatus, isTrue);
    });

    test('should handle disconnect properly', () async {
      await provider.disconnect();
      // After disconnect, stream should be closed
    });

    test('should support simulation with base implementation', () async {
      final transaction = Transaction(instructions: []);
      final result = await provider.simulate(transaction);

      expect(result, isNotNull);
      expect(result.success, isTrue);
      expect(result.logs.isNotEmpty, isTrue);
      expect(result.logs.first.contains('not yet implemented'), isTrue);
    });

    test('should have expected capabilities', () {
      final capabilities = provider.config.capabilities;

      expect(capabilities.contains(ProviderCapability.signTransaction), isTrue);
      expect(capabilities.contains(ProviderCapability.signAllTransactions),
          isTrue,);
      expect(capabilities.contains(ProviderCapability.signMessage), isTrue);
      expect(capabilities.contains(ProviderCapability.simulateTransaction),
          isTrue,);
      expect(
          capabilities.contains(ProviderCapability.hardwareSecurity), isFalse,);
    });
  });

  group('ProviderConfiguration', () {
    test('should support connection configuration', () {
      final config = const ConnectionConfig(
        rpcUrl: 'https://api.mainnet-beta.solana.com',
      );

      expect(config.rpcUrl, equals('https://api.mainnet-beta.solana.com'));
      expect(config.commitment, equals(CommitmentConfigs.finalized));
    });

    test('should support wallet configuration', () {
      final walletConfig = const WalletConfig(
        type: WalletType.keypair,
        autoGenerate: true,
        config: {'test': 'value'},
      );

      expect(walletConfig.type, equals(WalletType.keypair));
      expect(walletConfig.autoGenerate, isTrue);
      expect(walletConfig.config['test'], equals('value'));
    });

    test('should support provider options', () {
      final options = const ProviderOptions(
        confirmOptions: ConfirmOptions(
          commitment: CommitmentConfigs.confirmed,
          skipPreflight: true,
        ),
        additionalOptions: {'timeout': 30000},
      );

      expect(options.commitment, equals(CommitmentConfigs.confirmed));
      expect(options.confirmOptions.skipPreflight, isTrue);
      expect(options.additionalOptions['timeout'], equals(30000));
    });
  });

  group('ProviderExceptions', () {
    test('should throw unsupported provider exception', () {
      expect(
        () => throw const UnsupportedProviderException('Test message'),
        throwsA(isA<UnsupportedProviderException>()),
      );
    });

    test('should throw provider validation exception', () {
      expect(
        () => throw const ProviderValidationException('Validation failed'),
        throwsA(isA<ProviderValidationException>()),
      );
    });

    test('should throw provider configuration exception', () {
      expect(
        () => throw const ProviderConfigurationException('Config error'),
        throwsA(isA<ProviderConfigurationException>()),
      );
    });

    test('should format exception messages correctly', () {
      final exception = const UnsupportedProviderException('Test message');
      expect(exception.toString(), contains('ProviderFactoryException'));
      expect(exception.toString(), contains('Test message'));
    });
  });

  group('Provider Integration', () {
    test('should integrate with existing anchor provider', () async {
      final provider = await ProviderFactory.createLocalProvider();

      // Should be compatible with existing systems
      expect(provider.connection, isNotNull);
      expect(provider.wallet, isNotNull);
      expect(provider.publicKey, isNotNull);
    });

    test('should maintain TypeScript compatibility', () async {
      final provider = await ProviderFactory.createEnvironmentProvider();

      // Check interface compatibility with TypeScript patterns
      expect(provider.connection, isNotNull);
      expect(provider.wallet, isNotNull);
      expect(provider.publicKey, isNotNull);
      expect(provider.isConnected, isTrue);
    });

    test('should support provider hot-swapping', () async {
      final provider1 = await ProviderFactory.createLocalProvider(
        endpoint: 'http://127.0.0.1:8899',
      );
      final provider2 = await ProviderFactory.createLocalProvider(
        endpoint: 'http://127.0.0.1:8900',
      );

      expect(provider1.connection, isNotNull);
      expect(provider2.connection, isNotNull);
      expect(provider1.publicKey, isNotNull);
      expect(provider2.publicKey, isNotNull);

      // Providers should be independent
      expect(provider1.publicKey, isNot(equals(provider2.publicKey)));
    });
  });
}
