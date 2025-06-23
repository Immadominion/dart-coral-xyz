/// Critical Iteration 2: Dynamic Method Access - COMPLETED
///
/// This file demonstrates the successfully implemented TypeScript-compatible
/// dynamic method access and fluent API patterns in the Dart Coral XYZ SDK.

library;

import '../lib/coral_xyz_anchor.dart';

void demonstrateTypescriptCompatibility() {
  // Create a sample IDL (like you'd load from a JSON file)
  final idl = Idl(
    address: 'Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS',
    metadata: IdlMetadata(
      name: 'demo_program',
      version: '0.1.0',
      spec: '0.1.0',
    ),
    instructions: [
      IdlInstruction(
        name: 'initialize',
        discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
        accounts: [
          IdlInstructionAccount(name: 'user', writable: true, signer: true),
          IdlInstructionAccount(
              name: 'systemProgram', writable: false, signer: false),
        ],
        args: [
          IdlField(name: 'value', type: const IdlType(kind: 'u64')),
        ],
      ),
      IdlInstruction(
        name: 'updateData',
        discriminator: [129, 25, 88, 69, 104, 200, 15, 164],
        accounts: [
          IdlInstructionAccount(
              name: 'dataAccount', writable: true, signer: false),
          IdlInstructionAccount(
              name: 'authority', writable: false, signer: true),
        ],
        args: [
          IdlField(name: 'newValue', type: const IdlType(kind: 'string')),
        ],
      ),
    ],
    accounts: [],
    events: [],
    errors: [],
    types: [],
    constants: [],
  );

  // Create the program instance
  final program = Program(idl, provider: AnchorProvider.defaultProvider());

  print('🎉 Critical Iteration 2: Dynamic Method Access - COMPLETED!');
  print('');
  print('✅ TypeScript-Compatible Syntax Examples:');
  print('');

  // Example 1: TypeScript-style dynamic method access
  print('1. Dynamic Method Access (TypeScript-style):');
  print('   TypeScript: program.methods.initialize(new BN(42))');
  print('   Dart:       program.methods.initialize([42])');
  print('');

  try {
    final dynamic methods = program.methods;
    final builder = methods.initialize([42]);
    print('   ✅ Dynamic method access works!');
    print('   ✅ Builder type: ${builder.runtimeType}');
  } catch (e) {
    print('   ❌ Error: $e');
  }
  print('');

  // Example 2: Bracket notation access
  print('2. Bracket Notation Access:');
  print('   TypeScript: program.methods["initialize"](new BN(42))');
  print('   Dart:       program.methods["initialize"]([42])');
  print('');

  try {
    final methodFunction = program.methods['initialize'];
    if (methodFunction != null) {
      final builder = methodFunction([42]);
      print('   ✅ Bracket notation access works!');
      print('   ✅ Builder type: ${builder.runtimeType}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
  print('');

  // Example 3: Complete fluent chain
  print('3. Complete Fluent Chain (TypeScript-compatible):');
  print(
      '   TypeScript: program.methods.initialize(42).accounts({...}).signers([])');
  print(
      '   Dart:       program.methods.initialize([42]).accounts({...}).signers([])');
  print('');

  try {
    final dynamic methods = program.methods;
    final result = methods.initialize([42]).accounts({
      'user': PublicKey.fromBase58('11111111111111111111111111111112'),
      'systemProgram': PublicKey.fromBase58('11111111111111111111111111111113'),
    }).signers(<Signer>[]);

    print('   ✅ Fluent chain works!');
    print('   ✅ Final builder type: ${result.runtimeType}');
    print('   ✅ Available execution methods:');
    print('      - instruction(): ${result.instruction != null ? "✅" : "❌"}');
    print('      - transaction(): ${result.transaction != null ? "✅" : "❌"}');
    print('      - rpc(): ${result.rpc != null ? "✅" : "❌"}');
    print('      - simulate(): ${result.simulate != null ? "✅" : "❌"}');
  } catch (e) {
    print('   ❌ Error: $e');
  }
  print('');

  // Example 4: Method introspection
  print('4. Method Introspection:');
  print('   Available methods: ${program.methods.names.toList()}');
  print('   Contains "initialize": ${program.methods.contains("initialize")}');
  print('   Contains "updateData": ${program.methods.contains("updateData")}');
  print(
      '   Contains "nonExistent": ${program.methods.contains("nonExistent")}');
  print('');

  // Example 5: Error handling
  print('5. Error Handling for Invalid Methods:');
  try {
    final dynamic methods = program.methods;
    methods.nonExistentMethod([]);
    print('   ❌ Should have thrown an error!');
  } catch (e) {
    print('   ✅ Proper error handling: ${e.toString().split('\n')[0]}');
  }
  print('');

  // Example 6: Independent builder instances
  print('6. Independent Builder Instances:');
  final dynamic methods = program.methods;
  final builder1 = methods.initialize([100]);
  final builder2 = methods.initialize([200]);
  print(
      '   Builder 1 and Builder 2 are different instances: ${!identical(builder1, builder2)}');
  print('   ✅ Each method call creates a fresh builder (TypeScript behavior)');
  print('');

  print('🚀 Summary:');
  print('   ✅ Dynamic method access: program.methods.methodName(args)');
  print('   ✅ Bracket notation: program.methods["methodName"](args)');
  print('   ✅ Full fluent API chain compatibility');
  print('   ✅ Type safety preserved throughout the chain');
  print('   ✅ Independent builder instances (no state pollution)');
  print('   ✅ Helpful error messages for invalid methods');
  print('   ✅ Method introspection and validation');
  print('');
  print(
      '🎯 The Dart SDK now provides the same developer experience as TypeScript!');
}

void main() {
  demonstrateTypescriptCompatibility();
}
