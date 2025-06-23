/// Enhanced Instruction Definition and Metadata System
///
/// This module provides comprehensive instruction metadata handling matching
/// TypeScript Anchor's sophisticated instruction definition system with
/// complete argument validation, account metadata, and constraint checking.

import '../idl/idl.dart';
import '../types/public_key.dart';

/// Enhanced instruction definition with comprehensive metadata and validation
class InstructionDefinition {
  final IdlInstruction _idlInstruction;
  final List<ArgumentDefinition> _arguments;
  final List<InstructionAccountDefinition> _accounts;
  final InstructionConstraints _constraints;
  final InstructionMetadata _metadata;

  InstructionDefinition._({
    required IdlInstruction idlInstruction,
    required List<ArgumentDefinition> arguments,
    required List<InstructionAccountDefinition> accounts,
    required InstructionConstraints constraints,
    required InstructionMetadata metadata,
  })  : _idlInstruction = idlInstruction,
        _arguments = arguments,
        _accounts = accounts,
        _constraints = constraints,
        _metadata = metadata;

  /// Create instruction definition from IDL instruction
  factory InstructionDefinition.fromIdl(IdlInstruction idlInstruction) {
    // Parse arguments with type information
    final arguments = idlInstruction.args
        .map((arg) => ArgumentDefinition.fromIdlField(arg))
        .toList();

    // Parse accounts with metadata
    final accounts = idlInstruction.accounts
        .map((account) => InstructionAccountDefinition.fromIdlAccount(account))
        .toList();

    // Create constraints from IDL metadata
    final constraints = InstructionConstraints.fromIdl(idlInstruction);

    // Create metadata
    final metadata = InstructionMetadata(
      name: idlInstruction.name,
      docs: idlInstruction.docs,
      discriminator: idlInstruction.discriminator,
      returnsType: idlInstruction.returns,
    );

    return InstructionDefinition._(
      idlInstruction: idlInstruction,
      arguments: arguments,
      accounts: accounts,
      constraints: constraints,
      metadata: metadata,
    );
  }

  /// Get instruction name
  String get name => _metadata.name;

  /// Get instruction documentation
  List<String>? get docs => _metadata.docs;

  /// Get instruction discriminator
  List<int>? get discriminator => _metadata.discriminator;

  /// Get return type
  String? get returnsType => _metadata.returnsType;

  /// Get all arguments with type information
  List<ArgumentDefinition> get arguments => List.unmodifiable(_arguments);

  /// Get all accounts with metadata
  List<InstructionAccountDefinition> get accounts =>
      List.unmodifiable(_accounts);

  /// Get instruction constraints
  InstructionConstraints get constraints => _constraints;

  /// Get instruction metadata
  InstructionMetadata get metadata => _metadata;

  /// Get original IDL instruction
  IdlInstruction get idlInstruction => _idlInstruction;

  /// Validate instruction arguments against definitions
  InstructionValidationResult validateArguments(
    Map<String, dynamic> providedArgs,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required arguments
    for (final argDef in _arguments) {
      if (argDef.isRequired && !providedArgs.containsKey(argDef.name)) {
        errors.add('Missing required argument: ${argDef.name}');
        continue;
      }

      if (providedArgs.containsKey(argDef.name)) {
        final value = providedArgs[argDef.name];
        final typeValidation = argDef.validateType(value);
        if (!typeValidation.isValid) {
          errors.add(
            'Invalid type for argument ${argDef.name}: ${typeValidation.error}',
          );
        }
      }
    }

    // Check for unexpected arguments
    for (final providedArgName in providedArgs.keys) {
      if (!_arguments.any((arg) => arg.name == providedArgName)) {
        warnings.add('Unexpected argument: $providedArgName');
      }
    }

    return InstructionValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate instruction accounts against definitions
  InstructionValidationResult validateAccounts(
    Map<String, dynamic> providedAccounts,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required accounts
    for (final accountDef in _accounts) {
      if (accountDef.isRequired &&
          !providedAccounts.containsKey(accountDef.name)) {
        errors.add('Missing required account: ${accountDef.name}');
        continue;
      }

      if (providedAccounts.containsKey(accountDef.name)) {
        final account = providedAccounts[accountDef.name];
        final accountValidation = accountDef.validateAccount(account);
        if (!accountValidation.isValid) {
          errors.add(
            'Invalid account ${accountDef.name}: ${accountValidation.error}',
          );
        }
      }
    }

    // Check for unexpected accounts
    for (final providedAccountName in providedAccounts.keys) {
      if (!_accounts.any((acc) => acc.name == providedAccountName)) {
        warnings.add('Unexpected account: $providedAccountName');
      }
    }

    return InstructionValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate complete instruction call
  InstructionValidationResult validate({
    required Map<String, dynamic> arguments,
    required Map<String, dynamic> accounts,
  }) {
    final argValidation = validateArguments(arguments);
    final accountValidation = validateAccounts(accounts);

    final allErrors = <String>[
      ...argValidation.errors,
      ...accountValidation.errors,
    ];

    final allWarnings = <String>[
      ...argValidation.warnings,
      ...accountValidation.warnings,
    ];

    return InstructionValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
    );
  }

  @override
  String toString() {
    return 'InstructionDefinition(name: $name, args: ${_arguments.length}, accounts: ${_accounts.length})';
  }
}

/// Argument definition with type validation
class ArgumentDefinition {
  final String name;
  final IdlType type;
  final List<String>? docs;
  final bool isRequired;
  final TypeValidator validator;

