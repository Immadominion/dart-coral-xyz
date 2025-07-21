/// # Coral XYZ Anchor for Dart
///
/// A comprehensive Dart client for Anchor programs on Solana, providing complete
/// feature parity with the TypeScript `@coral-xyz/anchor` package. This library
/// enables type-safe, idiomatic Dart interactions with Anchor programs on the
/// Solana blockchain.
///
/// ## Features
///
/// - **🔒 Type-Safe**: Full type safety with Dart's null safety and strong typing
/// - **📋 IDL-Based**: Automatic type-safe interfaces from Anchor IDL files
/// - **🌐 Cross-Platform**: Mobile (Flutter), web, and desktop support
/// - **⚡ Modern Async**: Idiomatic Dart async/await patterns
/// - **🎯 TypeScript Parity**: Complete compatibility with `@coral-xyz/anchor`
/// - **📊 Event System**: Real-time event listening and parsing
/// - **🔧 Extensible**: Custom coders and advanced use cases
///
/// ## Quick Start
///
/// ```dart
/// import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
///
/// // Connect to Solana devnet
/// final connection = Connection('https://api.devnet.solana.com');
/// final provider = AnchorProvider(connection, wallet);
///
/// // Load and interact with your program
/// final program = Program(idl, programId, provider);
///
/// // Call program methods
/// final signature = await program.methods
///   .initialize()
///   .accounts({'counter': counterKeypair.publicKey})
///   .signers([counterKeypair])
///   .rpc();
///
/// // Fetch account data
/// final account = await program.account.counter.fetch(counterKeypair.publicKey);
/// print('Counter: ${account.count}');
/// ```
///
/// ## Core Classes
///
/// ### Program
/// The main interface for interacting with Anchor programs:
/// - `Program.methods` - Call program instructions
/// - `Program.account` - Fetch and manage account data
/// - `Program.instruction` - Build raw instructions
/// - `Program.transaction` - Construct transactions
/// - `Program.addEventListener` - Listen for program events
///
/// ### AnchorProvider
/// Manages connections and wallet interactions:
/// - Connection to Solana RPC endpoints
/// - Wallet integration for signing transactions
/// - Configurable commitment levels and options
///
/// ### IDL (Interface Definition Language)
/// Type definitions for your Anchor programs:
/// - Parse IDL JSON files
/// - Generate type-safe interfaces
/// - Validate program structure
///
/// ## Advanced Features
///
/// ### Event System
/// Listen to and parse program events in real-time:
///
/// ```dart
/// // Subscribe to specific events
/// program.addEventListener('Transfer', (event, slot, signature) {
///   print('Transfer: ${event.data.amount} tokens');
/// });
///
/// // Event filtering and aggregation
/// final stats = await program.getEventStatistics('Transfer');
/// ```
///
/// ### Custom Account Resolution
/// Dynamically resolve accounts and PDAs:
///
/// ```dart
/// await program.methods
///   .complexInstruction()
///   .accountsResolver((accounts) async {
///     final (pda, bump) = await PublicKey.findProgramAddress(
///       [utf8.encode('seed')], programId
///     );
///     return {...accounts, 'derivedAccount': pda};
///   })
///   .rpc();
/// ```
///
/// ### Transaction Building
/// Build and customize transactions:
///
/// ```dart
/// final tx = await program.methods
///   .myInstruction()
///   .accounts(accounts)
///   .transaction();
///
/// // Add additional instructions
/// tx.add(SystemProgram.transfer(/* ... */));
///
/// // Send with custom options
/// await provider.sendAndConfirm(tx, signers: [wallet]);
/// ```
///
/// ## Error Handling
///
/// The library provides comprehensive error handling:
///
/// ```dart
/// try {
///   await program.methods.initialize().rpc();
/// } on AnchorError catch (e) {
///   print('Anchor error: ${e.message}');
/// } on SolanaException catch (e) {
///   print('Solana error: ${e.message}');
/// } catch (e) {
///   print('Unexpected error: $e');
/// }
/// ```
///
/// ## Flutter Integration
///
/// Perfect for mobile dApps with Flutter:
///
/// ```dart
/// class CounterWidget extends StatefulWidget {
///   @override
///   _CounterWidgetState createState() => _CounterWidgetState();
/// }
///
/// class _CounterWidgetState extends State<CounterWidget> {
///   late Program program;
///   int count = 0;
///
///   @override
///   void initState() {
///     super.initState();
///     _initializeProgram();
///   }
///
///   Future<void> _increment() async {
///     await program.methods.increment().rpc();
///     _fetchCount();
///   }
///
///   // ... rest of implementation
/// }
/// ```
///
/// ## Migration from TypeScript
///
/// This library provides 1:1 compatibility with TypeScript patterns:
///
/// | TypeScript | Dart | Notes |
/// |------------|------|-------|
/// | `program.methods.initialize()` | `program.methods.initialize()` | Identical API |
/// | `program.account.counter.fetch()` | `program.account.counter.fetch()` | Type-safe |
/// | `addEventListener()` | `addEventListener()` | Same signature |
/// | `AnchorProvider` | `AnchorProvider` | Compatible options |
///
/// ## Performance
///
/// Optimized for production use:
/// - Memory-efficient object pooling
/// - Intelligent RPC batching and caching
/// - Minimal runtime overhead
/// - Compile-time type guarantees
///
/// ## See Also
///
/// - [Examples](https://github.com/coral-xyz/dart-coral-xyz/tree/main/example) - Working examples
/// - [Anchor Documentation](https://www.anchor-lang.com/) - Learn Anchor framework
/// - [Solana Documentation](https://docs.solana.com/) - Solana blockchain docs
library coral_xyz_anchor;

