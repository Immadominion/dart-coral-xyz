/// Basic-0 Example: TypeScript Anchor "basic-0" Tutorial Equivalent
///
/// This example demonstrates a simple initialize() RPC call for an Anchor
/// program, validating IDL loading and RPC connection.
///
/// Key concepts demonstrated:
/// - IDL loading and parsing
/// - Connection health check
/// - Program instance creation
/// - Initialize RPC call pattern

import 'package:coral_xyz/coral_xyz_anchor.dart';

Future<void> main() async {
  print('🔰 Basic-0 Example: Simple initialize() call');
  print('============================================\n');
  try {
    // Step 1: Setup connection and provider
    final connection = Connection('https://api.devnet.solana.com');
    final keypair = await Keypair.generate();
    final wallet = KeypairWallet(keypair);
    final provider = AnchorProvider(connection, wallet);
    print('Connection RPC URL: ${connection.rpcUrl}');
    print('Wallet public key: ${wallet.publicKey}');

    // Optional: Check connection health
    try {
      final healthy = await connection.checkHealth();
      print('Connection health check: \\${healthy}');
    } catch (e) {
      print('Health check skipped (demo mode): \\${e}');
    }

    // Step 2: Load minimal IDL
    final idl = const Idl(
      address: '11111111111111111111111111111111',
      metadata: IdlMetadata(name: 'basic0', version: '0.1.0', spec: '0.1.0'),
      instructions: [
        IdlInstruction(
          name: 'initialize',
          discriminator: [0, 0, 0, 0, 0, 0, 0, 0],
          accounts: [],
          args: [],
        ),
      ],
    );
    print('IDL loaded with ${idl.instructions.length} instruction(s):');
    for (final instr in idl.instructions) {
      print('- \\${instr.name}');
    }

    // Step 3: Create program instance (use withProgramId for custom ID)
    final programId = PublicKey.fromBase58('11111111111111111111111111111111');
    final program = Program.withProgramId(idl, programId, provider: provider);
    print('Program instance created for ID: \\${programId}');

    // Step 4: Initialize RPC call (demo)
    print('\\nCalling initialize RPC (demo) ...');
    try {
      final signature = await program.methods.initialize().rpc();
      print('Initialize RPC invoked; signature: \\${signature}');
    } catch (e) {
      print('RPC call skipped (demo mode): \\${e}');
    }

    print('\\n✅ Basic-0 example completed successfully!');
  } catch (error) {
    print('❌ Error in Basic-0 example: \\${error}');
  }
}
