/// Method interface generation for Anchor programs
///
/// This module provides the MethodBuilder class which generates type-safe
/// method interfaces from IDL definitions, enabling dynamic method generation
/// with automatic instruction building and parameter validation.

library;

import '../idl/idl.dart';
import '../types/public_key.dart';
import '../types/transaction.dart';
import '../provider/anchor_provider.dart';
import '../program/context.dart';
import '../program/instruction_builder.dart';
import '../program/accounts_resolver.dart';
import '../coder/instruction_coder.dart';
import '../types/common.dart';

/// Builder for creating typed methods from IDL instructions
class MethodBuilder {
  final IdlInstruction _instruction;
  final PublicKey _programId;
  final AnchorProvider _provider;
  final InstructionCoder _instructionCoder;
  final AccountsResolver _accountsResolver;

  MethodBuilder({
    required IdlInstruction instruction,
    required PublicKey programId,
    required AnchorProvider provider,
    required InstructionCoder instructionCoder,
    required AccountsResolver accountsResolver,
  })  : _instruction = instruction,
        _programId = programId,
        _provider = provider,
        _instructionCoder = instructionCoder,
        _accountsResolver = accountsResolver;

  /// Create a method that builds and executes an instruction
  Future<String> Function(Map<String, dynamic> args, Context context)
      get execute {
    return (Map<String, dynamic> args, Context context) async {
      // Validate arguments against IDL instruction
      _validateArguments(args);

      // Build the instruction
      final instruction = await _buildInstruction(args, context);

      // Create transaction with the instruction
      final transaction = Transaction(
        instructions: [instruction],
        feePayer: _provider.wallet?.publicKey,
      );

      // Send and confirm the transaction
      return await _provider.sendAndConfirm(transaction);
    };
  }

  /// Create a method that builds an instruction without executing
  Future<TransactionInstruction> Function(
      Map<String, dynamic> args, Context context) get instruction {
    return (Map<String, dynamic> args, Context context) async {
      _validateArguments(args);
      return await _buildInstruction(args, context);
    };
  }

  /// Create a method that builds a transaction without executing
  Future<Transaction> Function(Map<String, dynamic> args, Context context)
      get transaction {
    return (Map<String, dynamic> args, Context context) async {
      _validateArguments(args);
      final instruction = await _buildInstruction(args, context);

      return Transaction(
        instructions: [instruction],
        feePayer: _provider.wallet?.publicKey,
      );
    };
  }

  /// Create a method that simulates the instruction
  Future<TransactionSimulationResult> Function(
      Map<String, dynamic> args, Context context) get simulate {
    return (Map<String, dynamic> args, Context context) async {
      _validateArguments(args);
      final instruction = await _buildInstruction(args, context);

      final transaction = Transaction(
        instructions: [instruction],
        feePayer: _provider.wallet?.publicKey,
      );

      return await _provider.simulate(transaction);
    };
  }

  /// Build the instruction from arguments and context
  Future<TransactionInstruction> _buildInstruction(
    Map<String, dynamic> args,
    Context context,
  ) async {
    try {
      // Create instruction builder with proper parameters
      final builder = InstructionBuilder(
        idl: Idl(
          address: _programId.toBase58(),
          metadata: const IdlMetadata(
            name: 'program',
            version: '0.1.0',
            spec: '0.1.0',
          ),
          instructions: [_instruction],
          types: [], // Empty for method building
        ),
        methodName: _instruction.name,
        instructionCoder: _instructionCoder,
        accountsResolver: _accountsResolver,
      );

      // Convert context.accounts to Map<String, dynamic> if it exists
      final accountsMap = <String, dynamic>{};
      if (context.accounts != null) {
        final accounts = context.accounts!;
        if (accounts is DynamicAccounts) {
          accountsMap.addAll(accounts.toMap());
        } else {
          // For other Accounts implementations, try to get a map representation
          accountsMap.addAll(accounts.toMap());
        }
      }

      // Set arguments and accounts using the InstructionBuilder API
      final buildResult = await builder
          .args(_transformArguments(args))
          .accounts(accountsMap)
          .context(context)
          .build();

      // Convert build result to TransactionInstruction
      return TransactionInstruction(
        programId: _programId,
        accounts: buildResult.metas,
        data: buildResult.data,
      );
    } catch (e) {
      throw MethodBuildError(
          'Failed to build instruction ${_instruction.name}: $e');
    }
  }

  /// Transform arguments to their serializable forms
  Map<String, dynamic> _transformArguments(Map<String, dynamic> args) {
    final transformed = <String, dynamic>{};

    for (final entry in args.entries) {
      final value = entry.value;

      // Transform PublicKey to base58 string or bytes (depending on what the coder expects)
      if (value is PublicKey) {
        transformed[entry.key] = value.toBase58();
      } else {
        transformed[entry.key] = value;
      }
    }

    return transformed;
  }

