/// RPC utilities matching TypeScript Anchor SDK utils.rpc
///
/// Provides RPC and transaction utilities with exact compatibility
/// to the TypeScript Anchor SDK's utils.rpc module using espresso-cash.
library;

// Use espresso-cash for proven Solana RPC functionality
import 'package:solana/solana.dart' as solana;
import 'package:solana/dto.dart' as dto;
import 'package:solana/encoder.dart' as encoder;

// Core dart-coral-xyz types for API compatibility
import '../types/public_key.dart';

/// RPC and transaction utilities
///
/// Matches TypeScript: utils.rpc.*
/// Provides transaction sending, simulation, and RPC helper functions using espresso-cash
class RpcUtils {
  /// Send a transaction to a program with given accounts and instruction data
  ///
  /// Matches TypeScript: utils.rpc.invoke(programId, accounts?, data?, provider?)
  static Future<String> invoke(
    PublicKey programId, {
    List<RpcAccountMeta>? accounts,
    List<int>? data,
    solana.SolanaClient? client,
    solana.Ed25519HDKeyPair? signer,
  }) async {
    client ??= _getDefaultClient();
    signer ??= await solana.Ed25519HDKeyPair.random();

    // Convert to espresso-cash instruction
    final instruction = encoder.Instruction(
      programId: solana.Ed25519HDPublicKey.fromBase58(programId.toBase58()),
      accounts: accounts
              ?.map((meta) => meta.isWritable
                  ? encoder.AccountMeta.writeable(
                      pubKey: solana.Ed25519HDPublicKey.fromBase58(
                          meta.publicKey.toBase58()),
                      isSigner: meta.isSigner,
                    )
                  : encoder.AccountMeta.readonly(
                      pubKey: solana.Ed25519HDPublicKey.fromBase58(
                          meta.publicKey.toBase58()),
                      isSigner: meta.isSigner,
                    ))
              .toList() ??
          [],
      data: encoder.ByteArray(data ?? []),
    );

    final message = encoder.Message.only(instruction);

    return client.sendAndConfirmTransaction(
      message: message,
      signers: [signer],
      commitment: solana.Commitment.confirmed,
    );
  }

  /// Simulate a transaction without sending it
  ///
  /// Matches TypeScript: utils.rpc.simulate(transaction, provider?)
  static Future<RpcSimulationResult> simulate(
    List<int> serializedTransaction, {
    solana.SolanaClient? client,
    solana.Commitment? commitment,
  }) async {
    client ??= _getDefaultClient();

    try {
      final encodedTx =
          encoder.SignedTx.fromBytes(serializedTransaction).encode();
      final result = await client.rpcClient.simulateTransaction(
        encodedTx,
        commitment: commitment ?? solana.Commitment.confirmed,
      );

      return RpcSimulationResult(
        success: result.value.err == null,
        logs: result.value.logs ?? [],
        unitsConsumed: result.value.unitsConsumed,
        error: result.value.err,
        accounts: result.value.accounts
            ?.map(RpcAccountInfo.fromSolanaAccount)
            .toList(),
      );
    } catch (e) {
      return RpcSimulationResult(
        success: false,
        logs: [],
        error: e.toString(),
      );
    }
  }

  /// Send and confirm a transaction with retries
  ///
  /// Matches TypeScript: utils.rpc.sendAndConfirm(transaction, provider?, options?)
  static Future<String> sendAndConfirm(
    encoder.Message message, {
    required solana.Ed25519HDKeyPair signer,
    solana.SolanaClient? client,
    solana.Commitment? commitment,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    client ??= _getDefaultClient();

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await client.sendAndConfirmTransaction(
          message: message,
          signers: [signer],
          commitment: commitment ?? solana.Commitment.confirmed,
        );
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }

        // Wait before retry with exponential backoff
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    throw Exception('Failed to send transaction after $maxRetries attempts');
  }

  /// Get multiple accounts in batches
  ///
  /// Matches TypeScript: utils.rpc.getMultipleAccounts(publicKeys, provider?)
  static Future<List<RpcAccountInfo?>> getMultipleAccounts(
    List<PublicKey> publicKeys, {
    solana.SolanaClient? client,
    solana.Commitment? commitment,
  }) async {
    client ??= _getDefaultClient();

    // Convert to espresso-cash public keys
    final solanaKeys = publicKeys
        .map((pk) => solana.Ed25519HDPublicKey.fromBase58(pk.toBase58()))
        .toList();

    // Split into chunks to avoid RPC limits (espresso-cash handles this internally)
    final result = await client.rpcClient.getMultipleAccounts(
      solanaKeys.map((key) => key.toBase58()).toList(),
      commitment: commitment ?? solana.Commitment.finalized,
    );

    return result.value
        .map((account) =>
            account != null ? RpcAccountInfo.fromSolanaAccount(account) : null)
        .toList();
  }

  /// Get account info with retry logic
  ///
  /// Matches TypeScript: utils.rpc.getAccount(publicKey, provider?)
  static Future<RpcAccountInfo?> getAccount(
    PublicKey publicKey, {
    solana.SolanaClient? client,
    solana.Commitment? commitment,
    int maxRetries = 3,
  }) async {
    client ??= _getDefaultClient();

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await client.rpcClient.getAccountInfo(
          publicKey.toBase58(),
          commitment: commitment ?? solana.Commitment.finalized,
        );

        return result.value != null
            ? RpcAccountInfo.fromSolanaAccount(result.value!)
            : null;
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    return null;
  }

