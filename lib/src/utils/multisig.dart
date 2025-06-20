/// Multisig utilities for Anchor programs
///
/// This module provides utilities for creating, managing, and executing
/// multisig transactions, similar to those commonly used in Solana programs.
///
/// While Anchor itself doesn't include built-in multisig utilities in TypeScript,
/// this module provides common patterns used in multisig programs to make
/// it easier to work with multisig flows in Dart.

library;

import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/transaction.dart';

/// Utilities for working with multisig programs and transactions
class MultisigUtils {
  /// Create seeds for a multisig PDA
  ///
  /// This creates the standard seeds used for multisig PDA derivation.
  /// The pattern follows: [multisig_pubkey]
  static List<Uint8List> createMultisigSeeds(PublicKey multisigKey) {
    return [multisigKey.bytes];
  }

  /// Find the multisig signer PDA
  ///
  /// This derives the PDA that acts as the signer for multisig transactions.
  /// This is a common pattern in multisig programs.
  static Future<PdaResult> findMultisigSigner(
    PublicKey multisigKey,
    PublicKey programId,
  ) async {
    final seeds = createMultisigSeeds(multisigKey);
    return PublicKey.findProgramAddress(seeds, programId);
  }

  /// Validate multisig threshold
  ///
  /// Ensures the threshold is valid (between 1 and the number of owners).
  static bool validateThreshold(int threshold, int ownerCount) {
    return threshold >= 1 && threshold <= ownerCount;
  }

  /// Check if enough owners have signed
  ///
  /// Compares the number of signatures against the required threshold.
  static bool hasThresholdSignatures(
    List<bool> signers,
    int threshold,
  ) {
    final signatureCount = signers.where((signed) => signed).length;
    return signatureCount >= threshold;
  }

  /// Create a multisig transaction account data structure
  ///
  /// This represents the typical structure of a multisig transaction
  /// as used in multisig programs.
  static MultisigTransaction createTransaction({
    required PublicKey multisig,
    required PublicKey programId,
    required List<TransactionAccount> accounts,
    required Uint8List data,
    required int ownerCount,
  }) {
    return MultisigTransaction(
      multisig: multisig,
      programId: programId,
      accounts: accounts,
      data: data,
      signers: List.filled(ownerCount, false),
      didExecute: false,
    );
  }

  /// Mark an owner as having signed the transaction
  ///
  /// Updates the signers array to indicate that a specific owner has signed.
  static MultisigTransaction signTransaction(
    MultisigTransaction transaction,
    int ownerIndex,
  ) {
    if (ownerIndex < 0 || ownerIndex >= transaction.signers.length) {
      throw ArgumentError('Invalid owner index: $ownerIndex');
    }

    final newSigners = List<bool>.from(transaction.signers);
    newSigners[ownerIndex] = true;

    return MultisigTransaction(
      multisig: transaction.multisig,
      programId: transaction.programId,
      accounts: transaction.accounts,
      data: transaction.data,
      signers: newSigners,
      didExecute: transaction.didExecute,
    );
  }

  /// Check if a transaction is ready for execution
  ///
  /// Returns true if the transaction has enough signatures and hasn't been executed.
  static bool canExecuteTransaction(
    MultisigTransaction transaction,
    int threshold,
  ) {
    return !transaction.didExecute &&
        hasThresholdSignatures(transaction.signers, threshold);
  }

  /// Get the owner index for a given public key
  ///
  /// Returns the index of the owner in the owners list, or -1 if not found.
  static int getOwnerIndex(List<PublicKey> owners, PublicKey owner) {
    for (int i = 0; i < owners.length; i++) {
      if (owners[i] == owner) {
        return i;
      }
    }
    return -1;
  }

  /// Validate that a public key is one of the multisig owners
  static bool isValidOwner(List<PublicKey> owners, PublicKey potentialOwner) {
    return getOwnerIndex(owners, potentialOwner) >= 0;
  }

  /// Create account metas for a multisig execution
  ///
  /// This creates the account metas needed for executing a multisig transaction,
  /// properly handling the signer status for the multisig signer PDA.
  static List<AccountMeta> createExecutionAccountMetas(
    List<TransactionAccount> accounts,
    PublicKey multisigSigner,
  ) {
    return accounts.map((account) {
      if (account.pubkey == multisigSigner) {
        // The multisig signer is signed by the program, not the client
        return AccountMeta(
          pubkey: account.pubkey,
          isSigner: false,
          isWritable: account.isWritable,
        );
      } else {
        return AccountMeta(
          pubkey: account.pubkey,
          isSigner: account.isSigner,
          isWritable: account.isWritable,
        );
      }
    }).toList();
  }

  /// Create seeds for transaction account derivation
  ///
  /// Some multisig programs derive transaction account addresses.
  static List<Uint8List> createTransactionSeeds(
    PublicKey multisig,
    String transactionId,
  ) {
    return [
      multisig.bytes,
      Uint8List.fromList(transactionId.codeUnits),
    ];
  }