export 'src/account/account_definition.dart'; // Account Definition Metadata System (Phase 2.1 - COMPLETED)
// Core exports - these will be implemented in phases
export 'src/codegen/annotations.dart';
export 'src/coder/coder.dart';
export 'src/coder/event_coder.dart'; // Event Coder (Phase 5.3 - COMPLETED)
export 'src/coder/instruction_coder.dart';
export 'src/coder/type_converter.dart'; // Unified type conversion system (Phase 5.5.3)
export 'src/coder/types_coder.dart'; // Types Coder (Phase 5.3 - COMPLETED)
// Export additional TypeScript-compatible features
export 'src/compat/bn_js_compat.dart';
// Error types (comprehensive error handling system)
export 'src/error/error.dart';
export 'src/event/event.dart'
    hide LogsNotification; // Event System (Phase 9.1 - COMPLETED)
export 'src/event/event_aggregation.dart'; // Event Aggregation and Processing Pipelines (Step 7.3 - COMPLETED)
export 'src/event/event_debugging.dart'; // Event Debugging and Monitoring (Step 7.3 - COMPLETED)
export 'src/event/event_definition.dart'; // Event Definition and Metadata Framework (Phase 4.1 - COMPLETED)
export 'src/event/event_log_parser.dart'
    hide
        ParsedEvent; // Event Log Parsing and Discriminator Handling (Phase 4.2 - COMPLETED)
export 'src/event/event_persistence.dart'; // Event Persistence and Restoration (Step 7.3 - COMPLETED)
export 'src/event/event_processor.dart'; // Event Processing and Handler Framework (Phase 4.4 - COMPLETED)
export 'src/event/event_subscription_manager.dart'
    hide
        EventSubscription,
        EventFilter; // Event Subscription and Filtering System (Phase 4.3 - COMPLETED)
export 'src/event/types.dart'
    show
        EventContext,
        ParsedEvent,
        EventStats,
        EventFilter,
        EventSubscriptionConfig,
        EventReplayConfig; // Event types for public API
// External package wrappers for consistent API
export 'src/external/external.dart';
// IDE Integration and Developer Experience (Step 8.4 - COMPLETED)
export 'src/ide/ide.dart'
    hide
        DebugConfig,
        AccountChange,
        DebugSession; // Hide to avoid conflicts with simulation modules
