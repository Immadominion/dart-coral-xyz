# Coral XYZ Anchor - Dart Examples

This directory contains comprehensive examples demonstrating how to use the Coral XYZ Anchor Dart client library to interact with Anchor programs on the Solana blockchain.

## Examples Overview

### 1. Hello World Example (`hello_world_example.dart`)

The most basic introduction to using the Dart Anchor client. Perfect for getting started.

**What it demonstrates:**

- Connecting to a Solana cluster (devnet)
- Creating keypairs and wallets
- Setting up providers
- Loading IDL definitions
- Creating program instances
- Building transactions (without sending)
- API usage patterns

**Run with:**

```bash
dart run example/hello_world_example.dart
```

### 2. Basic Usage Example (`basic_usage.dart`)

A comprehensive walkthrough of the core Anchor client components and workflows.

**What it demonstrates:**

- Connection management for different networks
- Wallet and keypair operations
- Provider setup with custom options
- IDL handling and parsing
- Program creation and usage
- Utility functions and best practices

**Run with:**

```bash
dart run example/basic_usage.dart
```

### 3. Complete Example (`complete_example.dart`)

An extensive example showing advanced features and real-world usage patterns.

**What it demonstrates:**

- Full program interaction lifecycle
- Advanced IDL structures
- Complex transaction building
- Account management patterns
- Error handling strategies
- Performance considerations

**Run with:**

```bash
dart run example/complete_example.dart
```

### 4. Event System Example (`event_system_example.dart`)

Focused demonstration of the event listening and parsing capabilities.

**What it demonstrates:**

- Setting up event listeners
- Filtering events by type and criteria
- Parsing event data from transaction logs
- Different listener types and patterns
- Event callback handling

**Run with:**

```bash
dart run example/event_system_example.dart
```

### 5. Mobile Integration Example (`mobile_integration_example.dart`)

Mobile/Flutter-specific patterns and best practices for integrating Anchor in mobile apps.

**What it demonstrates:**

- Mobile-friendly async patterns
- State management with Anchor programs
- Error handling for mobile environments
- UI integration patterns
- Background processing considerations
- Resource management and cleanup

**Run with:**

```bash
dart run example/mobile_integration_example.dart
```

## Prerequisites

Before running the examples, make sure you have:

1. **Dart SDK** installed (version 3.0 or higher)
2. **Dependencies** installed:
   ```bash
   dart pub get
   ```

## Common Usage Patterns

### Basic Setup Pattern

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

// 1. Create connection
final connection = Connection('https://api.devnet.solana.com');

// 2. Create wallet
final keypair = await Keypair.generate();
final wallet = KeypairWallet(keypair);

// 3. Create provider
final provider = AnchorProvider(connection, wallet);

// 4. Load program from IDL
final idl = Idl.fromJson(idlJson);
final program = Program(idl, provider: provider);
```

### Method Calling Pattern

```dart
// Build and potentially send a transaction
final methodBuilder = program.methods['methodName'];
if (methodBuilder != null) {
  final transaction = methodBuilder
      .call([arg1, arg2])
      .accounts({
        'account1': address1,
        'account2': address2,
      })
      .transaction();

  // To actually send:
  // final signature = await provider.sendAndConfirm(transaction);
}
```

### Account Fetching Pattern

```dart
// Access account namespace
final accountClient = program.account['AccountType'];
if (accountClient != null) {
  // In real usage: final data = await accountClient.fetch(address);
}
```

## Development Notes

### Example Status

All examples are designed to be educational and demonstrate API usage patterns. They include:

- ✅ **Compile successfully** - All examples pass Dart analysis
- ✅ **Show best practices** - Demonstrate proper error handling, resource management
- ✅ **Educational value** - Clear comments and step-by-step explanations
- ⚠️ **Mock interactions** - Some examples use simulated data since they don't connect to real deployed programs

### Network Configuration

Examples use different networks for demonstration:

- **Devnet** (default): Safe for testing, includes faucets for funding
- **Testnet**: Alternative test environment
- **Mainnet**: Production network (use with caution)
- **Localhost**: For local Solana test validator

### Error Handling

All examples include comprehensive error handling demonstrating:

- Network connection errors
- Invalid transaction scenarios
- Account not found cases
- Insufficient funds scenarios
- Program interaction failures

## Extending the Examples

Feel free to modify these examples for your specific use cases:

1. **Replace IDL data** with your actual program IDL
2. **Update program IDs** to match your deployed programs
3. **Modify account structures** to match your program's accounts
4. **Add custom method calls** specific to your program
5. **Integrate with your wallet** instead of generating random keypairs

## Getting Help

If you encounter issues with the examples:

1. Check that all dependencies are installed: `dart pub get`
2. Verify your Dart SDK version: `dart --version`
3. Review the API reference documentation
4. Check the main library documentation in the parent directory

## Contributing

If you'd like to contribute additional examples:

1. Follow the existing naming convention
2. Include comprehensive comments and documentation
3. Add error handling and edge cases
4. Update this README with your new example
5. Ensure the example compiles and runs successfully

---

**Happy coding with Coral XYZ Anchor! 🌊**
