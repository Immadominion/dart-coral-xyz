/// Mobile/Flutter Integration Example for Coral XYZ Anchor Client
///
/// This example demonstrates how to integrate the Coral XYZ Anchor client
/// in a Flutter mobile application. It shows:
///
/// - Mobile-friendly async patterns
/// - State management with Anchor programs
/// - Error handling for mobile environments
/// - UI integration patterns
/// - Background processing considerations
/// - Platform-specific optimizations

library;

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Example Flutter state management class for Anchor integration
class SolanaWalletState {
  Keypair? _keypair;
  AnchorProvider? _provider;
  Connection? _connection;

  // Getters
  bool get isConnected => _provider != null;
  PublicKey? get publicKey => _keypair?.publicKey;
  String? get balance => _cachedBalance;

  String? _cachedBalance;

  /// Initialize wallet for mobile environment
  Future<void> initializeWallet({
    String network = 'devnet',
    Keypair? existingKeypair,
  }) async {
    try {
      // Set up connection based on network
      final String rpcUrl;
      switch (network) {
        case 'mainnet':
          rpcUrl = 'https://api.mainnet-beta.solana.com';
          break;
        case 'testnet':
          rpcUrl = 'https://api.testnet.solana.com';
          break;
        case 'devnet':
        default:
          rpcUrl = 'https://api.devnet.solana.com';
          break;
      }

      _connection = Connection(rpcUrl);

      // Use existing keypair or generate new one
      _keypair = existingKeypair ?? await Keypair.generate();

      // Create provider
      final wallet = KeypairWallet(_keypair!);
      _provider = AnchorProvider(_connection!, wallet);

      // Cache initial balance
      await _updateBalance();
    } catch (e) {
      throw SolanaWalletException('Failed to initialize wallet: $e');
    }
  }

  /// Update cached balance (call periodically or after transactions)
  Future<void> _updateBalance() async {
    if (_connection == null || _keypair == null) return;

    try {
      final lamports = await _connection!.getBalance(_keypair!.publicKey);
      _cachedBalance = '${lamports / 1000000000} SOL';
    } catch (e) {
      print('Failed to update balance: $e');
    }
  }

  /// Clean disconnect
  void disconnect() {
    _connection?.close();
    _keypair = null;
    _provider = null;
    _connection = null;
    _cachedBalance = null;
  }
}

/// Example mobile-optimized program interaction class
class MobileProgramManager {
  final AnchorProvider provider;
  final Program program;

  MobileProgramManager({
    required this.provider,
    required this.program,
  });

  /// Factory method for creating manager from IDL
  static Future<MobileProgramManager> create({
    required AnchorProvider provider,
    required Map<String, dynamic> idlJson,
  }) async {
    try {
      final idl = Idl.fromJson(idlJson);
      final program = Program(idl, provider: provider);

      return MobileProgramManager(
        provider: provider,
        program: program,
      );
    } catch (e) {
      throw SolanaWalletException('Failed to create program manager: $e');
    }
  }

  /// Mobile-optimized method calling with progress callbacks
  Future<String> callProgramMethod({
    required String methodName,
    required List<dynamic> args,
    required Map<String, PublicKey> accounts,
    void Function(String status)? onProgress,
  }) async {
    try {
      onProgress?.call('Building transaction...');

      // Get method builder
      final methodBuilder = program.methods[methodName];
      if (methodBuilder == null) {
        throw Exception('Method "$methodName" not found in program');
      }

      // Build transaction
      // ignore: unused_local_variable
      final transaction =
          methodBuilder.call(args).accounts(accounts).transaction();

      onProgress?.call('Sending transaction...');

      // Note: In a real implementation, you would need to convert
      // AnchorTransaction to the appropriate Transaction type
      // For this demo, we'll simulate the signature response
      final signature =
          'demo_signature_${DateTime.now().millisecondsSinceEpoch}';

      onProgress?.call('Transaction confirmed');

      return signature;
    } catch (e) {
      onProgress?.call('Transaction failed');
      rethrow;
    }
  }

  /// Fetch account data with caching for mobile
  Future<Map<String, dynamic>?> fetchAccountData({
    required String accountType,
    required PublicKey address,
    bool useCache = true,
  }) async {
    try {
      final accountClient = program.account[accountType];
      if (accountClient == null) {
        throw Exception('Account type "$accountType" not found');
      }

      // In a real app, you'd implement caching here
      // For now, we'll just return null to demonstrate the API
      return null;
    } catch (e) {
      print('Failed to fetch account data: $e');
      return null;
    }
  }
}

