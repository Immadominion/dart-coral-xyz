/// Account Definition Metadata System
///
/// This module provides comprehensive account definition system matching TypeScript's
/// IDL-based account metadata handling with complete type information, field metadata,
/// and validation requirements.
library;

import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/error/error.dart';

/// Comprehensive account definition with metadata handling
class AccountDefinition {

  const AccountDefinition({
    required this.name,
    this.docs,
    this.discriminator,
    required this.type,
    required this.fields,
    required this.validationRules,
    required this.structureMetadata,
    this.inheritanceInfo,
    this.versionInfo,
  });

  /// Create AccountDefinition from IDL account
  factory AccountDefinition.fromIdlAccount(
    IdlAccount idlAccount,
    List<IdlTypeDef>? types,
  ) {
    final typeDef = types?.firstWhere(
      (t) => t.name == idlAccount.name,
      orElse: () => throw IdlError(
          'Type definition not found for account: ${idlAccount.name}'),
    );

    if (typeDef == null) {
      throw IdlError(
          'Type definition required for account: ${idlAccount.name}');
    }

    // Extract fields from type definition
    final fields = _extractFieldDefinitions(typeDef.type, types ?? []);

    // Create validation rules based on account structure
    final validationRules = _createValidationRules(fields, idlAccount);

    // Create structure metadata
    final structureMetadata = _createStructureMetadata(fields, typeDef);

    return AccountDefinition(
      name: idlAccount.name,
      docs: idlAccount.docs,
      discriminator: idlAccount.discriminator,
      type: idlAccount.type,
      fields: fields,
      validationRules: validationRules,
      structureMetadata: structureMetadata,
      versionInfo: _extractVersionInfo(typeDef),
    );
  }
  /// Account name from IDL
  final String name;

  /// Optional documentation
  final List<String>? docs;

  /// Account discriminator for identification
  final List<int>? discriminator;

  /// Account type definition containing fields
  final IdlTypeDefType type;

  /// Field definitions with metadata
  final List<FieldDefinition> fields;

  /// Account validation rules
  final AccountValidationRules validationRules;

  /// Account structure metadata
  final AccountStructureMetadata structureMetadata;

  /// Optional account inheritance information
  final AccountInheritanceInfo? inheritanceInfo;

  /// Account versioning information
  final AccountVersionInfo? versionInfo;

  /// Extract field definitions from type definition
  static List<FieldDefinition> _extractFieldDefinitions(
    IdlTypeDefType typeDefType,
    List<IdlTypeDef> allTypes,
  ) {
    final fields = <FieldDefinition>[];

    if (typeDefType.kind == 'struct' && typeDefType.fields != null) {
      for (final field in typeDefType.fields!) {
        fields.add(FieldDefinition.fromIdlField(field, allTypes));
      }
    }

    return fields;
  }

  /// Create validation rules based on field structure
  static AccountValidationRules _createValidationRules(
    List<FieldDefinition> fields,
    IdlAccount account,
  ) {
    final requiredFields =
        fields.where((f) => f.isRequired).map((f) => f.name).toList();
    final optionalFields =
        fields.where((f) => !f.isRequired).map((f) => f.name).toList();

    // Calculate minimum size: discriminator + required fields
    int minSize = 8; // discriminator
    for (final field in fields.where((f) => f.isRequired)) {
      minSize += field.typeInfo.minimumSize ?? 0;
    }

    return AccountValidationRules(
      requireDiscriminator: account.discriminator != null,
      requiredFields: requiredFields,
      optionalFields: optionalFields,
      minimumSize: minSize,
      allowPartialData: false,
      fieldConstraints: _createFieldConstraints(fields),
    );
  }

  /// Create field constraints
  static Map<String, FieldConstraint> _createFieldConstraints(
      List<FieldDefinition> fields,) {
    final constraints = <String, FieldConstraint>{};

    for (final field in fields) {
      constraints[field.name] = FieldConstraint(
        fieldName: field.name,
        isRequired: field.isRequired,
        typeConstraint: field.typeInfo.constraint,
        sizeConstraint: field.typeInfo.minimumSize != null
            ? SizeConstraint(min: field.typeInfo.minimumSize)
            : null,
      );
    }

    return constraints;
  }

