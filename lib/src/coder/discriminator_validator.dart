/// Discriminator Validation Framework
///
/// This module provides robust validation system that checks discriminator
/// matches with detailed error reporting, matching TypeScript's validation
/// strictness from BorshAccountsCoder.decode().

library;

import 'dart:typed_data';

/// Result of discriminator validation operation.
class DiscriminatorValidationResult {

  /// Create validation result.
  const DiscriminatorValidationResult({
    required this.isValid,
    this.errorMessage,
    this.expectedDiscriminator,
    this.actualDiscriminator,
    this.mismatchIndex = -1,
  });

  /// Create successful validation result.
  const DiscriminatorValidationResult.success()
      : isValid = true,
        errorMessage = null,
        expectedDiscriminator = null,
        actualDiscriminator = null,
        mismatchIndex = -1;

  /// Create failed validation result.
  DiscriminatorValidationResult.failure({
    required String message,
    Uint8List? expected,
    Uint8List? actual,
    int mismatchIndex = -1,
  })  : isValid = false,
        errorMessage = message,
        expectedDiscriminator = expected,
        actualDiscriminator = actual,
        mismatchIndex = mismatchIndex;
  /// Whether validation passed
  final bool isValid;

  /// Error message if validation failed
  final String? errorMessage;

  /// Expected discriminator bytes
  final Uint8List? expectedDiscriminator;

  /// Actual discriminator bytes found
  final Uint8List? actualDiscriminator;

  /// Byte position where mismatch occurred (-1 if no mismatch)
  final int mismatchIndex;
}

/// Robust discriminator validation system with detailed error reporting.
///
/// This class provides comprehensive discriminator validation that matches
/// TypeScript Anchor's validation strictness, with detailed error context
/// and debugging information for mismatch scenarios.
class DiscriminatorValidator {

  /// Create a new discriminator validator.
  ///
  /// [bypassValidation] If true, all validations will pass (default: false)
  /// [cacheResults] If true, validation results will be cached (default: true)
  DiscriminatorValidator({
    this.bypassValidation = false,
    this.cacheResults = true,
  });
  /// Size of Anchor discriminators
  static const int discriminatorSize = 8;

  /// Whether to enable validation bypass for development/testing
  final bool bypassValidation;

  /// Whether to cache validation results for performance
  final bool cacheResults;

  /// Cache for validation results (when cacheResults is true)
  final Map<String, DiscriminatorValidationResult> _validationCache = {};

  /// Validate discriminator against expected value.
  ///
  /// [expected] The expected discriminator bytes
  /// [actual] The actual discriminator bytes to validate
  /// [context] Optional context for error reporting (e.g., account name)
  ///
  /// Returns validation result with detailed information
  DiscriminatorValidationResult validate(
    Uint8List expected,
    Uint8List actual, {
    String? context,
  }) {
    // Check cache first
    if (cacheResults) {
      final cacheKey = _generateCacheKey(expected, actual, context);
      final cached = _validationCache[cacheKey];
      if (cached != null) {
        return cached;
      }
    }

    // Bypass validation if configured
    if (bypassValidation) {
      final result = const DiscriminatorValidationResult.success();
      _cacheResult(expected, actual, context, result);
      return result;
    }

    // Perform validation
    final result = _performValidation(expected, actual, context);
    _cacheResult(expected, actual, context, result);
    return result;
  }

  /// Validate account data discriminator.
  ///
  /// [expectedDiscriminator] The expected account discriminator
  /// [accountData] The raw account data bytes
  /// [accountName] Optional account name for error context
  ///
  /// Returns validation result
  DiscriminatorValidationResult validateAccountData(
    Uint8List expectedDiscriminator,
    Uint8List accountData, {
    String? accountName,
  }) {
    // Check if account data is long enough for discriminator
    if (accountData.length < discriminatorSize) {
      final context = accountName != null ? ' for account "$accountName"' : '';
      return DiscriminatorValidationResult.failure(
        message: 'Account data too short$context. '
            'Expected at least $discriminatorSize bytes for discriminator, '
            'got ${accountData.length} bytes',
        expected: expectedDiscriminator,
        actual: accountData.isNotEmpty
            ? accountData.sublist(0, accountData.length)
            : Uint8List(0),
      );
    }

    // Extract discriminator from account data
    final actualDiscriminator = accountData.sublist(0, discriminatorSize);

    return validate(
      expectedDiscriminator,
      actualDiscriminator,
      context: accountName,
    );
  }

  /// Validate bulk discriminators for performance.
  ///
  /// [validations] List of validation parameters
  ///
  /// Returns list of validation results in same order
  List<DiscriminatorValidationResult> validateBulk(
    List<({Uint8List expected, Uint8List actual, String? context})> validations,
  ) => validations
        .map((v) => validate(v.expected, v.actual, context: v.context))
        .toList();

  /// Clear validation cache.
  void clearCache() {
    _validationCache.clear();
  }

  /// Get cache size.
  int get cacheSize => _validationCache.length;

