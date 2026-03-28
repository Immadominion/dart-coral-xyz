/// T1.1 — IDL Parsing Component Tests
///
/// Tests Idl.fromJson() against real Anchor IDL files to verify:
/// - Modern format (spec 0.1.0) parsing with all field types
/// - Old format (v0.x) backward compatibility
/// - Format auto-detection (Anchor vs Quasar vs Codama)
/// - Type system: primitives, vec, option, array, defined, enum, struct
/// - Accounts, events, errors, constants, metadata, docs
/// - Round-trip: fromJson → toJson → fromJson
@TestOn('vm')
library;

import 'dart:convert';

import 'package:coral_xyz/src/idl/idl.dart';
import 'package:test/test.dart';

import '../fixtures/idl_fixtures.dart';

void main() {
  group('Idl.fromJson — modern format (spec 0.1.0)', () {
    late Idl idl;

    setUpAll(() {
      idl = Idl.fromJson(IdlFixtures.anchorFull);
    });

    test('parses top-level fields', () {
      expect(idl.address, 'id11111111111111111111111111111111111111111');
      expect(idl.format, IdlFormat.anchor);
      expect(idl.docs, ['IDL test program documentation.']);
    });

    test('parses metadata', () {
      final meta = idl.metadata!;
      expect(meta.name, 'idl');
      expect(meta.version, '0.1.0');
      expect(meta.spec, '0.1.0');
      expect(meta.description, 'Created with Anchor');
    });

    test('parses instructions with discriminators', () {
      expect(
        idl.instructions.length,
        4,
      ); // cause_error, initialize, initialize_with_values, initialize_with_values2

      final causeError = idl.findInstruction('cause_error')!;
      expect(causeError.discriminator, [67, 104, 37, 17, 2, 155, 68, 17]);
      expect(causeError.args, isEmpty);
      expect(causeError.accounts, isEmpty);

      final initValues = idl.findInstruction('initialize_with_values')!;
      expect(initValues.discriminator, [220, 73, 8, 213, 178, 69, 181, 141]);
      expect(initValues.docs, isNotEmpty);
      expect(
        initValues.docs!.first,
        'Initializes an account with specified values',
      );
    });

    test('parses instruction arguments with all primitive types', () {
      final ix = idl.findInstruction('initialize_with_values')!;
      final argNames = ix.args.map((a) => a.name).toList();
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

      // Verify type kinds
      final typeMap = {for (final a in ix.args) a.name: a.type.kind};
      expect(typeMap['bool_field'], 'bool');
      expect(typeMap['u8_field'], 'u8');
      expect(typeMap['i8_field'], 'i8');
      expect(typeMap['u64_field'], 'u64');
      expect(typeMap['string_field'], 'string');
      expect(typeMap['pubkey_field'], 'pubkey');
      expect(typeMap['bytes_field'], 'bytes');
    });

    test('parses complex types: vec, option, array, defined', () {
      final ix = idl.findInstruction('initialize_with_values')!;
      final argMap = {for (final a in ix.args) a.name: a.type};

      // vec<u64>
      final vecField = argMap['vec_field']!;
      expect(vecField.kind, 'vec');
      expect(vecField.inner!.kind, 'u64');

      // vec<defined(FooStruct)>
      final vecStruct = argMap['vec_struct_field']!;
      expect(vecStruct.kind, 'vec');
      expect(vecStruct.inner!.kind, 'defined');
      expect(vecStruct.inner!.defined!.name, 'FooStruct');

      // option<bool>
      final optField = argMap['option_field']!;
      expect(optField.kind, 'option');
      expect(optField.inner!.kind, 'bool');

      // defined(FooStruct)
      final structField = argMap['struct_field']!;
      expect(structField.kind, 'defined');
      expect(structField.defined!.name, 'FooStruct');

      // array<bool, 3>
      final arrayField = argMap['array_field']!;
      expect(arrayField.kind, 'array');
      expect(arrayField.inner!.kind, 'bool');
      expect(arrayField.size, 3);

      // defined(FooEnum)
      final enumField = argMap['enum_field_1']!;
      expect(enumField.kind, 'defined');
      expect(enumField.defined!.name, 'FooEnum');
    });

    test('parses nested/composite accounts', () {
      final ix = idl.findInstruction('initialize')!;
      // Has nested accounts group
      final nestedGroup = ix.accounts.firstWhere((a) => a.name == 'nested');
      expect(nestedGroup, isA<IdlInstructionAccounts>());
      final group = nestedGroup as IdlInstructionAccounts;
      expect(group.accounts.length, 2);

      final clock =
          group.accounts.firstWhere((a) => a.name == 'clock')
              as IdlInstructionAccount;
      expect(clock.address, 'SysvarC1ock11111111111111111111111111111111');
      expect(clock.docs, ['Sysvar clock']);
    });

    test('parses account definitions with discriminators', () {
      expect(idl.accounts!.length, 3); // SomeZcAccount, State, State2

      final state = idl.findAccount('State')!;
      expect(state.discriminator, [216, 146, 107, 94, 104, 75, 182, 177]);

      final state2 = idl.findAccount('State2')!;
      expect(state2.discriminator, [106, 97, 255, 161, 250, 205, 185, 192]);
    });

    test('parses event definitions with discriminators', () {
      expect(idl.events!.length, 1);
      final event = idl.events!.first;
      expect(event.name, 'SomeEvent');
      expect(event.discriminator, [39, 221, 150, 148, 91, 206, 29, 93]);
    });

    test('parses error definitions', () {
      expect(idl.errors!.length, 4);
      final someError = idl.errors!.firstWhere((e) => e.name == 'SomeError');
      expect(someError.code, 500000);
      expect(someError.msg, 'Example error.');

      final noMsg = idl.errors!.firstWhere((e) => e.name == 'ErrorWithoutMsg');
      expect(noMsg.code, 500002);
      expect(noMsg.msg, isNull);
    });

    test('parses constants', () {
      expect(idl.constants!.length, 4);
      final bytesStr = idl.constants!.firstWhere((c) => c.name == 'BYTES_STR');
      expect(bytesStr.type, 'bytes');
      expect(bytesStr.value, '[116, 101, 115, 116]');

      final u8Const = idl.constants!.firstWhere((c) => c.name == 'U8');
      expect(u8Const.type, 'u8');
      expect(u8Const.value, '6');
    });

    test('parses type definitions — struct', () {
      final fooStruct = idl.findType('FooStruct')!;
      expect(fooStruct.type.kind, 'struct');
      expect(fooStruct.type.fields!.length, 6);

      final fieldNames = fooStruct.type.fields!.map((f) => f.name).toList();
      expect(fieldNames, [
        'field1',
        'field2',
        'nested',
        'vec_nested',
        'option_nested',
        'enum_field',
      ]);
    });

    test('parses type definitions — enum with all variant kinds', () {
      final fooEnum = idl.findType('FooEnum')!;
      expect(fooEnum.type.kind, 'enum');
      expect(fooEnum.type.variants!.length, 7);

      final variantNames = fooEnum.type.variants!.map((v) => v.name).toList();
      expect(variantNames, [
        'Unnamed',
        'UnnamedSingle',
        'Named',
        'Struct',
        'OptionStruct',
        'VecStruct',
        'NoFields',
      ]);

      // Named variant has named fields
      final named = fooEnum.type.variants!.firstWhere((v) => v.name == 'Named');
      expect(named.fields, isNotEmpty);
      expect(named.fields!.first.name, 'bool_field');

      // Unnamed variant has tuple fields (not named fields)
      final unnamed = fooEnum.type.variants!.firstWhere(
        (v) => v.name == 'Unnamed',
      );
      expect(unnamed.fields, isNull);
      expect(unnamed.tupleFields, isNotEmpty);
      expect(unnamed.tupleFields!.length, 3);
      expect(unnamed.tupleFields!.first.kind, 'bool');

      // NoFields variant
      final noFields = fooEnum.type.variants!.firstWhere(
        (v) => v.name == 'NoFields',
      );
      expect(noFields.fields, isNull);
      expect(noFields.tupleFields, isNull);
    });

    test('parses zero-copy account type with serialization and repr', () {
      final zcAccount = idl.findType('SomeZcAccount')!;
      expect(zcAccount.serialization, 'bytemuck');
      expect(zcAccount.repr!.kind, 'c');
    });

    test('parses return type on instruction', () {
      final ix = idl.findInstruction('initialize_with_values2')!;
      // The returns field is present — it's a defined type name
      expect(ix.returns, isNotNull);
    });

    test('findInstruction returns null for unknown name', () {
      expect(idl.findInstruction('nonexistent'), isNull);
    });

    test('findAccount returns null for unknown name', () {
      expect(idl.findAccount('nonexistent'), isNull);
    });

    test('findType returns null for unknown name', () {
      expect(idl.findType('nonexistent'), isNull);
    });
  });

  group('Idl.fromJson — old format (v0.x)', () {
    late Idl idl;

    setUpAll(() {
      idl = Idl.fromJson(IdlFixtures.oldFormatCounter);
    });

    test('parses name and version from top-level', () {
      expect(idl.name, 'basic_counter');
      expect(idl.version, '0.1.0');
      expect(idl.address, isNull);
      expect(idl.metadata, isNull);
    });

    test('detects anchor format', () {
      expect(idl.format, IdlFormat.anchor);
    });

    test('parses instructions without discriminators', () {
      expect(idl.instructions.length, 2);

      final init = idl.findInstruction('initialize')!;
      expect(init.discriminator, isNull);
      expect(init.args, isEmpty);
      expect(init.accounts.length, 3);

      final incr = idl.findInstruction('increment')!;
      expect(incr.args.length, 1);
      expect(incr.args.first.name, 'amount');
      expect(incr.args.first.type.kind, 'u64');
    });

    test('parses old-style isMut/isSigner account flags', () {
      final init = idl.findInstruction('initialize')!;
      final counter =
          init.accounts.firstWhere((a) => a.name == 'counter')
              as IdlInstructionAccount;
      expect(counter.writable, isTrue);
      expect(counter.signer, isFalse);

      final payer =
          init.accounts.firstWhere((a) => a.name == 'payer')
              as IdlInstructionAccount;
      expect(payer.writable, isTrue);
      expect(payer.signer, isTrue);
    });

    test('parses errors from old format', () {
      expect(idl.errors!.length, 2);
      expect(idl.errors!.first.code, 6000);
      expect(idl.errors!.first.name, 'CannotGetBump');
      expect(idl.errors!.first.msg, 'Cannot get the bump.');
    });
  });

  group('Idl.fromJson — minimal', () {
    test('parses minimal valid IDL', () {
      final idl = Idl.fromJson(IdlFixtures.minimal);
      expect(idl.address, 'Min11111111111111111111111111111111111111111');
      expect(idl.metadata!.name, 'minimal');
      expect(idl.instructions.length, 1);
      expect(idl.accounts, isNull);
      expect(idl.events, isNull);
      expect(idl.errors, isNull);
      expect(idl.types, isNull);
      expect(idl.constants, isNull);
    });
  });

  group('IdlFormat.detect', () {
    test('detects anchor format for standard IDL', () {
      expect(IdlFormat.detect(IdlFixtures.anchorFull), IdlFormat.anchor);
    });

    test('detects codama format by standard field', () {
      expect(
        IdlFormat.detect({'standard': 'codama', 'instructions': []}),
        IdlFormat.codama,
      );
    });

    test('detects codama format by rootNode kind', () {
      expect(
        IdlFormat.detect({'kind': 'rootNode', 'instructions': []}),
        IdlFormat.codama,
      );
    });

    test('detects quasar format by short discriminator', () {
      final json = {
        'instructions': [
          {
            'name': 'init',
            'discriminator': [0],
            'args': [],
            'accounts': [],
          },
        ],
      };
      expect(IdlFormat.detect(json), IdlFormat.quasar);
    });

    test('detects quasar format by hasRemaining', () {
      final json = {
        'instructions': [
          {
            'name': 'init',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'hasRemaining': true,
            'args': [],
            'accounts': [],
          },
        ],
      };
      expect(IdlFormat.detect(json), IdlFormat.quasar);
    });

    test('detects quasar format by bounded string type', () {
      final json = {
        'instructions': [
          {
            'name': 'init',
            'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
            'args': [
              {
                'name': 'name',
                'type': {
                  'string': {'maxLength': 32},
                },
              },
            ],
            'accounts': [],
          },
        ],
      };
      expect(IdlFormat.detect(json), IdlFormat.quasar);
    });

    test('detects quasar format by tail type in types section', () {
      final json = {
        'instructions': [],
        'types': [
          {
            'name': 'MyStruct',
            'type': {
              'kind': 'struct',
              'fields': [
                {
                  'name': 'data',
                  'type': {
                    'tail': {'element': 'u8'},
                  },
                },
              ],
            },
          },
        ],
      };
      expect(IdlFormat.detect(json), IdlFormat.quasar);
    });

    test('returns anchor for empty instructions list', () {
      expect(IdlFormat.detect({'instructions': []}), IdlFormat.anchor);
    });
  });

  group('Idl round-trip (fromJson → toJson → fromJson)', () {
    test('round-trips modern IDL preserving structure', () {
      final original = Idl.fromJson(IdlFixtures.anchorFull);
      final json = original.toJson();
      final roundTripped = Idl.fromJson(json);

      expect(roundTripped.address, original.address);
      expect(roundTripped.instructions.length, original.instructions.length);
      expect(roundTripped.accounts?.length, original.accounts?.length);
      expect(roundTripped.events?.length, original.events?.length);
      expect(roundTripped.errors?.length, original.errors?.length);
      expect(roundTripped.types?.length, original.types?.length);
      expect(roundTripped.constants?.length, original.constants?.length);

      // Verify instruction discriminators survive round-trip
      for (int i = 0; i < original.instructions.length; i++) {
        expect(
          roundTripped.instructions[i].discriminator,
          original.instructions[i].discriminator,
          reason:
              'Discriminator mismatch on instruction ${original.instructions[i].name}',
        );
      }

      // Verify account discriminators survive round-trip
      for (int i = 0; i < (original.accounts?.length ?? 0); i++) {
        expect(
          roundTripped.accounts![i].discriminator,
          original.accounts![i].discriminator,
          reason:
              'Discriminator mismatch on account ${original.accounts![i].name}',
        );
      }
    });

    test('round-trips minimal IDL', () {
      final original = Idl.fromJson(IdlFixtures.minimal);
      final json = original.toJson();
      final roundTripped = Idl.fromJson(json);

      expect(roundTripped.address, original.address);
      expect(roundTripped.instructions.length, 1);
      expect(roundTripped.instructions.first.name, 'initialize');
    });
  });

  group('IdlType.fromJson edge cases', () {
    test('parses simple string types', () {
      expect(IdlType.fromJson('u8').kind, 'u8');
      expect(IdlType.fromJson('bool').kind, 'bool');
      expect(IdlType.fromJson('string').kind, 'string');
      expect(IdlType.fromJson('pubkey').kind, 'pubkey');
      expect(IdlType.fromJson('bytes').kind, 'bytes');
    });

    test('parses vec type', () {
      final t = IdlType.fromJson({'vec': 'u64'});
      expect(t.kind, 'vec');
      expect(t.inner!.kind, 'u64');
    });

    test('parses option type', () {
      final t = IdlType.fromJson({'option': 'bool'});
      expect(t.kind, 'option');
      expect(t.inner!.kind, 'bool');
    });

    test('parses array type', () {
      final t = IdlType.fromJson({
        'array': ['u8', 32],
      });
      expect(t.kind, 'array');
      expect(t.inner!.kind, 'u8');
      expect(t.size, 32);
    });

    test('parses defined type (string name)', () {
      final t = IdlType.fromJson({'defined': 'MyStruct'});
      expect(t.kind, 'defined');
      expect(t.defined!.name, 'MyStruct');
    });

    test('parses defined type (object with name)', () {
      final t = IdlType.fromJson({
        'defined': {'name': 'FooStruct'},
      });
      expect(t.kind, 'defined');
      expect(t.defined!.name, 'FooStruct');
    });

    test('parses nested vec<option<u64>>', () {
      final t = IdlType.fromJson({
        'vec': {'option': 'u64'},
      });
      expect(t.kind, 'vec');
      expect(t.inner!.kind, 'option');
      expect(t.inner!.inner!.kind, 'u64');
    });

    test('throws on invalid type format', () {
      expect(() => IdlType.fromJson(42), throwsArgumentError);
    });
  });

  group('IdlType.toJson round-trip', () {
    test('round-trips primitive types', () {
      for (final kind in ['u8', 'bool', 'string', 'pubkey', 'bytes']) {
        expect(IdlType.fromJson(IdlType.fromJson(kind).toJson()).kind, kind);
      }
    });

    test('round-trips vec type', () {
      final original = IdlType.fromJson({'vec': 'u64'});
      final restored = IdlType.fromJson(original.toJson());
      expect(restored.kind, 'vec');
      expect(restored.inner!.kind, 'u64');
    });

    test('round-trips option type', () {
      final original = IdlType.fromJson({'option': 'bool'});
      final restored = IdlType.fromJson(original.toJson());
      expect(restored.kind, 'option');
      expect(restored.inner!.kind, 'bool');
    });

    test('round-trips array type', () {
      final original = IdlType.fromJson({
        'array': ['u8', 32],
      });
      final restored = IdlType.fromJson(original.toJson());
      expect(restored.kind, 'array');
      expect(restored.inner!.kind, 'u8');
      expect(restored.size, 32);
    });
  });
}