  /// Create structure metadata
  static AccountStructureMetadata _createStructureMetadata(
    List<FieldDefinition> fields,
    IdlTypeDef typeDef,
  ) {
    final fixedFields = fields.where((f) => f.typeInfo.isFixedSize).toList();
    final variableFields =
        fields.where((f) => !f.typeInfo.isFixedSize).toList();

    int? fixedSize;
    if (variableFields.isEmpty) {
      fixedSize = 8; // discriminator
      for (final field in fixedFields) {
        fixedSize = fixedSize! + (field.typeInfo.minimumSize ?? 0);
      }
    }

    return AccountStructureMetadata(
      totalFields: fields.length,
      fixedSizeFields: fixedFields.length,
      variableSizeFields: variableFields.length,
      fixedSize: fixedSize,
      hasNestedStructures: fields.any((f) => f.typeInfo.isNested),
      serialization: 'borsh', // Default serialization for Anchor
    );
  }

  /// Extract version information from type definition
  static AccountVersionInfo? _extractVersionInfo(IdlTypeDef typeDef) {
    // Look for version fields or metadata
    final docs = typeDef.docs;
    if (docs != null) {
      for (final doc in docs) {
        if (doc.toLowerCase().contains('version')) {
          return const AccountVersionInfo(
            version: '1.0.0', // Default version
            compatibleVersions: ['1.0.0'],
            migrationRequired: false,
          );
        }
      }
    }
    return null;
  }

  /// Validate account structure against definition
  AccountValidationResult validateStructure(List<int> accountData) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check discriminator if required
    if (validationRules.requireDiscriminator) {
      if (accountData.length < 8) {
        errors.add('Account data too short for discriminator');
      } else if (discriminator != null) {
        final actualDiscriminator = accountData.take(8).toList();
        if (!_listEquals(actualDiscriminator, discriminator)) {
          errors.add('Discriminator mismatch');
        }
      }
    }

    // Check minimum size
    if (accountData.length < validationRules.minimumSize) {
      errors.add(
          'Account data below minimum size: ${accountData.length} < ${validationRules.minimumSize}',);
    }

    // Validate field constraints
    for (final constraint in validationRules.fieldConstraints.values) {
      final result = constraint.validate(accountData);
      if (!result.isValid) {
        errors.addAll(result.errors);
      }
      warnings.addAll(result.warnings);
    }

    return AccountValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      accountName: name,
      validatedSize: accountData.length,
    );
  }

  /// Get field definition by name
  FieldDefinition? getField(String fieldName) {
    try {
      return fields.firstWhere((field) => field.name == fieldName);
    } catch (e) {
      return null;
    }
  }

  /// Check if account has field
  bool hasField(String fieldName) => getField(fieldName) != null;

  /// Get required fields
  List<FieldDefinition> get requiredFields =>
      fields.where((f) => f.isRequired).toList();

  /// Get optional fields
  List<FieldDefinition> get optionalFields =>
      fields.where((f) => !f.isRequired).toList();

  /// Get fixed-size fields
  List<FieldDefinition> get fixedSizeFields =>
      fields.where((f) => f.typeInfo.isFixedSize).toList();

  /// Get variable-size fields
  List<FieldDefinition> get variableSizeFields =>
      fields.where((f) => !f.typeInfo.isFixedSize).toList();

  /// Calculate expected size for given field values
  int calculateExpectedSize(Map<String, dynamic> fieldValues) {
    int size = 8; // discriminator

    for (final field in fields) {
      if (fieldValues.containsKey(field.name)) {
        size += field.typeInfo.calculateSize(fieldValues[field.name]);
      } else if (field.isRequired) {
        size += field.typeInfo.minimumSize ?? 0;
      }
    }

    return size;
  }

  @override
  String toString() =>
      'AccountDefinition(name: $name, fields: ${fields.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountDefinition &&
        name == other.name &&
        _listEquals(discriminator, other.discriminator) &&
        _listEquals(fields, other.fields);
  }

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(discriminator ?? []),
        Object.hashAll(fields),
      );
}

/// Field definition with comprehensive type information
class FieldDefinition {

  const FieldDefinition({
    required this.name,
    this.docs,
    required this.typeInfo,
    required this.isRequired,
    this.validationMetadata,
  });

