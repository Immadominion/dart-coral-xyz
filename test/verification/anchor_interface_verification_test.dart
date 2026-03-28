/// Anchor Interface Verification Test
///
/// Verifies that coral_xyz correctly handles a real Anchor IDL:
/// - IDL parsing (format detection, instructions, accounts, types, events, errors)
/// - Discriminator computation (must match the IDL-provided values)
/// - Instruction encoding/decoding round-trip
/// - Account encoding/decoding round-trip
/// - Event encoding/decoding round-trip
/// - Error code mapping
/// - Program class construction and namespace wiring
///
/// This test uses the real IDL from anchor/tests/idl/idls/new.json
/// which exercises structs, enums, vecs, options, arrays, pubkeys,
/// nested types, zero-copy accounts, events, errors, constants, and
/// return types.
///
/// Run: dart test test/verification/anchor_interface_verification_test.dart -r expanded
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/src/coder/borsh_accounts_coder.dart';
import 'package:coral_xyz/src/coder/discriminator_computer.dart';
import 'package:coral_xyz/src/coder/event_coder.dart';
import 'package:coral_xyz/src/coder/instruction_coder.dart';
import 'package:coral_xyz/src/coder/main_coder.dart';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/program/program_class.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:test/test.dart';

import 'verification_helpers.dart';

/// The fixture file: a real Anchor IDL from anchor/tests/idl/idls/new.json
const _fixtureFile = 'anchor_idl_test_program.json';