  /// Get cache statistics.
  Map<String, dynamic> get cacheStatistics => {
        'size': cacheSize,
        'enabled': cacheResults,
        'bypassEnabled': bypassValidation,
      };

  /// Perform the actual validation logic.
  DiscriminatorValidationResult _performValidation(
    Uint8List expected,
    Uint8List actual,
    String? context,
  ) {
    // Validate expected discriminator size
    if (expected.length != discriminatorSize) {
      return DiscriminatorValidationResult.failure(
        message:
            'Expected discriminator must be exactly $discriminatorSize bytes, '
            'got ${expected.length} bytes',
        expected: expected,
        actual: actual,
      );
    }

    // Validate actual discriminator size
    if (actual.length != discriminatorSize) {
      final contextStr = context != null ? ' for "$context"' : '';
      return DiscriminatorValidationResult.failure(
        message:
            'Actual discriminator must be exactly $discriminatorSize bytes$contextStr, '
            'got ${actual.length} bytes',
        expected: expected,
        actual: actual,
      );
    }

    // Byte-by-byte comparison
    for (int i = 0; i < discriminatorSize; i++) {
      if (expected[i] != actual[i]) {
        final contextStr = context != null ? ' for "$context"' : '';
        return DiscriminatorValidationResult.failure(
          message: 'Discriminator mismatch$contextStr at byte $i. '
              'Expected: ${_formatByte(expected[i])}, '
              'Actual: ${_formatByte(actual[i])}\n'
              'Expected discriminator: ${_formatBytes(expected)}\n'
              'Actual discriminator:   ${_formatBytes(actual)}',
          expected: expected,
          actual: actual,
          mismatchIndex: i,
        );
      }
    }

    return const DiscriminatorValidationResult.success();
  }

  /// Generate cache key for validation result.
  String _generateCacheKey(
      Uint8List expected, Uint8List actual, String? context,) {
    final expectedHex = _formatBytes(expected);
    final actualHex = _formatBytes(actual);
    final contextStr = context ?? '';
    return '$expectedHex:$actualHex:$contextStr';
  }

  /// Cache validation result if caching is enabled.
  void _cacheResult(
    Uint8List expected,
    Uint8List actual,
    String? context,
    DiscriminatorValidationResult result,
  ) {
    if (cacheResults) {
      final cacheKey = _generateCacheKey(expected, actual, context);
      _validationCache[cacheKey] = result;
    }
  }

  /// Format single byte as hex string.
  String _formatByte(int byte) => '0x${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  /// Format byte array as hex string.
  String _formatBytes(Uint8List bytes) => bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();

  /// Create validator with validation bypass enabled.
  ///
  /// Useful for development and testing scenarios where discriminator
  /// validation should be skipped.
  static DiscriminatorValidator createBypass() => DiscriminatorValidator(bypassValidation: true);

  /// Create validator with validation caching disabled.
  ///
  /// Useful for scenarios where memory usage should be minimized
  /// or validation results should not be cached.
  static DiscriminatorValidator createNonCaching() => DiscriminatorValidator(cacheResults: false);

  /// Create validator with strict validation settings.
  ///
  /// Default settings with no bypass and caching enabled.
  static DiscriminatorValidator createStrict() => DiscriminatorValidator();
}

/// Discriminator validation exception.
///
/// Thrown when discriminator validation fails and exceptions are preferred
/// over validation result objects.
class DiscriminatorValidationException implements Exception {

  /// Create validation exception from result.
  const DiscriminatorValidationException(this.result);
  /// The validation result that caused this exception
  final DiscriminatorValidationResult result;

  @override
  String toString() => 'DiscriminatorValidationException: ${result.errorMessage}';
}

/// Utility functions for discriminator validation.
class DiscriminatorValidationUtils {
  /// Validate discriminator and throw exception if invalid.
  ///
  /// [validator] The validator to use
  /// [expected] Expected discriminator
  /// [actual] Actual discriminator
  /// [context] Optional context for error reporting
  ///
  /// Throws [DiscriminatorValidationException] if validation fails
  static void validateOrThrow(
    DiscriminatorValidator validator,
    Uint8List expected,
    Uint8List actual, {
    String? context,
  }) {
    final result = validator.validate(expected, actual, context: context);
    if (!result.isValid) {
      throw DiscriminatorValidationException(result);
    }
  }

  /// Quick validation without creating validator instance.
  ///
  /// [expected] Expected discriminator
  /// [actual] Actual discriminator
  ///
  /// Returns true if discriminators match exactly
  static bool quickValidate(Uint8List expected, Uint8List actual) {
    if (expected.length != actual.length) return false;
    if (expected.length != 8) return false;

    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }

  /// Extract discriminator from account data safely.
  ///
  /// [accountData] The account data bytes
  ///
  /// Returns discriminator bytes or null if data is too short
  static Uint8List? extractDiscriminator(Uint8List accountData) {
    if (accountData.length < DiscriminatorValidator.discriminatorSize) {
      return null;
    }
    return accountData.sublist(0, DiscriminatorValidator.discriminatorSize);
  }
}
