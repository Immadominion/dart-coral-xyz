/// Provider factory for automatic provider selection and configuration
///
/// This module provides the ProviderFactory class that implements intelligent
/// provider selection based on environment and configuration, matching
/// TypeScript's provider ecosystem patterns.

library;

import 'dart:async';
import '../types/public_key.dart';
import '../types/commitment.dart';
import '../types/keypair.dart';
import '../types/transaction.dart' as transaction_types;
import 'connection.dart';
import 'wallet.dart';
import '../types/connection_config.dart';
import 'provider_interface.dart';
import 'anchor_provider.dart';

/// Factory for creating and configuring providers
///
/// This class implements the factory pattern for automatic provider detection
/// and configuration, supporting multiple provider types and environments
/// while maintaining compatibility with TypeScript's provider patterns.
class ProviderFactory {
  /// Default connection endpoints for different environments
  static const Map<String, String> defaultEndpoints = {
    'mainnet': 'https://api.mainnet-beta.solana.com',
    'testnet': 'https://api.testnet.solana.com',
    'devnet': 'https://api.devnet.solana.com',
    'localnet': 'http://127.0.0.1:8899',
  };

  /// Registry of available provider builders
  static final Map<ProviderType, ProviderBuilder> _providerBuilders = {
    ProviderType.keypair: _buildKeypairProvider,
  };

  /// Create provider based on environment and configuration
  ///
  /// This method implements intelligent provider selection matching TypeScript's
  /// behavior, automatically detecting the best provider type for the current
  /// environment and configuration.
  ///
  /// [config] - Provider creation configuration
  /// Returns configured provider instance
  static Future<ProviderInterface> createProvider(
    ProviderCreationConfig config,
  ) async {
    // Determine provider type if not specified
    final providerType = config.type ?? await _detectProviderType();

    // Get provider builder
    final builder = _providerBuilders[providerType];
    if (builder == null) {
      throw UnsupportedProviderException(
        'No provider builder registered for type: $providerType',
      );
    }

    // Build and configure provider
    final provider = await builder(config);

    // Validate provider compatibility
    await _validateProvider(provider, config);

    return provider;
  }

  /// Create provider with automatic environment detection
  ///
  /// Matches TypeScript's AnchorProvider.env() functionality by reading
  /// environment variables and configuration to create an appropriate provider.
  ///
  /// [environment] - Target environment (mainnet, testnet, devnet, localnet)
  /// [options] - Optional configuration overrides
  /// Returns configured provider for the environment
  static Future<ProviderInterface> createEnvironmentProvider({
    String environment = 'localnet',
    ProviderOptions? options,
  }) async {
    final endpoint =
        defaultEndpoints[environment] ?? defaultEndpoints['localnet']!;

    final config = ProviderCreationConfig(
      type: ProviderType.keypair,
      connectionConfig: ConnectionConfig(
        rpcUrl: endpoint,
        commitment: options?.commitment ?? CommitmentConfigs.processed,
      ),
      walletConfig: const WalletConfig(
        type: WalletType.keypair,
        autoGenerate: true,
      ),
      options: options ?? const ProviderOptions(),
    );

    return await createProvider(config);
  }

  /// Create local development provider
  ///
  /// Matches TypeScript's AnchorProvider.local() functionality for creating
  /// a provider suitable for local development and testing.
  ///
  /// [endpoint] - Local cluster endpoint (defaults to http://127.0.0.1:8899)
  /// [options] - Optional configuration overrides
  /// Returns configured local provider
  static Future<ProviderInterface> createLocalProvider({
    String? endpoint,
    ProviderOptions? options,
  }) async {
    final config = ProviderCreationConfig(
      type: ProviderType.keypair,
      connectionConfig: ConnectionConfig(
        rpcUrl: endpoint ?? defaultEndpoints['localnet']!,
        commitment: options?.commitment ?? CommitmentConfigs.processed,
      ),
      walletConfig: const WalletConfig(
        type: WalletType.keypair,
        autoGenerate: true,
      ),
      options: options ?? const ProviderOptions(),
    );

    return await createProvider(config);
  }

  /// Register custom provider builder
  ///
  /// Allows registration of custom provider implementations for extension
  /// and customization of the provider ecosystem.
  ///
  /// [type] - Provider type identifier
  /// [builder] - Provider builder function
  static void registerProviderBuilder(
    ProviderType type,
    ProviderBuilder builder,
  ) {
    _providerBuilders[type] = builder;
  }

  /// Get available provider types
  ///
  /// Returns list of currently supported provider types based on
  /// registered builders and environment capabilities.
  static List<ProviderType> getAvailableProviderTypes() {
    return _providerBuilders.keys.toList();
  }

  /// Detect optimal provider type for current environment
  static Future<ProviderType> _detectProviderType() async {
    // For now, default to keypair provider
    // Future implementations will detect mobile environments
    return ProviderType.keypair;
  }

  /// Validate provider compatibility with configuration
  static Future<void> _validateProvider(
    ProviderInterface provider,
    ProviderCreationConfig config,
  ) async {
    // Validate provider type matches requested type
    if (config.type != null && provider.providerType != config.type) {
      throw ProviderValidationException(
        'Provider type mismatch: requested ${config.type}, '
        'got ${provider.providerType}',
      );
    }

    // Validate required capabilities
    if (config.requiredCapabilities.isNotEmpty) {
      final missing =
          config.requiredCapabilities.difference(provider.config.capabilities);
      if (missing.isNotEmpty) {
        throw ProviderValidationException(
          'Provider missing required capabilities: $missing',
        );
      }
    }
  }

