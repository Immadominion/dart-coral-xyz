/// PDA Definition and Metadata System
///
/// This module provides comprehensive PDA pattern management with metadata handling,
/// automatic IDL integration, and validation capabilities matching TypeScript's
/// sophisticated PDA pattern management system.
library;

import 'dart:typed_data';

import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/pda/pda_derivation_engine.dart' as pda;

/// Enumeration of seed types for PDA patterns
enum PdaSeedType {
  string,
  bytes,
  publicKey,
  number,
  discriminator,
  custom,
}

/// Describes a seed requirement in a PDA pattern
class PdaSeedRequirement {

  const PdaSeedRequirement({
    required this.name,
    required this.type,
    this.description,
    this.optional = false,
    this.fixedLength,
    this.minLength,
    this.maxLength,
    this.defaultValue,
    this.allowedValues,
    this.metadata,
  });
  final String name;
  final PdaSeedType type;
  final String? description;
  final bool optional;
  final int? fixedLength;
  final int? minLength;
  final int? maxLength;
  final dynamic defaultValue;
  final List<dynamic>? allowedValues;
  final Map<String, dynamic>? metadata;

  /// Validate a seed value against this requirement
  bool validate(dynamic value) {
    // Handle optional seeds
    if (value == null) {
      return optional || defaultValue != null;
    }

    // Type-specific validation
    switch (type) {
      case PdaSeedType.string:
        if (value is! String) return false;
        break;
      case PdaSeedType.bytes:
        if (value is! Uint8List && value is! List<int>) return false;
        break;
      case PdaSeedType.publicKey:
        if (value is! PublicKey) return false;
        break;
      case PdaSeedType.number:
        if (value is! int) return false;
        break;
      case PdaSeedType.discriminator:
        if (value is! Uint8List || value.length != 8) return false;
        break;
      case PdaSeedType.custom:
        // Custom validation - defer to specific pattern implementation
        break;
    }

    // Length validation
    if (type == PdaSeedType.string && value is String) {
      final length = value.length;
      if (fixedLength != null) {
        if (length != fixedLength) return false;
      }
      if (minLength != null) {
        final min = minLength as int;
        if (length < min) return false;
      }
      if (maxLength != null) {
        final max = maxLength as int;
        if (length > max) return false;
      }
    } else if (type == PdaSeedType.bytes &&
        (value is Uint8List || value is List<int>)) {
      final int length = value.length as int;
      if (fixedLength != null && length != fixedLength) return false;
      if (minLength != null) {
        if (length < minLength!) return false;
      }
      if (maxLength != null) {
        if (length > maxLength!) return false;
      }
    }

    // Allowed values validation
    if (allowedValues != null && !allowedValues!.contains(value)) {
      return false;
    }

    return true;
  }

  /// Convert a validated value to a PdaSeed
  pda.PdaSeed toPdaSeed(dynamic value) {
    final effectiveValue = value ?? defaultValue;
    if (effectiveValue == null) {
      throw ArgumentError('Seed value is required for $name');
    }

    switch (type) {
      case PdaSeedType.string:
        return pda.StringSeed(effectiveValue as String);
      case PdaSeedType.bytes:
        if (effectiveValue is Uint8List) {
          return pda.BytesSeed(effectiveValue);
        } else if (effectiveValue is List<int>) {
          return pda.BytesSeed(Uint8List.fromList(effectiveValue));
        }
        throw ArgumentError('Invalid bytes value for seed $name');
      case PdaSeedType.publicKey:
        return pda.PublicKeySeed(effectiveValue as PublicKey);
      case PdaSeedType.number:
        final byteLength = fixedLength ?? 4; // Default to u32
        return pda.NumberSeed(effectiveValue as int, byteLength: byteLength);
      case PdaSeedType.discriminator:
        return pda.BytesSeed(effectiveValue as Uint8List);
      case PdaSeedType.custom:
        throw UnimplementedError(
            'Custom seed types require specific implementation',);
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('PdaSeedRequirement(');
    buffer.write('name: $name, type: $type');
    if (description != null) buffer.write(', description: $description');
    if (optional) buffer.write(', optional: true');
    if (fixedLength != null) buffer.write(', fixedLength: $fixedLength');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Represents a PDA pattern definition with metadata and validation rules
class PdaDefinition {

  const PdaDefinition({
    required this.name,
    this.description,
    required this.seedRequirements,
    this.programId,
    this.accountType,
    this.metadata,
    this.tags,
    this.version,
    this.parent,
  });
  final String name;
  final String? description;
  final List<PdaSeedRequirement> seedRequirements;
  final PublicKey? programId;
  final String? accountType;
  final Map<String, dynamic>? metadata;
  final List<String>? tags;
  final String? version;
  final PdaDefinition? parent;

  /// Validate seed values against this definition
  PdaValidationResult validateSeeds(Map<String, dynamic> seedValues) {
    final errors = <String>[];
    final warnings = <String>[];
    final resolvedSeeds = <pda.PdaSeed>[];

    for (final requirement in seedRequirements) {
      final value = seedValues[requirement.name];

      if (!requirement.validate(value)) {
        if (requirement.optional) {
          warnings.add('Optional seed ${requirement.name} failed validation');
        } else {
          errors.add('Required seed ${requirement.name} failed validation');
          continue;
        }
      }

      try {
        resolvedSeeds.add(requirement.toPdaSeed(value));
      } catch (e) {
        errors.add('Failed to create seed for ${requirement.name}: $e');
      }
    }

    return PdaValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      resolvedSeeds: resolvedSeeds,
    );
  }

  /// Derive a PDA using validated seed values
  pda.PdaResult derivePda(
      Map<String, dynamic> seedValues, PublicKey? overrideProgramId,) {
    final validation = validateSeeds(seedValues);
    if (!validation.isValid) {
      throw PdaValidationException(validation.errors.join('; '));
    }

    final targetProgramId = overrideProgramId ?? programId;
    if (targetProgramId == null) {
      throw ArgumentError(
          'Program ID must be provided either in definition or as override',);
    }

    return pda.PdaDerivationEngine.findProgramAddress(
        validation.resolvedSeeds, targetProgramId,);
  }

  /// Check if this definition inherits from another
  bool inheritsFrom(PdaDefinition other) {
    PdaDefinition? current = parent;
    while (current != null) {
      if (current == other) return true;
      current = current.parent;
    }
    return false;
  }

  /// Get all seed requirements including inherited ones
  List<PdaSeedRequirement> getAllSeedRequirements() {
    final requirements = <PdaSeedRequirement>[];

    // Add parent requirements first
    if (parent != null) {
      requirements.addAll(parent!.getAllSeedRequirements());
    }

    // Add own requirements
    requirements.addAll(seedRequirements);

    return requirements;
  }

  /// Create a PDA definition from IDL account metadata
  static PdaDefinition? fromIdlAccount(
      IdlAccount account, PublicKey programId,) {
    // Extract PDA pattern from account name and metadata
    // This is a simplified implementation - real-world patterns would be more complex
    final seedRequirements = <PdaSeedRequirement>[];

    // Common patterns for account names
    final name = account.name;
    if (name.contains('user') || name.contains('User')) {
      seedRequirements.add(const PdaSeedRequirement(
        name: 'user',
        type: PdaSeedType.publicKey,
        description: 'User public key',
      ),);
    }

    if (name.contains('mint') || name.contains('Mint')) {
      seedRequirements.add(const PdaSeedRequirement(
        name: 'mint',
        type: PdaSeedType.publicKey,
        description: 'Mint public key',
      ),);
    }

    // Add discriminator if present
    if (account.discriminator != null) {
      seedRequirements.add(PdaSeedRequirement(
        name: 'discriminator',
        type: PdaSeedType.discriminator,
        description: 'Account discriminator',
        defaultValue: Uint8List.fromList(account.discriminator!),
      ),);
    }

    // Only create definition if we found meaningful patterns
    if (seedRequirements.isNotEmpty) {
      return PdaDefinition(
        name: name,
        description: 'Auto-generated PDA definition for $name account',
        seedRequirements: seedRequirements,
        programId: programId,
        accountType: name,
        metadata: {
          'auto_generated': true,
          'source': 'idl_account',
        },
      );
    }

    return null;
  }

  @override
  String toString() => 'PdaDefinition(name: $name, seeds: ${seedRequirements.length}, '
        'accountType: $accountType)';
}

/// Result of PDA seed validation
class PdaValidationResult {

  const PdaValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.resolvedSeeds,
  });
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<pda.PdaSeed> resolvedSeeds;