export 'src/idl/idl.dart'; // IDL system for program interface definitions (Phase 2.1 - COMPLETED)
export 'src/idl/idl_utils.dart'; // IDL utilities for fetching and processing on-chain IDLs
export 'src/instruction/instruction_definition.dart';
// Export native program support (like TypeScript @coral-xyz/anchor native)
export 'src/native/system_program.dart';
export 'src/pda/pda_cache.dart'; // PDA Caching and Performance Optimization (Phase 5.2 - COMPLETED)
export 'src/pda/pda_definition.dart'; // PDA Definition and Metadata System (Phase 5.3 - COMPLETED)
export 'src/pda/pda_derivation_engine.dart' hide PdaUtils;
// Performance Optimization and Monitoring (Step 8.3 - COMPLETED)
export 'src/performance/performance_optimization.dart'
    hide
        PerformanceMetrics,
        MonitoringMetrics,
        OptimizationRecommendation,
        OptimizationType; // Avoid conflicts with simulation modules
export 'src/platform/flutter_widgets.dart';
export 'src/platform/mobile_optimization.dart'
    hide TransactionStatus, MobileWalletSession;
export 'src/platform/platform_integration.dart';
// Mobile and Web Platform Optimization (Step 8.5 - COMPLETED)
export 'src/platform/platform_optimization.dart';
export 'src/platform/web_optimization.dart' hide CacheEntry;
export 'src/program/accounts_resolver.dart'; // Accounts resolution system
export 'src/program/context.dart'
    hide ConfirmOptions, Context, Accounts; // Context and account management
export 'src/program/instruction_builder.dart'
    hide
        InstructionBuilder; // Instruction Building and Validation Framework (Step 2.6 - COMPLETED)
export 'src/program/method_builder.dart'; // Method Interface Generation (Phase 7.3 - Task 7.3)
export 'src/program/namespace/account_cache_manager.dart'
    show
        AccountCacheManager,
        AccountCacheConfig,
        CacheInvalidationStrategy,
        CacheEntry;
export 'src/program/namespace/account_fetcher.dart'
    show AccountFetcher, AccountFetcherConfig, ProgramAccount;
export 'src/program/namespace/account_namespace.dart'
    show AccountNamespace, AccountClient;
export 'src/program/namespace/account_operations.dart'
    show
        AccountOperationsManager,
        AccountRelationship,
        AccountRelationshipType,
        AccountCreationParams,
        AccountDebugInfo;
// Account Management and Subscription System (Step 7.2 - COMPLETED)
export 'src/program/namespace/account_subscription_manager.dart'
    show
        AccountSubscriptionManager,
        AccountSubscriptionConfig,
        AccountChangeNotification,
        AccountSubscriptionState,
        AccountSubscriptionStats;
export 'src/program/namespace/instruction_namespace.dart'
    show InstructionNamespace;
export 'src/program/namespace/methods_namespace.dart' show MethodsNamespace;
// Namespace exports (Phase 6.2 - COMPLETED: Namespace Generation System)
export 'src/program/namespace/namespace_factory.dart';
export 'src/program/namespace/rpc_namespace.dart' show RpcNamespace;
export 'src/program/namespace/simulate_namespace.dart' show SimulateNamespace;
export 'src/program/namespace/transaction_namespace.dart'
    show TransactionNamespace;
export 'src/program/namespace/types.dart'
    hide
        SimulationResult,
        TransactionInstruction,
        AccountMeta,
        Context,
        Accounts;
export 'src/program/namespace/views_namespace.dart' show ViewsNamespace;
export 'src/program/pda_utils.dart' show PdaUtils, AddressResolver;
export 'src/program/program.dart';
export 'src/program/program_class.dart'; // Core Program class with TypeScript compatibility
export 'src/program/program_error_handler.dart'; // Unified error handling system
export 'src/program/type_safe_method_builder.dart'; // Type-safe method builder for fluent API
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
// Connection pooling for high-performance applications
export 'src/provider/connection_pool.dart'
    show
        ConnectionPool,
        ConnectionPoolConfig,
        LoadBalancingStrategy,
        PooledConnection,
        ConnectionPoolMetrics;