  ArgumentDefinition({
    required this.name,
    required this.type,
    this.docs,
    this.isRequired = true,
    required this.validator,
  });

  /// Create from IDL field
  factory ArgumentDefinition.fromIdlField(IdlField field) {
    return ArgumentDefinition(
      name: field.name,
      type: field.type,
      docs: field.docs,
      isRequired: true, // All IDL fields are typically required
      validator: TypeValidator.fromIdlType(field.type),
    );
  }

  /// Validate argument value against type definition
  TypeValidationResult validateType(dynamic value) {
    return validator.validate(value);
  }

  @override
  String toString() {
    return 'ArgumentDefinition(name: $name, type: $type, required: $isRequired)';
  }
}

/// Instruction account definition with metadata and validation
class InstructionAccountDefinition {
  final String name;
  final List<String>? docs;
  final bool isWritable;
  final bool isSigner;
  final bool isOptional;
  final String? address;
  final IdlPda? pda;
  final List<String>? relations;

  InstructionAccountDefinition({
    required this.name,
    this.docs,
    this.isWritable = false,
    this.isSigner = false,
    this.isOptional = false,
    this.address,
    this.pda,
    this.relations,
  });

  /// Create from IDL account item
  factory InstructionAccountDefinition.fromIdlAccount(
      IdlInstructionAccountItem account) {
    if (account is IdlInstructionAccount) {
      return InstructionAccountDefinition(
        name: account.name,
        docs: account.docs,
        isWritable: account.writable,
        isSigner: account.signer,
        isOptional: account.optional,
        address: account.address,
        pda: account.pda,
        relations: account.relations,
      );
    } else if (account is IdlInstructionAccounts) {
      // For composite accounts, use the group name
      return InstructionAccountDefinition(
        name: account.name,
        docs: null,
        isWritable: false,
        isSigner: false,
        isOptional: false,
      );
    } else {
      throw ArgumentError('Unknown account type: ${account.runtimeType}');
    }
  }

  /// Get if account is required
  bool get isRequired => !isOptional;

  /// Validate account value
  SimpleValidationResult validateAccount(dynamic account) {
    if (account == null && isRequired) {
      return SimpleValidationResult(
        isValid: false,
        error: 'Account is required but null was provided',
      );
    }

    if (account != null && account is! PublicKey && account is! String) {
      return SimpleValidationResult(
        isValid: false,
        error: 'Account must be PublicKey or string address',
      );
    }

    return SimpleValidationResult(isValid: true);
  }

  @override
  String toString() {
    return 'InstructionAccountDefinition(name: $name, writable: $isWritable, signer: $isSigner, optional: $isOptional)';
  }
}

/// Instruction constraints and validation rules
class InstructionConstraints {
  final int maxArguments;
  final int maxAccounts;
  final bool requiresSignature;
  final List<String> mutuallyExclusiveArgs;
  final List<String> dependentArgs;

  const InstructionConstraints({
    this.maxArguments = 100,
    this.maxAccounts = 100,
    this.requiresSignature = false,
    this.mutuallyExclusiveArgs = const [],
    this.dependentArgs = const [],
  });

  /// Create constraints from IDL instruction
  factory InstructionConstraints.fromIdl(IdlInstruction instruction) {
    final hasSignerAccount = instruction.accounts.any((account) {
      if (account is IdlInstructionAccount) {
        return account.signer;
      }
      return false;
    });

    return InstructionConstraints(
      maxArguments: instruction.args.length + 10, // Allow some flexibility
      maxAccounts: instruction.accounts.length + 10,
      requiresSignature: hasSignerAccount,
      mutuallyExclusiveArgs: const [],
      dependentArgs: const [],
    );
  }

  /// Validate constraints
  bool validateConstraints({
    required int argumentCount,
    required int accountCount,
    required bool hasSignature,
  }) {
    if (argumentCount > maxArguments) return false;
    if (accountCount > maxAccounts) return false;
    if (requiresSignature && !hasSignature) return false;
    return true;
  }
}

/// Instruction metadata
class InstructionMetadata {
  final String name;
  final List<String>? docs;
  final List<int>? discriminator;
  final String? returnsType;

