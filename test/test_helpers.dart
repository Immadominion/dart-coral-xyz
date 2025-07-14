import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';
import 'dart:math';

/// Mock provider for testing with configurable behavior
class MockProvider extends AnchorProvider {
  MockProvider(super.connection, super.wallet);

  /// Create a mock provider with default test configuration
  factory MockProvider.createDefault() {
    final connection = MockConnection('http://localhost:8899');
    final wallet = MockWallet();
    return MockProvider(connection, wallet);
  }
}

/// Mock connection for testing with configurable responses
class MockConnection extends Connection {

  MockConnection(String endpoint) : super(endpoint);
  final Map<String, dynamic> _mockResponses = {};
  final List<String> _callLog = [];
  bool _shouldThrow = false;
  Exception? _throwException;

  /// Configure the connection to throw an exception on next call
  void setThrowOnNextCall(Exception exception) {
    _shouldThrow = true;
    _throwException = exception;
  }

  /// Set a mock response for a specific RPC method
  void setMockResponse(String method, dynamic response) {
    _mockResponses[method] = response;
  }

  /// Get the log of all RPC calls made
  List<String> get callLog => List.unmodifiable(_callLog);

  /// Clear all mock responses and call logs
  void reset() {
    _mockResponses.clear();
    _callLog.clear();
    _shouldThrow = false;
    _throwException = null;
  }

  // Override key methods for testing
  @override
  Future<String> checkHealth() async {
    _callLog.add('checkHealth');
    if (_shouldThrow) {
      _shouldThrow = false;
      throw _throwException!;
    }
    final result = _mockResponses['checkHealth'];
    return result is String ? result : 'ok';
  }

  @override
  Future<int> getBalance(PublicKey address,
      {CommitmentConfig? commitment,}) async {
    _callLog.add('getBalance:${address.toBase58()}');
    if (_shouldThrow) {
      _shouldThrow = false;
      throw _throwException!;
    }
    final result = _mockResponses['getBalance'];
    return result is int ? result : 1000000000; // 1 SOL default
  }
}

/// Mock wallet for testing with customizable signing behavior
class MockWallet implements Wallet {

  MockWallet([Keypair? keypair])
      : _keypair = keypair ??
            Keypair.fromSecretKey(
                Uint8List.fromList(List.generate(32, (i) => i + 1)));
  final Keypair _keypair;
  bool _shouldThrowOnSign = false;
  Exception? _signException;

  /// Create a mock wallet with a deterministic keypair
  static Future<MockWallet> createWithKeypair([Keypair? keypair]) async {
    final kp = keypair ?? await _generateMockKeypair();
    return MockWallet(kp);
  }

  static Future<Keypair> _generateMockKeypair() async {
    // Generate deterministic keypair for testing
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = i + 1; // Avoid all zeros
    }
    return Keypair.fromSeed(seed);
  }

  @override
  PublicKey get publicKey => _keypair.publicKey;

  /// Configure wallet to throw on signing
  void setThrowOnSign(Exception exception) {
    _shouldThrowOnSign = true;
    _signException = exception;
  }

  /// Reset wallet to normal signing behavior
  void resetSigningBehavior() {
    _shouldThrowOnSign = false;
    _signException = null;
  }

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (_shouldThrowOnSign) {
      _shouldThrowOnSign = false;
      throw _signException!;
    }

    // Mock signing by adding a signature
    final signedTx = Transaction(
      instructions: transaction.instructions,
      feePayer: transaction.feePayer,
      recentBlockhash: transaction.recentBlockhash,
    );

    // Add mock signature
    signedTx.addSignature(_keypair.publicKey, Uint8List(64));
    return signedTx;
  }

  @override
  Future<List<Transaction>> signAllTransactions(
      List<Transaction> transactions,) async {
    final results = <Transaction>[];
    for (final tx in transactions) {
      results.add(await signTransaction(tx));
    }
    return results;
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (_shouldThrowOnSign) {
      _shouldThrowOnSign = false;
      throw _signException!;
    }
    // Return mock signature
    return Uint8List.fromList(List.generate(64, (i) => i % 256));
  }
}

/// Utility to create a test keypair and public key
Future<Keypair> createTestKeypair() async => await Keypair.generate();

/// Create a deterministic test keypair from seed for reproducible tests
Future<Keypair> createDeterministicTestKeypair(int seed) async {
  final random = Random(seed);
  final seedBytes = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    seedBytes[i] = random.nextInt(256);
  }
  return Keypair.fromSeed(seedBytes);
}

/// Utility to create a test account data map
Map<String, dynamic> createTestAccountData({
  String name = 'test',
  int lamports = 1000,
  Map<String, dynamic>? extraFields,
}) {
  final data = {
    'name': name,
    'lamports': lamports,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  };

  if (extraFields != null) {
    data.addAll(extraFields.cast<String, Object>());
  }

  return data;
}

