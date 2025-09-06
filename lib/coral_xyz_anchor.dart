/// # Coral XYZ Anchor for Dart
///
/// A comprehensive Dart client for Anchor programs on Solana, providing complete
/// feature parity with the TypeScript `@coral-xyz/anchor` package. This library
/// enables type-s// IDE Support// Performance optimizations - removed for production cleanup- removed for production cleanupfe, idiomatic Dart interactions with Anchor programs on the
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
/// import 'package:coral_xyz/coral_xyz_anchor.dart';
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
library coral_xyz;

export 'src/account/account_definition.dart'; // Account Definition Metadata System (Phase 2.1 - COMPLETED)
// Core exports - these will be implemented in phases
export 'src/codegen/annotations.dart';
export 'src/coder/coder.dart';
export 'src/coder/event_coder.dart'; // Event Coder (Phase 5.3 - COMPLETED)
export 'src/coder/instruction_coder.dart';
export 'src/coder/type_converter.dart'; // Unified type conversion system (Phase 5.5.3)
export 'src/coder/types_coder.dart'; // Types Coder (Phase 5.3 - COMPLETED)
// Export additional TypeScript-compatible features
// Compat - removed for production cleanup
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

export 'src/idl/idl.dart'; // IDL system for program interface definitions (Phase 2.1 - COMPLETED)
export 'src/idl/idl_utils.dart'; // IDL utilities for fetching and processing on-chain IDLs
export 'src/instruction/instruction_definition.dart';
// Export native program support (like TypeScript @coral-xyz/anchor native)
export 'src/native/system_program.dart';
export 'src/pda/pda_cache.dart'; // PDA Caching and Performance Optimization (Phase 5.2 - COMPLETED)
export 'src/pda/pda_definition.dart'; // PDA Definition and Metadata System (Phase 5.3 - COMPLETED)
export 'src/pda/pda_derivation_engine.dart' hide PdaUtils, PdaResult;
// Performance optimization - removed for production cleanup
// Platform widgets - simplified for production
export 'src/program/accounts_resolver.dart'; // Accounts resolution system
export 'src/program/common.dart'
    show
        ProgramCommon,
        NodeWallet; // Program common utilities - TypeScript parity
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
export 'src/provider/connection.dart' show Connection;
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
        AdapterWallet;
// SPL (Solana Program Library) Integration (Phase 2 - COMPLETED)
export 'src/spl/spl.dart'; // SPL Token and other Solana Program Library integrations
// Transaction simulation (Phase 3.1 - COMPLETED)
// Note: Advanced analysis modules (compute_unit_analyzer, enhanced_simulation_analyzer,
// preflight_validator, simulation_cache_manager, simulation_debugger, simulation_result_processor)
// are not exported as they are not part of TypeScript SDK parity and should use espresso-cash
// directly for transaction analysis capabilities.
export 'src/transaction/transaction_simulator.dart'
    hide TransactionSimulationResult; // Avoid conflict with types.dart
// PDA Derivation Engine (Phase 5.1 - COMPLETED)
// PublicKey now uses production-ready espresso-cash implementation
export 'src/types/public_key.dart';
// Re-export commonly used types for convenience
// export 'src/types/public_key.dart';
// export 'src/types/keypair.dart';
export 'src/types/transaction.dart'
    hide TransactionInstruction, AccountMeta, Transaction;
// VersionedTransaction support for TypeScript SDK parity
export 'src/types/versioned_transaction.dart';
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
// import 'package:coral_xyz/src/idl/enhanced_types.dart' as enhanced;
export 'src/utils/utils.dart';
export 'src/wallet/mobile_wallet_adapter.dart';
// Advanced Wallet Integration System (Phase 6.3 - COMPLETED)
export 'src/wallet/wallet_adapter.dart';
export 'src/wallet/wallet_discovery.dart';
export 'src/workspace/cpi_framework.dart'; // Cross-Program Invocation Framework (Step 5.6 - COMPLETED)
// Note: error_utils.dart is deprecated in favor of src/error.dart
export 'src/workspace/workspace.dart';

// Import necessary classes for workspace functionality
import 'src/provider/anchor_provider.dart';
import 'src/workspace/workspace.dart';

/// Global workspace instance providing TypeScript-like lazy loading
///
/// This global workspace provides the same convenient access pattern as
/// the TypeScript SDK, allowing programs to be accessed like:
/// ```dart
/// workspace.myProgram  // Returns Program instance
/// workspace.MyProgram  // Same program, case-insensitive
/// workspace["my-program"]  // Also works with string accessor
/// ```
///
/// The workspace automatically loads programs from Anchor.toml configuration
/// and implements lazy loading - programs are only loaded when first accessed.
///
/// **Usage with default provider:**
/// ```dart
/// import 'package:coral_xyz/coral_xyz_anchor.dart';
///
/// // Access programs directly (will use AnchorProvider.env())
/// final program = workspace.counterProgram;
/// await program.methods.increment().rpc();
/// ```
///
/// **Usage with custom provider:**
/// ```dart
/// import 'package:coral_xyz/coral_xyz_anchor.dart';
///
/// // Set custom provider first
/// setProvider(myCustomProvider);
///
/// // Now workspace uses your provider
/// final program = workspace.myProgram;
/// ```
///
/// **Workspace lazy loading behavior:**
/// - Programs are loaded on first access (matching TypeScript behavior)
/// - IDL files are automatically discovered from `target/idl/` directory
/// - Anchor.toml configuration is respected for program addresses
/// - Case-insensitive program access (camelCase, PascalCase, snake_case, kebab-case)
/// - Error thrown if program IDL or configuration is not found
WorkspaceProxy get workspace => WorkspaceProxy._instance;

/// Get current provider instance (TypeScript-compatible API)
AnchorProvider getProvider() {
  return AnchorProvider.defaultProvider();
}

/// Set the global provider instance (TypeScript-compatible API)
void setProvider(AnchorProvider provider) {
  AnchorProvider.setDefaultProvider(provider);
  // Reset workspace to use new provider
  workspace.reset();
}

/// Proxy class that provides TypeScript-like workspace access with lazy loading
class WorkspaceProxy {
  static final WorkspaceProxy _instance = WorkspaceProxy._();
  WorkspaceProxy._();

  /// Get current provider, defaulting to AnchorProvider.env() if not set
  AnchorProvider get _currentProvider {
    try {
      return getProvider();
    } catch (_) {
      // If no provider is set, use default provider
      return AnchorProvider.defaultProvider();
    }
  }

  /// Lazy-loaded workspace instance
  Workspace? _workspace;

  /// Get or create workspace instance
  Workspace get _workspaceInstance {
    return _workspace ??= Workspace(_currentProvider);
  }

  /// Reset workspace (useful for provider changes)
  void reset() {
    _workspace = null;
  }

  /// Dynamic program access using noSuchMethod proxy pattern
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final memberName = invocation.memberName;
      final programName = _symbolToProgramName(memberName);

      // Use the workspace's lazy loading functionality
      return _workspaceInstance.lazyLoadProgram(programName);
    }

    return super.noSuchMethod(invocation);
  }

  String _symbolToProgramName(Symbol symbol) {
    final s = symbol.toString();
    // Symbol("ProgramName") => ProgramName
    final match = RegExp('"(.*)"').firstMatch(s);
    return match != null ? match.group(1)! : s;
  }
}

/// Version of the coral_xyz package
const String packageVersion = '1.0.0-beta.1';

/// Supported Anchor IDL specification version
const String supportedIdlVersion = '0.1.0';
