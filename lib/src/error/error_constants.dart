/// Anchor error code constants matching TypeScript implementation
///
/// This module provides error code constants with exact numeric values matching
/// the TypeScript Anchor client's error system for full compatibility.
library;

/// Instruction error codes (100-999)
class InstructionErrorCode {
  /// 8 byte instruction identifier not provided
  static const int instructionMissing = 100;

  /// Fallback functions are not supported
  static const int instructionFallbackNotFound = 101;

  /// The program could not deserialize the given instruction
  static const int instructionDidNotDeserialize = 102;

  /// The program could not serialize the given instruction
  static const int instructionDidNotSerialize = 103;
}

/// IDL instruction error codes (1000-1999)
class IdlInstructionErrorCode {
  /// The program was compiled without idl instructions
  static const int idlInstructionMissing = 1000;

  /// The transaction was given an invalid program for the IDL instruction
  static const int idlInstructionInvalidProgram = 1001;

  /// IDL account must be empty in order to resize, try closing first
  static const int idlAccountNotEmpty = 1002;

  /// IDL instruction parsing failed
  static const int idlInstructionParseError = 1003;

  /// IDL instruction serialization failed
  static const int idlInstructionSerializeError = 1004;

  /// IDL instruction deserialization failed
  static const int idlInstructionDeserializeError = 1005;

  /// IDL instruction execution failed
  static const int idlInstructionExecutionError = 1006;

  /// IDL instruction fallback not found
  static const int idlInstructionFallbackNotFound = 1007;

  /// IDL instruction data is invalid
  static const int idlInstructionInvalidData = 1008;
}

/// Event instruction error codes (1500-1999)
class EventInstructionErrorCode {
  /// The program was compiled without `event-cpi` feature
  static const int eventInstructionMissing = 1500;

  /// Event instruction parsing failed
  static const int eventInstructionParseError = 1501;

  /// Event instruction serialization failed
  static const int eventInstructionSerializeError = 1502;

  /// Event instruction deserialization failed
  static const int eventInstructionDeserializeError = 1503;

  /// Event instruction execution failed
  static const int eventInstructionExecutionError = 1504;

  /// Event instruction fallback not found
  static const int eventInstructionFallbackNotFound = 1505;

  /// Event instruction data is invalid
  static const int eventInstructionInvalidData = 1506;
}

/// Constraint error codes (2000-2499)
class ConstraintErrorCode {
  /// A mut constraint was violated
  static const int constraintMut = 2000;

  /// A has one constraint was violated
  static const int constraintHasOne = 2001;

  /// A signer constraint was violated
  static const int constraintSigner = 2002;

  /// A raw constraint was violated
  static const int constraintRaw = 2003;

  /// An owner constraint was violated
  static const int constraintOwner = 2004;

  /// A rent exemption constraint was violated
  static const int constraintRentExempt = 2005;

  /// A seeds constraint was violated
  static const int constraintSeeds = 2006;

  /// An executable constraint was violated
  static const int constraintExecutable = 2007;

  /// Deprecated Error, feel free to replace with something else
  static const int constraintState = 2008;

  /// An associated constraint was violated
  static const int constraintAssociated = 2009;

  /// An associated init constraint was violated
  static const int constraintAssociatedInit = 2010;

  /// A close constraint was violated
  static const int constraintClose = 2011;

  /// An address constraint was violated
  static const int constraintAddress = 2012;

  /// Expected zero account discriminant
  static const int constraintZero = 2013;

  /// A token mint constraint was violated
  static const int constraintTokenMint = 2014;

  /// A token owner constraint was violated
  static const int constraintTokenOwner = 2015;

  /// A mint mint authority constraint was violated
  static const int constraintMintMintAuthority = 2016;

  /// A mint freeze authority constraint was violated
  static const int constraintMintFreezeAuthority = 2017;

  /// A mint decimals constraint was violated
  static const int constraintMintDecimals = 2018;

  /// A space constraint was violated
  static const int constraintSpace = 2019;

