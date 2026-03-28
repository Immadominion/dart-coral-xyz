import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/idl/idl_utils.dart';
import 'package:coral_xyz/src/provider/provider.dart';
import 'package:coral_xyz/src/coder/coder.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/types/commitment.dart';
import 'package:coral_xyz/src/event/event_manager.dart' as event_manager;
import 'package:coral_xyz/src/event/types.dart' as event_types;
import 'package:coral_xyz/src/program/namespace/namespace_factory.dart';
import 'package:coral_xyz/src/program/namespace/account_namespace.dart';
import 'package:coral_xyz/src/program/namespace/instruction_namespace.dart';
import 'package:coral_xyz/src/program/namespace/methods_namespace.dart';
import 'package:coral_xyz/src/program/namespace/rpc_namespace.dart';
import 'package:coral_xyz/src/program/namespace/simulate_namespace.dart';
import 'package:coral_xyz/src/program/namespace/transaction_namespace.dart';
import 'package:coral_xyz/src/program/namespace/views_namespace.dart';

/// # Core Program Class for Anchor Program Interactions
///
/// The `Program` class is the primary interface for interacting with Anchor programs
/// on Solana. It provides a type-safe, idiomatic Dart API that mirrors the TypeScript
/// `@coral-xyz/anchor` Program class functionality.
///
/// ## Key Features
///
/// - **Type-Safe Method Calls**: Automatically generated method builders based on IDL
/// - **Account Management**: Fetch, create, and manage program accounts
/// - **Event Subscription**: Real-time event listening and parsing
/// - **Transaction Building**: Flexible transaction construction and submission
/// - **Simulation Support**: Test transactions before sending
/// - **Error Handling**: Comprehensive error types with detailed context
///
/// ## Basic Usage
///
/// ```dart
/// // Connect to Solana devnet
/// final connection = Connection('https://api.devnet.solana.com');
/// final provider = AnchorProvider(connection, wallet);
///
/// // Create program instance
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
/// ```
///
/// ## Advanced Usage
///
/// ### Custom Account Resolution
/// ```dart
/// await program.methods
///   .complexInstruction()
///   .accountsResolver((accounts) async {
///     final (pda, bump) = await PublicKey.findProgramAddress(
///       [utf8.encode('seed'), userKey.toBytes()], programId
///     );
///     return {...accounts, 'derivedAccount': pda};
///   })
///   .rpc();
/// ```
///
/// ### Event Subscription
/// ```dart
/// // Listen to specific events
/// program.addEventListener('Transfer', (event, slot, signature) {
///   print('Transfer: ${event.data.amount} tokens');
/// });
///
/// // Event filtering
/// program.addEventListener('Trade', (event, slot, signature) {
///   final trade = event.data as TradeEvent;
///   if (trade.amount > BigInt.from(1000000)) {
///     print('Large trade detected: ${trade.amount}');
///   }
/// });
/// ```
///
/// ### Transaction Simulation
/// ```dart
/// // Simulate before sending
/// final simulation = await program.methods
///   .risky_operation()
///   .accounts({'account': accountKey})
///   .simulate();
///
/// if (simulation.err != null) {
///   print('Transaction would fail: ${simulation.err}');
///   return;
/// }
///
/// // Transaction looks good, send it
/// await program.methods
///   .risky_operation()
///   .accounts({'account': accountKey})
///   .rpc();
/// ```
///
/// ### Manual Transaction Building
/// ```dart
/// // Build transaction without sending
/// final transaction = await program.methods
///   .myInstruction(args)
///   .accounts({'account': accountKey})
///   .transaction();
///
/// // Add additional instructions
/// transaction.add(SystemProgram.transfer(
///   fromPubkey: wallet.publicKey,
///   toPubkey: recipient,
///   lamports: amount,
/// ));
///
/// // Send manually with custom options
/// final signature = await provider.sendAndConfirm(
///   transaction,
///   signers: [wallet],
///   options: ConfirmOptions(commitment: Commitment.finalized),
/// );
/// ```
///
/// ## Error Handling
///
/// ```dart
/// try {
///   await program.methods.initialize().rpc();
/// } on AnchorError catch (e) {
///   // Handle program-specific errors
///   print('Anchor error ${e.code}: ${e.message}');
/// } on SolanaException catch (e) {
///   // Handle network/RPC errors
///   print('Solana error: ${e.message}');
/// } catch (e) {
///   // Handle unexpected errors
///   print('Unexpected error: $e');
/// }
/// ```
///
/// ## TypeScript Compatibility
///
/// This class provides 1:1 compatibility with the TypeScript Anchor Program class:
///
/// | TypeScript | Dart | Notes |
/// |------------|------|-------|
/// | `program.methods.initialize()` | `program.methods.initialize()` | Identical |
/// | `program.account.counter.fetch()` | `program.account.counter.fetch()` | Type-safe |
/// | `program.addEventListener()` | `program.addEventListener()` | Same API |
/// | `program.instruction.init()` | `program.instruction.init()` | Raw instructions |
/// | `program.transaction.init()` | `program.transaction.init()` | Transaction builders |
///
/// See the [migration guide](https://github.com/Immadominion/dart-coral-xyz/blob/main/MIGRATION.md)
/// for detailed TypeScript to Dart conversion patterns.
class Program<T extends Idl> {
  /// Creates a new Program instance
  ///
  /// This is the primary constructor for creating a Program instance from an IDL.
  ///
  /// [idl] The IDL definition for the program. This defines the program's
  ///       interface including instructions, accounts, events, and types.
  /// [provider] The network and wallet provider. If not provided, uses the
  ///           default provider which connects to localhost:8899. You typically
  ///           want to provide your own for non-local development.
  /// [coder] Custom coder for serialization. If not provided, creates a default
  ///         BorshCoder instance suitable for most Anchor programs.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Basic usage with default provider (localhost)
  /// final program = Program(idl);
  ///
  /// // With custom provider
  /// final connection = Connection('https://api.devnet.solana.com');
  /// final provider = AnchorProvider(connection, wallet);
  /// final program = Program(idl, provider: provider);
  ///
  /// // With custom coder (advanced)
  /// final customCoder = MyCustomCoder(idl);
  /// final program = Program(idl, provider: provider, coder: customCoder);
  /// ```
  Program(this._idl, {AnchorProvider? provider, Coder? coder})
    : _rawIdl = _idl as Idl,
      _provider = provider ?? AnchorProvider.defaultProvider(),
      _programId = PublicKey.fromBase58(
        _idl.address ??
            (throw ArgumentError(
              'IDL must contain an address field when using the default constructor. Use Program.withProgramId() to pass the program ID separately.',
            )),
      ),
      _coder = coder ?? AutoCoder(_idl) {
    // Generate namespaces after all fields are initialized
    _namespaces = NamespaceFactory.build(
      idl: _rawIdl,
      coder: _coder,
      programId: _programId,
      provider: _provider,
    );

    // Initialize event manager (TypeScript-compatible)
    _eventManager = event_manager.EventManager(_programId, _provider, _coder);
  }