  /// Encode instruction data for multisig use
  ///
  /// This is a helper for encoding instruction data that will be stored
  /// in a multisig transaction and executed later.
  static Uint8List encodeInstructionData(
    String instructionName,
    Map<String, dynamic> args,
  ) {
    // This would typically use the program's IDL to encode the instruction
    // For now, we'll use a simple encoding
    final nameBytes = Uint8List.fromList(instructionName.codeUnits);
    final argsJson = args.toString();
    final argsBytes = Uint8List.fromList(argsJson.codeUnits);

    return Uint8List.fromList([
      ...nameBytes,
      0, // separator
      ...argsBytes,
    ]);
  }
}

/// Represents a transaction account in a multisig context
class TransactionAccount {
  final PublicKey pubkey;
  final bool isSigner;
  final bool isWritable;

  const TransactionAccount({
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
  });

  /// Convert to AccountMeta for instruction building
  AccountMeta toAccountMeta() {
    return AccountMeta(
      pubkey: pubkey,
      isSigner: isSigner,
      isWritable: isWritable,
    );
  }

  @override
  String toString() {
    return 'TransactionAccount(pubkey: $pubkey, isSigner: $isSigner, isWritable: $isWritable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionAccount &&
        other.pubkey == pubkey &&
        other.isSigner == isSigner &&
        other.isWritable == isWritable;
  }

  @override
  int get hashCode => Object.hash(pubkey, isSigner, isWritable);
}

/// Represents a multisig transaction
class MultisigTransaction {
  final PublicKey multisig;
  final PublicKey programId;
  final List<TransactionAccount> accounts;
  final Uint8List data;
  final List<bool> signers;
  final bool didExecute;

  const MultisigTransaction({
    required this.multisig,
    required this.programId,
    required this.accounts,
    required this.data,
    required this.signers,
    required this.didExecute,
  });

  /// Get the number of signatures collected
  int get signatureCount {
    return signers.where((signed) => signed).length;
  }

  /// Check if a specific owner has signed
  bool hasOwnerSigned(int ownerIndex) {
    if (ownerIndex < 0 || ownerIndex >= signers.length) {
      return false;
    }
    return signers[ownerIndex];
  }

  /// Get list of owner indices who have signed
  List<int> get signerIndices {
    final indices = <int>[];
    for (int i = 0; i < signers.length; i++) {
      if (signers[i]) {
        indices.add(i);
      }
    }
    return indices;
  }

  @override
  String toString() {
    return 'MultisigTransaction(multisig: $multisig, programId: $programId, '
        'accounts: ${accounts.length}, signatures: $signatureCount/${signers.length}, '
        'executed: $didExecute)';
  }
}

/// Configuration for a multisig account
class MultisigConfig {
  final List<PublicKey> owners;
  final int threshold;
  final int nonce;

  const MultisigConfig({
    required this.owners,
    required this.threshold,
    required this.nonce,
  });

  /// Validate the multisig configuration
  bool get isValid {
    return MultisigUtils.validateThreshold(threshold, owners.length);
  }

  /// Get the multisig signer PDA for this config
  Future<PdaResult> getSignerPda(
    PublicKey multisigKey,
    PublicKey programId,
  ) async {
    return MultisigUtils.findMultisigSigner(multisigKey, programId);
  }

  @override
  String toString() {
    return 'MultisigConfig(owners: ${owners.length}, threshold: $threshold, nonce: $nonce)';
  }
}

/// Helper for building multisig-related account constraints
class MultisigAccountBuilder {
  final PublicKey multisigKey;
  final PublicKey programId;

  const MultisigAccountBuilder({
    required this.multisigKey,
    required this.programId,
  });

  /// Build accounts for creating a multisig
  Map<String, dynamic> createMultisigAccounts() {
    return {
      'multisig': multisigKey,
    };
  }

  /// Build accounts for creating a transaction
  Map<String, dynamic> createTransactionAccounts({
    required PublicKey transaction,
    required PublicKey proposer,
  }) {
    return {
      'multisig': multisigKey,
      'transaction': transaction,
      'proposer': proposer,
    };
  }

  /// Build accounts for approving a transaction
  Map<String, dynamic> approveAccounts({
    required PublicKey transaction,
    required PublicKey owner,
  }) {
    return {
      'multisig': multisigKey,
      'transaction': transaction,
      'owner': owner,
    };
  }

  /// Build accounts for executing a transaction
  Future<Map<String, dynamic>> executeAccounts({
    required PublicKey transaction,
  }) async {
    final signerPda = await MultisigUtils.findMultisigSigner(
      multisigKey,
      programId,
    );

    return {
      'multisig': multisigKey,
      'multisigSigner': signerPda.address,
      'transaction': transaction,
    };
  }
}
