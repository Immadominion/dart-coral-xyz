/// # Interface Definition Language (IDL) System
///
/// The IDL system provides comprehensive support for parsing, validating, and
/// managing Anchor Interface Definition Language files. IDL files define the
/// complete interface of Anchor programs including instructions, accounts,
/// events, errors, and custom types.
///
/// ## Features
///
/// - **Complete IDL Parsing**: Support for all Anchor IDL features
/// - **Type-Safe Validation**: Comprehensive validation with detailed error reporting
/// - **TypeScript Compatibility**: Full compatibility with TypeScript IDL format
/// - **Advanced Utilities**: Type introspection, complexity analysis, and more
/// - **On-Chain Fetching**: Retrieve IDL files directly from program accounts
///
/// ## Basic Usage
///
/// ```dart
/// // Parse IDL from JSON string
/// final idl = Idl.fromJson(jsonDecode(idlJsonString));
///
/// // Fetch IDL from on-chain program account
/// final idl = await Idl.fetchFromAddress(programId, provider);
///
/// // Validate IDL structure
/// final validation = IdlUtils.validateIdl(idl);
/// if (validation.hasErrors) {
///   print('Validation errors: ${validation.errors}');
/// }
/// ```
///
/// ## IDL Structure
///
/// An IDL defines the complete interface of an Anchor program:
///
/// ```dart
/// final idl = Idl(
///   name: 'my_program',
///   version: '0.1.0',
///   instructions: [
///     IdlInstruction(
///       name: 'initialize',
///       args: [IdlField(name: 'amount', type: IdlType.u64())],
///       accounts: [
///         IdlAccountItem.single(IdlAccount(name: 'user', isMut: false, isSigner: true)),
///         IdlAccountItem.single(IdlAccount(name: 'systemProgram', isMut: false, isSigner: false)),
///       ],
///     ),
///   ],
///   accounts: [
///     IdlAccount(name: 'Counter', type: IdlTypeDef(/* ... */)),
///   ],
///   events: [
///     IdlEvent(name: 'CounterUpdated', fields: [/* ... */]),
///   ],
/// );
/// ```
///
/// ## Advanced Features
///
/// ### Type Introspection
/// ```dart
/// // Find all custom types referenced in the IDL
/// final types = IdlUtils.extractTypeReferences(idl);
///
/// // Find which accounts use a specific type
/// final accounts = IdlUtils.findAccountsUsingType(idl, 'MyCustomType');
///
/// // Calculate IDL complexity
/// final complexity = IdlUtils.calculateComplexity(idl);
/// ```
///
/// ### IDL Validation
/// ```dart
/// final result = IdlUtils.validateIdl(idl);
///
/// // Check for errors
/// if (result.hasErrors) {
///   for (final error in result.errors) {
///     print('Error: ${error.message} at ${error.path}');
///   }
/// }
///
/// // Check for warnings
/// if (result.hasWarnings) {
///   for (final warning in result.warnings) {
///     print('Warning: ${warning.message}');
///   }
/// }
/// ```
///
/// ### Type Conversion
/// ```dart
/// // Convert snake_case IDL to Dart camelCase
/// final dartIdl = IdlUtils.convertToCamelCase(idl);
///
/// // Generate summary for documentation
/// final summary = IdlUtils.generateSummary(idl);
/// print('Program: ${summary.name} (${summary.instructionCount} instructions)');
/// ```
///
/// ## On-Chain IDL Fetching
///
/// Anchor programs can store their IDL on-chain for dynamic loading:
///
/// ```dart
/// try {
///   // Fetch IDL from program's IDL account
///   final idl = await Idl.fetchFromAddress(programId, provider);
///   final program = Program(idl, programId, provider);
/// } on IdlError catch (e) {
///   // Handle IDL not found or invalid
///   print('Failed to fetch IDL: ${e.message}');
/// }
/// ```
///
/// ## TypeScript Compatibility
///
/// This IDL implementation is fully compatible with TypeScript Anchor IDLs:
///
/// | TypeScript Feature | Dart Support | Notes |
/// |-------------------|--------------|-------|
/// | Instructions | ✅ Complete | Full argument and account support |
/// | Accounts | ✅ Complete | Type definitions and constraints |
/// | Events | ✅ Complete | Event fields and discriminators |
/// | Errors | ✅ Complete | Custom error codes and messages |
/// | Types | ✅ Complete | All Borsh types + custom types |
/// | Constants | ✅ Complete | Program constants |
/// | Metadata | ✅ Complete | Version and deployment info |
///
/// ## Error Handling
///
/// ```dart
/// try {
///   final idl = Idl.fromJson(json);
/// } on IdlParseError catch (e) {
///   print('Failed to parse IDL: ${e.message}');
/// } on IdlValidationError catch (e) {
///   print('Invalid IDL structure: ${e.message}');
/// }
/// ```
library;

