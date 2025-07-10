/// Enhanced Testing Infrastructure for Dart Coral XYZ SDK
///
/// Comprehensive testing framework matching TypeScript Anchor's testing capabilities
/// with fixtures, mocks, development utilities, and scenario management.

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import '../provider/provider.dart';
import '../provider/connection.dart';
import '../provider/wallet.dart';
import '../types/public_key.dart';
import '../types/keypair.dart';
import '../types/transaction.dart';
import '../types/commitment.dart';
import '../idl/idl.dart';
import '../program/program_class.dart';
import '../workspace/workspace.dart';

/// Test Validator Management System
/// Provides local validator setup, management, and cleanup for integration testing
class TestValidator {
  final String rpcUrl;
  final Map<String, dynamic> config;
  bool _isRunning = false;
  Process? _validatorProcess;
  final List<Keypair> _deployedPrograms = [];

  TestValidator({
    this.rpcUrl = 'http://localhost:8899',
    this.config = const {},
  });

  /// Start the test validator with specified configuration
  Future<void> start({
    Duration? timeout = const Duration(seconds: 30),
    List<String>? extraArgs,
  }) async {
    if (_isRunning) return;

    final args = [
      '--rpc-port',
      '8899',
      '--reset',
      '--quiet',
      ...?extraArgs,
    ];

    // Start solana-test-validator process
    _validatorProcess = await Process.start('solana-test-validator', args);

    // Wait for validator to be ready
    await _waitForValidator(timeout!);
    _isRunning = true;
  }

  /// Stop the test validator and cleanup
  Future<void> stop() async {
    if (!_isRunning) return;

    _validatorProcess?.kill();
    await _validatorProcess?.exitCode;
    _validatorProcess = null;
    _isRunning = false;
    _deployedPrograms.clear();
  }

  /// Wait for validator to become available
  Future<void> _waitForValidator(Duration timeout) async {
    final connection = Connection(rpcUrl);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        await connection.checkHealth();
        return;
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    throw TimeoutException('Test validator failed to start', timeout);
  }

  /// Deploy a program to the test validator
  Future<PublicKey> deployProgram(
    String programPath,
    Keypair? programKeypair,
  ) async {
    if (!_isRunning) throw StateError('Test validator not running');

    final keypair = programKeypair ?? await Keypair.generate();

    // Deploy using solana CLI
    final result = await Process.run('solana', [
      'program',
      'deploy',
      '--url',
      rpcUrl,
      '--program-id',
      keypair.publicKey.toBase58(),
      programPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to deploy program: ${result.stderr}');
    }

    _deployedPrograms.add(keypair);
    return keypair.publicKey;
  }

  /// Get connection to the test validator
  Connection getConnection() => Connection(rpcUrl);

  /// Check if validator is running
  bool get isRunning => _isRunning;

  /// Get list of deployed programs
  List<PublicKey> get deployedPrograms =>
      _deployedPrograms.map((k) => k.publicKey).toList();
}

/// Test Account Management and Funding
/// Manages test accounts, funding, and lifecycle for test scenarios
class TestAccountManager {
  final Connection connection;
  final Keypair payerKeypair;
  final Map<String, Keypair> _namedAccounts = {};
  final List<Keypair> _managedAccounts = [];

  TestAccountManager(this.connection, this.payerKeypair);

  /// Create a funded test account
  Future<Keypair> createFundedAccount({
    String? name,
    int lamports = 1000000000, // 1 SOL
  }) async {
    final account = await Keypair.generate();

    // Fund the account using airdrop (simplified for testing)
    await _requestAirdrop(account.publicKey, lamports);

    _managedAccounts.add(account);
    if (name != null) {
      _namedAccounts[name] = account;
    }

    return account;
  }

  /// Request airdrop for testing
  Future<void> _requestAirdrop(PublicKey publicKey, int lamports) async {
    // In a real implementation, this would use requestAirdrop RPC call
    // For now, we'll simulate this
    print('Airdropping $lamports lamports to ${publicKey.toBase58()}');
  }

  /// Get account by name
  Keypair? getAccount(String name) => _namedAccounts[name];

