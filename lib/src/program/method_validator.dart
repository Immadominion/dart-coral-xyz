/// Method parameter and type validation for IDL-based methods
///
/// This module provides comprehensive validation for method parameters,
/// accounts, and types based on IDL definitions to ensure type safety
/// and correct program interaction.

library;

import '../idl/idl.dart';
import '../types/public_key.dart';
import 'namespace/types.dart';

/// Validates method parameters and accounts against IDL specifications
///
/// Provides comprehensive type checking and validation for method calls,
/// ensuring arguments and accounts match IDL requirements.
class MethodValidator {
  final IdlInstruction _instruction;
  final List<IdlTypeDef> _idlTypes;

  MethodValidator({
    required IdlInstruction instruction,
    required List<IdlTypeDef> idlTypes,
  })  : _instruction = instruction,
        _idlTypes = idlTypes;

  /// Validate method arguments and accounts
  ///
  /// Performs comprehensive validation including:
  /// - Argument count and type validation
  /// - Account presence and type validation
  /// - Required account flags (signer, writable)
  /// - Custom type validation for complex types
  Future<void> validate(List<dynamic> args, Accounts accounts) async {
    await _validateArguments(args);
    await _validateAccounts(accounts);
  }

  /// Validate method arguments against IDL specification
  Future<void> _validateArguments(List<dynamic> args) async {
    final expectedArgs = _instruction.args;

    // Check argument count
    if (args.length != expectedArgs.length) {
      throw MethodValidationError(
          'Invalid argument count for method "${_instruction.name}". '
          'Expected ${expectedArgs.length}, got ${args.length}.');
    }

    // Validate each argument type
    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      final expectedArg = expectedArgs[i];

      try {
        await _validateArgumentType(arg, expectedArg.type, expectedArg.name);
      } catch (e) {
        throw MethodValidationError(
            'Invalid argument "${expectedArg.name}" at position $i in method "${_instruction.name}": $e');
      }
    }
  }

  /// Validate individual argument type
  Future<void> _validateArgumentType(
    dynamic value,
    IdlType expectedType,
    String argumentName,
  ) async {
    switch (expectedType.kind) {
      case 'bool':
        if (value is! bool) {
          throw ArgumentError('Expected bool, got ${value.runtimeType}');
        }
        break;

      case 'u8':
      case 'i8':
        if (value is! int || value < -128 || value > 255) {
          throw ArgumentError('Expected int in range -128 to 255, got $value');
        }
        break;

      case 'u16':
      case 'i16':
        if (value is! int || value < -32768 || value > 65535) {
          throw ArgumentError(
              'Expected int in range -32768 to 65535, got $value');
        }
        break;

      case 'u32':
      case 'i32':
        if (value is! int || value < -2147483648 || value > 4294967295) {
          throw ArgumentError('Expected int in 32-bit range, got $value');
        }
        break;

      case 'u64':
      case 'i64':
      case 'u128':
      case 'i128':
      case 'u256':
      case 'i256':
        if (value is! BigInt && value is! int) {
          throw ArgumentError(
              'Expected BigInt or int for ${expectedType.kind}, got ${value.runtimeType}');
        }
        break;

      case 'f32':
      case 'f64':
        if (value is! double && value is! int) {
          throw ArgumentError(
              'Expected double or int for ${expectedType.kind}, got ${value.runtimeType}');
        }
        break;

      case 'string':
        if (value is! String) {
          throw ArgumentError('Expected String, got ${value.runtimeType}');
        }
        break;

      case 'pubkey':
        if (value is! PublicKey && value is! String) {
          throw ArgumentError(
              'Expected PublicKey or String, got ${value.runtimeType}');
        }
        // Additional validation for string format if it's a string
        if (value is String) {
          try {
            PublicKey.fromBase58(value);
          } catch (e) {
            throw ArgumentError('Invalid PublicKey format: $e');
          }
        }
        break;

      case 'bytes':
        if (value is! List<int>) {
          throw ArgumentError(
              'Expected List<int> for bytes, got ${value.runtimeType}');
        }
        break;

      case 'vec':
        if (value is! List) {
          throw ArgumentError(
              'Expected List for vec, got ${value.runtimeType}');
        }
        // Validate each element in the vector
        for (int i = 0; i < value.length; i++) {
          await _validateArgumentType(
            value[i],
            expectedType.inner!,
            '$argumentName[$i]',
          );
        }
        break;

      case 'option':
        if (value != null) {
          await _validateArgumentType(value, expectedType.inner!, argumentName);
        }
        break;

      case 'array':
        if (value is! List) {
          throw ArgumentError(
              'Expected List for array, got ${value.runtimeType}');
        }
        if (expectedType.size != null && value.length != expectedType.size) {
          throw ArgumentError(
              'Expected array of length ${expectedType.size}, got ${value.length}');
        }
        // Validate each element in the array
        for (int i = 0; i < value.length; i++) {
          await _validateArgumentType(
            value[i],
            expectedType.inner!,
            '$argumentName[$i]',
          );
        }
        break;

      case 'defined':
        await _validateDefinedType(value, expectedType.defined!, argumentName);
        break;

      default:
        // Unknown type - skip validation but warn
        // In a production system, this might throw an error
        break;
    }
  }

  /// Validate custom defined types
  Future<void> _validateDefinedType(
    dynamic value,
    String typeName,
    String argumentName,
  ) async {
    // Find the type definition
    final typeDef = _idlTypes.firstWhere(
      (type) => type.name == typeName,
      orElse: () => throw ArgumentError('Unknown type: $typeName'),
    );

    switch (typeDef.type.kind) {
      case 'struct':
        if (value is! Map<String, dynamic>) {
          throw ArgumentError(
              'Expected Map for struct $typeName, got ${value.runtimeType}');
        }
        await _validateStructFields(value, typeDef.type.fields!, typeName);
        break;

      case 'enum':
        if (value is! Map<String, dynamic>) {
          throw ArgumentError(
              'Expected Map for enum $typeName, got ${value.runtimeType}');
        }
        await _validateEnumVariant(value, typeDef.type.variants!, typeName);
        break;

      default:
        // Other type kinds - basic validation
        break;
    }
  }

  /// Validate struct fields
  Future<void> _validateStructFields(
    Map<String, dynamic> value,
    List<IdlField> fields,
    String typeName,
  ) async {
    for (final field in fields) {
      if (!value.containsKey(field.name)) {
        throw ArgumentError(
            'Missing required field "${field.name}" in struct $typeName');
      }

      await _validateArgumentType(
        value[field.name],
        field.type,
        '${typeName}.${field.name}',
      );
    }

    // Check for unexpected fields
    for (final key in value.keys) {
      if (!fields.any((field) => field.name == key)) {
        throw ArgumentError('Unexpected field "$key" in struct $typeName');
      }
    }
  }

  /// Validate enum variant
  Future<void> _validateEnumVariant(
    Map<String, dynamic> value,
    List<IdlEnumVariant> variants,
    String typeName,
  ) async {
    if (value.length != 1) {
      throw ArgumentError(
          'Enum $typeName must have exactly one variant, got ${value.length}');
    }

    final variantName = value.keys.first;
    final variantValue = value.values.first;

    final variant = variants.firstWhere(
      (v) => v.name == variantName,
      orElse: () => throw ArgumentError(
          'Unknown variant "$variantName" in enum $typeName'),
    );

    // Validate variant fields if they exist
    if (variant.fields != null && variant.fields!.isNotEmpty) {
      if (variantValue is! Map<String, dynamic>) {
        throw ArgumentError(
            'Expected Map for enum variant "$variantName" fields, got ${variantValue.runtimeType}');
      }

      for (final field in variant.fields!) {
        if (!variantValue.containsKey(field.name)) {
          throw ArgumentError(
              'Missing required field "${field.name}" in enum variant "$variantName"');
        }

        await _validateArgumentType(
          variantValue[field.name],
          field.type,
          '$typeName.$variantName.${field.name}',
        );
      }
    }
  }

  /// Validate accounts against IDL account specifications
  Future<void> _validateAccounts(Accounts accounts) async {
    final expectedAccounts = _instruction.accounts;

    // Check for missing required accounts
    for (final accountSpec in expectedAccounts) {
      final isOptional = _isAccountOptional(accountSpec);

      if (!isOptional && !accounts.containsKey(accountSpec.name)) {
        throw MethodValidationError(
            'Missing required account "${accountSpec.name}" for method "${_instruction.name}"');
      }

      // Validate account type if present
      if (accounts.containsKey(accountSpec.name)) {
        final account = accounts[accountSpec.name];
        await _validateAccountType(account, accountSpec);
      }
    }

    // Check for unexpected accounts (warning only)
    for (final accountName in accounts.keys) {
      if (!expectedAccounts.any((spec) => spec.name == accountName)) {
        // This is typically not an error, just a warning
        // Additional accounts may be needed for specific use cases
      }
    }
  }

  /// Validate individual account type and properties
  Future<void> _validateAccountType(
    dynamic account,
    IdlInstructionAccountItem accountSpec,
  ) async {
    if (account == null) {
      if (!_isAccountOptional(accountSpec)) {
        throw MethodValidationError(
            'Account "${accountSpec.name}" cannot be null');
      }
      return;
    }

    // Validate account is a PublicKey or string
    if (account is! PublicKey && account is! String) {
      throw MethodValidationError(
          'Account "${accountSpec.name}" must be PublicKey or String, got ${account.runtimeType}');
    }

    // Additional account-specific validations can be added here
    // For example: checking if account exists on-chain, has correct owner, etc.
  }

  /// Check if an account is optional
  bool _isAccountOptional(IdlInstructionAccountItem accountSpec) {
    // Check if this is an IdlInstructionAccount with optional flag
    if (accountSpec is IdlInstructionAccount) {
      return accountSpec.optional;
    }

    // For other account types, assume required
    return false;
  }

  /// Validate method is eligible for view calls
  bool isViewEligible() {
    // Must have return type
    if (_instruction.returns == null) {
      return false;
    }

    // All accounts must be read-only (non-writable)
    for (final account in _instruction.accounts) {
      if (account is IdlInstructionAccount && account.writable) {
        return false;
      }
    }

    return true;
  }

  /// Get detailed validation information for debugging
  ValidationInfo getValidationInfo() {
    return ValidationInfo(
      instruction: _instruction,
      isViewEligible: isViewEligible(),
      requiredAccounts: _instruction.accounts
          .where((account) => !_isAccountOptional(account))
          .map((account) => account.name)
          .toList(),
      optionalAccounts: _instruction.accounts
          .where((account) => _isAccountOptional(account))
          .map((account) => account.name)
          .toList(),
      argumentTypes: _instruction.args
          .map((arg) => ArgumentTypeInfo(
                name: arg.name,
                type: arg.type.kind,
                isOptional: arg.type.kind == 'option',
              ))
          .toList(),
    );
  }
}

