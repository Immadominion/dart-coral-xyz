/// Native Solana System Program utilities.
/// Provides TypeScript-like system program functionality.
library system_program;

import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';

/// Solana System Program utilities
class SystemProgram {
  /// System Program ID
  static final PublicKey programId = PublicKey.fromBase58(
    '11111111111111111111111111111112',
  );

  /// Create account instruction
  static TransactionInstruction createAccount({
    required PublicKey fromPubkey,
    required PublicKey newAccountPubkey,
    required int lamports,
    required int space,
    required PublicKey programId,
  }) =>
      TransactionInstruction(
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

  /// Close account instruction (generic, transfers lamports to destination)
  static TransactionInstruction closeAccount({
    required PublicKey account,
    required PublicKey destination,
    PublicKey? authority,
  }) {
    return TransactionInstruction(
      programId: SystemProgram.programId,
      accounts: [
        AccountMeta(pubkey: account, isSigner: false, isWritable: true),
        AccountMeta(pubkey: destination, isSigner: false, isWritable: true),
        if (authority != null)
          AccountMeta(pubkey: authority, isSigner: true, isWritable: false),
      ],
      data: Uint8List(0), // No data for generic close
    );
  }

  /// Transfer instruction
  static TransactionInstruction transfer({
    required PublicKey fromPubkey,
    required PublicKey toPubkey,
    required int lamports,
  }) =>
      TransactionInstruction(
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

  /// Assign account to program instruction
  static TransactionInstruction assign({
    required PublicKey accountPubkey,
    required PublicKey programId,
  }) =>
      TransactionInstruction(
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

  /// Allocate space for account instruction
  static TransactionInstruction allocate({
    required PublicKey accountPubkey,
    required int space,
  }) =>
      TransactionInstruction(
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

  /// Encode create account instruction data
  static Uint8List _encodeCreateAccountData({
    required int lamports,
    required int space,
    required PublicKey programId,
  }) {
    final data = Uint8List(52); // 4 + 8 + 8 + 32
    var offset = 0;

    // Instruction discriminator (0 = CreateAccount)
    _setUint32LE(data, offset, 0);
    offset += 4;

    // Lamports (8 bytes)
    _setUint64LE(data, offset, lamports);
    offset += 8;

    // Space (8 bytes)
    _setUint64LE(data, offset, space);
    offset += 8;

    // Program ID (32 bytes)
    data.setAll(offset, programId.toBytes());

    return data;
  }

  /// Encode transfer instruction data
  static Uint8List _encodeTransferData({required int lamports}) {
    final data = Uint8List(12); // 4 + 8
    var offset = 0;

    // Instruction discriminator (2 = Transfer)
    _setUint32LE(data, offset, 2);
    offset += 4;

    // Lamports (8 bytes)
    _setUint64LE(data, offset, lamports);

    return data;
  }

  /// Encode assign instruction data
  static Uint8List _encodeAssignData({required PublicKey programId}) {
    final data = Uint8List(36); // 4 + 32
    var offset = 0;

    // Instruction discriminator (1 = Assign)
    _setUint32LE(data, offset, 1);
    offset += 4;

    // Program ID (32 bytes)
    data.setAll(offset, programId.toBytes());

    return data;
  }

  /// Encode allocate instruction data
  static Uint8List _encodeAllocateData({required int space}) {
    final data = Uint8List(12); // 4 + 8
    var offset = 0;

    // Instruction discriminator (8 = Allocate)
    _setUint32LE(data, offset, 8);
    offset += 4;

    // Space (8 bytes)
    _setUint64LE(data, offset, space);

    return data;
  }

  /// Set 32-bit little-endian value
  static void _setUint32LE(Uint8List buffer, int offset, int value) {
    buffer[offset] = value & 0xFF;
    buffer[offset + 1] = (value >> 8) & 0xFF;
    buffer[offset + 2] = (value >> 16) & 0xFF;
    buffer[offset + 3] = (value >> 24) & 0xFF;
  }

  /// Set 64-bit little-endian value
  static void _setUint64LE(Uint8List buffer, int offset, int value) {
    // For simplicity, only handle values up to 2^53
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