  /// Create a Program instance with a separate program ID
  ///
  /// This constructor matches the TypeScript API pattern:
  /// ```typescript
  /// new Program(idl, programId, provider)
  /// ```
  ///
  /// Usage:
  /// ```dart
  /// final programId = PublicKey.fromBase58('...');
  /// final program = Program.withProgramId(idl, programId, provider: provider);
  /// ```
  Program.withProgramId(
    this._idl,
    PublicKey programId, {
    AnchorProvider? provider,
    Coder? coder,
  }) : _rawIdl = _idl as Idl,
       _provider = provider ?? AnchorProvider.defaultProvider(),
       _programId = programId,
       _coder = coder ?? AutoCoder(_idl) {
    // Generate namespaces after all fields are initialized
    _namespaces = NamespaceFactory.build(
      idl: _rawIdl,
      coder: _coder,
      programId: _programId,
      provider: _provider,
    );

    // Initialize event manager (TypeScript-compatible)
    _eventManager = event_manager.EventManager(_programId, _provider, _coder);
  }

  /// The IDL definition for this program
  final T _idl;

  /// The raw IDL (before any transformations)
  final Idl _rawIdl;

  /// Auto-detect the IDL format and create a Program with the correct coders.
  ///
  /// This is the recommended entry-point for multi-framework support:
  /// ```dart
  /// final program = Program.auto(idl, provider: provider);
  /// ```
  ///
  /// Equivalent to the default constructor (which already auto-detects).
  static Program<Idl> auto(Idl idl, {AnchorProvider? provider}) {
    if (idl.address != null) {
      return Program(idl, provider: provider);
    }
    throw ArgumentError(
      'IDL must contain an address field. '
      'Use Program.withProgramId() to provide the program ID separately.',
    );
  }

  /// The program's public key address
  final PublicKey _programId;

  /// The provider for network and wallet operations
  final AnchorProvider _provider;

  /// The coder for serialization/deserialization
  final Coder _coder;

  /// Generated namespaces for program interaction
  late final NamespaceSet _namespaces;

  /// Event manager for handling program event subscriptions (TypeScript-compatible)
  late final event_manager.EventManager _eventManager;

  /// The IDL definition for this program
  T get idl => _idl;

  /// The raw IDL (before any transformations)
  Idl get rawIdl => _rawIdl;

  /// The program's public key address
  PublicKey get programId => _programId;

  /// The provider for network and wallet operations
  AnchorProvider get provider => _provider;

  /// The coder for serialization/deserialization
  Coder get coder => _coder;

  /// The connection for network operations (unified resource sharing)
  ///
  /// This provides direct access to the underlying Solana connection
  /// that is shared across all namespaces and the event manager.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Access the connection directly
  /// final latestBlockhash = await program.connection.getLatestBlockhash();
  ///
  /// // Check network status
  /// final health = await program.connection.getHealth();
  /// ```
  Connection get connection => _provider.connection;

  /// The event manager for program event subscriptions (unified resource sharing)
  ///
  /// This provides direct access to the TypeScript-compatible EventManager
  /// that shares the same connection and provider resources as all other
  /// program operations.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Access event manager directly for advanced operations
  /// final stats = program.events.stats;
  /// final state = program.events.state;
  ///
  /// // Access the same functionality as the convenience methods
  /// final listenerId = program.events.addEventListener('MyEvent', callback);
  /// await program.events.removeEventListener(listenerId);
  /// ```
  event_manager.EventManager get events => _eventManager;

  /// The RPC namespace for sending signed transactions
  ///
  /// This namespace provides methods that directly send transactions to the network.
  /// Each method corresponds to an instruction defined in the IDL.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Send a transaction with automatic account resolution
  /// final signature = await program.rpc.initialize(
  ///   args: [initValue],
  ///   accounts: {
  ///     'user': wallet.publicKey,
  ///     'systemProgram': SystemProgram.programId,
  ///   },
  /// );
  /// ```
  RpcNamespace get rpc => _namespaces.rpc;

  /// The instruction namespace for building transaction instructions
  ///
  /// This namespace provides methods that return TransactionInstruction objects
  /// without sending them. Useful for building complex transactions or batching.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Build an instruction
  /// final instruction = await program.instruction.initialize(
  ///   args: [initValue],
  ///   accounts: {
  ///     'user': wallet.publicKey,
  ///     'systemProgram': SystemProgram.programId,
  ///   },
  /// );
  ///
  /// // Add to a transaction
  /// final transaction = Transaction()..add(instruction);
  /// ```
  InstructionNamespace get instruction => _namespaces.instruction;

  /// The transaction namespace for building full transactions
  ///
  /// This namespace provides methods that return complete Transaction objects
  /// with all necessary instructions and metadata.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Build a complete transaction
  /// final transaction = await program.transaction.initialize(
  ///   args: [initValue],
  ///   accounts: {
  ///     'user': wallet.publicKey,
  ///     'systemProgram': SystemProgram.programId,
  ///   },
  /// );
  ///
  /// // Sign and send manually
  /// await transaction.sign([wallet]);
  /// final signature = await connection.sendTransaction(transaction);
  /// ```
  TransactionNamespace get transaction => _namespaces.transaction;

  /// The account namespace for account operations
  ///
  /// This namespace provides methods for fetching, creating, and managing
  /// program accounts based on the account types defined in the IDL.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Fetch a single account
  /// final accountData = await program.account.myAccount.fetch(accountKey);
  ///
  /// // Fetch multiple accounts
  /// final accounts = await program.account.myAccount.all();
  ///
  /// // Fetch with filtering
  /// final filtered = await program.account.myAccount.all([
  ///   MemcmpFilter(offset: 8, bytes: someValue),
  /// ]);
  /// ```
  AccountNamespace get account => _namespaces.account;