// Enhanced connection management with retry and recovery
export 'src/provider/enhanced_connection.dart'
    show
        EnhancedConnection,
        RetryConfig,
        CircuitBreakerConfig,
        RequestDeduplicator;
// Removed legacy Web3.js compatibility layer; use Transaction.serialize directly
// export 'src/compat/web3_compat.dart' hide TransactionError, AccountError;
export 'src/provider/mobile_wallet_adapter/mobile_wallet_adapter_wallet.dart';
export 'src/provider/provider.dart'
    show
        Wallet,
        KeypairWallet,
        ConfirmOptions,
        TransactionWithSigners,
        ProviderException,
        ProviderTransactionException,
        AnchorProvider; // Provider system (Phase 4.1 - COMPLETED: Connection Management)
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
// Testing Infrastructure exports (Step 8.2 - COMPLETED)
export 'src/testing/test_infrastructure.dart';
// Compute Unit Analysis and Fee Estimation (Phase 3.3 - COMPLETED)
export 'src/transaction/compute_unit_analyzer.dart';
// Enhanced Simulation Analysis and Optimization (Step 7.4 - COMPLETED)
export 'src/transaction/enhanced_simulation_analyzer.dart'
    hide
        OptimizationRecommendation,
        ComparisonResult,
        CacheStatistics,
        OptimizationType; // Avoid conflicts
// Pre-flight Account Validation (Phase 3.2 - COMPLETED)
export 'src/transaction/preflight_validator.dart';
// Simulation Caching and Replay System (Step 7.4 - COMPLETED)
export 'src/transaction/simulation_cache_manager.dart'
    hide CacheStatistics; // Avoid conflict with account_cache_manager.dart
// Simulation Debugging and Development Tools (Step 7.4 - COMPLETED)
export 'src/transaction/simulation_debugger.dart';
// Simulation Result Processing and Analysis (Phase 3.4 - COMPLETED)
export 'src/transaction/simulation_result_processor.dart';
// Transaction Building and Serialization Infrastructure
export 'src/transaction/transaction.dart'
    hide AccountMeta, TransactionInstruction;
// Transaction simulation (Phase 3.1 - COMPLETED)
export 'src/transaction/transaction_simulator.dart'
    hide TransactionSimulationResult; // Avoid conflict with types.dart
// PDA Derivation Engine (Phase 5.1 - COMPLETED)
// Note: PdaResult from pda_derivation_engine takes precedence over types/public_key.dart
export 'src/types/public_key.dart' hide PdaResult;
// Re-export commonly used types for convenience
// export 'src/types/public_key.dart';
// export 'src/types/keypair.dart';
export 'src/types/transaction.dart'
    hide TransactionInstruction, AccountMeta, Transaction;
// Type definitions (Phase 1.3 - COMPLETED)
export 'src/types/types.dart'
    hide AccountMeta, TransactionInstruction, Transaction;
export 'src/utils/anchor_utils.dart';
export 'src/utils/binary_reader.dart';
export 'src/utils/binary_writer.dart';
export 'src/utils/multisig.dart';
// Core utilities
export 'src/utils/pubkey.dart';
// export 'src/errors/anchor_error.dart';

// Constants and enums
// export 'src/constants/commitment.dart';

// Export TypeScript-like utilities and compatibility features
export 'src/utils/typescript_compatibility.dart';
// Enhanced types available via qualified import:
// import 'package:coral_xyz_anchor/src/idl/enhanced_types.dart' as enhanced;
export 'src/utils/utils.dart';
export 'src/wallet/mobile_wallet_adapter.dart';
// Advanced Wallet Integration System (Phase 6.3 - COMPLETED)
export 'src/wallet/wallet_adapter.dart';
export 'src/wallet/wallet_discovery.dart';
export 'src/workspace/cpi_framework.dart'; // Cross-Program Invocation Framework (Step 5.6 - COMPLETED)
// Note: error_utils.dart is deprecated in favor of src/error.dart
export 'src/workspace/workspace.dart';

/// Version of the coral_xyz_anchor package
const String packageVersion = '0.1.0';

/// Supported Anchor IDL specification version
const String supportedIdlVersion = '0.1.0';
