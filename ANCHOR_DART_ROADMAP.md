# Anchor Dart SDK Parity Roadmap

This roadmap outlines the steps to bring the Dart Anchor SDK (`dart-coral-xyz`) up to parity with the TypeScript Anchor SDK, including wallet/signature integration and other key features.

---

## 1. Wallet/Signature Integration (Highest Priority)

**Goal:** Allow any Wallet (Keypair, MWA, browser, etc.) to sign transactions as expected by Anchor.

### Steps:

- Define a robust Wallet interface (review for completeness):
  - `Future<Transaction> signTransaction(Transaction tx)`
  - `Future<List<Transaction>> signAllTransactions(List<Transaction> txs)`
  - `Future<Uint8List> signMessage(Uint8List message)`
  - `PublicKey get publicKey`
- Implement a MobileWalletAdapterWallet:
  - Create a class that implements `Wallet` and wraps a MobileWalletAdapter client.
  - In `signTransaction`, call the MWA client’s `signTransactions` with the compiled message bytes, attach the returned signature to the transaction, and return it.
  - In `signAllTransactions`, do the same for a batch.
  - Ensure `signMessage` is either implemented or throws `UnimplementedError`.
- Update AnchorProvider and Program usage:
  - When initializing the provider, pass an instance of your MWA wallet when using a mobile wallet.
  - Ensure the correct wallet is used for all transaction flows.
- Test end-to-end:
  - Write integration tests that use both KeypairWallet and MWA wallet to sign and send transactions.
  - Confirm that transactions are signed and accepted by the Solana network.

---

## 2. Transaction Serialization/Deserialization

**Goal:** Ensure transactions are serialized and deserialized exactly as the Solana/Anchor TS SDK expects.

### Steps:

- Review and test the `Transaction` class:
  - Ensure `compileMessage()` and `serialize()` produce correct Solana wire format.
  - Add tests that compare Dart-serialized transactions to those from the TS SDK for the same instructions.
- Support for Partial Signatures:
  - Implement logic to allow multiple signers (e.g., for multisig or CPI flows).
  - Ensure signatures can be added in any order and are correctly matched to required signers.

---

## 3. IDL and Program Client Parity

**Goal:** The Dart SDK should generate program clients from IDL and support all Anchor features.

### Steps:

- IDL Parsing:
  - Ensure the Dart IDL parser supports all fields present in Anchor-generated IDLs (instructions, accounts, types, events, errors, metadata, etc.).
  - Add support for custom types, enums, and nested structs.
- Program Client Generation:
  - The `Program` class should dynamically generate methods for all instructions in the IDL.
  - Support for `.accounts()`, `.signers()`, `.preInstructions()`, `.postInstructions()`, and `.rpc()` as in TS SDK.
- Account Fetching and Decoding:
  - Implement account fetchers that can decode any account type defined in the IDL.
  - Support for fetching multiple accounts, filters, and deserialization.
- Error Handling:
  - Parse Anchor error codes and messages from transaction logs and surface them in Dart exceptions.

---

## 4. Provider and Connection Features

**Goal:** Match the Provider/Connection abstraction of the TS SDK.

### Steps:

- Provider:
  - Support for custom commitment levels, preflight options, and timeouts.
  - Allow switching between different wallets and connections at runtime.
- Connection:
  - Support all relevant Solana RPC methods (getAccountInfo, getProgramAccounts, sendTransaction, etc.).
  - Add WebSocket support for subscriptions (logs, account changes, etc.).

---

## 5. Advanced Anchor Features

**Goal:** Support all advanced Anchor/TS SDK features.

### Steps:

- CPI (Cross-Program Invocation) Support:
  - Allow building and sending transactions that invoke other programs.
- Events:
  - Parse and emit Anchor events from transaction logs.
- Simulate Transactions:
  - Implement `.simulate()` to preview transaction effects and logs.
- Multisig and PDA Utilities:
  - Add helpers for finding and using PDAs, and for multisig flows.

---

## 6. Testing, Examples, and Documentation

**Goal:** Ensure reliability and ease of use.

### Steps:

- Comprehensive Tests:
  - Unit and integration tests for all features, including wallet adapters, program clients, and error handling.
- Examples:
  - Provide example apps for common flows: counter, token, multisig, etc.
- Documentation:
  - Write clear docs for all public APIs, wallet integration, and migration guides for TS users.

---

## 7. Mock/Stub Steps (To Be Implemented)

- Events: Dart SDK may not yet parse Anchor events from logs.
- Account Filters: Support for memcmp and dataSize filters in getProgramAccounts.
- Custom Serializers: For rare IDL types or custom account layouts.
- Browser Wallets: Adapter for web/Flutter web wallets (e.g., Phantom).
- CLI Tools: Dart equivalents for Anchor CLI commands (optional).

---

## Summary Table

