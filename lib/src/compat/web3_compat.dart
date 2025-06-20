/// Web3.js compatibility layer for Dart/Coral
/// Provides TypeScript/Web3.js-like APIs and utilities
library web3_compat;

import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/keypair.dart';
import '../types/transaction.dart';

/// Web3.js compatible Connection class wrapper
/// Provides TypeScript-like APIs for Solana connections
class Web3Connection {
  // Note: Connection implementation would be injected here
  // final Connection _connection;

  Web3Connection(/* Connection connection */) /* : _connection = connection */;

  /// Get recent blockhash (Web3.js style)
  Future<Map<String, dynamic>> getRecentBlockhash([String? commitment]) async {
    // This would delegate to the actual connection implementation
    throw UnimplementedError(
        'Web3Connection.getRecentBlockhash not yet implemented');
  }

  /// Send transaction (Web3.js style)
  Future<String> sendTransaction(Transaction transaction,
      [Map<String, dynamic>? options]) async {
    throw UnimplementedError(
        'Web3Connection.sendTransaction not yet implemented');
  }

  /// Confirm transaction (Web3.js style)
  Future<Map<String, dynamic>> confirmTransaction(String signature,
      [String? commitment]) async {
    throw UnimplementedError(
        'Web3Connection.confirmTransaction not yet implemented');
  }

  /// Get account info (Web3.js style)
  Future<Map<String, dynamic>?> getAccountInfo(PublicKey publicKey,
      [String? commitment]) async {
    throw UnimplementedError(
        'Web3Connection.getAccountInfo not yet implemented');
  }

  /// Get balance (Web3.js style)
  Future<int> getBalance(PublicKey publicKey, [String? commitment]) async {
    throw UnimplementedError('Web3Connection.getBalance not yet implemented');
  }
}

/// Web3.js compatible PublicKey extensions
extension Web3PublicKey on PublicKey {
  /// Create from base58 string (Web3.js style)
  static PublicKey fromBase58(String base58) => PublicKey.fromBase58(base58);

  /// Create from buffer/bytes (Web3.js style)
  static PublicKey fromBuffer(Uint8List buffer) => PublicKey.fromBytes(buffer);

  /// Convert to base58 string (Web3.js style)
  String toBase58() => this.toBase58();

  /// Convert to buffer/bytes (Web3.js style)
  Uint8List toBuffer() => bytes;

  /// Check equality (Web3.js style)
  bool equals(PublicKey other) => this == other;
}

/// Web3.js compatible Keypair extensions
extension Web3Keypair on Keypair {
  /// Generate random keypair (Web3.js style)
  static Future<Keypair> generate() => Keypair.generate();

  /// Create from secret key (Web3.js style)
  static Keypair fromSecretKey(Uint8List secretKey) =>
      Keypair.fromSecretKey(secretKey);

  /// Create from seed (Web3.js style)
  static Future<Keypair> fromSeed(Uint8List seed) => Keypair.fromSeed(seed);

  /// Get public key (Web3.js style)
  PublicKey get publicKey => this.publicKey;

  /// Get secret key (Web3.js style)
  Uint8List get secretKey => this.secretKey;
}

/// Web3.js compatible Transaction extensions
extension Web3Transaction on Transaction {
  /// Add instruction (Web3.js style)
  void add(TransactionInstruction instruction) {
    instructions.add(instruction);
  }

  /// Set recent blockhash (Web3.js style) - Note: Transaction would need to be mutable
  void setRecentBlockhash(String recentBlockhash) {
    // This would require a mutable Transaction implementation
    throw UnimplementedError(
        'Web3Transaction.setRecentBlockhash requires mutable Transaction');
  }

  /// Set fee payer (Web3.js style) - Note: Transaction would need to be mutable
  void setFeePayer(PublicKey feePayer) {
    // This would require a mutable Transaction implementation
    throw UnimplementedError(
        'Web3Transaction.setFeePayer requires mutable Transaction');
  }

  /// Sign transaction (Web3.js style)
  void sign(List<Keypair> signers) {
    // This would implement actual signing with all provided signers
    for (int i = 0; i < signers.length; i++) {
      // Implementation would sign with each signer
      // Access via index to avoid unused variable warning
    }
    throw UnimplementedError('Web3Transaction.sign not yet implemented');
  }

  /// Partial sign (Web3.js style)
  void partialSign(List<Keypair> signers) {
    sign(signers);
  }

  /// Serialize (Web3.js style)
  Uint8List serialize([Map<String, dynamic>? options]) {
    throw UnimplementedError('Web3Transaction.serialize not yet implemented');
  }
}