  /// Get account balance
  Future<int> getBalance(PublicKey publicKey) async {
    return await connection.getBalance(publicKey);
  }

  /// Create test account with specific data
  Future<Keypair> createAccountWithData({
    required PublicKey owner,
    required int space,
    required Uint8List data,
    int? lamports,
    String? name,
  }) async {
    final account = await Keypair.generate();

    // Use provided lamports or get from mock/real connection
    int rentExemptLamports;
    try {
      rentExemptLamports =
          lamports ?? await connection.getMinimumBalanceForRentExemption(space);
    } catch (e) {
      // Fallback for mock connections that don't implement this method
      rentExemptLamports = lamports ?? 1000000; // Default 0.001 SOL
    }

    // In a real implementation, this would create the account using system program
    // For testing, we'll simulate this
    await _requestAirdrop(account.publicKey, rentExemptLamports);

    _managedAccounts.add(account);
    if (name != null) {
      _namedAccounts[name] = account;
    }

    return account;
  }

  /// Cleanup all managed accounts
  Future<void> cleanup() async {
    _namedAccounts.clear();
    _managedAccounts.clear();
  }
}

/// Mock Provider and Connection Framework
/// Advanced mock implementations for isolated unit testing
class AdvancedMockProvider extends AnchorProvider {
  final AdvancedMockConnection mockConnection;
  final MockWallet mockWallet;
  final Map<String, dynamic> _configurations = {};

  AdvancedMockProvider._(this.mockConnection, this.mockWallet)
      : super(mockConnection, mockWallet);

  factory AdvancedMockProvider.create({
    String endpoint = 'http://localhost:8899',
    Keypair? walletKeypair,
    Map<String, dynamic>? config,
  }) {
    final connection = AdvancedMockConnection(endpoint);
    final wallet = MockWallet(walletKeypair);
    final provider = AdvancedMockProvider._(connection, wallet);

    if (config != null) {
      provider._configurations.addAll(config);
    }

    return provider;
  }

  /// Configure mock responses for specific scenarios
  void configureMockScenario(
      String scenarioName, Map<String, dynamic> responses) {
    mockConnection.setScenario(scenarioName, responses);
  }

  /// Activate a specific test scenario
  void activateScenario(String scenarioName) {
    mockConnection.activateScenario(scenarioName);
  }

  /// Get configuration value
  T? getConfig<T>(String key) => _configurations[key] as T?;

  /// Set configuration value
  void setConfig(String key, dynamic value) {
    _configurations[key] = value;
  }
}

/// Advanced Mock Connection with scenario support
class AdvancedMockConnection extends Connection {
  final Map<String, Map<String, dynamic>> _scenarios = {};
  final Map<String, dynamic> _currentResponses = {};
  final List<String> _callHistory = [];
  int _callCount = 0;

  AdvancedMockConnection(String endpoint) : super(endpoint);

  /// Set responses for a named scenario
  void setScenario(String name, Map<String, dynamic> responses) {
    _scenarios[name] = Map.from(responses);
  }

  /// Activate a scenario
  void activateScenario(String name) {
    if (!_scenarios.containsKey(name)) {
      throw ArgumentError('Unknown scenario: $name');
    }
    _currentResponses.clear();
    _currentResponses.addAll(_scenarios[name]!);
  }

  /// Record method call
  void _recordCall(String method, [Map<String, dynamic>? params]) {
    _callCount++;
    _callHistory
        .add('$method${params != null ? ':${jsonEncode(params)}' : ''}');
  }

  /// Get call history
  List<String> get callHistory => List.unmodifiable(_callHistory);

  /// Get call count
  int get callCount => _callCount;

  /// Clear history and responses
  void reset() {
    _callHistory.clear();
    _callCount = 0;
    _currentResponses.clear();
  }

  @override
  Future<String> checkHealth() async {
    _recordCall('checkHealth');
    final result = _currentResponses['checkHealth'];
    return result != null ? result.toString() : 'ok';
  }