| Feature                         | Status/Action Needed |
| ------------------------------- | -------------------- |
| Wallet interface                | ✅ **COMPLETED**     |
| MWA wallet implementation       | ✅ **COMPLETED**     |
| Transaction serialization       | ✅ **COMPLETED**     |
| IDL parsing                     | ✅ **COMPLETED**     |
| Program client generation       | ✅ **COMPLETED**     |
| Account fetching/decoding       | ✅ **COMPLETED**     |
| Error handling                  | ✅ **COMPLETED**     |
| Provider/connection abstraction | ✅ **COMPLETED**     |
| Events                          | ✅ **COMPLETED**     |
| Simulate transactions           | ✅ **COMPLETED**     |
| Multisig/PDA utilities          | ✅ **COMPLETED**     |
| Account filters                 | ✅ **COMPLETED**     |
| Browser wallet support          | **Implement**        |
| Tests/examples/docs             | Expand/complete      |

---

**COMPLETED:**

- Wallet interface: Dart `Wallet` interface matches TS SDK, with all required methods.
- MWA wallet implementation: `MobileWalletAdapterWallet` implemented and robust.
- AnchorProvider and Program usage: Provider supports wallet injection and all transaction flows use the injected wallet.
- Transaction serialization: `Transaction` class's `compileMessage` and `serialize` methods fixed for correct Solana wire format and partial/multisig signing.
- IDL parsing: Dart IDL parser supports all Anchor fields, custom types, enums, and nested structs.
- Program client generation: `Program` class dynamically generates methods for all instructions, supports `.accounts()`, `.signers()`, `.preInstructions()`, `.postInstructions()`, `.rpc()`.
- Account fetching/decoding: Account fetchers decode any account type, support multiple accounts, filters, and deserialization.
- Provider/connection abstraction: Custom commitment levels, preflight options, timeouts, and all relevant Solana RPC methods supported. WebSocket support for subscriptions implemented.
- Simulate transactions: `.simulate()` implemented for transaction preview/logs.
- Account filters: `getProgramAccounts` supports memcmp and dataSize filters.
- Events: Robust event parsing and emission from transaction logs, matching TS SDK, with full integration and tests.
- Error handling: Comprehensive error parsing from logs, including AnchorError, ProgramError, program stack, and IDL error mapping. All error handling tests pass.
- **Multisig and PDA utilities: Complete utilities for multisig workflows and PDA derivation, matching TypeScript SDK patterns. Includes enhanced seed conversion, address validation, multisig transaction management, and account builders.**
- Tests: Integration/unit tests for wallet adapters, provider, transaction serialization, partial signatures, events, error handling, and multisig/PDA utilities. All tests pass except for expected network errors (no local validator).

**PENDING:**

- Browser wallet support: Adapter for web/Flutter web wallets (next step).
- Tests/examples/docs: Expand/complete as needed.

**CODE STATE:**

- /lib/src/provider/wallet.dart (Wallet interface, KeypairWallet, fixes for partial signing)
- /lib/src/provider/mobile_wallet_adapter/mobile_wallet_adapter_wallet.dart (MWA wallet implementation)
- /lib/src/provider/anchor_provider.dart (Provider usage, wallet injection)
- /lib/src/types/transaction.dart (Transaction serialization, partial signing, error handling)
- /lib/src/idl/idl.dart (IDL parsing)
- /lib/src/program/program_class.dart, /lib/src/program/namespace/methods_namespace.dart, /lib/src/program/method_builder.dart (Program client generation)
- /lib/src/provider/connection.dart (Account fetching, filters, RPC)
- /lib/src/event/event_manager.dart, /lib/src/event/event_parser.dart (Event system)
- /lib/src/error.dart (Comprehensive error handling)
- /lib/src/utils/binary_writer.dart (ArgumentError for invalid values)
- **NEW: /lib/src/utils/pubkey.dart (PublicKey utilities matching TypeScript utils.publicKey)**
- **NEW: /lib/src/utils/multisig.dart (Multisig utilities for transaction management and PDA derivation)**
- **ENHANCED: /lib/src/program/pda_utils.dart (Enhanced PDA utilities with better seed conversion and validation)**
- /test/wallet_test.dart, /test/anchor_provider_test.dart, /test/mobile_wallet_adapter_wallet_test.dart, /test/transaction_serialization_test.dart, /test/program_events_test.dart, /test/error_handling_test.dart (Tests for all major features)
- **NEW: /test/pubkey_utils_test.dart, /test/multisig_utils_test.dart, /test/enhanced_pda_utils_test.dart, /test/multisig_pda_integration_test.dart (Comprehensive tests for multisig and PDA utilities)**
- /lib/coral_xyz_anchor.dart (Exports for error system, multisig utilities, and other modules)
- /ANCHOR_DART_ROADMAP.md (Roadmap status updated to mark multisig/PDA utilities as completed)
