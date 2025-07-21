/// Basic usage example showing the core features of Coral XYZ Anchor client
///
/// This example demonstrates the essential components and workflows for
/// interacting with Anchor programs using the Dart client library.
library;

import 'dart:convert';
import 'package:coral_xyz/coral_xyz_anchor.dart';

void main() async {
  print('🌊 Coral XYZ Anchor - Basic Usage Example');
  print('==========================================\n');

  try {
    // Core Components Demonstration
    await demonstrateConnection();
    await demonstrateWalletAndKeypair();
    await demonstrateProviderSetup();
    await demonstrateIdlHandling();
    await demonstrateProgramCreation();
    await demonstrateUtilities();

    print('✅ Basic usage example completed successfully!');
  } catch (error) {
    print('❌ Error in basic usage example: $error');
  }
}

/// Demonstrate connection setup
Future<void> demonstrateConnection() async {
  print('📡 1. Connection Management');
  print('   ========================');

  // Connect to different networks
  final devnetConnection = Connection('https://api.devnet.solana.com');
  print('   ✓ Created devnet connection: ${devnetConnection.rpcUrl}');

  final mainnetConnection = Connection('https://api.mainnet-beta.solana.com');
  print('   ✓ Created mainnet connection: ${mainnetConnection.rpcUrl}');

  final localConnection = Connection('http://127.0.0.1:8899');
  print('   ✓ Created local connection: ${localConnection.rpcUrl}');

  // Example of checking connection health (would work with actual RPC)
  try {
    final healthy = await devnetConnection.checkHealth();
    print('   ✓ Connection health check: $healthy');
  } catch (e) {
    print('   ⚠️  Health check skipped (demo mode): $e');
  }

  print('');
}

/// Demonstrate wallet and keypair operations
Future<void> demonstrateWalletAndKeypair() async {
  print('🔐 2. Wallet and Keypair Management');
  print('   ================================');

  // Generate new keypairs
  final keypair1 = await Keypair.generate();
  print('   ✓ Generated keypair 1: ${keypair1.publicKey}');

  final keypair2 = await Keypair.generate();
  print('   ✓ Generated keypair 2: ${keypair2.publicKey}');

  // Create wallets from keypairs
  final wallet1 = KeypairWallet(keypair1);
  print('   ✓ Created wallet from keypair 1');

  final wallet2 = KeypairWallet(keypair2);
  print('   ✓ Created wallet from keypair 2');

  // Demonstrate wallet API
  print('   ✓ Wallet 1 public key: ${wallet1.publicKey}');
  print('   ✓ Wallet 2 public key: ${wallet2.publicKey}');

  print('');
}

/// Demonstrate provider setup patterns
Future<void> demonstrateProviderSetup() async {
  print('🏗️  3. Provider Setup');
  print('   =================');

  final connection = Connection('https://api.devnet.solana.com');
  final keypair = await Keypair.generate();
  final wallet = KeypairWallet(keypair);

  // Create provider
  final provider = AnchorProvider(connection, wallet);
  print('   ✓ Created AnchorProvider');
  print('   ✓ Provider connection: ${provider.connection.rpcUrl}');
  print('   ✓ Provider wallet: ${provider.wallet?.publicKey}');

  // Demonstrate provider options
  final customOptions = const ConfirmOptions(
    commitment: CommitmentConfigs.confirmed,
    maxRetries: 3,
  );

  final customProvider =
      AnchorProvider(connection, wallet, options: customOptions);
  print('   ✓ Created provider with custom options');
  print('   ✓ Commitment level: ${customProvider.options.commitment}');

  print('');
}

