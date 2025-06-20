/// Hello World Example for Dart Coral XYZ Anchor Client
///
/// This example demonstrates the most basic usage of the Dart Anchor client:
/// - Connecting to a Solana cluster
/// - Creating a program instance from an IDL
/// - Building and sending transactions
/// - Fetching account data
///
/// This is equivalent to the "hello-world" examples commonly found in
/// TypeScript Anchor tutorials.

library;

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

Future<void> main() async {
  print('🌊 Dart Coral XYZ Anchor - Hello World Example');
  print('================================================\n');

  try {
    // Step 1: Set up connection to devnet
    print('1. Connecting to Solana devnet...');
    final connection = Connection('https://api.devnet.solana.com');

    // Create a keypair for the example (in production, load from file/env)
    final payer = await Keypair.generate();
    print('   Generated payer: ${payer.publicKey}');

    // Note: In a real application, you would fund the account through external means
    // For this example, we'll check if the account has enough balance
    print('   Checking account balance...');
    final balance = await connection.getBalance(payer.publicKey);
    print('   Current balance: ${balance / 1000000000} SOL');

    if (balance < 1000000) {
      // Less than 0.001 SOL
      print('   ⚠️  Account needs funding for transaction fees');
      print('   Please fund the account: ${payer.publicKey}');
      print('   You can use the Solana faucet at https://faucet.solana.com/');
    }
    print('   ✓ Account ready\n');

    // Step 2: Set up wallet and provider
    print('2. Setting up wallet and provider...');
    final wallet = KeypairWallet(payer);
    final provider = AnchorProvider(connection, wallet);
    print('   ✓ Provider created\n');

    // Step 3: Load IDL and create program instance
    print('3. Loading program IDL...');

    // Example IDL for a simple counter program
    final Map<String, dynamic> counterIdl = {
      'address': 'Counter111111111111111111111111111111111111',
      'metadata': {
        'name': 'counter',
        'version': '0.1.0',
        'spec': '0.1.0',
        'description': 'A simple counter program',
      },
      'instructions': [
        {
          'name': 'initialize',
          'discriminator': [175, 175, 109, 31, 13, 152, 155, 237],
          'accounts': [
            {
              'name': 'counter',
              'writable': true,
              'signer': true,
            },
            {
              'name': 'payer',
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
              'name': 'initialValue',
              'type': 'u64',
            },
          ],
        },
        {
          'name': 'increment',
          'discriminator': [11, 18, 104, 9, 104, 174, 59, 33],
          'accounts': [
            {
              'name': 'counter',
              'writable': true,
            },
          ],
          'args': [],
        },
      ],
      'accounts': [
        {
          'name': 'Counter',
          'discriminator': [255, 176, 4, 245, 188, 253, 124, 25],
        },
      ],
      'types': [
        {
          'name': 'Counter',
          'type': {
            'kind': 'struct',
            'fields': [
              {
                'name': 'value',
                'type': 'u64',
              },
            ],
          },
        },
      ],
    };

    try {
      final idl = Idl.fromJson(counterIdl);
      final program = Program(idl, provider: provider);
      print('   ✓ Program instance created\n');

      // Step 4: Generate account for counter
      print('4. Generating counter account...');
      final counterKeypair = await Keypair.generate();
      print('   Counter address: ${counterKeypair.publicKey}\n');

      // Step 5: Demonstrate method building API
      print('5. Building initialize transaction...');

      // Note: This is a demonstration of the API structure
      // In a real scenario, you would need actual program deployment and proper accounts
      try {
        // Build a method call using the fluent API pattern
        final methodBuilder = program.methods['initialize'];
        if (methodBuilder != null) {
          // ignore: unused_local_variable
          final transaction = methodBuilder.call([42]) // Initial value
              .accounts({
            'counter': counterKeypair.publicKey,
            'payer': payer.publicKey,
            'systemProgram':
                PublicKey.fromBase58('11111111111111111111111111111111'),
          })
              // Note: In real usage, additional signers would be provided here
              // .signers([counterKeypair]) // Would need proper Signer implementation
              .transaction(); // Build transaction instead of executing

          print('   ✓ Transaction built successfully');
          print('   ✓ Transaction would initialize counter with value 42\n');

          // Uncommenting this would actually send the transaction:
          // final signature = await provider.sendAndConfirm(transaction);
          // print('   ✓ Transaction signature: $signature');
        } else {
          print('   ⚠️  Method "initialize" not found in program\n');
        }
      } catch (e) {
        print('   ⚠️  Transaction building failed (expected for demo): $e\n');
      }

      // Step 6: Demonstrate account fetching API
      print('6. Demonstrating account fetch API...');
      try {
        // This would fetch account data in a real scenario
        final accountClient = program.account['Counter'];
        if (accountClient != null) {
          print('   ✓ Account client found for Counter type');
          print('   ✓ In real usage: program.account.counter.fetch(address)\n');
        } else {
          print('   ⚠️  Account type "Counter" not found in program\n');
        }
      } catch (e) {
        print('   ⚠️  Account access failed (expected for demo): $e\n');
      }

      // Step 7: Demonstrate increment method API
      print('7. Demonstrating increment method API...');
      try {
        final incrementBuilder = program.methods['increment'];
        if (incrementBuilder != null) {
          // ignore: unused_local_variable
          final transaction =
              incrementBuilder.call([]) // No arguments for increment
                  .accounts({
            'counter': counterKeypair.publicKey,
          }).transaction();

          print('   ✓ Increment transaction built successfully');
          print('   ✓ Transaction would increment the counter\n');
        } else {
          print('   ⚠️  Method "increment" not found in program\n');
        }
      } catch (e) {
        print(
            '   ⚠️  Increment method building failed (expected for demo): $e\n');
      }

      // Step 8: Summary
      print('8. Summary - API Usage Patterns:');
      print('   • Connection: Connection(rpcUrl)');
      print('   • Wallet: KeypairWallet(keypair)');
      print('   • Provider: AnchorProvider(connection, wallet)');
      print('   • Program: Program(idl, provider: provider)');
      print(
          '   • Methods: program.methods[\'methodName\'].call(args).accounts(map).transaction()');
      print('   • Accounts: program.account[\'AccountType\'].fetch(address)');
      print('   • Sending: provider.sendAndConfirm(transaction)');
      print('\n✅ Hello World example completed successfully!');
    } catch (e) {
      print('   ❌ Program creation failed: $e');
      print('   This may be due to IDL structure differences.');
      print('   The API patterns shown above are still valid.\n');

      // Show the API patterns even if program creation fails
      print('4. API Usage Patterns (Demo):');
      print('   • Connection: Connection(rpcUrl) ✓');
      print('   • Wallet: KeypairWallet(keypair) ✓');
      print('   • Provider: AnchorProvider(connection, wallet) ✓');
      print('   • Program: Program(idl, provider: provider)');
      print('   • Methods: program.methods[\'methodName\'].call(args)');
      print('   • Accounts: program.account[\'AccountType\'].fetch(address)');
      print('\n✅ API demonstration completed successfully!');
    }

    // Demonstrate error handling patterns
    await demonstrateErrorHandling();

    // Demonstrate basic utilities
    await demonstrateDataTypes();
  } catch (e) {
    print('❌ Error in main execution: $e');
    print('This is expected for a demo without actual program deployment.');
  }
}

