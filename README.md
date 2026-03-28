# coral_xyz

[![pub package](https://img.shields.io/pub/v/coral_xyz.svg)](https://pub.dev/packages/coral_xyz)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Dart client for Solana programs. Supports [Anchor](https://www.anchor-lang.com/), [Quasar](https://github.com/coral-xyz/quasar), and [Pinocchio](https://github.com/febo/pinocchio) frameworks through runtime IDL parsing, Borsh serialization, zero-copy account decoding, and PDA derivation.

Built on [espresso-cash/solana](https://pub.dev/packages/solana) for RPC, cryptography, and transaction primitives.

## Installation

```yaml
dependencies:
  coral_xyz: ^1.0.0-beta.9
```

```bash
dart pub get
```

Requires Dart SDK `^3.9.0`.

## Quick start

```dart
import 'package:coral_xyz/coral_xyz.dart';

void main() async {
  // Load IDL (from JSON file, string, or on-chain fetch)
  final idl = Idl.fromJson(jsonDecode(idlString));

  // Set up provider
  final connection = Connection('https://api.devnet.solana.com');
  final wallet = NodeWallet(await Keypair.generate());
  final provider = AnchorProvider(connection, wallet);

  // Create program instance
  final program = Program(idl, programId, provider);

  // Call a program method
  await program.methods['initialize']!([])
    .accounts({'counter': counterAddress})
    .signers([counterKeypair])
    .rpc();

  // Fetch an account
  final data = await program.account['Counter']!.fetch(counterAddress);
}
```

## Features

- **Multi-framework support** — Parse and interact with Anchor, Quasar, and Pinocchio program IDLs through a single API
- **Borsh serialization** — Encode/decode instruction data and account state using the Borsh binary format
- **Zero-copy accounts** — Decode Quasar zero-copy account layouts with explicit discriminators
- **PDA derivation** — Derive program addresses from IDL-defined seeds (const, account, arg)
- **Type-safe builders** — Fluent method builders with `.accounts()`, `.signers()`, `.rpc()`, `.simulate()`, `.view()`
- **Event parsing** — Subscribe to and decode program events via `addEventListener`
- **Codama/manual interface** — Define program interfaces manually for non-IDL programs via `ProgramInterface.define()`
- **In-process testing** — Quasar-SVM FFI bindings for deterministic program execution without a validator

## Supported frameworks

| Framework | IDL parsing | Instruction encoding | Account decoding | PDA derivation | Local execution |
|-----------|:-----------:|:-------------------:|:----------------:|:--------------:|:---------------:|
| Anchor    | Yes         | Yes                 | Yes (Borsh)      | Yes            | —               |
| Quasar    | Yes         | Yes                 | Yes (zero-copy)  | Yes            | Yes (SVM FFI)   |
| Pinocchio | Yes (Codama/manual) | Yes           | Yes              | Yes            | —               |

## Usage

### Loading an IDL

```dart
// From JSON string
final idl = Idl.fromJson(jsonDecode(idlJsonString));

// Format is auto-detected (Anchor, Quasar, or Codama)
print(idl.metadata?.name);
print(idl.instructions.length);
```

### Program methods

```dart
// Access a method by name, pass instruction arguments
final builder = program.methods['deposit']!([BigInt.from(1000000)]);

// Set accounts and signers, then send
final signature = await builder
  .accounts({
    'vault': vaultAddress,
    'user': walletAddress,
    'systemProgram': SystemProgram.programId,
  })
  .signers([userKeypair])
  .rpc();
```

### Fetching accounts

```dart
// Fetch a single account
final counter = await program.account['Counter']!.fetch(counterAddress);
print(counter['count']); // decoded field

// Fetch all accounts of a type
final allCounters = await program.account['Counter']!.all();
```

### PDA derivation

```dart
final (address, bump) = await PublicKey.findProgramAddress(
  [utf8.encode('vault'), userPublicKey.toBytes()],
  programId,
);
```

### Simulating transactions

```dart
final result = await program.methods['transfer']!([amount])
  .accounts(accounts)
  .simulate();
```

### View functions

```dart
// Calls simulate and decodes the return value
final price = await program.methods['getPrice']!([])
  .accounts(accounts)
  .view();
```

### Events

```dart
final listenerId = program.addEventListener('Transfer', (event, slot, sig) {
  print('Transfer: ${event.data}');
});

// Later: remove listener
program.removeEventListener(listenerId);
```

### Manual program interface (Pinocchio/non-IDL)

```dart
final idl = ProgramInterface.define(
  programId: myProgramId,
  name: 'my_program',
)
  .addInstruction(
    name: 'deposit',
    discriminator: [0x01],
    args: [IdlField(name: 'amount', type: IdlType.fromJson('u64'))],
    accounts: [
      IdlInstructionAccount(name: 'vault', isMut: true, isSigner: false),
      IdlInstructionAccount(name: 'user', isMut: true, isSigner: true),
    ],
  )
  .build();
```

### Quasar-SVM local execution

```dart
import 'package:coral_xyz/coral_xyz.dart';

final svm = QuasarSvm();
svm.addProgram(programId, elfBytes);

final result = svm.processInstruction(
  programId: programId,
  accounts: [...],
  data: instructionData,
);
```

## Code generation (optional)

For static code generation from IDL files using `build_runner`, add the companion package:

```yaml
dev_dependencies:
  coral_xyz_codegen: ^1.0.0-beta.9
  build_runner: ^2.13.0
```

Then run:

```bash
dart run build_runner build
```

See [`coral_xyz_codegen`](https://pub.dev/packages/coral_xyz_codegen) for details.

## Examples

Full Flutter example apps are available at [coral-xyz-examples](https://github.com/Immadominion/coral-xyz-examples):

- **basic_counter** — Anchor counter program with Flutter UI
- **voting_app** — On-chain voting with real-time updates
- **todo_app** — CRUD operations with Anchor
- **quasar_vault** — Quasar vault deposit/withdraw
- **pinocchio_vault** — Pinocchio vault with manual interface

Standalone Dart examples are in the [`example/`](example/) directory.

## Testing

```bash
# Run all tests (excluding integration tests that need a validator)
dart test -x integration

# Run only verification tests
dart test test/verification/

# Run with a local validator for integration tests
solana-test-validator --reset &
dart test
```

730 non-integration tests, 34 integration tests, 293 verification tests across Anchor, Quasar, and Pinocchio.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

```bash
git clone https://github.com/Immadominion/dart-coral-xyz.git
cd dart-coral-xyz
dart pub get
dart test
dart analyze
```

## License

MIT. See [LICENSE](LICENSE).
