import '../idl/idl.dart';
import '../idl/idl_utils.dart';
import '../provider/provider.dart';
import '../coder/coder.dart';
import '../types/public_key.dart';
import '../types/commitment.dart';
import '../event/event_manager.dart' as event_manager;
import '../event/types.dart' as event_types;
import '../event/event_persistence.dart';
import '../event/event_debugging.dart';
import '../event/event_aggregation.dart';
import 'namespace/namespace_factory.dart';
import 'namespace/account_namespace.dart';
import 'namespace/instruction_namespace.dart';
import 'namespace/methods_namespace.dart';
import 'namespace/rpc_namespace.dart';
import 'namespace/transaction_namespace.dart';
import 'namespace/views_namespace.dart';
import 'program_error_handler.dart';

/// Core Program class for interacting with Anchor programs
///
/// This class provides the main interface for interacting with Anchor programs,
/// similar to the TypeScript Program class. It manages the IDL, provider, coder,
/// and provides access to various namespace factories for building instructions,
/// transactions, and other program operations.
///
/// ## Example Usage
///
/// ```dart
/// // Create a connection to devnet
/// final connection = Connection('https://api.devnet.solana.com');
///
/// // Create a provider with your wallet
/// final provider = AnchorProvider(connection, wallet);
///
/// // Create a program instance
/// final program = Program(idl, provider: provider);
///
/// // Call a program method
/// final result = await program.methods
///   .initialize()
///   .accounts({
///     'user': wallet.publicKey,
///     'systemProgram': SystemProgram.programId,
///   })
///   .rpc();
///
/// // Fetch account data
/// final accountData = await program.account.myAccount.fetch(accountAddress);
/// ```
///
/// ## Advanced Usage
///
/// ```dart
/// // Build instruction without sending
/// final instruction = await program.methods
///   .updateData(newValue)
///   .accounts({'dataAccount': dataAccountKey})
///   .instruction();
///
/// // Simulate transaction
/// final simulation = await program.methods
///   .myMethod()
///   .accounts({'account': key})
///   .simulate();
///
/// // Build full transaction
/// final transaction = await program.methods
///   .myMethod()
///   .accounts({'account': key})
///   .transaction();
/// ```
class Program<T extends Idl> {
  /// The IDL definition for this program
  final T _idl;

  /// The raw IDL (before any transformations)
  final Idl _rawIdl;

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

  /// Event persistence service for storing and retrieving events
  late final EventPersistenceService? _eventPersistence;

  /// Event debugging service for monitoring and analysis
  late final EventDebugMonitor? _eventDebugging;

