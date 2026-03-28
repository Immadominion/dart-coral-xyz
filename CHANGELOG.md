# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-beta.9] - 2026-03-28

### Added

- **Quasar framework support**: Full IDL parsing, zero-copy account decoding with explicit discriminators, instruction encoding, and PDA derivation for Quasar programs
- **Pinocchio/Codama support**: `CodamaParser` for Pinocchio program IDLs and `ProgramInterface.define()` for manual interface definition without IDL files
- **Quasar-SVM FFI bindings**: In-process Solana program execution via `dart:ffi` — run deterministic tests without `solana-test-validator`. Includes `QuasarSvm`, `ExecutionResult`, account factories, and sysvar configuration
- **Multi-format IDL detection**: Automatic format detection (Anchor, Quasar, Codama) in `Idl.fromJson()`
- **`AccountsCoderFactory`**: Dispatches to `BorshAccountsCoder` or `ZeroCopyAccountsCoder` based on IDL format
- **`DiscriminatorComputer`**: Unified discriminator handling for Anchor (SHA256), Quasar (explicit), and manual discriminators
- **`PdaSeedResolver`**: Resolves PDA seeds from IDL definitions (const, account, arg seeds)
- **`PdaDerivationEngine`**: Derives program addresses from IDL-defined PDA specifications
- **`EventAuthority`**: PDA derivation for Quasar `emit_cpi!` event patterns
- **764 tests**: 730 non-integration + 34 integration tests, including 293 verification tests across all three frameworks

### Fixed

- **`AccountFetcher.all()` filter plumbing** (HIGH): Discriminator and user-provided filters were constructed but never passed to `getProgramAccounts`. All `fetchAll(filters: ...)` calls now work correctly.
- **`TypeSafeMethodBuilder.view()` decode** (MEDIUM): Was returning raw base64 string instead of decoded value. Now decodes through `base64Decode()` then `_coder.types.decode()`, matching `ViewsNamespace` behavior.
- **Connection silent fallbacks**: Removed 19 try/catch blocks from `connection.dart` that swallowed RPC errors and returned fake values (`[]`, `0`, `null`). All RPC methods now propagate errors.
- **Keypair sync factory traps**: Removed 3 sync constructors (`fromSecretKey`, `fromBase58`, `fromJson`) that always threw `UnimplementedError`. Use async variants instead.
- **IDL parser: array generic size**: `IdlType.fromJson` crashed on `{"array": ["u8", {"generic": "N"}]}`. Now handles generic const sizes.
- **IDL parser: PDA seed arg null type**: `IdlSeedArg.fromJson` crashed when seed type was absent (common in complex IDLs). Made `type` nullable.
- **IDL parser: tuple struct fields**: `IdlTypeDefType.fromJson` crashed on tuple fields (bare type strings instead of `{name, type}` maps). Added tuple field detection.

### Changed

- **BREAKING**: Upgraded `solana` dependency from `^0.31.2+1` to `^0.32.0`
- **BREAKING**: Dart SDK constraint raised from `^3.7.0` to `^3.9.0`
- **BREAKING**: Moved `analyzer`, `build`, and `source_gen` to separate `coral_xyz_codegen` package. The main package no longer pulls in build-time dependencies.
- Removed unused dependencies: `toml`, `bs58`, `http`, `web_socket_channel`, `base_codecs`, `blockchain_utils`, `cryptography`, `ed25519_hd_key`, `equatable`, `borsh`
- Removed facade/mock code from production lib: `connection_pool.dart`, `enhanced_connection.dart`, `error_monitoring.dart`, `error_recovery.dart`, `production_error_handler.dart`, `error_framework.dart`, `discriminator_cache.dart`, `discriminator_validator.dart`, and others
- Collapsed 14-file error system to core error types only
- `MockProvider.createDefault()` changed from sync to async factory
- `createTestProgram()` changed from sync to async

### Removed

- `ROADMAP.md`, `TESTING_ROADMAP.md`, `VERIFICATION_ROADMAP.md`, `PHASE9_SPEC.md`, `TS_VS_DART_COMPARISON.md` — internal development artifacts
- `doc/` directory with hallucinated integration guides
- Enterprise bloat: `CircuitBreaker`, `ErrorRecoveryExecutor`, `CpiFramework`, `ProgramManager`, `BorshWrapper`, event persistence/replay modules

