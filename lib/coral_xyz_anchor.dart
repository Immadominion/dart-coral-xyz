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
export 'src/provider/provider.dart'
    show
        Wallet,
        KeypairWallet,
        ConfirmOptions,
        TransactionWithSigners,
        SimulationResult,
        ProviderException,
        ProviderTransactionException,
        AnchorProvider; // Provider system (Phase 4.1 - COMPLETED: Connection Management)
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
        LogsNotification,
        SendTransactionOptions,
        RpcTransactionConfirmation,
        memcmpFilter,
        dataSizeFilter,
        tokenAccountFilter;

// Enhanced connection management with retry and recovery
export 'src/provider/enhanced_connection.dart'
    show
        EnhancedConnection,
        RetryConfig,
        CircuitBreakerConfig,
        CircuitBreakerState,
        CircuitBreaker,
        RequestDeduplicator;

// Connection pooling for high-performance applications
export 'src/provider/connection_pool.dart'
    show
        ConnectionPool,
        ConnectionPoolConfig,
        LoadBalancingStrategy,
        PooledConnection,
        ConnectionPoolMetrics;
export 'src/program/program.dart';
export 'src/program/program_class.dart'; // Core Program class with TypeScript compatibility
export 'src/program/program_error_handler.dart'; // Unified error handling system
export 'src/program/method_builder.dart'; // Method Interface Generation (Phase 7.3 - Task 7.3)
export 'src/program/type_safe_method_builder.dart'; // Type-safe method builder for fluent API
export 'src/program/instruction_builder.dart'; // Instruction Building and Validation Framework (Step 2.6 - COMPLETED)
export 'src/program/accounts_resolver.dart'; // Accounts resolution system
export 'src/program/context.dart'
    hide ConfirmOptions; // Context and account management
export 'src/coder/coder.dart';
export 'src/coder/event_coder.dart'; // Event Coder (Phase 5.3 - COMPLETED)
export 'src/coder/types_coder.dart'; // Types Coder (Phase 5.3 - COMPLETED)
export 'src/coder/type_converter.dart'; // Unified type conversion system (Phase 5.5.3)
export 'src/coder/instruction_coder.dart';
export 'src/event/event.dart'
    hide LogsNotification; // Event System (Phase 9.1 - COMPLETED)
export 'src/event/event_definition.dart'; // Event Definition and Metadata Framework (Phase 4.1 - COMPLETED)
export 'src/event/event_log_parser.dart'
    hide
        ParsedEvent; // Event Log Parsing and Discriminator Handling (Phase 4.2 - COMPLETED)
export 'src/event/event_subscription_manager.dart'
    hide
        EventSubscription,
        EventFilter; // Event Subscription and Filtering System (Phase 4.3 - COMPLETED)
export 'src/event/event_processor.dart'; // Event Processing and Handler Framework (Phase 4.4 - COMPLETED)
export 'src/event/event_persistence.dart'; // Event Persistence and Restoration (Step 7.3 - COMPLETED)
export 'src/event/event_debugging.dart'; // Event Debugging and Monitoring (Step 7.3 - COMPLETED)
export 'src/event/event_aggregation.dart'; // Event Aggregation and Processing Pipelines (Step 7.3 - COMPLETED)
export 'src/event/types.dart'
    show
        EventContext,
        ParsedEvent,
        EventStats,
        EventFilter,
        EventSubscriptionConfig,
        EventReplayConfig; // Event types for public API
export 'src/idl/idl.dart'; // IDL system for program interface definitions (Phase 2.1 - COMPLETED)
export 'src/idl/idl_utils.dart'; // IDL utilities for fetching and processing on-chain IDLs
export 'src/account/account_definition.dart'; // Account Definition Metadata System (Phase 2.1 - COMPLETED)
// Enhanced types available via qualified import:
// import 'package:coral_xyz_anchor/src/idl/enhanced_types.dart' as enhanced;
export 'src/utils/utils.dart';

// PDA and multisig utilities (Phase 5.1 - COMPLETED: Core PDA Derivation Engine)
export 'src/utils/pubkey.dart';
export 'src/utils/multisig.dart';
export 'src/program/pda_utils.dart' show PdaUtils, AddressResolver;
export 'src/pda/pda_derivation_engine.dart' hide PdaUtils;
export 'src/pda/pda_cache.dart'; // PDA Caching and Performance Optimization (Phase 5.2 - COMPLETED)
export 'src/pda/pda_definition.dart'; // PDA Definition and Metadata System (Phase 5.3 - COMPLETED)

// Namespace exports (Phase 6.2 - COMPLETED: Namespace Generation System)
export 'src/program/namespace/namespace_factory.dart';
export 'src/program/namespace/account_namespace.dart'
    show AccountNamespace, AccountClient;
export 'src/program/namespace/account_fetcher.dart'
    show AccountFetcher, AccountFetcherConfig, ProgramAccount;
// Account Management and Subscription System (Step 7.2 - COMPLETED)
export 'src/program/namespace/account_subscription_manager.dart'
    show
        AccountSubscriptionManager,
        AccountSubscriptionConfig,
        AccountChangeNotification,
        AccountSubscriptionState,
        AccountSubscriptionStats;
export 'src/program/namespace/account_cache_manager.dart'
    show
        AccountCacheManager,
        AccountCacheConfig,
        CacheInvalidationStrategy,
        CacheEntry,
        CacheStatistics;
export 'src/program/namespace/account_operations.dart'
    show
        AccountOperationsManager,
        AccountRelationship,
        AccountRelationshipType,
        AccountCreationParams,
        AccountDebugInfo;
