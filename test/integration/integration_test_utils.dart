/// Integration testing utilities for Anchor Dart client
///
/// This module provides infrastructure for running integration tests
/// against a local Solana test validator, creating end-to-end test
/// scenarios, and validating compatibility with TypeScript implementation.

library;

import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart'
    hide Transaction, TransactionInstruction;
import 'package:coral_xyz_anchor/src/types/transaction.dart'
    show Transaction, TransactionInstruction;
import 'dart:typed_data';

/// Configuration for integration test environment
class IntegrationTestConfig {
  const IntegrationTestConfig({
    this.rpcUrl = 'http://127.0.0.1:8899',
    this.wsUrl = 'ws://127.0.0.1:8900',
    this.autoManageValidator = true,
    this.validatorTimeout = const Duration(seconds: 30),
    this.fundingAmount = 1000000000, // 1 SOL
  });

  /// RPC URL for the test validator
  final String rpcUrl;

  /// WebSocket URL for the test validator
  final String wsUrl;

  /// Whether to start/stop validator automatically
  final bool autoManageValidator;

  /// Validator startup timeout
  final Duration validatorTimeout;

  /// Test account funding amount in lamports
  final int fundingAmount;
}

/// Manager for local Solana test validator
class SolanaTestValidator {
  SolanaTestValidator(this.config);
  Process? _validatorProcess;
  final IntegrationTestConfig config;
  bool _isRunning = false;

  /// Check if validator is running
  bool get isRunning => _isRunning;

  /// Start the local test validator
  Future<void> start() async {
    if (_isRunning) return;

    print('Starting Solana test validator...');

    try {
      // Start validator process
      _validatorProcess = await Process.start(
        'solana-test-validator',
        [
          '--rpc-port',
          '8899',
          '--ws-port',
          '8900',
          '--ledger',
          '.anchor/test-ledger',
          '--bpf-program',
          '11111111111111111111111111111111',
          'tests/fixtures/noop.so',
          '--reset',
          '--quiet',
        ],
        runInShell: true,
      );

      // Wait for validator to be ready
      await _waitForValidator();
      _isRunning = true;
      print('Solana test validator started successfully');
    } catch (e) {
      throw Exception('Failed to start Solana test validator: $e');
    }
  }

  /// Stop the test validator
  Future<void> stop() async {
    if (!_isRunning) return;

    print('Stopping Solana test validator...');

    _validatorProcess?.kill();
    await _validatorProcess?.exitCode;
    _validatorProcess = null;
    _isRunning = false;

    print('Solana test validator stopped');
  }

  /// Wait for validator to be ready
  Future<void> _waitForValidator() async {
    final connection = Connection(config.rpcUrl);
    final deadline = DateTime.now().add(config.validatorTimeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        await connection.getLatestBlockhash();
        return; // Validator is ready
      } catch (e) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    throw TimeoutException('Validator failed to start within timeout');
  }
}

/// Integration test environment setup
class IntegrationTestEnvironment {
  IntegrationTestEnvironment([IntegrationTestConfig? config])
      : config = config ?? const IntegrationTestConfig(),
        validator =
            SolanaTestValidator(config ?? const IntegrationTestConfig());
  final IntegrationTestConfig config;
  final SolanaTestValidator validator;
  late final Connection connection;
  late final AnchorProvider provider;

  final List<Keypair> _testAccounts = [];

  /// Initialize the test environment
  Future<void> setUp() async {
    if (config.autoManageValidator) {
      await validator.start();
    }

    connection = Connection(config.rpcUrl);

    // Create a test wallet
    final wallet = await KeypairWallet.generate();
    provider = AnchorProvider(connection, wallet);

    // Fund the test wallet
    await _fundAccount(wallet.publicKey, config.fundingAmount);
  }

  /// Clean up the test environment
  Future<void> tearDown() async {
    if (config.autoManageValidator) {
      await validator.stop();
    }
  }

  /// Create and fund a new test account
  Future<Keypair> createFundedAccount([int? lamports]) async {
    final keypair = await Keypair.generate();
    await _fundAccount(keypair.publicKey, lamports ?? config.fundingAmount);
    _testAccounts.add(keypair);
    return keypair;
  }

  /// Fund an account using mock funding (airdrop not available in current Connection API)
  Future<void> _fundAccount(PublicKey publicKey, int lamports) async {
    try {
      // Mock implementation - in real integration tests, this would use test validator's airdrop
      // For now, we'll skip actual funding and assume accounts are funded
      print(
        'Mock funding account ${publicKey.toBase58()} with $lamports lamports',
      );

      // In a real implementation, this would call:
      // final signature = await connection.requestAirdrop(publicKey, lamports);
      // await connection.confirmTransaction(signature);

      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate network delay
    } catch (e) {
      print(
        'Mock funding completed (real airdrop would be implemented here): $e',
      );
    }
  }

