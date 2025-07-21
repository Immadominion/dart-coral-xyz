# 🌊 Coral XYZ Anchor Examples

This directory contains comprehensive examples demonstrating how to use the Dart Coral XYZ Anchor client library. Each example is self-contained and shows different aspects of Anchor program interaction.

## 📚 Available Examples

### 🔰 Basic Examples

#### `basic_usage.dart`

**Comprehensive feature overview** - Demonstrates the essential components and workflows for interacting with Anchor programs.

- Connection setup and management
- Wallet and keypair handling
- Provider configuration
- IDL loading and parsing
- Program instance creation
- Core utility functions

Run with: `dart basic_usage.dart`

#### `counter_basic.dart`

**TypeScript tutorial equivalent** - Mirrors the "basic-1" tutorial from TypeScript Anchor documentation.

- IDL loading and parsing
- Connection and provider setup
- Account generation
- Transaction building patterns
- TypeScript compatibility patterns

Run with: `dart counter_basic.dart`

#### `program_interaction.dart`

**Production patterns** - Shows how to interact with deployed Anchor programs in real applications.

- RPC calls and account fetching
- PDA (Program Derived Address) generation
- Error handling for network operations
- Account lookup patterns
- IDL structure inspection

Run with: `dart program_interaction.dart`

- Full program interaction lifecycle
- Advanced IDL structures
- Complex transaction building
- Account management patterns
- Error handling strategies
- Performance considerations

**Run with:**

### 🚀 Advanced Examples

#### `complete_example.dart`

**Full workflow demonstration** - Complete end-to-end example showing advanced Anchor workflows.

- Sample counter program interaction
- Transaction building and execution
- Account data fetching and parsing
- Event handling and subscription
- Error handling patterns
- Multiple transaction patterns

Run with: `dart complete_example.dart`

#### `event_system_example.dart`

**Event handling patterns** - Demonstrates the Anchor event system implementation.

- Event listening and subscription
- Event filtering by type and criteria
- Event callback handling
- Transaction log parsing
- Real-time event monitoring

Run with: `dart event_system_example.dart`

## 🎯 TypeScript Anchor Parity

These examples are designed to provide equivalent functionality to the TypeScript `@coral-xyz/anchor` package:

| TypeScript Pattern                | Dart Equivalent                   | Example File                |
| --------------------------------- | --------------------------------- | --------------------------- |
| `anchor.workspace.Counter`        | `Program(idl, provider)`          | `counter_basic.dart`        |
| `program.methods.initialize()`    | `program.methods.initialize()`    | `complete_example.dart`     |
| `program.account.counter.fetch()` | `program.account.counter.fetch()` | `program_interaction.dart`  |
| Event listeners                   | Event system implementation       | `event_system_example.dart` |

## 🛠 Prerequisites

Before running these examples, ensure you have:

1. **Dart SDK** (>= 3.0.0)
2. **coral_xyz_anchor** package added to your project
3. **Network connectivity** for RPC calls (examples use devnet)
   ```

   ```

## Common Usage Patterns

### Basic Setup Pattern

## 📦 Adding to Your Project

Add the Coral XYZ Anchor package to your `pubspec.yaml`:

```yaml
dependencies:
  coral_xyz_anchor: ^1.0.0
```

## 🔧 Running Examples

```bash
# Run any example
dart example/basic_usage.dart
dart example/counter_basic.dart
dart example/program_interaction.dart

# Or with specific Dart SDK
/path/to/dart example/basic_usage.dart
```

## 🚦 Example Status

All examples are designed to run without requiring a local Solana validator:

- ✅ **Compile and run successfully**
- ✅ **Demonstrate core concepts**
- ✅ **Show error handling patterns**
- ✅ **Include TypeScript equivalents**
- ✅ **Mock network calls gracefully**

## 🤝 Contributing

When adding new examples:

1. **Keep them focused** - Each example should demonstrate specific concepts
2. **Include extensive comments** - Explain every step for beginners
3. **Add TypeScript equivalents** - Show how it relates to TS Anchor
4. **Handle errors gracefully** - Don't assume network connectivity
5. **Stay under 200 lines** - Keep examples concise and readable

## 📖 Additional Resources

- [Anchor Framework Documentation](https://www.anchor-lang.com/)
- [Solana Developer Documentation](https://docs.solana.com/developers)
- [TypeScript Anchor Package](https://github.com/coral-xyz/anchor)
- [Coral XYZ Anchor Dart API Reference](https://pub.dev/documentation/coral_xyz_anchor/latest/)

---

Happy coding with Anchor and Dart! �
