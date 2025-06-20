import 'dart:typed_data';
import '../idl/idl.dart';
import '../provider/provider.dart';
import '../coder/coder.dart';
import '../types/public_key.dart';
import '../types/commitment.dart';
import '../event/event_manager.dart';
import '../event/types.dart';
import '../event/event_subscription.dart';
import 'namespace/namespace_factory.dart';
import 'namespace/account_namespace.dart';
import 'namespace/instruction_namespace.dart';
import 'namespace/methods_namespace.dart';
import 'namespace/rpc_namespace.dart';
import 'namespace/simulate_namespace.dart';
import 'namespace/transaction_namespace.dart';

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

  /// Event manager for handling program event subscriptions
  late final EventManager _eventManager;

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

    // Initialize event manager
    _eventManager = EventManager(
      programId: _programId,
      provider: _provider,
      coder: _coder as BorshCoder,
    );
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

    // Initialize event manager
    _eventManager = EventManager(
      programId: _programId,
      provider: _provider,
      coder: _coder as BorshCoder,
    );
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
    final idl = await fetchIdl(programId, provider: provider);

    if (idl == null) {
      return null;
    }

    return Program<Idl>(idl, provider: provider);
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

    try {
      // Calculate the IDL address
      final idlAddress = await getIdlAddress(programId);

      // Fetch the account info
      final accountInfo = await provider.connection.getAccountInfo(
        idlAddress,
      );

      if (accountInfo == null) {
        return null;
      }

      // TODO: Implement proper IDL account decoding with compression handling
      // For now, return null as this requires more infrastructure
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Calculate the IDL address for a given program ID
  ///
  /// This derives the deterministic address where the IDL is stored on-chain
  static Future<PublicKey> getIdlAddress(PublicKey programId) async {
    final seeds = [
      'anchor:idl'.codeUnits,
      programId.bytes,
    ];

    final result = await PublicKey.findProgramAddress(
      seeds.map((seed) => Uint8List.fromList(seed)).toList(),
      programId,
    );

    return result.address;
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

  /// Invokes the given callback every time the given event is emitted
  ///
  /// This method registers an event listener for a specific event type defined in the IDL.
  /// The callback will be invoked whenever the event is emitted from program logs.
  ///
  /// [eventName] - The PascalCase name of the event, as defined in the IDL
  /// [callback] - The function to invoke whenever the event is emitted
  /// [commitment] - Optional commitment level for the subscription
  ///
  /// Returns a subscription that can be used to cancel the listener
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Listen for a specific event
  /// final subscription = await program.addEventListener<MyEventData>(
  ///   'MyEvent',
  ///   (eventData, slot, signature) {
  ///     print('Event received: $eventData at slot $slot');
  ///   },
  /// );
  ///
  /// // Cancel the subscription later
  /// await subscription.cancel();
  /// ```
  Future<EventSubscription> addEventListener<T>(
    String eventName,
    EventCallback<T> callback, {
    CommitmentConfig? commitment,
  }) async {
    return await _eventManager.addEventListener<T>(
      eventName,
      callback,
      commitment: commitment,
    );
  }

  /// Remove an event listener
  ///
  /// This method removes a previously registered event listener.
  ///
  /// [listenerId] - The ID of the listener to remove
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Remove listener using the subscription
  /// await subscription.cancel();
  ///
  /// // Or remove directly by ID
  /// await program.removeEventListener(listenerId);
  /// ```
  Future<void> removeEventListener(String listenerId) async {
    return await _eventManager.removeEventListener(listenerId);
  }

  /// Subscribe to all program logs
  ///
  /// This method subscribes to raw transaction logs for this program.
  /// It provides access to all logs, including those that may not be events.
  ///
  /// [callback] - Function to call when logs are received
  /// [commitment] - Optional commitment level for the subscription
  ///
  /// Returns a subscription that can be used to cancel the log listener
  ///
  /// ## Example
  ///
  /// ```dart
  /// final subscription = await program.subscribeToLogs((logs) {
  ///   print('Program logs: ${logs.logs}');
  ///   if (logs.err != null) {
  ///     print('Transaction failed: ${logs.err}');
  ///   }
  /// });
  /// ```
  Future<EventSubscription> subscribeToLogs(
    LogCallback callback, {
    CommitmentConfig? commitment,
  }) async {
    return await _eventManager.subscribeToLogs(
      callback,
      commitment: commitment,
    );
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
  /// to clean up WebSocket connections and event listeners.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Clean up when done with the program
  /// await program.dispose();
  /// ```
  Future<void> dispose() async {
    await _eventManager.dispose();
  }

  @override
  String toString() {
    return 'Program(programId: ${_programId.toBase58()}, '
        'name: ${_idl.metadata?.name ?? "Unknown"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Program &&
        other._programId == _programId &&
        other._idl.metadata?.name == _idl.metadata?.name;
  }

  @override
  int get hashCode => _programId.hashCode ^ (_idl.metadata?.name.hashCode ?? 0);
}
