/// T1.2 — Discriminator Computation Component Tests
///
/// Verifies DiscriminatorComputer produces byte-identical results to the
/// TypeScript Anchor client SHA256-based discriminator computation.
///
/// Ground truth: SHA256 sums computed via `echo -n "prefix:name" | shasum -a 256`
/// and cross-verified against anchor/tests/idl/idls/new.json discriminator arrays.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:coral_xyz/src/coder/discriminator_computer.dart';
import 'package:test/test.dart';

void main() {
  group('DiscriminatorComputer — instruction discriminators', () {
    // Ground truth from: echo -n "global:<name>" | shasum -a 256 | first 8 bytes
    // Cross-verified with anchor/tests/idl/idls/new.json

    test('cause_error matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeInstructionDiscriminator(
        'cause_error',
      );
      expect(disc, orderedEquals([67, 104, 37, 17, 2, 155, 68, 17]));
    });

    test('initialize matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeInstructionDiscriminator(
        'initialize',
      );
      expect(disc, orderedEquals([175, 175, 109, 31, 13, 152, 155, 237]));
    });

    test('initialize_with_values matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeInstructionDiscriminator(
        'initialize_with_values',
      );
      expect(disc, orderedEquals([220, 73, 8, 213, 178, 69, 181, 141]));
    });

    test('initialize_with_values2 matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeInstructionDiscriminator(
        'initialize_with_values2',
      );
      expect(disc, orderedEquals([248, 190, 21, 97, 239, 148, 39, 181]));
    });

    test('produces exactly 8 bytes', () {
      final disc = DiscriminatorComputer.computeInstructionDiscriminator(
        'anything',
      );
      expect(disc.length, 8);
      expect(disc, isA<Uint8List>());
    });

    test('throws on empty name', () {
      expect(
        () => DiscriminatorComputer.computeInstructionDiscriminator(''),
        throwsArgumentError,
      );
    });

    test('different names produce different discriminators', () {
      final d1 = DiscriminatorComputer.computeInstructionDiscriminator(
        'initialize',
      );
      final d2 = DiscriminatorComputer.computeInstructionDiscriminator(
        'increment',
      );
      expect(d1, isNot(orderedEquals(d2)));
    });
  });

  group('DiscriminatorComputer — account discriminators', () {
    test('State matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeAccountDiscriminator('State');
      expect(disc, orderedEquals([216, 146, 107, 94, 104, 75, 182, 177]));
    });

    test('State2 matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeAccountDiscriminator('State2');
      expect(disc, orderedEquals([106, 97, 255, 161, 250, 205, 185, 192]));
    });

    test('SomeZcAccount matches IDL', () {
      final disc = DiscriminatorComputer.computeAccountDiscriminator(
        'SomeZcAccount',
      );
      expect(disc, orderedEquals([56, 72, 82, 194, 210, 35, 17, 191]));
    });

    test('throws on empty name', () {
      expect(
        () => DiscriminatorComputer.computeAccountDiscriminator(''),
        throwsArgumentError,
      );
    });
  });

  group('DiscriminatorComputer — event discriminators', () {
    test('SomeEvent matches IDL and SHA256', () {
      final disc = DiscriminatorComputer.computeEventDiscriminator('SomeEvent');
      expect(disc, orderedEquals([39, 221, 150, 148, 91, 206, 29, 93]));
    });

    test('throws on empty name', () {
      expect(
        () => DiscriminatorComputer.computeEventDiscriminator(''),
        throwsArgumentError,
      );
    });
  });

  group('DiscriminatorComputer — hex utilities', () {
    test('discriminatorToHex produces correct hex string', () {
      final disc = Uint8List.fromList([67, 104, 37, 17, 2, 155, 68, 17]);
      expect(
        DiscriminatorComputer.discriminatorToHex(disc),
        '43682511029b4411',
      );
    });

    test('discriminatorFromHex round-trips with discriminatorToHex', () {
      final disc = Uint8List.fromList([175, 175, 109, 31, 13, 152, 155, 237]);
      final hexStr = DiscriminatorComputer.discriminatorToHex(disc);
      final restored = DiscriminatorComputer.discriminatorFromHex(hexStr);
      expect(restored, orderedEquals(disc));
    });

    test('discriminatorFromHex handles 0x prefix', () {
      final disc = DiscriminatorComputer.discriminatorFromHex(
        '0x43682511029b4411',
      );
      expect(disc, orderedEquals([67, 104, 37, 17, 2, 155, 68, 17]));
    });

    test('discriminatorFromHex throws on wrong length', () {
      expect(
        () => DiscriminatorComputer.discriminatorFromHex('aabb'),
        throwsArgumentError,
      );
    });
  });

  group('DiscriminatorComputer — compare', () {
    test('equal discriminators return true', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final b = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(DiscriminatorComputer.compareDiscriminators(a, b), isTrue);
    });

    test('different discriminators return false', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final b = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 9]);
      expect(DiscriminatorComputer.compareDiscriminators(a, b), isFalse);
    });

    test('different-length discriminators return false', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 3, 4]);
      expect(DiscriminatorComputer.compareDiscriminators(a, b), isFalse);
    });
  });

  group('DiscriminatorComputer — Quasar explicit discriminators', () {
    test('fromExplicit creates discriminator from byte list', () {
      final disc = DiscriminatorComputer.fromExplicit([0]);
      expect(disc, orderedEquals([0]));
      expect(disc.length, 1);
    });

    test('fromExplicit with multi-byte discriminator', () {
      final disc = DiscriminatorComputer.fromExplicit([1, 0, 0, 0]);
      expect(disc, orderedEquals([1, 0, 0, 0]));
      expect(disc.length, 4);
    });

    test('fromExplicit throws on empty list', () {
      expect(() => DiscriminatorComputer.fromExplicit([]), throwsArgumentError);
    });

    test('isExplicit returns true for short discriminators', () {
      expect(DiscriminatorComputer.isExplicit([0]), isTrue);
      expect(DiscriminatorComputer.isExplicit([1, 2, 3]), isTrue);
      expect(DiscriminatorComputer.isExplicit([1, 2, 3, 4, 5, 6, 7]), isTrue);
    });

    test('isExplicit returns false for 8-byte discriminators', () {
      expect(
        DiscriminatorComputer.isExplicit([1, 2, 3, 4, 5, 6, 7, 8]),
        isFalse,
      );
    });

    test('isExplicit returns false for empty list', () {
      expect(DiscriminatorComputer.isExplicit([]), isFalse);
    });

    test('hasQuasarEventPrefix detects 0xFF', () {
      expect(DiscriminatorComputer.hasQuasarEventPrefix([0xFF, 1, 2]), isTrue);
      expect(DiscriminatorComputer.hasQuasarEventPrefix([0xFE, 1, 2]), isFalse);
      expect(DiscriminatorComputer.hasQuasarEventPrefix([]), isFalse);
    });

    test('validateExplicitDiscriminator rejects all-zero', () {
      expect(
        () => DiscriminatorComputer.validateExplicitDiscriminator([0, 0, 0]),
        throwsArgumentError,
      );
    });

    test(
      'validateExplicitDiscriminator rejects 0xFF prefix for non-events',
      () {
        expect(
          () => DiscriminatorComputer.validateExplicitDiscriminator([0xFF, 1]),
          throwsArgumentError,
        );
      },
    );

    test('validateExplicitDiscriminator allows 0xFF prefix for events', () {
      // Should not throw
      DiscriminatorComputer.validateExplicitDiscriminator([
        0xFF,
        1,
      ], isEvent: true);
    });
  });

  group('DiscriminatorComputer.resolve — dispatch', () {
    test('returns explicit discriminator when provided', () {
      final disc = DiscriminatorComputer.resolve(
        prefix: 'global:',
        name: 'initialize',
        explicit: [42],
      );
      expect(disc, orderedEquals([42]));
    });

    test('computes SHA256 discriminator when explicit is null', () {
      final disc = DiscriminatorComputer.resolve(
        prefix: 'global:',
        name: 'initialize',
        explicit: null,
      );
      expect(disc, orderedEquals([175, 175, 109, 31, 13, 152, 155, 237]));
    });

    test('computes SHA256 discriminator when explicit is empty', () {
      final disc = DiscriminatorComputer.resolve(
        prefix: 'global:',
        name: 'initialize',
        explicit: [],
      );
      expect(disc, orderedEquals([175, 175, 109, 31, 13, 152, 155, 237]));
    });
  });
}