// Core IDL Types (Task 2.1)

/// ## The Main IDL Class
///
/// The `Idl` class represents a complete Anchor program interface definition.
/// It contains all the information needed to interact with an Anchor program
/// including instructions, accounts, events, errors, and custom types.
///
/// ### Constructor Parameters
///
/// - `instructions` - List of program instructions (required)
/// - `address` - Program's on-chain address (optional)
/// - `name` - Human-readable program name (optional)
/// - `version` - Program version string (optional)
/// - `metadata` - Additional metadata like spec version (optional)
/// - `docs` - Program documentation strings (optional)
/// - `accounts` - Account type definitions (optional)
/// - `events` - Event definitions for program events (optional)
/// - `errors` - Custom error code definitions (optional)
/// - `types` - Custom type definitions (optional)
/// - `constants` - Program constant definitions (optional)
///
/// ### Example
///
/// ```dart
/// final idl = Idl(
///   name: 'counter_program',
///   version: '0.1.0',
///   instructions: [
///     IdlInstruction(
///       name: 'initialize',
///       args: [IdlField(name: 'initial_count', type: IdlType.u64())],
///       accounts: [/* account definitions */],
///     ),
///   ],
///   accounts: [
///     IdlAccount(name: 'Counter', type: /* type definition */),
///   ],
/// );
/// ```
class Idl {
  const Idl({
    required this.instructions,
    this.address,
    this.name,
    this.version,
    this.metadata,
    this.docs,
    this.accounts,
    this.events,
    this.errors,
    this.types,
    this.constants,
  });

