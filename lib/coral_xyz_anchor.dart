/// Coral XYZ Anchor - A comprehensive Dart client for Anchor programs on Solana
///
/// This library provides a type-safe, idiomatic Dart interface for interacting
/// with Anchor programs on the Solana blockchain. It mirrors the functionality
/// of the TypeScript @coral-xyz/anchor package while leveraging Dart's strengths
/// like null safety, strong typing, and excellent async/await support.
///
/// ## Features
///
/// - Type-safe program interactions based on IDL definitions
/// - Comprehensive Borsh serialization/deserialization support
/// - Flexible provider system for wallet and connection management
/// - Dynamic namespace generation for intuitive program APIs
/// - Built-in event listening and parsing capabilities
/// - Cross-platform support (mobile, web, desktop via Flutter)
/// - Extensive utility functions for addresses, transactions, and accounts
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
///
/// // Create a connection to the Solana cluster
/// final connection = Connection('https://api.devnet.solana.com');
///
/// // Set up a provider with your wallet
/// final provider = AnchorProvider(connection, wallet);
///
/// // Load your program using its IDL
/// final program = Program(idl, programId, provider);
///
/// // Call program methods
/// final result = await program.methods
///   .myInstruction(arg1, arg2)
///   .accounts({
///     'account1': publicKey1,
///     'account2': publicKey2,
///   })
///   .rpc();
/// ```
///
/// ## Advanced Usage
///
/// ```dart
/// // Listen to program events
/// program.addEventListener('MyEvent', (event, slot) {
///   print('Event received: ${event.data}');
/// });
///
/// // Fetch account data
/// final accountData = await program.account.myAccount.fetch(accountPublicKey);
///
/// // Build and send transactions manually
/// final tx = await program.methods
///   .myInstruction(args)
///   .accounts(accounts)
///   .transaction();
///
/// final signature = await provider.sendAndConfirm(tx);
/// ```
library coral_xyz_anchor;

// Core exports - these will be implemented in phases
export 'src/provider/provider.dart'; // Provider system (Phase 4.1 - COMPLETED: Connection Management)
export 'src/provider/connection.dart'
    show
        Connection,
        AccountInfo,
        LatestBlockhash,
        AccountFilter,
        MemcmpFilter,
        DataSizeFilter,
        TokenAccountFilter,
        ProgramAccountInfo,
        SendTransactionOptions,
        RpcTransactionConfirmation,
        memcmpFilter,
        dataSizeFilter,
        tokenAccountFilter; // Account fetching filters
export 'src/program/program.dart';
export 'src/program/method_builder.dart'; // Method Interface Generation (Phase 7.3 - Task 7.3)
export 'src/coder/coder.dart';
export 'src/coder/account_coder.dart'; // Account Coder (Phase 5.2 - COMPLETED)
export 'src/coder/event_coder.dart'; // Event Coder (Phase 5.3 - COMPLETED)
export 'src/coder/types_coder.dart'; // Types Coder (Phase 5.3 - COMPLETED)
export 'src/event/event.dart'; // Event System (Phase 9.1 - COMPLETED)
export 'src/idl/idl.dart'; // IDL system for program interface definitions (Phase 2.1 - COMPLETED)
// Enhanced types available via qualified import:
// import 'package:coral_xyz_anchor/src/idl/enhanced_types.dart' as enhanced;
export 'src/utils/utils.dart';

// PDA and multisig utilities (Phase 5.4 - COMPLETED: Multisig and PDA Utilities)
export 'src/utils/pubkey.dart';
export 'src/utils/multisig.dart';
export 'src/program/pda_utils.dart' show PdaUtils, AddressResolver;

// Namespace exports (Phase 6.2 - COMPLETED: Namespace Generation System)
export 'src/program/namespace/namespace_factory.dart';
export 'src/program/namespace/account_namespace.dart'
    show AccountNamespace, AccountClient, ProgramAccount;
export 'src/program/namespace/instruction_namespace.dart';
export 'src/program/namespace/methods_namespace.dart';
export 'src/program/namespace/rpc_namespace.dart';
export 'src/program/namespace/simulate_namespace.dart';
export 'src/program/namespace/transaction_namespace.dart';
export 'src/program/namespace/types.dart'
    hide SimulationResult, TransactionInstruction, AccountMeta;

// Type definitions (Phase 1.3 - COMPLETED)
export 'src/types/types.dart';

// External package wrappers for consistent API
export 'src/external/external.dart';

// Re-export commonly used types for convenience
// export 'src/types/public_key.dart';
// export 'src/types/keypair.dart';
// export 'src/types/transaction.dart';

// Error types
export 'src/error.dart'; // Comprehensive error handling system
// export 'src/errors/anchor_error.dart';

// Constants and enums
// export 'src/constants/commitment.dart';

// Export TypeScript-like utilities and compatibility features
export 'src/utils/typescript_compatibility.dart';
export 'src/utils/anchor_utils.dart';
// Note: error_utils.dart is deprecated in favor of src/error.dart
export 'src/workspace/workspace.dart';

// Export native program support (like TypeScript @coral-xyz/anchor native)
export 'src/native/system_program.dart';

// Export additional TypeScript-compatible features
export 'src/compat/bn_js_compat.dart';
export 'src/compat/web3_compat.dart' hide TransactionError;
export 'src/provider/mobile_wallet_adapter/mobile_wallet_adapter_wallet.dart';

/// Version of the coral_xyz_anchor package
const String packageVersion = '0.1.0';

/// Supported Anchor IDL specification version
const String supportedIdlVersion = '0.1.0';
