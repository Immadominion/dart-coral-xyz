/// Account factory functions for creating pre-initialized accounts.
///
/// Mirrors the Rust/TS/Python factory helpers for creating accounts
/// that the SPL Token program and other programs expect.
library;

import 'dart:typed_data';

import '../types/public_key.dart';
import 'execution_result.dart';
import 'programs.dart';

// ---------------------------------------------------------------------------
// Rent helper
// ---------------------------------------------------------------------------

/// Default Solana rent: minimum_balance(dataLen) = (dataLen + 128) * 3480 * 2
int rentMinimumBalance(int dataLen) => (dataLen + 128) * 3480 * 2;

// ---------------------------------------------------------------------------
// SPL Token state sizes
// ---------------------------------------------------------------------------

/// SPL Mint account data size (82 bytes).
const int mintSize = 82;

/// SPL Token Account data size (165 bytes).
const int tokenAccountSize = 165;

// ---------------------------------------------------------------------------
// Factory functions
// ---------------------------------------------------------------------------

/// Create a system-owned account with the given lamports.
/// Defaults to 1 SOL if omitted.
KeyedAccount createKeyedSystemAccount(
  PublicKey address, {
  int lamports = lamportsPerSol,
}) {
  return KeyedAccount(
    address: address,
    owner: systemProgramId,
    lamports: lamports,
    data: Uint8List(0),
  );
}

/// Options for creating a mint account.
class MintOpts {
  const MintOpts({
    this.mintAuthority,
    this.supply = 0,
    this.decimals = 9,
    this.freezeAuthority,
  });

  final PublicKey? mintAuthority;
  final int supply;
  final int decimals;
  final PublicKey? freezeAuthority;
}

/// Create a pre-initialized mint account.
KeyedAccount createKeyedMintAccount(
  PublicKey address, {
  MintOpts opts = const MintOpts(),
  PublicKey? tokenProgramId,
}) {
  tokenProgramId ??= splTokenProgramId;
  final data = _encodeMint(opts);
  return KeyedAccount(
    address: address,
    owner: tokenProgramId,
    lamports: rentMinimumBalance(mintSize),
    data: data,
  );
}

/// Options for creating a token account.
class TokenAccountOpts {
  const TokenAccountOpts({
    required this.mint,
    required this.owner,
    required this.amount,
    this.delegate,
    this.state = 1, // Initialized
    this.isNative,
    this.delegatedAmount = 0,
    this.closeAuthority,
  });

  final PublicKey mint;
  final PublicKey owner;
  final int amount;
  final PublicKey? delegate;

  /// 0 = Uninitialized, 1 = Initialized, 2 = Frozen
  final int state;
  final int? isNative;
  final int delegatedAmount;
  final PublicKey? closeAuthority;
}

/// Create a pre-initialized token account.
KeyedAccount createKeyedTokenAccount(
  PublicKey address, {
  required TokenAccountOpts opts,
  PublicKey? tokenProgramId,
}) {
  tokenProgramId ??= splTokenProgramId;
  final data = _encodeTokenAccount(opts);
  return KeyedAccount(
    address: address,
    owner: tokenProgramId,
    lamports: rentMinimumBalance(tokenAccountSize),
    data: data,
  );
}

/// Create a pre-initialized associated token account.
/// The address is derived from wallet, mint, and token program.
KeyedAccount createKeyedAssociatedTokenAccount(
  PublicKey wallet,
  PublicKey mint,
  int amount, {
  PublicKey? tokenProgramId,
}) {
  tokenProgramId ??= splTokenProgramId;

  final pda = PublicKeyUtils.findProgramAddressSync([
    wallet.bytes,
    tokenProgramId.bytes,
    mint.bytes,
  ], splAssociatedTokenProgramId);

  final opts = TokenAccountOpts(mint: mint, owner: wallet, amount: amount);
  final data = _encodeTokenAccount(opts);

  return KeyedAccount(
    address: pda.address,
    owner: tokenProgramId,
    lamports: rentMinimumBalance(tokenAccountSize),
    data: data,
  );
}

// ---------------------------------------------------------------------------
// SPL state encoding (matches Pack trait exactly)
// ---------------------------------------------------------------------------

/// Encode a Mint struct (82 bytes).
Uint8List _encodeMint(MintOpts opts) {
  final data = Uint8List(mintSize);
  final bd = ByteData.sublistView(data);
  var o = 0;

  // mintAuthority: COption<Pubkey>
  if (opts.mintAuthority != null) {
    bd.setUint32(o, 1, Endian.little);
    o += 4;
    data.setAll(o, opts.mintAuthority!.bytes);
    o += 32;
  } else {
    bd.setUint32(o, 0, Endian.little);
    o += 4;
    // 32 bytes remain zero
    o += 32;
  }

  // supply: u64
  _writeU64(bd, o, opts.supply);
  o += 8;

  // decimals: u8
  data[o++] = opts.decimals;

  // isInitialized: bool
  data[o++] = 1; // always initialized

  // freezeAuthority: COption<Pubkey>
  if (opts.freezeAuthority != null) {
    bd.setUint32(o, 1, Endian.little);
    o += 4;
    data.setAll(o, opts.freezeAuthority!.bytes);
    // o += 32;
  } else {
    bd.setUint32(o, 0, Endian.little);
    // o += 4;
    // 32 bytes remain zero
  }

  return data;
}

/// Encode a Token Account struct (165 bytes).
Uint8List _encodeTokenAccount(TokenAccountOpts opts) {
  final data = Uint8List(tokenAccountSize);
  final bd = ByteData.sublistView(data);
  var o = 0;

  // mint: Pubkey
  data.setAll(o, opts.mint.bytes);
  o += 32;

  // owner: Pubkey
  data.setAll(o, opts.owner.bytes);
  o += 32;

  // amount: u64
  _writeU64(bd, o, opts.amount);
  o += 8;

  // delegate: COption<Pubkey>
  if (opts.delegate != null) {
    bd.setUint32(o, 1, Endian.little);
    o += 4;
    data.setAll(o, opts.delegate!.bytes);
    o += 32;
  } else {
    bd.setUint32(o, 0, Endian.little);
    o += 4;
    o += 32; // zeroed
  }

  // state: u8
  data[o++] = opts.state;

  // isNative: COption<u64>
  if (opts.isNative != null) {
    bd.setUint32(o, 1, Endian.little);
    o += 4;
    _writeU64(bd, o, opts.isNative!);
    o += 8;
  } else {
    bd.setUint32(o, 0, Endian.little);
    o += 4;
    o += 8; // zeroed
  }

  // delegatedAmount: u64
  _writeU64(bd, o, opts.delegatedAmount);
  o += 8;

  // closeAuthority: COption<Pubkey>
  if (opts.closeAuthority != null) {
    bd.setUint32(o, 1, Endian.little);
    o += 4;
    data.setAll(o, opts.closeAuthority!.bytes);
    // o += 32;
  } else {
    bd.setUint32(o, 0, Endian.little);
    // o += 4;
    // 32 bytes remain zero
  }

  return data;
}

void _writeU64(ByteData bd, int offset, int value) {
  bd.setUint32(offset, value & 0xFFFFFFFF, Endian.little);
  bd.setUint32(offset + 4, (value >> 32) & 0xFFFFFFFF, Endian.little);
}