  /// A required account for the constraint is None
  static const int constraintAccountIsNone = 2020;

  /// A token account token program constraint was violated
  static const int constraintTokenTokenProgram = 2021;

  /// A mint token program constraint was violated
  static const int constraintMintTokenProgram = 2022;

  /// An associated token account token program constraint was violated
  static const int constraintAssociatedTokenTokenProgram = 2023;

  /// A group pointer extension constraint was violated
  static const int constraintMintGroupPointerExtension = 2024;

  /// A group pointer extension authority constraint was violated
  static const int constraintMintGroupPointerExtensionAuthority = 2025;

  /// A group pointer extension group address constraint was violated
  static const int constraintMintGroupPointerExtensionGroupAddress = 2026;

  /// A group member pointer extension constraint was violated
  static const int constraintMintGroupMemberPointerExtension = 2027;

  /// A group member pointer extension authority constraint was violated
  static const int constraintMintGroupMemberPointerExtensionAuthority = 2028;

  /// A group member pointer extension group address constraint was violated
  static const int constraintMintGroupMemberPointerExtensionMemberAddress =
      2029;

  /// A metadata pointer extension constraint was violated
  static const int constraintMintMetadataPointerExtension = 2030;

  /// A metadata pointer extension authority constraint was violated
  static const int constraintMintMetadataPointerExtensionAuthority = 2031;

  /// A metadata pointer extension metadata address constraint was violated
  static const int constraintMintMetadataPointerExtensionMetadataAddress = 2032;

  /// A close authority constraint was violated
  static const int constraintMintCloseAuthorityExtension = 2033;

  /// A close authority extension authority constraint was violated
  static const int constraintMintCloseAuthorityExtensionAuthority = 2034;

  /// A permanent delegate extension constraint was violated
  static const int constraintMintPermanentDelegateExtension = 2035;

  /// A permanent delegate extension delegate constraint was violated
  static const int constraintMintPermanentDelegateExtensionDelegate = 2036;

  /// A transfer hook extension constraint was violated
  static const int constraintMintTransferHookExtension = 2037;

  /// A transfer hook extension authority constraint was violated
  static const int constraintMintTransferHookExtensionAuthority = 2038;

  /// A transfer hook extension transfer hook program id constraint was violated
  static const int constraintMintTransferHookExtensionProgramId = 2039;
}

/// Require error codes (2500-2999)
class RequireErrorCode {
  /// A require expression was violated
  static const int requireViolated = 2500;

  /// A require_eq expression was violated
  static const int requireEqViolated = 2501;

  /// A require_keys_eq expression was violated
  static const int requireKeysEqViolated = 2502;

  /// A require_neq expression was violated
  static const int requireNeqViolated = 2503;

  /// A require_keys_neq expression was violated
  static const int requireKeysNeqViolated = 2504;

  /// A require_gt expression was violated
  static const int requireGtViolated = 2505;

  /// A require_gte expression was violated
  static const int requireGteViolated = 2506;
}

/// Account error codes (3000-3999)
class AccountErrorCode {
  /// The account discriminator was already set on this account
  static const int accountDiscriminatorAlreadySet = 3000;

  /// No 8 byte discriminator was found on the account
  static const int accountDiscriminatorNotFound = 3001;

  /// 8 byte discriminator did not match what was expected
  static const int accountDiscriminatorMismatch = 3002;

  /// Failed to deserialize the account
  static const int accountDidNotDeserialize = 3003;

  /// Failed to serialize the account
  static const int accountDidNotSerialize = 3004;

  /// Not enough account keys given to the instruction
  static const int accountNotEnoughKeys = 3005;

  /// The given account is not mutable
  static const int accountNotMutable = 3006;

  /// The given account is owned by a different program than expected
  static const int accountOwnedByWrongProgram = 3007;

  /// Program ID was not as expected
  static const int invalidProgramId = 3008;

  /// Program account is not executable
  static const int invalidProgramExecutable = 3009;

  /// The given account did not sign
  static const int accountNotSigner = 3010;

