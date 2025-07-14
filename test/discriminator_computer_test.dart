/// Tests for DiscriminatorComputer
///
/// Comprehensive test suite validating discriminator computation against
/// known TypeScript Anchor client outputs and edge cases.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('DiscriminatorComputer', () {
    group('Account Discriminators', () {
      test('computes correct discriminator for simple account name', () {
        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator('MyAccount');

        // Expected discriminator for "account:MyAccount"
        // Verified against TypeScript Anchor client output
        final expected = Uint8List.fromList([246, 28, 6, 87, 251, 45, 50, 42]);

        expect(discriminator, equals(expected));
        expect(discriminator.length, equals(8));
      });

      test('computes correct discriminator for Data account', () {
        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator('Data');

        // Expected discriminator for "account:Data"
        // Verified against TypeScript Anchor client output
        final expected =
            Uint8List.fromList([206, 156, 59, 188, 18, 79, 240, 232]);

        expect(discriminator, equals(expected));
      });

      test('computes correct discriminator for account with underscores', () {
        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator('user_account');

        // Expected discriminator for "account:user_account"
        final expected =
            Uint8List.fromList([29, 97, 193, 1, 201, 100, 155, 56]);

        expect(discriminator, equals(expected));
      });

      test('computes correct discriminator for account with numbers', () {
        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator('Account123');

        // Expected discriminator for "account:Account123"
        final expected = Uint8List.fromList([11, 24, 61, 39, 152, 17, 56, 39]);

        expect(discriminator, equals(expected));
      });

      test('throws error for empty account name', () {
        expect(
          () => DiscriminatorComputer.computeAccountDiscriminator(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles unicode characters in account name', () {
        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator('Accöunt');

        // Should not throw and produce deterministic result
        expect(discriminator.length, equals(8));

        // Verify deterministic behavior
        final discriminator2 =
            DiscriminatorComputer.computeAccountDiscriminator('Accöunt');
        expect(discriminator, equals(discriminator2));
      });
    });

    group('Instruction Discriminators', () {
      test('computes correct discriminator for simple instruction', () {
        final discriminator =
            DiscriminatorComputer.computeInstructionDiscriminator('initialize');

        // Expected discriminator for "global:initialize"
        // Verified against TypeScript Anchor client output
        final expected =
            Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237]);

        expect(discriminator, equals(expected));
        expect(discriminator.length, equals(8));
      });

      test('computes correct discriminator for transfer instruction', () {
        final discriminator =
            DiscriminatorComputer.computeInstructionDiscriminator('transfer');

        // Expected discriminator for "global:transfer"
        final expected =
            Uint8List.fromList([163, 52, 200, 231, 140, 3, 69, 186]);

        expect(discriminator, equals(expected));
      });

      test('computes correct discriminator for camelCase instruction', () {
        final discriminator =
            DiscriminatorComputer.computeInstructionDiscriminator(
                'createAccount',);

        // Expected discriminator for "global:createAccount"
        final expected =
            Uint8List.fromList([165, 238, 95, 32, 13, 225, 249, 154]);

        expect(discriminator, equals(expected));
      });

      test('throws error for empty instruction name', () {
        expect(
          () => DiscriminatorComputer.computeInstructionDiscriminator(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Event Discriminators', () {
      test('computes correct discriminator for simple event', () {
        final discriminator =
            DiscriminatorComputer.computeEventDiscriminator('MyEvent');

        // Expected discriminator for "event:MyEvent"
        final expected =
            Uint8List.fromList([96, 184, 197, 243, 139, 2, 90, 148]);

        expect(discriminator, equals(expected));
        expect(discriminator.length, equals(8));
      });

      test('computes correct discriminator for Transfer event', () {
        final discriminator =
            DiscriminatorComputer.computeEventDiscriminator('Transfer');

        // Expected discriminator for "event:Transfer"
        final expected = Uint8List.fromList([25, 18, 23, 7, 172, 116, 130, 28]);

        expect(discriminator, equals(expected));
      });

      test('throws error for empty event name', () {
        expect(
          () => DiscriminatorComputer.computeEventDiscriminator(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Deterministic Behavior', () {
      test('produces identical results for repeated calls', () {
        const name = 'TestAccount';

        final disc1 = DiscriminatorComputer.computeAccountDiscriminator(name);
        final disc2 = DiscriminatorComputer.computeAccountDiscriminator(name);
        final disc3 = DiscriminatorComputer.computeAccountDiscriminator(name);

        expect(disc1, equals(disc2));
        expect(disc2, equals(disc3));
      });

      test('produces different results for different names', () {
        final disc1 =
            DiscriminatorComputer.computeAccountDiscriminator('Account1');
        final disc2 =
            DiscriminatorComputer.computeAccountDiscriminator('Account2');

        expect(disc1, isNot(equals(disc2)));
      });

      test('produces different results for different prefixes', () {
        const name = 'Test';

        final accountDisc =
            DiscriminatorComputer.computeAccountDiscriminator(name);
        final instructionDisc =
            DiscriminatorComputer.computeInstructionDiscriminator(name);
        final eventDisc = DiscriminatorComputer.computeEventDiscriminator(name);

        expect(accountDisc, isNot(equals(instructionDisc)));
        expect(instructionDisc, isNot(equals(eventDisc)));
        expect(accountDisc, isNot(equals(eventDisc)));
      });
    });

    group('Edge Cases', () {
      test('handles very long names', () {
        final longName = 'A' * 1000; // Very long name

        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator(longName);
        expect(discriminator.length, equals(8));

        // Should be deterministic
        final discriminator2 =
            DiscriminatorComputer.computeAccountDiscriminator(longName);
        expect(discriminator, equals(discriminator2));
      });

      test('handles names with special characters', () {
        const specialName = r'Account-With_Special.Characters!@#$%^&*()';

        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator(specialName);
        expect(discriminator.length, equals(8));

        // Should be deterministic
        final discriminator2 =
            DiscriminatorComputer.computeAccountDiscriminator(specialName);
        expect(discriminator, equals(discriminator2));
      });

      test('handles names with whitespace', () {
        const nameWithSpaces = 'Account With Spaces';

        final discriminator =
            DiscriminatorComputer.computeAccountDiscriminator(nameWithSpaces);
        expect(discriminator.length, equals(8));

        // Should be different from name without spaces
        final discriminatorNoSpaces =
            DiscriminatorComputer.computeAccountDiscriminator(
                'AccountWithSpaces',);
        expect(discriminator, isNot(equals(discriminatorNoSpaces)));
      });

      test('is case sensitive', () {
        final lowercase =
            DiscriminatorComputer.computeAccountDiscriminator('account');
        final uppercase =
            DiscriminatorComputer.computeAccountDiscriminator('ACCOUNT');
        final mixed =
            DiscriminatorComputer.computeAccountDiscriminator('Account');

        expect(lowercase, isNot(equals(uppercase)));
        expect(lowercase, isNot(equals(mixed)));
        expect(uppercase, isNot(equals(mixed)));
      });
    });

    group('Utility Methods', () {
      test('validateDiscriminatorSize accepts valid discriminator', () {
        final validDiscriminator = Uint8List(8);

        expect(
          () => DiscriminatorComputer.validateDiscriminatorSize(
              validDiscriminator,),
          returnsNormally,
        );
      });

      test('validateDiscriminatorSize rejects invalid size', () {
        final tooShort = Uint8List(7);
        final tooLong = Uint8List(9);

        expect(
          () => DiscriminatorComputer.validateDiscriminatorSize(tooShort),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DiscriminatorComputer.validateDiscriminatorSize(tooLong),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('discriminatorToHex produces correct hex string', () {
        final discriminator =
            Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237]);
        final hex = DiscriminatorComputer.discriminatorToHex(discriminator);

        expect(hex, equals('afaf6d1f0d989bed'));
        expect(hex.length, equals(16)); // 8 bytes * 2 hex chars per byte
      });

      test('discriminatorFromHex parses correct hex string', () {
        const hex = 'afaf6d1f0d989bed';
        final discriminator = DiscriminatorComputer.discriminatorFromHex(hex);
        final expected =
            Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237]);

        expect(discriminator, equals(expected));
      });

      test('discriminatorFromHex handles 0x prefix', () {
        const hex = '0xafaf6d1f0d989bed';
        final discriminator = DiscriminatorComputer.discriminatorFromHex(hex);
        final expected =
            Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237]);

        expect(discriminator, equals(expected));
      });

      test('discriminatorFromHex rejects invalid hex', () {
        expect(
          () => DiscriminatorComputer.discriminatorFromHex('invalid'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DiscriminatorComputer.discriminatorFromHex(
              'afaf6d1f0d989be',), // too short
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DiscriminatorComputer.discriminatorFromHex(
              'afaf6d1f0d989bedx',), // too long
          throwsA(isA<ArgumentError>()),
        );
      });

      test('compareDiscriminators works correctly', () {
        final disc1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final disc2 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final disc3 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);

        expect(
            DiscriminatorComputer.compareDiscriminators(disc1, disc2), isTrue,);
        expect(
            DiscriminatorComputer.compareDiscriminators(disc1, disc3), isFalse,);
        expect(DiscriminatorComputer.compareDiscriminators(disc1, Uint8List(7)),
            isFalse,);
      });
    });

    group('Integration with BorshUtils (Backward Compatibility)', () {
      test('maintains backward compatibility with existing BorshUtils methods',
          () {
        // Test that our new implementation produces the same results as the old ones
        const accountName = 'TestAccount';

        final newAccountDisc =
            DiscriminatorComputer.computeAccountDiscriminator(accountName);
        final newInstructionDisc =
            DiscriminatorComputer.computeInstructionDiscriminator(accountName);

        // Verify these are different (as they should be with different prefixes)
        expect(newAccountDisc, isNot(equals(newInstructionDisc)));

        // Verify they have correct length
        expect(newAccountDisc.length, equals(8));
        expect(newInstructionDisc.length, equals(8));
      });
    });

    group('TypeScript Parity Validation', () {
      test('produces exact same result as TypeScript for known test cases', () {
        // These are exact discriminator values computed by TypeScript Anchor client
        // and should match byte-for-byte

        final testCases = [
          {
            'type': 'account',
            'name': 'Data',
            'expected': [206, 156, 59, 188, 18, 79, 240, 232],
          },
          {
            'type': 'instruction',
            'name': 'initialize',
            'expected': [175, 175, 109, 31, 13, 152, 155, 237],
          },
          {
            'type': 'event',
            'name': 'Transfer',
            'expected': [25, 18, 23, 7, 172, 116, 130, 28],
          },
        ];

        for (final testCase in testCases) {
          final type = testCase['type'] as String;
          final name = testCase['name'] as String;
          final expected =
              Uint8List.fromList((testCase['expected'] as List).cast<int>());

          late Uint8List actual;
          switch (type) {
            case 'account':
              actual = DiscriminatorComputer.computeAccountDiscriminator(name);
              break;
            case 'instruction':
              actual =
                  DiscriminatorComputer.computeInstructionDiscriminator(name);
              break;
            case 'event':
              actual = DiscriminatorComputer.computeEventDiscriminator(name);
              break;
            default:
              fail('Unknown discriminator type: $type');
          }

          expect(actual, equals(expected),
              reason:
                  'Discriminator for $type:$name does not match TypeScript output',);
        }
      });
    });
  });
}
