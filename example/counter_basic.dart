/// Counter Basic Example - TypeScript Anchor Tutorial Equivalent
///
/// This example demonstrates the most fundamental Anchor program interaction:
/// a simple counter that can be initialized and incremented.
///
/// This mirrors the "basic-1" tutorial from the TypeScript Anchor documentation,
/// providing exact feature parity for Dart developers.
///
/// Key concepts demonstrated:
/// - IDL loading and parsing
/// - Connection and provider setup
/// - Program ID handling
/// - Account generation
/// - Transaction building patterns
library;

import 'dart:typed_data';
import 'package:coral_xyz/coral_xyz.dart';

Future<void> main() async {
  print('🧮 Counter Basic Example');
  print('========================\n');

  try {
    // Step 1: Setup connection (same as TypeScript anchor.setProvider())
    print('1. Setting up connection and provider...');
    final connection = Connection('https://api.devnet.solana.com');
    final keypair = await Keypair.fromSecretKeyAsync(
      Uint8List.fromList(List.filled(32, 1)),
    );
    final wallet = await KeypairWallet.fromCustomKeypairAsync(
      keypair,
    ); // Use bridge method
    final provider = AnchorProvider(connection, wallet);
    print('   ✓ Connection: ${connection.rpcUrl}');
    print('   ✓ Wallet: ${wallet.publicKey}');

    // Step 2: Define program ID
    print('\\n2. Setting up program...');
    final programId = PublicKey.fromBase58(
      'Counter111111111111111111111111111111111111',
    );
    print('   Program ID: $programId');

    // Step 3: Generate counter account keypair
    print('\\n3. Generating counter account...');
    final counterKeypair = await Keypair.generate();
    print('   Counter account: ${counterKeypair.publicKey}');

    // Step 4: Create sample IDL
    print('\\n4. Loading program IDL...');
    final counterIdl = createCounterIdl();
    print(
      '   ✓ IDL loaded with ${counterIdl.instructions.length} instructions',
    );
    print(
      '   Instructions: ${counterIdl.instructions.map((IdlInstruction i) => i.name).join(', ')}',
    );

    // Step 5: Demonstrate account creation parameters and initialize RPC
    print('\n5. Building initialize instruction and calling RPC...');
    final initAccounts = {
      'counter': counterKeypair.publicKey,
      'user': provider.wallet!.publicKey,
      'systemProgram': SystemProgram.programId,
    };
    print('   ✓ Initialize accounts configured:');
    initAccounts.forEach((name, pubkey) {
      print('     $name: $pubkey');
    });
    // Create program instance (use withProgramId when passing programId)
    final program = Program.withProgramId(
      counterIdl,
      programId,
      provider: provider,
    );
    print('   ✓ Program created with ID: $programId');
    // Call initialize RPC (demo mode)
    try {
      final sig1 = await program.methods['initialize']()
          .accounts(initAccounts)
          .signers([counterKeypair]).rpc();
      print('   ✓ initialize RPC signature: $sig1');
    } catch (e) {
      print('   ⚠ initialize RPC skipped (demo): $e');
    }

    // Step 6: Demonstrate increment instruction and call RPC
    print('\n6. Building increment instruction and calling RPC...');
    final incrementAccounts = {'counter': counterKeypair.publicKey};
    print('   ✓ Increment accounts configured:');
    incrementAccounts.forEach((name, pubkey) {
      print('     $name: $pubkey');
    });
    // Call increment RPC (demo mode)
    try {
      final sig2 = await program.methods['increment']()
          .accounts(incrementAccounts)
          .rpc();
      print('   ✓ increment RPC signature: $sig2');
    } catch (e) {
      print('   ⚠ increment RPC skipped (demo): $e');
    }

    // Step 7: Fetch and verify account data
    print('\n7. Fetching counter account data...');
    try {
      final counterData = await program.account.Counter.fetch(
        counterKeypair.publicKey,
      );
      print('   ✓ Counter value: ${counterData.count}');
    } catch (e) {
      print('   ⚠ Fetch skipped (demo): $e');
    }
    // Step 8: Show TypeScript equivalent patterns
    print('\\n7. TypeScript Equivalent Patterns:');
    print('   TypeScript: const program = anchor.workspace.Counter;');
    print('   Dart:       final program = Program(idl, provider);');
    print('');
    print(
      '   TypeScript: await program.methods.initialize().accounts({...}).rpc();',
    );
    print(
      '   Dart:       await program.methods.initialize().accounts({...}).rpc();',
    );
    print('');
    print(
      '   TypeScript: const counter = await program.account.counter.fetch(pubkey);',
    );
    print(
      '   Dart:       final counter = await program.account.counter.fetch(pubkey);',
    );

    print('\\n✅ Counter basic example completed!');
    print(
      '\\n📚 This example shows the core patterns for Anchor program interaction.',
    );
    print('   In a real application, you would:');
    print('   - Deploy the counter program to devnet/mainnet');
    print('   - Fund your wallet with SOL');
    print('   - Execute the transactions on-chain');
  } catch (error) {
    print('❌ Error in counter example: $error');
    rethrow;
  }
}

/// Create a sample counter IDL for demonstration
Idl createCounterIdl() {
  return const Idl(
    address: 'Counter111111111111111111111111111111111111',
    metadata: IdlMetadata(name: 'counter', version: '0.1.0', spec: '0.1.0'),
    instructions: [
      IdlInstruction(
        name: 'initialize',
        discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
        accounts: [
          IdlInstructionAccount(name: 'counter', writable: true, signer: true),
          IdlInstructionAccount(name: 'user', writable: true, signer: true),
          IdlInstructionAccount(
            name: 'systemProgram',
            address: '11111111111111111111111111111112',
          ),
        ],
        args: [],
      ),
      IdlInstruction(
        name: 'increment',
        discriminator: [11, 18, 104, 9, 104, 174, 59, 33],
        accounts: [IdlInstructionAccount(name: 'counter', writable: true)],
        args: [],
      ),
    ],
    accounts: [
      IdlAccount(
        name: 'Counter',
        discriminator: [255, 176, 4, 245, 188, 253, 124, 25],
        type: IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(
              name: 'count',
              type: IdlType(kind: 'u64'),
            ),
          ],
        ),
      ),
    ],
    types: [
      IdlTypeDef(
        name: 'Counter',
        type: IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(
              name: 'count',
              type: IdlType(kind: 'u64'),
            ),
          ],
        ),
      ),
    ],
  );
}