  /// Create FieldDefinition from IDL field
  factory FieldDefinition.fromIdlField(IdlField field, List<IdlTypeDef> types) {
    final typeInfo = FieldTypeInfo.fromIdlType(field.type, types);
    final isRequired = !typeInfo.isOptional;

    return FieldDefinition(
      name: field.name,
      docs: field.docs,
      typeInfo: typeInfo,
      isRequired: isRequired,
      validationMetadata: _createValidationMetadata(field, typeInfo),
    );
  }
  /// Field name
  final String name;

  /// Optional documentation
  final List<String>? docs;

  /// Field type information
  final FieldTypeInfo typeInfo;

  /// Whether field is required
  final bool isRequired;

  /// Field validation metadata
  final FieldValidationMetadata? validationMetadata;

  /// Create validation metadata for field
  static FieldValidationMetadata? _createValidationMetadata(
    IdlField field,
    FieldTypeInfo typeInfo,
  ) => FieldValidationMetadata(
      allowNull: typeInfo.isOptional,
      sizeValidation: typeInfo.isFixedSize,
      typeValidation: true,
      customValidators: [],
    );

  @override
  String toString() =>
      'FieldDefinition(name: $name, type: ${typeInfo.typeName})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FieldDefinition &&
        name == other.name &&
        typeInfo == other.typeInfo &&
        isRequired == other.isRequired;
  }

  @override
  int get hashCode => Object.hash(name, typeInfo, isRequired);
}

/// Field type information with size and constraint details
class FieldTypeInfo {

  const FieldTypeInfo({
    required this.typeName,
    required this.isFixedSize,
    required this.isOptional,
    required this.isNested,
    this.minimumSize,
    this.maximumSize,
    this.constraint,
    this.innerType,
  });

  /// Create FieldTypeInfo from IDL type
  factory FieldTypeInfo.fromIdlType(IdlType type, List<IdlTypeDef> types) {
    switch (type.kind) {
      case 'bool':
        return const FieldTypeInfo(
          typeName: 'bool',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 1,
          maximumSize: 1,
        );
      case 'u8':
        return const FieldTypeInfo(
          typeName: 'u8',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 1,
          maximumSize: 1,
        );
      case 'i8':
        return const FieldTypeInfo(
          typeName: 'i8',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 1,
          maximumSize: 1,
        );
      case 'u16':
        return const FieldTypeInfo(
          typeName: 'u16',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 2,
          maximumSize: 2,
        );
      case 'i16':
        return const FieldTypeInfo(
          typeName: 'i16',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 2,
          maximumSize: 2,
        );
      case 'u32':
        return const FieldTypeInfo(
          typeName: 'u32',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 4,
          maximumSize: 4,
        );
      case 'i32':
        return const FieldTypeInfo(
          typeName: 'i32',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 4,
          maximumSize: 4,
        );
      case 'u64':
        return const FieldTypeInfo(
          typeName: 'u64',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 8,
          maximumSize: 8,
        );
      case 'i64':
        return const FieldTypeInfo(
          typeName: 'i64',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 8,
          maximumSize: 8,
        );
      case 'string':
        return const FieldTypeInfo(
          typeName: 'string',
          isFixedSize: false,
          isOptional: false,
          isNested: false,
          minimumSize: 4, // length prefix
        );
      case 'pubkey':
        return const FieldTypeInfo(
          typeName: 'pubkey',
          isFixedSize: true,
          isOptional: false,
          isNested: false,
          minimumSize: 32,
          maximumSize: 32,
        );
      case 'option':
        final innerTypeInfo = FieldTypeInfo.fromIdlType(type.inner!, types);
        return FieldTypeInfo(
          typeName: 'option',
          isFixedSize: false,
          isOptional: true,
          isNested: innerTypeInfo.isNested,
          minimumSize: 1, // discriminator
          innerType: innerTypeInfo,
        );
      case 'vec':
        final innerTypeInfo = FieldTypeInfo.fromIdlType(type.inner!, types);
        return FieldTypeInfo(
          typeName: 'vec',
          isFixedSize: false,
          isOptional: false,
          isNested: true,
          minimumSize: 4, // length prefix
          innerType: innerTypeInfo,
        );
      case 'array':
        final innerTypeInfo = FieldTypeInfo.fromIdlType(type.inner!, types);
        final arraySize = type.size ?? 0;
        return FieldTypeInfo(
          typeName: 'array',
          isFixedSize: innerTypeInfo.isFixedSize,
          isOptional: false,
          isNested: true,
          minimumSize: innerTypeInfo.isFixedSize
              ? (innerTypeInfo.minimumSize ?? 0) * arraySize
              : null,
          maximumSize: innerTypeInfo.isFixedSize
              ? (innerTypeInfo.maximumSize ?? 0) * arraySize
              : null,
          innerType: innerTypeInfo,
        );
      case 'defined':
        // Look up the defined type
        final typeDef = types.firstWhere(
          (t) => t.name == type.defined,
          orElse: () =>
              throw IdlError('Defined type not found: ${type.defined}'),
        );
        return FieldTypeInfo(
          typeName: 'defined',
          isFixedSize: false, // Assume variable size for complex types
          isOptional: false,
          isNested: true,
          minimumSize: 0, // Complex calculation needed
        );
      default:
        return FieldTypeInfo(
          typeName: type.kind,
          isFixedSize: false,
          isOptional: false,
          isNested: false,
          minimumSize: 0,
        );
    }
  }
  /// Type name (e.g., 'u64', 'string', 'vec', 'option')
  final String typeName;

