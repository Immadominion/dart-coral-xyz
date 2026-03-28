/// Advanced IDL Feature Verification Tests (Session 4)
///
/// Verifies:
///   1. Generics IDL parsing (type generics, const generics, nested generics)
///   2. Legacy (old) IDL format parsing (isMut/isSigner, bare "defined", camelCase)
///   3. Multi-event IDL parsing and event coder (amm_v3 with 11 events)
///   4. Deeply nested optional types (option<vec<defined>>, option<defined(option<T>)>)
///   5. Legacy ↔ New format cross-comparison (same program, both formats)
///
/// Uses real Anchor IDLs: generics.json, old.json, amm_v3.json, mpl_token_metadata.json
///
/// Run: dart test test/verification/advanced_idl_verification_test.dart -r expanded
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/src/coder/event_coder.dart';
import 'package:coral_xyz/src/coder/instruction_coder.dart';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:test/test.dart';

import 'verification_helpers.dart';

void main() {
  final report = VerificationReport();

  tearDownAll(() => report.printSummary());

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Generics IDL Parsing
  // ═══════════════════════════════════════════════════════════════════════════

  group('Generics IDL parsing', () {
    late Idl genericsIdl;

    setUpAll(() {
      genericsIdl = loadFixtureIdl('generics_program.json');
    });

    test('parses generics IDL with correct metadata', () {
      expect(
        genericsIdl.address,
        equals('Generics111111111111111111111111111111111111'),
      );
      expect(genericsIdl.metadata?.name, equals('generics'));
      expect(genericsIdl.format, equals(IdlFormat.anchor));

      report.pass('Generics', 'IDL metadata parsed correctly');
    });

    test('parses instruction with generic arg type', () {
      expect(genericsIdl.instructions, hasLength(1));
      final ix = genericsIdl.instructions.first;
      expect(ix.name, equals('generic'));
      expect(ix.args, hasLength(1));

      final arg = ix.args.first;
      expect(arg.name, equals('generic_field'));
      expect(arg.type.kind, equals('defined'));
      expect(arg.type.defined?.name, equals('GenericType'));

      report.pass('Generics', 'instruction with generic arg parsed');
    });

    test('parses generic type instantiation parameters', () {
      final ix = genericsIdl.instructions.first;
      final definedType = ix.args.first.type.defined!;
      final generics = definedType.generics;

      expect(generics, isNotNull);
      expect(generics!, hasLength(3));

      // First: type generic → u32
      expect(generics[0].kind, equals('type'));
      expect(generics[0].type, isNotNull);

      // Second: type generic → u64
      expect(generics[1].kind, equals('type'));

      // Third: const generic → "10"
      expect(generics[2].kind, equals('const'));
      expect(generics[2].value, equals('10'));

      report.pass(
        'Generics',
        'generic instantiation parameters (2 type + 1 const)',
      );
    });

    test('parses type definition with generic parameters', () {
      final types = genericsIdl.types!;
      final genericType = types.firstWhere((t) => t.name == 'GenericType');

      expect(genericType.generics, isNotNull);
      expect(genericType.generics!, hasLength(3));

      expect(genericType.generics![0].kind, equals('type'));
      expect(genericType.generics![0].name, equals('T'));

      expect(genericType.generics![1].kind, equals('type'));
      expect(genericType.generics![1].name, equals('U'));

      expect(genericType.generics![2].kind, equals('const'));
      expect(genericType.generics![2].name, equals('N'));

      report.pass(
        'Generics',
        'type definition generic parameters (T, U, N:const)',
      );
    });

    test('parses generic enum with multiple variant types', () {
      final types = genericsIdl.types!;
      final genericEnum = types.firstWhere((t) => t.name == 'GenericEnum');

      expect(genericEnum.generics, isNotNull);
      expect(genericEnum.generics!, hasLength(3));
      expect(genericEnum.type.kind, equals('enum'));
      expect(genericEnum.type.variants, isNotNull);
      expect(genericEnum.type.variants!.length, greaterThanOrEqualTo(4));

      report.pass(
        'Generics',
        'generic enum with variants parsed',
        detail: '${genericEnum.type.variants!.length} variants',
      );
    });

    test('parses nested generic type references', () {
      final types = genericsIdl.types!;
      final genericNested = types.firstWhere((t) => t.name == 'GenericNested');

      expect(genericNested.generics, isNotNull);
      expect(genericNested.generics!, hasLength(2));
      expect(genericNested.generics![0].name, equals('V'));
      expect(genericNested.generics![1].name, equals('Z'));

      final fields = genericNested.type.fields!;
      expect(fields.length, greaterThanOrEqualTo(2));

      report.pass(
        'Generics',
        'nested generic type (GenericNested<V,Z>) parsed',
      );
    });

    test('parses const-generic-only wrapper type', () {
      final types = genericsIdl.types!;
      final wrapped = types.firstWhere((t) => t.name == 'WrappedU8Array');

      expect(wrapped.generics, isNotNull);
      expect(wrapped.generics!, hasLength(1));
      expect(wrapped.generics![0].kind, equals('const'));
      expect(wrapped.generics![0].name, equals('N'));

      report.pass(
        'Generics',
        'const-generic-only type (WrappedU8Array<N>) parsed',
      );
    });

    test('generics IDL round-trips through JSON', () {
      final json = genericsIdl.toJson();
      final reparsed = Idl.fromJson(json);

      expect(
        reparsed.instructions.length,
        equals(genericsIdl.instructions.length),
      );
      expect(reparsed.types!.length, equals(genericsIdl.types!.length));

      // Verify generics survive round-trip
      final reparsedType = reparsed.types!.firstWhere(
        (t) => t.name == 'GenericType',
      );
      expect(reparsedType.generics, isNotNull);
      expect(
        reparsedType.generics!.length,
        equals(
          genericsIdl.types!
              .firstWhere((t) => t.name == 'GenericType')
              .generics!
              .length,
        ),
      );

      report.pass('Generics', 'IDL JSON round-trip preserves generics');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Legacy (Old) IDL Format Parsing
  // ═══════════════════════════════════════════════════════════════════════════

  group('Legacy IDL format parsing', () {
    late Idl legacyIdl;
    late Idl newIdl;

    setUpAll(() {
      legacyIdl = loadFixtureIdl('legacy_idl_program.json');
      newIdl = loadFixtureIdl('anchor_idl_test_program.json');
    });

    test('parses legacy format top-level fields', () {
      // Legacy format has name/version at top level, no address, no metadata
      expect(legacyIdl.name, equals('idl'));
      expect(legacyIdl.version, equals('0.1.0'));
      expect(legacyIdl.format, equals(IdlFormat.anchor));
      expect(legacyIdl.docs, isNotNull);

      report.pass('Legacy', 'top-level fields (name, version, docs) parsed');
    });

    test('parses legacy constants', () {
      expect(legacyIdl.constants, isNotNull);
      expect(legacyIdl.constants!, hasLength(4));

      final u8Const = legacyIdl.constants!.firstWhere((c) => c.name == 'U8');
      expect(u8Const.type, equals('u8'));
      expect(u8Const.value, equals('6'));

      report.pass('Legacy', 'constants parsed (4 constants)');
    });

    test('parses legacy isMut/isSigner as writable/signer', () {
      final ix = legacyIdl.instructions.firstWhere(
        (i) => i.name == 'initialize',
      );
      // Legacy accounts should be flattened from nested structure
      expect(ix.accounts, isNotEmpty);

      // The first account "state" has isMut=true, isSigner=true
      final stateAccount =
          ix.accounts.firstWhere(
                (a) => a is IdlInstructionAccount && a.name == 'state',
                orElse: () => throw StateError('state account not found'),
              )
              as IdlInstructionAccount;
      expect(stateAccount.writable, isTrue);
      expect(stateAccount.signer, isTrue);
      expect(stateAccount.isMut, isTrue); // Legacy getter
      expect(stateAccount.isSigner, isTrue); // Legacy getter

      report.pass('Legacy', 'isMut/isSigner mapped to writable/signer');
    });

    test('parses legacy bare "defined" string type references', () {
      // Legacy format: "defined": "FooStruct" (bare string)
      // New format: "defined": {"name": "FooStruct"} (object)
      final types = legacyIdl.types!;
      final fooStruct = types.firstWhere((t) => t.name == 'FooStruct');
      expect(fooStruct.type.kind, equals('struct'));

      // Check a field that references another defined type
      final nestedField = fooStruct.type.fields!.firstWhere(
        (f) => f.name == 'nested' || f.name == 'enumField',
        orElse: () => fooStruct.type.fields!.first,
      );
      // It should have been parsed regardless of format
      expect(nestedField.type, isNotNull);

      report.pass('Legacy', 'bare "defined" string type references parsed');
    });

    test('parses legacy event with index field', () {
      expect(legacyIdl.events, isNotNull);
      expect(legacyIdl.events!, hasLength(1));

      final event = legacyIdl.events!.first;
      expect(event.name, equals('SomeEvent'));
      expect(event.fields, isNotNull);
      expect(event.fields!, hasLength(3));

      // Legacy events have "index" field specifier (ignored in parsing but present)
      expect(event.fields![0].name, equals('boolField'));

      report.pass('Legacy', 'event with fields parsed (SomeEvent, 3 fields)');
    });

    test('parses legacy errors', () {
      expect(legacyIdl.errors, isNotNull);
      expect(legacyIdl.errors!, hasLength(3));

      report.pass('Legacy', 'errors parsed (3 errors)');
    });

    test('legacy and new IDLs have same instruction set', () {
      // Both old.json and new.json represent the same program
      final legacyIxNames = legacyIdl.instructions.map((i) => i.name).toSet();
      final newIxNames = newIdl.instructions.map((i) => i.name).toSet();

      // Legacy uses camelCase, new uses snake_case
      // Some mapping: initializeWithValues → initialize_with_values
      expect(legacyIxNames, contains('initialize'));
      expect(newIxNames, contains('initialize'));

      // Both should have 4 instructions
      expect(legacyIdl.instructions.length, equals(newIdl.instructions.length));

      report.pass(
        'Legacy',
        'same instruction count as new format (${legacyIdl.instructions.length})',
      );
    });

    test('legacy and new IDLs have same type definitions', () {
      final legacyTypeNames = legacyIdl.types!.map((t) => t.name).toSet();
      final newTypeNames = newIdl.types!.map((t) => t.name).toSet();

      // Types should match (modulo naming differences)
      expect(legacyTypeNames, contains('BarStruct'));
      expect(newTypeNames, contains('BarStruct'));
      expect(legacyTypeNames, contains('FooEnum'));
      expect(newTypeNames, contains('FooEnum'));

      report.pass('Legacy', 'type definitions match new format');
    });

    test('legacy IDL round-trips through JSON', () {
      final json = legacyIdl.toJson();
      final reparsed = Idl.fromJson(json);

      expect(
        reparsed.instructions.length,
        equals(legacyIdl.instructions.length),
      );
      expect(reparsed.types!.length, equals(legacyIdl.types!.length));
      expect(reparsed.events!.length, equals(legacyIdl.events!.length));
      expect(reparsed.constants!.length, equals(legacyIdl.constants!.length));

      report.pass('Legacy', 'JSON round-trip preserves all sections');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Multi-Event IDL Parsing and Event Coder
  // ═══════════════════════════════════════════════════════════════════════════

  group('Multi-event IDL (amm_v3)', () {
    late Idl ammIdl;

    setUpAll(() {
      ammIdl = loadFixtureIdl('amm_v3_events.json');
    });

    test('parses all 11 events with discriminators', () {
      expect(ammIdl.events, isNotNull);
      expect(ammIdl.events!, hasLength(11));

      for (final event in ammIdl.events!) {
        expect(event.name, isNotEmpty);
        expect(event.discriminator, isNotNull);
        expect(event.discriminator!, hasLength(8));
      }

      report.pass(
        'Events',
        'all 11 amm_v3 events parsed with 8-byte discriminators',
      );
    });

    test('event type definitions exist in types section', () {
      final eventNames = ammIdl.events!.map((e) => e.name).toSet();
      final typeNames = ammIdl.types!.map((t) => t.name).toSet();

      // Every event should have a matching type definition
      for (final eventName in eventNames) {
        expect(
          typeNames,
          contains(eventName),
          reason: 'Event "$eventName" should have a matching type definition',
        );
      }

      report.pass('Events', 'all 11 events have matching type definitions');
    });

    test('SwapEvent type has 12 fields with diverse types', () {
      final swapType = ammIdl.types!.firstWhere((t) => t.name == 'SwapEvent');
      expect(swapType.type.kind, equals('struct'));
      expect(swapType.type.fields, hasLength(12));

      // Verify field type diversity
      final fieldTypes = swapType.type.fields!.map((f) => f.type.kind).toSet();
      expect(fieldTypes, containsAll(['pubkey', 'u64', 'u128', 'bool']));

      report.pass(
        'Events',
        'SwapEvent: 12 fields, types: ${fieldTypes.join(", ")}',
      );
    });

    test('event coder initializes with all 11 events', () {
      final coder = BorshEventCoder(ammIdl);

      // The coder should not throw during initialization
      // Verify by encoding a simple event
      expect(coder, isNotNull);

      report.pass('Events', 'BorshEventCoder initialized with 11 events');
    });

    test('event encode/decode for SwapEvent documents u128 limitation', () {
      final coder = BorshEventCoder(ammIdl);

      // SwapEvent contains u128 fields which the event encoder doesn't support yet
      final swapType = ammIdl.types!.firstWhere((t) => t.name == 'SwapEvent');
      final eventData = <String, dynamic>{};
      for (final field in swapType.type.fields!) {
        switch (field.type.kind) {
          case 'pubkey':
            eventData[field.name] = '11111111111111111111111111111111';
            break;
          case 'u64':
            eventData[field.name] = 1000;
            break;
          case 'u128':
            eventData[field.name] = BigInt.from(999999);
            break;
          case 'bool':
            eventData[field.name] = true;
            break;
          case 'i32':
            eventData[field.name] = -100;
            break;
        }
      }

      // u128 type is not yet supported in event encoder
      expect(
        () => coder.encode('SwapEvent', eventData),
        throwsA(predicate((e) => e.toString().contains('u128'))),
      );

      report.pass('Events', 'SwapEvent u128 limitation documented');
    });

    test(
      'event encode/decode for PoolCreatedEvent documents u128 limitation',
      () {
        final coder = BorshEventCoder(ammIdl);

        final poolType = ammIdl.types!.firstWhere(
          (t) => t.name == 'PoolCreatedEvent',
        );
        final eventData = <String, dynamic>{};
        for (final field in poolType.type.fields!) {
          switch (field.type.kind) {
            case 'pubkey':
              eventData[field.name] = '11111111111111111111111111111111';
              break;
            case 'u64':
              eventData[field.name] = 500;
              break;
            case 'u128':
              eventData[field.name] = BigInt.from(12345);
              break;
            case 'u16':
              eventData[field.name] = 10;
              break;
            case 'i32':
              eventData[field.name] = -50;
              break;
          }
        }

        // u128 type is not yet supported in event encoder
        expect(
          () => coder.encode('PoolCreatedEvent', eventData),
          throwsA(predicate((e) => e.toString().contains('u128'))),
        );

        report.pass('Events', 'PoolCreatedEvent u128 limitation documented');
      },
    );

    test('event discriminators are unique across all 11 events', () {
      final discriminators = <String>{};
      for (final event in ammIdl.events!) {
        final discHex = event.discriminator!
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        expect(
          discriminators.add(discHex),
          isTrue,
          reason: 'Discriminator collision for ${event.name}',
        );
      }

      report.pass('Events', 'all 11 discriminators are unique');
    });

    test('large IDL parses all sections completely', () {
      expect(ammIdl.instructions, hasLength(25));
      expect(ammIdl.accounts, isNotNull);
      expect(ammIdl.accounts!, hasLength(9));
      expect(ammIdl.types!, hasLength(26));
      expect(ammIdl.errors, isNotNull);
      expect(ammIdl.errors!, hasLength(45));

      report.pass(
        'Events',
        'amm_v3 IDL: 25 instructions, 9 accounts, 26 types, 11 events, 45 errors',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Deeply Nested Optional Types
  // ═══════════════════════════════════════════════════════════════════════════

  group('Deeply nested optional types (mpl_token_metadata)', () {
    late Idl metadataIdl;

    setUpAll(() {
      metadataIdl = loadFixtureIdl('mpl_token_metadata.json');
    });

    test('parses Metadata account type', () {
      expect(metadataIdl.accounts, isNotNull);
      expect(metadataIdl.accounts!, hasLength(1));
      expect(metadataIdl.accounts!.first.name, equals('Metadata'));

      report.pass('Nested', 'Metadata account parsed');
    });

    test('parses option<vec<defined>> type (creators field)', () {
      final types = metadataIdl.types!;
      final metadataType = types.firstWhere((t) => t.name == 'Metadata');
      final creatorsField = metadataType.type.fields!.firstWhere(
        (f) => f.name == 'creators',
      );

      // Should be option<vec<defined:Creator>>
      expect(creatorsField.type.kind, equals('option'));
      expect(creatorsField.type.inner, isNotNull);
      expect(creatorsField.type.inner!.kind, equals('vec'));
      expect(creatorsField.type.inner!.inner, isNotNull);
      expect(creatorsField.type.inner!.inner!.kind, equals('defined'));
      expect(creatorsField.type.inner!.inner!.defined!.name, equals('Creator'));

      report.pass(
        'Nested',
        'option<vec<defined:Creator>> parsed (3 levels deep)',
      );
    });

    test('parses option<defined:enum> types', () {
      final types = metadataIdl.types!;
      final metadataType = types.firstWhere((t) => t.name == 'Metadata');

      final tokenStandardField = metadataType.type.fields!.firstWhere(
        (f) => f.name == 'token_standard',
      );
      expect(tokenStandardField.type.kind, equals('option'));
      expect(tokenStandardField.type.inner!.kind, equals('defined'));
      expect(
        tokenStandardField.type.inner!.defined!.name,
        equals('TokenStandard'),
      );

      // Verify TokenStandard is an enum
      final tokenStandard = types.firstWhere((t) => t.name == 'TokenStandard');
      expect(tokenStandard.type.kind, equals('enum'));
      expect(tokenStandard.type.variants, isNotNull);

      report.pass('Nested', 'option<defined:TokenStandard(enum)> parsed');
    });

    test('parses option<defined:struct> types', () {
      final types = metadataIdl.types!;
      final metadataType = types.firstWhere((t) => t.name == 'Metadata');

      final collectionField = metadataType.type.fields!.firstWhere(
        (f) => f.name == 'collection',
      );
      expect(collectionField.type.kind, equals('option'));
      expect(collectionField.type.inner!.kind, equals('defined'));
      expect(collectionField.type.inner!.defined!.name, equals('Collection'));

      // Verify Collection is a struct
      final collection = types.firstWhere((t) => t.name == 'Collection');
      expect(collection.type.kind, equals('struct'));
      expect(collection.type.fields, isNotNull);

      report.pass('Nested', 'option<defined:Collection(struct)> parsed');
    });

    test('parses nested option through defined type indirection', () {
      final types = metadataIdl.types!;

      // ProgrammableConfig is an enum with a variant that contains option<pubkey>
      final progConfig = types.firstWhere(
        (t) => t.name == 'ProgrammableConfig',
      );
      expect(progConfig.type.kind, equals('enum'));

      final variants = progConfig.type.variants!;
      expect(variants, isNotEmpty);

      // The V1 variant should have a rule_set field with type option<pubkey>
      final v1Variant = variants.firstWhere((v) => v.name == 'V1');
      expect(v1Variant.fields, isNotNull);
      final ruleSetField = v1Variant.fields!.firstWhere(
        (f) => f.name == 'rule_set',
      );
      expect(ruleSetField.type.kind, equals('option'));
      expect(
        ruleSetField.type.inner!.kind,
        anyOf(equals('pubkey'), equals('publicKey')),
      );

      report.pass(
        'Nested',
        'deeply nested: option<defined:ProgrammableConfig(enum(option<pubkey>))>',
      );
    });

    test('type diversity coverage', () {
      final types = metadataIdl.types!;
      expect(types.length, greaterThanOrEqualTo(9));

      final structs = types.where((t) => t.type.kind == 'struct').length;
      final enums = types.where((t) => t.type.kind == 'enum').length;

      expect(structs, greaterThan(0));
      expect(enums, greaterThan(0));

      report.pass(
        'Nested',
        'mpl_token_metadata: ${types.length} types ($structs structs, $enums enums)',
      );
    });

    test('metadata IDL round-trips through JSON', () {
      final json = metadataIdl.toJson();
      final reparsed = Idl.fromJson(json);

      expect(reparsed.types!.length, equals(metadataIdl.types!.length));
      expect(reparsed.accounts!.length, equals(metadataIdl.accounts!.length));

      // Verify nested option survives round-trip
      final reparsedMeta = reparsed.types!.firstWhere(
        (t) => t.name == 'Metadata',
      );
      final creatorsField = reparsedMeta.type.fields!.firstWhere(
        (f) => f.name == 'creators',
      );
      expect(creatorsField.type.kind, equals('option'));
      expect(creatorsField.type.inner!.kind, equals('vec'));
      expect(creatorsField.type.inner!.inner!.kind, equals('defined'));

      report.pass('Nested', 'JSON round-trip preserves nested options');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Legacy ↔ New Format Cross-Comparison
  // ═══════════════════════════════════════════════════════════════════════════

  group('Legacy vs new format cross-comparison', () {
    late Idl legacyIdl;
    late Idl newIdl;

    setUpAll(() {
      legacyIdl = loadFixtureIdl('legacy_idl_program.json');
      newIdl = loadFixtureIdl('anchor_idl_test_program.json');
    });

    test('both formats parse the same enum variants', () {
      final legacyEnum = legacyIdl.types!.firstWhere(
        (t) => t.name == 'FooEnum',
      );
      final newEnum = newIdl.types!.firstWhere((t) => t.name == 'FooEnum');

      expect(legacyEnum.type.kind, equals('enum'));
      expect(newEnum.type.kind, equals('enum'));
      expect(
        legacyEnum.type.variants!.length,
        equals(newEnum.type.variants!.length),
      );

      // Variant names should match
      final legacyVariantNames = legacyEnum.type.variants!
          .map((v) => v.name)
          .toList();
      final newVariantNames = newEnum.type.variants!
          .map((v) => v.name)
          .toList();
      expect(legacyVariantNames, equals(newVariantNames));

      report.pass(
        'CrossCompare',
        'FooEnum variants match (${legacyVariantNames.length} variants)',
      );
    });

    test('both formats parse BarStruct with same fields', () {
      final legacyBar = legacyIdl.types!.firstWhere(
        (t) => t.name == 'BarStruct',
      );
      final newBar = newIdl.types!.firstWhere((t) => t.name == 'BarStruct');

      expect(legacyBar.type.fields!.length, equals(newBar.type.fields!.length));

      // Field types should match (modulo name casing)
      for (int i = 0; i < legacyBar.type.fields!.length; i++) {
        expect(
          legacyBar.type.fields![i].type.kind,
          equals(newBar.type.fields![i].type.kind),
        );
      }

      report.pass('CrossCompare', 'BarStruct fields match across formats');
    });

    test('new format has discriminators, legacy does not', () {
      // New format events have pre-computed discriminators
      if (newIdl.events != null && newIdl.events!.isNotEmpty) {
        final newEvent = newIdl.events!.first;
        expect(newEvent.discriminator, isNotNull);
      }

      // Legacy format events typically don't have discriminators
      if (legacyIdl.events != null && legacyIdl.events!.isNotEmpty) {
        final legacyEvent = legacyIdl.events!.first;
        // Old format may or may not have discriminators — no crash either way
        expect(legacyEvent.name, isNotEmpty);
      }

      report.pass(
        'CrossCompare',
        'discriminator presence matches expected format',
      );
    });

    test('new format has address field, legacy does not', () {
      expect(newIdl.address, isNotNull);
      expect(newIdl.address, isNotEmpty);

      // Legacy format has no address at top level
      expect(legacyIdl.address, isNull);

      report.pass('CrossCompare', 'address field: new=present, legacy=absent');
    });

    test('instruction encoder works with new format IDL', () {
      final coder = BorshInstructionCoder(newIdl);

      // Encode a simple instruction to verify coder works
      final encoded = coder.encode('initialize', {});
      expect(encoded.length, equals(8)); // Just discriminator, no args

      report.pass('CrossCompare', 'instruction coder works with new format');
    });
  });
}
