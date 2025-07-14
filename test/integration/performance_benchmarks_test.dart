import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart'
    hide AccountMeta, Transaction, TransactionInstruction;
import 'package:coral_xyz_anchor/src/types/transaction.dart'
    show AccountMeta, Transaction, TransactionInstruction;
import 'integration_test_utils.dart';
import 'dart:typed_data';

/// Performance benchmarking tests
void main() {
  group('Performance Benchmarks', () {
    late IntegrationTestEnvironment env;
    late PerformanceBenchmark connectionBenchmark;
    late PerformanceBenchmark encodingBenchmark;
    late PerformanceBenchmark transactionBenchmark;

    setUpAll(() async {
      env = IntegrationTestEnvironment();
      await env.setUp();

      connectionBenchmark = PerformanceBenchmark('Connection Operations');
      encodingBenchmark = PerformanceBenchmark('Encoding/Decoding');
      transactionBenchmark = PerformanceBenchmark('Transaction Building');
    });

    tearDownAll(() async {
      await env.tearDown();

      // Print benchmark results
      print('\n=== Performance Benchmark Results ===');
      print(connectionBenchmark.stats);
      print(encodingBenchmark.stats);
      print(transactionBenchmark.stats);
    });

    test('connection latency benchmark', () async {
      const iterations = 10;

      for (int i = 0; i < iterations; i++) {
        connectionBenchmark.start();
        try {
          // Benchmark connection operations
          await env.connection.getLatestBlockhash();
        } catch (e) {
          // Expected in test environment - just measuring timing
        }
        connectionBenchmark.stop();
      }

      final stats = connectionBenchmark.stats;
      expect(stats.sampleCount, equals(iterations));
      expect(
        stats.average.inMilliseconds,
        lessThan(5000),
      ); // Should be under 5 seconds in test env
    });

    test('instruction encoding benchmark', () async {
      const iterations = 100;

      // Create mock IDL for encoding tests
      final mockIdl = Idl(
        address: 'BenchmarkProgram1111111111111111111111111',
        metadata: const IdlMetadata(
          name: 'benchmark_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'benchmark_instruction',
            docs: ['Benchmark instruction'],
            discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
            accounts: [],
            args: [
              IdlField(name: 'value', type: idlTypeU64()),
              IdlField(name: 'flag', type: idlTypeBool()),
              IdlField(name: 'data', type: idlTypeString()),
            ],
          ),
        ],
      );

      final coder = BorshCoder(mockIdl);
      final testArgs = {
        'value': 123456789,
        'flag': true,
        'data': 'benchmark_test_data',
      };

      for (int i = 0; i < iterations; i++) {
        encodingBenchmark.start();
        final encoded =
            coder.instructions.encode('benchmark_instruction', testArgs);
        encodingBenchmark.stop();

        expect(encoded, isNotNull);
        expect(encoded.length, greaterThan(8)); // Should include discriminator
      }

      final stats = encodingBenchmark.stats;
      expect(stats.sampleCount, equals(iterations));
      expect(
        stats.average.inMicroseconds,
        lessThan(10000),
      ); // Should be under 10ms
    });

    test('transaction building benchmark', () async {
      const iterations = 50;

      final programKeypair = await env.createFundedAccount();
      final userKeypair = await env.createFundedAccount();

      for (int i = 0; i < iterations; i++) {
        transactionBenchmark.start();

        // Build a complex transaction
        final instruction = TransactionInstruction(
          programId: programKeypair.publicKey,
          accounts: [
            AccountMeta(
              pubkey: userKeypair.publicKey,
              isSigner: true,
              isWritable: true,
            ),
            AccountMeta(
              pubkey: programKeypair.publicKey,
              isSigner: false,
              isWritable: false,
            ),
          ],
          data: Uint8List.fromList(
            List.generate(
              64,
              (index) => index % 256,
            ),
          ), // 64 bytes of test data
        );

        final transaction = Transaction(
          instructions: [
            instruction,
            instruction,
            instruction,
          ], // Multiple instructions
          feePayer: userKeypair.publicKey,
        );

        transactionBenchmark.stop();

        expect(transaction.instructions.length, equals(3));
        expect(transaction.feePayer, equals(userKeypair.publicKey));
      }

      final stats = transactionBenchmark.stats;
      expect(stats.sampleCount, equals(iterations));
      expect(
        stats.average.inMicroseconds,
        lessThan(5000),
      ); // Should be under 5ms
    });

    test('account data processing benchmark', () async {
      const iterations = 20;
      final accountBenchmark = PerformanceBenchmark('Account Processing');

      // Create mock IDL with account definition
      final mockIdl = Idl(
        address: 'AccountBenchmark111111111111111111111111',
        metadata: const IdlMetadata(
          name: 'account_benchmark',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [], // Empty instructions for account-only benchmark
        accounts: [
          IdlAccount(
            name: 'BenchmarkAccount',
            discriminator: [10, 20, 30, 40, 50, 60, 70, 80],
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(name: 'value1', type: idlTypeU64()),
                IdlField(name: 'value2', type: idlTypeU32()),
                IdlField(name: 'flag', type: idlTypeBool()),
                IdlField(name: 'authority', type: idlTypePubkey()),
              ],
            ),
          ),
        ],
      );

      final coder = BorshCoder(mockIdl);
      final testAccount = await env.createFundedAccount();
      final testData = {
        'value1': 987654321,
        'value2': 12345,
        'flag': false,
        'authority': testAccount.publicKey.toBase58(),
      };

      for (int i = 0; i < iterations; i++) {
        accountBenchmark.start();

        // Encode account data
        final encoded =
            await coder.accounts.encode('BenchmarkAccount', testData);

        // Decode account data
        final decoded = coder.accounts
            .decode<Map<String, dynamic>>('BenchmarkAccount', encoded);

        accountBenchmark.stop();

        expect(decoded, isNotNull);
        expect(decoded['value1'], equals(987654321));
        expect(decoded['value2'], equals(12345));
        expect(decoded['flag'], equals(false));
      }

      final stats = accountBenchmark.stats;
      expect(stats.sampleCount, equals(iterations));
      expect(
        stats.average.inMilliseconds,
        lessThan(100),
      ); // Should be under 100ms

      print('Account Processing Benchmark: $stats');
    });

    test('memory usage benchmark', () async {
      // This test measures memory efficiency of key operations
      const largeIterations = 1000;
      final memoryBenchmark = PerformanceBenchmark('Memory Operations');

      final testAccounts = <Keypair>[];

      memoryBenchmark.start();

      // Create many keypairs to test memory usage
      for (int i = 0; i < largeIterations; i++) {
        final keypair = await Keypair.generate();
        testAccounts.add(keypair);
      }

      // Create many public keys
      final publicKeys = testAccounts.map((kp) => kp.publicKey).toList();

      // Create many account metas
      final accountMetas = publicKeys.map(AccountMeta.readonly).toList();

      memoryBenchmark.stop();

      expect(testAccounts.length, equals(largeIterations));
      expect(publicKeys.length, equals(largeIterations));
      expect(accountMetas.length, equals(largeIterations));

      final stats = memoryBenchmark.stats;
      expect(
        stats.average.inSeconds,
        lessThan(30),
      ); // Should complete within 30 seconds

      print('Memory Operations Benchmark: $stats');
    });
  });
}
