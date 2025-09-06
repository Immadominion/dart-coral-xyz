/// SPL Token Swap Program integration for Anchor
///
/// This module provides Anchor-style access to the SPL Token Swap Program
/// with exact TypeScript SDK compatibility.
library;

import '../provider/anchor_provider.dart';
import '../program/program_class.dart';
import '../idl/idl.dart';
import '../coder/main_coder.dart';
import '../utils/logger.dart';

/// SPL Token Swap Program ID
const String SPL_TOKEN_SWAP_PROGRAM_ID =
    "SwapsVeCiPHMUAtzQWZw7RjsKjgCjhwU55QGu4U1Szw";

/// Parameters for creating a Token Swap Program instance
class GetTokenSwapProgramParams {
  /// Optional program ID (defaults to SPL_TOKEN_SWAP_PROGRAM_ID)
  final String? programId;

  /// Optional provider (uses default if not provided)
  final AnchorProvider? provider;

  const GetTokenSwapProgramParams({
    this.programId,
    this.provider,
  });
}

/// Creates an SPL Token Swap Program instance matching TypeScript SDK
///
/// Matches TypeScript: splTokenSwapProgram(params?: GetProgramParams): Program<SplTokenSwap>
Program<SplTokenSwapIdl> splTokenSwapProgram(
    [GetTokenSwapProgramParams? params]) {
  final programId = params?.programId ?? SPL_TOKEN_SWAP_PROGRAM_ID;
  final provider = params?.provider;

  final logger = AnchorLogger.getLogger('SplTokenSwapProgram');
  logger.debug('Creating SPL Token Swap Program with ID: $programId');

  return Program<SplTokenSwapIdl>(
    _createSplTokenSwapIdl(programId),
    provider: provider,
    coder: SplTokenSwapCoder(_createSplTokenSwapIdl(programId)),
  );
}

/// SPL Token Swap IDL type definition
class SplTokenSwapIdl extends Idl {
  SplTokenSwapIdl({
    required super.version,
    required super.name,
    required super.instructions,
    required super.accounts,
    required super.errors,
    required super.types,
    required super.metadata,
    super.address,
  });
}

/// Coder for SPL Token Swap Program instructions and accounts
class SplTokenSwapCoder extends BorshCoder<String, String> {
  SplTokenSwapCoder(Idl idl) : super(idl);
}