  /// Build keypair-based provider
  static Future<ProviderInterface> _buildKeypairProvider(
    ProviderCreationConfig config,
  ) async {
    // Create connection
    final connection = Connection.fromConfig(config.connectionConfig);

    // Create wallet
    final wallet = await _createWallet(config.walletConfig);

    // Create provider
    final provider = KeypairProvider(
      connection: connection,
      wallet: wallet,
      options: config.options.confirmOptions,
    );

    return provider;
  }

  /// Create wallet based on configuration
  static Future<Wallet> _createWallet(WalletConfig config) async {
    switch (config.type) {
      case WalletType.keypair:
        if (config.autoGenerate) {
          final keypair = await Keypair.generate();
          return KeypairWallet(keypair);
        } else if (config.keypair != null) {
          return KeypairWallet(config.keypair!);
        } else {
          throw const ProviderConfigurationException(
            'Keypair wallet requires either autoGenerate=true or explicit keypair',
          );
        }
      default:
        throw UnsupportedProviderException(
          'Wallet type not yet supported: ${config.type}',
        );
    }
  }
}

/// Provider builder function type
typedef ProviderBuilder = Future<ProviderInterface> Function(
  ProviderCreationConfig config,
);

/// Configuration for provider creation
class ProviderCreationConfig {
  /// Desired provider type (null for auto-detection)
  final ProviderType? type;

  /// Connection configuration
  final ConnectionConfig connectionConfig;

  /// Wallet configuration
  final WalletConfig walletConfig;

  /// Provider options
  final ProviderOptions options;

  /// Required provider capabilities
  final Set<ProviderCapability> requiredCapabilities;

  const ProviderCreationConfig({
    this.type,
    required this.connectionConfig,
    required this.walletConfig,
    required this.options,
    this.requiredCapabilities = const {},
  });
}

/// Connection configuration

/// Wallet configuration
class WalletConfig {
  /// Wallet type
  final WalletType type;

  /// Auto-generate keypair for keypair wallets
  final bool autoGenerate;

  /// Explicit keypair for keypair wallets
  final Keypair? keypair;

  /// Wallet-specific configuration
  final Map<String, dynamic> config;

  const WalletConfig({
    required this.type,
    this.autoGenerate = false,
    this.keypair,
    this.config = const {},
  });
}

/// Wallet type enumeration
enum WalletType {
  /// Keypair-based wallet
  keypair,

  /// Mobile wallet adapter
  mobileWallet,

  /// Hardware wallet
  hardwareWallet,
}

/// Provider options
class ProviderOptions {
  /// Default confirmation options
  final ConfirmOptions confirmOptions;

  /// Additional provider-specific options
  final Map<String, dynamic> additionalOptions;

  const ProviderOptions({
    this.confirmOptions = ConfirmOptions.defaultOptions,
    this.additionalOptions = const {},
  });

  /// Get commitment level
  CommitmentConfig? get commitment => confirmOptions.commitment;
}

/// Keypair-based provider implementation
class KeypairProvider extends BaseProvider {
  @override
  final Wallet wallet;

  KeypairProvider({
    required super.connection,
    required this.wallet,
    ConfirmOptions? options,
  }) : super(
          config: const ProviderConfig(
            type: ProviderType.keypair,
            name: 'KeypairProvider',
            version: '1.0.0',
            capabilities: {
              ProviderCapability.signTransaction,
              ProviderCapability.signAllTransactions,
              ProviderCapability.signMessage,
              ProviderCapability.simulateTransaction,
            },
          ),
        ) {
    // Mark as connected since keypair provider is always ready
    updateConnectionStatus(ProviderConnectionStatus.connected());
  }

  @override
  PublicKey? get publicKey => wallet.publicKey;

  @override
  Future<void> connect() async {
    // Keypair provider is always connected
    updateConnectionStatus(ProviderConnectionStatus.connected());
  }

  @override
  Future<String> sendAndConfirm(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    ConfirmOptions? options,
  }) async {
    // Create AnchorProvider for actual transaction handling
    final anchorProvider = AnchorProvider(
      connection,
      wallet,
      options: options ?? ConfirmOptions.defaultOptions,
    );

    return await anchorProvider.sendAndConfirm(
      transaction,
      signers: signers,
      options: options,
    );
  }

  @override
  Future<List<String>> sendAll(
    List<TransactionWithSigners> transactions, {
    ConfirmOptions? options,
  }) async {
    // Create AnchorProvider for actual transaction handling
    final anchorProvider = AnchorProvider(
      connection,
      wallet,
      options: options ?? ConfirmOptions.defaultOptions,
    );

    return await anchorProvider.sendAll(
      transactions,
      options: options,
    );
  }
}

/// Provider-related exceptions
class ProviderFactoryException implements Exception {
  final String message;
  const ProviderFactoryException(this.message);

  @override
  String toString() => 'ProviderFactoryException: $message';
}

class UnsupportedProviderException extends ProviderFactoryException {
  const UnsupportedProviderException(super.message);
}

class ProviderValidationException extends ProviderFactoryException {
  const ProviderValidationException(super.message);
}

class ProviderConfigurationException extends ProviderFactoryException {
  const ProviderConfigurationException(super.message);
}