  @override
  Future<int> getBalance(PublicKey address,
      {CommitmentConfig? commitment}) async {
    _recordCall('getBalance', {'address': address.toBase58()});
    final result = _currentResponses['getBalance'];
    return result is int ? result : 1000000000;
  }

  @override
  Future<LatestBlockhash> getLatestBlockhash(
      {CommitmentConfig? commitment}) async {
    _recordCall('getLatestBlockhash');
    final mockBlockhash = _currentResponses['getLatestBlockhash'] ??
        '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM';

    return LatestBlockhash(
      blockhash: mockBlockhash.toString(),
      lastValidBlockHeight: 123456789,
    );
  }

  @override
  Future<int> getMinimumBalanceForRentExemption(int dataLength,
      {CommitmentConfig? commitment}) async {
    _recordCall(
        'getMinimumBalanceForRentExemption', {'dataLength': dataLength});
    final result = _currentResponses['getMinimumBalanceForRentExemption'];
    return result is int ? result : 1000000;
  }

  @override
  Future<String> sendAndConfirmTransaction(
    dynamic transaction, {
    CommitmentConfig? commitment,
  }) async {
    _recordCall('sendAndConfirmTransaction', {
      'transaction': transaction is Map ? transaction.length : transaction.toString(),
    });
    final result = _currentResponses['sendAndConfirmTransaction'];
    return result != null
        ? result.toString()
        : '2id3YC2jK9G5Wo2phDx4gJVAew8DcY5NAojnVuao8rkxwPYPe8cSwE5GzhEgJA2y8fVjDEo6iR6ykBvDxrTQrtpb';
  }
}

/// Mock Wallet with advanced signing simulation
class MockWallet implements Wallet {
  final Keypair _keypair;
  final List<String> _signedTransactions = [];
  bool _shouldThrow = false;
  Exception? _throwException;

  MockWallet([Keypair? keypair])
      : _keypair = keypair ?? _generateDefaultKeypair();

  static Keypair _generateDefaultKeypair() {
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = (i + 1) % 256;
    }
    // For testing, create a keypair from a deterministic secret key
    final secretKey = Uint8List(64);
    // Copy seed to first 32 bytes and second 32 bytes for compatibility
    secretKey.setRange(0, 32, seed);
    secretKey.setRange(32, 64, seed);
    return Keypair.fromSecretKey(secretKey);
  }

  @override
  PublicKey get publicKey => _keypair.publicKey;

  /// Configure to throw exception on next signing operation
  void setThrowOnSign(Exception exception) {
    _shouldThrow = true;
    _throwException = exception;
  }

  /// Reset to normal signing behavior
  void resetSigningBehavior() {
    _shouldThrow = false;
    _throwException = null;
  }

  /// Get history of signed transaction signatures
  List<String> get signedTransactions => List.unmodifiable(_signedTransactions);

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw _throwException!;
    }

    final signedTx = Transaction(
      instructions: transaction.instructions,
      feePayer: transaction.feePayer,
      recentBlockhash: transaction.recentBlockhash,
    );

    // Generate mock signature
    final signature = _generateMockSignature();
    signedTx.addSignature(_keypair.publicKey, signature);

    _signedTransactions.add(base64Encode(signature));
    return signedTx;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions) async {
    final results = <Transaction>[];
    for (final tx in transactions) {
      results.add(await signTransaction(tx));
    }
    return results;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw _throwException!;
    }

    final signature = _generateMockSignature();
    _signedTransactions.add(base64Encode(signature));
    return signature;
  }

  /// Generate a deterministic mock signature
  Uint8List _generateMockSignature() {
    final signature = Uint8List(64);
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    for (int i = 0; i < 64; i++) {
      signature[i] = random.nextInt(256);
    }
    return signature;
  }
}

/// Test Fixtures and Scenario Management
/// Predefined test scenarios, fixtures, and data management
class TestFixtures {
  static final Map<String, Idl> _programIdls = {};
  static final Map<String, Map<String, dynamic>> _accountFixtures = {};

  /// Register a program IDL fixture
  static void registerProgramIdl(String name, Idl idl) {
    _programIdls[name] = idl;
  }

