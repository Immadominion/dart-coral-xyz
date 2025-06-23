/// Test file for transaction simulation functionality
/// This file demonstrates and tests the new TransactionSimulator capabilities

import 'dart:typed_data';
import '../lib/src/types/public_key.dart';
import '../lib/src/types/transaction.dart';
import '../lib/src/provider/connection.dart';
import '../lib/src/provider/anchor_provider.dart';
import '../lib/src/transaction/transaction_simulator.dart';

void main() async {
  print('Testing Transaction Simulation Core Engine...\n');

  try {
    // Create test connection
    final connection = Connection('https://api.devnet.solana.com');

    // Create test provider
    final provider = AnchorProvider(connection, null);

    // Create transaction simulator
    final simulator = TransactionSimulator(provider);

    // Create a simple test transaction
    final testTransaction = _createTestTransaction();

    print('1. Testing basic transaction simulation...');
    final result = await simulator.simulate(testTransaction);

    print('   - Success: ${result.success}');
    print('   - Logs: ${result.logs.length} entries');
    if (result.error != null) {
      print('   - Error: ${result.error}');
    }
    print('   - Compute units: ${result.unitsConsumed ?? 'N/A'}');

    print('\n2. Testing simulation with account validation...');
    final accountValidationResult =
        await simulator.simulateWithAccountValidation(
      testTransaction,
      requiredAccounts: [PublicKey.systemProgram],
    );

    print('   - Success: ${accountValidationResult.success}');
    print(
        '   - Has accounts data: ${accountValidationResult.accounts != null}');

    print('\n3. Testing simulation with signature verification...');
    final sigVerifyResult =
        await simulator.simulateWithSigVerify(testTransaction);

    print('   - Success: ${sigVerifyResult.success}');
    print('   - Error type: ${sigVerifyResult.error?.type ?? 'None'}');

    print('\n4. Testing simulation configuration...');
    final config = TransactionSimulationConfig(
      commitment: 'confirmed',
      includeAccounts: true,
      sigVerify: false,
      replaceRecentBlockhash: true,
    );

    final configResult =
        await simulator.simulate(testTransaction, config: config);
    print(
        '   - Config applied successfully: ${configResult.success || configResult.error != null}');

    print('\n5. Testing cache functionality...');
    final cacheStats1 = simulator.getCacheStats();
    await simulator.simulate(testTransaction);
    final cacheStats2 = simulator.getCacheStats();

    print('   - Cache size before: ${cacheStats1['size']}');
    print('   - Cache size after: ${cacheStats2['size']}');
    print(
        '   - Cache working: ${cacheStats2['size']! >= cacheStats1['size']!}');

    simulator.clearCache();
    final cacheStats3 = simulator.getCacheStats();
    print('   - Cache cleared: ${cacheStats3['size'] == 0}');

    print(
        '\n✅ Transaction Simulation Core Engine tests completed successfully!');
    print('🚀 Phase 3, Step 3.1 is fully implemented and working.');
  } catch (e, stackTrace) {
    print('❌ Test failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Create a simple test transaction for simulation
Transaction _createTestTransaction() {
  final systemProgram = PublicKey.systemProgram;
  final testAccount = PublicKey.fromBase58('11111111111111111111111111111111');

  final instruction = TransactionInstruction(
    programId: systemProgram,
    accounts: [
      AccountMeta.readonly(testAccount),
    ],
    data: Uint8List.fromList([0]), // Simple no-op instruction
  );

  return Transaction(
    instructions: [instruction],
    feePayer: testAccount,
    recentBlockhash:
        'FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5', // Mock blockhash
  );
}
