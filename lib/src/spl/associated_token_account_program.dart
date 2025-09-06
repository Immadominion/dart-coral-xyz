/// SPL Associated Token Account Program integration for Anchor
///
/// This module provides Anchor-style access to the SPL Associated Token Account Program
/// with exact TypeScript SDK compatibility. It leverages the existing comprehensive
/// ATA implementation from the espresso-cash-public package.
library;

import '../provider/anchor_provider.dart';
import '../program/program_class.dart';
import '../idl/idl.dart';
import '../coder/main_coder.dart';
import '../utils/logger.dart';

/// SPL Associated Token Account Program ID
/// Matches TypeScript: SPL_ASSOCIATED_TOKEN_ACCOUNT_PROGRAM_ID
const String SPL_ASSOCIATED_TOKEN_ACCOUNT_PROGRAM_ID =
    'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';

/// Parameters for getting Associated Token Account program
///
/// Matches TypeScript: GetProgramParams interface
class GetAssociatedTokenAccountProgramParams {
  const GetAssociatedTokenAccountProgramParams({
    this.programId,
    this.provider,
  });

  /// Optional custom program ID
  final String? programId;

  /// Optional provider
  final AnchorProvider? provider;
}

/// SPL Associated Token Account IDL type definition
/// Matches TypeScript: SplAssociatedTokenAccount type
typedef SplAssociatedTokenAccountIdl = Idl;

/// SPL Associated Token Account Coder
///
/// Extends BorshCoder to provide ATA-specific encoding/decoding
/// Matches TypeScript: SplAssociatedTokenAccountCoder
class SplAssociatedTokenAccountCoder extends BorshCoder {
  SplAssociatedTokenAccountCoder(SplAssociatedTokenAccountIdl idl) : super(idl);
}

/// Creates an SPL Associated Token Account Program instance matching TypeScript SDK
///
/// Matches TypeScript: splAssociatedTokenAccountProgram(params?: GetProgramParams): Program<SplAssociatedTokenAccount>
Program<SplAssociatedTokenAccountIdl> splAssociatedTokenAccountProgram(
    [GetAssociatedTokenAccountProgramParams? params]) {
  final programId =
      params?.programId ?? SPL_ASSOCIATED_TOKEN_ACCOUNT_PROGRAM_ID;
  final provider = params?.provider;

  final logger = AnchorLogger.getLogger('SplAssociatedTokenAccountProgram');
  logger.debug(
      'Creating SPL Associated Token Account Program with ID: $programId');

  return Program<SplAssociatedTokenAccountIdl>(
    _createSplAssociatedTokenAccountIdl(programId),
    provider: provider,
    coder: SplAssociatedTokenAccountCoder(
        _createSplAssociatedTokenAccountIdl(programId)),
  );
}

/// Creates the SPL Associated Token Account IDL
///
/// Internal function that constructs the IDL exactly matching the TypeScript SDK
SplAssociatedTokenAccountIdl _createSplAssociatedTokenAccountIdl(
    String programId) {
  return Idl(
    address: programId,
    instructions: [
      // create instruction
      IdlInstruction(
        name: 'create',
        discriminator: const [0],
        accounts: const [
          IdlInstructionAccount(
            name: 'fundingAddress',
            writable: true,
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'associatedAccountAddress',
            writable: true,
          ),
          IdlInstructionAccount(
            name: 'walletAddress',
          ),
          IdlInstructionAccount(
            name: 'tokenMintAddress',
          ),
          IdlInstructionAccount(
            name: 'systemProgram',
            address: '11111111111111111111111111111111',
          ),
          IdlInstructionAccount(
            name: 'tokenProgram',
            address: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
          ),
        ],
        args: const [],
      ),
      // createIdempotent instruction
      IdlInstruction(
        name: 'createIdempotent',
        discriminator: const [1],
        accounts: const [
          IdlInstructionAccount(
            name: 'fundingAddress',
            writable: true,
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'associatedAccountAddress',
            writable: true,
          ),
          IdlInstructionAccount(
            name: 'walletAddress',
          ),
          IdlInstructionAccount(
            name: 'tokenMintAddress',
          ),
          IdlInstructionAccount(
            name: 'systemProgram',
            address: '11111111111111111111111111111111',
          ),
          IdlInstructionAccount(
            name: 'tokenProgram',
            address: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
          ),
        ],
        args: const [],
      ),
      // recoverNested instruction
      IdlInstruction(
        name: 'recoverNested',
        discriminator: const [2],
        accounts: const [
          IdlInstructionAccount(
            name: 'nestedAssociatedAccountAddress',
            writable: true,
          ),
          IdlInstructionAccount(
            name: 'nestedTokenMintAddress',
          ),
          IdlInstructionAccount(
            name: 'destinationAssociatedAccountAddress',
            writable: true,
          ),
          IdlInstructionAccount(
            name: 'ownerAssociatedAccountAddress',
          ),
          IdlInstructionAccount(
            name: 'ownerTokenMintAddress',
          ),
          IdlInstructionAccount(
            name: 'walletAddress',
            writable: true,
            signer: true,
          ),
          IdlInstructionAccount(
            name: 'tokenProgram',
            address: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
          ),
        ],
        args: const [],
      ),
    ],
    accounts: [],
    types: [],
    errors: [
      IdlErrorCode(
        code: 0,
        name: 'invalidOwner',
        msg: 'Associated token account owner does not match address derivation',
      ),
    ],
    metadata: const IdlMetadata(
      name: 'splAssociatedTokenAccount',
      version: '1.1.1',
      spec: '0.1.0',
    ),
  );
}
