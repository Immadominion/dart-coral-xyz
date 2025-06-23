import 'dart:typed_data';
import '../idl/idl.dart';
import '../idl/idl_utils.dart';
import '../provider/provider.dart';
import '../coder/coder.dart';
import '../types/public_key.dart';
import '../types/commitment.dart';
import '../event/event_manager.dart';
import '../event/event_persistence.dart';
import '../event/event_debugging.dart';
import '../event/event_aggregation.dart';
import '../event/types.dart' hide EventCallback;
import 'namespace/namespace_factory.dart';
import 'namespace/account_namespace.dart';
import 'namespace/instruction_namespace.dart';
import 'namespace/methods_namespace.dart';
import 'namespace/rpc_namespace.dart';
import 'namespace/simulate_namespace.dart';
import 'namespace/transaction_namespace.dart';
import 'namespace/views_namespace.dart';
import 'program_error_handler.dart';
import 'context.dart';

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
  late final EventManager _eventManager;

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
    _eventManager = EventManager(
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
    _eventManager = EventManager(
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
  EventManager get events => _eventManager;

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

  /// The simulation namespace for transaction simulation
  ///
  /// This namespace provides methods that simulate transactions without
  /// actually sending them, useful for testing and debugging.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Simulate a transaction
  /// final simulation = await program.simulate.initialize(
  ///   args: [initValue],
  ///   accounts: {
  ///     'user': wallet.publicKey,
  ///     'systemProgram': SystemProgram.programId,
  ///   },
  /// );
  ///
  /// if (simulation.value.err != null) {
  ///   print('Simulation failed: ${simulation.value.err}');
  /// }
  /// ```
  SimulateNamespace get simulate => _namespaces.simulate;

  /// The methods namespace for fluent method building (primary interface)
  ///
  /// This is the primary interface for interacting with program methods.
  /// It provides a fluent API for building and executing program instructions.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Basic method call
  /// final result = await program.methods
  ///   .initialize(initValue)
  ///   .accounts({
  ///     'user': wallet.publicKey,
  ///     'systemProgram': SystemProgram.programId,
  ///   })
  ///   .rpc();
  ///
  /// // With additional signers
  /// final result = await program.methods
  ///   .updateData(newData)
  ///   .accounts({'dataAccount': dataKey})
  ///   .signers([additionalSigner])
  ///   .rpc();
  ///
  /// // Build instruction instead of sending
  /// final instruction = await program.methods
  ///   .myMethod()
  ///   .instruction();
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
    EventCallback<T> callback, {
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

  /// Get current event processing statistics
  ///
  /// Returns statistics about event processing including:
  /// - Total events processed
  /// - Parse errors
  /// - Events per second
  /// - etc.
  EventStats get eventStats => _eventManager.stats;

  /// Current WebSocket connection state for event subscriptions
  WebSocketState get eventConnectionState => _eventManager.state;

  /// Stream of connection state changes for event subscriptions
  Stream<WebSocketState> get eventConnectionStateStream =>
      _eventManager.stateStream;

  /// Dispose of all event subscriptions and close connections
  ///
  /// This method should be called when the Program instance is no longer needed
  /// to clean up WebSocket connections, event listeners, and namespace subscriptions.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Clean up when done with the program
  /// await program.dispose();
  /// ```
  Future<void> dispose() async {
    // Dispose event manager first to stop new events
    await _eventManager.dispose();

    // Clean up namespace subscriptions and resources
    _namespaces.account.dispose();

    // Clean up advanced event services
    await _eventPersistence?.dispose();
    // Note: EventDebugMonitor and EventAggregationService don't have dispose methods in current implementation
  }

  /// Enable event persistence for storing and retrieving historical events
  ///
  /// This method initializes the event persistence service which allows
  /// storing events to disk for later analysis and replay.
  ///
  /// [config] - Optional configuration for persistence service
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Enable with default configuration
  /// await program.enableEventPersistence();
  ///
  /// // Enable with custom configuration
  /// await program.enableEventPersistence(
  ///   EventPersistenceConfig.production()
  /// );
  /// ```
  Future<void> enableEventPersistence([EventPersistenceConfig? config]) async {
    _eventPersistence ??= EventPersistenceService(
      storageDirectory: config?.storageDirectory ?? './events',
      enableCompression: config?.enableCompression ?? true,
      maxFileSize: config?.maxFileSize ?? 50 * 1024 * 1024, // 50MB
    );
  }

  /// Enable event debugging and monitoring
  ///
  /// This method initializes the event debugging service which provides
  /// comprehensive monitoring, metrics, and alerting capabilities.
  ///
  /// [config] - Optional configuration for debugging service
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Enable with default configuration
  /// await program.enableEventDebugging();
  ///
  /// // Enable with custom configuration
  /// await program.enableEventDebugging(
  ///   EventMonitorConfig.production()
  /// );
  /// ```
  Future<void> enableEventDebugging([EventMonitorConfig? config]) async {
    _eventDebugging ??= EventDebugMonitor(
      config: config ?? const EventMonitorConfig(),
    );
  }

  /// Enable event aggregation and processing pipelines
  ///
  /// This method initializes the event aggregation service which provides
  /// advanced event processing capabilities including aggregation and pipelines.
  ///
  /// [config] - Optional configuration for aggregation service
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Enable with default configuration
  /// await program.enableEventAggregation();
  ///
  /// // Enable with custom configuration
  /// await program.enableEventAggregation(
  ///   EventAggregationConfig.production()
  /// );
  /// ```
  Future<void> enableEventAggregation([EventAggregationConfig? config]) async {
    _eventAggregation ??= EventAggregationService(
      config: config ?? const EventAggregationConfig(),
    );
  }

  /// Get event persistence statistics if persistence is enabled
  ///
  /// Returns statistics about stored events including total count,
  /// storage size, and processing metrics.
  ///
  /// ## Example
  ///
  /// ```dart
  /// if (program.isPersistenceEnabled) {
  ///   final stats = await program.getEventPersistenceStats();
  ///   print('Total events stored: ${stats.totalEvents}');
  ///   print('Storage size: ${stats.storageSize} bytes');
  /// }
  /// ```
  Future<EventPersistenceStats?> getEventPersistenceStats() async {
    return await _eventPersistence?.getStatistics();
  }

  /// Get event debugging and monitoring statistics if debugging is enabled
  ///
  /// Returns comprehensive debugging statistics including performance metrics,
  /// error rates, and monitoring data.
  ///
  /// ## Example
  ///
  /// ```dart
  /// if (program.isDebuggingEnabled) {
  ///   final stats = await program.getEventDebuggingStats();
  ///   print('Processing rate: ${stats.processingRate} events/sec');
  ///   print('Error rate: ${stats.errorRate}%');
  /// }
  /// ```
  Future<EventMonitoringStats?> getEventDebuggingStats() async {
    return _eventDebugging?.currentStats;
  }

  /// Get event aggregation results if aggregation is enabled
  ///
  /// Returns aggregated event data and processing pipeline results.
  ///
  /// ## Example
  ///
  /// ```dart
  /// if (program.isAggregationEnabled) {
  ///   final results = await program.getEventAggregationResults();
  ///   for (final result in results) {
  ///     print('Event: ${result.eventName}, Count: ${result.count}');
  ///   }
  /// }
  /// ```
  Future<List<AggregatedEvent>> getEventAggregationResults() async {
    if (_eventAggregation == null) return [];

    final results = <AggregatedEvent>[];
    await for (final event in _eventAggregation!.getAggregatedEvents('*')) {
      results.add(event);
      if (results.length >= 100) break; // Limit results
    }
    return results;
  }

  /// Restore events from persistence storage
  ///
  /// This method allows retrieving historical events from the persistence
  /// storage with optional filtering criteria.
  ///
  /// [filter] - Optional filter criteria for event selection
  /// [startTime] - Optional start time for event range
  /// [endTime] - Optional end time for event range
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Restore all events
  /// final allEvents = await program.restoreEvents();
  ///
  /// // Restore events with filtering
  /// final filteredEvents = await program.restoreEvents(
  ///   filter: EventFilter.byName('MyEvent'),
  ///   startTime: DateTime.now().subtract(Duration(days: 1)),
  /// );
  /// ```
  Future<List<ParsedEvent>> restoreEvents({
    EventFilter? filter,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (_eventPersistence == null) {
      throw StateError(
          'Event persistence is not enabled. Call enableEventPersistence() first.');
    }

    final results = <ParsedEvent>[];
    await for (final event in _eventPersistence!.restoreEvents(
      fromDate: startTime,
      toDate: endTime,
    )) {
      results.add(event);
    }
    return results;
  }

  /// Create an event processing pipeline
  ///
  /// This method creates a new event processing pipeline that can transform,
  /// filter, and aggregate events in real-time.
  ///
  /// [processors] - List of processors to include in the pipeline
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Create a pipeline with filtering and transformation
  /// final pipeline = await program.createEventPipeline([
  ///   FilterProcessor((event) => event.name == 'MyEvent'),
  ///   TransformProcessor((event) => event.copyWith(
  ///     metadata: {...event.metadata, 'processed': true}
  ///   )),
  /// ]);
  ///
  /// // Process events through the pipeline
  /// pipeline.processedEvents.listen((result) {
  ///   print('Processed event: ${result.event.name}');
  /// });
  /// ```
  Future<EventProcessingPipeline> createEventPipeline(
    List<EventPipelineProcessor> processors,
  ) async {
    if (_eventAggregation == null) {
      throw StateError(
          'Event aggregation is not enabled. Call enableEventAggregation() first.');
    }

    final pipeline = EventProcessingPipeline();
    for (final processor in processors) {
      pipeline.addProcessor(processor);
    }
    return pipeline;
  }

  /// Subscribe to aggregated events with specific aggregation type
  ///
  /// This method allows subscribing to events that have been aggregated
  /// using specified aggregation strategies (count, sum, average, etc.).
  ///
  /// [eventName] - Name of the event to aggregate
  /// [aggregator] - Aggregation strategy to use
  /// [windowSize] - Time window for aggregation
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Subscribe to event counts every 5 seconds
  /// final subscription = await program.subscribeToAggregatedEvents(
  ///   'MyEvent',
  ///   CountAggregator(),
  ///   Duration(seconds: 5),
  /// );
  ///
  /// subscription.listen((aggregatedEvent) {
  ///   print('Event count in last 5s: ${aggregatedEvent.value}');
  /// });
  /// ```
  Future<Stream<AggregatedEvent>> subscribeToAggregatedEvents(
    String eventName,
    EventAggregator aggregator,
    Duration windowSize,
  ) async {
    if (_eventAggregation == null) {
      throw StateError(
          'Event aggregation is not enabled. Call enableEventAggregation() first.');
    }

    // For now, return the aggregated events stream for the event name
    // This can be enhanced to support the specific aggregator and window size
    return _eventAggregation!.getAggregatedEvents(eventName);
  }

  /// Create a unified Program error for consistent error handling
  ///
  /// This method provides a consistent way to create errors for Program operations,
  /// matching TypeScript's error handling patterns.
  ///
  /// [message] The error message
  /// [cause] The underlying cause of the error (optional)
  ///
  /// ## Example
  ///
  /// ```dart
  /// throw program.createError(
  ///   'Failed to initialize account',
  ///   cause: someException,
  /// );
  /// ```
  ProgramOperationError createError(String message, [dynamic cause]) {
    return ProgramOperationError(
      operation: 'programOperation',
      message: message,
      code: 6100, // Program-specific error code
      cause: cause,
      context: {
        'programId': _programId.toBase58(),
      },
    );
  }

  /// Execute an operation with unified error handling
  ///
  /// This method wraps any Program operation with consistent error handling.
  ///
  /// [operationName] The name of the operation being performed
  /// [operation] The operation to execute
  /// [context] Additional context for error reporting
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = await program.withErrorHandling(
  ///   'customOperation',
  ///   () async => await someRiskyOperation(),
  ///   context: {'additional': 'info'},
  /// );
  /// ```
  Future<T> withErrorHandling<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? context,
  }) async {
    return await ProgramErrorHandler.wrapOperation(
      operationName,
      operation,
      context: {
        'programId': _programId.toBase58(),
        ...?context,
      },
    );
  }

  // ...existing code...
}