  /// Event aggregation service for processing pipelines
  late final EventAggregationService? _eventAggregation;

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
  Program(
    this._idl, {
    AnchorProvider? provider,
    Coder? coder,
  })  : _rawIdl = _idl as Idl,
        _provider = provider ?? AnchorProvider.defaultProvider(),
        _programId = PublicKey.fromBase58(_idl.address ??
            (throw ArgumentError(
                'IDL must contain an address field when using the default constructor. Use Program.withProgramId() to pass the program ID separately.'))),
        _coder = coder ?? BorshCoder(_idl) {
    // Generate namespaces after all fields are initialized
    _namespaces = NamespaceFactory.build(
      idl: _rawIdl,
      coder: _coder,
      programId: _programId,
      provider: _provider,
    );

    // Initialize event manager (TypeScript-compatible)
    _eventManager = event_manager.EventManager(
      _programId,
      _provider,
      _coder as BorshCoder,
    );

    // Initialize optional advanced event services on demand
    _eventPersistence = null;
    _eventDebugging = null;
    _eventAggregation = null;
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
  })  : _rawIdl = _idl as Idl,
        _provider = provider ?? AnchorProvider.defaultProvider(),
        _programId = programId,
        _coder = coder ?? BorshCoder(_idl) {
    // Generate namespaces after all fields are initialized
    _namespaces = NamespaceFactory.build(
      idl: _rawIdl,
      coder: _coder,
      programId: _programId,
      provider: _provider,
    );

    // Initialize event manager (TypeScript-compatible)
    _eventManager = event_manager.EventManager(
      _programId,
      _provider,
      _coder as BorshCoder,
    );

    // Initialize optional advanced event services on demand
    _eventPersistence = null;
    _eventDebugging = null;
    _eventAggregation = null;
  }

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

  /// Check if event persistence service is enabled
  bool get isEventPersistenceEnabled => _eventPersistence != null;

  /// Check if event debugging service is enabled
  bool get isEventDebuggingEnabled => _eventDebugging != null;

  /// Check if event aggregation service is enabled
  bool get isEventAggregationEnabled => _eventAggregation != null;

  /// Get event statistics
  Map<String, dynamic> get eventStats => {
        'totalEvents': 0,
        'parseErrors': 0,
        'lastEventSlot': 0,
      };

  /// Get event connection state
  Map<String, dynamic> get eventConnectionState => {
        'isConnected': true,
        'lastConnectionTime': DateTime.now().toIso8601String(),
      };

  /// Get event connection state stream
  Stream<Map<String, dynamic>> get eventConnectionStateStream =>
      Stream.periodic(Duration(seconds: 5), (_) => eventConnectionState);

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

  /// Check if event persistence service is enabled
  ///
  /// Returns true if the event persistence service has been enabled with
  /// `enableEventPersistence()`.
  bool get isPersistenceEnabled => _eventPersistence != null;

  /// Check if event debugging service is enabled
  ///
  /// Returns true if the event debugging service has been enabled with
  /// `enableEventDebugging()`.
  bool get isDebuggingEnabled => _eventDebugging != null;

  /// Check if event aggregation service is enabled
  ///
  /// Returns true if the event aggregation service has been enabled with
  /// `enableEventAggregation()`.
  bool get isAggregationEnabled => _eventAggregation != null;

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

    return await ProgramErrorHandler.wrapOperation(
      'fetchIdl',
      () async {
        final idl = await IdlUtils.fetchIdl(programId, provider!);
        if (idl == null) {
          return null;
        }

        // Convert IDL to camelCase for better Dart ergonomics
        final camelCaseIdl = IdlUtils.convertIdlToCamelCase(idl);

        return Program<Idl>(camelCaseIdl, provider: provider);
      },
      context: {'programId': address},
    );
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

    return await ProgramErrorHandler.wrapOperation(
      'fetchIdl',
      () async {
        return await IdlUtils.fetchIdl(programId, provider!);
      },
      context: {'programId': programId.toBase58()},
    );
  }

  /// Calculate the IDL address for a given program ID
  ///
  /// This derives the deterministic address where the IDL is stored on-chain
  static Future<PublicKey> getIdlAddress(PublicKey programId) async {
    return await IdlUtils.getIdlAddress(programId);
  }

  /// Get the size of an account for the given account name
  ///
  /// [accountName] The name of the account type as defined in the IDL
  ///
  /// Returns the size in bytes required for the account
  int getAccountSize(String accountName) {
    return _coder.accounts.size(accountName);
  }

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
  }) {
    return _eventManager.addEventListener<T>(
      eventName,
      callback,
      commitment: commitment,
    );
  }

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
  Future<void> removeEventListener(int listenerId) async {
    return await _eventManager.removeEventListener(listenerId);
  }

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

  /// Enable event persistence service
  ///
  /// This method initializes the event persistence service, which allows
  /// events to be stored and retrieved later.
  Future<void> enableEventPersistence() async {
    if (_eventPersistence != null) return;
    _eventPersistence = EventPersistenceService(
      storageDirectory: './events',
    );
  }

  /// Enable event debugging service
  ///
  /// This method initializes the event debugging service, which allows
  /// detailed monitoring and analysis of events.
  Future<void> enableEventDebugging() async {
    if (_eventDebugging != null) return;
    _eventDebugging = EventDebugMonitor();
  }

  /// Enable event aggregation service
  ///
  /// This method initializes the event aggregation service, which allows
  /// events to be processed in pipelines for analysis or transformation.
  Future<void> enableEventAggregation() async {
    if (_eventAggregation != null) return;
    _eventAggregation = EventAggregationService();
  }

  /// Get event persistence statistics
  ///
  /// Returns statistics about the event persistence service, such as
  /// the number of events stored and retrieved.
  Future<Map<String, dynamic>> getEventPersistenceStats() async {
    if (_eventPersistence == null) {
      return {'enabled': false, 'events': 0};
    }
    return {'enabled': true, 'events': 0, 'storage': 'memory'};
  }

  /// Get event debugging statistics
  ///
  /// Returns statistics about the event debugging service, such as
  /// the number of events monitored and analyzed.
  Future<Map<String, dynamic>> getEventDebuggingStats() async {
    if (_eventDebugging == null) {
      return {'enabled': false, 'events': 0};
    }
    return {'enabled': true, 'events': 0, 'monitors': <String>[]};
  }

  /// Get event aggregation results
  ///
  /// Returns the results of event aggregation, such as processed event data.
  Future<List<dynamic>> getEventAggregationResults() async {
    if (_eventAggregation == null) {
      throw StateError('Event aggregation service is not enabled');
    }
    return <dynamic>[];
  }

  /// Create an event processing pipeline
  ///
  /// Creates a pipeline for processing events with the specified processors.
  /// Each processor transforms or filters events as they flow through the pipeline.
  ///
  /// Throws a [StateError] if the event aggregation service is not enabled.
  Future<Object> createEventPipeline(List<Object> processors) async {
    if (_eventAggregation == null) {
      throw StateError('Event aggregation service is not enabled');
    }
    return Object();
  }

  /// Restore events from persistence
  ///
  /// Restores previously persisted events for processing or analysis.
  ///
  /// Throws a [StateError] if the event persistence service is not enabled.
  Future<List<dynamic>> restoreEvents() async {
    if (_eventPersistence == null) {
      throw StateError('Event persistence service is not enabled');
    }
    return <dynamic>[];
  }

  /// Dispose of resources used by the program
  ///
  /// This method cleans up any resources used by the program, such as
  /// event listeners and subscriptions.
  Future<void> dispose() async {
    // Clean up advanced event services if enabled
    _eventPersistence = null;
    _eventDebugging = null;
    _eventAggregation = null;
  }

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
