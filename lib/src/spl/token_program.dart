/// SPL Token Program integration for Anchor
///
/// This module provides Anchor-style access to the SPL Token Program
/// with exact TypeScript SDK compatibility. It leverages the existing
/// comprehensive SPL Token implementation from the espresso-cash-public package.
library;

import '../provider/anchor_provider.dart';
import '../program/program_class.dart';
import '../idl/idl.dart';
import '../coder/main_coder.dart';
import '../utils/logger.dart';

/// SPL Token Program ID
const String SPL_TOKEN_PROGRAM_ID =
    "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";

/// SPL Token 2022 Program ID
const String SPL_TOKEN_2022_PROGRAM_ID =
    "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb";

/// Parameters for creating a Token Program instance
class GetTokenProgramParams {
  /// Optional program ID (defaults to SPL_TOKEN_PROGRAM_ID)
  final String? programId;

  /// Optional provider (uses default if not provided)
  final AnchorProvider? provider;

  const GetTokenProgramParams({
    this.programId,
    this.provider,
  });
}

/// Creates an SPL Token Program instance matching TypeScript SDK
///
/// Matches TypeScript: splTokenProgram(params?: GetProgramParams): Program<SplToken>
Program<SplTokenIdl> splTokenProgram([GetTokenProgramParams? params]) {
  final programId = params?.programId ?? SPL_TOKEN_PROGRAM_ID;
  final provider = params?.provider;

  final logger = AnchorLogger.getLogger('SplTokenProgram');
  logger.debug('Creating SPL Token Program with ID: $programId');

  return Program<SplTokenIdl>(
    _createSplTokenIdl(programId),
    provider: provider,
    coder: SplTokenCoder(_createSplTokenIdl(programId)),
  );
}

/// Creates an SPL Token 2022 Program instance
///
/// Extension of the original Token Program with additional features
Program<SplTokenIdl> splToken2022Program([GetTokenProgramParams? params]) {
  final programId = params?.programId ?? SPL_TOKEN_2022_PROGRAM_ID;
  final provider = params?.provider;

  final logger = AnchorLogger.getLogger('SplToken2022Program');
  logger.debug('Creating SPL Token 2022 Program with ID: $programId');

  return Program<SplTokenIdl>(
    _createSplTokenIdl(programId),
    provider: provider,
    coder: SplTokenCoder(_createSplTokenIdl(programId)),
  );
}