/// Web3.js compatible instruction creation
class Web3Instructions {
  /// System program create account instruction (Web3.js style)
  static TransactionInstruction createAccount({
    required PublicKey fromPubkey,
    required PublicKey newAccountPubkey,
    required int lamports,
    required int space,
    required PublicKey programId,
  }) {
    return TransactionInstruction(
      programId: PublicKey.fromBase58(
          '11111111111111111111111111111111'), // System Program
      accounts: [
        AccountMeta.writable(fromPubkey, isSigner: true),
        AccountMeta.writable(newAccountPubkey, isSigner: true),
      ],
      data: Uint8List.fromList([
        0, // Create account instruction
        ...lamports.toBytes(8), // lamports as little-endian u64
        ...space.toBytes(8), // space as little-endian u64
        ...programId.bytes, // program ID (32 bytes)
      ]),
    );
  }

  /// System program transfer instruction (Web3.js style)
  static TransactionInstruction transfer({
    required PublicKey fromPubkey,
    required PublicKey toPubkey,
    required int lamports,
  }) {
    return TransactionInstruction(
      programId: PublicKey.fromBase58(
          '11111111111111111111111111111111'), // System Program
      accounts: [
        AccountMeta.writable(fromPubkey, isSigner: true),
        AccountMeta.writable(toPubkey, isSigner: false),
      ],
      data: Uint8List.fromList([
        2, // Transfer instruction
        ...lamports.toBytes(8), // lamports as little-endian u64
      ]),
    );
  }
}

/// Web3.js compatible constants
class Web3Constants {
  /// System program ID
  static final PublicKey systemProgramId =
      PublicKey.fromBase58('11111111111111111111111111111111');

  /// SPL Token program ID
  static final PublicKey tokenProgramId =
      PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

  /// Associated Token program ID
  static final PublicKey associatedTokenProgramId =
      PublicKey.fromBase58('ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL');

  /// Rent sysvar ID
  static final PublicKey sysvarRentId =
      PublicKey.fromBase58('SysvarRent111111111111111111111111111111111');

  /// Clock sysvar ID
  static final PublicKey sysvarClockId =
      PublicKey.fromBase58('SysvarC1ock11111111111111111111111111111111');
}

/// Web3.js compatible commitment levels
class Web3Commitment {
  static const String processed = 'processed';
  static const String confirmed = 'confirmed';
  static const String finalized = 'finalized';
  static const String recent = 'recent';
  static const String single = 'single';
  static const String singleGossip = 'singleGossip';
  static const String root = 'root';
  static const String max = 'max';
}

/// Web3.js compatible utilities
class Web3Utils {
  /// Check if string is valid base58
  static bool isValidBase58(String value) {
    try {
      PublicKey.fromBase58(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Convert lamports to SOL
  static double lamportsToSol(int lamports) {
    return lamports / 1000000000.0; // 1 SOL = 1e9 lamports
  }

  /// Convert SOL to lamports
  static int solToLamports(double sol) {
    return (sol * 1000000000).round();
  }

  /// Generate random seed
  static Uint8List randomSeed([int length = 32]) {
    // This would use a secure random generator
    throw UnimplementedError('Web3Utils.randomSeed not yet implemented');
  }
}

/// Extension for int to bytes conversion (little-endian)
extension IntToBytes on int {
  Uint8List toBytes(int length) {
    final bytes = Uint8List(length);
    var value = this;
    for (int i = 0; i < length; i++) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }
}

/// Web3.js compatible account meta creation
extension Web3AccountMeta on AccountMeta {
  /// Create writable account meta (Web3.js style)
  static AccountMeta writable(PublicKey pubkey, bool isSigner) {
    return AccountMeta(
      pubkey: pubkey,
      isSigner: isSigner,
      isWritable: true,
    );
  }

  /// Create readonly account meta (Web3.js style)
  static AccountMeta readonly(PublicKey pubkey, bool isSigner) {
    return AccountMeta(
      pubkey: pubkey,
      isSigner: isSigner,
      isWritable: false,
    );
  }
}

/// Web3.js compatible error types
class Web3Error extends Error {
  final String message;
  final String? code;

  Web3Error(this.message, {this.code});

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

class TransactionError extends Web3Error {
  TransactionError(String message, {String? code}) : super(message, code: code);
}

class ConnectionError extends Web3Error {
  ConnectionError(String message, {String? code}) : super(message, code: code);
}

class AccountError extends Web3Error {
  AccountError(String message, {String? code}) : super(message, code: code);
}