  /// Parse IDL from JSON
  factory Idl.fromJson(Map<String, dynamic> json) => Idl(
        address: json['address'] as String?,
        name: json['name'] as String?,
        version: json['version'] as String?,
        metadata: json['metadata'] != null
            ? IdlMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
            : null,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        instructions: (json['instructions'] as List<dynamic>)
            .map((e) => IdlInstruction.fromJson(e as Map<String, dynamic>))
            .toList(),
        accounts: (json['accounts'] as List<dynamic>?)
            ?.map((e) => IdlAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        events: (json['events'] as List<dynamic>?)
            ?.map((e) => IdlEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        errors: (json['errors'] as List<dynamic>?)
            ?.map((e) => IdlErrorCode.fromJson(e as Map<String, dynamic>))
            .toList(),
        types: (json['types'] as List<dynamic>?)
            ?.map((e) => IdlTypeDef.fromJson(e as Map<String, dynamic>))
            .toList(),
        constants: (json['constants'] as List<dynamic>?)
            ?.map((e) => IdlConst.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Program address (optional - can be provided separately)
  final String? address;

  /// Program name (for compatibility with traditional IDL format)
  final String? name;

  /// Program version (for compatibility with traditional IDL format)
  final String? version;

  /// Program metadata (optional for compatibility)
  final IdlMetadata? metadata;

  /// Optional documentation
  final List<String>? docs;

  /// List of program instructions
  final List<IdlInstruction> instructions;

  /// Optional account definitions
  final List<IdlAccount>? accounts;

  /// Optional event definitions
  final List<IdlEvent>? events;

  /// Optional error code definitions
  final List<IdlErrorCode>? errors;

  /// Optional custom type definitions
  final List<IdlTypeDef>? types;

  /// Optional program constants
  final List<IdlConst>? constants;

  /// Convert IDL to JSON
  Map<String, dynamic> toJson() => {
        if (address != null) 'address': address,
        if (name != null) 'name': name,
        if (version != null) 'version': version,
        if (metadata != null) 'metadata': metadata!.toJson(),
        if (docs != null) 'docs': docs,
        'instructions': instructions.map((e) => e.toJson()).toList(),
        if (accounts != null)
          'accounts': accounts!.map((e) => e.toJson()).toList(),
        if (events != null) 'events': events!.map((e) => e.toJson()).toList(),
        if (errors != null) 'errors': errors!.map((e) => e.toJson()).toList(),
        if (types != null) 'types': types!.map((e) => e.toJson()).toList(),
        if (constants != null)
          'constants': constants!.map((e) => e.toJson()).toList(),
      };

  /// Find instruction by name
  IdlInstruction? findInstruction(String name) {
    try {
      return instructions.firstWhere((instruction) => instruction.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Find account by name
  IdlAccount? findAccount(String name) {
    try {
      return accounts?.firstWhere((account) => account.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Find type definition by name
  IdlTypeDef? findType(String name) {
    try {
      return types?.firstWhere((type) => type.name == name);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() =>
      'Idl(address: $address, instructions: ${instructions.length})';
}

/// IDL metadata containing program information
class IdlMetadata {
  const IdlMetadata({
    required this.name,
    required this.version,
    required this.spec,
    this.description,
    this.repository,
    this.dependencies,
    this.contact,
    this.deployments,
  });

  factory IdlMetadata.fromJson(Map<String, dynamic> json) => IdlMetadata(
        name: json['name'] as String,
        version: json['version'] as String,
        spec: json['spec'] as String,
        description: json['description'] as String?,
        repository: json['repository'] as String?,
        dependencies: (json['dependencies'] as List<dynamic>?)
            ?.map((e) => IdlDependency.fromJson(e as Map<String, dynamic>))
            .toList(),
        contact: json['contact'] as String?,
        deployments: json['deployments'] != null
            ? IdlDeployments.fromJson(
                json['deployments'] as Map<String, dynamic>,
              )
            : null,
      );
  final String name;
  final String version;
  final String spec;
  final String? description;
  final String? repository;
  final List<IdlDependency>? dependencies;
  final String? contact;
  final IdlDeployments? deployments;

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'spec': spec,
        if (description != null) 'description': description,
        if (repository != null) 'repository': repository,
        if (dependencies != null)
          'dependencies': dependencies!.map((e) => e.toJson()).toList(),
        if (contact != null) 'contact': contact,
        if (deployments != null) 'deployments': deployments!.toJson(),
      };

  @override
  String toString() => 'IdlMetadata(name: $name, version: $version)';
}

/// Program dependency information
class IdlDependency {
  const IdlDependency({required this.name, required this.version});

  factory IdlDependency.fromJson(Map<String, dynamic> json) => IdlDependency(
        name: json['name'] as String,
        version: json['version'] as String,
      );
  final String name;
  final String version;

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
      };

  @override
  String toString() => 'IdlDependency(name: $name, version: $version)';
}

/// Program deployment addresses for different networks
class IdlDeployments {
  const IdlDeployments({
    this.mainnet,
    this.testnet,
    this.devnet,
    this.localnet,
  });

  factory IdlDeployments.fromJson(Map<String, dynamic> json) => IdlDeployments(
        mainnet: json['mainnet'] as String?,
        testnet: json['testnet'] as String?,
        devnet: json['devnet'] as String?,
        localnet: json['localnet'] as String?,
      );
  final String? mainnet;
  final String? testnet;
  final String? devnet;
  final String? localnet;

  Map<String, dynamic> toJson() => {
        if (mainnet != null) 'mainnet': mainnet,
        if (testnet != null) 'testnet': testnet,
        if (devnet != null) 'devnet': devnet,
        if (localnet != null) 'localnet': localnet,
      };

  @override
  String toString() => 'IdlDeployments(mainnet: $mainnet, devnet: $devnet)';
}

/// Program instruction definition
class IdlInstruction {
  const IdlInstruction({
    required this.name,
    required this.args,
    required this.accounts,
    this.docs,
    this.discriminator,
    this.returns,
  });

  factory IdlInstruction.fromJson(Map<String, dynamic> json) => IdlInstruction(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        args: (json['args'] as List<dynamic>? ??
                []) // Handle cases where args might be missing
            .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
            .toList(),
        accounts: (json['accounts'] as List<dynamic>? ??
                []) // Handle cases where accounts might be missing
            .map(
              (e) =>
                  IdlInstructionAccountItem.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        discriminator: (json['discriminator'] as List<dynamic>?)?.cast<int>(),
        returns: json['returns'] as String?,
      );
  final String name;
  final List<String>? docs;
  final List<IdlField> args;
  final List<IdlInstructionAccountItem> accounts;
  final IdlDiscriminator? discriminator;
  final String? returns;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'args': args.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        if (discriminator != null) 'discriminator': discriminator,
        if (returns != null) 'returns': returns,
      };

  @override
  String toString() => 'IdlInstruction(name: $name)';
}

/// Program account definition
class IdlAccount {
  const IdlAccount({
    required this.name,
    this.docs,
    required this.discriminator,
  });

  factory IdlAccount.fromJson(Map<String, dynamic> json) => IdlAccount(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        discriminator: (json['discriminator'] as List<dynamic>).cast<int>(),
      );
  final String name;
  final List<String>? docs;
  final IdlDiscriminator discriminator;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'discriminator': discriminator,
      };

  @override
  String toString() => 'IdlAccount(name: $name)';
}

/// Program event definition
class IdlEvent {
  const IdlEvent({
    required this.name,
    required this.fields,
    this.docs,
    this.discriminator,
  });

  factory IdlEvent.fromJson(Map<String, dynamic> json) => IdlEvent(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        fields: (json['fields'] as List<dynamic>)
            .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
            .toList(),
        discriminator: (json['discriminator'] as List<dynamic>?)?.cast<int>(),
      );
  final String name;
  final List<String>? docs;
  final List<IdlField> fields;
  final IdlDiscriminator? discriminator;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'fields': fields.map((e) => e.toJson()).toList(),
        if (discriminator != null) 'discriminator': discriminator,
      };

  @override
  String toString() => 'IdlEvent(name: $name)';
}

/// Program error code definition
class IdlErrorCode {
  const IdlErrorCode({
    required this.code,
    required this.name,
    this.msg,
  });

  factory IdlErrorCode.fromJson(Map<String, dynamic> json) => IdlErrorCode(
        code: json['code'] as int,
        name: json['name'] as String,
        msg: json['msg'] as String?,
      );
  final int code;
  final String name;
  final String? msg;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        if (msg != null) 'msg': msg,
      };

  @override
  String toString() => 'IdlErrorCode(code: $code, name: $name)';
}

/// Discriminator for identifying different types on-chain
typedef IdlDiscriminator = List<int>;

/// Field definition for structs, enums, and instruction arguments
class IdlField {
  const IdlField({required this.name, required this.type, this.docs});

  factory IdlField.fromJson(Map<String, dynamic> json) => IdlField(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        type: IdlType.fromJson(json['type']), // type can be string or map
      );
  final String name;
  final List<String>? docs;
  final IdlType type;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'type': type.toJson(),
      };

  @override
  String toString() => 'IdlField(name: $name, type: ${type.kind})';
}

/// Base class for PDA seeds
abstract class IdlSeed {
  const IdlSeed({required this.kind});

  factory IdlSeed.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'const':
        return IdlSeedConst.fromJson(json);
      case 'arg':
        return IdlSeedArg.fromJson(json);
      case 'account':
        return IdlSeedAccount.fromJson(json);
      default:
        throw ArgumentError('Unknown seed kind: $kind');
    }
  }
  final String kind;

  Map<String, dynamic> toJson();
}

/// Constant seed for PDA derivation
class IdlSeedConst extends IdlSeed {
  const IdlSeedConst({required this.value}) : super(kind: 'const');

  factory IdlSeedConst.fromJson(Map<String, dynamic> json) => IdlSeedConst(
        value: (json['value'] as List<dynamic>).cast<int>(),
      );
  final String type = 'bytes';
  final List<int> value;

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'type': type,
        'value': value,
      };

  @override
  String toString() => 'IdlSeedConst(value: $value)';
}

/// Argument-based seed for PDA derivation
class IdlSeedArg extends IdlSeed {
  const IdlSeedArg({required this.type, required this.path})
      : super(kind: 'arg');

  factory IdlSeedArg.fromJson(Map<String, dynamic> json) => IdlSeedArg(
        type: IdlType.fromJson(json['type']),
        path: json['path'] as String,
      );
  final IdlType type;
  final String path;

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'type': type.toJson(),
        'path': path,
      };

  @override
  String toString() => 'IdlSeedArg(path: $path)';
}

/// Account-based seed for PDA derivation
class IdlSeedAccount extends IdlSeed {
  const IdlSeedAccount({required this.type, required this.path})
      : super(kind: 'account');

  factory IdlSeedAccount.fromJson(Map<String, dynamic> json) => IdlSeedAccount(
        type: IdlType.fromJson(json['type']),
        path: json['path'] as String,
      );
  final IdlType type;
  final String path;

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'type': type.toJson(),
        'path': path,
      };

  @override
  String toString() => 'IdlSeedAccount(path: $path)';
}

/// PDA (Program Derived Address) specification
class IdlPda {
  const IdlPda({required this.seeds, this.programId});