  /// Whether type has fixed size
  final bool isFixedSize;

  /// Whether type is optional
  final bool isOptional;

  /// Whether type contains nested structures
  final bool isNested;

  /// Minimum size in bytes (null for variable size)
  final int? minimumSize;

  /// Maximum size in bytes (null for unlimited)
  final int? maximumSize;

  /// Type constraint for validation
  final TypeConstraint? constraint;

  /// Inner type for collections/options
  final FieldTypeInfo? innerType;

  /// Calculate size for a given value
  int calculateSize(dynamic value) {
    if (isFixedSize) {
      return minimumSize ?? 0;
    }

    switch (typeName) {
      case 'string':
        return 4 + (value as String).length; // length prefix + utf8 bytes
      case 'vec':
        final list = value as List;
        int size = 4; // length prefix
        for (final item in list) {
          size += innerType?.calculateSize(item) ?? 0;
        }
        return size;
      case 'option':
        if (value == null) {
          return 1; // None discriminator
        }
        return 1 +
            (innerType?.calculateSize(value) ??
                0); // Some discriminator + value
      default:
        return minimumSize ?? 0;
    }
  }

  @override
  String toString() => 'FieldTypeInfo(type: $typeName, fixed: $isFixedSize)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FieldTypeInfo &&
        typeName == other.typeName &&
        isFixedSize == other.isFixedSize &&
        isOptional == other.isOptional &&
        minimumSize == other.minimumSize;
  }

  @override
  int get hashCode =>
      Object.hash(typeName, isFixedSize, isOptional, minimumSize);
}

/// Account validation rules
class AccountValidationRules {

  const AccountValidationRules({
    required this.requireDiscriminator,
    required this.requiredFields,
    required this.optionalFields,
    required this.minimumSize,
    required this.allowPartialData,
    required this.fieldConstraints,
  });
  /// Whether discriminator is required
  final bool requireDiscriminator;

  /// List of required field names
  final List<String> requiredFields;

  /// List of optional field names
  final List<String> optionalFields;

  /// Minimum account size in bytes
  final int minimumSize;

  /// Whether partial data is allowed
  final bool allowPartialData;

  /// Field-specific constraints
  final Map<String, FieldConstraint> fieldConstraints;

  @override
  String toString() =>
      'AccountValidationRules(requiredFields: ${requiredFields.length})';
}

/// Field constraint for validation
class FieldConstraint {

  const FieldConstraint({
    required this.fieldName,
    required this.isRequired,
    this.typeConstraint,
    this.sizeConstraint,
  });
  /// Field name
  final String fieldName;

  /// Whether field is required
  final bool isRequired;

  /// Type constraint
  final TypeConstraint? typeConstraint;

  /// Size constraint
  final SizeConstraint? sizeConstraint;

  /// Validate field against account data
  FieldValidationResult validate(List<int> accountData) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic validation logic - would need to parse actual field data
    // This is a simplified implementation