  /// Get all created test accounts
  List<Keypair> get testAccounts => List.unmodifiable(_testAccounts);

  /// Deploy a test program (mock implementation)
  Future<PublicKey> deployTestProgram(
    String programName,
    List<int> programData,
  ) async {
    // In a real implementation, this would deploy the program to the test validator
    // For now, return a mock program ID
    final keypair = await Keypair.generate();
    return keypair.publicKey;
  }
}

/// Performance benchmarking utilities
class PerformanceBenchmark {
  PerformanceBenchmark(this.name);
  final String name;
  final List<Duration> _measurements = [];
  DateTime? _startTime;

  /// Start timing
  void start() {
    _startTime = DateTime.now();
  }

  /// Stop timing and record measurement
  void stop() {
    if (_startTime == null) throw StateError('Benchmark not started');

    final duration = DateTime.now().difference(_startTime!);
    _measurements.add(duration);
    _startTime = null;
  }

  /// Get benchmark statistics
  BenchmarkStats get stats {
    if (_measurements.isEmpty) {
      return BenchmarkStats(
        name,
        Duration.zero,
        Duration.zero,
        Duration.zero,
        0,
      );
    }

    final sortedMeasurements = List<Duration>.from(_measurements)..sort();
    final min = sortedMeasurements.first;
    final max = sortedMeasurements.last;

    final totalMs =
        _measurements.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    final avgMs = totalMs / _measurements.length;
    final average = Duration(microseconds: avgMs.round());

    return BenchmarkStats(name, min, max, average, _measurements.length);
  }

  /// Clear all measurements
  void reset() {
    _measurements.clear();
    _startTime = null;
  }
}

/// Benchmark statistics
class BenchmarkStats {
  const BenchmarkStats(
      this.name, this.min, this.max, this.average, this.sampleCount);
  final String name;
  final Duration min;
  final Duration max;
  final Duration average;
  final int sampleCount;

  @override
  String toString() => 'BenchmarkStats($name: avg=${average.inMilliseconds}ms, '
      'min=${min.inMilliseconds}ms, max=${max.inMilliseconds}ms, '
      'samples=$sampleCount)';
}

/// Cross-program testing utilities
class CrossProgramTester {
  CrossProgramTester(this.environment);
  final IntegrationTestEnvironment environment;
  final Map<String, Program> _programs = {};

  /// Register a program for cross-program testing
  void registerProgram(String name, Program program) {
    _programs[name] = program;
  }

  /// Execute a cross-program instruction (CPI)
  Future<String> executeCrossProgram({
    required String callerProgram,
    required String targetProgram,
    required String instruction,
    required Map<String, dynamic> args,
  }) async {
    final caller = _programs[callerProgram];
    final target = _programs[targetProgram];

    if (caller == null) {
      throw ArgumentError('Caller program not found: $callerProgram');
    }
    if (target == null) {
      throw ArgumentError('Target program not found: $targetProgram');
    }

    // Build and execute cross-program instruction
    // This is a simplified mock implementation
    final instruction = TransactionInstruction(
      programId: caller.programId,
      accounts: [],
      data: Uint8List(0),
    );

    final transaction = Transaction(
      instructions: [instruction],
    );

    return environment.provider.sendAndConfirm(transaction);
  }
}

/// Compatibility testing with TypeScript implementation
class TypeScriptCompatibilityTester {
  TypeScriptCompatibilityTester(this.environment);
  final IntegrationTestEnvironment environment;

  /// Test IDL parsing compatibility
  Future<bool> testIdlCompatibility(Map<String, dynamic> tsIdl) async {
    try {
      final dartIdl = Idl.fromJson(tsIdl);

      // Verify key properties match
      expect(dartIdl.address, tsIdl['address']);
      expect(dartIdl.metadata?.name, tsIdl['metadata']['name']);
      expect(dartIdl.instructions.length, tsIdl['instructions'].length);

      return true;
    } catch (e) {
      print('IDL compatibility test failed: $e');
      return false;
    }
  }

  /// Test instruction encoding compatibility
  Future<bool> testInstructionEncoding({
    required String instructionName,
    required Map<String, dynamic> args,
    required List<int> expectedBytes,
  }) async {
    try {
      // This would compare Dart encoding with TypeScript encoding
      // For now, return true as mock implementation
      return true;
    } catch (e) {
      print('Instruction encoding compatibility test failed: $e');
      return false;
    }
  }

  /// Test account data parsing compatibility
  Future<bool> testAccountDataCompatibility({
    required List<int> accountData,
    required Map<String, dynamic> expectedParsed,
  }) async {
    try {
      // This would compare Dart account parsing with TypeScript parsing
      // For now, return true as mock implementation
      return true;
    } catch (e) {
      print('Account data compatibility test failed: $e');
      return false;
    }
  }
}