/// SPL Token IDL type definition
class SplTokenIdl extends Idl {
  SplTokenIdl({
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

/// Coder for SPL Token Program instructions and accounts
class SplTokenCoder extends BorshCoder<String, String> {
  SplTokenCoder(Idl idl) : super(idl);
}

/// Creates a minimal SPL Token IDL for the Anchor Program
SplTokenIdl _createSplTokenIdl(String programId) {
  return SplTokenIdl(
    version: '3.3.0',
    name: 'spl_token',
    address: programId,
    instructions: [
      IdlInstruction(
        name: 'initializeMint',
        accounts: [
          IdlInstructionAccount(name: 'mint', writable: true, signer: false),
          IdlInstructionAccount(name: 'rent', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'decimals', type: IdlType.u8()),
          IdlField(name: 'mintAuthority', type: IdlType.publicKey()),
          IdlField(
              name: 'freezeAuthority',
              type: IdlType.option(IdlType.publicKey())),
        ],
      ),
      IdlInstruction(
        name: 'initializeAccount',
        accounts: [
          IdlInstructionAccount(name: 'account', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: false, signer: false),
          IdlInstructionAccount(name: 'owner', writable: false, signer: false),
          IdlInstructionAccount(name: 'rent', writable: false, signer: false),
        ],
        args: [],
      ),
      IdlInstruction(
        name: 'transfer',
        accounts: [
          IdlInstructionAccount(name: 'source', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'approve',
        accounts: [
          IdlInstructionAccount(name: 'source', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'delegate', writable: false, signer: false),
          IdlInstructionAccount(name: 'owner', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'mintTo',
        accounts: [
          IdlInstructionAccount(name: 'mint', writable: true, signer: false),
          IdlInstructionAccount(name: 'to', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'burn',
        accounts: [
          IdlInstructionAccount(name: 'account', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
        ],
      ),
      IdlInstruction(
        name: 'closeAccount',
        accounts: [
          IdlInstructionAccount(name: 'account', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(name: 'owner', writable: false, signer: true),
        ],
        args: [],
      ),
      IdlInstruction(
        name: 'freezeAccount',
        accounts: [
          IdlInstructionAccount(name: 'account', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'freezeAuthority', writable: false, signer: true),
        ],
        args: [],
      ),
      IdlInstruction(
        name: 'thawAccount',
        accounts: [
          IdlInstructionAccount(name: 'account', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'freezeAuthority', writable: false, signer: true),
        ],
        args: [],
      ),
      IdlInstruction(
        name: 'transferChecked',
        accounts: [
          IdlInstructionAccount(name: 'source', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'destination', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
          IdlField(name: 'decimals', type: IdlType.u8()),
        ],
      ),
      IdlInstruction(
        name: 'approveChecked',
        accounts: [
          IdlInstructionAccount(name: 'source', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'delegate', writable: false, signer: false),
          IdlInstructionAccount(name: 'owner', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
          IdlField(name: 'decimals', type: IdlType.u8()),
        ],
      ),
      IdlInstruction(
        name: 'mintToChecked',
        accounts: [
          IdlInstructionAccount(name: 'mint', writable: true, signer: false),
          IdlInstructionAccount(name: 'to', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
          IdlField(name: 'decimals', type: IdlType.u8()),
        ],
      ),
      IdlInstruction(
        name: 'burnChecked',
        accounts: [
          IdlInstructionAccount(name: 'account', writable: true, signer: false),
          IdlInstructionAccount(name: 'mint', writable: false, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'amount', type: IdlType.u64()),
          IdlField(name: 'decimals', type: IdlType.u8()),
        ],
      ),
    ],
    accounts: [],
    types: [
      IdlTypeDef(
        name: 'Account',
        type: const IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(name: 'mint', type: IdlType(kind: 'pubkey')),
            IdlField(name: 'owner', type: IdlType(kind: 'pubkey')),
            IdlField(name: 'amount', type: IdlType(kind: 'u64')),
            IdlField(
                name: 'delegate',
                type: IdlType(kind: 'option', inner: IdlType(kind: 'pubkey'))),
            IdlField(name: 'state', type: IdlType(kind: 'u8')),
            IdlField(
                name: 'isNative',
                type: IdlType(kind: 'option', inner: IdlType(kind: 'u64'))),
            IdlField(name: 'delegatedAmount', type: IdlType(kind: 'u64')),
            IdlField(
                name: 'closeAuthority',
                type: IdlType(kind: 'option', inner: IdlType(kind: 'pubkey'))),
          ],
        ),
      ),
      IdlTypeDef(
        name: 'Mint',
        type: const IdlTypeDefType(
          kind: 'struct',
          fields: [
            IdlField(
                name: 'mintAuthority',
                type: IdlType(kind: 'option', inner: IdlType(kind: 'pubkey'))),
            IdlField(name: 'supply', type: IdlType(kind: 'u64')),
            IdlField(name: 'decimals', type: IdlType(kind: 'u8')),
            IdlField(name: 'isInitialized', type: IdlType(kind: 'bool')),
            IdlField(
                name: 'freezeAuthority',
                type: IdlType(kind: 'option', inner: IdlType(kind: 'pubkey'))),
          ],
        ),
      ),
    ],
    errors: [],
    metadata: const IdlMetadata(
      name: 'spl_token',
      version: '3.3.0',
      spec: '0.1.0',
    ),
  );
}