  /// The given account is not owned by the system program
  static const int accountNotSystemOwned = 3011;

  /// The program expected this account to be already initialized
  static const int accountNotInitialized = 3012;

  /// The given account is not a program data account
  static const int accountNotProgramData = 3013;

  /// The given account is not the associated token account
  static const int accountNotAssociatedTokenAccount = 3014;

  /// The given public key does not match the required sysvar
  static const int accountSysvarMismatch = 3015;

  /// The account reallocation exceeds the MAX_PERMITTED_DATA_INCREASE limit
  static const int accountReallocExceedsLimit = 3016;

  /// The account was duplicated for more than one reallocation
  static const int accountDuplicateReallocs = 3017;
}

/// Miscellaneous error codes (4100-4999)
class MiscellaneousErrorCode {
  /// The declared program id does not match the actual program id
  static const int declaredProgramIdMismatch = 4100;

  /// You cannot/should not initialize the payer account as a program account
  static const int tryingToInitPayerAsProgramAccount = 4101;

  /// The program could not perform the numeric conversion, out of range integral type conversion attempted
  static const int invalidNumericConversion = 4102;
}

/// Deprecated error codes (5000)
class DeprecatedErrorCode {
  /// The API being used is deprecated and should no longer be used
  static const int deprecated = 5000;
}

/// Combined error code constants matching TypeScript LangErrorCode
class LangErrorCode {
  // Instructions
  static const int instructionMissing = InstructionErrorCode.instructionMissing;
  static const int instructionFallbackNotFound =
      InstructionErrorCode.instructionFallbackNotFound;
  static const int instructionDidNotDeserialize =
      InstructionErrorCode.instructionDidNotDeserialize;
  static const int instructionDidNotSerialize =
      InstructionErrorCode.instructionDidNotSerialize;

  // IDL instructions
  static const int idlInstructionMissing =
      IdlInstructionErrorCode.idlInstructionMissing;
  static const int idlInstructionInvalidProgram =
      IdlInstructionErrorCode.idlInstructionInvalidProgram;
  static const int idlAccountNotEmpty =
      IdlInstructionErrorCode.idlAccountNotEmpty;
  static const int idlInstructionParseError =
      IdlInstructionErrorCode.idlInstructionParseError;
  static const int idlInstructionSerializeError =
      IdlInstructionErrorCode.idlInstructionSerializeError;
  static const int idlInstructionDeserializeError =
      IdlInstructionErrorCode.idlInstructionDeserializeError;
  static const int idlInstructionExecutionError =
      IdlInstructionErrorCode.idlInstructionExecutionError;
  static const int idlInstructionFallbackNotFound =
      IdlInstructionErrorCode.idlInstructionFallbackNotFound;
  static const int idlInstructionInvalidData =
      IdlInstructionErrorCode.idlInstructionInvalidData;

  // Event instructions
  static const int eventInstructionMissing =
      EventInstructionErrorCode.eventInstructionMissing;
  static const int eventInstructionParseError =
      EventInstructionErrorCode.eventInstructionParseError;
  static const int eventInstructionSerializeError =
      EventInstructionErrorCode.eventInstructionSerializeError;
  static const int eventInstructionDeserializeError =
      EventInstructionErrorCode.eventInstructionDeserializeError;
  static const int eventInstructionExecutionError =
      EventInstructionErrorCode.eventInstructionExecutionError;
  static const int eventInstructionFallbackNotFound =
      EventInstructionErrorCode.eventInstructionFallbackNotFound;
  static const int eventInstructionInvalidData =
      EventInstructionErrorCode.eventInstructionInvalidData;

