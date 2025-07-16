# Dart Coral XYZ - Anchor Client for Dart

## Overview

This project aims to create a comprehensive Dart client for Anchor programs that mirrors the functionality of#### Task 5.2: Account Coder ✅

- [x] Create AccountsCoder interface
- [x] Implement account data encoding/decoding
- [x] Add account discriminator verification
- [x] Create account size calculation utilities
- [x] Implement account memory comparison utilities (memcmp)
- [x] Add comprehensive test coverage (28 tests)
- [x] Integrate with main coder system
- [x] Export in main librarypeScript `@coral-xyz/anchor` package. The goal is to make interacting with Anchor programs as easy and intuitive in Dart as it is in TypeScript, while leveraging Dart's strengths like strong typing, null safety, and excellent async/await support.

## Architecture Analysis from TypeScript Implementation

The TypeScript Anchor client consists of several key components:

1. **Provider Layer** - Connection management and wallet integration
2. **Program Layer** - IDL-based program interface generation
3. **Coder Layer** - Borsh serialization/deserialization
4. **Namespace Factories** - Dynamic API generation (methods, accounts, events)
5. **Utils Layer** - Common utilities for addresses, bytes, RPC calls
6. **Event System** - Program event listening and parsing
7. **Workspace Integration** - Development environment support

## Dart Strengths to Leverage

- Strong type system with null safety
- Excellent async/await support
- Built-in JSON serialization capabilities
- Good cross-platform support (mobile, web, desktop)
- Efficient memory management
- Code generation capabilities

## Dart Limitations to Consider

- Limited native crypto libraries (need external packages)
- No direct equivalent to Node.js buffer handling
- Different approach to dynamic property access
- Web3 ecosystem is still developing in Dart

## Project Structure

```
dart-coral-xyz/
├── lib/
│   ├── src/
│   │   ├── provider/
│   │   ├── program/
│   │   ├── coder/
│   │   ├── idl/
│   │   ├── utils/
│   │   ├── native/
│   │   └── workspace/
│   ├── coral_xyz_anchor.dart
├── example/
├── test/
├── pubspec.yaml
├── CHANGELOG.md
├── README.md
└── LICENSE
```

---

## DEVELOPMENT ROADMAP

### Phase 1: Foundation & Core Infrastructure

#### Task 1.1: Project Setup and Basic Structure ✅

- [x] Create complete pubspec.yaml with all required dependencies
- [x] Set up proper Dart package structure following pub.dev conventions
- [x] Create basic library exports in coral_xyz_anchor.dart
- [x] Set up linting rules and analysis_options.yaml
- [x] Create initial README.md and documentation structure
- [x] Set up GitHub Actions for CI/CD (testing, formatting, pub.dev publishing)

#### Task 1.2: Core Dependencies and External Packages ✅

- [x] Research and integrate Solana Web3 Dart packages
- [x] Add crypto dependencies (for key generation, signing)
- [x] Add HTTP client dependencies for RPC calls
- [x] Add serialization dependencies (for Borsh encoding/decoding)
- [x] Create wrapper classes for external dependencies to ensure consistent API

#### Task 1.3: Basic Type Definitions ✅

