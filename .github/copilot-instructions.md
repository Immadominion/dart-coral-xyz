# Copilot Instructions — coral_xyz

## Project Overview

`coral_xyz` is a universal Dart client for Solana programs supporting **Anchor**, **Quasar**, and **Pinocchio** frameworks. It provides dynamic IDL-based program interactions, Borsh serialization, event subscriptions, PDA derivation, and cross-program invocation — all from Dart/Flutter.

Code generation lives in a separate sibling package: `coral_xyz_codegen`.

## Architecture

```
dart-coral-xyz/
├── lib/coral_xyz.dart          # Barrel export (single public API surface)
├── lib/src/
│   ├── account/                # Account definitions & metadata
│   ├── codegen/                # Annotations only (generators moved to coral_xyz_codegen)
│   ├── coder/                  # Borsh serialization — accounts, instructions, events, types
│   ├── error/                  # Error framework — anchor errors, RPC errors, monitoring
│   ├── event/                  # Event system — parsing, subscriptions, aggregation, replay
│   ├── external/               # Thin wrappers around borsh & encoding
│   ├── idl/                    # IDL parsing (Anchor + Quasar format)
│   ├── instruction/            # Instruction definitions
│   ├── native/                 # Native Solana programs (SystemProgram)
│   ├── pda/                    # PDA derivation, caching, definitions
│   ├── program/                # Core Program class, method builders, namespaces
│   │   └── namespace/          # Account, instruction, RPC, simulate, transaction namespaces
│   ├── provider/               # Connection, AnchorProvider, wallet adapters, connection pool
│   ├── spl/                    # SPL Token, ATA, Token Swap wrappers
│   ├── transaction/            # Transaction building and simulation
│   ├── types/                  # PublicKey, Keypair, Transaction, common types
│   ├── utils/                  # Binary reader/writer, SHA256, token utils, encoding
│   ├── wallet/                 # Wallet adapters, mobile wallet adapter, discovery
│   └── workspace/              # Workspace management, CPI framework, program manager
```

### Sibling Package: coral_xyz_codegen

```
coral_xyz_codegen/
├── lib/builder.dart            # build_runner entry point
├── lib/coral_xyz_codegen.dart  # Barrel export
├── lib/src/
│   ├── anchor_generator.dart   # Main source_gen generator
│   ├── build_config.dart       # Builder factories
│   └── generators/             # Account, error, instruction, program, type generators
```

## Key Dependencies

- **solana** (espresso-cash): `^0.32.0` — RPC client, Ed25519, token programs
- **crypto/cryptography**: SHA256 discriminators, Ed25519
- **build/source_gen/analyzer**: Only in `coral_xyz_codegen` (NOT in main package)

## Conventions

- **Dart SDK**: `^3.9.0` (required by solana 0.32.0 package)
- **Barrel exports**: Everything public goes through `lib/coral_xyz.dart` with `show`/`hide` to control API surface
- **PublicKey**: Use `coral_xyz`'s `PublicKey` class (wraps espresso-cash `Ed25519HDPublicKey`)
- **IDL**: Parse via `Idl.fromJson()` — supports both Anchor and modern IDL formats
- **Discriminators**: Anchor uses SHA256 8-byte; Quasar uses explicit 1–4 byte; both supported
- **Borsh**: All serialization through `coder/` module — `BorshAccountsCoder`, `InstructionCoder`, etc.
- **Errors**: Custom error classes extend `ProgramError`; error codes map to IDL errors
- **No toml**: `workspace_config.dart` can't parse Anchor.toml (toml package removed for Flutter compat)

## Build & Test

```bash
cd dart-coral-xyz
dart pub get
dart analyze
dart test

# Code generation (requires coral_xyz_codegen)
dart run build_runner build
```

## Common Patterns

### Loading a program from IDL
```dart
final program = Program(idl, programId, provider);
final result = await program.methods.myInstruction(arg1: value).rpc();
```

### PDA derivation
```dart
final [pda, bump] = await PublicKey.findProgramAddress(
  [utf8.encode('seed'), owner.toBytes()],
  programId,
);
```

### Event subscription
```dart
program.addEventListener('MyEvent', (event, slot, signature) {
  print('Got event: $event');
});
```

## What NOT to Do

- Don't add `analyzer`, `build`, or `source_gen` to the main `coral_xyz` package
- Don't import `dart:io` in files that need to work on web/Flutter
- Don't duplicate SPL token logic — use espresso-cash re-exports from `utils/token.dart`
- Don't add the `toml` package — it causes petitparser conflicts with Flutter
- Don't create `*_new.dart`, `*_temp.dart`, or `*_backup.dart` files — use version control instead