/// Example Flutter widget integration pattern
class SolanaWalletWidget {
  final SolanaWalletState _walletState = SolanaWalletState();

  /// Initialize wallet when widget is created
  Future<void> initializeForApp() async {
    try {
      await _walletState.initializeWallet(
        network: 'devnet', // Use appropriate network for your app
      );
      print('Wallet initialized: ${_walletState.publicKey}');
    } catch (e) {
      print('Wallet initialization failed: $e');
      // Handle error in UI
    }
  }

  /// Send transaction with UI feedback
  Future<void> sendTransaction({
    required String programIdString,
    required Map<String, dynamic> idlJson,
    required String methodName,
    required List<dynamic> args,
    required Map<String, PublicKey> accounts,
  }) async {
    if (!_walletState.isConnected) {
      print('Wallet not connected');
      return;
    }

    try {
      // Create program manager
      final programManager = await MobileProgramManager.create(
        provider: _walletState._provider!,
        idlJson: idlJson,
      );

      // Call method with progress updates
      final signature = await programManager.callProgramMethod(
        methodName: methodName,
        args: args,
        accounts: accounts,
        onProgress: (status) {
          print('Progress: $status');
          // Update UI with progress
        },
      );

      print('Transaction successful: $signature');

      // Update balance after transaction
      await _walletState._updateBalance();
    } catch (e) {
      print('Transaction failed: $e');
      // Show error to user
    }
  }

  /// Clean up resources
  void dispose() {
    _walletState.disconnect();
  }
}

/// Custom exception for Solana wallet operations
class SolanaWalletException implements Exception {
  final String message;

  const SolanaWalletException(this.message);

  @override
  String toString() => 'SolanaWalletException: $message';
}

/// Example usage in a Flutter app
Future<void> demonstrateMobileUsage() async {
  print('📱 Mobile/Flutter Integration Example');
  print('====================================\n');

  // 1. Initialize wallet
  print('1. Initializing mobile wallet...');
  final walletWidget = SolanaWalletWidget();

  try {
    await walletWidget.initializeForApp();
    print('   ✓ Wallet initialized successfully\n');
  } catch (e) {
    print('   ❌ Wallet initialization failed: $e\n');
    return;
  }

  // 2. Demonstrate program interaction
  print('2. Demonstrating program interaction...');

  // Example IDL for a simple program
  final exampleIdl = {
    'address': 'MobileApp11111111111111111111111111111111',
    'metadata': {
      'name': 'mobile_app_program',
      'version': '0.1.0',
      'spec': '0.1.0',
    },
    'instructions': [
      {
        'name': 'updateData',
        'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
        'accounts': [
          {
            'name': 'dataAccount',
            'writable': true,
          },
          {
            'name': 'authority',
            'signer': true,
          },
        ],
        'args': [
          {
            'name': 'newValue',
            'type': 'string',
          },
        ],
      },
    ],
    'accounts': [],
    'types': [],
  };

  try {
    final dataAccount = await Keypair.generate();

    await walletWidget.sendTransaction(
      programIdString: 'MobileApp11111111111111111111111111111111',
      idlJson: exampleIdl,
      methodName: 'updateData',
      args: ['Hello from mobile!'],
      accounts: {
        'dataAccount': dataAccount.publicKey,
        'authority': walletWidget._walletState.publicKey!,
      },
    );

    print('   ✓ Program interaction completed\n');
  } catch (e) {
    print('   ⚠️  Program interaction failed (expected for demo): $e\n');
  }

  // 3. Demonstrate best practices
  print('3. Mobile Integration Best Practices:');
  print('   • Use state management for wallet connection status');
  print('   • Implement proper error handling with user-friendly messages');
  print('   • Cache frequently accessed data to reduce RPC calls');
  print('   • Show progress indicators for long-running operations');
  print('   • Handle network connectivity changes gracefully');
  print('   • Implement secure storage for sensitive data');
  print('   • Use background processing for non-critical operations');
  print('   • Optimize for mobile data usage and battery life\n');

  // 4. Clean up
  print('4. Cleaning up resources...');
  walletWidget.dispose();
  print('   ✓ Resources cleaned up\n');

  print('✅ Mobile integration example completed!');
}

/// Entry point for the example
void main() async {
  await demonstrateMobileUsage();
}
