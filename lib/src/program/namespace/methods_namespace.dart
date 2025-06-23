import '../../types/public_key.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart' hide SimulationResult;
import 'account_namespace.dart';
import 'instruction_namespace.dart';
import 'rpc_namespace.dart';
import 'simulate_namespace.dart';
import 'transaction_namespace.dart';
import '../method_interface_generator.dart';
import '../type_safe_method_builder.dart';
import '../method_validator.dart';

/// The methods namespace provides a fluent interface for building and executing
/// program methods with type-safe parameters.
///
/// ## Usage (TypeScript-compatible dynamic method access)
///
/// ```dart
/// // Dynamic method access (like TypeScript)
/// final result = await program.methods.initialize(args)
///     .accounts({...})
///     .signers([...])
///     .rpc();
///
/// // Alternative bracket access (for when method names conflict with Dart keywords)
/// final result = await program.methods['methodName'](args)
///     .accounts({...})
///     .signers([...])
///     .rpc();
/// ```
class MethodsNamespace {
  final Map<String, TypeSafeMethodBuilder> _builders = {};
  final MethodInterfaceGenerator _generator;

  MethodsNamespace._(this._generator);

  /// Build methods namespace from IDL
  static MethodsNamespace build({
    required Idl idl,
    required AnchorProvider provider,
    required PublicKey programId,
    required InstructionNamespace instructionNamespace,
    required TransactionNamespace transactionNamespace,
    required RpcNamespace rpcNamespace,
    required SimulateNamespace simulateNamespace,
    required AccountNamespace accountNamespace,
    required Coder coder,
  }) {
    final generator = MethodInterfaceGenerator(
      idl: idl,
      provider: provider,
      programId: programId,
      coder: coder,
      instructionNamespace: instructionNamespace,
      transactionNamespace: transactionNamespace,
      rpcNamespace: rpcNamespace,
      simulateNamespace: simulateNamespace,
      accountNamespace: accountNamespace,
    );
    final namespace = MethodsNamespace._(generator);

    // Create type-safe method builders for each IDL instruction
    for (final instruction in idl.instructions) {
      final validator = MethodValidator(
        instruction: instruction,
        idlTypes: idl.types ?? [],
      );
      namespace._builders[instruction.name] = TypeSafeMethodBuilder(
        instruction: instruction,
        provider: provider,
        programId: programId,
        instructionNamespace: instructionNamespace,
        transactionNamespace: transactionNamespace,
        rpcNamespace: rpcNamespace,
        simulateNamespace: simulateNamespace,
        accountNamespace: accountNamespace,
        coder: coder,
        validator: validator,
      );
    }

    return namespace;
  }

  /// Get a method builder by name (bracket notation access)
  ///
  /// Returns a function that accepts arguments and returns a configured TypeSafeMethodBuilder.
  /// This enables both bracket access patterns:
  ///
  /// ```dart
  /// // Direct access to builder (for advanced use cases)
  /// final builder = program.methods.getBuilder('methodName');
  ///
  /// // Function call with arguments (preferred)
  /// final result = await program.methods['methodName'](args)
  ///     .accounts({...})
  ///     .rpc();
  /// ```
  TypeSafeMethodBuilder Function(List<dynamic>)? operator [](String name) {
    final builder = _builders[name];
    if (builder == null) return null;

    // Return a function that accepts arguments and returns the configured builder
    return (List<dynamic> args) => builder.withArgs(args);
  }

  /// Get a method builder directly by name (for advanced use cases)
  ///
  /// Most of the time you should use the bracket notation or dynamic method access instead:
  /// - `program.methods.methodName(args)` (TypeScript-like)
  /// - `program.methods['methodName'](args)` (bracket notation)
  ///
  /// This method is provided for advanced scenarios where you need direct access to the builder.
  TypeSafeMethodBuilder? getBuilder(String name) => _builders[name];

  /// Get all method names
  Iterable<String> get names => _builders.keys;

  /// Check if a method exists
  bool contains(String name) => _builders.containsKey(name);

  /// Get the method interface generator
  MethodInterfaceGenerator get generator => _generator;

  /// Dynamic method access (TypeScript-compatible)
  ///
  /// This method enables TypeScript-like syntax: `program.methods.initialize(args)`
  /// by intercepting property access and method calls on undefined properties.
  ///
  /// When you call `program.methods.methodName(args)`, Dart will:
  /// 1. Look for a property named `methodName` (which doesn't exist)
  /// 2. Call this `noSuchMethod` with the invocation details
  /// 3. Extract the method name and arguments
  /// 4. Return the appropriate TypeSafeMethodBuilder configured with those arguments
  ///
  /// This creates the same developer experience as TypeScript:
  /// ```dart
  /// // Both of these work the same way:
  /// program.methods.initialize(42)       // Dynamic access (like TypeScript)
  /// program.methods['initialize'](42)    // Bracket access (traditional Dart)
  /// ```
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Only handle method calls (not property getters/setters)
    if (!invocation.isMethod) {
      return super.noSuchMethod(invocation);
    }

    // Extract the method name from the invocation
    final methodName = invocation.memberName.toString();

    // Remove the 'Symbol("' prefix and '")' suffix that Dart adds
    final cleanMethodName =
        methodName.startsWith('Symbol("') && methodName.endsWith('")')
            ? methodName.substring(8, methodName.length - 2)
            : methodName;

    // Check if we have a builder for this method
    final builder = _builders[cleanMethodName];
    if (builder == null) {
      // Method doesn't exist in IDL, throw a helpful error
      throw ArgumentError(
        'Method "$cleanMethodName" not found in program IDL. '
        'Available methods: ${_builders.keys.toList()}',
      );
    }

    // Extract the positional arguments from the invocation
    final args = invocation.positionalArguments;

    // Call the builder with the provided arguments and return it
    // This enables the fluent API: program.methods.methodName(args).accounts({}).rpc()
    // We use withArgs to create a new instance (like TypeScript) rather than modifying the existing one
    return builder.withArgs(args);
  }

  @override
  String toString() {
    return 'MethodsNamespace(methods: ${_builders.keys.toList()})';
  }
}