    return FieldValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Type constraint for field validation
class TypeConstraint {

  const TypeConstraint({
    required this.expectedType,
    required this.allowNull,
  });
  /// Expected type name
  final String expectedType;

  /// Whether nulls are allowed
  final bool allowNull;
}

/// Size constraint for field validation
class SizeConstraint {

  const SizeConstraint({this.min, this.max});
  /// Minimum size
  final int? min;

  /// Maximum size
  final int? max;
}

/// Account structure metadata
class AccountStructureMetadata {

  const AccountStructureMetadata({
    required this.totalFields,
    required this.fixedSizeFields,
    required this.variableSizeFields,
    this.fixedSize,
    required this.hasNestedStructures,
    this.serialization,
    this.repr,
  });
  /// Total number of fields
  final int totalFields;

  /// Number of fixed-size fields
  final int fixedSizeFields;

  /// Number of variable-size fields
  final int variableSizeFields;

  /// Fixed size in bytes (null if variable)
  final int? fixedSize;

  /// Whether account has nested structures
  final bool hasNestedStructures;

  /// Serialization method
  final String? serialization;

  /// Memory representation
  final String? repr;

  @override
  String toString() =>
      'AccountStructureMetadata(fields: $totalFields, fixed: $fixedSize)';
}

/// Account inheritance information
class AccountInheritanceInfo {

  const AccountInheritanceInfo({
    this.parentAccount,
    required this.inheritedFields,
    required this.overrideFields,
  });
  /// Parent account name
  final String? parentAccount;

  /// Inherited fields
  final List<String> inheritedFields;

  /// Override fields
  final List<String> overrideFields;
}

/// Account version information
class AccountVersionInfo {

  const AccountVersionInfo({
    required this.version,
    required this.compatibleVersions,
    required this.migrationRequired,
  });
  /// Current version
  final String version;

  /// Compatible versions
  final List<String> compatibleVersions;

  /// Whether migration is required
  final bool migrationRequired;
}

/// Field validation metadata
class FieldValidationMetadata {

  const FieldValidationMetadata({
    required this.allowNull,
    required this.sizeValidation,
    required this.typeValidation,
    required this.customValidators,
  });
  /// Whether null values are allowed
  final bool allowNull;

  /// Whether size validation is required
  final bool sizeValidation;

  /// Whether type validation is required
  final bool typeValidation;

  /// Custom validators
  final List<String> customValidators;
}

/// Account validation result
class AccountValidationResult {

  const AccountValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.accountName,
    required this.validatedSize,
  });
  /// Whether validation passed
  final bool isValid;

  /// Validation errors
  final List<String> errors;

  /// Validation warnings
  final List<String> warnings;

  /// Account name that was validated
  final String accountName;

  /// Size that was validated
  final int validatedSize;

  @override
  String toString() =>
      'AccountValidationResult(valid: $isValid, errors: ${errors.length})';
}

/// Field validation result
class FieldValidationResult {

  const FieldValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
  /// Whether validation passed
  final bool isValid;

  /// Validation errors
  final List<String> errors;

  /// Validation warnings
  final List<String> warnings;
}

/// IDL parsing utilities for account structure extraction
class IdlAccountParser {
  /// Parse all account definitions from IDL
  static List<AccountDefinition> parseAccounts(Idl idl) {
    if (idl.accounts == null) return [];

    return idl.accounts!.map((account) => AccountDefinition.fromIdlAccount(account, idl.types)).toList();
  }

  /// Parse single account definition by name
  static AccountDefinition? parseAccount(Idl idl, String accountName) {
    final account = idl.findAccount(accountName);
    if (account == null) return null;

    return AccountDefinition.fromIdlAccount(account, idl.types);
  }

  /// Validate IDL account definitions
  static List<String> validateIdlAccounts(Idl idl) {
    final errors = <String>[];

    if (idl.accounts != null) {
      for (final account in idl.accounts!) {
        // Check if type definition exists
        if (idl.types?.any((t) => t.name == account.name) != true) {
          errors.add('Missing type definition for account: ${account.name}');
        }
      }
    }

    return errors;
  }
}

/// Helper function to compare lists for equality
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
