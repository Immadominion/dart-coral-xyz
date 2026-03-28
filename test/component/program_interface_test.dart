/// T1.10 — ProgramInterface Builder Component Tests
///
/// Tests the manual program definition builder API:
///   ProgramInterface.define() → ProgramInterfaceBuilder →
///     .instruction() → InstructionDefBuilder → .done()
///     .account() → AccountDefBuilder → .done()
///     .type() → TypeDefBuilder → .done()
///     .event() / .error() → ProgramInterfaceBuilder
///     .build() → Idl
///
/// All tests verify produced Idl objects directly — no mocks.
library;

import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/program/program_interface.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. Builder construction & basic build
  // ---------------------------------------------------------------------------
  group('Builder construction', () {
    test('minimal build produces valid Idl', () {
      final idl = ProgramInterface.define(
        name: 'minimal',
      ).instruction('noop').done().build();

      expect(idl.name, 'minimal');
      expect(idl.instructions.length, 1);
      expect(idl.instructions.first.name, 'noop');
    });

    test('name, address, and version are set', () {
      final idl = ProgramInterface.define(
        name: 'myProg',
        address: '11111111111111111111111111111111',
        version: '1.2.3',
      ).instruction('init').done().build();

      expect(idl.name, 'myProg');
      expect(idl.address, '11111111111111111111111111111111');
      expect(idl.version, '1.2.3');
    });

    test('default version is 0.0.0', () {
      final idl = ProgramInterface.define(
        name: 'v',
      ).instruction('x').done().build();
      expect(idl.version, '0.0.0');
    });

    test('format is manual', () {
      final idl = ProgramInterface.define(
        name: 'f',
      ).instruction('x').done().build();
      expect(idl.format, IdlFormat.manual);
    });

    test('metadata contains spec: manual', () {
      final idl = ProgramInterface.define(
        name: 'meta',
      ).instruction('x').done().build();
      expect(idl.metadata, isNotNull);
      expect(idl.metadata!.spec, 'manual');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Instruction builder
  // ---------------------------------------------------------------------------
  group('Instruction builder', () {
    test('instruction with discriminator', () {
      final idl = ProgramInterface.define(
        name: 'disc',
      ).instruction('transfer', discriminator: [0xAB, 0xCD]).done().build();

      final ix = idl.instructions.first;
      expect(ix.name, 'transfer');
      expect(ix.discriminator, [0xAB, 0xCD]);
    });

    test('instruction without discriminator', () {
      final idl = ProgramInterface.define(
        name: 'nodisc',
      ).instruction('process').done().build();

      final ix = idl.instructions.first;
      expect(ix.name, 'process');
      // discriminator should be null or absent
      expect(ix.discriminator, isNull);
    });

    test('instruction accounts with flags', () {
      final idl = ProgramInterface.define(name: 'accts')
          .instruction('create')
          .account('payer', signer: true, writable: true)
          .account('data', writable: true)
          .account('system', optional: true)
          .done()
          .build();

      final accounts = idl.instructions.first.accounts
          .cast<IdlInstructionAccount>();
      expect(accounts.length, 3);

      expect(accounts[0].name, 'payer');
      expect(accounts[0].signer, true);
      expect(accounts[0].writable, true);

      expect(accounts[1].name, 'data');
      expect(accounts[1].signer, false);
      expect(accounts[1].writable, true);

      expect(accounts[2].name, 'system');
      expect(accounts[2].optional, true);
    });

    test('instruction args with simple types', () {
      final idl = ProgramInterface.define(name: 'args')
          .instruction('set')
          .arg('amount', 'u64')
          .arg('flag', 'bool')
          .arg('name', 'string')
          .done()
          .build();

      final args = idl.instructions.first.args;
      expect(args.length, 3);
      expect(args[0].name, 'amount');
      expect(args[0].type.kind, 'u64');
      expect(args[1].name, 'flag');
      expect(args[1].type.kind, 'bool');
      expect(args[2].name, 'name');
      expect(args[2].type.kind, 'string');
    });

    test('instruction args with complex types', () {
      final idl = ProgramInterface.define(name: 'complex')
          .instruction('update')
          .arg('data', {'vec': 'u8'})
          .arg('maybe', {'option': 'pubkey'})
          .arg('fixedArr', {
            'array': ['u8', 32],
          })
          .done()
          .build();

      final args = idl.instructions.first.args;
      expect(args[0].type.kind, 'vec');
      expect(args[0].type.inner!.kind, 'u8');
      expect(args[1].type.kind, 'option');
      expect(args[1].type.inner!.kind, 'pubkey');
      expect(args[2].type.kind, 'array');
      expect(args[2].type.inner!.kind, 'u8');
      expect(args[2].type.size, 32);
    });

    test('multiple instructions', () {
      final idl = ProgramInterface.define(name: 'multi')
          .instruction('init', discriminator: [0])
          .account('counter', writable: true, signer: true)
          .account('user', signer: true)
          .arg('value', 'u64')
          .done()
          .instruction('increment', discriminator: [1])
          .account('counter', writable: true)
          .arg('by', 'u64')
          .done()
          .instruction('reset', discriminator: [2])
          .account('counter', writable: true)
          .account('authority', signer: true)
          .done()
          .build();

      expect(idl.instructions.length, 3);
      expect(idl.instructions[0].name, 'init');
      expect(idl.instructions[0].discriminator, [0]);
      expect(idl.instructions[0].accounts.length, 2);
      expect(idl.instructions[0].args.length, 1);

      expect(idl.instructions[1].name, 'increment');
      expect(idl.instructions[1].discriminator, [1]);
      expect(idl.instructions[1].args.length, 1);

      expect(idl.instructions[2].name, 'reset');
      expect(idl.instructions[2].discriminator, [2]);
      expect(idl.instructions[2].accounts.length, 2);
      expect(idl.instructions[2].args.length, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Account builder
  // ---------------------------------------------------------------------------
  group('Account builder', () {
    test('account with fields and discriminator', () {
      final idl = ProgramInterface.define(name: 'acct')
          .instruction('x')
          .done()
          .account('Counter', discriminator: [0])
          .field('authority', 'pubkey')
          .field('count', 'u64')
          .field('bump', 'u8')
          .done()
          .build();

      // Account shows up in accounts list
      expect(idl.accounts, isNotNull);
      expect(idl.accounts!.length, 1);
      expect(idl.accounts!.first.name, 'Counter');
      expect(idl.accounts!.first.discriminator, [0]);

      // Account layout shows up in types
      expect(idl.types, isNotNull);
      final counterType = idl.types!
          .where((t) => t.name == 'Counter')
          .firstOrNull;
      expect(counterType, isNotNull);
      expect(counterType!.type.kind, 'struct');
      expect(counterType.type.fields!.length, 3);
      expect(counterType.type.fields![0].name, 'authority');
      expect(counterType.type.fields![0].type.kind, 'pubkey');
      expect(counterType.type.fields![1].name, 'count');
      expect(counterType.type.fields![1].type.kind, 'u64');
    });

    test('account without discriminator uses empty list', () {
      final idl = ProgramInterface.define(name: 'nodisc')
          .instruction('x')
          .done()
          .account('Data')
          .field('value', 'u32')
          .done()
          .build();

      expect(idl.accounts!.first.discriminator, isEmpty);
    });

    test('account with complex field types', () {
      final idl = ProgramInterface.define(name: 'complex')
          .instruction('x')
          .done()
          .account('Vault')
          .field('owner', 'pubkey')
          .field('balances', {'vec': 'u64'})
          .field('name', {
            'array': ['u8', 32],
          })
          .done()
          .build();

      final vaultType = idl.types!.where((t) => t.name == 'Vault').firstOrNull;
      expect(vaultType, isNotNull);
      final fields = vaultType!.type.fields!;
      expect(fields[1].type.kind, 'vec');
      expect(fields[1].type.inner!.kind, 'u64');
      expect(fields[2].type.kind, 'array');
      expect(fields[2].type.size, 32);
    });

    test('multiple accounts', () {
      final idl = ProgramInterface.define(name: 'multi')
          .instruction('x')
          .done()
          .account('Config', discriminator: [0])
          .field('admin', 'pubkey')
          .done()
          .account('UserData', discriminator: [1])
          .field('balance', 'u64')
          .field('active', 'bool')
          .done()
          .build();

      expect(idl.accounts!.length, 2);
      expect(idl.types!.length, 2);
      expect(idl.accounts![0].name, 'Config');
      expect(idl.accounts![1].name, 'UserData');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Type builder
  // ---------------------------------------------------------------------------
  group('Type builder', () {
    test('struct type with fields', () {
      final idl = ProgramInterface.define(name: 'types')
          .instruction('x')
          .done()
          .type('Point')
          .field('x', 'i32')
          .field('y', 'i32')
          .doneAsStruct()
          .build();

      final pointType = idl.types!.where((t) => t.name == 'Point').first;
      expect(pointType.type.kind, 'struct');
      expect(pointType.type.fields!.length, 2);
      expect(pointType.type.fields![0].name, 'x');
      expect(pointType.type.fields![0].type.kind, 'i32');
    });

    test('enum type with simple variants', () {
      final idl = ProgramInterface.define(name: 'enums')
          .instruction('x')
          .done()
          .type('Status')
          .variant('Active')
          .variant('Inactive')
          .variant('Pending')
          .doneAsEnum()
          .build();

      final status = idl.types!.where((t) => t.name == 'Status').first;
      expect(status.type.kind, 'enum');
      expect(status.type.variants!.length, 3);
      expect(status.type.variants![0].name, 'Active');
      expect(status.type.variants![1].name, 'Inactive');
      expect(status.type.variants![2].name, 'Pending');
    });

    test('enum type with variant fields', () {
      final idl = ProgramInterface.define(name: 'richEnum')
          .instruction('x')
          .done()
          .type('Action')
          .variant(
            'Transfer',
            fields: [
              {'name': 'amount', 'type': 'u64'},
              {'name': 'recipient', 'type': 'pubkey'},
            ],
          )
          .variant('Close')
          .doneAsEnum()
          .build();

      final action = idl.types!.where((t) => t.name == 'Action').first;
      expect(action.type.variants![0].name, 'Transfer');
      expect(action.type.variants![0].fields, isNotNull);
      expect(action.type.variants![0].fields!.length, 2);
      expect(action.type.variants![1].name, 'Close');
    });

    test('done() auto-detects struct vs enum', () {
      // Struct (has fields, no variants)
      final idlStruct = ProgramInterface.define(
        name: 'auto',
      ).instruction('x').done().type('Pos').field('x', 'f32').done().build();
      expect(idlStruct.types!.first.type.kind, 'struct');

      // Enum (has variants)
      final idlEnum = ProgramInterface.define(name: 'auto2')
          .instruction('x')
          .done()
          .type('Dir')
          .variant('Up')
          .variant('Down')
          .done()
          .build();
      expect(idlEnum.types!.first.type.kind, 'enum');
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Events & errors
  // ---------------------------------------------------------------------------
  group('Events and errors', () {
    test('events are added to idl', () {
      final idl = ProgramInterface.define(name: 'evt')
          .instruction('x')
          .done()
          .event('Transfer', discriminator: [0xAA, 0xBB])
          .event('Approval')
          .build();

      expect(idl.events, isNotNull);
      expect(idl.events!.length, 2);
      expect(idl.events!.first.name, 'Transfer');
      expect(idl.events!.first.discriminator, [0xAA, 0xBB]);
      expect(idl.events!.last.name, 'Approval');
    });

    test('errors are added to idl', () {
      final idl = ProgramInterface.define(name: 'err')
          .instruction('x')
          .done()
          .error(6000, 'Unauthorized', msg: 'Not authorized')
          .error(6001, 'Overflow')
          .build();

      expect(idl.errors, isNotNull);
      expect(idl.errors!.length, 2);
      expect(idl.errors!.first.code, 6000);
      expect(idl.errors!.first.name, 'Unauthorized');
      expect(idl.errors!.first.msg, 'Not authorized');
      expect(idl.errors!.last.code, 6001);
      expect(idl.errors!.last.name, 'Overflow');
      expect(idl.errors!.last.msg, isNull);
    });

    test('no events/errors produces null lists', () {
      final idl = ProgramInterface.define(
        name: 'bare',
      ).instruction('x').done().build();

      // events and errors may be null or empty
      expect(idl.events == null || idl.events!.isEmpty, true);
      expect(idl.errors == null || idl.errors!.isEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Full program definition (counter example from docstring)
  // ---------------------------------------------------------------------------
  group('Full program definition', () {
    test('counter program matches expected structure', () {
      final idl =
          ProgramInterface.define(
                name: 'counter',
                address: '11111111111111111111111111111111',
              )
              .instruction('initialize', discriminator: [0])
              .account('counter', writable: true, signer: true)
              .account('user', signer: true)
              .account('systemProgram')
              .arg('initialValue', 'u64')
              .done()
              .instruction('increment', discriminator: [1])
              .account('counter', writable: true)
              .account('user', signer: true)
              .arg('amount', 'u64')
              .done()
              .account('Counter', discriminator: [0])
              .field('authority', 'pubkey')
              .field('count', 'u64')
              .done()
              .error(6000, 'Overflow', msg: 'Counter overflow')
              .build();

      // Top-level
      expect(idl.name, 'counter');
      expect(idl.address, '11111111111111111111111111111111');
      expect(idl.format, IdlFormat.manual);

      // Instructions
      expect(idl.instructions.length, 2);

      final init = idl.instructions[0];
      expect(init.name, 'initialize');
      expect(init.discriminator, [0]);
      expect(init.accounts.length, 3);
      expect(init.args.length, 1);
      expect(init.args.first.name, 'initialValue');
      expect(init.args.first.type.kind, 'u64');

      final incr = idl.instructions[1];
      expect(incr.name, 'increment');
      expect(incr.discriminator, [1]);
      expect(incr.accounts.length, 2);
      expect(incr.args.first.type.kind, 'u64');

      // Accounts
      expect(idl.accounts!.length, 1);
      expect(idl.accounts!.first.name, 'Counter');

      // Types (Counter struct)
      final counterType = idl.types!.where((t) => t.name == 'Counter').first;
      expect(counterType.type.fields!.length, 2);

      // Errors
      expect(idl.errors!.length, 1);
      expect(idl.errors!.first.code, 6000);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Chaining fluency
  // ---------------------------------------------------------------------------
  group('Chaining fluency', () {
    test('builder methods return correct builder types', () {
      final parent = ProgramInterface.define(name: 'chain');

      // instruction() returns InstructionDefBuilder
      final ixBuilder = parent.instruction('ix');
      expect(ixBuilder, isA<InstructionDefBuilder>());

      // account/arg return self
      final ixBuilder2 = ixBuilder.account('a').arg('b', 'u8');
      expect(ixBuilder2, isA<InstructionDefBuilder>());

      // done() returns ProgramInterfaceBuilder
      final back = ixBuilder2.done();
      expect(back, isA<ProgramInterfaceBuilder>());

      // account() returns AccountDefBuilder
      final acctBuilder = back.account('A');
      expect(acctBuilder, isA<AccountDefBuilder>());

      // field returns self, done() returns parent
      final back2 = acctBuilder.field('x', 'u8').done();
      expect(back2, isA<ProgramInterfaceBuilder>());

      // type() returns TypeDefBuilder
      final typeBuilder = back2.type('T');
      expect(typeBuilder, isA<TypeDefBuilder>());

      // build() returns Idl
      final idl = typeBuilder.field('v', 'u8').doneAsStruct().build();
      expect(idl, isA<Idl>());
    });

    test('defined type reference in instruction args', () {
      final idl = ProgramInterface.define(name: 'defRef')
          .instruction('process')
          .arg('config', {'defined': 'Config'})
          .done()
          .type('Config')
          .field('value', 'u64')
          .doneAsStruct()
          .build();

      final arg = idl.instructions.first.args.first;
      expect(arg.type.kind, 'defined');
      expect(arg.type.defined!.name, 'Config');
    });
  });
}