/// Creates a comprehensive SPL Token Swap IDL for the Anchor Program
SplTokenSwapIdl _createSplTokenSwapIdl(String programId) {
  return SplTokenSwapIdl(
    version: '3.0.0',
    name: 'spl_token_swap',
    address: programId,
    instructions: [
      IdlInstruction(
        name: 'initialize',
        accounts: [
          IdlInstructionAccount(name: 'swap', writable: true, signer: true),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: false),
          IdlInstructionAccount(name: 'tokenA', writable: false, signer: false),
          IdlInstructionAccount(name: 'tokenB', writable: false, signer: false),
          IdlInstructionAccount(name: 'pool', writable: true, signer: false),
          IdlInstructionAccount(name: 'fee', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'tokenProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'fees', type: IdlType.string()),
          IdlField(name: 'swapCurve', type: IdlType.string()),
        ],
      ),
      IdlInstruction(
        name: 'swap',
        accounts: [
          IdlInstructionAccount(name: 'swap', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'userTransferAuthority', writable: false, signer: true),
          IdlInstructionAccount(name: 'source', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapSource', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapDestination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'poolMint', writable: true, signer: false),
          IdlInstructionAccount(name: 'poolFee', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'tokenProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'amountIn', type: IdlType.u64()),
          IdlField(name: 'minimumAmountOut', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'depositAllTokenTypes',
        accounts: [
          IdlInstructionAccount(name: 'swap', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'userTransferAuthority', writable: false, signer: true),
          IdlInstructionAccount(
              name: 'depositTokenA', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'depositTokenB', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenA', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenB', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'poolMint', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'tokenProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'poolTokenAmount', type: IdlType.u64()),
          IdlField(name: 'maximumTokenAAmount', type: IdlType.u64()),
          IdlField(name: 'maximumTokenBAmount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'withdrawAllTokenTypes',
        accounts: [
          IdlInstructionAccount(name: 'swap', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'userTransferAuthority', writable: false, signer: true),
          IdlInstructionAccount(
              name: 'poolMint', writable: true, signer: false),
          IdlInstructionAccount(name: 'source', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenA', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenB', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destinationTokenA', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destinationTokenB', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'feeAccount', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'tokenProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'poolTokenAmount', type: IdlType.u64()),
          IdlField(name: 'minimumTokenAAmount', type: IdlType.u64()),
          IdlField(name: 'minimumTokenBAmount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'depositSingleTokenTypeExactAmountIn',
        accounts: [
          IdlInstructionAccount(name: 'swap', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'userTransferAuthority', writable: false, signer: true),
          IdlInstructionAccount(
              name: 'sourceToken', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenA', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenB', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'poolMint', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'tokenProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'sourceTokenAmount', type: IdlType.u64()),
          IdlField(name: 'minimumPoolTokenAmount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'withdrawSingleTokenTypeExactAmountOut',
        accounts: [
          IdlInstructionAccount(name: 'swap', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'userTransferAuthority', writable: false, signer: true),
          IdlInstructionAccount(
              name: 'poolMint', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'poolTokenSource', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenA', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'swapTokenB', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'feeAccount', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'tokenProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'destinationTokenAmount', type: IdlType.u64()),
          IdlField(name: 'maximumPoolTokenAmount', type: IdlType.u64()),
        ],
      ),
    ],
    accounts: <IdlAccount>[],
    types: <IdlTypeDef>[],
    errors: [
      IdlErrorCode(
          code: 0, name: 'AlreadyInUse', msg: 'Swap account already in use'),
      IdlErrorCode(
          code: 1,
          name: 'InvalidProgramAddress',
          msg: 'Invalid program address generated from bump seed and key'),
      IdlErrorCode(
          code: 2,
          name: 'InvalidOwner',
          msg: 'Input account owner is not the program address'),
      IdlErrorCode(
          code: 3,
          name: 'InvalidOutputOwner',
          msg: 'Output pool account owner cannot be the program address'),
      IdlErrorCode(
          code: 4,
          name: 'ExpectedMint',
          msg: 'Deserialized account is not an SPL Token mint'),
      IdlErrorCode(
          code: 5,
          name: 'ExpectedAccount',
          msg: 'Deserialized account is not an SPL Token account'),
      IdlErrorCode(
          code: 6, name: 'EmptySupply', msg: 'Input token account empty'),
      IdlErrorCode(
          code: 7,
          name: 'InvalidSupply',
          msg: 'Pool token mint has a non-zero supply'),
      IdlErrorCode(
          code: 8,
          name: 'InvalidDelegate',
          msg: 'Token account has a delegate'),
      IdlErrorCode(code: 9, name: 'InvalidInput', msg: 'InvalidInput'),
      IdlErrorCode(
          code: 10,
          name: 'IncorrectSwapAccount',
          msg: 'Address of the provided swap token account is incorrect'),
      IdlErrorCode(
          code: 11,
          name: 'IncorrectPoolMint',
          msg: 'Address of the provided pool token mint is incorrect'),
      IdlErrorCode(code: 12, name: 'InvalidOutput', msg: 'InvalidOutput'),
      IdlErrorCode(
          code: 13,
          name: 'CalculationFailure',
          msg: 'General calculation failure due to overflow or underflow'),
      IdlErrorCode(
          code: 14, name: 'InvalidInstruction', msg: 'Invalid instruction'),
      IdlErrorCode(
          code: 15,
          name: 'RepeatedMint',
          msg: 'Swap input token accounts have the same mint'),
      IdlErrorCode(
          code: 16,
          name: 'ExceededSlippage',
          msg: 'Swap instruction exceeds desired slippage limit'),
      IdlErrorCode(
          code: 17,
          name: 'InvalidCloseAuthority',
          msg: 'Token account has a close authority'),
      IdlErrorCode(
          code: 18,
          name: 'InvalidFreezeAuthority',
          msg: 'Token account has a freeze authority'),
      IdlErrorCode(
          code: 19,
          name: 'IncorrectFeeAccount',
          msg: 'Pool fee token account is incorrect'),
      IdlErrorCode(
          code: 20,
          name: 'ZeroTradingTokens',
          msg: 'Given pool token amount results in zero trading tokens'),
      IdlErrorCode(
          code: 21,
          name: 'FeeCalculationFailure',
          msg:
              'The fee calculation failed due to overflow, underflow, or unexpected 0'),
      IdlErrorCode(
          code: 22, name: 'ConversionFailure', msg: 'ConversionFailure'),
      IdlErrorCode(
          code: 23,
          name: 'InvalidFee',
          msg:
              'The provided fee does not match the program owner\'s constraints'),
      IdlErrorCode(
          code: 24,
          name: 'IncorrectTokenProgramId',
          msg:
              'The provided token program does not match the token program expected by the swap'),
      IdlErrorCode(
          code: 25,
          name: 'UnsupportedCurveType',
          msg: 'The provided curve type is not supported by the program owner'),
      IdlErrorCode(
          code: 26,
          name: 'InvalidCurve',
          msg: 'The provided curve parameters are invalid'),
      IdlErrorCode(
          code: 27,
          name: 'UnsupportedCurveOperation',
          msg: 'The operation cannot be performed on the given curve'),
    ],
    metadata: IdlMetadata(
      name: 'spl_token_swap',
      version: '3.0.0',
      spec: '0.1.0',
    ),
  );
}