  const InstructionMetadata({
    required this.name,
    this.docs,
    this.discriminator,
    this.returnsType,
  });
}

/// Type validator for instruction arguments
class TypeValidator {
  final IdlType type;
  final Function(dynamic) validator;

  TypeValidator({
    required this.type,
    required this.validator,
  });

  /// Create validator from IDL type
  factory TypeValidator.fromIdlType(IdlType type) {
    return TypeValidator(
      type: type,
      validator: _createValidator(type),
    );
  }

  /// Validate value against type
  TypeValidationResult validate(dynamic value) {
    try {
      final isValid = validator(value);
      if (isValid is bool) {
        return TypeValidationResult(
          isValid: isValid,
          error: isValid ? null : 'Type validation failed for $type',
        );
      } else {
        return TypeValidationResult(
          isValid: false,
          error: 'Invalid validator response',
        );
      }
    } catch (e) {
      return TypeValidationResult(
        isValid: false,
        error: 'Validation error: $e',
      );
    }
  }

  /// Create type-specific validator function
  static Function(dynamic) _createValidator(IdlType type) {
    final kind = type.kind;
    switch (kind) {
      case 'bool':
        return (value) => value is bool;
      case 'u8':
      case 'i8':
      case 'u16':
      case 'i16':
      case 'u32':
      case 'i32':
      case 'u64':
      case 'i64':
      case 'u128':
      case 'i128':
        return (value) => value is int;
      case 'f32':
      case 'f64':
        return (value) => value is num;
      case 'string':
        return (value) => value is String;
      case 'publicKey':
        return (value) => value is PublicKey || value is String;
      case 'array':
        return (value) => value is List;
      case 'option':
        return (value) => true; // Options can be null or the inner type
      case 'defined':
        return (value) => true; // Allow any for user-defined types
      case 'vec':
        return (value) => value is List;
      default:
        return (value) => true; // Default: allow any value
    }
  }
}

/// Validation result for instructions
class InstructionValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const InstructionValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Check if validation passed without errors
  bool get hasErrors => errors.isNotEmpty;

  /// Check if validation has warnings
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    return 'InstructionValidationResult(valid: $isValid, errors: ${errors.length}, warnings: ${warnings.length})';
  }
}

/// Result of argument validation
class ArgumentValidationResult {
  final bool isValid;
  final String? error;
  final String? expectedType;
  final String? actualType;

  const ArgumentValidationResult({
    required this.isValid,
    this.error,
    this.expectedType,
    this.actualType,
  });

  factory ArgumentValidationResult.valid() {
    return const ArgumentValidationResult(isValid: true);
  }

  factory ArgumentValidationResult.invalid({
    required String error,
    String? expectedType,
    String? actualType,
  }) {
    return ArgumentValidationResult(
      isValid: false,
      error: error,
      expectedType: expectedType,
      actualType: actualType,
    );
  }

  @override
  String toString() {
    if (isValid) return 'ArgumentValidationResult(valid: true)';
    return 'ArgumentValidationResult(valid: false, error: $error)';
  }
}

/// Result of instruction account validation
class InstructionAccountValidationResult {
  final bool isValid;
  final String? error;
  final String? expectedConstraint;
  final String? actualValue;

  const InstructionAccountValidationResult({
    required this.isValid,
    this.error,
    this.expectedConstraint,
    this.actualValue,
  });

  factory InstructionAccountValidationResult.valid() {
    return const InstructionAccountValidationResult(isValid: true);
  }

  factory InstructionAccountValidationResult.invalid({
    required String error,
    String? expectedConstraint,
    String? actualValue,
  }) {
    return InstructionAccountValidationResult(
      isValid: false,
      error: error,
      expectedConstraint: expectedConstraint,
      actualValue: actualValue,
    );
  }

  @override
  String toString() {
    if (isValid) return 'InstructionAccountValidationResult(valid: true)';
    return 'InstructionAccountValidationResult(valid: false, error: $error)';
  }
}

/// Type validation result
class TypeValidationResult {
  final bool isValid;
  final String? error;

  const TypeValidationResult({
    required this.isValid,
    this.error,
  });

  @override
  String toString() {
    return 'TypeValidationResult(valid: $isValid, error: $error)';
  }
}

/// Simple validation result for basic validations
class SimpleValidationResult {
  final bool isValid;
  final String? error;

  const SimpleValidationResult({
    required this.isValid,
    this.error,
  });

  @override
  String toString() {
    return 'SimpleValidationResult(valid: $isValid, error: $error)';
  }
}
