# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Task 3.2: Anchor-Specific Borsh Extensions (COMPLETED)**

  - Implemented comprehensive Anchor-specific Borsh extensions in `anchor_borsh.dart`
  - Core features:
    - `AnchorBorsh` class with static serialization/deserialization methods
    - PublicKey Borsh serialization and deserialization
    - Account/instruction/event discriminator handling
    - Support for custom discriminators with validation
  - Extension methods for enhanced usability:
    - `PublicKeyBorsh`: Extension methods for PublicKey serialization
    - `AnchorBorshSerializer`: Extension methods for BorshSerializer
    - `AnchorBorshDeserializer`: Extension methods for BorshDeserializer
  - Utilities:
    - Account discriminator generation from account names
    - Instruction discriminator generation from instruction names
    - Event discriminator support for comprehensive Anchor integration
    - Discriminator verification with proper error handling
  - Created comprehensive test suite with 14 tests covering all functionality
  - All tests passing with robust error handling and edge case coverage

- **Dependency Resolution (COMPLETED)**

  - Resolved version conflicts between packages
  - Temporarily disabled conflicting packages:
    - `dart_code_metrics`: Conflicts with `http ^1.1.0` required by `solana`
    - `solana_web3`, `ed25519_hd_key`, `blockchain_utils`: Version conflicts with core packages
    - `solana_mobile_client`: Simplified for initial development
  - Updated external wrappers to use placeholder implementations
  - Enhanced `SolanaRpcWrapper` with proper error handling and future-ready structure
  - Documented all changes in `DEPENDENCIES.md`
  - Package dependencies successfully resolved and ready for development

- **Task 2.2: IDL Utilities (COMPLETED)**

  - Implemented comprehensive IDL utility system in `IdlUtils` class
  - Core utility functions:
    - `idlAddress()`: Generate deterministic IDL address (placeholder for PDA derivation)
    - `idlSeed()`: Standard seed for IDL address generation
    - `convertToCamelCase()`: Convert snake_case IDL to Dart camelCase conventions
    - `validateIdl()`: Comprehensive IDL validation with detailed error reporting
    - `extractTypeReferences()`: Extract all type names referenced in IDL
    - `findAccountsUsingType()`: Find accounts that reference specific types
    - `findInstructionsUsingAccount()`: Find instructions using specific accounts
    - `calculateComplexity()`: IDL complexity analysis and metrics
    - `generateSummary()`: High-level IDL summary for documentation
  - Validation features:
    - Discriminator uniqueness validation for instructions and accounts
    - Type reference consistency checking
    - Field type validation with context-aware error reporting
    - Circular dependency detection
    - Comprehensive error and warning categorization
  - Analysis features:
    - Complexity scoring (0-100 scale) based on structure, field counts, and nesting
    - Type usage analysis and dependency mapping
    - Dead code detection for unused types
    - Cross-reference analysis between instructions, accounts, and types
  - CamelCase conversion:
    - Automatic snake_case to camelCase conversion for Dart conventions
    - Preserves field paths with proper dot notation handling
    - Maintains IDL structure integrity during conversion
  - Result types:
    - `IdlValidationResult`: Structured validation results with errors and warnings
    - `IdlComplexityMetrics`: Detailed complexity analysis with scoring
    - `IdlSummary`: High-level program overview for documentation
  - Comprehensive error handling and null safety throughout
  - Ready for integration with PDA derivation (Phase 3) and account fetching (Phase 4)