  @override
  String toString() => 'PdaValidationResult(isValid: $isValid, errors: ${errors.length}, '
        'warnings: ${warnings.length}, seeds: ${resolvedSeeds.length})';
}

/// Exception thrown when PDA validation fails
class PdaValidationException implements Exception {

  const PdaValidationException(this.message);
  final String message;

  @override
  String toString() => 'PdaValidationException: $message';
}

/// Registry for managing PDA definitions
class PdaDefinitionRegistry {
  final Map<String, PdaDefinition> _definitions = {};
  final Map<PublicKey, List<PdaDefinition>> _programDefinitions = {};

  /// Register a PDA definition
  void register(PdaDefinition definition) {
    _definitions[definition.name] = definition;

    if (definition.programId != null) {
      _programDefinitions
          .putIfAbsent(definition.programId!, () => [])
          .add(definition);
    }
  }

  /// Get a definition by name
  PdaDefinition? getDefinition(String name) => _definitions[name];

  /// Get all definitions for a program
  List<PdaDefinition> getDefinitionsForProgram(PublicKey programId) => _programDefinitions[programId] ?? [];

  /// Register definitions from IDL
  void registerFromIdl(Idl idl, PublicKey programId) {
    if (idl.accounts != null) {
      for (final account in idl.accounts!) {
        final definition = PdaDefinition.fromIdlAccount(account, programId);
        if (definition != null) {
          register(definition);
        }
      }
    }
  }

  /// Clear all definitions
  void clear() {
    _definitions.clear();
    _programDefinitions.clear();
  }

  /// Get all registered definitions
  List<PdaDefinition> getAllDefinitions() => _definitions.values.toList();

  /// Find definitions by tag
  List<PdaDefinition> findDefinitionsByTag(String tag) => _definitions.values
        .where((def) => def.tags?.contains(tag) == true)
        .toList();

  /// Find definitions by account type
  List<PdaDefinition> findDefinitionsByAccountType(String accountType) => _definitions.values
        .where((def) => def.accountType == accountType)
        .toList();

  @override
  String toString() => 'PdaDefinitionRegistry(definitions: ${_definitions.length}, '
        'programs: ${_programDefinitions.length})';
}

/// Global PDA definition registry instance
PdaDefinitionRegistry? _globalRegistry;

/// Get or create the global PDA definition registry
PdaDefinitionRegistry getGlobalPdaDefinitionRegistry() => _globalRegistry ??= PdaDefinitionRegistry();

/// Set a custom global PDA definition registry
void setGlobalPdaDefinitionRegistry(PdaDefinitionRegistry registry) {
  _globalRegistry = registry;
}

/// Clear the global PDA definition registry
void clearGlobalPdaDefinitionRegistry() {
  _globalRegistry?.clear();
}