export 'src/instruction/instruction_definition.dart';
export 'src/program/namespace/instruction_namespace.dart'
    show InstructionNamespace;
export 'src/program/namespace/methods_namespace.dart' show MethodsNamespace;
export 'src/program/namespace/rpc_namespace.dart' show RpcNamespace;
export 'src/program/namespace/simulate_namespace.dart' show SimulateNamespace;
export 'src/program/namespace/transaction_namespace.dart'
    show TransactionNamespace;
export 'src/program/namespace/views_namespace.dart' show ViewsNamespace;
export 'src/program/namespace/types.dart'
    hide
        SimulationResult,
        TransactionInstruction,
        AccountMeta,
        Context,
        Accounts;

// Transaction simulation (Phase 3.1 - COMPLETED)
export 'src/transaction/transaction_simulator.dart'
    hide TransactionSimulationResult; // Avoid conflict with types.dart

// Pre-flight Account Validation (Phase 3.2 - COMPLETED)
export 'src/transaction/preflight_validator.dart';

// Compute Unit Analysis and Fee Estimation (Phase 3.3 - COMPLETED)
export 'src/transaction/compute_unit_analyzer.dart';

// Simulation Result Processing and Analysis (Phase 3.4 - COMPLETED)
export 'src/transaction/simulation_result_processor.dart';

// Enhanced Simulation Analysis and Optimization (Step 7.4 - COMPLETED)
export 'src/transaction/enhanced_simulation_analyzer.dart'
    hide
        OptimizationRecommendation,
        ComparisonResult,
        CacheStatistics,
        OptimizationType; // Avoid conflicts

// Simulation Caching and Replay System (Step 7.4 - COMPLETED)
export 'src/transaction/simulation_cache_manager.dart'
    hide CacheStatistics; // Avoid conflict with account_cache_manager.dart

// Simulation Debugging and Development Tools (Step 7.4 - COMPLETED)
export 'src/transaction/simulation_debugger.dart';

// Transaction Building and Serialization Infrastructure
export 'src/transaction/transaction.dart';

// Type definitions (Phase 1.3 - COMPLETED)
export 'src/types/types.dart'
    hide AccountMeta, TransactionInstruction, Transaction;

// PDA Derivation Engine (Phase 5.1 - COMPLETED)
// Note: PdaResult from pda_derivation_engine takes precedence over types/public_key.dart
export 'src/types/public_key.dart' hide PdaResult;

// External package wrappers for consistent API
export 'src/external/external.dart';

// Testing Infrastructure exports (Step 8.2 - COMPLETED)
export 'src/testing/test_infrastructure.dart';

// Performance Optimization and Monitoring (Step 8.3 - COMPLETED)
export 'src/performance/performance_optimization.dart'
    hide
        PerformanceMetrics,
        MonitoringMetrics,
        OptimizationRecommendation,
        OptimizationType; // Avoid conflicts with simulation modules

// IDE Integration and Developer Experience (Step 8.4 - COMPLETED)
export 'src/ide/ide.dart'
    hide
        DebugConfig,
        AccountChange,
        DebugSession; // Hide to avoid conflicts with simulation modules

// Re-export commonly used types for convenience
// export 'src/types/public_key.dart';
// export 'src/types/keypair.dart';
export 'src/types/transaction.dart'
    hide TransactionInstruction, AccountMeta, Transaction;

// Error types
export 'src/error/error.dart'; // Comprehensive error handling system
// export 'src/errors/anchor_error.dart';

// Constants and enums
// export 'src/constants/commitment.dart';

// Export TypeScript-like utilities and compatibility features
export 'src/utils/typescript_compatibility.dart';
export 'src/utils/anchor_utils.dart';
// Note: error_utils.dart is deprecated in favor of src/error.dart
export 'src/workspace/workspace.dart';
export 'src/workspace/cpi_framework.dart'; // Cross-Program Invocation Framework (Step 5.6 - COMPLETED)

// Export native program support (like TypeScript @coral-xyz/anchor native)
export 'src/native/system_program.dart';

// Export additional TypeScript-compatible features
export 'src/compat/bn_js_compat.dart';
// Removed legacy Web3.js compatibility layer; use Transaction.serialize directly
// export 'src/compat/web3_compat.dart' hide TransactionError, AccountError;
export 'src/provider/mobile_wallet_adapter/mobile_wallet_adapter_wallet.dart';

// Advanced Wallet Integration System (Phase 6.3 - COMPLETED)
export 'src/wallet/wallet_adapter.dart';
export 'src/wallet/mobile_wallet_adapter.dart';
export 'src/wallet/wallet_discovery.dart';

// Mobile and Web Platform Optimization (Step 8.5 - COMPLETED)
export 'src/platform/platform_optimization.dart';
export 'src/platform/flutter_widgets.dart';
export 'src/platform/web_optimization.dart' hide CacheEntry;
export 'src/platform/mobile_optimization.dart'
    hide TransactionStatus, MobileWalletSession;
export 'src/platform/platform_integration.dart';

// Legacy wallet support (keeping for backward compatibility)
export 'src/provider/wallet.dart'
    hide
        WalletException,
        WalletUserRejectedException,
        WalletNotConnectedException,
        WalletNotAvailableException,
        WalletAdapter,
        AdapterWallet,
        MockWalletAdapter;

/// Version of the coral_xyz_anchor package
const String packageVersion = '0.1.0';

/// Supported Anchor IDL specification version
const String supportedIdlVersion = '0.1.0';