- **Task 2.1: IDL Type Definitions (COMPLETED)**

  - Implemented comprehensive IDL type system in `lib/src/idl/idl.dart`
  - Core IDL classes:
    - `Idl`: Main IDL structure with JSON parsing, validation, and lookup methods
    - `IdlMetadata`: Program metadata with versioning and deployment info
    - `IdlInstruction`: Instruction definitions with discriminators, accounts, and args
    - `IdlAccount`: Account type definitions with field specifications
    - `IdlEvent`: Event definitions for program event emissions
    - `IdlErrorCode`: Error code definitions with human-readable messages
    - `IdlTypeDef`: Custom type definitions for program-specific types
    - `IdlConst`: Program constant definitions
    - `IdlField`: Field definitions with type information and documentation
    - `IdlType`: Comprehensive type system supporting all Anchor/Borsh types
  - Advanced type support:
    - Primitive types (bool, u8-u128, i8-i128, f32, f64, string, publicKey, bytes)
    - Collection types (vec, array with size specification)
    - Optional types (option wrapper)
    - Custom defined types with references
    - Struct types with field definitions
    - Enum types with variant support (including tuple/struct variants)
  - JSON serialization/deserialization for all IDL components
  - IDL validation with comprehensive error reporting
  - Lookup methods for instructions, accounts, events, errors, types, and constants
  - Type introspection methods (isPrimitive, isCollection, isOptional, isDefined)
  - Proper error handling and null safety throughout
  - Comprehensive documentation and string representations

- **Borsh Serialization System (Phase 3.1 - COMPLETED)**

  - Implemented comprehensive Borsh serialization from scratch following the official specification
  - Added `BorshSerializer` with support for all basic types: u8, u16, u32, u64, bool, string, arrays, options
  - Created `BorshDeserializer` with little-endian integer support and proper error handling
  - Implemented `BorshUtils` with Anchor-specific discriminator generation for accounts and instructions
  - Added `BorshStruct` base class and `BorshSerializableMixin` for custom data structures
  - Updated `BorshWrapper` to use the new implementation instead of placeholder code
  - Created 27 comprehensive tests covering all serialization/deserialization scenarios
  - All tests pass with proper type safety and error handling

- Initial project structure and roadmap
- Basic package configuration
- Core module placeholders
- Development environment setup
- External dependency wrappers for consistent API design
- Comprehensive dependency analysis and selection
- SolanaRpcWrapper for enhanced RPC operations
- BorshWrapper for Anchor-specific serialization
- CryptoWrapper for ED25519 operations and HD key derivation
- EncodingWrapper for Base58, Base64, and hex encoding
- DEPENDENCIES.md with complete dependency documentation
- Task implementation reporting system
- **Task 1.3**: Complete basic type definitions system

  - PublicKey class with base58/hex support and PDA derivation
  - Keypair class with multiple creation methods and wallet interface
  - Transaction types (Transaction, TransactionInstruction, AccountMeta, Signature)
  - Commitment level enums and configuration
  - Connection configuration with network presets
  - Comprehensive utility classes (ByteUtils, StringUtils, NumberUtils)
  - Result type for error handling
  - Custom exception types for different error scenarios

- **Test Type Fixes (COMPLETED)**
  - Fixed all `List<int>` vs `Uint8List` type errors in test files
  - Corrected exception type expectations in `external_wrappers_test.dart`
  - Updated test cases to use proper `Uint8List.fromList()` conversions
  - Enhanced hex validation tests with better error type coverage
  - All tests now pass without type-related compilation errors

### Changed

- Updated pubspec.yaml with carefully selected external packages
- Enhanced project structure with external wrapper layer

### Dependencies Added

- solana: ^0.31.2+1 (Primary Solana RPC client)
- borsh: ^0.3.2 (Borsh serialization)
- cryptography: ^2.7.0 (ED25519 cryptography)
- ed25519_hd_key: ^2.3.0 (HD key derivation)
- bs58: ^1.0.2 (Base58 encoding)
- base_codecs: ^1.0.1 (Additional encodings)
- blockchain_utils: ^5.0.0 (Comprehensive utilities)

### Deprecated

- N/A

### Removed

- N/A

### Fixed

- N/A

### Security

- N/A

## [0.1.0] - 2024-XX-XX

### Added

- Initial release with basic project structure
- Comprehensive roadmap for development
- Core architecture planning
- Documentation framework