  // Constraints
  static const int constraintMut = ConstraintErrorCode.constraintMut;
  static const int constraintHasOne = ConstraintErrorCode.constraintHasOne;
  static const int constraintSigner = ConstraintErrorCode.constraintSigner;
  static const int constraintRaw = ConstraintErrorCode.constraintRaw;
  static const int constraintOwner = ConstraintErrorCode.constraintOwner;
  static const int constraintRentExempt =
      ConstraintErrorCode.constraintRentExempt;
  static const int constraintSeeds = ConstraintErrorCode.constraintSeeds;
  static const int constraintExecutable =
      ConstraintErrorCode.constraintExecutable;
  static const int constraintState = ConstraintErrorCode.constraintState;
  static const int constraintAssociated =
      ConstraintErrorCode.constraintAssociated;
  static const int constraintAssociatedInit =
      ConstraintErrorCode.constraintAssociatedInit;
  static const int constraintClose = ConstraintErrorCode.constraintClose;
  static const int constraintAddress = ConstraintErrorCode.constraintAddress;
  static const int constraintZero = ConstraintErrorCode.constraintZero;
  static const int constraintTokenMint =
      ConstraintErrorCode.constraintTokenMint;
  static const int constraintTokenOwner =
      ConstraintErrorCode.constraintTokenOwner;
  static const int constraintMintMintAuthority =
      ConstraintErrorCode.constraintMintMintAuthority;
  static const int constraintMintFreezeAuthority =
      ConstraintErrorCode.constraintMintFreezeAuthority;
  static const int constraintMintDecimals =
      ConstraintErrorCode.constraintMintDecimals;
  static const int constraintSpace = ConstraintErrorCode.constraintSpace;
  static const int constraintAccountIsNone =
      ConstraintErrorCode.constraintAccountIsNone;
  static const int constraintTokenTokenProgram =
      ConstraintErrorCode.constraintTokenTokenProgram;
  static const int constraintMintTokenProgram =
      ConstraintErrorCode.constraintMintTokenProgram;
  static const int constraintAssociatedTokenTokenProgram =
      ConstraintErrorCode.constraintAssociatedTokenTokenProgram;
  static const int constraintMintGroupPointerExtension =
      ConstraintErrorCode.constraintMintGroupPointerExtension;
  static const int constraintMintGroupPointerExtensionAuthority =
      ConstraintErrorCode.constraintMintGroupPointerExtensionAuthority;
  static const int constraintMintGroupPointerExtensionGroupAddress =
      ConstraintErrorCode.constraintMintGroupPointerExtensionGroupAddress;
  static const int constraintMintGroupMemberPointerExtension =
      ConstraintErrorCode.constraintMintGroupMemberPointerExtension;
  static const int constraintMintGroupMemberPointerExtensionAuthority =
      ConstraintErrorCode.constraintMintGroupMemberPointerExtensionAuthority;
  static const int constraintMintGroupMemberPointerExtensionMemberAddress =
      ConstraintErrorCode
          .constraintMintGroupMemberPointerExtensionMemberAddress;
  static const int constraintMintMetadataPointerExtension =
      ConstraintErrorCode.constraintMintMetadataPointerExtension;
  static const int constraintMintMetadataPointerExtensionAuthority =
      ConstraintErrorCode.constraintMintMetadataPointerExtensionAuthority;
  static const int constraintMintMetadataPointerExtensionMetadataAddress =
      ConstraintErrorCode.constraintMintMetadataPointerExtensionMetadataAddress;
  static const int constraintMintCloseAuthorityExtension =
      ConstraintErrorCode.constraintMintCloseAuthorityExtension;
  static const int constraintMintCloseAuthorityExtensionAuthority =
      ConstraintErrorCode.constraintMintCloseAuthorityExtensionAuthority;
  static const int constraintMintPermanentDelegateExtension =
      ConstraintErrorCode.constraintMintPermanentDelegateExtension;
  static const int constraintMintPermanentDelegateExtensionDelegate =
      ConstraintErrorCode.constraintMintPermanentDelegateExtensionDelegate;
  static const int constraintMintTransferHookExtension =
      ConstraintErrorCode.constraintMintTransferHookExtension;
  static const int constraintMintTransferHookExtensionAuthority =
      ConstraintErrorCode.constraintMintTransferHookExtensionAuthority;
  static const int constraintMintTransferHookExtensionProgramId =
      ConstraintErrorCode.constraintMintTransferHookExtensionProgramId;

