/// Account Size and Structure Validation Engine
///
/// This module provides comprehensive account size validation matching the
/// TypeScript Anchor client's multi-layered size validation logic.
/// Includes discriminator overhead validation, minimum field size requirements,
/// and structure-specific size calculations.
library;

import 'dart:typed_data';

/// Validation result for account size validation
class AccountSizeValidationResult {
  /// Whether the validation passed
  final bool isValid;

  /// Error message if validation failed
  final String? errorMessage;

  /// Expected size in bytes
  final int? expectedSize;

  /// Actual size in bytes
  final int? actualSize;

  /// Size difference (actual - expected)
  final int? sizeDifference;

  /// Validation context (account name, structure info, etc.)
  final Map<String, dynamic>? context;

  const AccountSizeValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.expectedSize,
    this.actualSize,
    this.sizeDifference,
    this.context,
  });

  /// Create a successful validation result
  const AccountSizeValidationResult.success({
    int? expectedSize,
    int? actualSize,
    Map<String, dynamic>? context,
  }) : this._(
          isValid: true,
          expectedSize: expectedSize,
          actualSize: actualSize,
          sizeDifference: actualSize != null && expectedSize != null
              ? actualSize - expectedSize
              : null,
          context: context,
        );

  /// Create a failed validation result
  const AccountSizeValidationResult.failure({
    required String message,
    int? expectedSize,
    int? actualSize,
    Map<String, dynamic>? context,
  }) : this._(
          isValid: false,
          errorMessage: message,
          expectedSize: expectedSize,
          actualSize: actualSize,
          sizeDifference: actualSize != null && expectedSize != null
              ? actualSize - expectedSize
              : null,
          context: context,
        );

  @override
  String toString() => isValid
      ? 'AccountSizeValidationResult.success(expected: $expectedSize, actual: $actualSize)'
      : 'AccountSizeValidationResult.failure($errorMessage)';
}

/// Exception thrown when account size validation fails
class AccountSizeValidationException implements Exception {
  final String message;
  final int? expectedSize;
  final int? actualSize;
  final Map<String, dynamic>? context;

  const AccountSizeValidationException(
    this.message, {
    this.expectedSize,
    this.actualSize,
    this.context,
  });

  @override
  String toString() =>
      'AccountSizeValidationException: $message (expected: $expectedSize, actual: $actualSize)';
}

/// Configuration for account size validation
class AccountSizeValidationConfig {
  /// Whether to include detailed context in results
  final bool includeContext;

  /// Whether to allow partial account data in specific scenarios
  final bool allowPartialData;

  /// Whether to validate discriminator size (8 bytes)
  final bool validateDiscriminator;

  /// Whether to perform strict size validation (exact match required)
  final bool strictValidation;

  /// Minimum account size tolerance (for variable-length fields)
  final int minimumSizeTolerance;

  /// Maximum account size tolerance (for reallocation scenarios)
  final int maximumSizeTolerance;

  /// Whether to bypass all validation (for testing)
  final bool bypassValidation;

  const AccountSizeValidationConfig({
    this.includeContext = true,
    this.allowPartialData = false,
    this.validateDiscriminator = true,
    this.strictValidation = true,
    this.minimumSizeTolerance = 0,
    this.maximumSizeTolerance = 0,
    this.bypassValidation = false,
  });

  /// Strict validation configuration (default)
  static const AccountSizeValidationConfig strict =
      AccountSizeValidationConfig();

  /// Permissive validation for variable-length accounts
  static const AccountSizeValidationConfig permissive =
      AccountSizeValidationConfig(
    strictValidation: false,
    minimumSizeTolerance: 8,
    maximumSizeTolerance: 1024,
  );

  /// Minimal validation (only discriminator check)
  static const AccountSizeValidationConfig minimal =
      AccountSizeValidationConfig(
    strictValidation: false,
    validateDiscriminator: true,
    allowPartialData: true,
    minimumSizeTolerance: 0,
    maximumSizeTolerance: 10000,
  );

  /// Bypass all validation (for testing)
  static const AccountSizeValidationConfig bypass =
      AccountSizeValidationConfig(bypassValidation: true);
}

/// Account structure definition for size calculation
class AccountStructureDefinition {
  /// Account type name
  final String name;

  /// Minimum required size (including discriminator)
  final int minimumSize;

  /// Maximum size (for variable-length accounts, null = unlimited)
  final int? maximumSize;

  /// Whether this account has variable-length fields
  final bool hasVariableLengthFields;

  /// Field definitions for detailed validation
  final List<AccountFieldDefinition> fields;

  /// Whether this account includes the 8-byte discriminator
  final bool hasDiscriminator;

  const AccountStructureDefinition({
    required this.name,
    required this.minimumSize,
    this.maximumSize,
    this.hasVariableLengthFields = false,
    this.fields = const [],
    this.hasDiscriminator = true,
  });

  /// Get total minimum size including discriminator
  int get totalMinimumSize => minimumSize + (hasDiscriminator ? 8 : 0);

