// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from IDL: test_program
// Version: 0.1.0
// Generated at: 2025-07-21T14:00:35.707942

import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart' as tx;
import 'package:solana/solana.dart' as solana;

/// Program ID for test_program
const String kProgramId = '11111111111111111111111111111112';

/// Main program interface for test_program
class TestProgramProgram extends Program {
  /// Creates a new TestProgramProgram instance
  TestProgramProgram({
    required PublicKey programId,
    AnchorProvider? provider,
  }) : super.withProgramId(Idl.fromJson(programIdl), programId,
            provider: provider);

  /// initialize instruction
  InitializeInstructionBuilder initialize({
    BigInt? amount,
  }) {
    return InitializeInstructionBuilder(
      program: this,
      amount: amount,
    );
  }

  /// update instruction
  UpdateInstructionBuilder update({
    String? newvalue,
  }) {
    return UpdateInstructionBuilder(
      program: this,
      newvalue: newvalue,
    );
  }

  /// Get the program IDL
  static const Map<String, dynamic> programIdl = {
    'version': '0.1.0',
    'name': 'test_program',
    'instructions': [
      {
        'name': 'initialize',
        'args': [
          {
            'name': 'amount',
            'type': 'u64',
          },
        ],
      },
      {
        'name': 'update',
        'args': [
          {
            'name': 'newValue',
            'type': 'string',
          },
        ],
      },
    ],
  };
}

/// Account data class for TestAccount
class TestaccountAccount {
  /// Creates a new TestaccountAccount
  const TestaccountAccount({
    required this.authority,
    required this.value,
    required this.name,
  });

  /// authority field
  final PublicKey authority;

  /// value field
  final BigInt value;

  /// name field
  final String name;

  /// Create TestaccountAccount from bytes
  static TestaccountAccount fromBytes(List<int> bytes) {
    final reader = BinaryReader(Uint8List.fromList(bytes).buffer.asByteData());
    return TestaccountAccount.fromReader(reader);
  }

  /// Create TestaccountAccount from BinaryReader
  static TestaccountAccount fromReader(BinaryReader reader) {
    final authority = PublicKey.fromBytes(reader.readBytes(32));
    final value = reader.readU64();
    final name = reader.readString();
    return TestaccountAccount(
      authority: authority,
      value: value,
      name: name,
    );
  }

  /// Convert TestaccountAccount to bytes
  List<int> toBytes() {
    final writer = BinaryWriter();
    writeToWriter(writer);
    return writer.toArray();
  }

  /// Write TestaccountAccount to BinaryWriter
  void writeToWriter(BinaryWriter writer) {
    writer.writeBytes(authority.toBytes());
    writer.writeU64(value);
    writer.writeString(name);
  }

  @override
  String toString() {
    return 'TestaccountAccount(' +
        'authority: $authority, ' +
        'value: $value, ' +
        'name: $name' +
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TestaccountAccount) return false;
    return authority == other.authority &&
        value == other.value &&
        name == other.name;
  }

  @override
  int get hashCode {
    return Object.hash(
      authority,
      value,
      name,
    );
  }
}

/// Accounts configuration for initialize instruction
class InitializeAccounts {
  /// Creates a new InitializeAccounts
  const InitializeAccounts({
    required this.user,
    required this.systemprogram,
  });

  /// user account
  final PublicKey user;

  /// systemProgram account
  final PublicKey systemprogram;

  /// Convert accounts to map
  Map<String, PublicKey> toMap() {
    final map = <String, PublicKey>{};
    map['user'] = user;
    map['systemProgram'] = systemprogram;
    return map;
  }
}

/// Builder for initialize instruction
class InitializeInstructionBuilder {
  /// Creates a new InitializeInstructionBuilder
  InitializeInstructionBuilder({
    required this.program,
    this.amount,
  });

  /// Program instance
  final Program program;

  /// amount argument
  final BigInt? amount;

  /// Create instruction - simplified for testing
  Future<tx.TransactionInstruction> instruction() async {
    // For testing purposes, create a basic instruction
    return tx.TransactionInstruction(
      programId: program.programId,
      accounts: [
        tx.AccountMeta(
          pubkey: program.provider.wallet?.publicKey ??
              PublicKey.fromBase58('11111111111111111111111111111111'),
          isSigner: true,
          isWritable: true,
        ),
      ],
      data: Uint8List.fromList([1, 2, 3, 4]), // Placeholder data
    );
  }