  factory IdlPda.fromJson(Map<String, dynamic> json) => IdlPda(
        seeds: (json['seeds'] as List<dynamic>)
            .map((e) => IdlSeed.fromJson(e as Map<String, dynamic>))
            .toList(),
        programId: json['programId'] != null
            ? IdlSeedAccount.fromJson(json['programId'] as Map<String, dynamic>)
            : null,
      );
  final List<IdlSeed> seeds;
  final IdlSeedAccount? programId;

  Map<String, dynamic> toJson() => {
        'seeds': seeds.map((e) => e.toJson()).toList(),
        if (programId != null) 'programId': programId!.toJson(),
      };

  @override
  String toString() => 'IdlPda(seeds: ${seeds.length})';
}

/// Base class for instruction account items (supports both single accounts and account groups)
abstract class IdlInstructionAccountItem {
  const IdlInstructionAccountItem({required this.name, this.docs});

  factory IdlInstructionAccountItem.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('accounts')) {
      return IdlInstructionAccounts.fromJson(json);
    } else {
      return IdlInstructionAccount.fromJson(json);
    }
  }
  final String name;
  final List<String>? docs;

  Map<String, dynamic> toJson();
}

/// Single instruction account with PDA support
class IdlInstructionAccount extends IdlInstructionAccountItem {
  const IdlInstructionAccount({
    required super.name,
    super.docs,
    this.writable = false,
    this.signer = false,
    this.optional = false,
    this.address,
    this.pda,
    this.relations,
  });

