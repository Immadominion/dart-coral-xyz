/// Native Solana System Program utilities.
/// Provides TypeScript-like system program functionality.
library;

import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/transaction.dart';

/// Solana System Program utilities
class SystemProgram {
  /// System Program ID
  static final PublicKey programId = PublicKey.fromBase58(
    '11111111111111111111111111111111',
  );

  /// Create account instruction
  static TransactionInstruction createAccount({
    required PublicKey fromPubkey,
    required PublicKey newAccountPubkey,
    required int lamports,
    required int space,
    required PublicKey programId,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(
          pubkey: fromPubkey,
          isSigner: true,
          isWritable: true,
        ),
        AccountMeta(
          pubkey: newAccountPubkey,
          isSigner: true,
          isWritable: true,
        ),
      ],
      data: _encodeCreateAccountData(
        lamports: lamports,
        space: space,
        programId: programId,
      ),
    );
  }

  /// Transfer instruction
  static TransactionInstruction transfer({
    required PublicKey fromPubkey,
    required PublicKey toPubkey,
    required int lamports,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(
          pubkey: fromPubkey,
          isSigner: true,
          isWritable: true,
        ),
        AccountMeta(
          pubkey: toPubkey,
          isSigner: false,
          isWritable: true,
        ),
      ],
      data: _encodeTransferData(lamports: lamports),
    );
  }

  /// Assign account to program instruction
  static TransactionInstruction assign({
    required PublicKey accountPubkey,
    required PublicKey programId,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(
          pubkey: accountPubkey,
          isSigner: true,
          isWritable: true,
        ),
      ],
      data: _encodeAssignData(programId: programId),
    );
  }

  /// Allocate space for account instruction
  static TransactionInstruction allocate({
    required PublicKey accountPubkey,
    required int space,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(
          pubkey: accountPubkey,
          isSigner: true,
          isWritable: true,
        ),
      ],
      data: _encodeAllocateData(space: space),
    );
  }

  /// Create account with seed instruction
  static TransactionInstruction createAccountWithSeed({
    required PublicKey fromPubkey,
    required PublicKey newAccountPubkey,
    required PublicKey basePubkey,
    required String seed,
    required int lamports,
    required int space,
    required PublicKey programId,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(
          pubkey: fromPubkey,
          isSigner: true,
          isWritable: true,
        ),
        AccountMeta(
          pubkey: newAccountPubkey,
          isSigner: false,
          isWritable: true,
        ),
        AccountMeta(
          pubkey: basePubkey,
          isSigner: true,
          isWritable: false,
        ),
      ],
      data: _encodeCreateAccountWithSeedData(
        basePubkey: basePubkey,
        seed: seed,
        lamports: lamports,
        space: space,
        programId: programId,
      ),
    );
  }

  /// Transfer with seed instruction
  static TransactionInstruction transferWithSeed({
    required PublicKey fromPubkey,
    required PublicKey toPubkey,
    required PublicKey basePubkey,
    required String seed,
    required int lamports,
    required PublicKey fromOwner,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(
          pubkey: fromPubkey,
          isSigner: false,
          isWritable: true,
        ),
        AccountMeta(
          pubkey: basePubkey,
          isSigner: true,
          isWritable: false,
        ),
        AccountMeta(
          pubkey: toPubkey,
          isSigner: false,
          isWritable: true,
        ),
      ],
      data: _encodeTransferWithSeedData(
        lamports: lamports,
        seed: seed,
        fromOwner: fromOwner,
      ),
    );
  }

  /// Get minimum balance for rent exemption
  static Future<int> getMinimumBalanceForRentExemption(
    int dataLength,
    // Connection would be passed here in real implementation
  ) async {
    // Simplified calculation - in real implementation this would
    // call the connection's getMinimumBalanceForRentExemption method
    return (dataLength + 128) * 6960; // Rough estimate
  }

  /// Encode create account instruction data
  static Uint8List _encodeCreateAccountData({
    required int lamports,
    required int space,
    required PublicKey programId,
  }) {
    final data = Uint8List(52); // 4 + 8 + 8 + 32
    var offset = 0;

    // Instruction discriminator (0 = CreateAccount)
    data.setAll(offset, [0, 0, 0, 0]);
    offset += 4;

    // Lamports (8 bytes, little-endian)
    _setUint64LE(data, offset, lamports);
    offset += 8;

    // Space (8 bytes, little-endian)
    _setUint64LE(data, offset, space);
    offset += 8;

    // Program ID (32 bytes)
    data.setAll(offset, programId.bytes);

    return data;
  }

  /// Encode transfer instruction data
  static Uint8List _encodeTransferData({required int lamports}) {
    final data = Uint8List(12); // 4 + 8
    var offset = 0;

    // Instruction discriminator (2 = Transfer)
    data.setAll(offset, [2, 0, 0, 0]);
    offset += 4;

    // Lamports (8 bytes, little-endian)
    _setUint64LE(data, offset, lamports);

    return data;
  }

  /// Encode assign instruction data
  static Uint8List _encodeAssignData({required PublicKey programId}) {
    final data = Uint8List(36); // 4 + 32
    var offset = 0;

    // Instruction discriminator (1 = Assign)
    data.setAll(offset, [1, 0, 0, 0]);
    offset += 4;

    // Program ID (32 bytes)
    data.setAll(offset, programId.bytes);

    return data;
  }

  /// Encode allocate instruction data
  static Uint8List _encodeAllocateData({required int space}) {
    final data = Uint8List(12); // 4 + 8
    var offset = 0;

    // Instruction discriminator (8 = Allocate)
    data.setAll(offset, [8, 0, 0, 0]);
    offset += 4;

    // Space (8 bytes, little-endian)
    _setUint64LE(data, offset, space);

    return data;
  }

  /// Encode create account with seed instruction data
  static Uint8List _encodeCreateAccountWithSeedData({
    required PublicKey basePubkey,
    required String seed,
    required int lamports,
    required int space,
    required PublicKey programId,
  }) {
    final seedBytes = Uint8List.fromList(seed.codeUnits);
    final data = Uint8List(32 + 4 + seedBytes.length + 8 + 8 + 32);
    var offset = 0;

    // Instruction discriminator (3 = CreateAccountWithSeed)
    data.setAll(offset, [3, 0, 0, 0]);
    offset += 4;

    // Base pubkey (32 bytes)
    data.setAll(offset, basePubkey.bytes);
    offset += 32;

    // Seed length (4 bytes, little-endian)
    _setUint32LE(data, offset, seedBytes.length);
    offset += 4;

    // Seed bytes
    data.setAll(offset, seedBytes);
    offset += seedBytes.length;

    // Lamports (8 bytes, little-endian)
    _setUint64LE(data, offset, lamports);
    offset += 8;

    // Space (8 bytes, little-endian)
    _setUint64LE(data, offset, space);
    offset += 8;

    // Program ID (32 bytes)
    data.setAll(offset, programId.bytes);

    return data;
  }

  /// Encode transfer with seed instruction data
  static Uint8List _encodeTransferWithSeedData({
    required int lamports,
    required String seed,
    required PublicKey fromOwner,
  }) {
    final seedBytes = Uint8List.fromList(seed.codeUnits);
    final data = Uint8List(4 + 8 + 4 + seedBytes.length + 32);
    var offset = 0;

    // Instruction discriminator (11 = TransferWithSeed)
    data.setAll(offset, [11, 0, 0, 0]);
    offset += 4;

    // Lamports (8 bytes, little-endian)
    _setUint64LE(data, offset, lamports);
    offset += 8;

    // Seed length (4 bytes, little-endian)
    _setUint32LE(data, offset, seedBytes.length);
    offset += 4;

    // Seed bytes
    data.setAll(offset, seedBytes);
    offset += seedBytes.length;

    // From owner (32 bytes)
    data.setAll(offset, fromOwner.bytes);

    return data;
  }

  /// Set 32-bit unsigned integer in little-endian format
  static void _setUint32LE(Uint8List buffer, int offset, int value) {
    buffer[offset] = value & 0xFF;
    buffer[offset + 1] = (value >> 8) & 0xFF;
    buffer[offset + 2] = (value >> 16) & 0xFF;
    buffer[offset + 3] = (value >> 24) & 0xFF;
  }

  /// Set 64-bit unsigned integer in little-endian format
  static void _setUint64LE(Uint8List buffer, int offset, int value) {
    buffer[offset] = value & 0xFF;
    buffer[offset + 1] = (value >> 8) & 0xFF;
    buffer[offset + 2] = (value >> 16) & 0xFF;
    buffer[offset + 3] = (value >> 24) & 0xFF;
    buffer[offset + 4] = (value >> 32) & 0xFF;
    buffer[offset + 5] = (value >> 40) & 0xFF;
    buffer[offset + 6] = (value >> 48) & 0xFF;
    buffer[offset + 7] = (value >> 56) & 0xFF;
  }
}

