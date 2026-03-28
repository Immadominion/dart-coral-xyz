/// Token utilities matching TypeScript Anchor SDK utils.token
///
/// Uses espresso-cash-public packages for proven implementations.
library;

import '../types/public_key.dart';
import 'package:solana/solana.dart' as solana;

/// Token program utilities
///
/// Matches TypeScript: utils.token.*
class TokenUtils {
  /// SPL Token Program ID
  static PublicKey get TOKEN_PROGRAM_ID =>
      PublicKey.fromBase58(solana.TokenProgram.id.toBase58());

  /// SPL Associated Token Account Program ID
  static PublicKey get ASSOCIATED_PROGRAM_ID =>
      PublicKey.fromBase58(solana.AssociatedTokenAccountProgram.id.toBase58());

  /// Find the associated token address for owner and mint
  ///
  /// Matches TypeScript: utils.token.associatedAddress({mint, owner})
  static Future<PublicKey> associatedAddress({
    required PublicKey mint,
    required PublicKey owner,
  }) async {
    final espressoMint = solana.Ed25519HDPublicKey.fromBase58(mint.toBase58());
    final espressoOwner = solana.Ed25519HDPublicKey.fromBase58(
      owner.toBase58(),
    );

    final associatedTokenAddress = await solana.findAssociatedTokenAddress(
      owner: espressoOwner,
      mint: espressoMint,
    );

    return PublicKey.fromBase58(associatedTokenAddress.toBase58());
  }
}
