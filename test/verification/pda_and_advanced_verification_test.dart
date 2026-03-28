/// PDA and Advanced Features Verification Test
///
/// Verifies:
///   - IDL PDA parsing (const, account, arg seed types)
///   - PDA derivation engine (determinism, off-curve, consistency)
///   - PDA seed resolver (IDL seed → concrete bytes)
///   - Complex enum encode/decode edge cases
///   - Account relations and fixed-address parsing
///   - Multi-fixture IDL parsing (external, relations programs)
///
/// Uses real Anchor IDLs: external.json, relations.json, and the test program IDL.
///
/// Run: dart test test/verification/pda_and_advanced_verification_test.dart -r expanded
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/src/coder/instruction_coder.dart';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/pda/pda_derivation_engine.dart';
import 'package:coral_xyz/src/pda/pda_seed_resolver.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:test/test.dart';

import 'verification_helpers.dart';

void main() {
  late Idl externalIdl;
  late Idl relationsIdl;
  late Idl testProgramIdl;
  final report = VerificationReport();

  setUpAll(() {
    externalIdl = loadFixtureIdl('external_pda_program.json');
    relationsIdl = loadFixtureIdl('relations_pda_program.json');
    testProgramIdl = loadFixtureIdl('anchor_idl_test_program.json');
  });

  tearDownAll(() {
    report.printSummary();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. PDA IDL Parsing
  // ═══════════════════════════════════════════════════════════════════════════

  group('PDA IDL parsing', () {
    test('external IDL: account seed type parsed', () {
      // The "init" instruction's "my_account" has PDA with account seed
      final initIx = externalIdl.instructions.firstWhere(
        (ix) => ix.name == 'init',
      );
      final myAccount = initIx.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'my_account');

      expect(myAccount.pda, isNotNull, reason: 'my_account should have PDA');
      expect(myAccount.pda!.seeds.length, equals(1));

      final seed = myAccount.pda!.seeds[0];
      expect(seed, isA<IdlSeedAccount>());
      expect((seed as IdlSeedAccount).path, equals('authority'));

      report.pass(
        'PDA',
        'account seed parsed from external IDL',
        detail: 'path=authority',
      );
    });

    test('relations IDL: const seed type parsed', () {
      // init_base's "account" has PDA with const seed [115,101,101,100] = "seed"
      final initBase = relationsIdl.instructions.firstWhere(
        (ix) => ix.name == 'init_base',
      );
      final account = initBase.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'account');

      expect(account.pda, isNotNull);
      expect(account.pda!.seeds.length, equals(1));

      final seed = account.pda!.seeds[0];
      expect(seed, isA<IdlSeedConst>());
      final constSeed = seed as IdlSeedConst;
      expect(constSeed.value, equals([115, 101, 101, 100]));
      // "seed" in UTF-8
      expect(String.fromCharCodes(constSeed.value), equals('seed'));

      report.pass(
        'PDA',
        'const seed parsed from relations IDL',
        detail: 'value=[115,101,101,100]="seed"',
      );
    });

    test('relations IDL: nested account group with PDAs', () {
      final testRelation = relationsIdl.instructions.firstWhere(
        (ix) => ix.name == 'test_relation',
      );

      // Should have top-level accounts + a nested group
      final nestedGroup = testRelation.accounts
          .whereType<IdlInstructionAccounts>()
          .firstWhere((a) => a.name == 'nested');
      expect(nestedGroup.accounts, isNotNull);

      // Nested group should contain accounts with PDAs
      final nestedAccount = nestedGroup.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'account');
      expect(nestedAccount.pda, isNotNull);
      expect(nestedAccount.pda!.seeds[0], isA<IdlSeedConst>());

      report.pass(
        'PDA',
        'nested account group with PDAs parsed',
        detail: 'nested.account has const seed PDA',
      );
    });

    test('external IDL: composite accounts preserve PDA through nesting', () {
      final updateComposite = externalIdl.instructions.firstWhere(
        (ix) => ix.name == 'update_composite',
      );

      // update_composite has a nested "update" group containing accounts with PDAs
      final updateGroup = updateComposite.accounts
          .whereType<IdlInstructionAccounts>()
          .firstWhere((a) => a.name == 'update');

      final myAccount = updateGroup.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'my_account');

      expect(myAccount.pda, isNotNull);
      expect(myAccount.pda!.seeds[0], isA<IdlSeedAccount>());
      expect(
        (myAccount.pda!.seeds[0] as IdlSeedAccount).path,
        equals('authority'),
      );

      report.pass(
        'PDA',
        'composite account nesting preserves PDA definitions',
        detail: 'update_composite.update.my_account has account seed',
      );
    });

    test('external IDL: fixed-address account parsed', () {
      final initIx = externalIdl.instructions.firstWhere(
        (ix) => ix.name == 'init',
      );
      final systemProgram = initIx.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'system_program');

      expect(systemProgram.address, equals('11111111111111111111111111111111'));

      report.pass(
        'PDA',
        'fixed-address account parsed',
        detail: 'system_program address=1111...1111',
      );
    });

    test('relations IDL: account relations parsed', () {
      final testRelation = relationsIdl.instructions.firstWhere(
        (ix) => ix.name == 'test_relation',
      );
      final myAccount = testRelation.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'my_account');

      expect(myAccount.relations, isNotNull);
      expect(myAccount.relations, contains('account'));

      report.pass(
        'PDA',
        'account relations parsed',
        detail: 'my_account.relations=[account]',
      );
    });

    test('PDA seed toJson/fromJson round-trip', () {
      // Verify all seed types survive serialization
      final constSeed = IdlSeedConst(value: [1, 2, 3]);
      final constJson = constSeed.toJson();
      final constBack = IdlSeed.fromJson(constJson);
      expect(constBack, isA<IdlSeedConst>());
      expect((constBack as IdlSeedConst).value, equals([1, 2, 3]));

      final accountSeed = IdlSeedAccount(path: 'authority');
      final accountJson = accountSeed.toJson();
      final accountBack = IdlSeed.fromJson(accountJson);
      expect(accountBack, isA<IdlSeedAccount>());
      expect((accountBack as IdlSeedAccount).path, equals('authority'));

      final argSeed = IdlSeedArg(path: 'index', type: IdlType.fromJson('u64'));
      final argJson = argSeed.toJson();
      final argBack = IdlSeed.fromJson(argJson);
      expect(argBack, isA<IdlSeedArg>());
      expect((argBack as IdlSeedArg).path, equals('index'));

      report.pass('PDA', 'all seed types survive toJson/fromJson round-trip');
    });

    test('IdlPda toJson/fromJson round-trip', () {
      final pda = IdlPda(
        seeds: [
          IdlSeedConst(value: [112, 111, 115]),
          IdlSeedAccount(path: 'owner'),
        ],
      );
      final json = pda.toJson();
      final back = IdlPda.fromJson(json);

      expect(back.seeds.length, equals(2));
      expect(back.seeds[0], isA<IdlSeedConst>());
      expect(back.seeds[1], isA<IdlSeedAccount>());

      report.pass('PDA', 'IdlPda round-trip preserves seeds');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. PDA Derivation Engine
  // ═══════════════════════════════════════════════════════════════════════════

  group('PDA derivation engine', () {
    test('derives deterministic address from string seed', () {
      final programId = PublicKey.fromBase58(
        '11111111111111111111111111111112',
      );
      final result1 = PdaDerivationEngine.findProgramAddress([
        StringSeed('hello'),
      ], programId);
      final result2 = PdaDerivationEngine.findProgramAddress([
        StringSeed('hello'),
      ], programId);

      expect(result1.address, equals(result2.address));
      expect(result1.bump, equals(result2.bump));

      report.pass(
        'PDA',
        'derivation is deterministic',
        detail: 'same seeds+program → same PDA',
      );
    });

    test('different seeds produce different addresses', () {
      final programId = PublicKey.fromBase58(
        '11111111111111111111111111111112',
      );
      final result1 = PdaDerivationEngine.findProgramAddress([
        StringSeed('seed_a'),
      ], programId);
      final result2 = PdaDerivationEngine.findProgramAddress([
        StringSeed('seed_b'),
      ], programId);

      expect(result1.address, isNot(equals(result2.address)));

      report.pass('PDA', 'different seeds → different addresses');
    });

    test('different program IDs produce different addresses', () {
      final program1 = PublicKey.fromBase58('11111111111111111111111111111112');
      final program2 = PublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final result1 = PdaDerivationEngine.findProgramAddress([
        StringSeed('test'),
      ], program1);
      final result2 = PdaDerivationEngine.findProgramAddress([
        StringSeed('test'),
      ], program2);

      expect(result1.address, isNot(equals(result2.address)));

      report.pass('PDA', 'different programs → different addresses');
    });

    test('bump is in valid range [0, 255]', () {
      final programId = PublicKey.fromBase58(
        '11111111111111111111111111111112',
      );
      final result = PdaDerivationEngine.findProgramAddress([
        StringSeed('bump_test'),
      ], programId);

      expect(result.bump, greaterThanOrEqualTo(0));
      expect(result.bump, lessThanOrEqualTo(255));

      report.pass(
        'PDA',
        'bump in valid range [0, 255]',
        detail: 'bump=${result.bump}',
      );
    });

    test('supports multiple seeds', () {
      final programId = PublicKey.fromBase58(
        '11111111111111111111111111111112',
      );
      final result = PdaDerivationEngine.findProgramAddress([
        StringSeed('prefix'),
        NumberSeed(42, byteLength: 8),
        BytesSeed(Uint8List.fromList([1, 2, 3])),
      ], programId);

      expect(result.address.toBase58(), isNotEmpty);

      report.pass(
        'PDA',
        'multiple seed types work together',
        detail: 'string+number+bytes seeds',
      );
    });

    test('PublicKeySeed works for account-based seeds', () {
      final programId = PublicKey.fromBase58(
        '11111111111111111111111111111112',
      );
      final authority = PublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final result = PdaDerivationEngine.findProgramAddress([
        PublicKeySeed(authority),
      ], programId);

      expect(result.address.toBase58(), isNotEmpty);

      report.pass('PDA', 'PublicKeySeed produces valid PDA');
    });

    test('too-long seed rejects', () {
      final programId = PublicKey.fromBase58(
        '11111111111111111111111111111112',
      );
      // A single seed > 32 bytes should be rejected
      expect(
        () => PdaDerivationEngine.findProgramAddress([
          BytesSeed(Uint8List(33)),
        ], programId),
        throwsA(isA<PdaDerivationException>()),
      );

      report.pass('PDA', 'rejects seed > 32 bytes');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. PDA Seed Resolver
  // ═══════════════════════════════════════════════════════════════════════════

  group('PDA seed resolver', () {
    test('resolves const seeds from IDL', () {
      // Use the relations IDL's const seed [115,101,101,100] = "seed"
      final initBase = relationsIdl.instructions.firstWhere(
        (ix) => ix.name == 'init_base',
      );
      final account = initBase.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'account');

      final resolved = PdaSeedResolver.resolveSeeds(account.pda!.seeds);
      expect(resolved.length, equals(1));
      expect(resolved[0].toBytes(), equals([115, 101, 101, 100]));

      report.pass(
        'PDA',
        'const seed resolved from IDL',
        detail: 'bytes match IDL value',
      );
    });

    test('resolves account seeds with provided accounts', () {
      final initIx = externalIdl.instructions.firstWhere(
        (ix) => ix.name == 'init',
      );
      final myAccount = initIx.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'my_account');

      final authorityKey = PublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final resolved = PdaSeedResolver.resolveSeeds(
        myAccount.pda!.seeds,
        accounts: {'authority': authorityKey},
      );

      expect(resolved.length, equals(1));
      // Should resolve to the 32-byte public key
      expect(resolved[0].toBytes().length, equals(32));
      expect(resolved[0].toBytes(), equals(authorityKey.toBytes()));

      report.pass(
        'PDA',
        'account seed resolved with provided PublicKey',
        detail: 'bytes match authority key',
      );
    });

    test('derivePda produces valid PDA from IDL definition', () {
      final initBase = relationsIdl.instructions.firstWhere(
        (ix) => ix.name == 'init_base',
      );
      final account = initBase.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'account');

      final programId = PublicKey.fromBase58(relationsIdl.address!);

      final result = PdaSeedResolver.derivePda(account.pda!, programId);

      expect(result.address.toBase58(), isNotEmpty);
      expect(result.bump, greaterThanOrEqualTo(0));
      expect(result.bump, lessThanOrEqualTo(255));

      // Verify determinism: same IDL + same program → same PDA
      final result2 = PdaSeedResolver.derivePda(account.pda!, programId);
      expect(result.address, equals(result2.address));
      expect(result.bump, equals(result2.bump));

      report.pass(
        'PDA',
        'derivePda from IDL definition works',
        detail:
            'address=${result.address.toBase58().substring(0, 8)}..., bump=${result.bump}',
      );
    });

    test('arg seed resolves numeric types', () {
      // Create an arg seed manually (amm_v3 has these)
      final argSeed = IdlSeedArg(path: 'index', type: IdlType.fromJson('u16'));

      final resolved = PdaSeedResolver.resolveSeeds(
        [argSeed],
        args: {'index': 42},
      );

      expect(resolved.length, equals(1));
      // u16 should produce 2 bytes in little-endian
      final bytes = resolved[0].toBytes();
      expect(bytes.length, equals(2));
      expect(bytes[0], equals(42)); // low byte
      expect(bytes[1], equals(0)); // high byte

      report.pass(
        'PDA',
        'arg seed resolves u16 correctly',
        detail: '42 → [42, 0]',
      );
    });

    test('arg seed resolves string type', () {
      final argSeed = IdlSeedArg(
        path: 'name',
        type: IdlType.fromJson('string'),
      );

      final resolved = PdaSeedResolver.resolveSeeds(
        [argSeed],
        args: {'name': 'hello'},
      );

      expect(resolved.length, equals(1));
      expect(resolved[0].toBytes(), equals('hello'.codeUnits));

      report.pass('PDA', 'arg seed resolves string correctly');
    });

    test('mixed seed types resolve together', () {
      // Simulate a real PDA with const + account + arg seeds
      final seeds = [
        IdlSeedConst(value: [112, 111, 115]), // "pos"
        IdlSeedAccount(path: 'owner'),
        IdlSeedArg(path: 'id', type: IdlType.fromJson('u32')),
      ];

      final owner = PublicKey.fromBase58('11111111111111111111111111111112');

      final resolved = PdaSeedResolver.resolveSeeds(
        seeds,
        accounts: {'owner': owner},
        args: {'id': 7},
      );

      expect(resolved.length, equals(3));
      expect(resolved[0].toBytes(), equals([112, 111, 115]));
      expect(resolved[1].toBytes(), equals(owner.toBytes()));
      final idBytes = resolved[2].toBytes();
      expect(idBytes[0], equals(7));

      report.pass('PDA', 'mixed seed types (const+account+arg) resolve');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Complex Enum Encoding Edge Cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('Complex enum encoding', () {
    late BorshInstructionCoder coder;

    setUpAll(() {
      coder = BorshInstructionCoder(testProgramIdl);
    });

    // Use the known-good arg structure from the main verification test
    Map<String, dynamic> _baseArgs({
      Map<String, dynamic>? enumField1Override,
      Map<String, dynamic>? enumField4Override,
    }) => {
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
      'enum_field_1':
          enumField1Override ??
          {
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
      'enum_field_4': enumField4Override ?? {'NoFields': {}},
    };

    test('encodes enum with unit variant (NoFields)', () {
      final data = coder.encode(
        'initialize_with_values',
        _baseArgs(
          enumField1Override: {'NoFields': {}},
          enumField4Override: {'NoFields': {}},
        ),
      );

      expect(data.length, greaterThan(8));
      final decoded = coder.decode(data);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('initialize_with_values'));

      report.pass(
        'PDA',
        'enum unit variant (NoFields) encodes/decodes',
        detail: '${data.length} bytes',
      );
    });

    test('encodes enum with tuple variant (Unnamed)', () {
      final data = coder.encode(
        'initialize_with_values',
        _baseArgs(
          enumField1Override: {
            'Unnamed': [
              true,
              42,
              {'some_field': false, 'other_field': 7},
            ],
          },
        ),
      );

      final decoded = coder.decode(data);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('initialize_with_values'));

      report.pass('PDA', 'enum tuple variant (Unnamed) encodes/decodes');
    });

    test('encodes enum with named variant (Named)', () {
      // enum_field_2 uses Named variant — already in baseArgs
      final data = coder.encode('initialize_with_values', _baseArgs());

      final decoded = coder.decode(data);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals('initialize_with_values'));

      report.pass('PDA', 'enum named variant (Named) encodes/decodes');
    });

    test('encodes enum with struct variant (Struct)', () {
      // enum_field_3 uses Struct variant — already in baseArgs
      final data = coder.encode('initialize_with_values', _baseArgs());

      final decoded = coder.decode(data);
      expect(decoded, isNotNull);

      report.pass('PDA', 'enum struct variant (Struct) encodes/decodes');
    });

    test('option<struct> with Some value encodes and decodes correctly', () {
      // Session 3 incorrectly identified this as a bug — the test was passing
      // BarStruct fields for a FooStruct-typed option. With correct FooStruct
      // data, option<defined> encoding works perfectly.
      final args = _baseArgs();
      args['option_struct_field'] = {
        'field1': 10,
        'field2': 200,
        'nested': {'some_field': true, 'other_field': 5},
        'vec_nested': <Map<String, dynamic>>[],
        'option_nested': null,
        'enum_field': {'NoFields': {}},
      };

      final encoded = coder.encode('initialize_with_values', args);
      expect(encoded.length, greaterThan(8));

      final decoded = coder.decode(encoded);
      expect(decoded, isNotNull);
      final decodedOption = decoded!.data['option_struct_field'];
      expect(decodedOption, isNotNull);
      expect(decodedOption['field1'], equals(10));
      expect(decodedOption['field2'], equals(200));

      report.pass(
        'PDA',
        'option<struct> Some value encodes/decodes',
        detail: 'FooStruct round-trip through option verified',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Multi-IDL Format Verification
  // ═══════════════════════════════════════════════════════════════════════════

  group('Multi-IDL format verification', () {
    test('external IDL parses all instructions', () {
      final ixNames = externalIdl.instructions.map((ix) => ix.name).toList();
      expect(
        ixNames,
        containsAll([
          'init',
          'update',
          'update_composite',
          'test_compilation_return_type',
        ]),
      );

      report.pass(
        'PDA',
        'external IDL: all instructions parsed',
        detail: '${ixNames.length} instructions',
      );
    });

    test('external IDL: return type parsed', () {
      final returnIx = externalIdl.instructions.firstWhere(
        (ix) => ix.name == 'test_compilation_return_type',
      );
      expect(returnIx.returns, isNotNull);

      report.pass('PDA', 'external IDL: instruction return type parsed');
    });

    test('relations IDL parses with correct address', () {
      expect(
        relationsIdl.address,
        equals('Re1ationsDerivation111111111111111111111111'),
      );
      expect(relationsIdl.metadata?.name, equals('relations_derivation'));

      report.pass('PDA', 'relations IDL: address and metadata parsed');
    });

    test('relations IDL: account type with pubkey field', () {
      final myAccountType = relationsIdl.types!.firstWhere(
        (t) => t.name == 'MyAccount',
      );
      final fields = myAccountType.type.fields;
      expect(fields, isNotNull);

      final pubkeyField = fields!.firstWhere((f) => f.name == 'my_account');
      expect(pubkeyField.type.kind, equals('pubkey'));

      final bumpField = fields.firstWhere((f) => f.name == 'bump');
      expect(bumpField.type.kind, equals('u8'));

      report.pass(
        'PDA',
        'relations IDL: MyAccount fields parsed',
        detail: 'my_account:pubkey, bump:u8',
      );
    });

    test('external IDL: writable and signer flags parsed', () {
      final initIx = externalIdl.instructions.firstWhere(
        (ix) => ix.name == 'init',
      );
      final authority = initIx.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'authority');
      final myAccount = initIx.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'my_account');

      expect(authority.writable, isTrue);
      expect(authority.signer, isTrue);
      expect(myAccount.writable, isTrue);
      expect(myAccount.signer, isFalse);

      report.pass('PDA', 'writable/signer flags parsed correctly');
    });

    test('external IDL toJson/fromJson round-trip', () {
      final json = externalIdl.toJson();
      final back = Idl.fromJson(json);

      expect(back.instructions.length, equals(externalIdl.instructions.length));
      expect(back.address, equals(externalIdl.address));

      // Verify PDA survived round-trip
      final initIx = back.instructions.firstWhere((ix) => ix.name == 'init');
      final myAccount = initIx.accounts
          .whereType<IdlInstructionAccount>()
          .firstWhere((a) => a.name == 'my_account');
      expect(myAccount.pda, isNotNull);
      expect(myAccount.pda!.seeds[0], isA<IdlSeedAccount>());

      report.pass('PDA', 'external IDL JSON round-trip preserves PDAs');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. EventAuthority PDA Verification
  // ═══════════════════════════════════════════════════════════════════════════

  group('EventAuthority PDA', () {
    test('derives deterministic event authority', () {
      final programId = PublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      // Derive twice — should be identical
      final result1 = PdaDerivationEngine.findProgramAddress([
        StringSeed('__event_authority'),
      ], programId);
      final result2 = PdaDerivationEngine.findProgramAddress([
        StringSeed('__event_authority'),
      ], programId);

      expect(result1.address, equals(result2.address));
      expect(result1.bump, equals(result2.bump));

      report.pass(
        'PDA',
        'EventAuthority PDA is deterministic',
        detail: 'bump=${result1.bump}',
      );
    });

    test('different programs get different event authorities', () {
      final program1 = PublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final program2 = PublicKey.fromBase58('11111111111111111111111111111112');

      final auth1 = PdaDerivationEngine.findProgramAddress([
        StringSeed('__event_authority'),
      ], program1);
      final auth2 = PdaDerivationEngine.findProgramAddress([
        StringSeed('__event_authority'),
      ], program2);

      expect(auth1.address, isNot(equals(auth2.address)));

      report.pass('PDA', 'different programs → different EventAuthority PDAs');
    });
  });
}
