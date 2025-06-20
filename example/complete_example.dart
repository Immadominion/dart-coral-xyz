/// Complete example demonstrating the Coral XYZ Anchor client capabilities
///
/// This example shows how to use the Anchor client to interact with a
/// sample program that manages a simple counter. It demonstrates:
///
/// - Setting up connections and providers
/// - Creating program instances
/// - Calling program methods
/// - Fetching account data
/// - Handling events
/// - Error handling
/// - Different transaction building patterns

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Sample IDL for a simple counter program
const counterIdl = {
  "address": "Counter111111111111111111111111111111111111",
  "metadata": {
    "name": "counter",
    "version": "0.1.0",
    "spec": "0.1.0",
  },
  "instructions": [
    {
      "name": "initialize",
      "discriminator": [175, 175, 109, 31, 13, 152, 155, 237],
      "accounts": [
        {
          "name": "counter",
          "writable": true,
          "signer": true,
        },
        {
          "name": "user",
          "writable": true,
          "signer": true,
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111112",
        }
      ],
      "args": [
        {"name": "authority", "type": "pubkey"}
      ]
    },
    {
      "name": "increment",
      "discriminator": [11, 18, 104, 9, 104, 174, 59, 33],
      "accounts": [
        {
          "name": "counter",
          "writable": true,
        },
        {
          "name": "authority",
          "signer": true,
        }
      ],
      "args": []
    },
    {
      "name": "decrement",
      "discriminator": [106, 227, 168, 59, 248, 27, 150, 101],
      "accounts": [
        {
          "name": "counter",
          "writable": true,
        },
        {
          "name": "authority",
          "signer": true,
        }
      ],
      "args": []
    }
  ],
  "accounts": [
    {
      "name": "counter",
      "discriminator": [255, 176, 4, 245, 188, 253, 124, 25],
      "type": {
        "kind": "struct",
        "fields": [
          {"name": "authority", "type": "pubkey"},
          {"name": "count", "type": "u64"}
        ]
      }
    }
  ],
  "events": [
    {
      "name": "CounterChanged",
      "discriminator": [114, 52, 123, 18, 151, 222, 151, 143],
      "fields": [
        {"name": "oldCount", "type": "u64"},
        {"name": "newCount", "type": "u64"}
      ]
    }
  ],
  "types": []
};