  /// Get total maximum size including discriminator
  int? get totalMaximumSize =>
      maximumSize != null ? maximumSize! + (hasDiscriminator ? 8 : 0) : null;
}

/// Individual field definition for size calculation
class AccountFieldDefinition {
  /// Field name
  final String name;

  /// Field size in bytes
  final int size;

  /// Whether this field is variable length
  final bool isVariableLength;

  /// Whether this field is optional
  final bool isOptional;

  const AccountFieldDefinition({
    required this.name,
    required this.size,
    this.isVariableLength = false,
    this.isOptional = false,
  });
}

/// Comprehensive account size validation engine
class AccountSizeValidator {
  /// Discriminator size (8 bytes for Anchor accounts)
  static const int discriminatorSize = 8;

  /// Validation statistics
  static int _validationCount = 0;
  static int _successCount = 0;
  static int _failureCount = 0;

  /// Get validation statistics
  static Map<String, int> get statistics => {
        'totalValidations': _validationCount,
        'successes': _successCount,
        'failures': _failureCount,
      };

  /// Reset validation statistics
  static void resetStatistics() {
    _validationCount = 0;
    _successCount = 0;
    _failureCount = 0;
  }

  /// Validate account size against structure definition
  ///
  /// [accountData] - Raw account data bytes
  /// [structureDefinition] - Expected account structure
  /// [config] - Validation configuration
  ///
  /// Returns validation result
  static AccountSizeValidationResult validateAccountSize({
    required Uint8List accountData,
    required AccountStructureDefinition structureDefinition,
    AccountSizeValidationConfig config = AccountSizeValidationConfig.strict,
  }) {
    _validationCount++;

    try {
      // Bypass validation if configured
      if (config.bypassValidation) {
        _successCount++;
        return AccountSizeValidationResult.success(
          expectedSize: structureDefinition.totalMinimumSize,
          actualSize: accountData.length,
          context: config.includeContext
              ? {
                  'validation_type': 'bypassed',
                  'account_type': structureDefinition.name,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      final actualSize = accountData.length;
      final expectedMinSize = structureDefinition.totalMinimumSize;
      final expectedMaxSize = structureDefinition.totalMaximumSize;

      // Check minimum size requirement first (includes discriminator)
      if (actualSize < expectedMinSize - config.minimumSizeTolerance) {
        _failureCount++;

        // Special case: if we have discriminator validation enabled and the only issue
        // is discriminator size, report it as a discriminator issue
        if (config.validateDiscriminator &&
            structureDefinition.hasDiscriminator &&
            actualSize < discriminatorSize &&
            expectedMinSize == discriminatorSize) {
          return AccountSizeValidationResult.failure(
            message: 'Account data too small for discriminator. '
                'Expected at least $discriminatorSize bytes for discriminator, got $actualSize bytes',
            expectedSize: discriminatorSize,
            actualSize: actualSize,
            context: config.includeContext
                ? {
                    'validation_type': 'discriminator_size_check',
                    'account_type': structureDefinition.name,
                    'discriminator_size': discriminatorSize,
                    'timestamp': DateTime.now().toIso8601String(),
                  }
                : null,
          );
        }

        return AccountSizeValidationResult.failure(
          message: 'Account data too small for ${structureDefinition.name}. '
              'Expected at least $expectedMinSize bytes, got $actualSize bytes',
          expectedSize: expectedMinSize,
          actualSize: actualSize,
          context: config.includeContext
              ? {
                  'validation_type': 'size_too_small',
                  'account_type': structureDefinition.name,
                  'minimum_required': expectedMinSize,
                  'tolerance': config.minimumSizeTolerance,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // Check maximum size requirement (if specified)
      if (expectedMaxSize != null &&
          actualSize > expectedMaxSize + config.maximumSizeTolerance) {
        _failureCount++;
        return AccountSizeValidationResult.failure(
          message: 'Account data too large for ${structureDefinition.name}. '
              'Expected at most $expectedMaxSize bytes, got $actualSize bytes',
          expectedSize: expectedMaxSize,
          actualSize: actualSize,
          context: config.includeContext
              ? {
                  'validation_type': 'size_too_large',
                  'account_type': structureDefinition.name,
                  'maximum_allowed': expectedMaxSize,
                  'tolerance': config.maximumSizeTolerance,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      // Strict validation: check exact size match for truly fixed-size accounts
      // (accounts with no variable fields AND no maximum size range)
      if (config.strictValidation &&
          !structureDefinition.hasVariableLengthFields &&
          structureDefinition.maximumSize == null &&
          actualSize != expectedMinSize) {
        _failureCount++;
        return AccountSizeValidationResult.failure(
          message: 'Account size mismatch for ${structureDefinition.name}. '
              'Expected exactly $expectedMinSize bytes, got $actualSize bytes',
          expectedSize: expectedMinSize,
          actualSize: actualSize,
          context: config.includeContext
              ? {
                  'validation_type': 'exact_size_mismatch',
                  'account_type': structureDefinition.name,
                  'is_fixed_size': !structureDefinition.hasVariableLengthFields,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              : null,
        );
      }

      _successCount++;
      return AccountSizeValidationResult.success(
        expectedSize: expectedMinSize,
        actualSize: actualSize,
        context: config.includeContext
            ? {
                'validation_type': 'size_validation_success',
                'account_type': structureDefinition.name,
                'has_variable_fields':
                    structureDefinition.hasVariableLengthFields,
                'field_count': structureDefinition.fields.length,
                'timestamp': DateTime.now().toIso8601String(),
              }
            : null,
      );
    } catch (error) {
      _failureCount++;
      return AccountSizeValidationResult.failure(
        message: 'Account size validation failed: $error',
        context: config.includeContext
            ? {
                'validation_type': 'error',
                'account_type': structureDefinition.name,
                'error': error.toString(),
                'timestamp': DateTime.now().toIso8601String(),
              }
            : null,
      );
    }
  }

  /// Validate account size with just minimum requirements
  ///
  /// [accountData] - Raw account data bytes
  /// [minimumSize] - Expected minimum size (including discriminator)
  /// [accountName] - Account type name for error context
  /// [config] - Validation configuration
  ///
  /// Returns validation result
  static AccountSizeValidationResult validateMinimumSize({
    required Uint8List accountData,
    required int minimumSize,
    String? accountName,
    AccountSizeValidationConfig config = AccountSizeValidationConfig.strict,
  }) {
    final structureDefinition = AccountStructureDefinition(
      name: accountName ?? 'UnknownAccount',
      minimumSize: minimumSize - (config.validateDiscriminator ? 8 : 0),
      hasDiscriminator: config.validateDiscriminator,
    );

    return validateAccountSize(
      accountData: accountData,
      structureDefinition: structureDefinition,
      config: config,
    );
  }

  /// Calculate expected size for basic account structures
  ///
  /// [baseFieldsSize] - Size of account fields (excluding discriminator)
  /// [includeDiscriminator] - Whether to include 8-byte discriminator
  ///
  /// Returns total expected size
  static int calculateExpectedSize({
    required int baseFieldsSize,
    bool includeDiscriminator = true,
  }) {
    return baseFieldsSize + (includeDiscriminator ? discriminatorSize : 0);
  }

  /// Validate batch of accounts
  ///
  /// [validations] - List of validation parameters
  ///
  /// Returns list of validation results in same order
  static List<AccountSizeValidationResult> validateBatch(
    List<
            ({
              Uint8List accountData,
              AccountStructureDefinition structureDefinition,
              AccountSizeValidationConfig? config,
            })>
        validations,
  ) {
    return validations
        .map((v) => validateAccountSize(
              accountData: v.accountData,
              structureDefinition: v.structureDefinition,
              config: v.config ?? AccountSizeValidationConfig.strict,
            ))
        .toList();
  }

  /// Check if account data meets discriminator requirements
  ///
  /// [accountData] - Raw account data bytes
  ///
  /// Returns true if account has space for 8-byte discriminator
  static bool hasDiscriminatorSpace(Uint8List accountData) {
    return accountData.length >= discriminatorSize;
  }

  /// Extract account payload (data after discriminator)
  ///
  /// [accountData] - Raw account data bytes
  /// [validateSize] - Whether to validate minimum size first
  ///
  /// Returns payload bytes or null if invalid
  static Uint8List? extractPayload(
    Uint8List accountData, {
    bool validateSize = true,
  }) {
    if (validateSize && !hasDiscriminatorSpace(accountData)) {
      return null;
    }

    if (accountData.length <= discriminatorSize) {
      return Uint8List(0);
    }

    return accountData.sublist(discriminatorSize);
  }

  /// Get size breakdown for debugging
  ///
  /// [accountData] - Raw account data bytes
  /// [structureDefinition] - Account structure definition
  ///
  /// Returns detailed size breakdown
  static Map<String, dynamic> getSizeBreakdown({
    required Uint8List accountData,
    required AccountStructureDefinition structureDefinition,
  }) {
    final actualSize = accountData.length;
    final expectedMinSize = structureDefinition.totalMinimumSize;
    final expectedMaxSize = structureDefinition.totalMaximumSize;
    final payloadSize =
        actualSize >= discriminatorSize ? actualSize - discriminatorSize : 0;

    return {
      'account_type': structureDefinition.name,
      'actual_size': actualSize,
      'expected_min_size': expectedMinSize,
      'expected_max_size': expectedMaxSize,
      'discriminator_size': discriminatorSize,
      'payload_size': payloadSize,
      'has_discriminator_space': hasDiscriminatorSpace(accountData),
      'size_difference': actualSize - expectedMinSize,
      'is_within_bounds': actualSize >= expectedMinSize &&
          (expectedMaxSize == null || actualSize <= expectedMaxSize),
      'field_definitions': structureDefinition.fields
          .map((f) => {
                'name': f.name,
                'size': f.size,
                'is_variable': f.isVariableLength,
                'is_optional': f.isOptional,
              })
          .toList(),
    };
  }
}
