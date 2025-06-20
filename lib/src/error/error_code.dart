/// Error codes that can be returned by internal framework code
/// 
/// - >= 100 Instruction error codes
/// - >= 1000 IDL error codes
/// - >= 2000 constraint error codes
/// - >= 3000 account error codes
/// - >= 4100 misc error codes
/// - = 5000 deprecated error code
class AnchorErrorCode {
  // Instruction Errors (100-999)
  static const instructionMissing = 100;
  static const instructionFallbackNotFound = 101;
  static const instructionDidNotDeserialize = 102;
  static const instructionDidNotSerialize = 103;

  // IDL Errors (1000-1999)
  static const idlInstructionStub = 1000;
  static const idlInstructionInvalidProgram = 1001;

  // Constraint Errors (2000-2999)
  static const constraintMut = 2000;
  static const constraintHasOne = 2001;
  static const constraintSigner = 2002;
  static const constraintRaw = 2003;
  static const constraintOwner = 2004;
  static const constraintRentExempt = 2005;
  static const constraintSeeds = 2006;
  static const constraintExecutable = 2007;
  static const constraintState = 2008;
  static const constraintAssociated = 2009;
  static const constraintAssociatedInit = 2010;
  static const constraintClose = 2011;
  static const constraintAddress = 2012;
  static const constraintZero = 2013;
  static const constraintTokenMint = 2014;
  static const constraintTokenOwner = 2015;
  static const constraintMintMintAuthority = 2016;
  static const constraintMintFreezeAuthority = 2017;
  static const constraintMintDecimals = 2018;
  static const constraintSpace = 2019;
  static const constraintAssociatedTokenMint = 2020;

  // Account Errors (3000-3999)
  static const accountNotEnoughKeys = 3000;
  static const accountDiscriminatorMismatch = 3001;
  static const accountDidNotDeserialize = 3002;
  static const accountDidNotSerialize = 3003;
  static const accountNotMutable = 3004;
  static const accountOwnedByWrongProgram = 3005;
  static const invalidProgramId = 3006;
  static const invalidProgramExecutable = 3007;
  static const accountNotSigner = 3008;
  static const accountNotSystemOwned = 3009;
  static const accountNotInitialized = 3010;
  static const accountNotProgramData = 3011;
  static const accountNotAssociatedTokenAccount = 3012;
  static const accountSysvarMismatch = 3013;
  static const accountReallocExceedsLimit = 3014;
  static const accountDuplicateReallocs = 3015;

  // Miscellaneous Errors (4100-4999)
  static const declaredProgramIdMismatch = 4100;
  static const initPayerAsProgram = 4101;
  static const invalidNumericConversion = 4102;

  // Deprecated Errors (5000)
  static const deprecated = 5000;

  // The starting point for user defined error codes
  static const userErrorOffset = 6000;
}

/// Represents a custom program error with message
class ProgramError {
  final int code;
  final String message;
  final String? programId;
  final String? fileLine;

  const ProgramError({
    required this.code,
    required this.message,
    this.programId,
    this.fileLine,
  });

  @override
  String toString() {
    final parts = <String>[];
    parts.add('Error Code: $code');
    parts.add('Error Message: $message');
    if (programId != null) parts.add('Program: $programId');
    if (fileLine != null) parts.add('Location: $fileLine');
    return parts.join(', ');
  }
}

/// Map of common error codes to their messages
const defaultErrorMap = {
  AnchorErrorCode.instructionMissing: 'Instruction missing from data',
  AnchorErrorCode.instructionFallbackNotFound: 'Fallback functions are not supported',
  AnchorErrorCode.instructionDidNotDeserialize: 'Failed to deserialize instruction',
  AnchorErrorCode.instructionDidNotSerialize: 'Failed to serialize instruction',
  AnchorErrorCode.idlInstructionStub: 'IDL instruction stub',
  AnchorErrorCode.idlInstructionInvalidProgram: 'IDL instruction invalid program',
  // ... Add more default error messages
};