  /// Send and confirm transaction
  Future<String> rpc({
    solana.Commitment? commitment,
    List<PublicKey>? signers,
    Map<String, dynamic>? options,
  }) async {
    final instruction = await this.instruction();
    final transaction = tx.Transaction(
      instructions: [instruction],
      feePayer: program.provider.wallet?.publicKey,
    );
    return await program.provider.sendAndConfirm(transaction);
  }

  /// Simulate transaction
  Future<TransactionSimulationResult> simulate({
    solana.Commitment? commitment,
    List<PublicKey>? signers,
    Map<String, dynamic>? options,
  }) async {
    final instruction = await this.instruction();
    final transaction = tx.Transaction(
      instructions: [instruction],
      feePayer: program.provider.wallet?.publicKey,
    );
    return await program.provider.simulate(transaction);
  }
}

/// Accounts configuration for update instruction
class UpdateAccounts {
  /// Creates a new UpdateAccounts
  const UpdateAccounts({
    required this.user,
    required this.account,
  });

  /// user account
  final PublicKey user;

  /// account account
  final PublicKey account;

  /// Convert accounts to map
  Map<String, PublicKey> toMap() {
    final map = <String, PublicKey>{};
    map['user'] = user;
    map['account'] = account;
    return map;
  }
}

/// Builder for update instruction
class UpdateInstructionBuilder {
  /// Creates a new UpdateInstructionBuilder
  UpdateInstructionBuilder({
    required this.program,
    this.newvalue,
  });

  /// Program instance
  final Program program;

  /// newValue argument
  final String? newvalue;

  /// Create instruction - simplified for testing
  Future<tx.TransactionInstruction> instruction() async {
    // For testing purposes, create a basic instruction
    return tx.TransactionInstruction(
      programId: program.programId,
      accounts: [
        tx.AccountMeta(
          pubkey: program.provider.wallet?.publicKey ??
              PublicKey.fromBase58('11111111111111111111111111111111'),
          isSigner: true,
          isWritable: true,
        ),
      ],
      data: Uint8List.fromList([1, 2, 3, 4]), // Placeholder data
    );
  }

  /// Send and confirm transaction
  Future<String> rpc({
    solana.Commitment? commitment,
    List<PublicKey>? signers,
    Map<String, dynamic>? options,
  }) async {
    final instruction = await this.instruction();
    final transaction = tx.Transaction(
      instructions: [instruction],
      feePayer: program.provider.wallet?.publicKey,
    );
    return await program.provider.sendAndConfirm(transaction);
  }

  /// Simulate transaction
  Future<TransactionSimulationResult> simulate({
    solana.Commitment? commitment,
    List<PublicKey>? signers,
    Map<String, dynamic>? options,
  }) async {
    final instruction = await this.instruction();
    final transaction = tx.Transaction(
      instructions: [instruction],
      feePayer: program.provider.wallet?.publicKey,
    );
    return await program.provider.simulate(transaction);
  }
}

/// Error class for test_program program
class TestProgramError extends ProgramError {
  /// Creates a new TestProgramError
  TestProgramError._({
    required int code,
    required String message,
  }) : super(
          code: code,
          msg: message,
        );

  /// InvalidAmount error
  /// Message: The amount is invalid
  static final invalidamount =
      TestProgramError._(code: 6000, message: 'The amount is invalid');

  /// Map of error codes to error instances
  static final Map<int, TestProgramError> _errorMap = {
    6000: invalidamount,
  };

  /// Create error from error code
  static TestProgramError? fromCode(int code) {
    return _errorMap[code];
  }

  @override
  String toString() {
    return 'TestProgramError(code: $code, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TestProgramError) return false;
    return code == other.code && message == other.message;
  }

  @override
  int get hashCode {
    return Object.hash(code, message);
  }

  /// List of all program errors
  static List<TestProgramError> get allErrors => [
        invalidamount,
      ];
}