/// System program instruction types
enum SystemInstructionType {
  createAccount,
  assign,
  transfer,
  createAccountWithSeed,
  advanceNonceAccount,
  withdrawNonceAccount,
  initializeNonceAccount,
  authorizeNonceAccount,
  allocate,
  allocateWithSeed,
  assignWithSeed,
  transferWithSeed,
}

/// System program utility functions
class SystemProgramUtils {
  /// Calculate the size needed for an account
  static int calculateAccountSize(Map<String, dynamic> accountLayout) {
    // Simplified calculation - in real implementation this would
    // analyze the account layout structure
    return 1024; // Default size
  }

  /// Check if an address is a valid system program instruction
  static bool isSystemProgramInstruction(TransactionInstruction instruction) {
    return instruction.programId == SystemProgram.programId;
  }

  /// Decode system program instruction type
  static SystemInstructionType? decodeInstructionType(
    TransactionInstruction instruction,
  ) {
    if (!isSystemProgramInstruction(instruction)) return null;
    if (instruction.data.isEmpty) return null;

    final discriminator = instruction.data[0];
    switch (discriminator) {
      case 0:
        return SystemInstructionType.createAccount;
      case 1:
        return SystemInstructionType.assign;
      case 2:
        return SystemInstructionType.transfer;
      case 3:
        return SystemInstructionType.createAccountWithSeed;
      case 8:
        return SystemInstructionType.allocate;
      case 11:
        return SystemInstructionType.transferWithSeed;
      default:
        return null;
    }
  }

  /// Extract lamports from transfer instruction
  static int? extractTransferAmount(TransactionInstruction instruction) {
    final type = decodeInstructionType(instruction);
    if (type != SystemInstructionType.transfer) return null;
    if (instruction.data.length < 12) return null;

    // Extract lamports from bytes 4-11 (little-endian)
    int lamports = 0;
    for (int i = 0; i < 8; i++) {
      lamports |= instruction.data[4 + i] << (i * 8);
    }
    return lamports;
  }
}