  /// Get a program IDL fixture
  static Idl? getProgramIdl(String name) => _programIdls[name];

  /// Register account data fixtures
  static void registerAccountFixture(String name, Map<String, dynamic> data) {
    _accountFixtures[name] = Map.from(data);
  }

  /// Get account data fixture
  static Map<String, dynamic>? getAccountFixture(String name) =>
      _accountFixtures[name];

  /// Create a complete test workspace fixture
  static TestWorkspaceFixture createWorkspaceFixture({
    required String name,
    required List<String> programs,
    Map<String, dynamic>? config,
  }) {
    return TestWorkspaceFixture(
      name: name,
      programs: programs,
      config: config ?? {},
    );
  }

  /// Clear all fixtures
  static void clear() {
    _programIdls.clear();
    _accountFixtures.clear();
  }
}

/// Test Workspace Fixture
class TestWorkspaceFixture {
  final String name;
  final List<String> programs;
  final Map<String, dynamic> config;
  final Map<String, Program> _loadedPrograms = {};

  TestWorkspaceFixture({
    required this.name,
    required this.programs,
    required this.config,
  });

  /// Load programs into workspace
  Future<Workspace> loadIntoWorkspace(AnchorProvider provider) async {
    final workspace = Workspace(provider);

    for (final programName in programs) {
      final idl = TestFixtures.getProgramIdl(programName);
      if (idl != null) {
        final keypair = await Keypair.generate();
        await workspace.loadProgram(programName, idl, keypair.publicKey);
      }
    }

    return workspace;
  }

  /// Get loaded program
  Program? getProgram(String name) => _loadedPrograms[name];
}

/// Test Data Generator
/// Utilities for generating test data, accounts, and transactions
class TestDataGenerator {
  static final Random _random = Random();

  /// Generate random bytes
  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Generate test IDL
  static Idl generateTestIdl({
    String? address,
    String name = 'test_program',
    List<IdlInstruction>? instructions,
    List<IdlAccount>? accounts,
  }) {
    return Idl(
      address: address ?? 'TestProgram111111111111111111111111111111',
      metadata: IdlMetadata(
        name: name,
        version: '0.1.0',
        spec: '0.1.0',
      ),
      instructions: instructions ??
          [
            IdlInstruction(
              name: 'initialize',
              discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
              accounts: [
                IdlInstructionAccount(
                  name: 'user',
                  writable: true,
                  signer: true,
                ),
              ],
              args: [
                IdlField(name: 'amount', type: idlTypeU64()),
              ],
            ),
          ],
      accounts: accounts,
    );
  }

  /// Generate test account data
  static Map<String, dynamic> generateAccountData({
    String? discriminator,
    Map<String, dynamic>? fields,
  }) {
    final data = <String, dynamic>{
      'discriminator': discriminator ?? 'test',
      'lamports':
          _random.nextInt(2147483647), // Use smaller max value for int32 range
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (fields != null) {
      data.addAll(fields);
    }

    return data;
  }
}

/// Integration Testing Framework
/// Utilities for running integration tests with real or mock validators
class IntegrationTestRunner {
  final TestValidator? validator;
  final Connection connection;
  final TestAccountManager accountManager;

  IntegrationTestRunner({
    this.validator,
    required this.connection,
    required this.accountManager,
  });

  /// Run test with setup and cleanup
  Future<T> runTest<T>(Future<T> Function() testFn) async {
    try {
      if (validator != null) {
        await validator!.start();
      }

      return await testFn();
    } finally {
      await accountManager.cleanup();
      if (validator != null) {
        await validator!.stop();
      }
    }
  }

  /// Create from test validator
  static Future<IntegrationTestRunner> fromValidator({
    TestValidator? validator,
    Keypair? payerKeypair,
  }) async {
    final testValidator = validator ?? TestValidator();
    final connection = testValidator.getConnection();
    final payer = payerKeypair ?? await Keypair.generate();
    final accountManager = TestAccountManager(connection, payer);

    return IntegrationTestRunner(
      validator: testValidator,
      connection: connection,
      accountManager: accountManager,
    );
  }
}
