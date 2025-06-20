# Coral XYZ Anchor for Dart

A comprehensive Dart client for Anchor programs on Solana, bringing the power and ease of the TypeScript `@coral-xyz/anchor` package to the Dart ecosystem.

## 🚀 Features

- **Type-Safe**: Full type safety with Dart's null safety and strong typing system
- **IDL-Based**: Automatic generation of type-safe program interfaces from Anchor IDL files
- **Cross-Platform**: Works on mobile (Flutter), web, and desktop applications
- **Modern Async**: Built with Dart's excellent async/await support
- **Comprehensive**: Complete feature parity with the TypeScript implementation
- **Developer-Friendly**: Intuitive API design that feels natural to Dart developers

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  coral_xyz_anchor: ^0.1.0
```

Then run:

```bash
dart pub get
```

## 🎯 Quick Start

```dart
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() async {
  // Create a connection to Solana
  final connection = Connection('https://api.devnet.solana.com');

  // Set up your wallet (replace with your actual wallet)
  final wallet = Keypair.fromSecretKey([/* your secret key */]);

  // Create a provider
  final provider = AnchorProvider(connection, wallet);

  // Load your program IDL
  final idl = await Idl.fetchFromAddress(programId, provider);

  // Create a program instance
  final program = Program(idl, programId, provider);

  // Call a program method
  final result = await program.methods
    .initialize()
    .accounts({
      'user': wallet.publicKey,
      'systemProgram': SystemProgram.programId,
    })
    .rpc();

  print('Transaction signature: $result');
}
```

## 📚 Documentation

### Core Concepts

#### Provider

The provider manages your connection to the Solana cluster and wallet:

```dart
final connection = Connection('https://api.mainnet-beta.solana.com');
final provider = AnchorProvider(connection, wallet);
```

#### Program

Load and interact with Anchor programs:

```dart
final program = Program(idl, programId, provider);

// Method calls
await program.methods.myInstruction(arg1, arg2).rpc();

// Account fetching
final account = await program.account.myAccount.fetch(accountAddress);

// Event listening
program.addEventListener('MyEvent', (event, slot) {
  print('Event: ${event.data}');
});
```

#### IDL Management

Work with Interface Definition Language files:

```dart
// Load from JSON
final idl = Idl.fromJson(idlJson);

// Fetch from on-chain
final idl = await Idl.fetchFromAddress(programId, provider);

// Validate IDL
final isValid = idl.validate();
```

### Advanced Usage

#### Custom Account Resolution

```dart
final result = await program.methods
  .complexInstruction()
  .accountsResolver((accounts) {
    return {
      ...accounts,
      'derivedAccount': await PublicKey.findProgramAddress([seed], programId),
    };
  })
  .rpc();
```

#### Transaction Building

```dart
final transaction = await program.methods
  .myInstruction()
  .accounts(accounts)
  .transaction();

// Add additional instructions
transaction.add(otherInstruction);

// Send manually
final signature = await provider.sendAndConfirm(transaction);
```

#### Batch Operations

```dart
final signatures = await provider.sendAll([
  {
    'tx': await program.methods.instruction1().transaction(),
    'signers': [keypair1],
  },
  {
    'tx': await program.methods.instruction2().transaction(),
    'signers': [keypair2],
  },
]);
```

## 🏗️ Development Status

This project is currently under active development. See our [roadmap](roadmap.md) for detailed progress and upcoming features.

### Current Phase: Foundation & Core Infrastructure ⏳

- \[x\] Project setup and structure
- \[ \] Core dependencies integration
- \[ \] Basic type definitions
- \[ \] IDL system foundation

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Install dependencies: `dart pub get`
3. Run tests: `dart test`
4. Run linting: `dart analyze`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Coral XYZ](https://github.com/coral-xyz) for the original TypeScript implementation
- [Solana Foundation](https://solana.com/) for the Solana blockchain
- The Dart and Flutter communities for their excellent tooling

## 🔗 Links

- [TypeScript Anchor Client](https://github.com/coral-xyz/anchor)
- [Anchor Framework Documentation](https://anchor-lang.com/)
- [Solana Documentation](https://docs.solana.com/)
- [Dart Language](https://dart.dev/)
- [Flutter Framework](https://flutter.dev/)
