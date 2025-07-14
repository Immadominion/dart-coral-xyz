/// Tests for DiscriminatorValidator
///
/// Comprehensive test suite validating discriminator validation framework
/// with detailed error reporting and edge case handling.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('DiscriminatorValidator', () {
    late DiscriminatorValidator validator;
    late Uint8List validDiscriminator1;
    late Uint8List validDiscriminator2;
    late Uint8List invalidDiscriminator;

    setUp(() {
      validator = DiscriminatorValidator();
      validDiscriminator1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      validDiscriminator2 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);
      invalidDiscriminator = Uint8List.fromList([1, 2, 3]); // Wrong size
    });

    group('Basic Validation', () {
      test('validates matching discriminators successfully', () {
        final result =
            validator.validate(validDiscriminator1, validDiscriminator1);

        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.mismatchIndex, equals(-1));
      });

      test('detects discriminator mismatch', () {
        final result =
            validator.validate(validDiscriminator1, validDiscriminator2);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.mismatchIndex, equals(7)); // Last byte differs
        expect(result.errorMessage!.contains('at byte 7'), isTrue);
        expect(result.errorMessage!.contains('Expected: 0x08'), isTrue);
        expect(result.errorMessage!.contains('Actual: 0x09'), isTrue);
      });

      test('validates discriminators with context', () {
        final result = validator.validate(
          validDiscriminator1,
          validDiscriminator2,
          context: 'MyAccount',
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('for "MyAccount"'), isTrue);
      });

      test('rejects invalid expected discriminator size', () {
        final result =
            validator.validate(invalidDiscriminator, validDiscriminator1);

        expect(result.isValid, isFalse);
        expect(
            result.errorMessage!
                .contains('Expected discriminator must be exactly 8 bytes'),
            isTrue,);
      });

      test('rejects invalid actual discriminator size', () {
        final result =
            validator.validate(validDiscriminator1, invalidDiscriminator);

        expect(result.isValid, isFalse);
        expect(
            result.errorMessage!
                .contains('Actual discriminator must be exactly 8 bytes'),
            isTrue,);
      });
    });

    group('Account Data Validation', () {
      test('validates account data with correct discriminator', () {
        final accountData = Uint8List.fromList([
          ...validDiscriminator1,
          10, 20, 30, 40, // Additional account data
        ]);

        final result = validator.validateAccountData(
          validDiscriminator1,
          accountData,
          accountName: 'TestAccount',
        );

        expect(result.isValid, isTrue);
      });

      test('detects account data discriminator mismatch', () {
        final accountData = Uint8List.fromList([
          ...validDiscriminator2,
          10, 20, 30, 40, // Additional account data
        ]);

        final result = validator.validateAccountData(
          validDiscriminator1,
          accountData,
          accountName: 'TestAccount',
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('for "TestAccount"'), isTrue);
      });

      test('rejects account data too short for discriminator', () {
        final shortAccountData = Uint8List.fromList([1, 2, 3]); // Only 3 bytes

        final result = validator.validateAccountData(
          validDiscriminator1,
          shortAccountData,
          accountName: 'TestAccount',
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('Account data too short'), isTrue);
        expect(
            result.errorMessage!.contains('Expected at least 8 bytes'), isTrue,);
        expect(result.errorMessage!.contains('got 3 bytes'), isTrue);
      });

      test('handles empty account data', () {
        final emptyAccountData = Uint8List(0);

        final result = validator.validateAccountData(
          validDiscriminator1,
          emptyAccountData,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('Account data too short'), isTrue);
        expect(result.errorMessage!.contains('got 0 bytes'), isTrue);
      });
    });

    group('Validation Bypass', () {
      test('bypass validator always returns success', () {
        final bypassValidator = DiscriminatorValidator(bypassValidation: true);

        final result =
            bypassValidator.validate(validDiscriminator1, validDiscriminator2);

        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
      });

      test('bypass validator ignores size mismatches', () {
        final bypassValidator = DiscriminatorValidator(bypassValidation: true);

        final result =
            bypassValidator.validate(validDiscriminator1, invalidDiscriminator);

        expect(result.isValid, isTrue);
      });

      test('createBypass factory creates bypass validator', () {
        final bypassValidator = DiscriminatorValidator.createBypass();

        final result =
            bypassValidator.validate(validDiscriminator1, validDiscriminator2);

        expect(result.isValid, isTrue);
      });
    });

    group('Validation Caching', () {
      test('caches validation results by default', () {
        expect(validator.cacheResults, isTrue);
        expect(validator.cacheSize, equals(0));

        // First validation
        validator.validate(validDiscriminator1, validDiscriminator2);
        expect(validator.cacheSize, equals(1));

        // Second validation with same parameters should use cache
        validator.validate(validDiscriminator1, validDiscriminator2);
        expect(validator.cacheSize, equals(1)); // Should not increase
      });

      test('respects cache disabled setting', () {
        final nonCachingValidator = DiscriminatorValidator(cacheResults: false);

        nonCachingValidator.validate(validDiscriminator1, validDiscriminator2);
        expect(nonCachingValidator.cacheSize, equals(0));
      });

      test('createNonCaching factory creates non-caching validator', () {
        final nonCachingValidator = DiscriminatorValidator.createNonCaching();

        nonCachingValidator.validate(validDiscriminator1, validDiscriminator2);
        expect(nonCachingValidator.cacheSize, equals(0));
      });

      test('cache considers context in key generation', () {
        validator.validate(validDiscriminator1, validDiscriminator2,
            context: 'Account1',);
        validator.validate(validDiscriminator1, validDiscriminator2,
            context: 'Account2',);

        expect(validator.cacheSize,
            equals(2),); // Different contexts = different cache entries
      });

      test('clears cache correctly', () {
        validator.validate(validDiscriminator1, validDiscriminator2);
        expect(validator.cacheSize, greaterThan(0));

        validator.clearCache();
        expect(validator.cacheSize, equals(0));
      });
    });

    group('Bulk Validation', () {
      test('validates multiple discriminators', () {
        final validations = [
          (
            expected: validDiscriminator1,
            actual: validDiscriminator1,
            context: 'Test1'
          ),
          (
            expected: validDiscriminator1,
            actual: validDiscriminator2,
            context: 'Test2'
          ),
          (
            expected: validDiscriminator2,
            actual: validDiscriminator2,
            context: 'Test3'
          ),
        ];

        final results = validator.validateBulk(validations);

        expect(results.length, equals(3));
        expect(results[0].isValid, isTrue);
        expect(results[1].isValid, isFalse);
        expect(results[2].isValid, isTrue);
      });

      test('maintains order in bulk validation results', () {
        final validations = [
          (
            expected: validDiscriminator1,
            actual: validDiscriminator2,
            context: 'First'
          ),
          (
            expected: validDiscriminator2,
            actual: validDiscriminator1,
            context: 'Second'
          ),
        ];

        final results = validator.validateBulk(validations);

        expect(results[0].errorMessage!.contains('for "First"'), isTrue);
        expect(results[1].errorMessage!.contains('for "Second"'), isTrue);
      });
    });

    group('Statistics and Monitoring', () {
      test('provides cache statistics', () {
        final stats = validator.cacheStatistics;

        expect(stats['size'], equals(0));
        expect(stats['enabled'], isTrue);
        expect(stats['bypassEnabled'], isFalse);

        validator.validate(validDiscriminator1, validDiscriminator2);

        final updatedStats = validator.cacheStatistics;
        expect(updatedStats['size'], equals(1));
      });

      test('reports bypass status in statistics', () {
        final bypassValidator = DiscriminatorValidator(bypassValidation: true);
        final stats = bypassValidator.cacheStatistics;

        expect(stats['bypassEnabled'], isTrue);
      });
    });

    group('Factory Methods', () {
      test('createStrict creates default validator', () {
        final strictValidator = DiscriminatorValidator.createStrict();

        expect(strictValidator.bypassValidation, isFalse);
        expect(strictValidator.cacheResults, isTrue);
      });

      test('factory methods create validators with correct settings', () {
        final bypass = DiscriminatorValidator.createBypass();
        final nonCaching = DiscriminatorValidator.createNonCaching();
        final strict = DiscriminatorValidator.createStrict();

        expect(bypass.bypassValidation, isTrue);
        expect(nonCaching.cacheResults, isFalse);
        expect(strict.bypassValidation, isFalse);
        expect(strict.cacheResults, isTrue);
      });
    });
  });

  group('DiscriminatorValidationResult', () {
    test('creates success result correctly', () {
      const result = DiscriminatorValidationResult.success();

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.expectedDiscriminator, isNull);
      expect(result.actualDiscriminator, isNull);
      expect(result.mismatchIndex, equals(-1));
    });

    test('creates failure result correctly', () {
      final expected = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final actual = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);

      final result = DiscriminatorValidationResult.failure(
        message: 'Test failure',
        expected: expected,
        actual: actual,
        mismatchIndex: 7,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Test failure'));
      expect(result.expectedDiscriminator, equals(expected));
      expect(result.actualDiscriminator, equals(actual));
      expect(result.mismatchIndex, equals(7));
    });
  });

  group('DiscriminatorValidationException', () {
    test('creates exception from validation result', () {
      final result = DiscriminatorValidationResult.failure(
        message: 'Test validation error',
      );

      final exception = DiscriminatorValidationException(result);

      expect(exception.result, equals(result));
      expect(exception.toString().contains('Test validation error'), isTrue);
    });
  });

  group('DiscriminatorValidationUtils', () {
    test('validateOrThrow passes for valid discriminators', () {
      final validator = DiscriminatorValidator();
      final discriminator = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      expect(
        () => DiscriminatorValidationUtils.validateOrThrow(
          validator,
          discriminator,
          discriminator,
        ),
        returnsNormally,
      );
    });

    test('validateOrThrow throws for invalid discriminators', () {
      final validator = DiscriminatorValidator();
      final expected = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final actual = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);

      expect(
        () => DiscriminatorValidationUtils.validateOrThrow(
          validator,
          expected,
          actual,
        ),
        throwsA(isA<DiscriminatorValidationException>()),
      );
    });

    test('quickValidate works correctly', () {
      final discriminator1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final discriminator2 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final discriminator3 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);

      expect(
          DiscriminatorValidationUtils.quickValidate(
              discriminator1, discriminator2,),
          isTrue,);
      expect(
          DiscriminatorValidationUtils.quickValidate(
              discriminator1, discriminator3,),
          isFalse,);
    });

    test('quickValidate rejects wrong size', () {
      final validDiscriminator = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final invalidDiscriminator = Uint8List.fromList([1, 2, 3]);

      expect(
          DiscriminatorValidationUtils.quickValidate(
              validDiscriminator, invalidDiscriminator,),
          isFalse,);
    });

    test('extractDiscriminator works correctly', () {
      final accountData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final shortData = Uint8List.fromList([1, 2, 3]);

      final extracted =
          DiscriminatorValidationUtils.extractDiscriminator(accountData);
      final extractedShort =
          DiscriminatorValidationUtils.extractDiscriminator(shortData);

      expect(extracted, equals(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])));
      expect(extractedShort, isNull);
    });
  });

  group('Error Formatting', () {
    test('formats bytes correctly in error messages', () {
      final validator = DiscriminatorValidator();
      final expected = Uint8List.fromList([255, 0, 15, 240, 5, 6, 7, 8]);
      final actual = Uint8List.fromList([254, 1, 16, 239, 5, 6, 7, 8]);

      final result = validator.validate(expected, actual);

      expect(result.errorMessage!.contains('0xFF'), isTrue);
      expect(result.errorMessage!.contains('0xFE'), isTrue);
      expect(result.errorMessage!.contains('FF000FF005060708'), isTrue);
      expect(result.errorMessage!.contains('FE0110EF05060708'), isTrue);
    });

    test('includes complete hex representation in error', () {
      final validator = DiscriminatorValidator();
      final expected = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final actual = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);

      final result = validator.validate(expected, actual);

      expect(
          result.errorMessage!
              .contains('Expected discriminator: 0102030405060708'),
          isTrue,);
      expect(
          result.errorMessage!
              .contains('Actual discriminator:   0102030405060709'),
          isTrue,);
    });
  });

  group('Performance', () {
    test('handles large number of validations efficiently', () {
      final validator = DiscriminatorValidator();
      final baseDiscriminator = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      // Perform many validations
      for (int i = 0; i < 1000; i++) {
        final discriminator =
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, i % 256]);
        validator.validate(baseDiscriminator, discriminator);
      }

      // Should complete without issues
      expect(validator.cacheSize, greaterThan(0));
    });

    test('cache improves performance for repeated validations', () {
      final validator = DiscriminatorValidator();
      final discriminator1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final discriminator2 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);

      // First set of validations
      for (int i = 0; i < 100; i++) {
        validator.validate(discriminator1, discriminator2);
      }

      // Clear cache and repeat
      validator.clearCache();
      for (int i = 0; i < 100; i++) {
        validator.validate(discriminator1, discriminator2);
      }

      // Should have some cache entries
      expect(validator.cacheSize, greaterThan(0));
    });
  });
}
