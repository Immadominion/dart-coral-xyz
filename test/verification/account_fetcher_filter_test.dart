/// Regression tests for AccountFetcher.all() filter plumbing.
///
/// Verifies that discriminator filters and user-provided filters
/// are actually passed through to getProgramAccounts (Session 13 fix).
library;

import 'package:coral_xyz/coral_xyz.dart'
    hide Transaction, TransactionInstruction, AccountMeta;
import 'package:coral_xyz/src/types/account_filter.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';
import 'verification_helpers.dart';

void main() {
  late VerificationReport report;

  setUpAll(() {
    report = VerificationReport();
  });

  tearDownAll(() {
    report.printSummary();
  });

  group('AccountFetcher.all() filter plumbing', () {
    late MockConnection mockConn;
    late MockProvider mockProvider;
    late Program program;

    setUp(() async {
      mockConn = MockConnection('http://localhost:8899');
      final wallet = await MockWallet.create();
      mockProvider = MockProvider(mockConn, wallet);

      // IDL with a named account and discriminator
      final idl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            const IdlMetadata(name: 'test', version: '0.1.0', spec: '0.1.0'),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            discriminator: const [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: const [
              IdlInstructionAccount(
                  name: 'myAccount', writable: true, signer: true),
            ],
            args: const [],
          ),
        ],
        accounts: const [
          IdlAccount(
            name: 'MyAccount',
            discriminator: [99, 100, 101, 102, 103, 104, 105, 106],
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'MyAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [IdlField(name: 'value', type: IdlType.fromJson('u64'))],
            ),
          ),
        ],
      );

      program = Program(idl, provider: mockProvider);
    });

    test('all() passes discriminator filter to getProgramAccounts', () async {
      // Call fetchAll(), which should construct filters and pass them
      final results = await program.account['MyAccount']!.fetchAll();

      // Verify filters were captured
      expect(
        mockConn.lastProgramAccountsFilters,
        isNotNull,
        reason: 'Filters should be passed to getProgramAccounts',
      );
      expect(mockConn.lastProgramAccountsFilters, isNotEmpty);

      // First filter should be the discriminator memcmp
      final first = mockConn.lastProgramAccountsFilters!.first;
      expect(first, isA<MemcmpFilter>());
      final memcmp = first as MemcmpFilter;
      expect(memcmp.offset, equals(0));
      // bytes should be base64-encoded discriminator
      expect(memcmp.bytes, isNotEmpty);

      report.pass(
        'AccountFetcher',
        'all() passes discriminator filter ✓',
        detail: 'FIXED: filters were silently dropped before Session 13',
      );
    });

    test('fetchAll(filters: [...]) passes user filters alongside discriminator',
        () async {
      final userFilter = MemcmpFilter(offset: 8, bytes: 'AAAA');
      await program.account['MyAccount']!.fetchAll(filters: [userFilter]);

      final filters = mockConn.lastProgramAccountsFilters!;

      // Should have at least 2: discriminator + user filter
      expect(filters.length, greaterThanOrEqualTo(2));

      // Last filter should be the user-provided one
      final last = filters.last;
      expect(last, isA<MemcmpFilter>());
      expect((last as MemcmpFilter).offset, equals(8));
      expect(last.bytes, equals('AAAA'));

      report.pass(
        'AccountFetcher',
        'fetchAll(filters) passes user filters ✓',
        detail: 'User filters appended after discriminator',
      );
    });

    test('fetchAll() with DataSizeFilter passes it through', () async {
      final sizeFilter = DataSizeFilter(128);
      await program.account['MyAccount']!.fetchAll(filters: [sizeFilter]);

      final filters = mockConn.lastProgramAccountsFilters!;

      // Should have discriminator + data size
      final dataSizeFilters = filters.whereType<DataSizeFilter>();
      expect(dataSizeFilters, isNotEmpty);
      expect(dataSizeFilters.first.dataSize, equals(128));

      report.pass(
        'AccountFetcher',
        'fetchAll() with DataSizeFilter ✓',
        detail: 'DataSizeFilter correctly plumbed through',
      );
    });

    test('fetchAll() without user filters still passes discriminator',
        () async {
      await program.account['MyAccount']!.fetchAll();

      final filters = mockConn.lastProgramAccountsFilters!;
      expect(filters, isNotEmpty,
          reason: 'Discriminator filter must always be sent');

      report.pass(
        'AccountFetcher',
        'fetchAll() always sends discriminator ✓',
        detail: 'Even with no user filters, discriminator is sent',
      );
    });
  });
}