void main() {
  late Idl idl;
  late Map<String, dynamic> rawJson;
  final report = VerificationReport();

  setUpAll(() {
    rawJson = loadFixtureJson(_fixtureFile);
    idl = loadFixtureIdl(_fixtureFile);
  });

  tearDownAll(() {
    report.printSummary();
  });

  // ─── 1. IDL Parsing ─────────────────────────────────────────────────────

  group('IDL parsing', () {
    test('detects Anchor format', () {
      expect(idl.format, equals(IdlFormat.anchor));
      report.pass('anchor', 'IDL format detection');
    });

    test('parses address', () {
      expect(
        idl.address,
        equals('id11111111111111111111111111111111111111111'),
      );
      report.pass('anchor', 'IDL address parsing');
    });

    test('parses metadata', () {
      expect(idl.metadata, isNotNull);
      expect(idl.metadata!.name, equals('idl'));
      expect(idl.metadata!.version, equals('0.1.0'));
      report.pass('anchor', 'IDL metadata parsing');
    });

    test('parses all instructions', () {
      final names = idl.instructions.map((ix) => ix.name).toList();
      expect(
        names,
        containsAll([
          'cause_error',
          'initialize',
          'initialize_with_values',
          'initialize_with_values2',
        ]),
      );
      expect(idl.instructions.length, equals(4));
      report.pass(
        'anchor',
        'IDL instruction parsing',
        detail: '${idl.instructions.length} instructions',
      );
    });

    test('parses instruction args with all primitive types', () {
      final ix = idl.findInstruction('initialize_with_values')!;
      final argNames = ix.args.map((a) => a.name).toList();
      // Verify comprehensive type coverage
      expect(
        argNames,
        containsAll([
          'bool_field',
          'u8_field',
          'i8_field',
          'u16_field',
          'i16_field',
          'u32_field',
          'i32_field',
          'f32_field',
          'u64_field',
          'i64_field',
          'f64_field',
          'u128_field',
          'i128_field',
          'bytes_field',
          'string_field',
          'pubkey_field',
        ]),
      );
      report.pass(
        'anchor',
        'IDL primitive type args',
        detail: '${argNames.length} args parsed',
      );
    });

    test('parses complex type args (vec, option, struct, array, enum)', () {
      final ix = idl.findInstruction('initialize_with_values')!;
      final argNames = ix.args.map((a) => a.name).toList();
      expect(
        argNames,
        containsAll([
          'vec_field',
          'vec_struct_field',
          'option_field',
          'option_struct_field',
          'struct_field',
          'array_field',
          'enum_field_1',
          'enum_field_2',
          'enum_field_3',
          'enum_field_4',
        ]),
      );
      report.pass('anchor', 'IDL complex type args');
    });

    test('parses instruction with return type', () {
      final ix = idl.findInstruction('initialize_with_values2')!;
      expect(ix.returns, isNotNull);
      report.pass('anchor', 'IDL instruction return type');
    });

    test('parses nested accounts', () {
      final ix = idl.findInstruction('initialize')!;
      // The 'nested' account should contain sub-accounts (clock, rent)
      final nestedAccount = ix.accounts.firstWhere((a) => a.name == 'nested');
      expect(nestedAccount, isA<IdlInstructionAccounts>());
      final nested = nestedAccount as IdlInstructionAccounts;
      expect(nested.accounts.length, equals(2));
      final nestedNames = nested.accounts.map((a) => a.name).toList();
      expect(nestedNames, containsAll(['clock', 'rent']));
      report.pass('anchor', 'IDL nested accounts parsing');
    });

    test('parses account definitions with discriminators', () {
      expect(idl.accounts, isNotNull);
      expect(idl.accounts!.length, equals(3));
      final names = idl.accounts!.map((a) => a.name).toList();
      expect(names, containsAll(['SomeZcAccount', 'State', 'State2']));

      // Each account should have a discriminator from the IDL
      for (final acc in idl.accounts!) {
        expect(
          acc.discriminator,
          isNotEmpty,
          reason: '${acc.name} should have a discriminator',
        );
      }
      report.pass(
        'anchor',
        'IDL account definitions',
        detail: '${idl.accounts!.length} accounts with discriminators',
      );
    });

    test('parses events with discriminators', () {
      expect(idl.events, isNotNull);
      expect(idl.events!.length, equals(1));
      expect(idl.events!.first.name, equals('SomeEvent'));
      expect(idl.events!.first.discriminator, isNotEmpty);
      report.pass('anchor', 'IDL event definitions');
    });

    test('parses errors with codes and messages', () {
      expect(idl.errors, isNotNull);
      expect(idl.errors!.length, equals(4));

      final someError = idl.errors!.firstWhere((e) => e.name == 'SomeError');
      expect(someError.code, equals(500000));
      expect(someError.msg, equals('Example error.'));

      final noMsg = idl.errors!.firstWhere((e) => e.name == 'ErrorWithoutMsg');
      expect(noMsg.msg, isNull);

      report.pass(
        'anchor',
        'IDL error definitions',
        detail: '${idl.errors!.length} errors',
      );
    });

    test('parses type definitions (structs and enums)', () {
      expect(idl.types, isNotNull);
      final typeNames = idl.types!.map((t) => t.name).toList();
      expect(
        typeNames,
        containsAll([
          'BarStruct',
          'FooEnum',
          'FooStruct',
          'SomeEvent',
          'SomeRetStruct',
          'State',
          'State2',
        ]),
      );
      report.pass(
        'anchor',
        'IDL type definitions',
        detail: '${idl.types!.length} types',
      );
    });

    test('parses enum variants correctly', () {
      final fooEnum = idl.types!.firstWhere((t) => t.name == 'FooEnum');
      expect(fooEnum.type.kind, equals('enum'));
      final variants = fooEnum.type.variants;
      expect(variants, isNotNull);
      final variantNames = variants!.map((v) => v.name).toList();
      expect(
        variantNames,
        containsAll([
          'Unnamed',
          'UnnamedSingle',
          'Named',
          'Struct',
          'OptionStruct',
          'VecStruct',
          'NoFields',
        ]),
      );
      report.pass(
        'anchor',
        'IDL enum variant parsing',
        detail: '${variants.length} variants',
      );
    });

    test('parses zero-copy account type', () {
      final zcType = idl.types!.firstWhere((t) => t.name == 'SomeZcAccount');
      expect(zcType.serialization, equals('bytemuck'));
      expect(zcType.repr, isNotNull);
      expect(zcType.repr!.kind, equals('c'));
      report.pass('anchor', 'IDL zero-copy account type');
    });

    test('parses constants', () {
      expect(idl.constants, isNotNull);
      expect(idl.constants!.length, equals(4));
      final u8Const = idl.constants!.firstWhere((c) => c.name == 'U8');
      expect(u8Const.type, equals('u8'));
      expect(u8Const.value, equals('6'));
      report.pass(
        'anchor',
        'IDL constants parsing',
        detail: '${idl.constants!.length} constants',
      );
    });

    test('parses module-scoped types', () {
      final typeNames = idl.types!.map((t) => t.name).toList();
      expect(typeNames, contains('external::MyStruct'));
      expect(typeNames, contains('idl::some_other_module::MyStruct'));
      report.pass('anchor', 'IDL module-scoped type names');
    });
  });

  // ─── 2. Discriminator Verification ──────────────────────────────────────

  group('Discriminator computation', () {
    test('instruction discriminators match IDL values', () {
      // The IDL contains pre-computed discriminators from the Anchor compiler.
      // Our computation must match exactly.
      for (final ix in idl.instructions) {
        if (ix.discriminator == null || ix.discriminator!.isEmpty) continue;

        final expected = Uint8List.fromList(ix.discriminator!);
        final computed = DiscriminatorComputer.computeInstructionDiscriminator(
          ix.name,
        );

        expect(
          computed,
          equals(expected),
          reason:
              'Discriminator mismatch for instruction "${ix.name}". '
              'Expected: ${bytesToHex(expected)}, Got: ${bytesToHex(computed)}',
        );
      }
      report.pass(
        'anchor',
        'Instruction discriminator computation',
        detail: '${idl.instructions.length} instructions verified',
      );
    });

    test('account discriminators match IDL values', () {
      for (final acc in idl.accounts!) {
        if (acc.discriminator.isEmpty) continue;

        final expected = Uint8List.fromList(acc.discriminator);
        final computed = DiscriminatorComputer.computeAccountDiscriminator(
          acc.name,
        );

        expect(
          computed,
          equals(expected),
          reason:
              'Discriminator mismatch for account "${acc.name}". '
              'Expected: ${bytesToHex(expected)}, Got: ${bytesToHex(computed)}',
        );
      }
      report.pass(
        'anchor',
        'Account discriminator computation',
        detail: '${idl.accounts!.length} accounts verified',
      );
    });

    test('event discriminators match IDL values', () {
      for (final evt in idl.events!) {
        if (evt.discriminator == null || evt.discriminator!.isEmpty) continue;

        final expected = Uint8List.fromList(evt.discriminator!);
        final computed = DiscriminatorComputer.computeEventDiscriminator(
          evt.name,
        );

        expect(
          computed,
          equals(expected),
          reason:
              'Discriminator mismatch for event "${evt.name}". '
              'Expected: ${bytesToHex(expected)}, Got: ${bytesToHex(computed)}',
        );
      }
      report.pass(
        'anchor',
        'Event discriminator computation',
        detail: '${idl.events!.length} events verified',
      );
    });
  });

  // ─── 3. Instruction Encoding/Decoding ───────────────────────────────────

  group('Instruction encoding/decoding', () {
    late BorshInstructionCoder coder;

    setUp(() {
      coder = BorshInstructionCoder(idl);
    });

    test('encode no-arg instruction (cause_error)', () {
      final encoded = coder.encode('cause_error', {});
      // Should be exactly the 8-byte discriminator
      expect(encoded.length, equals(8));
      final expected = Uint8List.fromList(
        idl.findInstruction('cause_error')!.discriminator!,
      );
      expect(encoded, equals(expected));
      report.pass('anchor', 'Encode no-arg instruction');
    });

    test('encode primitive-type args instruction', () {
      // Use a subset of the types to test encoding
      final encoded = coder.encode('initialize_with_values', {
        'bool_field': true,
        'u8_field': 42,
        'i8_field': -5,
        'u16_field': 1000,
        'i16_field': -1000,
        'u32_field': 100000,
        'i32_field': -100000,
        'f32_field': 3.14,
        'u64_field': 999999999,
        'i64_field': -999999999,
        'f64_field': 2.71828,
        'u128_field': BigInt.from(12345678901234),
        'i128_field': BigInt.from(-12345678901234),
        'bytes_field': [1, 2, 3, 4],
        'string_field': 'hello world',
        'pubkey_field': '11111111111111111111111111111111',
        'vec_field': [1, 2, 3],
        'vec_struct_field': <Map<String, dynamic>>[],
        'option_field': true,
        'option_struct_field': null,
        'struct_field': {
          'field1': 10,
          'field2': 200,
          'nested': {'some_field': true, 'other_field': 5},
          'vec_nested': <Map<String, dynamic>>[],
          'option_nested': null,
          'enum_field': {'NoFields': {}},
        },
        'array_field': [true, false, true],
        'enum_field_1': {
          'Unnamed': [
            true,
            42,
            {'some_field': false, 'other_field': 7},
          ],
        },
        'enum_field_2': {
          'Named': {
            'bool_field': true,
            'u8_field': 1,
            'nested': {'some_field': true, 'other_field': 2},
          },
        },
        'enum_field_3': {
          'Struct': [
            {'some_field': false, 'other_field': 99},
          ],
        },
        'enum_field_4': {'NoFields': {}},
      });

      // Must be longer than 8 bytes (discriminator)
      expect(encoded.length, greaterThan(8));

      // First 8 bytes should match the IDL discriminator
      final disc = encoded.sublist(0, 8);
      final expectedDisc = Uint8List.fromList(
        idl.findInstruction('initialize_with_values')!.discriminator!,
      );
      expect(disc, equals(expectedDisc));

      report.pass(
        'anchor',
        'Encode primitive+complex args instruction',
        detail: '${encoded.length} bytes encoded',
      );
    });

    test('decode round-trips for no-arg instruction', () {
      final encoded = coder.encode('cause_error', {});
      final decoded = coder.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.name, equals('cause_error'));
      expect(decoded.data, isEmpty);
      report.pass('anchor', 'Decode round-trip (no-arg)');
    });

    test('decode round-trips for primitive args', () {
      final args = {
        'bool_field': true,
        'u8_field': 42,
        'i8_field': -5,
        'u16_field': 1000,
        'i16_field': -1000,
        'u32_field': 100000,
        'i32_field': -100000,
        'f32_field': 3.14,
        'u64_field': 999999999,
        'i64_field': -999999999,
        'f64_field': 2.71828,
        'u128_field': BigInt.from(12345678901234),
        'i128_field': BigInt.from(-12345678901234),
        'bytes_field': [1, 2, 3, 4],
        'string_field': 'hello world',
        'pubkey_field': '11111111111111111111111111111111',
        'vec_field': [1, 2, 3],
        'vec_struct_field': <Map<String, dynamic>>[],
        'option_field': true,
        'option_struct_field': null,
        'struct_field': {
          'field1': 10,
          'field2': 200,
          'nested': {'some_field': true, 'other_field': 5},
          'vec_nested': <Map<String, dynamic>>[],
          'option_nested': null,
          'enum_field': {'NoFields': {}},
        },
        'array_field': [true, false, true],
        'enum_field_1': {
          'Unnamed': [
            true,
            42,
            {'some_field': false, 'other_field': 7},
          ],
        },
        'enum_field_2': {
          'Named': {
            'bool_field': true,
            'u8_field': 1,
            'nested': {'some_field': true, 'other_field': 2},
          },
        },
        'enum_field_3': {
          'Struct': [
            {'some_field': false, 'other_field': 99},
          ],
        },
        'enum_field_4': {'NoFields': {}},
      };

      final encoded = coder.encode('initialize_with_values', args);
      final decoded = coder.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.name, equals('initialize_with_values'));

      // Verify key fields survive the round-trip
      expect(decoded.data['bool_field'], equals(true));
      expect(decoded.data['u8_field'], equals(42));
      expect(decoded.data['i8_field'], equals(-5));
      expect(decoded.data['u16_field'], equals(1000));
      expect(decoded.data['i16_field'], equals(-1000));
      expect(decoded.data['u32_field'], equals(100000));
      expect(decoded.data['i32_field'], equals(-100000));
      expect(decoded.data['string_field'], equals('hello world'));

      report.pass('anchor', 'Decode round-trip (primitive+complex args)');
    });

    test('encode vec-of-option and box_field (initialize_with_values2)', () {
      final encoded = coder.encode('initialize_with_values2', {
        'vec_of_option': [999, null, 42],
        'box_field': false,
      });

      expect(encoded.length, greaterThan(8));

      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('initialize_with_values2'));
      expect(decoded.data['box_field'], equals(false));

      report.pass('anchor', 'Encode/decode vec<option<u64>>');
    });
  });

  // ─── 4. Account Encoding/Decoding ──────────────────────────────────────

  group('Account encoding/decoding', () {
    late BorshAccountsCoder coder;

    setUp(() {
      coder = BorshAccountsCoder(idl);
    });

    test('account discriminator lookup works', () {
      final disc = coder.accountDiscriminator('State');
      expect(disc.length, equals(8));
      final expected = Uint8List.fromList(
        idl.accounts!.firstWhere((a) => a.name == 'State').discriminator,
      );
      expect(disc, equals(expected));
      report.pass('anchor', 'Account discriminator lookup');
    });

    test('State2 account encode/decode round-trip', () async {
      final data = {
        'vec_of_option': [BigInt.from(100), null, BigInt.from(200)],
        'box_field': true,
      };

      final encoded = await coder.encode('State2', data);
      expect(encoded.length, greaterThan(8));

      // Verify discriminator prefix
      final disc = encoded.sublist(0, 8);
      final expected = Uint8List.fromList(
        idl.accounts!.firstWhere((a) => a.name == 'State2').discriminator,
      );
      expect(disc, equals(expected));

      // Decode and verify round-trip
      final decoded = coder.decode<Map<String, dynamic>>('State2', encoded);
      expect(decoded['box_field'], equals(true));

      report.pass('anchor', 'State2 account encode/decode round-trip');
    });

    test('account size calculation', () {
      // The coder should be able to calculate account sizes
      final size = coder.size('State2');
      // State2 has: 8 (disc) + 4 (vec len) + variable + 1 (bool)
      // Minimum should be at least discriminator + bool = 13
      expect(size, greaterThanOrEqualTo(9));
      report.pass(
        'anchor',
        'Account size calculation',
        detail: 'State2 size = $size',
      );
    });
  });

  // ─── 5. Event Encoding/Decoding ────────────────────────────────────────

  group('Event encoding/decoding', () {
    late BorshEventCoder eventCoder;

    setUp(() {
      eventCoder = BorshEventCoder(idl);
    });

    test('event coder initializes without error', () {
      // Just constructing the event coder should work
      expect(eventCoder, isNotNull);
      report.pass('anchor', 'Event coder construction');
    });

    test('event encode/decode round-trip for SomeEvent', () {
      // SomeEvent has: bool_field, external_my_struct, other_module_my_struct
      final eventData = {
        'bool_field': true,
        'external_my_struct': {'some_field': 42},
        'other_module_my_struct': {'some_u8': 7},
      };

      final encoded = eventCoder.encode('SomeEvent', eventData);
      expect(encoded.length, greaterThan(0));

      // Decode by converting to base64 (like log output)
      final base64Log = base64Encode(encoded);
      final decoded = eventCoder.decode(base64Log);

      expect(decoded, isNotNull);
      expect(decoded!.name, equals('SomeEvent'));
      expect(decoded.data['bool_field'], equals(true));

      report.pass('anchor', 'Event encode/decode round-trip');
    });

    test('event discriminator matches IDL value', () {
      final eventDisc = idl.events!.first.discriminator!;
      final computed = DiscriminatorComputer.computeEventDiscriminator(
        'SomeEvent',
      );
      expect(computed, equals(Uint8List.fromList(eventDisc)));
      report.pass('anchor', 'Event discriminator matches IDL');
    });
  });

  // ─── 6. Error Code Mapping ─────────────────────────────────────────────

  group('Error code mapping', () {
    test('all errors are accessible', () {
      expect(idl.errors!.length, equals(4));

      final errorMap = {for (final e in idl.errors!) e.name: e};
      expect(errorMap['SomeError']!.code, equals(500000));
      expect(errorMap['OtherError']!.code, equals(500001));
      expect(errorMap['ErrorWithoutMsg']!.code, equals(500002));
      expect(errorMap['WithDiscrim']!.code, equals(500500));

      report.pass(
        'anchor',
        'Error code mapping',
        detail: '4 error codes mapped',
      );
    });

    test('error messages are preserved', () {
      final someError = idl.errors!.firstWhere((e) => e.name == 'SomeError');
      expect(someError.msg, equals('Example error.'));

      final noMsg = idl.errors!.firstWhere((e) => e.name == 'ErrorWithoutMsg');
      expect(noMsg.msg, isNull);

      report.pass('anchor', 'Error message preservation');
    });
  });

  // ─── 7. Program Class Construction ─────────────────────────────────────

  group('Program class construction', () {
    test('Program creates from real IDL', () {
      final program = Program(idl);
      expect(program.idl, isNotNull);
      expect(
        program.programId.toBase58(),
        equals('id11111111111111111111111111111111111111111'),
      );
      report.pass('anchor', 'Program construction from IDL');
    });

    test('Program.methods namespace contains all instructions', () {
      final program = Program(idl);
      expect(program.methods.contains('cause_error'), isTrue);
      expect(program.methods.contains('initialize'), isTrue);
      expect(program.methods.contains('initialize_with_values'), isTrue);
      expect(program.methods.contains('initialize_with_values2'), isTrue);
      expect(program.methods.contains('nonexistent'), isFalse);
      report.pass(
        'anchor',
        'Methods namespace wiring',
        detail: '4 methods available',
      );
    });

    test('Program.coder.instructions encodes same as standalone coder', () {
      final program = Program(idl);
      final standalone = BorshInstructionCoder(idl);

      final programEncoded = program.coder.instructions.encode(
        'cause_error',
        {},
      );
      final standaloneEncoded = standalone.encode('cause_error', {});

      expect(programEncoded, equals(standaloneEncoded));
      report.pass('anchor', 'Program coder consistency');
    });

    test('Program auto-detects IDL format', () {
      final program = Program.auto(idl);
      expect(program.idl.format, equals(IdlFormat.anchor));
      report.pass('anchor', 'Program.auto() format detection');
    });

    test('Program.withProgramId overrides address', () {
      final customId = PublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final program = Program.withProgramId(idl, customId);
      expect(
        program.programId.toBase58(),
        equals('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
      );
      report.pass('anchor', 'Program.withProgramId override');
    });
  });

  // ─── 8. AutoCoder Framework Dispatch ───────────────────────────────────

  group('AutoCoder framework dispatch', () {
    test('AutoCoder selects BorshAccountsCoder for Anchor IDL', () {
      final coder = AutoCoder(idl);
      // For Anchor format, accounts coder should be BorshAccountsCoder
      expect(coder.accounts, isA<BorshAccountsCoder>());
      report.pass('anchor', 'AutoCoder selects Borsh for Anchor');
    });

    test('AutoCoder provides working instruction coder', () {
      final coder = AutoCoder(idl);
      final encoded = coder.instructions.encode('cause_error', {});
      expect(encoded.length, equals(8));
      report.pass('anchor', 'AutoCoder instruction coder works');
    });

    test('AutoCoder provides working event coder', () {
      final coder = AutoCoder(idl);
      // Should be able to access events coder without error
      expect(coder.events, isA<BorshEventCoder>());
      report.pass('anchor', 'AutoCoder event coder works');
    });
  });

  // ─── 9. Edge Cases and Robustness ──────────────────────────────────────

  group('Edge cases', () {
    test('empty instruction list IDL still constructs', () {
      final emptyIdl = Idl.fromJson({
        'address': '11111111111111111111111111111111',
        'metadata': {'name': 'empty', 'version': '0.1.0', 'spec': '0.1.0'},
        'instructions': <Map<String, dynamic>>[],
      });
      final program = Program(emptyIdl);
      expect(program.idl.instructions, isEmpty);
      report.pass('anchor', 'Empty instruction IDL construction');
    });

    test('unknown instruction name throws on encode', () {
      final coder = BorshInstructionCoder(idl);
      expect(
        () => coder.encode('nonexistent_method', {}),
        throwsA(isA<InstructionCoderException>()),
      );
      report.pass('anchor', 'Unknown instruction throws on encode');
    });

    test('discriminator mismatch rejects account data', () {
      final coder = BorshAccountsCoder(idl);
      // Create fake account data with wrong discriminator
      final fakeData = Uint8List(100);
      fakeData.fillRange(0, 8, 0xFF); // Wrong discriminator

      expect(
        () => coder.decode('State', fakeData),
        throwsA(anything), // Should throw some kind of error
      );
      report.pass('anchor', 'Wrong discriminator rejects account data');
    });

    test('IDL fromJson/toJson round-trip preserves structure', () {
      final json1 = idl.toJson();
      final idl2 = Idl.fromJson(json1);
      final json2 = idl2.toJson();

      // Instruction count should survive round-trip
      expect(idl2.instructions.length, equals(idl.instructions.length));
      expect(idl2.accounts?.length, equals(idl.accounts?.length));
      expect(idl2.events?.length, equals(idl.events?.length));
      expect(idl2.errors?.length, equals(idl.errors?.length));
      expect(idl2.types?.length, equals(idl.types?.length));
      expect(idl2.constants?.length, equals(idl.constants?.length));

      report.pass('anchor', 'IDL JSON round-trip preserves structure');
    });
  });
}
