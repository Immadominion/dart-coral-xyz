import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('AccountNamespace', () {
    test('fetch single and multiple accounts', () async {
      final idl = const Idl(
        address: 'TestAddress',
        metadata: IdlMetadata(
            name: 'TestProgram', version: '0.0.1', spec: 'anchor-idl/0.0.1',),
        accounts: [
          IdlAccount(
              name: 'TestAccount',
              type: IdlTypeDefType(kind: 'struct', fields: []),),
        ],
        instructions: [],
      );
      final coder = DummyCoder();
      final provider = AnchorProvider.defaultProvider();
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final namespace = AccountNamespace.build(
        idl: idl,
        coder: coder,
        programId: programId,
        provider: provider,
      );
      final client = namespace['TestAccount'];
      expect(client, isNotNull);
      final address = PublicKey.fromBase58('11111111111111111111111111111111');
      final single = await client!.fetch(address);
      expect(single, isNull); // Placeholder returns null
      final batch = await client.fetchMultiple([address, address]);
      expect(batch, hasLength(2));
      expect(batch[0], isNull);
    });

    test('fetch with caching', () async {
      final idl = const Idl(
        address: 'TestAddress',
        metadata: IdlMetadata(
          name: 'TestProgram',
          version: '0.0.1',
          spec: 'anchor-idl/0.0.1',
        ),
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            type: IdlTypeDefType(kind: 'struct', fields: []),
          ),
        ],
        instructions: [],
      );
      final coder = DummyCoder();
      final provider = AnchorProvider.defaultProvider();
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final namespace = AccountNamespace.build(
        idl: idl,
        coder: coder,
        programId: programId,
        provider: provider,
      );
      final client = namespace['TestAccount'];
      expect(client, isNotNull);

      final address = PublicKey.fromBase58('11111111111111111111111111111111');

      // Test with cache enabled (default)
      final cached = await client!.fetch(address);
      expect(cached, isNull); // Mock implementation returns null

      // Test with cache disabled
      final uncached = await client.fetch(address, useCache: false);
      expect(uncached, isNull); // Mock implementation returns null

      // Test cache clearing
      client.clearCache();
      client.clearExpiredCache();
    });

    test('fetchAll with filters', () async {
      final idl = const Idl(
        address: 'TestAddress',
        metadata: IdlMetadata(
          name: 'TestProgram',
          version: '0.0.1',
          spec: 'anchor-idl/0.0.1',
        ),
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            type: IdlTypeDefType(kind: 'struct', fields: []),
          ),
        ],
        instructions: [],
      );
      final coder = DummyCoder();
      final provider = AnchorProvider.defaultProvider();
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final namespace = AccountNamespace.build(
        idl: idl,
        coder: coder,
        programId: programId,
        provider: provider,
      );
      final client = namespace['TestAccount'];
      expect(client, isNotNull);

      // Test fetchAll without filters
      final all = await client!.fetchAll();
      expect(all, isA<List<ProgramAccount>>());
      expect(all, isEmpty); // Mock implementation returns empty list

      // Test fetchAll with filters
      final filtered = await client.fetchAll(
        filters: [
          MemcmpFilter(offset: 8, bytes: 'test'),
          DataSizeFilter(100),
        ],
        limit: 10,
      );
      expect(filtered, isA<List<ProgramAccount>>());
      expect(filtered, isEmpty); // Mock implementation returns empty list
    });

    test('subscription system', () async {
      final idl = const Idl(
        address: 'TestAddress',
        metadata: IdlMetadata(
          name: 'TestProgram',
          version: '0.0.1',
          spec: 'anchor-idl/0.0.1',
        ),
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            type: IdlTypeDefType(kind: 'struct', fields: []),
          ),
        ],
        instructions: [],
      );
      final coder = DummyCoder();
      final provider = AnchorProvider.defaultProvider();
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final namespace = AccountNamespace.build(
        idl: idl,
        coder: coder,
        programId: programId,
        provider: provider,
      );
      final client = namespace['TestAccount'];
      expect(client, isNotNull);

      final address = PublicKey.fromBase58('11111111111111111111111111111111');

      // Test subscription creation
      final stream = client!.subscribe(address);
      expect(stream, isA<Stream<Map<String, dynamic>>>());

      // Test unsubscribe
      client.unsubscribe(address);
    });

    test('account client properties', () async {
      final idl = const Idl(
        address: 'TestAddress',
        metadata: IdlMetadata(
          name: 'TestProgram',
          version: '0.0.1',
          spec: 'anchor-idl/0.0.1',
        ),
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            type: IdlTypeDefType(kind: 'struct', fields: []),
          ),
        ],
        instructions: [],
      );
      final coder = DummyCoder();
      final provider = AnchorProvider.defaultProvider();
      final programId =
          PublicKey.fromBase58('11111111111111111111111111111111');
      final namespace = AccountNamespace.build(
        idl: idl,
        coder: coder,
        programId: programId,
        provider: provider,
      );
      final client = namespace['TestAccount'];
      expect(client, isNotNull);

      // Test account client properties
      expect(client!.name, equals('TestAccount'));
      expect(client.size, equals(0)); // Mock implementation returns 0
      expect(client.discriminator,
          equals([]),); // Mock implementation returns empty list
    });
  });
}

// DummyCoder implements the Coder interface with all required generics and members
class DummyCoder implements Coder<String, String> {
  @override
  AccountsCoder<String> get accounts => DummyAccountsCoder();
  @override
  InstructionCoder get instructions => DummyInstructionCoder();
  @override
  EventCoder get events => DummyEventCoder();
  @override
  TypesCoder<String> get types => DummyTypesCoder();
}

// DummyAccountsCoder implements the AccountsCoder interface with all required members
class DummyAccountsCoder implements AccountsCoder<String> {
  @override
  Future<Uint8List> encode<T>(String accountName, T account) async =>
      Uint8List(0);
  @override
  T decode<T>(String accountName, Uint8List data) => null as T;
  @override
  T decodeUnchecked<T>(String accountName, Uint8List data) => null as T;
  @override
  T decodeAny<T>(Uint8List data) => null as T;
  @override
  Map<String, dynamic> memcmp(String accountName, {Uint8List? appendData}) =>
      {};
  @override
  int size(String accountName) => 0;
  @override
  Uint8List accountDiscriminator(String accountName) => Uint8List(0);
}

class DummyInstructionCoder implements InstructionCoder {
  @override
  Uint8List encode(String ixName, Map<String, dynamic> ix) => Uint8List(0);
  @override
  Instruction? decode(Uint8List data, {String encoding = 'hex'}) => null;
  @override
  InstructionDisplay? format(Instruction ix, List<AccountMeta> accountMetas) =>
      null;
}

class DummyEventCoder implements EventCoder {
  @override
  Event? decode<E extends IdlEvent>(String log) => null;
}

class DummyTypesCoder implements TypesCoder<String> {
  @override
  Uint8List encode<T>(String typeName, T data) => Uint8List(0);
  @override
  T decode<T>(String typeName, Uint8List data) => null as T;
  @override
  int? getTypeSize(String typeName) => null;
}
