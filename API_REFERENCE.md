# API Reference - Coral XYZ Anchor for Dart

This document provides comprehensive API documentation for the Coral XYZ Anchor Dart client.

## Table of Contents

- [Core Classes](#core-classes)
  - [Program](#program)
  - [AnchorProvider](#anchorprovider)
  - [Connection](#connection)
- [IDL System](#idl-system)
  - [Idl](#idl)
  - [IDL Types](#idl-types)
- [Coder System](#coder-system)
  - [Coder Interface](#coder-interface)
  - [BorshCoder](#borshcoder)
- [Namespaces](#namespaces)
  - [MethodsNamespace](#methodsnamespace)
  - [AccountNamespace](#accountnamespace)
  - [EventNamespace](#eventnamespace)
- [Types](#types)
  - [PublicKey](#publickey)
  - [Keypair](#keypair)
  - [Transaction](#transaction)
- [Utilities](#utilities)
  - [PDA Functions](#pda-functions)
  - [Serialization](#serialization)
- [Error Handling](#error-handling)

## Core Classes

### Program

The main class for interacting with Anchor programs.

```dart
class Program<T extends Idl>
```

#### Constructor

```dart
Program(
  T idl, {
  AnchorProvider? provider,
  Coder? coder,
})
```

Creates a new Program instance.

**Parameters:**

- `idl` - The IDL definition for the program
- `provider` - Network and wallet provider (optional, uses default if not provided)
- `coder` - Custom coder for serialization (optional, creates default BorshCoder)

**Example:**

```dart
final program = Program(idl, provider: provider);
```

#### Properties

##### `idl`

```dart
T get idl
```

The IDL definition for this program.

##### `programId`

```dart
PublicKey get programId
```

The program's public key address.

##### `provider`

```dart
AnchorProvider get provider
```

The provider for network and wallet operations.

##### `coder`

```dart
Coder get coder
```

The coder for serialization/deserialization.

##### `methods`

```dart
MethodsNamespace get methods
```

The primary interface for calling program methods.

**Example:**

```dart
final result = await program.methods
  .initialize(arg1)
  .accounts({'user': userKey})
  .rpc();
```

##### `account`

```dart
AccountNamespace get account
```

Interface for account operations.

**Example:**

```dart
final accountData = await program.account.myAccount.fetch(accountKey);
```

##### `instruction`

```dart
InstructionNamespace get instruction
```

Interface for building instructions without sending.

##### `transaction`

```dart
TransactionNamespace get transaction
```

Interface for building complete transactions.

##### `simulate`

```dart
SimulateNamespace get simulate
```

Interface for transaction simulation.

##### `rpc`

```dart
RpcNamespace get rpc
```

Interface for direct RPC calls.

#### Static Methods

##### `at`

```dart
static Future<Program<Idl>?> at(
  String address, {
  AnchorProvider? provider,
})
```

Creates a Program instance by fetching the IDL from the network.

**Parameters:**

- `address` - The program address as a base58 string
- `provider` - Network provider (optional)

**Returns:** Program instance or null if IDL not found

**Example:**

```dart
final program = await Program.at('YourProgramId', provider: provider);
```

##### `fetchIdl`

```dart
static Future<Idl?> fetchIdl(
  PublicKey programId, {
  AnchorProvider? provider,
})
```

Fetches an IDL from the blockchain.

##### `getIdlAddress`

```dart
static Future<PublicKey> getIdlAddress(PublicKey programId)
```

Calculates the IDL address for a given program ID.

#### Instance Methods

##### `getAccountSize`

```dart
int getAccountSize(String accountName)
```

Gets the size of an account type in bytes.

##### `validateProgramId`

```dart
void validateProgramId(PublicKey expectedProgramId)
```

Validates that this program matches the expected program ID.

### AnchorProvider

Manages connection and wallet for program interactions.

```dart
class AnchorProvider
```

#### Constructor

```dart
AnchorProvider(Connection connection, Wallet wallet)
```

#### Properties

##### `connection`

```dart
Connection get connection
```

The Solana RPC connection.

##### `wallet`

```dart
Wallet get wallet
```

The wallet for signing transactions.

#### Static Methods

##### `defaultProvider`

```dart
static AnchorProvider defaultProvider()
```

Gets the default provider (localhost connection).

##### `setDefault`

```dart
static void setDefault(AnchorProvider provider)
```

Sets the default provider.

### Connection

Manages RPC connections to Solana clusters.

```dart
class Connection
```

#### Constructor

```dart
Connection(String rpcEndpoint, {
  String? wsEndpoint,
  Duration? timeout,
})
```

#### Properties

##### `rpcEndpoint`

```dart
String get rpcEndpoint
```

The RPC endpoint URL.

##### `wsEndpoint`

```dart
String? get wsEndpoint
```

The WebSocket endpoint URL.

#### Methods

##### `getAccountInfo`

```dart
Future<AccountInfo?> getAccountInfo(PublicKey address)
```

Fetches account information.

##### `sendTransaction`

```dart
Future<String> sendTransaction(Transaction transaction)
```

Sends a transaction to the network.

##### `simulateTransaction`

```dart
Future<SimulationResult> simulateTransaction(Transaction transaction)
```

Simulates a transaction.

## IDL System

### Idl

Represents an Interface Definition Language file.

```dart
class Idl
```

#### Constructor

```dart
const Idl({
  required this.address,
  required this.metadata,
  required this.instructions,
  this.accounts,
  this.events,
  this.errors,
  this.types,
})
```

#### Factory Constructor

```dart
factory Idl.fromJson(Map<String, dynamic> json)
```

Creates an IDL from JSON data.

#### Properties

##### `address`

```dart
final String address
```

The program address.

##### `metadata`

```dart
final IdlMetadata metadata
```

Program metadata (name, version, etc.).

##### `instructions`

```dart
final List<IdlInstruction> instructions
```

List of program instructions.

##### `accounts`

```dart
final List<IdlAccount>? accounts
```

List of account types (optional).

##### `events`

```dart
final List<IdlEvent>? events
```

List of event types (optional).

##### `types`

```dart
final List<IdlTypeDef>? types
```

List of custom types (optional).

### IDL Types

#### IdlInstruction

Represents a program instruction.

```dart
class IdlInstruction {
  final String name;
  final List<IdlInstructionAccount> accounts;
  final List<IdlField> args;
  final List<int> discriminator;
}
```

#### IdlInstructionAccount

Represents an account in an instruction.

```dart
class IdlInstructionAccount {
  final String name;
  final bool? writable;
  final bool? signer;
  final bool? optional;
  final String? address;
  final IdlPda? pda;
}
```

#### IdlType

Represents a type in the IDL.

```dart
class IdlType {
  final String kind;
  final IdlType? inner;
  final int? size;
  final String? defined;
}
```

Common kinds:

- `'bool'`, `'u8'`, `'u16'`, `'u32'`, `'u64'`, `'i8'`, `'i16'`, `'i32'`, `'i64'`
- `'f32'`, `'f64'`, `'string'`, `'pubkey'`, `'bytes'`
- `'vec'` (with `inner`), `'option'` (with `inner`), `'array'` (with `inner` and `size`)
- `'defined'` (with `defined` name)

## Coder System

### Coder Interface

Base interface for all coders.

```dart
abstract class Coder<A extends String, T extends String>
```

#### Properties

##### `instruction`

```dart
InstructionCoder get instruction
```

##### `accounts`

```dart
AccountsCoder<A> get accounts
```

##### `events`

```dart
EventCoder get events
```

##### `types`

```dart
TypesCoder<T> get types
```

### BorshCoder

Borsh-based implementation of the Coder interface.

```dart
class BorshCoder<A extends String, T extends String> implements Coder<A, T>
```

#### Constructor

```dart
BorshCoder(Idl idl)
```

## Namespaces

### MethodsNamespace

Primary interface for calling program methods.

#### Methods

Dynamic methods are generated based on the IDL instructions.

```dart
// For instruction named "initialize"
MethodBuilder initialize(/* args based on IDL */)

// For instruction named "update"
MethodBuilder update(/* args based on IDL */)
```

### MethodBuilder

Fluent interface for building and executing methods.

#### Methods

##### `accounts`

```dart
MethodBuilder accounts(Map<String, PublicKey> accounts)
```

Sets the accounts for the instruction.

##### `signers`

```dart
MethodBuilder signers(List<Keypair> signers)
```

Adds additional signers.

##### `rpc`

```dart
Future<String> rpc()
```

Executes the method and returns the transaction signature.

##### `instruction`

```dart
Future<TransactionInstruction> instruction()
```

Builds and returns the instruction without sending.

##### `transaction`

```dart
Future<Transaction> transaction()
```

Builds and returns a complete transaction.

##### `simulate`

```dart
Future<SimulationResult> simulate()
```

Simulates the transaction.

### AccountNamespace

Interface for account operations.

#### Methods

Dynamic methods are generated based on the IDL accounts.

```dart
// For account type named "Counter"
AccountClient<Counter> get counter

// For account type named "User"
AccountClient<User> get user
```

### AccountClient

Client for a specific account type.

#### Methods

##### `fetch`

```dart
Future<T> fetch(PublicKey address)
```

Fetches a single account.

##### `all`

```dart
Future<List<AccountWithPubkey<T>>> all([List<Filter>? filters])
```

Fetches all accounts of this type.

##### `size`

```dart
int get size
```

Gets the account size in bytes.

## Types

### PublicKey

Represents a Solana public key.

```dart
class PublicKey
```

#### Constructors

##### `fromBase58`

```dart
factory PublicKey.fromBase58(String base58)
```

##### `fromBytes`

```dart
factory PublicKey.fromBytes(Uint8List bytes)
```

#### Static Methods

##### `findProgramAddress`

```dart
static Future<PdaResult> findProgramAddress(
  List<Uint8List> seeds,
  PublicKey programId,
)
```

#### Methods

##### `toBase58`

```dart
String toBase58()
```

##### `toBytes`

```dart
Uint8List toBytes()
```

### Keypair

Represents a Solana keypair (public + private key).

```dart
class Keypair
```

#### Constructors

##### `generate`

```dart
factory Keypair.generate()
```

##### `fromSecretKey`

```dart
factory Keypair.fromSecretKey(Uint8List secretKey)
```

#### Properties

##### `publicKey`

```dart
PublicKey get publicKey
```

##### `secretKey`

```dart
Uint8List get secretKey
```

### Transaction

Represents a Solana transaction.

```dart
class Transaction
```

#### Methods

##### `add`

```dart
Transaction add(TransactionInstruction instruction)
```

##### `sign`

```dart
Future<void> sign(List<Keypair> signers)
```

## Utilities

### PDA Functions

#### `findProgramAddress`

```dart
Future<PdaResult> findProgramAddress(
  List<Uint8List> seeds,
  PublicKey programId,
)
```

Finds a Program Derived Address.

#### `createWithSeed`

```dart
Future<PublicKey> createWithSeed(
  PublicKey fromPublicKey,
  String seed,
  PublicKey programId,
)
```

Creates an address with a seed.

### Serialization

#### Borsh Utilities

The package includes comprehensive Borsh serialization utilities:

```dart
// Serialize data
final serializer = BorshSerializer();
serializer.writeU64(12345);
final bytes = serializer.toBytes();

// Deserialize data
final deserializer = BorshDeserializer(bytes);
final value = deserializer.readU64();
```

## Error Handling

### AnchorException

Base exception for Anchor-related errors.

```dart
class AnchorException implements Exception {
  final String message;
  final dynamic cause;

  const AnchorException(this.message, [this.cause]);
}
```

### Specific Exceptions

#### `InstructionCoderException`

Thrown by instruction coder operations.

#### `AccountCoderException`

Thrown by account coder operations.

#### `EventCoderException`

Thrown by event coder operations.

#### `TypesCoderException`

Thrown by types coder operations.

### Error Handling Patterns

```dart
try {
  final result = await program.methods.myMethod().rpc();
} on AnchorException catch (e) {
  print('Anchor error: ${e.message}');
  if (e.cause != null) {
    print('Cause: ${e.cause}');
  }
} catch (e) {
  print('Other error: $e');
}
```

## Examples

### Basic Usage

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() async {
  // Setup
  final connection = Connection('https://api.devnet.solana.com');
  final provider = AnchorProvider(connection, wallet);
  final program = Program(idl, provider: provider);

  // Call method
  final result = await program.methods
    .initialize(initValue)
    .accounts({
      'user': wallet.publicKey,
      'systemProgram': SystemProgram.programId,
    })
    .rpc();

  print('Transaction: $result');
}
```

### Advanced Usage

```dart
// Build complex transaction
final instruction1 = await program.methods
  .firstMethod()
  .accounts({...})
  .instruction();

final instruction2 = await program.methods
  .secondMethod()
  .accounts({...})
  .instruction();

final transaction = Transaction()
  ..add(instruction1)
  ..add(instruction2);

await transaction.sign([wallet]);
final signature = await connection.sendTransaction(transaction);
```

## Version Information

This API reference is for coral_xyz_anchor version 0.1.0.

For the latest updates and changes, see the [CHANGELOG.md](CHANGELOG.md).

## Contributing

Found an error in the documentation? Please [open an issue](https://github.com/your-repo/issues) or submit a pull request.
