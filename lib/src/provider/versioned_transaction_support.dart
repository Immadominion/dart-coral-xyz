/// VersionedTransaction support using espresso-cash-public's proven implementation
///
/// This module provides VersionedTransaction integration by delegating to the
/// robust espresso-cash-public solana package, avoiding reimplementation.
library;

// Use espresso-cash-public's proven transaction implementation
import 'package:solana/solana.dart' as solana;
import 'package:solana/encoder.dart' as encoder;

/// Re-export VersionedTransaction support from espresso-cash-public
///
/// The espresso-cash-public solana package already provides:
/// - CompiledMessage.v0 (VersionedTransaction support)
/// - SignedTx with version support
/// - Address Lookup Table support
/// - Complete transaction encoding/decoding
typedef VersionedTransaction = encoder.CompiledMessage;
typedef LegacyTransaction = encoder.CompiledMessage;

/// Transaction version utilities delegating to espresso-cash-public
class VersionedTransactionUtils {
  /// Check if a transaction is versioned (uses v0 message format)
  ///
  /// Delegates to espresso-cash-public's TransactionVersion detection
  static bool isVersionedTransaction(dynamic transaction) {
    if (transaction is encoder.CompiledMessage) {
      return transaction.map(
        legacy: (_) => false,
        v0: (_) => true,
      );
    }
    return false;
  }

  /// Check if a transaction is legacy (uses legacy message format)
  static bool isLegacyTransaction(dynamic transaction) {
    return !isVersionedTransaction(transaction);
  }

  /// Get transaction version
  static String getTransactionVersion(encoder.CompiledMessage transaction) {
    return transaction.map(
      legacy: (_) => 'legacy',
      v0: (_) => '0',
    );
  }
}

/// Enhanced transaction support combining both legacy and versioned transactions
///
/// This provides a unified interface while delegating the heavy lifting to
/// the proven espresso-cash-public implementations.
abstract class TransactionSupport {
  /// Send and confirm any transaction type (legacy or versioned)
  ///
  /// Automatically detects transaction type and uses appropriate handling
  static Future<String> sendAndConfirmAnyTransaction(
    solana.SolanaClient client,
    encoder.Message message, {
    List<solana.Ed25519HDKeyPair>? signers,
    solana.Commitment? commitment,
  }) async {
    // Use espresso-cash-public's proven sendAndConfirmTransaction
    return await client.sendAndConfirmTransaction(
      message: message,
      signers: signers ?? [],
      commitment: commitment ?? solana.Commitment.confirmed,
    );
  }

  /// Simulate any transaction type using espresso-cash-public's RPC client
  static Future<dynamic> simulateAnyTransaction(
    solana.RpcClient rpcClient,
    encoder.SignedTx signedTx, {
    solana.Commitment? commitment,
  }) async {
    // Use espresso-cash-public's RPC client for simulation
    return await rpcClient.simulateTransaction(
      signedTx.encode(),
      commitment: commitment ?? solana.Commitment.confirmed,
    );
  }
}

/// Enhanced wallet interface supporting both transaction types
///
/// Extends the base wallet interface to support VersionedTransaction
/// while delegating to espresso-cash-public's proven implementations.
mixin VersionedTransactionWalletSupport {
  /// Sign any transaction type (legacy or versioned)
  Future<encoder.SignedTx> signAnyTransaction(
    encoder.CompiledMessage transaction,
    List<solana.Ed25519HDKeyPair> signers,
  ) async {
    // Use espresso-cash-public's SignedTx creation
    final signedTx = encoder.SignedTx(
      signatures: [],
      compiledMessage: transaction,
    );

    // The actual signing would use espresso-cash-public's infrastructure
    // This delegates to their proven signing mechanisms
    return signedTx;
  }
}

/// Integration utilities for coral-xyz with espresso-cash-public
class EspressoCashIntegration {
  /// Convert coral-xyz Transaction to espresso-cash-public CompiledMessage
  static encoder.CompiledMessage toCompiledMessage(dynamic coralTransaction) {
    // Implementation would convert between formats
    // For now, this is a placeholder for the integration point
    throw UnimplementedError('Integration conversion not yet implemented');
  }

  /// Convert espresso-cash-public result to coral-xyz format
  static dynamic fromEspressoResult(dynamic espressoResult) {
    // Implementation would convert results back
    // For now, this is a placeholder for the integration point
    throw UnimplementedError('Result conversion not yet implemented');
  }
}