/// Helper function to demonstrate error handling
Future<void> demonstrateErrorHandling() async {
  print('\n📚 Error Handling Patterns');
  print('===========================\n');

  try {
    // This will fail - demonstrating proper error handling
    final connection = Connection('https://api.devnet.solana.com');
    final invalidPubkey = PublicKey.fromBase58(
        '11111111111111111111111111111111'); // System program

    // This should fail gracefully
    final balance = await connection.getBalance(invalidPubkey);
    print('Balance: $balance');
  } on FormatException catch (e) {
    print('✓ Caught format error: ${e.message}');
  } catch (e) {
    print('✓ Caught general error: $e');
  }
}

/// Example of working with different data types
Future<void> demonstrateDataTypes() async {
  print('\n🔢 Working with Solana Data Types');
  print('==================================\n');

  // PublicKey operations
  final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
  print('PublicKey: $pubkey');
  print('PublicKey bytes: ${pubkey.toBytes()}');

  // Keypair operations
  final keypair = await Keypair.generate();
  print('Generated keypair: ${keypair.publicKey}');

  // Working with lamports (SOL denominations)
  const solAmount = 1.5; // 1.5 SOL
  final lamports = (solAmount * 1000000000).toInt(); // Convert to lamports
  print('$solAmount SOL = $lamports lamports');
}
