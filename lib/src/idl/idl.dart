/// IDL (Interface Definition Language) system with essential PDA support
///
/// This module handles parsing, validation, and management of Anchor IDL files
/// which define the interface and structure of Anchor programs.

library;

// Core IDL Types (Task 2.1)

/// The main IDL structure that defines an Anchor program interface
class Idl {
  /// Program address (optional - can be provided separately)
  final String? address;

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

  const Idl({
    this.address,
    this.metadata,
    this.docs,
    required this.instructions,
    this.accounts,
    this.events,
    this.errors,
    this.types,
    this.constants,
  });

  /// Parse IDL from JSON
  factory Idl.fromJson(Map<String, dynamic> json) {
    return Idl(
      address: json['address'] as String?,
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
  }

  /// Convert IDL to JSON
  Map<String, dynamic> toJson() {
    return {
      if (address != null) 'address': address,
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
  }

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
  final String name;
  final String version;
  final String spec;
  final String? description;
  final String? repository;
  final List<IdlDependency>? dependencies;
  final String? contact;
  final IdlDeployments? deployments;

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

  factory IdlMetadata.fromJson(Map<String, dynamic> json) {
    return IdlMetadata(
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
          ? IdlDeployments.fromJson(json['deployments'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
  }

  @override
  String toString() => 'IdlMetadata(name: $name, version: $version)';
}

/// Program dependency information
class IdlDependency {
  final String name;
  final String version;

  const IdlDependency({required this.name, required this.version});

  factory IdlDependency.fromJson(Map<String, dynamic> json) {
    return IdlDependency(
      name: json['name'] as String,
      version: json['version'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
    };
  }

  @override
  String toString() => 'IdlDependency(name: $name, version: $version)';
}

/// Program deployment addresses for different networks
class IdlDeployments {
  final String? mainnet;
  final String? testnet;
  final String? devnet;
  final String? localnet;

  const IdlDeployments({
    this.mainnet,
    this.testnet,
    this.devnet,
    this.localnet,
  });

  factory IdlDeployments.fromJson(Map<String, dynamic> json) {
    return IdlDeployments(
      mainnet: json['mainnet'] as String?,
      testnet: json['testnet'] as String?,
      devnet: json['devnet'] as String?,
      localnet: json['localnet'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (mainnet != null) 'mainnet': mainnet,
      if (testnet != null) 'testnet': testnet,
      if (devnet != null) 'devnet': devnet,
      if (localnet != null) 'localnet': localnet,
    };
  }

  @override
  String toString() => 'IdlDeployments(mainnet: $mainnet, devnet: $devnet)';
}

/// Program instruction definition
class IdlInstruction {
  final String name;
  final List<String>? docs;
  final List<IdlField> args;
  final List<IdlInstructionAccountItem> accounts;
  final IdlDiscriminator? discriminator;
  final String? returns;

  const IdlInstruction({
    required this.name,
    this.docs,
    required this.args,
    required this.accounts,
    this.discriminator,
    this.returns,
  });

  factory IdlInstruction.fromJson(Map<String, dynamic> json) {
    return IdlInstruction(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      args: (json['args'] as List<dynamic>? ??
              []) // Handle cases where args might be missing
          .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
          .toList(),
      accounts: (json['accounts'] as List<dynamic>? ??
              []) // Handle cases where accounts might be missing
          .map((e) =>
              IdlInstructionAccountItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      discriminator: (json['discriminator'] as List<dynamic>?)?.cast<int>(),
      returns: json['returns'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'args': args.map((e) => e.toJson()).toList(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      if (discriminator != null) 'discriminator': discriminator,
      if (returns != null) 'returns': returns,
    };
  }

  @override
  String toString() => 'IdlInstruction(name: $name)';
}

/// Program account definition
class IdlAccount {
  final String name;
  final List<String>? docs;
  final IdlTypeDefType type;
  final IdlDiscriminator? discriminator;

  const IdlAccount({
    required this.name,
    this.docs,
    required this.type,
    this.discriminator,
  });

  factory IdlAccount.fromJson(Map<String, dynamic> json) {
    return IdlAccount(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      type: IdlTypeDefType.fromJson(json['type'] as Map<String, dynamic>),
      discriminator: (json['discriminator'] as List<dynamic>?)?.cast<int>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'type': type.toJson(),
      if (discriminator != null) 'discriminator': discriminator,
    };
  }

  @override
  String toString() => 'IdlAccount(name: $name)';
}

/// Program event definition
class IdlEvent {
  final String name;
  final List<String>? docs;
  final List<IdlField> fields;
  final IdlDiscriminator? discriminator;

  const IdlEvent({
    required this.name,
    this.docs,
    required this.fields,
    this.discriminator,
  });

  factory IdlEvent.fromJson(Map<String, dynamic> json) {
    return IdlEvent(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      fields: (json['fields'] as List<dynamic>)
          .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
          .toList(),
      discriminator: (json['discriminator'] as List<dynamic>?)?.cast<int>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'fields': fields.map((e) => e.toJson()).toList(),
      if (discriminator != null) 'discriminator': discriminator,
    };
  }

  @override
  String toString() => 'IdlEvent(name: $name)';
}

/// Program error code definition
class IdlErrorCode {
  final int code;
  final String name;
  final String? msg;

  const IdlErrorCode({
    required this.code,
    required this.name,
    this.msg,
  });

  factory IdlErrorCode.fromJson(Map<String, dynamic> json) {
    return IdlErrorCode(
      code: json['code'] as int,
      name: json['name'] as String,
      msg: json['msg'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      if (msg != null) 'msg': msg,
    };
  }

  @override
  String toString() => 'IdlErrorCode(code: $code, name: $name)';
}

/// Discriminator for identifying different types on-chain
typedef IdlDiscriminator = List<int>;

/// Field definition for structs, enums, and instruction arguments
class IdlField {
  final String name;
  final List<String>? docs;
  final IdlType type;

  const IdlField({required this.name, this.docs, required this.type});

  factory IdlField.fromJson(Map<String, dynamic> json) {
    return IdlField(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      type: IdlType.fromJson(json['type']), // type can be string or map
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'type': type.toJson(),
    };
  }

  @override
  String toString() => 'IdlField(name: $name, type: ${type.kind})';
}

/// Base class for PDA seeds
abstract class IdlSeed {
  final String kind;

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

  Map<String, dynamic> toJson();
}

/// Constant seed for PDA derivation
class IdlSeedConst extends IdlSeed {
  final String type = 'bytes';
  final List<int> value;

  const IdlSeedConst({required this.value}) : super(kind: 'const');

  factory IdlSeedConst.fromJson(Map<String, dynamic> json) {
    return IdlSeedConst(
      value: (json['value'] as List<dynamic>).cast<int>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'type': type,
      'value': value,
    };
  }

  @override
  String toString() => 'IdlSeedConst(value: $value)';
}

/// Argument-based seed for PDA derivation
class IdlSeedArg extends IdlSeed {
  final IdlType type;
  final String path;

  const IdlSeedArg({required this.type, required this.path})
      : super(kind: 'arg');

  factory IdlSeedArg.fromJson(Map<String, dynamic> json) {
    return IdlSeedArg(
      type: IdlType.fromJson(json['type']),
      path: json['path'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'type': type.toJson(),
      'path': path,
    };
  }

  @override
  String toString() => 'IdlSeedArg(path: $path)';
}

/// Account-based seed for PDA derivation
class IdlSeedAccount extends IdlSeed {
  final IdlType type;
  final String path;

  const IdlSeedAccount({required this.type, required this.path})
      : super(kind: 'account');

  factory IdlSeedAccount.fromJson(Map<String, dynamic> json) {
    return IdlSeedAccount(
      type: IdlType.fromJson(json['type']),
      path: json['path'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'type': type.toJson(),
      'path': path,
    };
  }

  @override
  String toString() => 'IdlSeedAccount(path: $path)';
}

/// PDA (Program Derived Address) specification
class IdlPda {
  final List<IdlSeed> seeds;
  final IdlSeedAccount? programId;

  const IdlPda({required this.seeds, this.programId});

  factory IdlPda.fromJson(Map<String, dynamic> json) {
    return IdlPda(
      seeds: (json['seeds'] as List<dynamic>)
          .map((e) => IdlSeed.fromJson(e as Map<String, dynamic>))
          .toList(),
      programId: json['programId'] != null
          ? IdlSeedAccount.fromJson(json['programId'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seeds': seeds.map((e) => e.toJson()).toList(),
      if (programId != null) 'programId': programId!.toJson(),
    };
  }

  @override
  String toString() => 'IdlPda(seeds: ${seeds.length})';
}

/// Base class for instruction account items (supports both single accounts and account groups)
abstract class IdlInstructionAccountItem {
  final String name;
  final List<String>? docs;

  const IdlInstructionAccountItem({required this.name, this.docs});

  factory IdlInstructionAccountItem.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('accounts')) {
      return IdlInstructionAccounts.fromJson(json);
    } else {
      return IdlInstructionAccount.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

/// Single instruction account with PDA support
class IdlInstructionAccount extends IdlInstructionAccountItem {
  final bool writable;
  final bool signer;
  final bool optional;
  final String? address;
  final IdlPda? pda;
  final List<String>? relations;

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

  factory IdlInstructionAccount.fromJson(Map<String, dynamic> json) {
    return IdlInstructionAccount(
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
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'writable': writable,
      'signer': signer,
      'optional': optional,
      if (address != null) 'address': address,
      if (pda != null) 'pda': pda!.toJson(),
      if (relations != null) 'relations': relations,
    };
  }

  bool get isMut => writable;
  bool get isSigner => signer;

  @override
  String toString() =>
      'IdlInstructionAccount(name: $name, writable: $writable, signer: $signer, optional: $optional)';
}

/// Group of instruction accounts (composite accounts)
class IdlInstructionAccounts extends IdlInstructionAccountItem {
  final List<IdlInstructionAccountItem> accounts;

  const IdlInstructionAccounts({
    required super.name,
    super.docs,
    required this.accounts,
  });

  factory IdlInstructionAccounts.fromJson(Map<String, dynamic> json) {
    return IdlInstructionAccounts(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      accounts: (json['accounts'] as List<dynamic>)
          .map((e) =>
              IdlInstructionAccountItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'accounts': accounts.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'IdlInstructionAccounts(name: $name, accounts: ${accounts.length})';
}

/// Constant definition
class IdlConst {
  final String name;
  final dynamic type;
  final String value;

  const IdlConst({required this.name, required this.type, required this.value});

  factory IdlConst.fromJson(Map<String, dynamic> json) {
    return IdlConst(
      name: json['name'] as String,
      type: json['type'],
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'value': value,
    };
  }

  @override
  String toString() => 'IdlConst(name: $name, value: $value)';
}

/// Type definition
class IdlTypeDef {
  final String name;
  final List<String>? docs;
  final IdlTypeDefType type;

  const IdlTypeDef({required this.name, this.docs, required this.type});

  factory IdlTypeDef.fromJson(Map<String, dynamic> json) {
    return IdlTypeDef(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      type: IdlTypeDefType.fromJson(json['type'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (docs != null) 'docs': docs,
      'type': type.toJson(),
    };
  }

  @override
  String toString() => 'IdlTypeDef(name: $name)';
}

/// Type definition type (struct, enum, etc.)
class IdlTypeDefType {
  final String kind;
  final List<IdlField>? fields;
  final List<IdlEnumVariant>? variants;

  const IdlTypeDefType({
    required this.kind,
    this.fields,
    this.variants,
  });

  factory IdlTypeDefType.fromJson(Map<String, dynamic> json) {
    return IdlTypeDefType(
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      if (fields != null) 'fields': fields!.map((e) => e.toJson()).toList(),
      if (variants != null)
        'variants': variants!.map((e) => e.toJson()).toList(),
    };
  }
}

/// Enum variant definition
class IdlEnumVariant {
  final String name;
  final List<IdlField>? fields;

  const IdlEnumVariant({required this.name, this.fields});

  factory IdlEnumVariant.fromJson(Map<String, dynamic> json) {
    return IdlEnumVariant(
      name: json['name'] as String,
      fields: json['fields'] != null
          ? (json['fields'] as List<dynamic>)
              .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (fields != null) 'fields': fields!.map((e) => e.toJson()).toList(),
    };
  }
}

/// Type specification for fields and arguments
class IdlType {
  final String kind;
  final IdlType? inner;
  final int? size;
  final String? defined;

  const IdlType({
    required this.kind,
    this.inner,
    this.size,
    this.defined,
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
        final String? definedName = json['defined'] as String?;

        // If kind is 'array' but inner/size are not directly under 'inner'/'size' but under the kind key
        if (kind == 'array' && json.containsKey(kind) && json[kind] is List) {
          final list = json[kind] as List;
          if (list.length == 2) {
            return IdlType(
                kind: kind,
                inner: IdlType.fromJson(list[0]),
                size: list[1] as int,
                defined: definedName);
          }
        }
        return IdlType(
            kind: kind, inner: inner, size: size, defined: definedName);
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
            return IdlType(kind: kind, defined: value as String);
          default:
            // This case handles simple types that might have been incorrectly wrapped in a map
            // or custom types not following the standard structure.
            // For robustness, if it's a single key map and not a known complex type,
            // assume the key is the kind.
            return IdlType(kind: kind);
        }
      }
      throw ArgumentError(
          'Ambiguous or invalid IDL type map: $json. Expected a single key for complex types or an explicit "kind" field.');
    } else {
      throw ArgumentError('Invalid type definition format: $json');
    }
  }

  dynamic toJson() {
    // Standard Anchor IDL JSON representation
    switch (kind) {
      case 'vec':
        return {'vec': inner?.toJson()};
      case 'option':
        return {'option': inner?.toJson()};
      case 'array':
        return {
          'array': [inner?.toJson(), size]
        };
      case 'defined':
        return {'defined': defined};
      default: // Simple types: "u8", "string", "bool", "publicKey", etc.
        return kind;
    }
  }

  @override
  String toString() => 'IdlType(kind: $kind)';
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
IdlType idlTypeDefined(String name) => IdlType(kind: 'defined', defined: name);

/// Utility function to check if an account item is a composite accounts group
bool isCompositeAccounts(IdlInstructionAccountItem accountItem) {
  return accountItem is IdlInstructionAccounts;
}