/// Demonstrate IDL handling
Future<void> demonstrateIdlHandling() async {
  print('📄 4. IDL (Interface Definition Language)');
  print('   ======================================');

  // Example IDL structure
  final exampleIdl = {
    'address': 'ExampleProgram1111111111111111111111111111',
    'metadata': {
      'name': 'example_program',
      'version': '0.1.0',
      'spec': '0.1.0',
      'description': 'An example Anchor program',
    },
    'instructions': [
      {
        'name': 'initialize',
        'discriminator': [175, 175, 109, 31, 13, 152, 155, 237],
        'accounts': [
          {
            'name': 'user',
            'writable': true,
            'signer': true,
          },
          {
            'name': 'systemProgram',
            'address': '11111111111111111111111111111111',
          },
        ],
        'args': [
          {
            'name': 'data',
            'type': 'string',
          },
        ],
      },
    ],
    'accounts': [
      {
        'name': 'UserAccount',
        'discriminator': [159, 117, 95, 227, 239, 151, 58, 236],
        'type': {
          'kind': 'struct',
          'fields': [],
        },
      },
    ],
    'types': [
      {
        'name': 'UserAccount',
        'type': {
          'kind': 'struct',
          'fields': [
            {
              'name': 'data',
              'type': 'string',
            },
            {
              'name': 'authority',
              'type': 'publicKey',
            },
          ],
        },
      },
    ],
  };

  // Parse IDL by encoding/decoding to ensure correct Map<String, dynamic>
  final idlJson = jsonDecode(jsonEncode(exampleIdl)) as Map<String, dynamic>;
  final idl = Idl.fromJson(idlJson);
  print('   ✓ Parsed IDL successfully');
  print('   ✓ Program name: ${idl.metadata?.name ?? "Unknown"}');
  print('   ✓ Program version: ${idl.metadata?.version ?? "Unknown"}');
  print('   ✓ Instructions count: ${idl.instructions.length}');
  print('   ✓ Account types count: ${idl.accounts?.length ?? 0}');
  print('   ✓ Custom types count: ${idl.types?.length ?? 0}');

  print('');
}

/// Demonstrate program creation and usage
Future<void> demonstrateProgramCreation() async {
  print('🚀 5. Program Creation and Usage');
  print('   ==============================');

  // Setup
  final connection = Connection('https://api.devnet.solana.com');
  final keypair = await Keypair.generate();
  final wallet = KeypairWallet(keypair);
  final provider = AnchorProvider(connection, wallet);

  // Create a minimal IDL for demonstration
  final idl = Idl.fromJson({
    'address': 'ExampleProgram1111111111111111111111111111',
    'metadata': {
      'name': 'demo_program',
      'version': '0.1.0',
      'spec': '0.1.0',
    },
    'instructions': [
      {
        'name': 'greet',
        'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
        'accounts': [],
        'args': [
          {
            'name': 'message',
            'type': 'string',
          },
        ],
      },
    ],
    'accounts': [],
    'types': [],
  });

  // Create program instance
  final program = Program(idl, provider: provider);
  print('   ✓ Created Program instance');
  print('   ✓ Program ID: ${program.programId}');
  print('   ✓ Program IDL name: ${program.idl.metadata?.name ?? "Unknown"}');

  // Demonstrate method access
  final greetMethod = program.methods['greet'];
  if (greetMethod != null) {
    print('   ✓ Found "greet" method in program');
    print('   ✓ Method usage: program.methods["greet"].call(["Hello World!"])');
  }

  // Demonstrate account access
  print('   ✓ Account namespace available: program.account');
  print('   ✓ Available methods: ${program.methods.names.toList()}');

  print('');
}

/// Demonstrate utility functions
Future<void> demonstrateUtilities() async {
  print('🛠️  6. Utility Functions');
  print('   ====================');

  // Public key operations
  final systemProgramId =
      PublicKey.fromBase58('11111111111111111111111111111111');
  print('   ✓ System Program ID: $systemProgramId');

  // Keypair operations
  final keypair = await Keypair.generate();
  print('   ✓ Generated keypair: ${keypair.publicKey}');

  // Base58 encoding/decoding
  final encoded = keypair.publicKey.toBase58();
  final decoded = PublicKey.fromBase58(encoded);
  print('   ✓ Base58 round trip: ${decoded == keypair.publicKey}');

  // Connection utilities
  final connection = Connection('https://api.devnet.solana.com');
  print('   ✓ Connection URL: ${connection.rpcUrl}');
  print('   ✓ Default commitment: ${connection.commitment}');

  print('');
}
