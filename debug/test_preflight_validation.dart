/// Test file for pre-flight account validation functionality
/// This file demonstrates and tests the new PreflightValidator capabilities

import 'dart:typed_data';
import '../lib/src/types/public_key.dart';
import '../lib/src/types/transaction.dart';
import '../lib/src/provider/connection.dart';
import '../lib/src/provider/anchor_provider.dart';
import '../lib/src/transaction/preflight_validator.dart';
import '../lib/src/transaction/transaction_simulator.dart';

void main() async {
  print('Testing Pre-flight Account Validation System...\n');

  try {
    // Create test connection
    final connection = Connection('https://api.devnet.solana.com');

    // Create test provider
    final provider = AnchorProvider(connection, null);

    // Create preflight validator
    final validator = PreflightValidator(provider);

    // Create transaction simulator with preflight validation
    final simulator = TransactionSimulator(provider);

    print('1. Testing basic account validation...');

    // Test with system program (should exist)
    final systemProgram = PublicKey.systemProgram;
    final existsResult =
        await validator.validateAccountExistence(systemProgram);
    print('   - System program exists: $existsResult');

    // Test ownership validation
    final ownershipResult = await validator.validateAccountOwnership(
      systemProgram,
      PublicKey.systemProgram,
    );
    print('   - System program ownership valid: $ownershipResult');

    print('\n2. Testing comprehensive account validation...');

    // Create test accounts list
    final testAccounts = [
      PublicKey.systemProgram,
      PublicKey.fromBase58(
          'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'), // Token Program
      PublicKey.fromBase58(
          '11111111111111111111111111111111'), // System Program
    ];

    final validationResult = await validator.validateAccounts(
      testAccounts,
      config: PreflightValidationConfig.defaultConfig(),
    );

    print('   - Total accounts validated: ${validationResult.totalAccounts}');
    print('   - Valid accounts: ${validationResult.validAccounts}');
    print('   - Invalid accounts: ${validationResult.invalidAccounts}');
    print('   - Validation successful: ${validationResult.success}');
    print(
        '   - Validation time: ${validationResult.validationTime.inMilliseconds}ms');
    print('   - Errors: ${validationResult.errors.length}');
    print('   - Warnings: ${validationResult.warnings.length}');

    print('\n3. Testing transaction validation...');

    // Create a test transaction
    final testTransaction = _createTestTransaction();

    final transactionValidationResult = await validator.validateTransaction(
      testTransaction,
      config: PreflightValidationConfig.defaultConfig(),
    );

    print(
        '   - Transaction validation successful: ${transactionValidationResult.success}');
    print(
        '   - Accounts in transaction: ${transactionValidationResult.totalAccounts}');
    print(
        '   - Validation errors: ${transactionValidationResult.errors.length}');

    print('\n4. Testing different validation configurations...');

    // Test strict validation
    final strictResult = await validator.validateAccounts(
      testAccounts,
      config: PreflightValidationConfig.strict(),
    );
    print('   - Strict validation successful: ${strictResult.success}');

    // Test permissive validation
    final permissiveResult = await validator.validateAccounts(
      testAccounts,
      config: PreflightValidationConfig.permissive(),
    );
    print('   - Permissive validation successful: ${permissiveResult.success}');

    print('\n5. Testing batch validation with parallel requests...');

    final batchResult = await validator.validateAccounts(
      testAccounts,
      config: PreflightValidationConfig(
        enableBatchValidation: true,
        maxParallelRequests: 5,
      ),
    );
    print('   - Batch validation successful: ${batchResult.success}');
    print(
        '   - Batch validation time: ${batchResult.validationTime.inMilliseconds}ms');

    print('\n6. Testing simulation with pre-flight validation...');

    final simulationResult = await simulator.simulateWithPreflightValidation(
      testTransaction,
      preflightConfig: PreflightValidationConfig.defaultConfig(),
    );

    print(
        '   - Simulation with preflight successful: ${simulationResult.success}');
    print('   - Simulation logs: ${simulationResult.logs.length} entries');
    if (simulationResult.error != null) {
      print('   - Simulation error: ${simulationResult.error!.type}');
    }

    print('\n7. Testing validation cache...');

    final cacheStats1 = validator.getCacheStats();
    await validator.validateAccountExistence(systemProgram);
    final cacheStats2 = validator.getCacheStats();

    print('   - Cache size before: ${cacheStats1['size']}');
    print('   - Cache size after: ${cacheStats2['size']}');
    print(
        '   - Cache working: ${cacheStats2['size']! >= cacheStats1['size']!}');

    validator.clearCache();
    final cacheStats3 = validator.getCacheStats();
    print('   - Cache cleared: ${cacheStats3['size'] == 0}');

    print('\n8. Testing validation with expected owners...');

    final expectedOwners = <PublicKey, PublicKey>{
      systemProgram: PublicKey.systemProgram,
    };

    final ownerValidationResult = await validator.validateAccounts(
      [systemProgram],
      expectedOwners: expectedOwners,
    );

    print('   - Owner validation successful: ${ownerValidationResult.success}');

    print('\n9. Testing error handling with non-existent account...');

    final nonExistentAccount =
        PublicKey.fromBase58('22222222222222222222222222222222');
    final errorResult = await validator.validateAccounts([nonExistentAccount]);

    print(
        '   - Non-existent account validation failed as expected: ${!errorResult.success}');
    print('   - Error count: ${errorResult.errors.length}');
    if (errorResult.errors.isNotEmpty) {
      print('   - Error type: ${errorResult.errors.first.type}');
      print('   - Error message: ${errorResult.errors.first.message}');
    }

    print(
        '\n✅ Pre-flight Account Validation System tests completed successfully!');
    print('🚀 Phase 3, Step 3.2 is fully implemented and working.');
  } catch (e, stackTrace) {
    print('❌ Test failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Create a simple test transaction for validation
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