  // Require
  static const int requireViolated = RequireErrorCode.requireViolated;
  static const int requireEqViolated = RequireErrorCode.requireEqViolated;
  static const int requireKeysEqViolated =
      RequireErrorCode.requireKeysEqViolated;
  static const int requireNeqViolated = RequireErrorCode.requireNeqViolated;
  static const int requireKeysNeqViolated =
      RequireErrorCode.requireKeysNeqViolated;
  static const int requireGtViolated = RequireErrorCode.requireGtViolated;
  static const int requireGteViolated = RequireErrorCode.requireGteViolated;

  // Accounts
  static const int accountDiscriminatorAlreadySet =
      AccountErrorCode.accountDiscriminatorAlreadySet;
  static const int accountDiscriminatorNotFound =
      AccountErrorCode.accountDiscriminatorNotFound;
  static const int accountDiscriminatorMismatch =
      AccountErrorCode.accountDiscriminatorMismatch;
  static const int accountDidNotDeserialize =
      AccountErrorCode.accountDidNotDeserialize;
  static const int accountDidNotSerialize =
      AccountErrorCode.accountDidNotSerialize;
  static const int accountNotEnoughKeys = AccountErrorCode.accountNotEnoughKeys;
  static const int accountNotMutable = AccountErrorCode.accountNotMutable;
  static const int accountOwnedByWrongProgram =
      AccountErrorCode.accountOwnedByWrongProgram;
  static const int invalidProgramId = AccountErrorCode.invalidProgramId;
  static const int invalidProgramExecutable =
      AccountErrorCode.invalidProgramExecutable;
  static const int accountNotSigner = AccountErrorCode.accountNotSigner;
  static const int accountNotSystemOwned =
      AccountErrorCode.accountNotSystemOwned;
  static const int accountNotInitialized =
      AccountErrorCode.accountNotInitialized;
  static const int accountNotProgramData =
      AccountErrorCode.accountNotProgramData;
  static const int accountNotAssociatedTokenAccount =
      AccountErrorCode.accountNotAssociatedTokenAccount;
  static const int accountSysvarMismatch =
      AccountErrorCode.accountSysvarMismatch;
  static const int accountReallocExceedsLimit =
      AccountErrorCode.accountReallocExceedsLimit;
  static const int accountDuplicateReallocs =
      AccountErrorCode.accountDuplicateReallocs;

  // Miscellaneous
  static const int declaredProgramIdMismatch =
      MiscellaneousErrorCode.declaredProgramIdMismatch;
  static const int tryingToInitPayerAsProgramAccount =
      MiscellaneousErrorCode.tryingToInitPayerAsProgramAccount;
  static const int invalidNumericConversion =
      MiscellaneousErrorCode.invalidNumericConversion;

  // Deprecated
  static const int deprecated = DeprecatedErrorCode.deprecated;
}