  /// Validate arguments against IDL instruction arguments
  void _validateArguments(Map<String, dynamic> args) {
    final requiredArgs = _instruction.args.where((arg) => !_isOptionalArg(arg));

    // Check for missing required arguments
    for (final arg in requiredArgs) {
      if (!args.containsKey(arg.name)) {
        throw MethodArgumentError(
          'Missing required argument "${arg.name}" for instruction "${_instruction.name}"',
        );
      }
    }

    // Check for unexpected arguments
    final expectedArgNames = _instruction.args.map((arg) => arg.name).toSet();
    for (final argName in args.keys) {
      if (!expectedArgNames.contains(argName)) {
        throw MethodArgumentError(
            'Unexpected argument "$argName" for instruction "${_instruction.name}". '
            'Expected: ${expectedArgNames.join(', ')}');
      }
    }

    // Validate argument types (basic validation)
    for (final arg in _instruction.args) {
      if (args.containsKey(arg.name)) {
        _validateArgumentType(arg.name, args[arg.name], arg.type);
      }
    }
  }

  /// Check if an argument is optional based on IDL type
  bool _isOptionalArg(IdlField arg) {
    return arg.type.kind == 'option';
  }

  /// Validate argument type against IDL type definition
  void _validateArgumentType(String argName, dynamic value, IdlType type) {
    if (value == null && type.kind != 'option') {
      throw MethodArgumentError('Argument "$argName" cannot be null');
    }

    switch (type.kind) {
      case 'bool':
        if (value != null && value is! bool) {
          throw MethodArgumentError('Argument "$argName" must be a bool');
        }
        break;
      case 'u8':
      case 'u16':
      case 'u32':
      case 'u64':
      case 'i8':
      case 'i16':
      case 'i32':
      case 'i64':
        if (value != null && value is! int) {
          throw MethodArgumentError('Argument "$argName" must be an int');
        }
        break;
      case 'string':
        if (value != null && value is! String) {
          throw MethodArgumentError('Argument "$argName" must be a string');
        }
        break;
      case 'pubkey':
        if (value != null && value is! PublicKey) {
          throw MethodArgumentError('Argument "$argName" must be a PublicKey');
        }
        break;
      case 'vec':
        if (value != null && value is! List) {
          throw MethodArgumentError('Argument "$argName" must be a List');
        }
        break;
      case 'array':
        if (value != null && value is! List) {
          throw MethodArgumentError('Argument "$argName" must be a List');
        }
        // Additional array size validation could be added here
        break;
      case 'option':
        // Options can be null, so validate the inner type if not null
        if (value != null && type.inner != null) {
          _validateArgumentType(argName, value, type.inner!);
        }
        break;
      case 'defined':
        // For defined types, we assume they're structs/objects
        if (value != null && value is! Map<String, dynamic>) {
          throw MethodArgumentError(
              'Argument "$argName" must be a Map for defined type');
        }
        break;
      default:
        // Unknown type, skip validation
        break;
    }
  }
}

/// Factory for creating method builders
class MethodBuilderFactory {
  final PublicKey _programId;
  final AnchorProvider _provider;
  final InstructionCoder _instructionCoder;
  final AccountsResolver _accountsResolver;

  MethodBuilderFactory({
    required PublicKey programId,
    required AnchorProvider provider,
    required InstructionCoder instructionCoder,
    required AccountsResolver accountsResolver,
  })  : _programId = programId,
        _provider = provider,
        _instructionCoder = instructionCoder,
        _accountsResolver = accountsResolver;

  /// Create a method builder for an IDL instruction
  MethodBuilder createMethodBuilder(IdlInstruction instruction) {
    return MethodBuilder(
      instruction: instruction,
      programId: _programId,
      provider: _provider,
      instructionCoder: _instructionCoder,
      accountsResolver: _accountsResolver,
    );
  }

  /// Create method builders for all instructions in an IDL
  Map<String, MethodBuilder> createAllMethodBuilders(Idl idl) {
    final builders = <String, MethodBuilder>{};

    for (final instruction in idl.instructions) {
      builders[instruction.name] = createMethodBuilder(instruction);
    }

    return builders;
  }
}

/// Method interface that combines all method types
class MethodInterface {
  /// Execute the method and return transaction signature
  final Future<String> Function(Map<String, dynamic> args, Context context)
      execute;

  /// Build instruction without executing
  final Future<TransactionInstruction> Function(
      Map<String, dynamic> args, Context context) instruction;

  /// Build transaction without executing
  final Future<Transaction> Function(Map<String, dynamic> args, Context context)
      transaction;

  /// Simulate the method execution
  final Future<TransactionSimulationResult> Function(
      Map<String, dynamic> args, Context context) simulate;

  const MethodInterface({
    required this.execute,
    required this.instruction,
    required this.transaction,
    required this.simulate,
  });

  /// Create method interface from method builder
  factory MethodInterface.fromBuilder(MethodBuilder builder) {
    return MethodInterface(
      execute: builder.execute,
      instruction: builder.instruction,
      transaction: builder.transaction,
      simulate: builder.simulate,
    );
  }
}

/// Error thrown when method argument validation fails
class MethodArgumentError extends AnchorException {
  MethodArgumentError(super.message);
}

/// Error thrown when method building fails
class MethodBuildError extends AnchorException {
  MethodBuildError(super.message);
}