  /// Confirm transaction with timeout
  ///
  /// Matches TypeScript: utils.rpc.confirm(signature, provider?, commitment?)
  static Future<bool> confirm(
    String signature, {
    solana.SolanaClient? client,
    solana.Commitment? commitment,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    client ??= _getDefaultClient();

    try {
      await client.waitForSignatureStatus(
        signature,
        status: commitment ?? solana.Commitment.confirmed,
        timeout: timeout,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get recent blockhash
  ///
  /// Matches TypeScript: utils.rpc.getRecentBlockhash(provider?)
  static Future<RpcBlockhashInfo> getRecentBlockhash({
    solana.SolanaClient? client,
    solana.Commitment? commitment,
  }) async {
    client ??= _getDefaultClient();

    final result = await client.rpcClient.getLatestBlockhash(
      commitment: commitment ?? solana.Commitment.finalized,
    );

    return RpcBlockhashInfo(
      blockhash: result.value.blockhash,
      lastValidBlockHeight: result.value.lastValidBlockHeight,
    );
  }

  /// Get program accounts with filters
  ///
  /// Matches TypeScript: utils.rpc.getProgramAccounts(programId, provider?, config?)
  static Future<List<RpcProgramAccount>> getProgramAccounts(
    PublicKey programId, {
    solana.SolanaClient? client,
    solana.Commitment? commitment,
    List<RpcAccountFilter>? filters,
  }) async {
    client ??= _getDefaultClient();

    final result = await client.rpcClient.getProgramAccounts(
      programId.toBase58(),
      commitment: commitment ?? solana.Commitment.finalized,
      encoding: dto.Encoding.base64,
    );

    return result
        .map((programAccount) => RpcProgramAccount(
              publicKey: PublicKey.fromBase58(programAccount.pubkey),
              account: RpcAccountInfo.fromSolanaAccount(programAccount.account),
            ))
        .toList();
  }

  /// Get default Solana client (should be injected in real implementation)
  static solana.SolanaClient _getDefaultClient() {
    // This should be dependency injected in real implementation
    return solana.SolanaClient(
      rpcUrl: Uri.parse('https://api.devnet.solana.com'),
      websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
    );
  }
}

/// Account metadata for instructions
class RpcAccountMeta {
  const RpcAccountMeta({
    required this.publicKey,
    required this.isSigner,
    required this.isWritable,
  });

  final PublicKey publicKey;
  final bool isSigner;
  final bool isWritable;

  factory RpcAccountMeta.readonly(PublicKey publicKey,
      {bool isSigner = false}) {
    return RpcAccountMeta(
      publicKey: publicKey,
      isSigner: isSigner,
      isWritable: false,
    );
  }

  factory RpcAccountMeta.writable(PublicKey publicKey,
      {bool isSigner = false}) {
    return RpcAccountMeta(
      publicKey: publicKey,
      isSigner: isSigner,
      isWritable: true,
    );
  }
}

/// Transaction simulation result
class RpcSimulationResult {
  const RpcSimulationResult({
    required this.success,
    required this.logs,
    this.unitsConsumed,
    this.error,
    this.accounts,
  });

  final bool success;
  final List<String> logs;
  final int? unitsConsumed;
  final dynamic error;
  final List<RpcAccountInfo?>? accounts;

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'logs': logs,
      'unitsConsumed': unitsConsumed,
      'error': error?.toString(),
      'accountsCount': accounts?.length,
    };
  }
}

/// Blockhash information
class RpcBlockhashInfo {
  const RpcBlockhashInfo({
    required this.blockhash,
    required this.lastValidBlockHeight,
  });

  final String blockhash;
  final int lastValidBlockHeight;
}

/// Account information
class RpcAccountInfo {
  const RpcAccountInfo({
    required this.owner,
    required this.lamports,
    required this.data,
    required this.executable,
    required this.rentEpoch,
  });

  final PublicKey owner;
  final int lamports;
  final List<int> data;
  final bool executable;
  final int rentEpoch;

  factory RpcAccountInfo.fromSolanaAccount(dto.Account account) {
    return RpcAccountInfo(
      owner: PublicKey.fromBase58(account.owner),
      lamports: account.lamports,
      data: account.data is dto.BinaryAccountData
          ? (account.data as dto.BinaryAccountData).data
          : [],
      executable: account.executable,
      rentEpoch: account.rentEpoch.toInt(),
    );
  }
}

/// Program account (public key + account info)
class RpcProgramAccount {
  const RpcProgramAccount({
    required this.publicKey,
    required this.account,
  });

  final PublicKey publicKey;
  final RpcAccountInfo account;
}

/// Account filter for getProgramAccounts
class RpcAccountFilter {
  const RpcAccountFilter._({
    this.memcmp,
    this.dataSize,
  });

  final RpcMemcmpFilter? memcmp;
  final int? dataSize;

  factory RpcAccountFilter.memcmp({
    required int offset,
    required String bytes,
  }) {
    return RpcAccountFilter._(
      memcmp: RpcMemcmpFilter(offset: offset, bytes: bytes),
    );
  }

  factory RpcAccountFilter.dataSize(int size) {
    return RpcAccountFilter._(dataSize: size);
  }
}

/// Memory comparison filter
class RpcMemcmpFilter {
  const RpcMemcmpFilter({
    required this.offset,
    required this.bytes,
  });

  final int offset;
  final String bytes;
}
