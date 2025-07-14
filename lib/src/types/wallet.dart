import 'dart:async';
import 'dart:typed_data';

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';

/// Abstract definition of a Solana wallet
abstract class Wallet {
  /// The public key of the wallet
  PublicKey get publicKey;

  /// Sign a transaction
  ///
  /// This method is responsible for applying the actual signature
  /// to the transaction bytes.
  FutureOr<void> signTransaction(Transaction transaction);

  /// Sign multiple transactions in batch
  ///
  /// Default implementation signs each transaction sequentially.
  /// Implementations can override this to provide more efficient
  /// batch signing.
  FutureOr<void> signAllTransactions(List<Transaction> transactions) async {
    for (final tx in transactions) {
      await signTransaction(tx);
    }
  }

  /// Sign an arbitrary message
  ///
  /// [message] - The message to sign as bytes
  FutureOr<Uint8List> signMessage(Uint8List message);
}