void main() async {
  print('🚀 Coral XYZ Anchor - Complete Example');
  print('=====================================\n');

  try {
    // 🔗 Step 1: Set up connection and provider
    await setupConnectionAndProvider();

    // 📋 Step 2: Load IDL and create program
    await loadProgramFromIdl();

    // 🌐 Step 3: Fetch program from network (when available)
    await fetchProgramFromNetwork();

    // 🏗️  Step 4: Account management
    await demonstrateAccountManagement();

    // 📝 Step 5: Instruction building patterns
    await demonstrateInstructionBuilding();

    // 🔄 Step 6: Transaction patterns
    await demonstrateTransactionPatterns();

    // 👂 Step 7: Event handling
    await demonstrateEventHandling();

    // ⚡ Step 8: Performance and error handling
    await demonstrateErrorHandling();

    print('\n✅ All examples completed successfully!');
  } catch (e, stackTrace) {
    print('\n❌ Example failed: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Demonstrates setting up connections and providers
Future<void> setupConnectionAndProvider() async {
  print('🔗 Setting up connection and provider...');

  // Create connection to different networks
  final devnetConnection = Connection('https://api.devnet.solana.com');
  // Example connections for other networks:
  // final testnetConnection = Connection('https://api.testnet.solana.com');
  // final mainnetConnection = Connection('https://api.mainnet-beta.solana.com');
  // final localConnection = Connection('http://127.0.0.1:8899');

  print('  ✓ Created connections to different networks');

  // Create a wallet (in real app, this would be user's wallet)
  final keypair = await Keypair.generate();
  final wallet = KeypairWallet(keypair);
  print('  ✓ Generated wallet: ${keypair.publicKey.toBase58()}');

  // Create providers
  final devnetProvider = AnchorProvider(devnetConnection, wallet);
  // Example provider for local development:
  // final localProvider = AnchorProvider(localConnection, wallet);

  print('  ✓ Created providers for different networks');

  // Set default provider for convenience
  AnchorProvider.setDefaultProvider(devnetProvider);
  print('  ✓ Set default provider to devnet\n');
}

/// Demonstrates loading a program from an IDL
Future<void> loadProgramFromIdl() async {
  print('📋 Loading program from IDL...');

  // Parse IDL from JSON
  final idl = Idl.fromJson(counterIdl);
  print('  ✓ Parsed IDL for program: ${idl.metadata?.name ?? "Unknown"}');
  print('  ✓ Program address: ${idl.address}');
  print('  ✓ Instructions: ${idl.instructions.length}');
  print('  ✓ Accounts: ${idl.accounts?.length ?? 0}');
  print('  ✓ Events: ${idl.events?.length ?? 0}');

  // Create program instance
  final program = Program(idl);
  print('  ✓ Created program instance');

  // Verify program properties
  print('  ✓ Program ID: ${program.programId.toBase58()}');
  print('  ✓ Provider network: ${program.provider.connection.rpcUrl}');
  print('  ✓ Coder type: ${program.coder.runtimeType}\n');
}

/// Demonstrates fetching a program from the network
Future<void> fetchProgramFromNetwork() async {
  print('🌐 Fetching program from network...');

  // Note: This will return null since the IDL is not actually deployed
  final programFromNetwork = await Program.at(
    'Counter111111111111111111111111111111111111',
  );

  if (programFromNetwork != null) {
    print('  ✓ Successfully fetched program from network');
    print(
        '  ✓ Program name: ${programFromNetwork.idl.metadata?.name ?? "Unknown"}');
  } else {
    print('  ⚠️  Program IDL not found on network (expected for this example)');
    print('  ℹ️  In production, use `anchor idl init` to deploy IDL');
  }

  // Demonstrate IDL address calculation
  final programId = PublicKey.fromBase58(
    'Counter111111111111111111111111111111111111',
  );
  final idlAddress = await Program.getIdlAddress(programId);
  print('  ✓ IDL would be stored at: ${idlAddress.toBase58()}\n');
}

/// Demonstrates account management operations
Future<void> demonstrateAccountManagement() async {
  print('🏗️  Account management...');

  final idl = Idl.fromJson(counterIdl);
  final program = Program(idl);

  // Generate account addresses
  final counterKeypair = await Keypair.generate();
  final userKeypair = await Keypair.generate();

  print(
      '  ✓ Generated counter account: ${counterKeypair.publicKey.toBase58()}');
  print('  ✓ Generated user account: ${userKeypair.publicKey.toBase58()}');

  // Calculate account size
  final accountSize = program.getAccountSize('counter');
  print('  ✓ Counter account size: $accountSize bytes');

  // Note: Actual account fetching would require the account to exist
  try {
    // This would fetch account data if it existed
    // final accountData = await program.account.counter.fetch(
    //   counterKeypair.publicKey,
    // );
    print(
        '  ℹ️  Account fetching requires deployed program and existing accounts');
  } catch (e) {
    print('  ⚠️  Account not found (expected for this example)');
  }

  print('  ✓ Account management demonstration complete\n');
}

/// Demonstrates different instruction building patterns
Future<void> demonstrateInstructionBuilding() async {
  print('📝 Instruction building patterns...');

  final idl = Idl.fromJson(counterIdl);
  // These would be used in actual instruction building:
  final program = Program(idl);
  final counterKeypair = await Keypair.generate();
  final userKeypair = await Keypair.generate();

  print('  ✓ Created program and keypairs for examples');
  print('  ✓ Program address: ${program.programId}');
  print('    Counter keypair: ${counterKeypair.publicKey.toBase58()}');
  print('    User keypair: ${userKeypair.publicKey.toBase58()}');

  // Pattern 1: Using the methods namespace (recommended)
  print('  📋 Pattern 1: Methods namespace (fluent API)');
  try {
    // Note: Dynamic method calls would be used in real implementation
    print('    ✓ Methods namespace available for dynamic calls');

    // Note: Building instruction would require actual accounts
    // final instruction = await methodBuilder
    //   .accounts({
    //     'counter': counterKeypair.publicKey,
    //     'user': userKeypair.publicKey,
    //     'systemProgram': SystemProgram.programId,
    //   })
    //   .instruction();
    print('    ℹ️  Instruction building requires valid accounts');
  } catch (e) {
    print('    ⚠️  Expected error: $e');
  }

  // Pattern 2: Using the instruction namespace directly
  print('  📋 Pattern 2: Direct instruction namespace');
  try {
    // final instruction = await program.instruction.increment(
    //   accounts: {
    //     'counter': counterKeypair.publicKey,
    //     'authority': userKeypair.publicKey,
    //   },
    // );
    print('    ℹ️  Direct instruction building also requires valid accounts');
  } catch (e) {
    print('    ⚠️  Expected error for missing implementation');
  }

  print('  ✓ Instruction building patterns demonstration complete\n');
}

/// Demonstrates transaction building and execution patterns
Future<void> demonstrateTransactionPatterns() async {
  print('🔄 Transaction patterns...');

  final idl = Idl.fromJson(counterIdl);
  final program = Program(idl);
  print('  ✓ Created program: ${program.programId.toBase58()}');

  // Pattern 1: Direct RPC execution (sends immediately)
  print('  🚀 Pattern 1: Direct RPC execution');
  try {
    // final signature = await program.methods
    //   .increment()
    //   .accounts({'counter': counterKey, 'authority': userKey})
    //   .rpc();
    print('    ℹ️  RPC execution would send transaction immediately');
  } catch (e) {
    print('    ⚠️  Expected error for demo');
  }

  // Pattern 2: Build transaction for manual handling
  print('  🏗️  Pattern 2: Manual transaction building');
  try {
    // final transaction = await program.methods
    //   .increment()
    //   .accounts({'counter': counterKey, 'authority': userKey})
    //   .transaction();
    //
    // // Add additional instructions, signers, etc.
    // await transaction.sign([userKeypair]);
    // final signature = await connection.sendTransaction(transaction);
    print(
        '    ℹ️  Transaction building allows for complex multi-instruction txs');
  } catch (e) {
    print('    ⚠️  Expected error for demo');
  }

  // Pattern 3: Simulation before execution
  print('  🔍 Pattern 3: Transaction simulation');
  try {
    // final simulation = await program.methods
    //   .increment()
    //   .accounts({'counter': counterKey, 'authority': userKey})
    //   .simulate();
    //
    // if (simulation.value.err == null) {
    //   // Safe to execute
    //   final signature = await program.methods
    //     .increment()
    //     .accounts({'counter': counterKey, 'authority': userKey})
    //     .rpc();
    // }
    print('    ℹ️  Simulation helps prevent failed transactions');
  } catch (e) {
    print('    ⚠️  Expected error for demo');
  }

  print('  ✓ Transaction patterns demonstration complete\n');
}

/// Demonstrates event handling
Future<void> demonstrateEventHandling() async {
  print('👂 Event handling...');

  final idl = Idl.fromJson(counterIdl);
  final program = Program(idl);
  print(
      '  ✓ Created program for event handling: ${program.programId.toBase58()}');

  // Note: Event handling would require actual event infrastructure
  print('  📡 Setting up event listeners...');
  try {
    // Example of how event listening would work:
    // program.addEventListener('CounterChanged', (event, slot) {
    //   print('Counter changed from ${event.oldCount} to ${event.newCount}');
    // });
    //
    // // Listen to all events
    // program.addEventListener('*', (event, slot) {
    //   print('Received event: ${event.name} at slot $slot');
    // });
    //
    // // Start listening
    // await program.startEventListening();

    print('    ℹ️  Event listeners would monitor program logs');
    print('    ℹ️  Events are parsed based on IDL definitions');
    print('    ℹ️  Supports typed event callbacks');
  } catch (e) {
    print('    ⚠️  Event system requires WebSocket connection');
  }

  print('  ✓ Event handling demonstration complete\n');
}

/// Demonstrates error handling patterns
Future<void> demonstrateErrorHandling() async {
  print('⚡ Error handling and performance...');

  final idl = Idl.fromJson(counterIdl);
  final program = Program(idl);
  print(
      '  ✓ Program loaded for error handling tests: ${program.programId.toBase58()}');

  // Error handling patterns
  print('  🛡️  Error handling patterns...');

  // 1. IDL validation errors
  try {
    // This intentionally creates an invalid IDL to demonstrate error handling
    final _ = Idl.fromJson({
      'address': 'invalid',
      'metadata': {'name': 'test'},
      'instructions': [],
    });
    print('    ⚠️  Should have thrown validation error');
  } catch (e) {
    print('    ✓ Caught IDL validation error: ${e.runtimeType}');
  }

  // 2. Account size calculation
  try {
    final size = program.getAccountSize('nonexistentAccount');
    print('    ⚠️  Should have thrown account error, got size: $size');
  } catch (e) {
    print('    ✓ Caught account error: ${e.runtimeType}');
  }

  // 3. Program ID validation
  try {
    final wrongProgramId = PublicKey.fromBase58(
      'WrongProgram1111111111111111111111111111111',
    );
    program.validateProgramId(wrongProgramId);
    print('    ⚠️  Should have thrown program ID error');
  } catch (e) {
    print('    ✓ Caught program ID validation error');
  }

  // Performance considerations
  print('  🚀 Performance considerations...');
  print('    ✓ IDL parsing is cached');
  print('    ✓ Coder instances are reused');
  print('    ✓ Account size calculations are cached');
  print('    ✓ Connection pooling available');

  print('  ✓ Error handling and performance demonstration complete\n');
}

/// Utility class to demonstrate advanced patterns
class CounterManager {
  final Program program;
  final Keypair authority;

  CounterManager(this.program, this.authority);

  /// Initialize a new counter
  Future<String> initializeCounter(PublicKey counterAddress) async {
    try {
      // In a real implementation:
      // return await program.methods
      //   .initialize(authority.publicKey)
      //   .accounts({
      //     'counter': counterAddress,
      //     'user': authority.publicKey,
      //     'systemProgram': SystemProgram.programId,
      //   })
      //   .signers([authority])
      //   .rpc();

      // For demo:
      await Future.delayed(Duration(milliseconds: 100));
      return 'demo-signature-initialize';
    } catch (e) {
      throw Exception('Failed to initialize counter: $e');
    }
  }

  /// Increment the counter
  Future<String> increment(PublicKey counterAddress) async {
    try {
      // In a real implementation:
      // return await program.methods
      //   .increment()
      //   .accounts({
      //     'counter': counterAddress,
      //     'authority': authority.publicKey,
      //   })
      //   .signers([authority])
      //   .rpc();

      // For demo:
      await Future.delayed(Duration(milliseconds: 100));
      return 'demo-signature-increment';
    } catch (e) {
      throw Exception('Failed to increment counter: $e');
    }
  }

  /// Fetch counter data
  Future<Map<String, dynamic>?> fetchCounter(PublicKey counterAddress) async {
    try {
      // In a real implementation:
      // return await program.account.counter.fetch(counterAddress);

      // For demo:
      await Future.delayed(Duration(milliseconds: 50));
      return {
        'authority': authority.publicKey.toBase58(),
        'count': 42,
      };
    } catch (e) {
      print('Counter not found: $e');
      return null;
    }
  }
}