## [1.0.0-beta.8] - 2025-10-19

### Fixed

- Runtime dependency pollution causing conflicts in consumer applications
- Removed `toml` dependency (eliminated petitparser 6.x lock conflicting with Flutter packages)
- Relaxed `web_socket_channel` constraint from `^3.0.0` to `>=2.0.0 <4.0.0`
- Removed unused `borsh` and `borsh_annotation` external dependencies

### Changed

- **Minor breaking change**: `WorkspaceConfig.read()` throws `UnsupportedError` without `toml` dependency. Add `toml: ^0.16.0` manually if needed.

## [1.0.0-beta.7] - 2025-10-19

### Changed

- Upgraded build-time dependencies: `analyzer` ^6.4.1 -> ^8.4.0, `build` ^2.4.1 -> ^4.0.2, `source_gen` ^1.5.0 -> ^4.0.2, `build_runner` ^2.4.7 -> ^2.9.0
- Upgraded core dependencies: `blockchain_utils` ^5.2.0, `http` ^1.2.0, `meta` ^1.16.0, `path` ^1.9.0
- Upgraded dev dependencies: `mockito` ^5.5.1, `test` ^1.25.0
- Removed `borsh` and `borsh_annotation` as runtime dependencies (internal Borsh implementation used instead)

### Fixed

- Dependency version conflicts caused by `borsh` constraining `source_gen` to <3.0.0

## [1.0.0-beta.6] - 2025-09-20

### Fixed

- **BREAKING**: Fixed `AnchorProvider` wallet interface violation — removed hard-coded `wallet as KeypairWallet` casts, now calls `wallet!.signTransaction()` / `wallet!.signAllTransactions()` to support any wallet implementation
- Fixed GitHub repository URL returning 404

### Added

- TypeScript SDK `utils.*` module parity: `sha256`, `bytes`, `publicKey`, `token`, `features`, `registry`, `rpc`
- VersionedTransaction support (v0 format, Address Lookup Tables, size estimation)
- SPL Token Swap Program with full IDL (6 instructions, 27 error codes)
- Transaction simulation via espresso-cash components
- Workspace lazy loading with dynamic program access and IDL auto-discovery
- `Keypair.fromFile()` for loading Solana CLI JSON wallets

## [1.0.0] - 2025-08-04

### Added

- Complete Anchor Program interface: method builders, account fetching, transaction construction
- IDL parsing, validation, and type generation
- Provider system with wallet integration and connection management
- Dynamic namespace generation (methods, accounts, instructions, transactions)
- Event system with real-time listening, parsing, and filtering
- Borsh serialization with Anchor-specific extensions and discriminators
- Cross-platform support (Flutter, web, desktop)

### Fixed

- PDA derivation `ConstraintSeeds` error (0x7d6) — delegated to `solana` package implementation
- Error handling standardized to use `FormatException` for PDA errors

## [1.0.0-beta.5] - 2025-09-20

Consolidates beta.4 changes (shipped without changelog) plus publishing prep.

### Added

- Versioned Transactions (v0) with size estimation and message compilation
- SPL modules: `token_program`, `associated_token_account_program`, `token_swap_program`
- Event system: TS-compatible parser, type converters, program subscriptions
- IDL/coder improvements: `idl_coder`, `idl_extensions`, enhanced type/instruction/event coders
- Utility modules for TypeScript parity: `sha256`, `bytes`, `hex`, `token`, `registry`, `rpc`
- PDA engine improvements, `AccountFilter` type
- Issue templates and PR template

### Changed

- **BREAKING**: Wallet interface — removed implicit `KeypairWallet` casts
- Transaction builder refactors, connection pooling, enhanced RPC handling
- Namespace refactors for account fetching, simulations, and transactions
- Public entrypoint aligned to `lib/coral_xyz.dart`

### Removed

- Debug/performance scaffolding, legacy compatibility shims, exploratory tests

## [1.0.0-beta.4] - 2025-09-06

See beta.5 entry (beta.4 shipped without changelog).