  factory IdlInstructionAccount.fromJson(Map<String, dynamic> json) =>
      IdlInstructionAccount(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        writable: json['writable'] as bool? ?? json['isMut'] as bool? ?? false,
        signer: json['signer'] as bool? ?? json['isSigner'] as bool? ?? false,
        optional: json['optional'] as bool? ?? false,
        address: json['address'] as String?,
        pda: json['pda'] != null
            ? IdlPda.fromJson(json['pda'] as Map<String, dynamic>)
            : null,
        relations: (json['relations'] as List<dynamic>?)?.cast<String>(),
      );
  final bool writable;
  final bool signer;
  final bool optional;
  final String? address;
  final IdlPda? pda;
  final List<String>? relations;

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'writable': writable,
        'signer': signer,
        'optional': optional,
        if (address != null) 'address': address,
        if (pda != null) 'pda': pda!.toJson(),
        if (relations != null) 'relations': relations,
      };

  bool get isMut => writable;
  bool get isSigner => signer;

  @override
  String toString() =>
      'IdlInstructionAccount(name: $name, writable: $writable, signer: $signer, optional: $optional)';
}

/// Group of instruction accounts (composite accounts)
class IdlInstructionAccounts extends IdlInstructionAccountItem {
  const IdlInstructionAccounts({
    required super.name,
    required this.accounts,
    super.docs,
  });