/// Helper for building test TransactionInstruction
TransactionInstruction buildTestInstruction({
  required PublicKey programId,
  List<AccountMeta> accounts = const [],
  List<int> data = const [],
  String? instructionName,
}) => TransactionInstruction(
    programId: programId,
    accounts: accounts,
    data: Uint8List.fromList(data),
  );

/// Create a test IDL for testing purposes
Idl createTestIdl({
  String? address,
  String name = 'test_program',
  List<IdlInstruction>? instructions,
  List<IdlAccount>? accounts,
  List<IdlTypeDef>? types,
}) => Idl(
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
    types: types,
  );

/// Create a test program with mock provider
Program createTestProgram({
  Idl? idl,
  AnchorProvider? provider,
}) {
  final testIdl = idl ?? createTestIdl();
  final testProvider = provider ?? MockProvider.createDefault();
  return Program(testIdl, provider: testProvider);
}

/// Assertion helper for Anchor account data
void expectAnchorAccount(
  Map<String, dynamic>? account, {
  required String expectedName,
  int? expectedLamports,
  Map<String, dynamic>? expectedFields,
}) {
  expect(account, isNotNull, reason: 'Account should not be null');
  expect(account!['name'], equals(expectedName),
      reason: 'Account name mismatch',);

  if (expectedLamports != null) {
    expect(account['lamports'], equals(expectedLamports),
        reason: 'Lamports mismatch',);
  }

  if (expectedFields != null) {
    for (final entry in expectedFields.entries) {
      expect(account[entry.key], equals(entry.value),
          reason: 'Field ${entry.key} mismatch',);
    }
  }
}

/// Assertion helper for transaction instructions
void expectTransactionInstruction(
  TransactionInstruction instruction, {
  required PublicKey expectedProgramId,
  int? expectedAccountCount,
  int? expectedDataLength,
  List<AccountMeta>? expectedAccounts,
}) {
  expect(instruction.programId, equals(expectedProgramId),
      reason: 'Program ID mismatch',);

  if (expectedAccountCount != null) {
    expect(instruction.accounts.length, equals(expectedAccountCount),
        reason: 'Account count mismatch',);
  }

  if (expectedDataLength != null) {
    expect(instruction.data.length, equals(expectedDataLength),
        reason: 'Data length mismatch',);
  }

  if (expectedAccounts != null) {
    expect(instruction.accounts.length, equals(expectedAccounts.length),
        reason: 'Expected accounts count mismatch',);

    for (int i = 0; i < expectedAccounts.length; i++) {
      final actual = instruction.accounts[i];
      final expected = expectedAccounts[i];

      expect(actual.pubkey, equals(expected.pubkey),
          reason: 'Account $i pubkey mismatch',);
      expect(actual.isSigner, equals(expected.isSigner),
          reason: 'Account $i signer flag mismatch',);
      expect(actual.isWritable, equals(expected.isWritable),
          reason: 'Account $i writable flag mismatch',);
    }
  }
}

/// Assertion helper for Program instances
void expectProgram(
  Program program, {
  required String expectedAddress,
  required String expectedName,
  int? expectedInstructionCount,
  int? expectedAccountCount,
}) {
  expect(program.programId.toBase58(), equals(expectedAddress),
      reason: 'Program address mismatch',);
  expect(program.idl.metadata?.name, equals(expectedName),
      reason: 'Program name mismatch',);

  if (expectedInstructionCount != null) {
    expect(program.idl.instructions.length, equals(expectedInstructionCount),
        reason: 'Instruction count mismatch',);
  }

  if (expectedAccountCount != null) {
    expect(program.idl.accounts?.length ?? 0, equals(expectedAccountCount),
        reason: 'Account type count mismatch',);
  }
}

/// Test utility for measuring execution time
class TestTimer {
  DateTime? _startTime;

  void start() {
    _startTime = DateTime.now();
  }

  Duration stop() {
    if (_startTime == null) throw StateError('Timer not started');
    final duration = DateTime.now().difference(_startTime!);
    _startTime = null;
    return duration;
  }
}

/// Test utility for capturing and asserting on function calls
class CallCapture {
  final List<String> _calls = [];

  void record(String call) {
    _calls.add(call);
  }

  List<String> get calls => List.unmodifiable(_calls);

  void expectCall(String expectedCall) {
    expect(_calls, contains(expectedCall),
        reason: 'Expected call not found: $expectedCall',);
  }

  void expectCallCount(int expectedCount) {
    expect(_calls.length, equals(expectedCount), reason: 'Call count mismatch');
  }

  void expectCallOrder(List<String> expectedOrder) {
    expect(_calls, equals(expectedOrder), reason: 'Call order mismatch');
  }

  void clear() {
    _calls.clear();
  }
}
