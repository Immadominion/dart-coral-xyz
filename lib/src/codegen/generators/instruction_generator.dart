/// Instruction builder generator
///
/// This module generates instruction builder classes that provide
/// type-safe fluent API for building and executing program instructions.
library;

import 'package:build/build.dart';
import '../../idl/idl.dart';

/// Generator for instruction builder classes
class InstructionGenerator {
  /// Creates an InstructionGenerator with the given IDL and options
  InstructionGenerator(this.idl, this.options);

  /// IDL definition
  final Idl idl;

  /// Build options
  final BuilderOptions options;

  /// Generate all instruction builder classes
  String generate() {
    final buffer = StringBuffer();

    // Generate instruction builder classes
    for (final instruction in idl.instructions) {
      _generateInstructionBuilder(buffer, instruction);
    }

    return buffer.toString();
  }

  /// Generate instruction builder class for a single instruction
  void _generateInstructionBuilder(
      StringBuffer buffer, IdlInstruction instruction) {
    final className = _toPascalCase(instruction.name);
    final builderClassName = '${className}InstructionBuilder';

    // Generate accounts configuration class FIRST (outside the builder class)
    _generateAccountsClass(buffer, instruction);

    buffer.writeln('/// Builder for ${instruction.name} instruction');
    if (instruction.docs?.isNotEmpty == true) {
      for (final doc in instruction.docs!) {
        buffer.writeln('/// $doc');
      }
    }
    buffer.writeln('class $builderClassName extends InstructionBuilder {');

    // Generate constructor
    buffer.writeln('  /// Creates a new $builderClassName');
    buffer.writeln('  $builderClassName({');
    buffer.writeln('    required Program program,');

    // Add instruction arguments as constructor parameters
    for (final arg in instruction.args) {
      final paramType = _dartTypeFromIdlType(arg.type);
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('    this.$paramName,');
    }

    buffer.writeln('  }) : super(');
    buffer.writeln('    idl: program.idl,');
    buffer.writeln('    methodName: \'${instruction.name}\',');
    buffer.writeln('    instructionCoder: program.coder.instruction,');
    buffer.writeln('    accountsResolver: program.accountsResolver,');
    buffer.writeln('  );');
    buffer.writeln();

    // Generate fields for instruction arguments
    for (final arg in instruction.args) {
      final paramType = _dartTypeFromIdlType(arg.type);
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('  /// ${arg.name} argument');
      buffer.writeln('  final $paramType? $paramName;');
      buffer.writeln();
    }

    // Generate accounts method with proper typing
    final accountsClassName = '${className}Accounts';
    buffer.writeln('  /// Set accounts for ${instruction.name} instruction');
    buffer
        .writeln('  $builderClassName accounts($accountsClassName accounts) {');
    buffer.writeln('    final builder = $builderClassName(');
    buffer
        .writeln('      program: InstructionBuilder.programFromBuilder(this),');

    // Pass through all constructor parameters
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('      $paramName: $paramName,');
    }

