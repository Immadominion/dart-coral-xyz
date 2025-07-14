/// Method Interface Generator for automatic type-safe method creation from IDL
///
/// This module generates type-safe method interfaces from IDL definitions,
/// enabling TypeScript-like method access patterns with full compile-time
/// type checking and IDE support.

library;

import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/coder/main_coder.dart';
import 'package:coral_xyz_anchor/src/program/namespace/account_namespace.dart';
import 'package:coral_xyz_anchor/src/program/namespace/instruction_namespace.dart';
import 'package:coral_xyz_anchor/src/program/namespace/transaction_namespace.dart';
import 'package:coral_xyz_anchor/src/program/namespace/rpc_namespace.dart';
import 'package:coral_xyz_anchor/src/program/namespace/simulate_namespace.dart';
import 'package:coral_xyz_anchor/src/program/type_safe_method_builder.dart';
import 'package:coral_xyz_anchor/src/program/method_validator.dart';

/// Generates type-safe method interfaces from IDL instructions
///
/// This class automatically creates method builders and validators for each
/// instruction in an IDL, providing TypeScript-like method access patterns.
class MethodInterfaceGenerator {

  MethodInterfaceGenerator({
    required Idl idl,
    required AnchorProvider provider,
    required PublicKey programId,
    required Coder coder,
    required InstructionNamespace instructionNamespace,
    required TransactionNamespace transactionNamespace,
    required RpcNamespace rpcNamespace,
    required SimulateNamespace simulateNamespace,
    required AccountNamespace accountNamespace,
  })  : _idl = idl,
        _provider = provider,
        _programId = programId,
        _coder = coder,
        _instructionNamespace = instructionNamespace,
        _transactionNamespace = transactionNamespace,
        _rpcNamespace = rpcNamespace,
        _simulateNamespace = simulateNamespace,
        _accountNamespace = accountNamespace;
  final Idl _idl;
  final AnchorProvider _provider;
  final PublicKey _programId;
  final Coder _coder;

  // Namespace dependencies
  final InstructionNamespace _instructionNamespace;
  final TransactionNamespace _transactionNamespace;
  final RpcNamespace _rpcNamespace;
  final SimulateNamespace _simulateNamespace;
  final AccountNamespace _accountNamespace;

  /// Generate all method interfaces for the IDL
  ///
  /// Creates a map of method names to their type-safe builders,
  /// enabling both dynamic access and type-safe method calls.
  Map<String, TypeSafeMethodBuilder> generateMethodInterfaces() {
    final interfaces = <String, TypeSafeMethodBuilder>{};

    for (final instruction in _idl.instructions) {
      interfaces[instruction.name] = _createMethodInterface(instruction);
    }

    return interfaces;
  }

  /// Create a type-safe method interface for a single instruction
  TypeSafeMethodBuilder _createMethodInterface(IdlInstruction instruction) {
    // Create method validator for this instruction
    final validator = MethodValidator(
      instruction: instruction,
      idlTypes: _idl.types ?? [],
    );

    return TypeSafeMethodBuilder(
      instruction: instruction,
      provider: _provider,
      programId: _programId,
      instructionNamespace: _instructionNamespace,
      transactionNamespace: _transactionNamespace,
      rpcNamespace: _rpcNamespace,
      simulateNamespace: _simulateNamespace,
      accountNamespace: _accountNamespace,
      coder: _coder,
      validator: validator,
    );
  }

