/// Tests for Transaction Building and Validation Infrastructure
///
/// This test suite validates the transaction building, validation, and
/// optimization infrastructure for TypeScript parity.

import 'package:test/test.dart';
import 'dart:typed_data';

import '../lib/src/transaction/transaction_builder.dart';
import '../lib/src/transaction/transaction_validator.dart';
import '../lib/src/transaction/transaction_optimizer.dart';
import '../lib/src/types/public_key.dart';
import '../lib/src/types/keypair.dart';
import '../lib/src/provider/anchor_provider.dart';
import '../lib/src/provider/connection.dart';
import '../lib/src/provider/wallet.dart';

void main() {
  group('Transaction Building Infrastructure', () {
    late AnchorProvider mockProvider;
    late Connection mockConnection;

    setUp(() async {
      // Create mock connection
      mockConnection = Connection('http://localhost:8899');

      // Create mock provider
      final keypair = await Keypair.generate();
      final wallet = KeypairWallet(keypair);
      mockProvider = AnchorProvider(mockConnection, wallet);
    });

    group('TransactionBuilder', () {
      test('creates builder with default configuration', () {
        final builder = TransactionBuilder.create(provider: mockProvider);

        expect(builder, isNotNull);
        expect(builder.toString(), contains('TransactionBuilder'));
      });

      test('creates builder with custom configuration', () {
        const config = TransactionBuilderConfig(
          maxInstructions: 50,
          autoComputeBudget: false,
        );

        final builder = TransactionBuilder.create(
          provider: mockProvider,
          config: config,
        );

        expect(builder, isNotNull);
      });

      test('fluent API - fee payer setting', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final testKey =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final result = builder.feePayer(testKey);

        expect(result, equals(builder)); // Returns self for chaining
      });

      test('fluent API - recent blockhash setting', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        const testBlockhash = 'testblockhash123';

        final result = builder.recentBlockhash(testBlockhash);

        expect(result, equals(builder));
      });

      test('fluent API - compute units setting', () {
        final builder = TransactionBuilder.create(provider: mockProvider);

        final result = builder.computeUnits(200000, price: 1000);

        expect(result, equals(builder));
      });

      test('adds instruction successfully', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final instruction = TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        );

        final result = builder.addInstruction(instruction);

        expect(result, equals(builder));
        final stats = builder.getStats();
        expect(stats['instructionCount'], equals(1));
      });

      test('throws error when exceeding max instructions', () {
        const config = TransactionBuilderConfig(maxInstructions: 1);
        final builder = TransactionBuilder.create(
          provider: mockProvider,
          config: config,
        );

        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final instruction = TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        );

        builder.addInstruction(instruction);

        expect(
          () => builder.addInstruction(instruction),
          throwsA(isA<Exception>()),
        );
      });

      test('adds multiple instructions', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final instructions = List.generate(
            3,
            (i) => TransactionInstruction(
                  programId: programId,
                  accounts: [],
                  data: Uint8List.fromList([i]),
                ));

        final result = builder.addInstructions(instructions);

        expect(result, equals(builder));
        final stats = builder.getStats();
        expect(stats['instructionCount'], equals(3));
      });

      test('registers and retrieves accounts', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final testKey =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.registerAccount('testAccount', testKey);

        final retrievedKey = builder.getAccount('testAccount');
        expect(retrievedKey, equals(testKey));
      });

      test('derives PDA and registers it', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final result = builder.derivePDA(
          name: 'testPDA',
          seeds: ['test', 123],
          programId: programId,
        );

        expect(result, equals(builder));

        final pdaKey = builder.getAccount('testPDA');
        expect(pdaKey, isNotNull);
      });

      test('creates account meta with name lookup', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final testKey =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.registerAccount('testAccount', testKey);

        final accountMeta = builder.account(
          name: 'testAccount',
          isSigner: true,
          isWritable: false,
        );

        expect(accountMeta.publicKey, equals(testKey));
        expect(accountMeta.isSigner, isTrue);
        expect(accountMeta.isWritable, isFalse);
      });

      test('creates account meta with direct public key', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final testKey =
            PublicKey.fromBase58('11111111111111111111111111111112');

        final accountMeta = builder.account(
          publicKey: testKey,
          isSigner: false,
          isWritable: true,
        );

        expect(accountMeta.publicKey, equals(testKey));
        expect(accountMeta.isSigner, isFalse);
        expect(accountMeta.isWritable, isTrue);
      });

      test('throws error for missing account name', () {
        final builder = TransactionBuilder.create(provider: mockProvider);

        expect(
          () => builder.account(
            name: 'nonexistent',
            isSigner: false,
            isWritable: false,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('throws error when neither name nor publicKey provided', () {
        final builder = TransactionBuilder.create(provider: mockProvider);

        expect(
          () => builder.account(
            isSigner: false,
            isWritable: false,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('builds instruction with fluent API', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final accountKey =
            PublicKey.fromBase58('11111111111111111111111111111113');

        final result = builder.instruction(
          programId: programId,
          accounts: [
            AccountMeta(
              publicKey: accountKey,
              isSigner: false,
              isWritable: true,
            ),
          ],
          data: Uint8List.fromList([1, 2, 3, 4]),
        );

        expect(result, equals(builder));
        final stats = builder.getStats();
        expect(stats['instructionCount'], equals(1));
      });

      test('provides transaction statistics', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final accountKey =
            PublicKey.fromBase58('11111111111111111111111111111113');

        builder.instruction(
          programId: programId,
          accounts: [
            AccountMeta(
                publicKey: accountKey, isSigner: true, isWritable: false),
          ],
          data: Uint8List.fromList([1, 2, 3]),
        );

        final stats = builder.getStats();

        expect(stats['instructionCount'], equals(1));
        expect(stats['uniqueAccounts'], greaterThan(0));
        expect(stats['signerAccounts'], greaterThan(0));
        expect(stats['writableAccounts'], greaterThanOrEqualTo(0));
        expect(stats['totalDataSize'], equals(3));
        expect(stats['estimatedSize'], greaterThan(0));
      });

      test('estimates transaction size correctly', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        // Add instruction with known data size
        builder.instruction(
          programId: programId,
          accounts: [],
          data: Uint8List(100), // 100 bytes of data
        );

        final stats = builder.getStats();
        final estimatedSize = stats['estimatedSize'] as int;

        expect(estimatedSize, greaterThan(100)); // Should include overhead
        expect(
            estimatedSize, lessThan(1232)); // Should be under transaction limit
      });

      test('clears builder state', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        // Add some state
        builder
          ..registerAccount('test', programId)
          ..addInstruction(TransactionInstruction(
            programId: programId,
            accounts: [],
            data: Uint8List.fromList([1, 2, 3]),
          ));

        // Verify state exists
        var stats = builder.getStats();
        expect(stats['instructionCount'], equals(1));
        expect(builder.getAccount('test'), isNotNull);

        // Clear and verify empty
        final result = builder.clear();
        expect(result, equals(builder));

        stats = builder.getStats();
        expect(stats['instructionCount'], equals(0));
        expect(builder.getAccount('test'), isNull);
      });

      test('toString provides meaningful information', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        final description = builder.toString();

        expect(description, contains('TransactionBuilder'));
        expect(description, contains('instructions: 1'));
        expect(description, contains('accounts:'));
        expect(description, contains('size:'));
        expect(description, contains('bytes'));
      });
    });

    group('TransactionValidator', () {
      test('creates validator with default config', () {
        const validator = TransactionValidator();
        expect(validator, isNotNull);
      });

      test('creates validator with custom config', () {
        final config = TransactionValidationConfig.strict();
        final validator = TransactionValidator(config: config);
        expect(validator, isNotNull);
      });

      test('validates builder successfully', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const validator = TransactionValidator();
        final result = await validator.validateBuilder(builder);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.metrics.instructionCount, equals(1));
      });

      test('detects empty transaction error', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);

        const validator = TransactionValidator();
        final result = await validator.validateBuilder(builder);

        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
        expect(result.errors.first.type, equals('instruction_count'));
      });

      test('detects size limit violations', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        // Add instruction with large data to exceed size limit
        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List(2000), // Large data
        ));

        const validator = TransactionValidator();
        final result = await validator.validateBuilder(builder);

        // Should have warnings or errors about size
        expect(result.warnings.isNotEmpty || result.errors.isNotEmpty, isTrue);
      });

      test('provides validation metrics', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const validator = TransactionValidator();
        final result = await validator.validateBuilder(builder);

        expect(result.metrics.instructionCount, equals(1));
        expect(result.metrics.estimatedSize, greaterThan(0));
        expect(result.metrics.validationTimeMs, greaterThanOrEqualTo(0));
        expect(result.metrics.efficiencyScore, greaterThanOrEqualTo(0));
        expect(result.metrics.efficiencyScore, lessThanOrEqualTo(100));
      });

      test('validation result summary is informative', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);

        const validator = TransactionValidator();
        final result = await validator.validateBuilder(builder);

        final summary = result.summary;
        expect(summary, isNotEmpty);
        expect(summary, contains('validation'));
      });
    });

    group('TransactionOptimizer', () {
      test('creates optimizer with default config', () {
        const optimizer = TransactionOptimizer();
        expect(optimizer, isNotNull);
      });

      test('creates optimizer with custom config', () {
        final config = TransactionOptimizationConfig.aggressive();
        final optimizer = TransactionOptimizer(config: config);
        expect(optimizer, isNotNull);
      });

      test('optimizes builder without errors', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const optimizer = TransactionOptimizer();
        final result = await optimizer.optimize(builder);

        expect(result.optimizedBuilder, isNotNull);
        expect(result.metrics, isNotNull);
        expect(result.appliedOptimizations, isNotNull);
        expect(result.warnings, isNotNull);
      });

      test('provides optimization metrics', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const optimizer = TransactionOptimizer();
        final result = await optimizer.optimize(builder);

        expect(result.metrics.originalSize, greaterThan(0));
        expect(result.metrics.optimizedSize, greaterThan(0));
        expect(result.metrics.originalComputeUnits, greaterThan(0));
        expect(result.metrics.optimizedComputeUnits, greaterThan(0));
        expect(result.metrics.optimizationTimeMs, greaterThanOrEqualTo(0));
        expect(result.metrics.sizeReduction, greaterThanOrEqualTo(0));
        expect(result.metrics.computeReduction, greaterThanOrEqualTo(0));
        expect(result.metrics.optimizationScore, greaterThanOrEqualTo(0));
        expect(result.metrics.optimizationScore, lessThanOrEqualTo(100));
      });

      test('provides optimization recommendations', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const optimizer = TransactionOptimizer();
        final recommendations =
            optimizer.getOptimizationRecommendations(builder);

        expect(recommendations, isNotNull);
        expect(recommendations, isA<List<String>>());
      });

      test('estimates transaction fees', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const optimizer = TransactionOptimizer();
        final fee = optimizer.estimateTransactionFee(builder);

        expect(fee, greaterThan(0));
        expect(fee, lessThan(1)); // Should be less than 1 SOL for simple tx
      });

      test('provides performance insights', () {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const optimizer = TransactionOptimizer();
        final insights = optimizer.getPerformanceInsights(builder);

        expect(insights.containsKey('estimatedFee'), isTrue);
        expect(insights.containsKey('estimatedComputeUnits'), isTrue);
        expect(insights.containsKey('complexity'), isTrue);
        expect(insights.containsKey('efficiency'), isTrue);
        expect(insights.containsKey('recommendations'), isTrue);

        expect(insights['complexity'], greaterThanOrEqualTo(0));
        expect(insights['complexity'], lessThanOrEqualTo(100));
        expect(insights['efficiency'], greaterThanOrEqualTo(0));
        expect(insights['efficiency'], lessThanOrEqualTo(100));
      });

      test('optimization result summary is informative', () async {
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');

        builder.addInstruction(TransactionInstruction(
          programId: programId,
          accounts: [],
          data: Uint8List.fromList([1, 2, 3]),
        ));

        const optimizer = TransactionOptimizer();
        final result = await optimizer.optimize(builder);

        final summary = result.summary;
        expect(summary, isNotEmpty);
        expect(summary, contains('optimization'));
      });
    });

    group('Integration Tests', () {
      test('complete transaction building workflow', () async {
        // Build transaction
        final builder = TransactionBuilder.create(provider: mockProvider);
        final programId =
            PublicKey.fromBase58('11111111111111111111111111111112');
        final accountKey =
            PublicKey.fromBase58('11111111111111111111111111111113');

        builder
          ..registerAccount('systemProgram', programId)
          ..registerAccount('targetAccount', accountKey)
          ..instruction(
            programId: programId,
            accounts: [
              builder.account(
                name: 'targetAccount',
                isSigner: false,
                isWritable: true,
              ),
            ],
            data: Uint8List.fromList([1, 2, 3, 4]),
          );

        // Validate transaction
        const validator = TransactionValidator();
        final validationResult = await validator.validateBuilder(builder);

        expect(validationResult.isValid, isTrue);

        // Optimize transaction
        const optimizer = TransactionOptimizer();
        final optimizationResult = await optimizer.optimize(builder);

        expect(optimizationResult.optimizedBuilder, isNotNull);

        // Get final stats
        final finalStats = optimizationResult.optimizedBuilder.getStats();
        expect(finalStats['instructionCount'], equals(1));
      });
    });
  });
}