  factory IdlInstructionAccounts.fromJson(Map<String, dynamic> json) =>
      IdlInstructionAccounts(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        accounts: (json['accounts'] as List<dynamic>)
            .map(
              (e) =>
                  IdlInstructionAccountItem.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
  final List<IdlInstructionAccountItem> accounts;

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'accounts': accounts.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() =>
      'IdlInstructionAccounts(name: $name, accounts: ${accounts.length})';
}

/// Constant definition
class IdlConst {
  const IdlConst({required this.name, required this.type, required this.value});

  factory IdlConst.fromJson(Map<String, dynamic> json) => IdlConst(
        name: json['name'] as String,
        type: json['type'],
        value: json['value'] as String,
      );
  final String name;
  final dynamic type;
  final String value;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'value': value,
      };

  @override
  String toString() => 'IdlConst(name: $name, value: $value)';
}

/// Type definition
class IdlTypeDef {
  const IdlTypeDef({
    required this.name,
    required this.type,
    this.docs,
    this.generics,
    this.serialization,
    this.repr,
  });

  factory IdlTypeDef.fromJson(Map<String, dynamic> json) => IdlTypeDef(
        name: json['name'] as String,
        docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
        type: IdlTypeDefType.fromJson(json['type'] as Map<String, dynamic>),
        generics: json['generics'] != null
            ? (json['generics'] as List<dynamic>)
                .map((e) =>
                    IdlTypeDefGeneric.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        serialization: json['serialization'] as String?,
        repr: json['repr'] != null
            ? IdlRepr.fromJson(json['repr'] as Map<String, dynamic>)
            : null,
      );
  final String name;
  final List<String>? docs;
  final IdlTypeDefType type;
  final List<IdlTypeDefGeneric>? generics;
  final String? serialization;
  final IdlRepr? repr;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'type': type.toJson(),
        if (generics != null)
          'generics': generics!.map((e) => e.toJson()).toList(),
        if (serialization != null) 'serialization': serialization,
        if (repr != null) 'repr': repr!.toJson(),
      };

  @override
  String toString() => 'IdlTypeDef(name: $name)';
}

/// Generic type parameter definition for type definitions
class IdlTypeDefGeneric {
  const IdlTypeDefGeneric({
    required this.name,
    required this.kind,
  });

  factory IdlTypeDefGeneric.fromJson(Map<String, dynamic> json) =>
      IdlTypeDefGeneric(
        name: json['name'] as String,
        kind: json['kind'] as String,
      );

  final String name;
  final String kind;

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
      };

  @override
  String toString() => 'IdlTypeDefGeneric(name: $name, kind: $kind)';
}

/// Representation attribute for type definitions
class IdlRepr {
  const IdlRepr({
    required this.kind,
    this.modifier,
  });

  factory IdlRepr.fromJson(Map<String, dynamic> json) => IdlRepr(
        kind: json['kind'] as String,
        modifier: json['modifier'] as String?,
      );

  final String kind;
  final String? modifier;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (modifier != null) 'modifier': modifier,
      };

  @override
  String toString() =>
      'IdlRepr(kind: $kind${modifier != null ? ', modifier: $modifier' : ''})';
}

/// Type definition type (struct, enum, type alias)
class IdlTypeDefType {
  const IdlTypeDefType({
    required this.kind,
    this.fields,
    this.variants,
    this.alias,
  });

  factory IdlTypeDefType.fromJson(Map<String, dynamic> json) => IdlTypeDefType(
        kind: json['kind'] as String,
        fields: json['fields'] != null
            ? (json['fields'] as List<dynamic>)
                .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        variants: json['variants'] != null
            ? (json['variants'] as List<dynamic>)
                .map((e) => IdlEnumVariant.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        alias: json['alias'] != null ? IdlType.fromJson(json['alias']) : null,
      );
  final String kind;
  final List<IdlField>? fields;
  final List<IdlEnumVariant>? variants;
  final IdlType? alias;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (fields != null) 'fields': fields!.map((e) => e.toJson()).toList(),
        if (variants != null)
          'variants': variants!.map((e) => e.toJson()).toList(),
        if (alias != null) 'alias': alias!.toJson(),
      };
}