  /// Generate method documentation from IDL instruction
  ///
  /// Extracts documentation from IDL comments and argument definitions
  /// to provide comprehensive method documentation for IDE integration.
  String generateMethodDocumentation(IdlInstruction instruction) {
    final buffer = StringBuffer();

    // Add method description from docs
    if (instruction.docs != null && instruction.docs!.isNotEmpty) {
      buffer.writeln('/// ${instruction.docs!.join('\n/// ')}');
    } else {
      buffer.writeln('/// Executes the ${instruction.name} instruction');
    }

    // Add separator
    buffer.writeln('///');

    // Add parameter documentation
    if (instruction.args.isNotEmpty) {
      buffer.writeln('/// ## Parameters');
      for (final arg in instruction.args) {
        buffer.writeln('/// - [${arg.name}] (${_formatTypeForDocs(arg.type)})');
        if (arg.docs != null && arg.docs!.isNotEmpty) {
          buffer.writeln('///   ${arg.docs!.join(' ')}');
        }
      }
      buffer.writeln('///');
    }

    // Add account requirements
    if (instruction.accounts.isNotEmpty) {
      buffer.writeln('/// ## Required Accounts');
      for (final account in instruction.accounts) {
        final flags = <String>[];
        // Add account flags if it's a single account (not a nested group)
        if (account is IdlInstructionAccount) {
          if (account.writable) flags.add('writable');
          if (account.signer) flags.add('signer');
          if (account.optional) flags.add('optional');
        }

        final flagsStr = flags.isNotEmpty ? ' (${flags.join(', ')})' : '';
        buffer.writeln('/// - ${account.name}$flagsStr');

        if (account.docs != null && account.docs!.isNotEmpty) {
          buffer.writeln('///   ${account.docs!.join(' ')}');
        }
      }
      buffer.writeln('///');
    }

    // Add return type information
    if (instruction.returns != null) {
      buffer.writeln('/// ## Returns');
      buffer.writeln('/// ${instruction.returns}');
      buffer.writeln('///');
    }

    // Add usage example
    buffer.writeln('/// ## Example');
    buffer.writeln('/// ```dart');
    if (instruction.args.isNotEmpty) {
      final argsList = instruction.args
          .map((arg) => _generateExampleValue(arg.type))
          .join(', ');
      buffer.writeln(
          '/// final result = await program.methods.${instruction.name}([$argsList])',);
    } else {
      buffer.writeln(
          '/// final result = await program.methods.${instruction.name}()',);
    }
    buffer.writeln('///     .accounts({...})');
    buffer.writeln('///     .rpc();');
    buffer.writeln('/// ```');

    return buffer.toString();
  }

  /// Format type for documentation display
  String _formatTypeForDocs(IdlType type) {
    switch (type.kind) {
      case 'bool':
        return 'bool';
      case 'u8':
      case 'i8':
      case 'u16':
      case 'i16':
      case 'u32':
      case 'i32':
        return 'int';
      case 'u64':
      case 'i64':
      case 'u128':
      case 'i128':
      case 'u256':
      case 'i256':
        return 'BigInt';
      case 'f32':
      case 'f64':
        return 'double';
      case 'string':
        return 'String';
      case 'pubkey':
        return 'PublicKey';
      case 'bytes':
        return 'Uint8List';
      case 'vec':
        return 'List<${_formatTypeForDocs(type.inner!)}>';
      case 'option':
        return '${_formatTypeForDocs(type.inner!)}?';
      case 'array':
        return 'List<${_formatTypeForDocs(type.inner!)}>';
      case 'defined':
        return type.defined ?? 'CustomType';
      default:
        return 'dynamic';
    }
  }

  /// Generate example value for documentation
  String _generateExampleValue(IdlType type) {
    switch (type.kind) {
      case 'bool':
        return 'true';
      case 'u8':
      case 'i8':
      case 'u16':
      case 'i16':
      case 'u32':
      case 'i32':
        return '42';
      case 'u64':
      case 'i64':
      case 'u128':
      case 'i128':
      case 'u256':
      case 'i256':
        return 'BigInt.from(1000000000)';
      case 'f32':
      case 'f64':
        return '3.14';
      case 'string':
        return '"example"';
      case 'pubkey':
        return 'PublicKey.fromBase58("11111111111111111111111111111112")';
      case 'bytes':
        return 'Uint8List.fromList([1, 2, 3])';
      case 'vec':
        return '[${_generateExampleValue(type.inner!)}]';
      case 'option':
        return _generateExampleValue(type.inner!);
      case 'array':
        return '[${_generateExampleValue(type.inner!)}]';
      case 'defined':
        return '{}';
      default:
        return 'null';
    }
  }

  /// Validate method interface generation
  ///
  /// Performs comprehensive validation to ensure generated method
  /// interfaces are correct and complete.
  ValidationResult validateMethodGeneration() {
    final errors = <String>[];
    final warnings = <String>[];

    // Check all instructions have valid names
    for (final instruction in _idl.instructions) {
      if (instruction.name.isEmpty) {
        errors.add('Instruction has empty name');
        continue;
      }

      // Validate instruction name follows Dart naming conventions
      if (!_isValidDartMethodName(instruction.name)) {
        warnings.add(
            'Instruction name "${instruction.name}" may not follow Dart naming conventions',);
      }

      // Validate arguments
      for (final arg in instruction.args) {
        if (arg.name.isEmpty) {
          errors.add(
              'Argument in instruction "${instruction.name}" has empty name',);
        }

        if (!_isValidDartParameterName(arg.name)) {
          warnings.add(
              'Argument name "${arg.name}" in "${instruction.name}" may not follow Dart naming conventions',);
        }
      }

      // Validate accounts
      for (final account in instruction.accounts) {
        if (account.name.isEmpty) {
          errors.add(
              'Account in instruction "${instruction.name}" has empty name',);
        }

        if (!_isValidDartParameterName(account.name)) {
          warnings.add(
              'Account name "${account.name}" in "${instruction.name}" may not follow Dart naming conventions',);
        }
      }
    }

    // Check for duplicate instruction names
    final instructionNames = _idl.instructions.map((i) => i.name).toList();
    final duplicates = <String>[];
    for (int i = 0; i < instructionNames.length; i++) {
      for (int j = i + 1; j < instructionNames.length; j++) {
        if (instructionNames[i] == instructionNames[j] &&
            !duplicates.contains(instructionNames[i])) {
          duplicates.add(instructionNames[i]);
        }
      }
    }

    for (final duplicate in duplicates) {
      errors.add('Duplicate instruction name: "$duplicate"');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Check if a string is a valid Dart method name
  bool _isValidDartMethodName(String name) {
    if (name.isEmpty) return false;

    // Check if starts with letter or underscore
    if (!RegExp('^[a-zA-Z_]').hasMatch(name)) return false;

    // Check if contains only valid characters
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) return false;

    // Check if it's not a Dart keyword
    const dartKeywords = {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield',
    };

    return !dartKeywords.contains(name);
  }

  /// Check if a string is a valid Dart parameter name
  bool _isValidDartParameterName(String name) {
    return _isValidDartMethodName(name); // Same rules apply
  }
}

/// Result of method interface validation
class ValidationResult {

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Validation Result: ${isValid ? 'VALID' : 'INVALID'}');

    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }

    return buffer.toString();
  }
}
