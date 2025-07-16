// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AnchorGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from IDL: test_program
// Version: 0.1.0
// Generated at: 2025-07-15T03:08:19.704872

import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:solana/solana.dart';
import 'package:borsh/borsh.dart';

/// Program ID for test_program
const String kProgramId = '11111111111111111111111111111112';

/// Main program interface for test_program
class TestProgram extends Program {
  /// Creates a new TestProgram instance
  TestProgram({
    required super.programId,
    required super.provider,
  });

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
  static const Map<String, dynamic> idl = {
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
class Testaccount {
  /// Creates a new Testaccount
  const Testaccount({
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

  /// Create Testaccount from bytes
  static Testaccount fromBytes(List<int> bytes) {
    final reader = BinaryReader(bytes);
    return Testaccount.fromReader(reader);
  }

  /// Create Testaccount from BinaryReader
  static Testaccount fromReader(BinaryReader reader) {
    final authority = PublicKey.fromBytes(reader.readBytes(32));
    final value = reader.readU64();
    final name = reader.readString();
    return Testaccount(
      authority: authority,
      value: value,
      name: name,
    );
  }

  /// Convert Testaccount to bytes
  List<int> toBytes() {
    final writer = BinaryWriter();
    writeToWriter(writer);
    return writer.toBytes();
  }

  /// Write Testaccount to BinaryWriter
  void writeToWriter(BinaryWriter writer) {
    writer.writeBytes(authority.toBytes());
    writer.writeU64(value);
    writer.writeString(name);
  }

  @override
  String toString() {
    return 'Testaccount(' +
        'authority: $authority, ' +
        'value: $value, ' +
        'name: $name' +
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Testaccount) return false;
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
class InitializeInstructionBuilder extends InstructionBuilder {
  /// Creates a new InitializeInstructionBuilder
  InitializeInstructionBuilder({
    required super.program,
    this.amount,
  });

  /// amount parameter
  final BigInt? amount;

  /// Configure accounts for this instruction
  InitializeInstructionBuilder accounts(InitializeAccounts accounts) {
    return InitializeInstructionBuilder(
      program: program,
      amount: amount,
    )..accountsConfig = accounts;
  }

  /// Configure signers for this instruction
  InitializeInstructionBuilder signers(List<Signer> signers) {
    return InitializeInstructionBuilder(
      program: program,
      amount: amount,
    )..signersConfig = signers;
  }

  /// Add pre-instructions to this instruction
  InitializeInstructionBuilder preInstructions(
      List<TransactionInstruction> instructions) {
    return InitializeInstructionBuilder(
      program: program,
      amount: amount,
    )..preInstructionsConfig = instructions;
  }

  /// Add post-instructions to this instruction
  InitializeInstructionBuilder postInstructions(
      List<TransactionInstruction> instructions) {
    return InitializeInstructionBuilder(
      program: program,
      amount: amount,
    )..postInstructionsConfig = instructions;
  }

  /// Build the instruction
  @override
  Future<TransactionInstruction> instruction() async {
    final args = <String, dynamic>{};
    if (amount != null) {
      args['amount'] = amount;
    }
    return program.instruction(
      'initialize',
      args,
      accounts: accountsConfig?.toMap() ?? {},
    );
  }

  /// Execute the instruction via RPC
  @override
  Future<String> rpc({
    Commitment? commitment,
    bool? skipPreflight,
    int? maxRetries,
  }) async {
    final instruction = await this.instruction();
    return program.rpc(
      instruction,
      signers: signersConfig ?? [],
      commitment: commitment,
      skipPreflight: skipPreflight,
      maxRetries: maxRetries,
    );
  }

  /// Simulate the instruction
  @override
  Future<SimulateTransactionResponse> simulate({
    Commitment? commitment,
    bool? sigVerify,
    bool? replaceRecentBlockhash,
  }) async {
    final instruction = await this.instruction();
    return program.simulate(
      instruction,
      signers: signersConfig ?? [],
      commitment: commitment,
      sigVerify: sigVerify,
      replaceRecentBlockhash: replaceRecentBlockhash,
    );
  }

  /// Accounts configuration
  InitializeAccounts? accountsConfig;

  /// Signers configuration
  List<Signer>? signersConfig;

  /// Pre-instructions configuration
  List<TransactionInstruction>? preInstructionsConfig;

  /// Post-instructions configuration
  List<TransactionInstruction>? postInstructionsConfig;
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
class UpdateInstructionBuilder extends InstructionBuilder {
  /// Creates a new UpdateInstructionBuilder
  UpdateInstructionBuilder({
    required super.program,
    this.newvalue,
  });

  /// newValue parameter
  final String? newvalue;

  /// Configure accounts for this instruction
  UpdateInstructionBuilder accounts(UpdateAccounts accounts) {
    return UpdateInstructionBuilder(
      program: program,
      newvalue: newvalue,
    )..accountsConfig = accounts;
  }

  /// Configure signers for this instruction
  UpdateInstructionBuilder signers(List<Signer> signers) {
    return UpdateInstructionBuilder(
      program: program,
      newvalue: newvalue,
    )..signersConfig = signers;
  }

  /// Add pre-instructions to this instruction
  UpdateInstructionBuilder preInstructions(
      List<TransactionInstruction> instructions) {
    return UpdateInstructionBuilder(
      program: program,
      newvalue: newvalue,
    )..preInstructionsConfig = instructions;
  }

  /// Add post-instructions to this instruction
  UpdateInstructionBuilder postInstructions(
      List<TransactionInstruction> instructions) {
    return UpdateInstructionBuilder(
      program: program,
      newvalue: newvalue,
    )..postInstructionsConfig = instructions;
  }

  /// Build the instruction
  @override
  Future<TransactionInstruction> instruction() async {
    final args = <String, dynamic>{};
    if (newvalue != null) {
      args['newValue'] = newvalue;
    }
    return program.instruction(
      'update',
      args,
      accounts: accountsConfig?.toMap() ?? {},
    );
  }

  /// Execute the instruction via RPC
  @override
  Future<String> rpc({
    Commitment? commitment,
    bool? skipPreflight,
    int? maxRetries,
  }) async {
    final instruction = await this.instruction();
    return program.rpc(
      instruction,
      signers: signersConfig ?? [],
      commitment: commitment,
      skipPreflight: skipPreflight,
      maxRetries: maxRetries,
    );
  }

  /// Simulate the instruction
  @override
  Future<SimulateTransactionResponse> simulate({
    Commitment? commitment,
    bool? sigVerify,
    bool? replaceRecentBlockhash,
  }) async {
    final instruction = await this.instruction();
    return program.simulate(
      instruction,
      signers: signersConfig ?? [],
      commitment: commitment,
      sigVerify: sigVerify,
      replaceRecentBlockhash: replaceRecentBlockhash,
    );
  }

  /// Accounts configuration
  UpdateAccounts? accountsConfig;

  /// Signers configuration
  List<Signer>? signersConfig;

  /// Pre-instructions configuration
  List<TransactionInstruction>? preInstructionsConfig;

  /// Post-instructions configuration
  List<TransactionInstruction>? postInstructionsConfig;
}

/// Error class for test_program program
class TestProgramError extends ProgramError {
  /// Creates a new TestProgramError
  const TestProgramError._(super.code, super.message);

  /// InvalidAmount error
  /// Message: The amount provided is invalid
  static const invalidamount =
      TestProgramError._(6000, 'The amount provided is invalid');

  /// Unauthorized error
  /// Message: Unauthorized access
  static const unauthorized = TestProgramError._(6001, 'Unauthorized access');

  /// Map of error codes to error instances
  static const Map<int, TestProgramError> _errorMap = {
    6000: invalidamount,
    6001: unauthorized,
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
        unauthorized,
      ];
}

/// Enum type: Status
enum Status {
  /// Active variant
  active,

  /// Inactive variant
  inactive,
}

/// Extension for Status enum
extension StatusExtension on Status {
  /// Create enum from index
  static Status fromIndex(int index) {
    return Status.values[index];
  }

  /// Get index of enum value
  int get index => Status.values.indexOf(this);

  /// Get name of enum value
  String get name {
    switch (this) {
      case Status.active:
        return 'Active';
      case Status.inactive:
        return 'Inactive';
    }
  }
}
