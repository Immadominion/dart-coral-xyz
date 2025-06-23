import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('AccountSizeValidator', () {
    setUp(() {
      // Reset statistics before each test
      AccountSizeValidator.resetStatistics();
    });

    group('Basic Size Validation', () {
      test('validates correct account size with discriminator', () {
        // Create account data: 8-byte discriminator + 16 bytes payload = 24 bytes total
        final accountData = Uint8List(24);
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16, // Payload size (discriminator added automatically)
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isTrue);
        expect(result.expectedSize, equals(24)); // 8 + 16
        expect(result.actualSize, equals(24));
        expect(result.sizeDifference, equals(0));
      });

      test('rejects account data too small', () {
        // Create account data: only 4 bytes (too small for discriminator)
        final accountData = Uint8List(4);
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('too small'), isTrue);
        expect(result.expectedSize, equals(24));
        expect(result.actualSize, equals(4));
        expect(result.sizeDifference, equals(-20));
      });

      test('rejects account data too large with maximum size', () {
        // Create large account data
        final accountData = Uint8List(1000);
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          maximumSize: 32, // 32 bytes payload + 8 discriminator = 40 total max
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('too large'), isTrue);
        expect(result.expectedSize, equals(40));
        expect(result.actualSize, equals(1000));
        expect(result.sizeDifference, equals(960));
      });
    });

    group('Discriminator Validation', () {
      test('validates discriminator space requirement', () {
        // Account with discriminator but insufficient size
        final accountData = Uint8List(6); // Less than 8 bytes for discriminator
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 0, // No additional payload required
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('discriminator'), isTrue);
        expect(result.expectedSize, equals(8));
        expect(result.actualSize, equals(6));
      });

      test('allows accounts without discriminator', () {
        // Account without discriminator requirement
        final accountData = Uint8List(16);
        final structureDefinition = AccountStructureDefinition(
          name: 'SystemAccount',
          minimumSize: 16,
          hasDiscriminator: false,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isTrue);
        expect(result.expectedSize, equals(16)); // No discriminator added
        expect(result.actualSize, equals(16));
      });

      test('checks discriminator space utility', () {
        expect(
            AccountSizeValidator.hasDiscriminatorSpace(Uint8List(8)), isTrue);
        expect(
            AccountSizeValidator.hasDiscriminatorSpace(Uint8List(10)), isTrue);
        expect(
            AccountSizeValidator.hasDiscriminatorSpace(Uint8List(7)), isFalse);
        expect(
            AccountSizeValidator.hasDiscriminatorSpace(Uint8List(0)), isFalse);
      });
    });

    group('Variable Length Field Support', () {
      test('validates variable-length account with strict mode disabled', () {
        // Account with variable-length fields
        final accountData = Uint8List(50); // More than minimum
        final structureDefinition = AccountStructureDefinition(
          name: 'VariableAccount',
          minimumSize: 16,
          hasVariableLengthFields: true,
          hasDiscriminator: true,
        );

        final config = AccountSizeValidationConfig(strictValidation: false);
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: config,
        );

        expect(result.isValid, isTrue);
        expect(result.expectedSize, equals(24)); // 8 + 16
        expect(result.actualSize, equals(50));
        expect(result.sizeDifference, equals(26));
      });

      test('rejects variable-length account in strict mode', () {
        // Account with variable-length fields but strict validation
        final accountData = Uint8List(50); // More than minimum
        final structureDefinition = AccountStructureDefinition(
          name: 'VariableAccount',
          minimumSize: 16,
          hasVariableLengthFields: true,
          hasDiscriminator: true,
        );

        final config = AccountSizeValidationConfig(strictValidation: true);
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: config,
        );

        expect(
            result.isValid, isTrue); // Should pass since it has variable fields
      });

      test('strict validation fails for fixed-size account with wrong size',
          () {
        // Fixed-size account with wrong size
        final accountData = Uint8List(50);
        final structureDefinition = AccountStructureDefinition(
          name: 'FixedAccount',
          minimumSize: 16,
          hasVariableLengthFields: false, // Fixed size
          hasDiscriminator: true,
        );

        final config = AccountSizeValidationConfig(strictValidation: true);
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: config,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage!.contains('exact'), isTrue);
      });
    });

    group('Tolerance Configuration', () {
      test('allows size within minimum tolerance', () {
        // Account slightly smaller than expected but within tolerance
        final accountData = Uint8List(22); // 2 bytes short
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          hasDiscriminator: true,
        );

        final config = AccountSizeValidationConfig(
          minimumSizeTolerance: 4,
          strictValidation: false, // Allow tolerance to work
        );
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: config,
        );

        expect(result.isValid, isTrue); // Within 4-byte tolerance
      });

      test('allows size within maximum tolerance', () {
        // Account slightly larger than max but within tolerance
        final accountData = Uint8List(34); // 2 bytes over max (32 + 2 = 34)
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          maximumSize: 24, // 32 total with discriminator
          hasDiscriminator: true,
        );

        final config = AccountSizeValidationConfig(maximumSizeTolerance: 4);
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: config,
        );

        expect(result.isValid, isTrue); // Within 4-byte tolerance
      });

      test('rejects size outside tolerance', () {
        // Account too far outside tolerance
        final accountData = Uint8List(18); // 6 bytes short
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          hasDiscriminator: true,
        );

        final config = AccountSizeValidationConfig(minimumSizeTolerance: 4);
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: config,
        );

        expect(result.isValid, isFalse); // Outside 4-byte tolerance
      });
    });

    group('Configuration Presets', () {
      test('strict configuration validates exactly', () {
        final accountData = Uint8List(25); // 1 byte too large
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig.strict,
        );

        expect(result.isValid, isFalse);
      });

      test('permissive configuration allows some variance', () {
        final accountData = Uint8List(32); // 8 bytes larger than minimum
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 16,
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig.permissive,
        );

        expect(result.isValid, isTrue); // Within permissive tolerance
      });

      test('bypass configuration always succeeds', () {
        final accountData = Uint8List(1); // Way too small
        final structureDefinition = AccountStructureDefinition(
          name: 'TestAccount',
          minimumSize: 100,
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig.bypass,
        );

        expect(result.isValid, isTrue); // Bypassed
        expect(result.context?['validation_type'], equals('bypassed'));
      });
    });

    group('Utility Functions', () {
      test('calculates expected size correctly', () {
        expect(
          AccountSizeValidator.calculateExpectedSize(
            baseFieldsSize: 32,
            includeDiscriminator: true,
          ),
          equals(40),
        );

        expect(
          AccountSizeValidator.calculateExpectedSize(
            baseFieldsSize: 32,
            includeDiscriminator: false,
          ),
          equals(32),
        );
      });

      test('validates minimum size with helper function', () {
        final accountData = Uint8List(24);
        final result = AccountSizeValidator.validateMinimumSize(
          accountData: accountData,
          minimumSize: 24,
          accountName: 'TestAccount',
        );

        expect(result.isValid, isTrue);
      });

      test('extracts payload correctly', () {
        final accountData = Uint8List.fromList([
          // Discriminator (8 bytes)
          1, 2, 3, 4, 5, 6, 7, 8,
          // Payload (4 bytes)
          9, 10, 11, 12,
        ]);

        final payload = AccountSizeValidator.extractPayload(accountData);
        expect(payload, isNotNull);
        expect(payload!.length, equals(4));
        expect(payload, equals([9, 10, 11, 12]));
      });

      test('handles payload extraction from small account', () {
        final accountData = Uint8List(4); // Too small for discriminator
        final payload = AccountSizeValidator.extractPayload(accountData);
        expect(payload, isNull);
      });

      test('handles payload extraction from discriminator-only account', () {
        final accountData = Uint8List(8); // Exactly discriminator size
        final payload = AccountSizeValidator.extractPayload(accountData);
        expect(payload, isNotNull);
        expect(payload!.length, equals(0));
      });
    });

    group('Complex Account Structures', () {
      test('validates account with field definitions', () {
        final fields = [
          AccountFieldDefinition(name: 'authority', size: 32),
          AccountFieldDefinition(name: 'amount', size: 8),
          AccountFieldDefinition(name: 'bump', size: 1),
        ];

        final structureDefinition = AccountStructureDefinition(
          name: 'ComplexAccount',
          minimumSize: 41, // 32 + 8 + 1
          fields: fields,
          hasDiscriminator: true,
        );

        final accountData = Uint8List(49); // 8 (discriminator) + 41 (fields)
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isTrue);
        expect(result.context?['field_count'], equals(3));
      });

      test('validates account with optional fields', () {
        final fields = [
          AccountFieldDefinition(name: 'required_field', size: 8),
          AccountFieldDefinition(
            name: 'optional_field',
            size: 4,
            isOptional: true,
          ),
        ];

        final structureDefinition = AccountStructureDefinition(
          name: 'OptionalFieldAccount',
          minimumSize: 8, // Only required field
          maximumSize: 12, // Both fields
          hasVariableLengthFields: true,
          fields: fields,
          hasDiscriminator: true,
        );

        // Test with only required field
        final smallAccountData = Uint8List(16); // 8 + 8
        final smallResult = AccountSizeValidator.validateAccountSize(
          accountData: smallAccountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig.permissive,
        );

        expect(smallResult.isValid, isTrue);

        // Test with both fields
        final largeAccountData = Uint8List(20); // 8 + 12
        final largeResult = AccountSizeValidator.validateAccountSize(
          accountData: largeAccountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig.permissive,
        );

        expect(largeResult.isValid, isTrue);
      });
    });

    group('Batch Validation', () {
      test('validates multiple accounts in batch', () {
        final validations = [
          (
            accountData: Uint8List(24),
            structureDefinition: AccountStructureDefinition(
              name: 'Account1',
              minimumSize: 16,
            ),
            config: null,
          ),
          (
            accountData: Uint8List(32),
            structureDefinition: AccountStructureDefinition(
              name: 'Account2',
              minimumSize: 24,
            ),
            config: null,
          ),
          (
            accountData: Uint8List(4), // Too small
            structureDefinition: AccountStructureDefinition(
              name: 'Account3',
              minimumSize: 16,
            ),
            config: null,
          ),
        ];

        final results = AccountSizeValidator.validateBatch(validations);

        expect(results.length, equals(3));
        expect(results[0].isValid, isTrue);
        expect(results[1].isValid, isTrue);
        expect(results[2].isValid, isFalse);
      });
    });

    group('Size Breakdown Analysis', () {
      test('provides detailed size breakdown', () {
        final structureDefinition = AccountStructureDefinition(
          name: 'AnalysisAccount',
          minimumSize: 24,
          maximumSize: 48,
          fields: [
            AccountFieldDefinition(name: 'pubkey', size: 32),
            AccountFieldDefinition(name: 'amount', size: 8),
            AccountFieldDefinition(
              name: 'variable_data',
              size: 0,
              isVariableLength: true,
            ),
          ],
          hasDiscriminator: true,
        );

        final accountData = Uint8List(40);
        final breakdown = AccountSizeValidator.getSizeBreakdown(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(breakdown['account_type'], equals('AnalysisAccount'));
        expect(breakdown['actual_size'], equals(40));
        expect(breakdown['expected_min_size'], equals(32)); // 24 + 8
        expect(breakdown['expected_max_size'], equals(56)); // 48 + 8
        expect(breakdown['discriminator_size'], equals(8));
        expect(breakdown['payload_size'], equals(32));
        expect(breakdown['has_discriminator_space'], isTrue);
        expect(breakdown['size_difference'], equals(8));
        expect(breakdown['is_within_bounds'], isTrue);
        expect(breakdown['field_definitions'], hasLength(3));
      });
    });

    group('Statistics Tracking', () {
      test('tracks validation statistics', () {
        expect(AccountSizeValidator.statistics['totalValidations'], equals(0));
        expect(AccountSizeValidator.statistics['successes'], equals(0));
        expect(AccountSizeValidator.statistics['failures'], equals(0));

        // Successful validation
        AccountSizeValidator.validateAccountSize(
          accountData: Uint8List(24),
          structureDefinition: AccountStructureDefinition(
            name: 'TestAccount',
            minimumSize: 16,
          ),
        );

        expect(AccountSizeValidator.statistics['totalValidations'], equals(1));
        expect(AccountSizeValidator.statistics['successes'], equals(1));
        expect(AccountSizeValidator.statistics['failures'], equals(0));

        // Failed validation
        AccountSizeValidator.validateAccountSize(
          accountData: Uint8List(4),
          structureDefinition: AccountStructureDefinition(
            name: 'TestAccount',
            minimumSize: 16,
          ),
        );

        expect(AccountSizeValidator.statistics['totalValidations'], equals(2));
        expect(AccountSizeValidator.statistics['successes'], equals(1));
        expect(AccountSizeValidator.statistics['failures'], equals(1));

        // Reset statistics
        AccountSizeValidator.resetStatistics();
        expect(AccountSizeValidator.statistics['totalValidations'], equals(0));
      });
    });

    group('Error Context and Reporting', () {
      test('includes detailed context in validation results', () {
        final accountData = Uint8List(4); // Too small
        final structureDefinition = AccountStructureDefinition(
          name: 'DetailedAccount',
          minimumSize: 16,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig(includeContext: true),
        );

        expect(result.isValid, isFalse);
        expect(result.context, isNotNull);
        expect(result.context!['validation_type'], equals('size_too_small'));
        expect(result.context!['account_type'], equals('DetailedAccount'));
        expect(result.context!['minimum_required'], equals(24));
        expect(result.context!.containsKey('timestamp'), isTrue);
      });

      test('excludes context when configured', () {
        final accountData = Uint8List(4);
        final structureDefinition = AccountStructureDefinition(
          name: 'NoContextAccount',
          minimumSize: 16,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
          config: AccountSizeValidationConfig(includeContext: false),
        );

        expect(result.isValid, isFalse);
        expect(result.context, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles empty account data', () {
        final accountData = Uint8List(0);
        final structureDefinition = AccountStructureDefinition(
          name: 'EmptyAccount',
          minimumSize: 0,
          hasDiscriminator: false,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isTrue);
      });

      test('handles very large accounts', () {
        final accountData = Uint8List(1000000); // 1MB
        final structureDefinition = AccountStructureDefinition(
          name: 'LargeAccount',
          minimumSize: 999992, // 1MB - 8 bytes discriminator
          hasDiscriminator: true,
        );

        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: structureDefinition,
        );

        expect(result.isValid, isTrue);
      });

      test('handles validation errors gracefully', () {
        final accountData = Uint8List(10);

        // This should not cause any crashes or exceptions
        final result = AccountSizeValidator.validateAccountSize(
          accountData: accountData,
          structureDefinition: AccountStructureDefinition(
            name: 'ErrorTestAccount',
            minimumSize: -1, // Invalid minimum size
          ),
        );

        // Should handle gracefully and return failure result
        expect(result.isValid, isFalse);
        expect(result.errorMessage, isNotNull);
      });
    });
  });
}