  /// The methods namespace for building and executing program calls
  ///
  /// This namespace provides methods that correspond to the instructions
  /// defined in the IDL. Each method returns a builder object that can
  /// be used to set accounts, arguments, and other options before
  /// sending the transaction.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Call a method with automatic account resolution
  /// final result = await program.methods.initialize(
  ///   args: [initValue],
  ///   accounts: {
  ///     'user': wallet.publicKey,
  ///     'systemProgram': SystemProgram.programId,
  ///   },
  /// ).rpc();
  ///
  /// // Call a method with manual account specification
  /// final result = await program.methods.updateData(
  ///   args: [newValue],
  ///   accounts: {
  ///     'dataAccount': dataAccountKey,
  ///   },
  /// ).rpc();
  /// ```
  MethodsNamespace get methods => _namespaces.methods;

  /// The views namespace for read-only function calls
  ///
  /// This namespace provides methods for calling read-only functions that
  /// return data without modifying blockchain state. Views use simulation
  /// to execute and extract return data from program logs.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Call a view function to get current price
  /// final price = await program.views.getPrice([marketAddress]);
  ///
  /// // Call a view function to get account info
  /// final info = await program.views.getAccountInfo([accountKey]);
  /// ```
  ///
  /// ## Requirements
  ///
  /// For an instruction to be available as a view function:
  /// - Must have a return type defined in the IDL
  /// - Must not have any writable accounts
  /// - Must be suitable for simulation without state changes
  ViewsNamespace get views => _namespaces.views;

  /// The simulate namespace for transaction simulation
  ///
  /// This namespace provides methods for simulating program transactions
  /// without sending them to the blockchain. This is useful for testing
  /// and debugging transactions before execution.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Simulate a transaction
  /// final result = await program.simulate.initialize([value], context);
  /// ```
  ///
  /// ## Note
  ///
  /// This namespace is available for all instructions defined in the IDL.
  SimulateNamespace get simulate => _namespaces.simulate;

  /// Creates a Program instance by fetching the IDL from the network
  ///
  /// This method fetches the IDL from the on-chain IDL account and creates
  /// a Program instance. The IDL must have been previously initialized
  /// via anchor CLI's `anchor idl init` command.
  ///
  /// [address] The on-chain address of the program as a base58 string
  /// [provider] The network and wallet provider. If not provided, uses
  ///           the default provider.
  ///
  /// Returns a Program instance or null if the IDL cannot be fetched.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Fetch IDL from devnet
  /// final connection = Connection('https://api.devnet.solana.com');
  /// final provider = AnchorProvider(connection, wallet);
  ///
  /// final program = await Program.at(
  ///   'Your_Program_ID_Here',
  ///   provider: provider,
  /// );
  ///
  /// if (program != null) {
  ///   // Use the program
  ///   final result = await program.methods.someMethod().rpc();
  /// } else {
  ///   print('Could not fetch IDL for program');
  /// }
  /// ```
  ///
  /// ## Note
  ///
  /// This method requires the program to have its IDL deployed on-chain.
  /// For local development or if the IDL is not deployed, use the regular
  /// constructor with a local IDL file instead.
  static Future<Program<Idl>?> at(
    String address, {
    AnchorProvider? provider,
  }) async {
    final programId = PublicKey.fromBase58(address);
    provider ??= AnchorProvider.defaultProvider();

    final idl = await IdlUtils.fetchIdl(programId, provider);
    if (idl == null) {
      return null;
    }

    // Convert IDL to camelCase for better Dart ergonomics
    final camelCaseIdl = IdlUtils.convertIdlToCamelCase(idl);

    return Program<Idl>(camelCaseIdl, provider: provider);
  }

  /// Fetches an IDL from the blockchain
  ///
  /// This method fetches the IDL from the on-chain IDL account.
  /// The IDL must have been previously initialized via anchor CLI's `anchor idl init` command.
  ///
  /// [programId] The on-chain address of the program
  /// [provider] The network and wallet provider (optional)
  ///
  /// Returns the IDL or null if not found
  static Future<Idl?> fetchIdl(
    PublicKey programId, {
    AnchorProvider? provider,
  }) async {
    provider ??= AnchorProvider.defaultProvider();

    return IdlUtils.fetchIdl(programId, provider);
  }