/// Enum variant definition
class IdlEnumVariant {
  const IdlEnumVariant({required this.name, this.fields});

  factory IdlEnumVariant.fromJson(Map<String, dynamic> json) => IdlEnumVariant(
        name: json['name'] as String,
        fields: json['fields'] != null
            ? (json['fields'] as List<dynamic>)
                .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );
  final String name;
  final List<IdlField>? fields;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (fields != null) 'fields': fields!.map((e) => e.toJson()).toList(),
      };
}

/// Type specification for fields and arguments
class IdlType {
  const IdlType({
    required this.kind,
    this.inner,
    this.size,
    this.defined,
    this.generic,
  });

  factory IdlType.fromJson(dynamic json) {
    if (json is String) {
      // Simple types like "u8", "string", "bool"
      return IdlType(kind: json);
    } else if (json is Map<String, dynamic>) {
      // Standard Anchor IDL type representation:
      // { "vec": <type> }, { "option": <type> }, { "array": [<type>, <size>] }, { "defined": "<name>" }
      // Or, if "kind" is explicitly provided (less common for this part of IDL but good to handle)
      if (json.containsKey('kind')) {
        final String kind = json['kind'] as String;
        final IdlType? inner =
            json.containsKey('inner') ? IdlType.fromJson(json['inner']) : null;
        final int? size = json['size']
            as int?; // Typically for 'array' if structured this way
        final IdlDefinedType? definedType = json['defined'] != null
            ? (json['defined'] is String
                ? IdlDefinedType(name: json['defined'] as String)
                : IdlDefinedType.fromJson(
                    json['defined'] as Map<String, dynamic>))
            : null;
        final String? generic = json['generic'] as String?;

        // If kind is 'array' but inner/size are not directly under 'inner'/'size' but under the kind key
        if (kind == 'array' && json.containsKey(kind) && json[kind] is List) {
          final list = json[kind] as List;
          if (list.length == 2) {
            return IdlType(
              kind: kind,
              inner: IdlType.fromJson(list[0]),
              size: list[1] as int,
              defined: definedType,
              generic: generic,
            );
          }
        }
        return IdlType(
          kind: kind,
          inner: inner,
          size: size,
          defined: definedType,
          generic: generic,
        );
      }

      if (json.keys.length == 1) {
        final kind = json.keys.first;
        final value = json.values.first;

        switch (kind) {
          case 'vec':
          case 'option':
            return IdlType(kind: kind, inner: IdlType.fromJson(value));
          case 'array':
            if (value is List && value.length == 2) {
              return IdlType(
                kind: kind,
                inner: IdlType.fromJson(value[0]),
                size: value[1] as int,
              );
            }
            throw ArgumentError('Invalid array type definition: $json');
          case 'defined':
            if (value is String) {
              return IdlType(kind: kind, defined: IdlDefinedType(name: value));
            } else if (value is Map<String, dynamic>) {
              return IdlType(
                  kind: kind, defined: IdlDefinedType.fromJson(value));
            }
            throw ArgumentError('Invalid defined type definition: $json');
          default:
            // This case handles simple types that might have been incorrectly wrapped in a map
            // or custom types not following the standard structure.
            // For robustness, if it's a single key map and not a known complex type,
            // assume the key is the kind.
            return IdlType(kind: kind);
        }
      }
      throw ArgumentError(
        'Ambiguous or invalid IDL type map: $json. Expected a single key for complex types or an explicit "kind" field.',
      );
    } else {
      throw ArgumentError('Invalid type definition format: $json');
    }
  }
  final String kind;
  final IdlType? inner;
  final int? size;
  final IdlDefinedType? defined;
  final String? generic;