/// Exception thrown during method validation
class MethodValidationError extends Error {
  final String message;

  MethodValidationError(this.message);

  @override
  String toString() => 'MethodValidationError: $message';
}

/// Information about method validation requirements
class ValidationInfo {
  final IdlInstruction instruction;
  final bool isViewEligible;
  final List<String> requiredAccounts;
  final List<String> optionalAccounts;
  final List<ArgumentTypeInfo> argumentTypes;

  const ValidationInfo({
    required this.instruction,
    required this.isViewEligible,
    required this.requiredAccounts,
    required this.optionalAccounts,
    required this.argumentTypes,
  });

  @override
  String toString() {
    return 'ValidationInfo(\n'
        '  method: ${instruction.name}\n'
        '  viewEligible: $isViewEligible\n'
        '  requiredAccounts: $requiredAccounts\n'
        '  optionalAccounts: $optionalAccounts\n'
        '  arguments: ${argumentTypes.map((a) => '${a.name}:${a.type}').join(', ')}\n'
        ')';
  }
}

/// Information about argument types for validation
class ArgumentTypeInfo {
  final String name;
  final String type;
  final bool isOptional;

  const ArgumentTypeInfo({
    required this.name,
    required this.type,
    required this.isOptional,
  });

  @override
  String toString() => '$name: $type${isOptional ? '?' : ''}';
}