  /// Calculate the IDL address for a given program ID
  ///
  /// This derives the deterministic address where the IDL is stored on-chain
  static Future<PublicKey> getIdlAddress(PublicKey programId) async =>
      IdlUtils.getIdlAddress(programId);

  /// Get the size of an account for the given account name
  ///
  /// [accountName] The name of the account type as defined in the IDL
  ///
  /// Returns the size in bytes required for the account
  int getAccountSize(String accountName) => _coder.accounts.size(accountName);

  /// Validate that this program matches the given program ID
  ///
  /// [expectedProgramId] The expected program ID to validate against
  ///
  /// Throws an [ArgumentError] if the program IDs don't match
  void validateProgramId(PublicKey expectedProgramId) {
    if (_programId != expectedProgramId) {
      throw ArgumentError(
        'Program ID mismatch: expected ${expectedProgramId.toBase58()}, '
        'got ${_programId.toBase58()}',
      );
    }
  }

  /// Invokes the given callback every time the given event is emitted (TypeScript-compatible)
  ///
  /// This method registers an event listener for a specific event type defined in the IDL.
  /// The callback will be invoked whenever the event is emitted from program logs.
  ///
  /// **API Change**: This method now returns a numeric listener ID (like TypeScript)
  /// instead of an EventSubscription to match TypeScript Anchor's exact behavior.
  ///
  /// [eventName] - The PascalCase name of the event, as defined in the IDL
  /// [callback] - The function to invoke whenever the event is emitted
  /// [commitment] - Optional commitment level for the subscription
  ///
  /// Returns a numeric listener ID that can be used with removeEventListener
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Listen for a specific event (TypeScript-compatible API)
  /// final listenerId = program.addEventListener<MyEventData>(
  ///   'MyEvent',
  ///   (eventData, slot, signature) {
  ///     print('Event received: $eventData at slot $slot');
  ///   },
  /// );
  ///
  /// // Cancel the subscription later
  /// await program.removeEventListener(listenerId);
  /// ```
  int addEventListener<T>(
    String eventName,
    event_types.EventCallback<T> callback, {
    CommitmentConfig? commitment,
  }) => _eventManager.addEventListener<T>(
    eventName,
    callback,
    commitment: commitment,
  );

  /// Remove an event listener (TypeScript-compatible)
  ///
  /// This method removes a previously registered event listener.
  ///
  /// [listenerId] - The numeric ID of the listener to remove (returned by addEventListener)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final listenerId = program.addEventListener('MyEvent', callback);
  /// // Later...
  /// await program.removeEventListener(listenerId);
  /// ```
  Future<void> removeEventListener(int listenerId) async =>
      _eventManager.removeEventListener(listenerId);

  /// Get event connection state
  ///
  /// Provides the current state of the event connection, such as whether it's
  /// active and the connection details.
  event_types.WebSocketState get currentEventConnectionState =>
      _eventManager.state;

  /// Get event connection state stream
  ///
  /// Provides a stream of connection state changes that can be listened to.
  Stream<event_types.WebSocketState> get eventConnectionStateUpdates =>
      _eventManager.stateStream;

  /// Get event statistics
  ///
  /// Returns statistics about event processing, such as the number of events
  /// received, processed, and any errors.
  event_types.EventStats get currentEventStats => _eventManager.stats;

  /// Dispose of resources used by the program
  Future<void> dispose() async {}

  /// Create a Program instance by fetching the IDL from the network
  ///
  /// This method fetches the IDL from the on-chain IDL account and creates
  /// a Program instance. The IDL must have been previously initialized
  /// via anchor CLI's `anchor idl init` command.
  ///
  /// [address] The on-chain address of the program as a base58 string
  /// [provider] The network and wallet provider. If not provided, uses
  ///           the default provider.
  ///
  /// Returns a Program instance or null if the IDL cannot be fetched.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Fetch IDL from devnet
  /// final connection = Connection('https://api.devnet.solana.com');
  /// final provider = AnchorProvider(connection, wallet);
  ///
  /// final program = await Program.at(
  ///   'Your_Program_ID_Here',
  ///   provider: provider,
  /// );
  ///
  /// if (program != null) {
  ///   // Use the program
  ///   final result = await program.methods.someMethod().rpc();
  /// } else {
  ///   print('Could not fetch IDL for program');
  /// }
  /// ```
  ///
  /// ## Note
  ///
  /// This method requires the program to have its IDL deployed on-chain.
}