/// Error code to message mapping matching TypeScript LangErrorMessage
const Map<int, String> langErrorMessage = {
  // Instructions
  LangErrorCode.instructionMissing: 'Instruction discriminator not provided',
  LangErrorCode.instructionFallbackNotFound:
      'Fallback functions are not supported',
  LangErrorCode.instructionDidNotDeserialize:
      'The program could not deserialize the given instruction',
  LangErrorCode.instructionDidNotSerialize:
      'The program could not serialize the given instruction',

  // IDL instructions
  LangErrorCode.idlInstructionMissing:
      'The program was compiled without idl instructions',
  LangErrorCode.idlInstructionInvalidProgram:
      'The transaction was given an invalid program for the IDL instruction',
  LangErrorCode.idlAccountNotEmpty:
      'IDL account must be empty in order to resize, try closing first',
  LangErrorCode.idlInstructionParseError: 'IDL instruction parsing failed',
  LangErrorCode.idlInstructionSerializeError:
      'IDL instruction serialization failed',
  LangErrorCode.idlInstructionDeserializeError:
      'IDL instruction deserialization failed',
  LangErrorCode.idlInstructionExecutionError:
      'IDL instruction execution failed',
  LangErrorCode.idlInstructionFallbackNotFound:
      'IDL instruction fallback not found',
  LangErrorCode.idlInstructionInvalidData: 'IDL instruction data is invalid',

  // Event instructions
  LangErrorCode.eventInstructionMissing:
      'The program was compiled without `event-cpi` feature',
  LangErrorCode.eventInstructionParseError: 'Event instruction parsing failed',
  LangErrorCode.eventInstructionSerializeError:
      'Event instruction serialization failed',
  LangErrorCode.eventInstructionDeserializeError:
      'Event instruction deserialization failed',
  LangErrorCode.eventInstructionExecutionError:
      'Event instruction execution failed',
  LangErrorCode.eventInstructionFallbackNotFound:
      'Event instruction fallback not found',
  LangErrorCode.eventInstructionInvalidData:
      'Event instruction data is invalid',

  // Constraints
  LangErrorCode.constraintMut: 'A mut constraint was violated',
  LangErrorCode.constraintHasOne: 'A has one constraint was violated',
  LangErrorCode.constraintSigner: 'A signer constraint was violated',
  LangErrorCode.constraintRaw: 'A raw constraint was violated',
  LangErrorCode.constraintOwner: 'An owner constraint was violated',
  LangErrorCode.constraintRentExempt:
      'A rent exemption constraint was violated',
  LangErrorCode.constraintSeeds: 'A seeds constraint was violated',
  LangErrorCode.constraintExecutable: 'An executable constraint was violated',
  LangErrorCode.constraintState:
      'Deprecated Error, feel free to replace with something else',
  LangErrorCode.constraintAssociated: 'An associated constraint was violated',
  LangErrorCode.constraintAssociatedInit:
      'An associated init constraint was violated',
  LangErrorCode.constraintClose: 'A close constraint was violated',
  LangErrorCode.constraintAddress: 'An address constraint was violated',
  LangErrorCode.constraintZero: 'Expected zero account discriminant',
  LangErrorCode.constraintTokenMint: 'A token mint constraint was violated',
  LangErrorCode.constraintTokenOwner: 'A token owner constraint was violated',
  LangErrorCode.constraintMintMintAuthority:
      'A mint mint authority constraint was violated',
  LangErrorCode.constraintMintFreezeAuthority:
      'A mint freeze authority constraint was violated',
  LangErrorCode.constraintMintDecimals:
      'A mint decimals constraint was violated',
  LangErrorCode.constraintSpace: 'A space constraint was violated',
  LangErrorCode.constraintAccountIsNone:
      'A required account for the constraint is None',
  LangErrorCode.constraintTokenTokenProgram:
      'A token account token program constraint was violated',
  LangErrorCode.constraintMintTokenProgram:
      'A mint token program constraint was violated',
  LangErrorCode.constraintAssociatedTokenTokenProgram:
      'An associated token account token program constraint was violated',
  LangErrorCode.constraintMintGroupPointerExtension:
      'A group pointer extension constraint was violated',
  LangErrorCode.constraintMintGroupPointerExtensionAuthority:
      'A group pointer extension authority constraint was violated',
  LangErrorCode.constraintMintGroupPointerExtensionGroupAddress:
      'A group pointer extension group address constraint was violated',
  LangErrorCode.constraintMintGroupMemberPointerExtension:
      'A group member pointer extension constraint was violated',
  LangErrorCode.constraintMintGroupMemberPointerExtensionAuthority:
      'A group member pointer extension authority constraint was violated',
  LangErrorCode.constraintMintGroupMemberPointerExtensionMemberAddress:
      'A group member pointer extension group address constraint was violated',
  LangErrorCode.constraintMintMetadataPointerExtension:
      'A metadata pointer extension constraint was violated',
  LangErrorCode.constraintMintMetadataPointerExtensionAuthority:
      'A metadata pointer extension authority constraint was violated',
  LangErrorCode.constraintMintMetadataPointerExtensionMetadataAddress:
      'A metadata pointer extension metadata address constraint was violated',
  LangErrorCode.constraintMintCloseAuthorityExtension:
      'A close authority constraint was violated',
  LangErrorCode.constraintMintCloseAuthorityExtensionAuthority:
      'A close authority extension authority constraint was violated',
  LangErrorCode.constraintMintPermanentDelegateExtension:
      'A permanent delegate extension constraint was violated',
  LangErrorCode.constraintMintPermanentDelegateExtensionDelegate:
      'A permanent delegate extension delegate constraint was violated',
  LangErrorCode.constraintMintTransferHookExtension:
      'A transfer hook extension constraint was violated',
  LangErrorCode.constraintMintTransferHookExtensionAuthority:
      'A transfer hook extension authority constraint was violated',
  LangErrorCode.constraintMintTransferHookExtensionProgramId:
      'A transfer hook extension transfer hook program id constraint was violated',

  // Require
  LangErrorCode.requireViolated: 'A require expression was violated',
  LangErrorCode.requireEqViolated: 'A require_eq expression was violated',
  LangErrorCode.requireKeysEqViolated:
      'A require_keys_eq expression was violated',
  LangErrorCode.requireNeqViolated: 'A require_neq expression was violated',
  LangErrorCode.requireKeysNeqViolated:
      'A require_keys_neq expression was violated',
  LangErrorCode.requireGtViolated: 'A require_gt expression was violated',
  LangErrorCode.requireGteViolated: 'A require_gte expression was violated',

  // Accounts
  LangErrorCode.accountDiscriminatorAlreadySet:
      'The account discriminator was already set on this account',
  LangErrorCode.accountDiscriminatorNotFound:
      'No discriminator was found on the account',
  LangErrorCode.accountDiscriminatorMismatch:
      'Account discriminator did not match what was expected',
  LangErrorCode.accountDidNotDeserialize: 'Failed to deserialize the account',
  LangErrorCode.accountDidNotSerialize: 'Failed to serialize the account',
  LangErrorCode.accountNotEnoughKeys:
      'Not enough account keys given to the instruction',
  LangErrorCode.accountNotMutable: 'The given account is not mutable',
  LangErrorCode.accountOwnedByWrongProgram:
      'The given account is owned by a different program than expected',
  LangErrorCode.invalidProgramId: 'Program ID was not as expected',
  LangErrorCode.invalidProgramExecutable: 'Program account is not executable',
  LangErrorCode.accountNotSigner: 'The given account did not sign',
  LangErrorCode.accountNotSystemOwned:
      'The given account is not owned by the system program',
  LangErrorCode.accountNotInitialized:
      'The program expected this account to be already initialized',
  LangErrorCode.accountNotProgramData:
      'The given account is not a program data account',
  LangErrorCode.accountNotAssociatedTokenAccount:
      'The given account is not the associated token account',
  LangErrorCode.accountSysvarMismatch:
      'The given public key does not match the required sysvar',
  LangErrorCode.accountReallocExceedsLimit:
      'The account reallocation exceeds the MAX_PERMITTED_DATA_INCREASE limit',
  LangErrorCode.accountDuplicateReallocs:
      'The account was duplicated for more than one reallocation',

  // Miscellaneous
  LangErrorCode.declaredProgramIdMismatch:
      'The declared program id does not match the actual program id',
  LangErrorCode.tryingToInitPayerAsProgramAccount:
      'You cannot/should not initialize the payer account as a program account',
  LangErrorCode.invalidNumericConversion:
      'The program could not perform the numeric conversion, out of range integral type conversion attempted',

  // Deprecated
  LangErrorCode.deprecated:
      'The API being used is deprecated and should no longer be used',
};

/// Helper function to get error message for a given error code
String getErrorMessage(int errorCode) =>
    langErrorMessage[errorCode] ?? 'Unknown error code: $errorCode';
