# Coral XYZ Anchor - Public API Documentation

This document provides comprehensive documentation for the public API of the Coral XYZ Anchor Dart SDK. All examples use only the public API exports available through `package:coral_xyz_anchor/coral_xyz_anchor.dart`.

## Table of Contents

1. [Core Types and Classes](#core-types-and-classes)
2. [Provider System](#provider-system)
3. [Program System](#program-system)
4. [IDL System](#idl-system)
5. [Coder System](#coder-system)
6. [Event System](#event-system)
7. [PDA and Address Utilities](#pda-and-address-utilities)
8. [Transaction System](#transaction-system)
9. [Namespace System](#namespace-system)
10. [Utility Functions](#utility-functions)
11. [Error Handling](#error-handling)
12. [Examples](#examples)

## Core Types and Classes

### PublicKey

Represents a Solana public key with validation and utility methods.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Create from base58 string
final publicKey = PublicKey.fromBase58('11111111111111111111111111111112');

// Create from bytes
final bytes = Uint8List(32);
final keyFromBytes = PublicKey.fromBytes(bytes);

// Generate unique key
final uniqueKey = PublicKey.unique();

// Convert to string/bytes
final base58String = publicKey.toBase58();
final keyBytes = publicKey.toBytes();

// Check if on curve
final isOnCurve = PublicKey.isOnCurve(publicKey);

// Validate base58 format
final isValid = PublicKey.isValidBase58('valid_base58_string');
```

### Keypair

Represents a Solana keypair for signing transactions.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Generate random keypair
final keypair = Keypair.generate();

// Create from secret key
final secretKey = Uint8List(64);
final keypairFromSecret = Keypair.fromSecretKey(secretKey);

// Access public key and secret key
final publicKey = keypair.publicKey;
final secretKey = keypair.secretKey;

// Sign data
final data = Uint8List.fromList([1, 2, 3]);
final signature = keypair.sign(data);
```

### Connection

Manages connection to Solana RPC endpoints with enhanced features.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Basic connection
final connection = Connection('https://api.devnet.solana.com');

// Enhanced connection with retry configuration
final enhancedConnection = EnhancedConnection(
  'https://api.devnet.solana.com',
  retryConfig: RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 5),
  ),
);

// Connection pool for high-performance applications
final connectionPool = ConnectionPool(
  endpoints: [
    'https://api.devnet.solana.com',
    'https://api.mainnet-beta.solana.com',
  ],
  config: ConnectionPoolConfig(
    maxConnectionsPerEndpoint: 10,
    loadBalancingStrategy: LoadBalancingStrategy.roundRobin,
  ),
);
```

### Transaction

Represents Solana transactions with builder pattern support.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Create transaction
final transaction = Transaction();

// Add instructions
final instruction = Instruction(
  programId: PublicKey.fromBase58('program_id'),
  accounts: [
    AccountMeta(
      pubkey: PublicKey.fromBase58('account_key'),
      isSigner: true,
      isWritable: true,
    ),
  ],
  data: Uint8List.fromList([1, 2, 3]),
);

transaction.add(instruction);

// Set recent blockhash
transaction.recentBlockhash = 'recent_blockhash';

// Sign transaction
transaction.sign([keypair]);
```

## Provider System

### AnchorProvider

Main provider class that combines connection and wallet for program interactions.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Create provider
final connection = Connection('https://api.devnet.solana.com');
final wallet = KeypairWallet(keypair);
final provider = AnchorProvider(connection, wallet);

// Configure options
final options = ConfirmOptions(
  commitment: Commitment.confirmed,
  preflightCommitment: Commitment.processed,
  skipPreflight: false,
);

final providerWithOptions = AnchorProvider(connection, wallet, options);

// Send and confirm transaction
final transaction = Transaction();
final signature = await provider.sendAndConfirm(transaction);
```

### Wallet Integration

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Keypair wallet
final keypairWallet = KeypairWallet(keypair);

// Mobile wallet adapter
final mobileWallet = MobileWalletAdapterWallet();
await mobileWallet.connect();

// Wallet discovery
final walletDiscovery = WalletDiscovery();
final availableWallets = await walletDiscovery.getAvailableWallets();
```

## Program System

### Program

Main class for interacting with Anchor programs.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Load program
final programId = PublicKey.fromBase58('your_program_id');
final program = Program(idl, programId, provider);

// Access namespaces
final methods = program.methods;
final account = program.account;
final instruction = program.instruction;
final transaction = program.transaction;
final simulate = program.simulate;
final views = program.views;
final rpc = program.rpc;
```

### Method Builder

Type-safe method building with fluent API.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Call program method
final result = await program.methods
  .myInstruction('arg1', 42)
  .accounts({
    'user': userPublicKey,
    'systemProgram': SystemProgram.programId,
  })
  .signers([userKeypair])
  .rpc();

// Build transaction without sending
final tx = await program.methods
  .myInstruction('arg1', 42)
  .accounts({'user': userPublicKey})
  .transaction();

// Simulate transaction
final simulation = await program.methods
  .myInstruction('arg1', 42)
  .accounts({'user': userPublicKey})
  .simulate();
```

## IDL System

### IDL Types

Complete IDL type system with validation and conversion.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Create IDL
final idl = Idl(
  version: '0.1.0',
  name: 'my_program',
  instructions: [
    IdlInstruction(
      name: 'initialize',
      accounts: [
        IdlAccount(
          name: 'user',
          isMut: true,
          isSigner: true,
        ),
      ],
      args: [
        IdlField(
          name: 'amount',
          type: IdlType.u64(),
        ),
      ],
    ),
  ],
  accounts: [
    IdlTypeDef(
      name: 'UserAccount',
      type: IdlTypeDefType.struct(
        fields: [
          IdlField(name: 'owner', type: IdlType.publicKey()),
          IdlField(name: 'balance', type: IdlType.u64()),
        ],
      ),
    ),
  ],
);

// IDL utilities
final fetchedIdl = await IdlUtils.fetchIdl(connection, programId);
final parsedIdl = IdlUtils.parseIdl(idlJson);
```

## Coder System

### BorshCoder

Main coder for serializing/deserializing program data.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Create coder
final coder = BorshCoder(idl);

// Instruction coding
final instructionData = coder.instruction.encode('initialize', {
  'amount': 1000,
  'name': 'test_account',
});

final decoded = coder.instruction.decode(instructionData);

// Account coding
final accountData = coder.accounts.encode('UserAccount', {
  'owner': userPublicKey,
  'balance': 1000,
});

final account = coder.accounts.decode('UserAccount', accountData);

// Event coding
final eventData = coder.events.encode('MyEvent', {
  'user': userPublicKey,
  'amount': 500,
});

final event = coder.events.decode(eventData);
```

### Type Conversion

Unified type conversion system with TypeScript compatibility.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Type converter
final converter = TypeConverter();

// Convert Dart types to IDL types
final idlType = converter.dartTypeToIdl(String);
final dartType = converter.idlTypeToDart(IdlType.string());

// Validate and convert values
final convertedValue = converter.convertValue('test', IdlType.string());
final isValid = converter.validateValue(42, IdlType.u64());
```

## Event System

### Event Subscription

Comprehensive event listening and processing.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Basic event listener
program.addEventListener('MyEvent', (event, slot, signature) {
  print('Event: ${event.data}');
  print('Slot: $slot');
  print('Signature: $signature');
});

// Advanced event subscription
final subscriptionManager = EventSubscriptionManager(connection);
final subscription = await subscriptionManager.subscribe(
  programId,
  config: EventSubscriptionConfig(
    filters: [
      EventFilter.byType('MyEvent'),
      EventFilter.byAccount(userPublicKey),
    ],
    commitment: Commitment.confirmed,
    enableMetrics: true,
  ),
);

// Event processing pipeline
final processor = EventProcessor(
  handlers: {
    'MyEvent': (event) => handleMyEvent(event),
    'AnotherEvent': (event) => handleAnotherEvent(event),
  },
);

await processor.processEvent(parsedEvent);

// Event persistence
final persistence = EventPersistence();
await persistence.saveEvent(event);
final savedEvents = await persistence.getEvents(
  programId: programId,
  fromSlot: 100000,
  toSlot: 200000,
);
```

### Event Debugging

Development tools for event monitoring.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Event debugging
final debugger = EventDebugging();
await debugger.startLogging(programId);

final metrics = debugger.getMetrics();
print('Events processed: ${metrics.totalEvents}');
print('Average processing time: ${metrics.averageProcessingTime}');

// Event aggregation
final aggregator = EventAggregation();
await aggregator.startAggregation(programId);

final stats = aggregator.getStatistics();
print('Event types: ${stats.eventTypes}');
print('Hourly breakdown: ${stats.hourlyBreakdown}');
```

## PDA and Address Utilities

### PDA Derivation

Program Derived Address utilities with caching.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Basic PDA derivation
final seeds = [
  Uint8List.fromList('user'.codeUnits),
  userPublicKey.toBytes(),
];

final pda = await PublicKey.findProgramAddress(seeds, programId);
print('PDA: ${pda.address}');
print('Bump: ${pda.bump}');

// PDA utilities
final pdaUtils = PdaUtils();
final derivedPda = await pdaUtils.derivePda(
  seeds: seeds,
  programId: programId,
);

// Address resolver
final resolver = AddressResolver();
final resolvedAddress = await resolver.resolveAddress(
  'user_account',
  context: {'user': userPublicKey},
);

// PDA caching
final cache = PdaCache();
final cachedPda = await cache.getPda(seeds, programId);
```

### Multisig Utilities

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Multisig configuration
final multisigConfig = MultisigConfig(
  owners: [owner1, owner2, owner3],
  threshold: 2,
  programId: multisigProgramId,
);

// Create multisig seeds
final seeds = MultisigUtils.createMultisigSeeds(multisigConfig);

// Find multisig signer
final signerPda = await MultisigUtils.findMultisigSigner(
  multisigKey,
  transactionIndex,
  programId,
);

// Validate signatures
final isValid = MultisigUtils.validateSignatures(
  transaction,
  multisigConfig,
);
```

## Transaction System

### Transaction Building

Advanced transaction building with validation.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Transaction builder
final builder = TransactionBuilder(connection);
final transaction = await builder
  .addInstruction(instruction1)
  .addInstruction(instruction2)
  .setRecentBlockhash()
  .setFeePayer(feePayer)
  .build();

// Transaction validator
final validator = TransactionValidator();
final validation = await validator.validate(transaction);
if (!validation.isValid) {
  print('Validation errors: ${validation.errors}');
}

// Transaction optimizer
final optimizer = TransactionOptimizer();
final optimized = await optimizer.optimize(transaction);
print('Optimizations applied: ${optimized.optimizations}');
```

### Simulation System

Comprehensive transaction simulation and analysis.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Basic simulation
final simulator = TransactionSimulator(connection);
final result = await simulator.simulate(transaction);

print('Success: ${result.success}');
print('Compute units used: ${result.computeUnitsUsed}');
print('Logs: ${result.logs}');

// Pre-flight validation
final validator = PreflightValidator(connection);
final validation = await validator.validate(transaction);

// Compute unit analysis
final analyzer = ComputeUnitAnalyzer(connection);
final analysis = await analyzer.analyze(transaction);
print('Recommended compute units: ${analysis.recommendedComputeUnits}');
print('Estimated fee: ${analysis.estimatedFee}');

// Enhanced simulation analysis
final enhancedAnalyzer = EnhancedSimulationAnalyzer(connection);
final enhancedResult = await enhancedAnalyzer.analyze(transaction);
print('Optimization recommendations: ${enhancedResult.recommendations}');
```

## Namespace System

### Account Namespace

Account fetching and management.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Fetch single account
final accountData = await program.account.userAccount.fetch(accountPublicKey);
print('Owner: ${accountData.owner}');
print('Balance: ${accountData.balance}');

// Fetch multiple accounts
final accounts = await program.account.userAccount.fetchMultiple([
  account1PublicKey,
  account2PublicKey,
]);

// Account subscription
final subscription = await program.account.userAccount.subscribe(
  accountPublicKey,
  callback: (account) {
    print('Account updated: ${account.balance}');
  },
);

// Account cache management
final cacheManager = AccountCacheManager(
  config: AccountCacheConfig(
    maxEntries: 1000,
    ttl: Duration(minutes: 5),
    invalidationStrategy: CacheInvalidationStrategy.timeToLive,
  ),
);

final cachedAccount = await cacheManager.get(accountPublicKey);
```

### Instruction Namespace

Instruction building and execution.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Build instruction
final instruction = await program.instruction.initialize(
  'arg1',
  42,
  accounts: {
    'user': userPublicKey,
    'systemProgram': SystemProgram.programId,
  },
);

// Add to transaction
final transaction = Transaction();
transaction.add(instruction);
```

## Utility Functions

### Data Conversion

Comprehensive data manipulation utilities.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Buffer operations
final buffer = DataConverter.createBuffer(32);
final combined = DataConverter.concat([buffer1, buffer2]);
final slice = DataConverter.slice(buffer, 0, 16);

// Encoding/decoding
final base58Encoded = DataConverter.encodeBase58(data);
final base58Decoded = DataConverter.decodeBase58(encoded);

final hexEncoded = DataConverter.encodeHex(data);
final hexDecoded = DataConverter.decodeHex(encoded);

// Number conversion
final u64Bytes = DataConverter.u64ToBytes(1000, Endian.little);
final u64Value = DataConverter.bytesToU64(bytes, Endian.little);

// BigInt support
final bigIntBytes = DataConverter.bigIntToBytes(BigInt.from(1000), 8);
final bigIntValue = DataConverter.bytesToBigInt(bytes, 8, signed: false);
```

### PublicKey Utilities

Extended PublicKey manipulation.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// Address validation
final isValid = PublicKeyUtils.isValidBase58(address);

// Deterministic address generation
final deterministicKey = PublicKeyUtils.createDeterministicAddress(
  seeds: [seed1, seed2],
  programId: programId,
);

// Address comparison
final areEqual = PublicKeyUtils.equals(key1, key2);

// Default addresses
final defaultKey = PublicKeyUtils.defaultKey();
final systemProgram = PublicKeyUtils.systemProgram();
```

## Error Handling

### Exception Types

Comprehensive error handling system.

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

try {
  await program.methods.myInstruction().rpc();
} on AnchorException catch (e) {
  print('Anchor error: ${e.message}');
  print('Error code: ${e.code}');
  print('Program: ${e.program}');
} on ProviderException catch (e) {
  print('Provider error: ${e.message}');
} on ConnectionException catch (e) {
  print('Connection error: ${e.message}');
  print('Endpoint: ${e.endpoint}');
} catch (e) {
  print('Unexpected error: $e');
}

// Error utilities
final errorHandler = ErrorHandler();
final handled = errorHandler.handleError(error);
print('User-friendly message: ${handled.userMessage}');
print('Retry recommended: ${handled.canRetry}');
```

## Examples

### Complete Program Interaction

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() async {
  // Setup
  final connection = Connection('https://api.devnet.solana.com');
  final keypair = Keypair.generate();
  final wallet = KeypairWallet(keypair);
  final provider = AnchorProvider(connection, wallet);

  // Load program
  final programId = PublicKey.fromBase58('your_program_id');
  final program = Program(idl, programId, provider);

  // Call instruction
  try {
    final signature = await program.methods
      .initialize(1000, 'test_account')
      .accounts({
        'user': keypair.publicKey,
        'userAccount': userAccountPda,
        'systemProgram': SystemProgram.programId,
      })
      .signers([keypair])
      .rpc();

    print('Transaction signature: $signature');

    // Fetch created account
    final account = await program.account.userAccount.fetch(userAccountPda);
    print('Created account balance: ${account.balance}');

  } catch (e) {
    print('Error: $e');
  }
}
```

### Event Monitoring

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() async {
  final connection = Connection('https://api.devnet.solana.com');
  final programId = PublicKey.fromBase58('your_program_id');

  // Set up event monitoring
  final subscriptionManager = EventSubscriptionManager(connection);

  await subscriptionManager.subscribe(
    programId,
    config: EventSubscriptionConfig(
      filters: [EventFilter.byType('TransferEvent')],
      commitment: Commitment.confirmed,
    ),
    onEvent: (event, slot, signature) {
      print('Transfer event detected:');
      print('  From: ${event.data.from}');
      print('  To: ${event.data.to}');
      print('  Amount: ${event.data.amount}');
      print('  Slot: $slot');
    },
  );

  print('Event monitoring started...');
}
```

### Multi-Program Workflow

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() async {
  final connection = Connection('https://api.devnet.solana.com');
  final wallet = KeypairWallet(Keypair.generate());
  final provider = AnchorProvider(connection, wallet);

  // Load multiple programs
  final program1 = Program(idl1, programId1, provider);
  final program2 = Program(idl2, programId2, provider);

  // Build cross-program transaction
  final instruction1 = await program1.instruction.initialize(
    accounts: {'user': wallet.publicKey},
  );

  final instruction2 = await program2.instruction.processData(
    accounts: {
      'dataAccount': dataAccountPda,
      'user': wallet.publicKey,
    },
  );

  // Execute in single transaction
  final transaction = Transaction();
  transaction.add(instruction1);
  transaction.add(instruction2);

  final signature = await provider.sendAndConfirm(transaction);
  print('Cross-program transaction: $signature');
}
```

This documentation covers the complete public API of the Coral XYZ Anchor Dart SDK. All examples use only public API imports and demonstrate production-ready patterns for building Solana applications with Dart.