  // Static factory methods for better API compatibility
  static IdlType bool() => const IdlType(kind: 'bool');
  static IdlType u8() => const IdlType(kind: 'u8');
  static IdlType i8() => const IdlType(kind: 'i8');
  static IdlType u16() => const IdlType(kind: 'u16');
  static IdlType i16() => const IdlType(kind: 'i16');
  static IdlType u32() => const IdlType(kind: 'u32');
  static IdlType i32() => const IdlType(kind: 'i32');
  static IdlType u64() => const IdlType(kind: 'u64');
  static IdlType i64() => const IdlType(kind: 'i64');
  static IdlType string() => const IdlType(kind: 'string');
  static IdlType publicKey() => const IdlType(kind: 'pubkey');
  static IdlType vec(IdlType inner) => IdlType(kind: 'vec', inner: inner);
  static IdlType option(IdlType inner) => IdlType(kind: 'option', inner: inner);
  static IdlType array(IdlType inner, int size) =>
      IdlType(kind: 'array', inner: inner, size: size);
  static IdlType definedType(String name) =>
      IdlType(kind: 'defined', defined: IdlDefinedType(name: name));

  dynamic toJson() {
    // Standard Anchor IDL JSON representation
    switch (kind) {
      case 'vec':
        return {'vec': inner?.toJson()};
      case 'option':
        return {'option': inner?.toJson()};
      case 'array':
        return {
          'array': [inner?.toJson(), size],
        };
      case 'defined':
        return {'defined': defined?.toJson()};
      case 'generic':
        return {'generic': generic};
      default: // Simple types: "u8", "string", "bool", "publicKey", etc.
        return kind;
    }
  }

  @override
  String toString() => 'IdlType(kind: $kind)';
}

/// Generic parameter specification for defined types
class IdlTypeGeneric {
  const IdlTypeGeneric({
    required this.kind,
    this.type,
    this.value,
  });

  factory IdlTypeGeneric.fromJson(Map<String, dynamic> json) => IdlTypeGeneric(
        kind: json['kind'] as String,
        type: json['type'] != null ? IdlType.fromJson(json['type']) : null,
        value: json['value'] as String?,
      );

  final String kind;
  final IdlType? type;
  final String? value;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (type != null) 'type': type!.toJson(),
        if (value != null) 'value': value,
      };

  @override
  String toString() => 'IdlTypeGeneric(kind: $kind)';
}

/// Defined type with optional generic parameters
class IdlDefinedType {
  const IdlDefinedType({
    required this.name,
    this.generics = const [],
  });

  factory IdlDefinedType.fromJson(Map<String, dynamic> json) => IdlDefinedType(
        name: json['name'] as String,
        generics: json['generics'] != null
            ? (json['generics'] as List<dynamic>)
                .map((e) => IdlTypeGeneric.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
      );

  final String name;
  final List<IdlTypeGeneric> generics;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (generics.isNotEmpty)
          'generics': generics.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() => 'IdlDefinedType(name: $name)';
}

// Factory functions for common types
IdlType idlTypeBool() => const IdlType(kind: 'bool');
IdlType idlTypeU8() => const IdlType(kind: 'u8');
IdlType idlTypeI8() => const IdlType(kind: 'i8');
IdlType idlTypeU16() => const IdlType(kind: 'u16');
IdlType idlTypeI16() => const IdlType(kind: 'i16');
IdlType idlTypeU32() => const IdlType(kind: 'u32');
IdlType idlTypeI32() => const IdlType(kind: 'i32');
IdlType idlTypeU64() => const IdlType(kind: 'u64');
IdlType idlTypeI64() => const IdlType(kind: 'i64');
IdlType idlTypeString() => const IdlType(kind: 'string');
IdlType idlTypePubkey() => const IdlType(kind: 'pubkey');
IdlType idlTypeVec(IdlType inner) => IdlType(kind: 'vec', inner: inner);
IdlType idlTypeOption(IdlType inner) => IdlType(kind: 'option', inner: inner);
IdlType idlTypeArray(IdlType inner, int size) =>
    IdlType(kind: 'array', inner: inner, size: size);
IdlType idlTypeDefined(String name) =>
    IdlType(kind: 'defined', defined: IdlDefinedType(name: name));

/// Utility function to check if an account item is a composite accounts group
bool isCompositeAccounts(IdlInstructionAccountItem accountItem) =>
    accountItem is IdlInstructionAccounts;