- [x] Create PublicKey class (equivalent to Solana's PublicKey)
- [x] Create Keypair class for key management
- [x] Define basic transaction types
- [x] Create commitment level enums
- [x] Define connection configuration types

### Phase 2: IDL System Foundation

#### Task 2.1: IDL Type Definitions ✅

- [x] Create comprehensive IDL type classes (Idl, IdlMetadata, IdlInstruction, etc.)
- [x] Implement IDL JSON parsing and validation
- [x] Create type-safe IDL account definitions
- [x] Implement IDL instruction definitions
- [x] Add IDL event and error definitions

#### Task 2.2: IDL Utilities ✅

- [x] Create IDL address derivation functions
- [x] Implement IDL account fetching from on-chain
- [x] Add IDL inflation/compression utilities
- [x] Create IDL validation functions
- [x] Implement camelCase conversion utilities for Dart naming conventions

### Phase 3: Borsh Serialization System

#### Task 3.1: Borsh Types Foundation ✅

- [x] Research existing Dart Borsh implementations or create from scratch
- [x] Implement basic Borsh type serializers (u8, u16, u32, u64, bool, string)
- [x] Create Borsh array and vector serializers
- [x] Implement Borsh option (nullable) type serializers
- [x] Add Borsh struct serialization capabilities

#### Task 3.2: Anchor-Specific Borsh Extensions ✅

- [x] Implement PublicKey Borsh serialization
- [x] Create discriminator handling for Anchor accounts/instructions
- [x] Add support for Anchor's 8-byte account discriminators
- [x] Implement instruction discriminator generation
- [x] Create custom serializers for Anchor-specific types

### Phase 4: Provider System

#### Task 4.1: Connection Management ✅

- [x] Create Connection class for RPC communication
- [x] Implement connection configuration and endpoint management
- [x] Add support for different commitment levels
- [x] Create RPC method wrappers for common operations
- [x] Implement connection health checking and retry logic

#### Task 4.2: Wallet Integration ✅

- [x] Create abstract Wallet interface
- [x] Implement basic Keypair wallet
- [x] Add transaction signing capabilities
- [x] Create wallet public key management
- [x] Design extension points for external wallet integrations

#### Task 4.3: Provider Implementation ✅

- [x] Create AnchorProvider class combining connection and wallet
- [x] Implement transaction sending and confirmation
- [x] Add batch transaction support
- [x] Create transaction simulation capabilities
- [x] Implement proper error handling and logging

### Phase 5: Coder System Architecture

#### Task 5.1: Instruction Coder ✅

- [x] Create InstructionCoder interface
- [x] Implement Borsh-based instruction encoding
- [x] Add instruction discriminator handling
- [x] Create instruction argument serialization
- [x] Implement instruction data validation
- [x] Add support for all primitive types (bool, u8-u64, i8-i64, string, pubkey)
- [x] Add support for complex types (arrays, vectors, options)
- [x] Implement instruction decoding with discriminator verification
- [x] Add instruction formatting for debugging and analysis
- [x] Create comprehensive test suite covering all functionality
- [x] Handle optional fields correctly (null values for option types)

#### Task 5.2: Account Coder ✅

- [x] Create AccountsCoder interface
- [x] Implement account data encoding/decoding
- [x] Add account discriminator verification
- [x] Create account size calculation utilities
- [x] Implement account memory comparison utilities (memcmp)
- [x] Add comprehensive test coverage (28 tests)
- [x] Integrate with main coder system
- [x] Export in main library

#### Task 5.3: Event and Types Coders ✅

- [x] Create EventCoder interface for parsing program events
- [x] Implement EventCoder with Borsh-based encoding/decoding
- [x] Add event log parsing and filtering capabilities
- [x] Create TypesCoder interface for user-defined types
- [x] Implement TypesCoder with recursive type serialization
- [x] Add support for structs, enums, and primitive types
- [x] Create comprehensive test coverage (EventCoder: 16+ tests, TypesCoder: 19+ tests)
- [x] Integrate with main coder system and export in main library
- [x] Add proper error handling and edge case management

### Phase 6: Program Interface System

#### Task 6.1: Program Class Foundation ✅

- [x] Create base Program class with IDL-based initialization
- [x] Implement program ID and provider management
- [x] Add program account fetching capabilities
- [x] Create basic program validation and utilities
- [x] Implement static methods for IDL fetching (fetchIdl, at)
- [x] Add IDL address derivation utilities
- [x] Create comprehensive test suite with 9+ tests
- [x] Integrate with existing coder and provider systems
- [x] Export in main library

#### Task 6.2: Namespace Generation System ✅

- [x] Design dynamic namespace generation architecture
- [x] Create MethodsNamespace for instruction building
- [x] Implement RpcNamespace for direct RPC calls
- [x] Add TransactionNamespace for transaction building
- [x] Create AccountNamespace for account operations
- [x] Implement InstructionNamespace and SimulateNamespace
- [x] Add NamespaceFactory for centralized namespace creation
- [x] Create comprehensive test suite for namespace system
- [x] Integrate with Program class and export in main library

#### Task 6.3: Context and Address Resolution ✅

- [x] Implement Context class for instruction contexts
- [x] Create automatic address resolution system
- [x] Add PDA (Program Derived Address) utilities
- [x] Implement account relationship mapping
- [x] Create address validation and verification

### Phase 7: Instruction and Transaction Building

#### Task 7.1: Instruction Builder ✅

- [x] Create instruction builder with fluent API
- [x] Implement account meta generation
- [x] Add instruction data serialization
- [x] Create instruction validation system
- [x] Implement signer and writable account detection

#### Task 7.2: Transaction Management ✅

- [x] Create transaction builder with multiple instructions
- [x] Implement transaction fee calculation
- [x] Add transaction size optimization
- [x] Create transaction simulation and dry-run
- [x] Implement transaction confirmation tracking

#### Task 7.3: Method Interface Generation ✅

- [x] Create dynamic method generation from IDL
- [x] Implement type-safe method parameters
- [x] Add automatic instruction building
- [x] Create return value handling
- [x] Implement error propagation from methods

### Phase 8: Account Management System

#### Task 8.1: Account Fetching ✅

- [x] Implement single account fetching
- [x] Create batch account fetching capabilities
- [x] Add account change subscription system
- [x] Implement account filtering and sorting
- [x] Create account caching mechanism

#### Task 8.2: Account Creation and Management ✅

- [x] Create account initialization utilities
- [x] Implement account rent calculation
- [x] Add account reallocation support
- [x] Create account closing utilities
- [x] Implement account ownership validation
- [x] Add comprehensive test coverage (17 tests)

### Phase 9: Event System ✅

#### Task 9.1: Event Listening Infrastructure ✅

- [x] Create event system architecture and types
- [x] Implement EventContext and ParsedEvent classes
- [x] Create EventFilter for filtering events by criteria
- [x] Implement EventParser for parsing program logs
- [x] Create EventManager for WebSocket subscription management
- [x] Add EventSubscription interface and implementations
- [x] Implement PausableEventListener for pausable event handling
- [x] Create BatchedEventListener for batched event processing
- [x] Add FilteredEventListener for advanced filtering
- [x] Implement HistoryEventListener for maintaining event history
- [x] Create EventReplay system for historical event processing
- [x] Add comprehensive test coverage (13 tests)
- [x] Export in main library

#### Task 9.2: Event Processing ✅

- [x] Create typed event classes from IDL
- [x] Implement event data deserialization via BorshEventCoder
- [x] Add event callback system with typed callbacks
- [x] Create event stats tracking and metrics
- [x] Implement event error handling
- [x] Add LogsNotification for WebSocket log events
- [x] Create EventSubscriptionConfig for subscription configuration
- [x] Implement event filter composition and logic

### Phase 10: Utilities and Helper Functions

#### Task 10.1: Address and Key Utilities ✅

- [x] Create PDA derivation functions
- [x] Implement address validation utilities
- [x] Add key format conversion functions
- [x] Create address shortening and formatting
- [x] Implement seed-based address generation

#### Task 10.2: Data Conversion Utilities ✅

- [x] Create bytes/Buffer manipulation utilities
- [x] Implement base58 encoding/decoding
- [x] Add number conversion utilities (BN equivalent)
- [x] Create endianness handling utilities
- [x] Implement data validation functions

#### Task 10.3: RPC and Network Utilities ✅

- [x] Create custom RPC method implementations
  - Enhanced getMultipleAccounts with batching
  - simulateTransaction with detailed results
  - Custom makeRequest with monitoring
- [x] Add network detection and configuration
  - SolanaNetwork enum (mainnet, testnet, devnet, localhost, custom)
  - detectNetwork(), getDefaultRpcUrl(), getDefaultWebSocketUrl()
  - createNetworkConfig() for automatic setup
- [x] Implement request/response logging
  - RpcLoggingConfig with preset configurations
  - Configurable logging for requests, responses, errors, timing
- [x] Create timeout and retry mechanisms
  - Per-request timeout configuration
  - Exponential backoff retry logic
  - Network-specific default timeouts
- [x] Add performance monitoring utilities
  - RpcPerformanceStats with success/failure tracking
  - Response time monitoring (min, max, average)
  - Statistics export and reset functionality

### Phase 11: Testing Infrastructure

#### Task 11.1: Unit Testing Framework ✅

- [x] Set up comprehensive unit test suite
- [x] Create mock providers and connections
- [x] Implement test utilities for account creation
- [x] Add test helpers for instruction building
- [x] Create assertion helpers for Anchor-specific data

#### Task 11.2: Integration Testing ✅

- [x] Set up local Solana test validator integration
- [x] Create end-to-end test scenarios
- [x] Implement cross-program testing
- [x] Add performance benchmarking tests
- [x] Create compatibility tests with TS implementation

### Phase 12: Documentation and Examples ✅

#### Task 12.1: API Documentation ✅

- [x] Generate comprehensive dartdoc documentation
- [x] Create API reference with examples
- [x] Add inline code examples for all public APIs
- [x] Create migration guide from TypeScript
- [x] Implement documentation testing

#### Task 12.2: Example Projects ✅

- [x] Create basic hello-world example
- [x] Implement comprehensive basic usage example
- [x] Add complete program interaction example
- [x] Create event system usage example
- [x] Add mobile/Flutter app integration example
- [x] Create comprehensive examples README with usage patterns

### Phase 13: Advanced Features

#### Task 13.1: Workspace Integration ✅

- [x] Create local Anchor workspace detection
- [x] Implement automatic IDL loading from workspace
- [x] Add program deployment utilities
- [x] Create test environment setup
- [x] Implement development mode features

#### Task 13.2: Performance Optimizations ✅

- [x] Implement connection pooling
- [x] Add request batching capabilities
- [x] Create intelligent caching systems
- [x] Optimize serialization performance
- [x] Implement lazy loading for large IDLs

### Phase 14: Publishing and Distribution

#### Task 14.1: Package Preparation ⏳

- [ ] Finalize pubspec.yaml for pub.dev
- [ ] Create comprehensive CHANGELOG.md
- [ ] Implement semantic versioning strategy
- [ ] Add package metadata and keywords
- [ ] Create package health and quality metrics

#### Task 14.2: Community and Ecosystem ⏳

- [ ] Create contribution guidelines
- [ ] Set up issue templates and PR templates
- [ ] Implement community feedback collection
- [ ] Create roadmap for future enhancements
- [ ] Add integration guides for popular Dart frameworks

---

## ASSESSMENT FINDINGS AND RECENT IMPROVEMENTS

### Critical Issues Identified and Resolved

#### Issue 1: Simplified IDL Structure (FIXED ✅)

**Problem**: The original Dart IDL system was significantly simplified compared to the TypeScript Anchor standard:

- Missing PDA/seed support (`IdlPda`, `IdlSeed`, `IdlSeedConst`, `IdlSeedArg`, `IdlSeedAccount`)
- No advanced account relationships (`writable`, `signer`, `address`, `relations`)
- Lacking comprehensive type system (generics, arrays, options, defined types)
- Missing account composition support (`IdlInstructionAccounts` vs single accounts)

**Solution Implemented**:

- ✅ Added full PDA/seed support with `IdlPda`, `IdlSeed` variants
- ✅ Enhanced `IdlInstructionAccount` with `writable`, `signer`, `optional`, `address`, `pda`, `relations`
- ✅ Added `IdlInstructionAccounts` for account composition
- ✅ Updated account resolver to handle new PDA derivation and relationship resolution
- ✅ Maintained backward compatibility with legacy field names (`isMut`, `isSigner`, `isOptional`)

#### Issue 2: Account Resolution System (ENHANCED ✅)

**Problem**: The existing accounts resolver didn't support the enhanced IDL structure.

**Solution Implemented**:

- ✅ Updated `AccountsResolver` to work with new IDL structure
- ✅ Added proper PDA derivation using `IdlPda` specifications
- ✅ Implemented seed-to-bytes conversion for `IdlSeedConst`, `IdlSeedArg`, `IdlSeedAccount`
- ✅ Added support for account relationships and nested account groups
- ✅ Enhanced missing account detection for optional vs required accounts

### Components Requiring Updates Due to IDL Enhancement

#### 1. Coder System (NEEDS UPDATE 🔄)

**Status**: Marked as ✅ COMPLETED but needs updating
**Issues**:

- TypesCoder may not handle the enhanced type system properly
- Account coder needs integration with new PDA-aware account structures
- Event coder may need updates for enhanced event definitions

#### 2. Program Interface System (NEEDS UPDATE 🔄)

**Status**: Marked as ✅ COMPLETED but may be subpar
**Issues**:

- Program class may not leverage enhanced account resolution
- Namespace generation may not use new PDA capabilities
- Context system integration with enhanced IDL features

#### 3. Missing Implementation Components (HIGH PRIORITY ⚠️)

Based on TypeScript reference, several critical components are missing:

**Account Management:**

- Automatic account resolution in instruction building
- PDA derivation utilities as part of program interface
- Account relationship traversal
- Account data fetching with enhanced IDL awareness

**Instruction Building:**

- Integration with enhanced account resolution
- Automatic PDA derivation during instruction building
- Context-aware account population

**Type System:**

- Full TypeScript parity for advanced IDL types
- Generic type support
- Complex nested type handling

### Next Priority Actions

#### Immediate (Next Session)

1. **Update TypesCoder** to handle enhanced IDL type system ✅ (robust, matches enhanced IDL and TS reference)
2. **Update Program Interface** to leverage enhanced account resolution ✅ (async account resolution, robust PDA/relations support)
3. **Test Integration** between enhanced IDL and existing coder system ✅ (unit/integration tests pass, robust compatibility)

#### Short Term

1. **Update Namespace Generation** to use PDA-aware account resolution ✅ (all namespace builders use async PDA-aware path)
2. **Enhance Instruction Building** with automatic account resolution ✅ (all instruction building is PDA-aware and async)
3. **Add Missing Type System Components** for full TypeScript parity ✅ (Enhanced IDL system with generics, advanced types, full TS parity completed)

#### Medium Term

1. **Complete Missing Phase 7-8 Components** (instruction/transaction building, account management)
2. **Add Event System** with enhanced IDL awareness
3. **Implement Advanced Features** (workspace integration, performance optimizations)

### Impact Assessment

**Positive Impacts**:

- ✅ Dart IDL now has feature parity with TypeScript for core PDA/account functionality
- ✅ Enhanced account resolution enables more sophisticated program interactions
- ✅ Foundation laid for full TypeScript compatibility

**Remaining Gaps**:

- 🔄 Some "completed" components need updates to leverage enhanced IDL
- ⚠️ Phase 7-8 (instruction/transaction building) are critical missing pieces
- ⚠️ Event system and advanced features still need implementation

### Conclusion

The IDL enhancement represents a major step toward TypeScript parity. The foundation is now solid, but several "completed" components need updates to fully leverage the enhanced capabilities. The roadmap should be updated to reflect these findings and prioritize integration work alongside missing component implementation.

---

## Success Criteria

1. **Functional Parity**: All core TypeScript functionality replicated in Dart
2. **Type Safety**: Full type safety with null safety compliance
3. **Performance**: Comparable or better performance than TypeScript version
4. **Documentation**: Comprehensive documentation with examples
5. **Testing**: 95%+ test coverage with integration tests
6. **Community**: Active usage and contribution from Dart/Flutter community

## Timeline Estimation

- **Phase 1-4**: 2-3 weeks (Foundation)
- **Phase 5-8**: 4-5 weeks (Core Implementation)
- **Phase 9-12**: 3-4 weeks (Advanced Features & Testing)
- **Phase 13-14**: 1-2 weeks (Polish & Publishing)

**Total Estimated Timeline**: 10-14 weeks

## Notes for Implementation

- Each task should be implementable within a single context window
- Tasks build upon each other - later tasks depend on earlier ones
- Focus on creating idiomatic Dart code that feels natural to Dart developers
- Maintain compatibility with the TypeScript API where possible
- Prioritize type safety and null safety throughout
- Consider mobile/Flutter-specific optimizations where applicable