    buffer.writeln('    );');
    buffer.writeln('    builder.accounts(accounts.toMap());');
    buffer.writeln('    return builder;');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate convenience methods
    _generateConvenienceMethods(buffer, instruction, builderClassName);

    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate accounts configuration class
  void _generateAccountsClass(StringBuffer buffer, IdlInstruction instruction) {
    final className = _toPascalCase(instruction.name);
    final accountsClassName = '${className}Accounts';

    buffer.writeln(
        '/// Accounts configuration for ${instruction.name} instruction');
    buffer.writeln('class $accountsClassName {');
    buffer.writeln('  /// Creates a new $accountsClassName');
    buffer.writeln('  const $accountsClassName({');

    // Add accounts from instruction
    for (final account in instruction.accounts) {
      final accountName = _toCamelCase(account.name);
      if (account is IdlInstructionAccount) {
        buffer.writeln(
            '    ${account.optional ? '' : 'required '}this.$accountName,');
      } else {
        buffer.writeln('    required this.$accountName,');
      }
    }

    buffer.writeln('  });');
    buffer.writeln();

    // Generate account fields
    for (final account in instruction.accounts) {
      final accountName = _toCamelCase(account.name);
      buffer.writeln('  /// ${account.name} account');
      if (account.docs?.isNotEmpty == true) {
        for (final doc in account.docs!) {
          buffer.writeln('  /// $doc');
        }
      }
      if (account is IdlInstructionAccount) {
        buffer.writeln(
            '  final PublicKey${account.optional ? '?' : ''} $accountName;');
      } else {
        buffer.writeln('  final PublicKey $accountName;');
      }
    }
    buffer.writeln();

    // Generate toMap method
    buffer.writeln('  /// Convert accounts to map');
    buffer.writeln('  Map<String, PublicKey> toMap() {');
    buffer.writeln('    final map = <String, PublicKey>{};');
    for (final account in instruction.accounts) {
      final accountName = _toCamelCase(account.name);
      if (account is IdlInstructionAccount && account.optional) {
        buffer.writeln('    if ($accountName != null) {');
        buffer.writeln('      map[\'${account.name}\'] = $accountName!;');
        buffer.writeln('    }');
      } else {
        buffer.writeln('    map[\'${account.name}\'] = $accountName;');
      }
    }
    buffer.writeln('    return map;');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate builder methods
  void _generateBuilderMethods(
      StringBuffer buffer, IdlInstruction instruction) {
    final className = _toPascalCase(instruction.name);
    final builderClassName = '${className}InstructionBuilder';
    final accountsClassName = '${className}Accounts';

    // Generate accounts method
    buffer.writeln('  /// Configure accounts for this instruction');
    buffer
        .writeln('  $builderClassName accounts($accountsClassName accounts) {');
    buffer.writeln('    return $builderClassName(');
    buffer.writeln('      program: program,');
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('      $paramName: $paramName,');
    }
    buffer.writeln('    )..accountsConfig = accounts;');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate signers method
    buffer.writeln('  /// Configure signers for this instruction');
    buffer.writeln('  $builderClassName signers(List<Signer> signers) {');
    buffer.writeln('    return $builderClassName(');
    buffer.writeln('      program: program,');
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('      $paramName: $paramName,');
    }
    buffer.writeln('    )..signersConfig = signers;');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate preInstructions method
    buffer.writeln('  /// Add pre-instructions to this instruction');
    buffer.writeln(
        '  $builderClassName preInstructions(List<TransactionInstruction> instructions) {');
    buffer.writeln('    return $builderClassName(');
    buffer.writeln('      program: program,');
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('      $paramName: $paramName,');
    }
    buffer.writeln('    )..preInstructionsConfig = instructions;');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate postInstructions method
    buffer.writeln('  /// Add post-instructions to this instruction');
    buffer.writeln(
        '  $builderClassName postInstructions(List<TransactionInstruction> instructions) {');
    buffer.writeln('    return $builderClassName(');
    buffer.writeln('      program: program,');
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('      $paramName: $paramName,');
    }
    buffer.writeln('    )..postInstructionsConfig = instructions;');
    buffer.writeln('  }');
    buffer.writeln();
  }

  /// Generate execution methods
  void _generateExecutionMethods(
      StringBuffer buffer, IdlInstruction instruction) {
    final className = _toPascalCase(instruction.name);

    // Generate instruction method
    buffer.writeln('  /// Build the instruction');
    buffer.writeln('  @override');
    buffer.writeln('  Future<TransactionInstruction> instruction() async {');
    buffer.writeln('    final args = <String, dynamic>{};');

    // Add instruction arguments
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln('    if ($paramName != null) {');
      buffer.writeln('      args[\'${arg.name}\'] = $paramName;');
      buffer.writeln('    }');
    }

    buffer.writeln('    return program.instruction(');
    buffer.writeln('      \'${instruction.name}\',');
    buffer.writeln('      args,');
    buffer.writeln('      accounts: accountsConfig?.toMap() ?? {},');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate RPC method
    buffer.writeln('  /// Execute the instruction via RPC');
    buffer.writeln('  @override');
    buffer.writeln('  Future<String> rpc({');
    buffer.writeln('    Commitment? commitment,');
    buffer.writeln('    bool? skipPreflight,');
    buffer.writeln('    int? maxRetries,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final instruction = await this.instruction();');
    buffer.writeln('    return program.rpc(');
    buffer.writeln('      instruction,');
    buffer.writeln('      signers: signersConfig ?? [],');
    buffer.writeln('      commitment: commitment,');
    buffer.writeln('      skipPreflight: skipPreflight,');
    buffer.writeln('      maxRetries: maxRetries,');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate simulate method
    buffer.writeln('  /// Simulate the instruction');
    buffer.writeln('  @override');
    buffer.writeln('  Future<SimulateTransactionResponse> simulate({');
    buffer.writeln('    Commitment? commitment,');
    buffer.writeln('    bool? sigVerify,');
    buffer.writeln('    bool? replaceRecentBlockhash,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final instruction = await this.instruction();');
    buffer.writeln('    return program.simulate(');
    buffer.writeln('      instruction,');
    buffer.writeln('      signers: signersConfig ?? [],');
    buffer.writeln('      commitment: commitment,');
    buffer.writeln('      sigVerify: sigVerify,');
    buffer.writeln('      replaceRecentBlockhash: replaceRecentBlockhash,');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate state fields
    buffer.writeln('  /// Accounts configuration');
    buffer.writeln('  ${className}Accounts? accountsConfig;');
    buffer.writeln();
    buffer.writeln('  /// Signers configuration');
    buffer.writeln('  List<Signer>? signersConfig;');
    buffer.writeln();
    buffer.writeln('  /// Pre-instructions configuration');
    buffer.writeln('  List<TransactionInstruction>? preInstructionsConfig;');
    buffer.writeln();
    buffer.writeln('  /// Post-instructions configuration');
    buffer.writeln('  List<TransactionInstruction>? postInstructionsConfig;');
  }

  /// Generate convenience methods for instruction builder
  void _generateConvenienceMethods(StringBuffer buffer,
      IdlInstruction instruction, String builderClassName) {
    buffer.writeln('  /// Create instruction');
    buffer.writeln('  Future<tx.Instruction> instruction() async {');
    buffer.writeln('    final args = <String, dynamic>{');

    // Add arguments to the map
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln(
          '      if ($paramName != null) \'${arg.name}\': $paramName,');
    }

    buffer.writeln('    };');
    buffer.writeln('    return super.args(args).instruction();');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Send and confirm transaction');
    buffer.writeln('  Future<String> rpc({');
    buffer.writeln('    Commitment? commitment,');
    buffer.writeln('    List<PublicKey>? signers,');
    buffer.writeln('    Map<String, dynamic>? options,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final args = <String, dynamic>{');

    // Add arguments to the map
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln(
          '      if ($paramName != null) \'${arg.name}\': $paramName,');
    }

    buffer.writeln('    };');
    buffer.writeln('    return super.args(args).rpc(');
    buffer.writeln('      commitment: commitment,');
    buffer.writeln('      signers: signers,');
    buffer.writeln('      options: options,');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Simulate transaction');
    buffer.writeln('  Future<SimulateTransactionResponse> simulate({');
    buffer.writeln('    Commitment? commitment,');
    buffer.writeln('    List<PublicKey>? signers,');
    buffer.writeln('    Map<String, dynamic>? options,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final args = <String, dynamic>{');

    // Add arguments to the map
    for (final arg in instruction.args) {
      final paramName = _toCamelCase(arg.name);
      buffer.writeln(
          '      if ($paramName != null) \'${arg.name}\': $paramName,');
    }

    buffer.writeln('    };');
    buffer.writeln('    return super.args(args).simulate(');
    buffer.writeln('      commitment: commitment,');
    buffer.writeln('      signers: signers,');
    buffer.writeln('      options: options,');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  /// Convert IDL type to Dart type
  String _dartTypeFromIdlType(IdlType type) {
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
        return 'BigInt';
      case 'f32':
      case 'f64':
        return 'double';
      case 'bytes':
        return 'List<int>';
      case 'string':
        return 'String';
      case 'publicKey':
        return 'PublicKey';
      case 'array':
        if (type.inner != null) {
          final elementType = _dartTypeFromIdlType(type.inner!);
          return 'List<$elementType>';
        }
        return 'List<dynamic>';
      case 'vec':
        if (type.inner != null) {
          final elementType = _dartTypeFromIdlType(type.inner!);
          return 'List<$elementType>';
        }
        return 'List<dynamic>';
      case 'option':
        if (type.inner != null) {
          final elementType = _dartTypeFromIdlType(type.inner!);
          return '$elementType?';
        }
        return 'dynamic?';
      case 'defined':
        return _toPascalCase(type.defined ?? 'Unknown');
      default:
        return 'dynamic';
    }
  }

  /// Convert string to PascalCase
  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join('');
  }

  /// Convert string to camelCase
  String _toCamelCase(String input) {
    final pascalCase = _toPascalCase(input);
    return pascalCase.isNotEmpty
        ? pascalCase[0].toLowerCase() + pascalCase.substring(1)
        : '';
  }
}
