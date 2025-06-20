# Migration Guide: TypeScript to Dart Anchor Client

This guide helps developers familiar with the TypeScript `@coral-xyz/anchor` package transition to the Dart `coral_xyz_anchor` package. While the APIs are very similar, there are some important differences due to language constraints and Dart idioms.

## Table of Contents

- [Installation & Setup](#installation--setup)
- [Basic Program Setup](#basic-program-setup)
- [Method Calls](#method-calls)
- [Account Operations](#account-operations)
- [Event Handling](#event-handling)
- [Type Differences](#type-differences)
- [Error Handling](#error-handling)
- [Advanced Patterns](#advanced-patterns)

## Installation & Setup

### TypeScript

```bash
npm install @coral-xyz/anchor
yarn add @coral-xyz/anchor
```

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program, AnchorProvider } from "@coral-xyz/anchor";
```

### Dart

```yaml
# pubspec.yaml
dependencies:
  coral_xyz_anchor: ^0.1.0
```

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
```

## Basic Program Setup

### TypeScript

```typescript
import { Connection, PublicKey } from "@solana/web3.js";
import { AnchorProvider, Program } from "@coral-xyz/anchor";

// Setup connection and provider
const connection = new Connection("https://api.devnet.solana.com");
const provider = new AnchorProvider(connection, wallet, {});

// Load program
const programId = new PublicKey("Your_Program_ID");
const program = new Program(idl, programId, provider);
```

### Dart

```dart
// Setup connection and provider
final connection = Connection('https://api.devnet.solana.com');
final provider = AnchorProvider(connection, wallet);

// Load program (program ID comes from IDL)
final idl = Idl.fromJson(idlJson);
final program = Program(idl, provider: provider);
```

**Key Differences:**

- Dart: Program ID is derived from the IDL's `address` field
- Dart: Provider configuration is simpler
- Dart: No need for separate program ID parameter

## Method Calls

### TypeScript

```typescript
// Basic method call
const tx = await program.methods
  .initialize(arg1, arg2)
  .accounts({
    user: wallet.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();

// With signers
const tx = await program.methods
  .updateData(newData)
  .accounts({ dataAccount: dataKey })
  .signers([signer])
  .rpc();
```

### Dart

```dart
// Basic method call
final tx = await program.methods
  .initialize(arg1, arg2)
  .accounts({
    'user': wallet.publicKey,
    'systemProgram': SystemProgram.programId,
  })
  .rpc();

// With signers
final tx = await program.methods
  .updateData(newData)
  .accounts({'dataAccount': dataKey})
  .signers([signer])
  .rpc();
```

**Key Differences:**

- Dart: Account names must be strings (quoted)
- Dart: Otherwise identical API

## Account Operations

### TypeScript

```typescript
// Fetch single account
const accountData = await program.account.myAccount.fetch(accountKey);

// Fetch multiple accounts
const accounts = await program.account.myAccount.all();

// Fetch with filters
const filtered = await program.account.myAccount.all([
  {
    memcmp: {
      offset: 8,
      bytes: someValue,
    },
  },
]);
```

### Dart

```dart
// Fetch single account
final accountData = await program.account.myAccount.fetch(accountKey);

// Fetch multiple accounts
final accounts = await program.account.myAccount.all();

// Fetch with filters
final filtered = await program.account.myAccount.all([
  MemcmpFilter(offset: 8, bytes: someValue),
]);
```

**Key Differences:**

- Dart: Filters use proper classes instead of anonymous objects
- Dart: Type-safe filter construction

## Event Handling

### TypeScript

```typescript
// Listen to specific event
program.addEventListener("MyEvent", (event, slot) => {
  console.log("Event received:", event);
});

// Remove listener
const listener = program.addEventListener("MyEvent", callback);
program.removeEventListener(listener);
```

### Dart

```dart
// Listen to specific event
program.addEventListener('MyEvent', (event, slot) {
  print('Event received: $event');
});

// Remove listener
final listener = program.addEventListener('MyEvent', callback);
program.removeEventListener(listener);
```

**Key Differences:**

- Dart: Event names must be strings (quoted)
- Dart: Use `print()` instead of `console.log()`

## Type Differences

### Primitive Types

| TypeScript | Dart              | Notes                         |
| ---------- | ----------------- | ----------------------------- |
| `string`   | `String`          | -                             |
| `number`   | `int` or `double` | Dart distinguishes int/double |
| `boolean`  | `bool`            | -                             |
| `Buffer`   | `Uint8List`       | Dart's byte array type        |
| `BN`       | `BigInt`          | Dart has native big integers  |

### PublicKey

### TypeScript

```typescript
import { PublicKey } from "@solana/web3.js";

const key = new PublicKey("base58string");
const keyFromBytes = new PublicKey(buffer);
```

### Dart

```dart
final key = PublicKey.fromBase58('base58string');
final keyFromBytes = PublicKey.fromBytes(bytes);
```

### Keypair

### TypeScript

```typescript
import { Keypair } from "@solana/web3.js";

const keypair = Keypair.generate();
const fromSecret = Keypair.fromSecretKey(secretKey);
```

### Dart

```dart
final keypair = Keypair.generate();
final fromSecret = Keypair.fromSecretKey(secretKey);
```

## Error Handling

### TypeScript

```typescript
try {
  const tx = await program.methods.myMethod().rpc();
} catch (error) {
  if (error instanceof AnchorError) {
    console.log("Anchor error:", error.error.errorCode.code);
  }
}
```

### Dart

```dart
try {
  final tx = await program.methods.myMethod().rpc();
} catch (error) {
  if (error is AnchorException) {
    print('Anchor error: ${error.code}');
  }
}
```

**Key Differences:**

- Dart: Use `is` instead of `instanceof`
- Dart: Different error structure

## Advanced Patterns

### IDL Fetching

### TypeScript

```typescript
const program = await Program.at(programId, provider);
```

### Dart

```dart
final program = await Program.at(programIdString, provider: provider);
```

### Custom Instruction Building

### TypeScript

```typescript
// Build instruction
const ix = await program.methods
  .myMethod()
  .accounts({...})
  .instruction();

// Build transaction
const tx = await program.methods
  .myMethod()
  .accounts({...})
  .transaction();
```

### Dart

```dart
// Build instruction
final ix = await program.methods
  .myMethod()
  .accounts({...})
  .instruction();

// Build transaction
final tx = await program.methods
  .myMethod()
  .accounts({...})
  .transaction();
```

### Simulation

### TypeScript

```typescript
const simulation = await program.methods
  .myMethod()
  .accounts({...})
  .simulate();
```

### Dart

```dart
final simulation = await program.methods
  .myMethod()
  .accounts({...})
  .simulate();
```

## Language-Specific Considerations

### Async/Await

Both languages use `async`/`await`, but Dart's implementation is more consistent:

### TypeScript

```typescript
// May need .then() in some contexts
const result = await someAsyncOperation();
```

### Dart

```dart
// Consistent async/await everywhere
final result = await someAsyncOperation();
```

### Null Safety

Dart has built-in null safety:

### TypeScript

```typescript
// Optional with TypeScript config
const value: string | null = getValue();
if (value !== null) {
  console.log(value.length);
}
```

### Dart

```dart
// Built-in null safety
final String? value = getValue();
if (value != null) {
  print(value.length); // No null check needed here
}
```

### Generics

Both support generics, but syntax differs:

### TypeScript

```typescript
const program: Program<MyIDL> = new Program(idl, provider);
```

### Dart

```dart
final Program<MyIDL> program = Program(idl, provider: provider);
```

## Common Migration Issues

### 1. String vs Object Keys

**TypeScript:** Accepts both string and object property access

```typescript
program.methods.initialize; // OK
program.methods["initialize"]; // OK
```

**Dart:** Only method access

```dart
program.methods.initialize // OK
// program.methods['initialize'] // Not available
```

### 2. Account Name Casing

**TypeScript:** Usually camelCase

```typescript
.accounts({
  userAccount: key,
  systemProgram: SystemProgram.programId,
})
```

**Dart:** Must match IDL exactly (often snake_case)

```dart
.accounts({
  'user_account': key,
  'system_program': SystemProgram.programId,
})
```

### 3. Buffer vs Uint8List

**TypeScript:**

```typescript
const data = Buffer.from([1, 2, 3]);
```

**Dart:**

```dart
final data = Uint8List.fromList([1, 2, 3]);
```

## Migration Checklist

- [ ] Update import statements
- [ ] Change account names to strings
- [ ] Update error handling patterns
- [ ] Replace Buffer with Uint8List
- [ ] Update PublicKey constructors
- [ ] Check async/await patterns
- [ ] Verify IDL loading
- [ ] Test event handling
- [ ] Update type annotations
- [ ] Check null safety

## Getting Help

- **Documentation:** [API Reference](link-to-docs)
- **Examples:** [GitHub Examples](link-to-examples)
- **Issues:** [GitHub Issues](link-to-issues)
- **Discord:** [Community Discord](link-to-discord)

## Performance Considerations

The Dart client is designed to be as performant as the TypeScript version:

- **Connection pooling:** Available for high-throughput applications
- **Caching:** IDL parsing and account sizes are cached
- **Serialization:** Efficient Borsh implementation
- **Memory:** Careful memory management for mobile applications

## Next Steps

1. Follow the [complete example](complete_example.dart) to see all features in action
2. Check out the [API reference](api-reference.md) for detailed documentation
3. Join the community for support and discussions
