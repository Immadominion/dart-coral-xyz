# 🌊 Coral XYZ Anchor for Dart

[![pub package](https://img.shields.io/pub/v/coral_xyz_anchor.svg)](https://pub.dev/packages/coral_xyz_anchor)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Dart client for Anchor programs on Solana, bringing the power and ease of the TypeScript `@coral-xyz/anchor` package to the Dart ecosystem.

## ⚡ Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  coral_xyz_anchor: ^1.0.0
```

Simple counter example:

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() async {
  // Connect to Solana devnet
  final connection = Connection('https://api.devnet.solana.com');

  // Set up your wallet
  final wallet = Keypair.fromSecretKey(yourSecretKey);
  final provider = AnchorProvider(connection, wallet);

  // Load your program
  final program = Program(idl, programId, provider);

  // Initialize counter
  await program.methods
    .initialize()
    .accounts({'counter': counterKeypair.publicKey})
    .signers([counterKeypair])
    .rpc();

  // Increment counter
  await program.methods
    .increment()
    .accounts({'counter': counterKeypair.publicKey})
    .rpc();

  // Fetch counter value
  final account = await program.account.counter.fetch(counterKeypair.publicKey);
  print('Counter value: ${account.count}');
}
```

## 🚀 Features

- **🔒 Type-Safe**: Full type safety with Dart's null safety and strong typing system
- **📋 IDL-Based**: Automatic generation of type-safe program interfaces from Anchor IDL files
- **🌐 Cross-Platform**: Works on mobile (Flutter), web, and desktop applications
- **⚡ Modern Async**: Built with Dart's excellent async/await support
- **🎯 TypeScript Parity**: Feature-complete implementation matching `@coral-xyz/anchor`
- **👨‍💻 Developer-Friendly**: Intuitive API design that feels natural to Dart developers
- **📊 Event System**: Comprehensive event listening and parsing capabilities
- **🔧 Extensible**: Built-in support for custom coders and advanced use cases

## 📚 Documentation

### Core Concepts

#### 🔌 Provider

The provider manages your connection to the Solana cluster and wallet:

```dart
// Connect to different networks
final devnetConnection = Connection('https://api.devnet.solana.com');
final mainnetConnection = Connection('https://api.mainnet-beta.solana.com');

// Create provider with wallet
final provider = AnchorProvider(connection, wallet, AnchorProviderOptions(
  commitment: Commitment.confirmed,
  preflightCommitment: Commitment.confirmed,
));
```

#### 📝 Program

Load and interact with Anchor programs:

```dart
// Load program from IDL
final program = Program(idl, programId, provider);

// Call program methods
final signature = await program.methods
  .myInstruction(arg1, arg2)
  .accounts({
    'account1': publicKey1,
    'account2': publicKey2,
  })
  .signers([additionalSigner])
  .rpc();

// Fetch account data
final accountData = await program.account.myAccount.fetch(accountAddress);

// Listen to program events
program.addEventListener('MyEvent', (event, slot, signature) {
  print('Event received: ${event.data}');
});
```

#### 📄 IDL Management

Work with Interface Definition Language files:

```dart
// Load from JSON
final idl = Idl.fromJson(idlJsonString);

// Fetch from on-chain
final idl = await Idl.fetchFromAddress(programId, provider);

// Validate IDL structure
final validationResult = IdlUtils.validateIdl(idl);
if (validationResult.hasErrors) {
  print('IDL validation errors: ${validationResult.errors}');
}
```

### 🏗️ Advanced Usage

#### 🔗 Custom Account Resolution

```dart
final result = await program.methods
  .complexInstruction()
  .accountsResolver((accounts) async {
    // Derive PDAs dynamically
    final (derivedAccount, bump) = await PublicKey.findProgramAddress(
      [utf8.encode('seed'), userPublicKey.toBytes()],
      programId
    );

    return {
      ...accounts,
      'derivedAccount': derivedAccount,
    };
  })
  .rpc();
```

#### 🔨 Transaction Building

```dart
// Build transaction manually
final transaction = await program.methods
  .myInstruction()
  .accounts(accounts)
  .transaction();

// Add additional instructions
transaction.add(SystemProgram.transfer(
  fromPubkey: wallet.publicKey,
  toPubkey: recipient,
  lamports: amount,
));

// Send with custom options
final signature = await provider.sendAndConfirm(
  transaction,
  signers: [wallet],
  options: ConfirmOptions(commitment: Commitment.finalized),
);
```

#### 📦 Batch Operations

```dart
// Send multiple transactions in parallel
final signatures = await provider.sendAll([
  SendTxRequest(
    tx: await program.methods.instruction1().transaction(),
    signers: [keypair1],
  ),
  SendTxRequest(
    tx: await program.methods.instruction2().transaction(),
    signers: [keypair2],
  ),
]);
```

#### 🎯 Event Filtering and Aggregation

```dart
// Advanced event filtering
program.addEventListener('Transfer', (event, slot, signature) {
  final transfer = event.data as TransferEvent;
  if (transfer.amount > 1000000) { // Only large transfers
    print('Large transfer detected: ${transfer.amount} lamports');
  }
});

// Event aggregation
final eventStats = await program.getEventStatistics(
  eventName: 'Transfer',
  startSlot: startSlot,
  endSlot: endSlot,
);
```

## 🔄 TypeScript Anchor Compatibility

This package provides 1:1 feature parity with the TypeScript `@coral-xyz/anchor` package:

| TypeScript Feature         | Dart Equivalent            | Status      |
| -------------------------- | -------------------------- | ----------- |
| `Program.methods`          | `program.methods`          | ✅ Complete |
| `Program.account`          | `program.account`          | ✅ Complete |
| `Program.instruction`      | `program.instruction`      | ✅ Complete |
| `Program.transaction`      | `program.transaction`      | ✅ Complete |
| `Program.rpc`              | `program.rpc`              | ✅ Complete |
| `Program.simulate`         | `program.simulate`         | ✅ Complete |
| `Program.addEventListener` | `program.addEventListener` | ✅ Complete |
| `AnchorProvider`           | `AnchorProvider`           | ✅ Complete |
| `Wallet` interface         | `Wallet` interface         | ✅ Complete |
| `IDL` types                | `Idl` classes              | ✅ Complete |
| `BorshCoder`               | `BorshCoder`               | ✅ Complete |
| `AccountsCoder`            | `AccountsCoder`            | ✅ Complete |
| `EventParser`              | `EventParser`              | ✅ Complete |

## 📱 Flutter Integration

Perfect for mobile dApps:

```dart
// Flutter example
class SolanaCounterApp extends StatefulWidget {
  @override
  _SolanaCounterAppState createState() => _SolanaCounterAppState();
}

class _SolanaCounterAppState extends State<SolanaCounterApp> {
  late Program counterProgram;
  int currentCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeProgram();
  }

  Future<void> _initializeProgram() async {
    final connection = Connection('https://api.devnet.solana.com');
    final provider = AnchorProvider(connection, wallet);
    counterProgram = Program(counterIdl, counterProgramId, provider);

    // Listen for counter updates
    counterProgram.addEventListener('CounterUpdated', (event, slot, signature) {
      setState(() {
        currentCount = event.data.newValue;
      });
    });
  }

  Future<void> _incrementCounter() async {
    await counterProgram.methods
      .increment()
      .accounts({'counter': counterAddress})
      .rpc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solana Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Counter: $currentCount', style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🏗️ Examples

Explore comprehensive examples in the [`example/`](example/) directory:

- **[`basic_usage.dart`](example/basic_usage.dart)** - Core functionality demonstration
- **[`counter_basic.dart`](example/counter_basic.dart)** - Simple counter program (TypeScript basic-1 equivalent)
- **[`program_interaction.dart`](example/program_interaction.dart)** - Production interaction patterns
- **[`event_system_example.dart`](example/event_system_example.dart)** - Event listening and parsing
- **[`complete_example.dart`](example/complete_example.dart)** - Advanced workflows and error handling

See the [example README](example/README.md) for detailed explanations and run instructions.

## 🧪 Testing

This package includes comprehensive test coverage:

```bash
# Run all tests
dart test

# Run specific test categories
dart test test/idl_test.dart          # IDL parsing and validation
dart test test/program_test.dart      # Program interaction
dart test test/event_test.dart        # Event system
dart test test/integration_test.dart  # Integration tests
```

All tests use mocks and do not require a local Solana validator.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/coral-xyz/dart-coral-xyz.git
   cd dart-coral-xyz
   ```

2. Install dependencies:

   ```bash
   dart pub get
   ```

3. Run tests:

   ```bash
   dart test
   ```

4. Run analysis:
   ```bash
   dart analyze
   dart format --set-exit-if-changed .
   ```

### Code Standards

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Maintain 100% test coverage for new features
- Add comprehensive dartdoc comments for public APIs
- Ensure all changes pass CI checks

## 📊 Performance

Optimized for production use:

- **Memory Efficient**: Minimal memory footprint with efficient object pooling
- **Network Optimized**: Intelligent batching and caching of RPC calls
- **Type Safe**: Zero runtime type errors with compile-time guarantees
- **Async First**: Non-blocking operations with proper error handling

## 🔐 Security

Security best practices built-in:

- **Secure by Default**: Safe defaults for all operations
- **Input Validation**: Comprehensive validation of all inputs
- **Error Handling**: Graceful handling of network and program errors
- **Audit Trail**: Comprehensive logging for debugging and monitoring

## 📋 Roadmap

- [x] **Phase 1**: Core IDL and program infrastructure
- [x] **Phase 2**: Borsh serialization and type system
- [x] **Phase 3**: Provider and connection management
- [x] **Phase 4**: Namespace generation and method builders
- [x] **Phase 5**: Event system and parsing
- [x] **Phase 6**: Advanced features and optimizations
- [ ] **Phase 7**: Flutter-specific optimizations
- [ ] **Phase 8**: Advanced CPI and large transaction support
- [ ] **Phase 9**: Performance monitoring and analytics

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Coral XYZ](https://github.com/coral-xyz) for the original TypeScript implementation
- [Solana Foundation](https://solana.com/) for the Solana blockchain
- The Dart and Flutter communities for their excellent tooling
- All contributors who have helped improve this package

## 🔗 Links

- [📖 API Documentation](https://pub.dev/documentation/coral_xyz_anchor/latest/)
- [🌐 Anchor Framework](https://www.anchor-lang.com/)
- [⚡ Solana Documentation](https://docs.solana.com/)
- [🎯 TypeScript Anchor Client](https://github.com/coral-xyz/anchor)
- [📱 Flutter Framework](https://flutter.dev/)
- [💻 Dart Language](https://dart.dev/)

---

<div align="center">

**Built with ❤️ for the Solana ecosystem**

[⭐ Star us on GitHub](https://github.com/coral-xyz/dart-coral-xyz) | [🐛 Report Issues](https://github.com/coral-xyz/dart-coral-xyz/issues) | [💬 Join Discord](https://discord.gg/anchor)

</div>
