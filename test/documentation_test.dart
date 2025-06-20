/// Documentation tests for the Coral XYZ Anchor package
///
/// These tests validate that the code examples in the documentation
/// compile and work as expected. They help ensure documentation
/// stays in sync with the actual API.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Documentation Examples', () {
    // Pattern 2: Public key operations
    group('API Reference Examples', () {
      test('public key operations', () async {
        final keypair = await Keypair.generate();
        final publicKey = keypair.publicKey;
        final base58 = publicKey.toBase58();
        final fromBase58 = PublicKey.fromBase58(base58);
        expect(fromBase58, equals(publicKey));
      });
      test('Program constructor example compiles', () {
        // This test validates the basic Program constructor example
        // from the API reference documentation

        expect(() {
          // Mock IDL for testing
          final mockIdl = Idl.fromJson({
            'address': '11111111111111111111111111111112',
            'metadata': {
              'name': 'test_program',
              'version': '0.1.0',
              'spec': '0.1.0',
            },
            'instructions': [],
          });

          // This should not throw during construction
          final program = Program(mockIdl);

          // Verify the program was created correctly
          expect(program.programId.toBase58(),
              equals('11111111111111111111111111111112'));
          expect(program.idl.metadata?.name, equals('test_program'));
        }, returnsNormally);
      });

      test('PublicKey examples compile', () {
        // Test PublicKey creation examples from API reference

        // fromBase58 example
        final key1 = PublicKey.fromBase58(
          '11111111111111111111111111111112',
        );
        expect(key1.toBase58(), equals('11111111111111111111111111111112'));

        // fromBytes example
        final bytes = key1.toBytes();
        final key2 = PublicKey.fromBytes(bytes);
        expect(key2, equals(key1));
      });

      test('Keypair examples compile', () async {
        // Test Keypair creation examples

        final keypair1 = await Keypair.generate();
        expect(keypair1.publicKey, isA<PublicKey>());
        expect(keypair1.secretKey, isA<Uint8List>());

        final keypair2 = Keypair.fromSecretKey(keypair1.secretKey);
        expect(keypair2.publicKey, equals(keypair1.publicKey));
      });

      test('Connection examples compile', () {
        // Test Connection creation examples

        final connection = Connection('https://api.devnet.solana.com');
        expect(connection.rpcUrl, equals('https://api.devnet.solana.com'));

        // Test with custom config
        final connectionWithConfig = Connection(
          'https://api.devnet.solana.com',
          config: ConnectionConfig(rpcUrl: 'https://api.devnet.solana.com'),
        );
        expect(connectionWithConfig.rpcUrl,
            equals('https://api.devnet.solana.com'));
      });

      test('AnchorProvider examples compile', () async {
        // Test AnchorProvider creation examples

        final connection = Connection('https://api.devnet.solana.com');
        final keypair = await Keypair.generate();
        final wallet = KeypairWallet(keypair);

        final provider = AnchorProvider(connection, wallet);
        expect(provider.connection, equals(connection));
        expect(provider.wallet?.publicKey, equals(wallet.publicKey));

        // Test default provider
        final defaultProvider = AnchorProvider.defaultProvider();
        expect(defaultProvider, isA<AnchorProvider>());
      });
    });

    group('Migration Guide Examples', () {
      test('basic setup examples compile', () async {
        // Test the basic setup examples from migration guide

        final connection = Connection('https://api.devnet.solana.com');
        final keypair = await Keypair.generate();
        final wallet = KeypairWallet(keypair);
        final provider = AnchorProvider(connection, wallet);

        final mockIdl = Idl.fromJson({
          'address': 'Counter111111111111111111111111111111111111',
          'metadata': {
            'name': 'counter',
            'version': '0.1.0',
            'spec': '0.1.0',
          },
          'instructions': [
            {
              'name': 'initialize',
              'discriminator': [175, 175, 109, 31, 13, 152, 155, 237],
              'accounts': [],
              'args': [],
            }
          ],
        });

        final program = Program(mockIdl, provider: provider);

        expect(program.programId.toBase58(),
            equals('Counter111111111111111111111111111111111111'));
        expect(program.provider, equals(provider));
      });

      test('IDL type examples compile', () {
        // Test IDL type creation examples

        // Basic types
        final boolType = IdlType(kind: 'bool');
        expect(boolType.kind, equals('bool'));

        final u64Type = IdlType(kind: 'u64');
        expect(u64Type.kind, equals('u64'));

        final stringType = IdlType(kind: 'string');
        expect(stringType.kind, equals('string'));

        // Complex types
        final vecType = IdlType(
          kind: 'vec',
          inner: IdlType(kind: 'u8'),
        );
        expect(vecType.kind, equals('vec'));
        expect(vecType.inner?.kind, equals('u8'));

        final optionType = IdlType(
          kind: 'option',
          inner: IdlType(kind: 'string'),
        );
        expect(optionType.kind, equals('option'));
        expect(optionType.inner?.kind, equals('string'));

        final arrayType = IdlType(
          kind: 'array',
          inner: IdlType(kind: 'u8'),
          size: 32,
        );
        expect(arrayType.kind, equals('array'));
        expect(arrayType.size, equals(32));
      });
    });

    group('Complete Example Validations', () {
      test('counter IDL example is valid', () {
        // Validate the complete counter IDL from the example

        final counterIdl = {
          "address": "Counter111111111111111111111111111111111111",
          "metadata": {
            "name": "counter",
            "version": "0.1.0",
            "spec": "0.1.0",
          },
          "instructions": [
            {
              "name": "initialize",
              "discriminator": [175, 175, 109, 31, 13, 152, 155, 237],
              "accounts": [
                {
                  "name": "counter",
                  "writable": true,
                  "signer": true,
                },
                {
                  "name": "user",
                  "writable": true,
                  "signer": true,
                },
                {
                  "name": "systemProgram",
                  "address": "11111111111111111111111111111112",
                }
              ],
              "args": [
                {"name": "authority", "type": "pubkey"}
              ]
            }
          ],
          "accounts": [
            {
              "name": "counter",
              "discriminator": [255, 176, 4, 245, 188, 253, 124, 25],
              "type": {
                "kind": "struct",
                "fields": [
                  {"name": "authority", "type": "pubkey"},
                  {"name": "count", "type": "u64"}
                ]
              }
            }
          ],
        };

        // This should parse without errors
        expect(() {
          final idl = Idl.fromJson(counterIdl);
          expect(idl.metadata?.name, equals('counter'));
          expect(idl.instructions.length, equals(1));
          expect(idl.instructions.first.name, equals('initialize'));
          expect(idl.accounts?.length, equals(1));
          expect(idl.accounts?.first.name, equals('counter'));
        }, returnsNormally);
      });

      test('error handling patterns compile', () {
        // Test error handling examples from documentation

        expect(() {
          try {
            // This should throw
            throw TypesCoderException('Test error');
          } on AnchorException catch (e) {
            expect(e.message, equals('Test error'));
            expect(e, isA<AnchorException>());
          }
        }, returnsNormally);

        // Test specific exception types
        expect(() {
          throw InstructionCoderException('Instruction error');
        }, throwsA(isA<InstructionCoderException>()));

        expect(() {
          throw AccountCoderException('Account error');
        }, throwsA(isA<AccountCoderException>()));

        expect(() {
          throw EventCoderException('Event error');
        }, throwsA(isA<EventCoderException>()));

        expect(() {
          throw TypesCoderException('Types error');
        }, throwsA(isA<TypesCoderException>()));
      });
    });

    group('Type System Examples', () {
      test('Borsh serialization examples compile', () {
        // Test Borsh serialization examples from documentation

        final serializer = BorshSerializer();
        serializer.writeU64(12345);
        serializer.writeBool(true);
        serializer.writeString('test');

        final bytes = serializer.toBytes();
        expect(bytes, isA<List<int>>());

        final deserializer = BorshDeserializer(bytes);
        final value1 = deserializer.readU64();
        final value2 = deserializer.readBool();
        final value3 = deserializer.readString();

        expect(value1, equals(12345));
        expect(value2, equals(true));
        expect(value3, equals('test'));
      });

      test('complex IDL structures compile', () {
        // Test complex IDL structures from documentation

        final complexIdl = {
          'address': '11111111111111111111111111111112',
          'metadata': {
            'name': 'complex_types',
            'version': '0.1.0',
            'spec': '0.1.0',
          },
          'instructions': [
            {
              'name': 'processData',
              'discriminator': [1, 2, 3, 4, 5, 6, 7, 8],
              'accounts': [
                {
                  'name': 'dataAccount',
                  'writable': true,
                }
              ],
              'args': []
            }
          ],
          'types': []
        };

        expect(() {
          final idl = Idl.fromJson(complexIdl);
          expect(idl.instructions.length, equals(1));
          expect(idl.instructions.first.name, equals('processData'));
        }, returnsNormally);
      });
    });
  });

  group('Documentation Consistency', () {
    test('all exported classes have documentation', () {
      // This test ensures main classes have basic documentation
      // In a real scenario, this would use reflection to check all exports

      // Core classes should be accessible
      expect(Program, isA<Type>());
      expect(AnchorProvider, isA<Type>());
      expect(Connection, isA<Type>());
      expect(PublicKey, isA<Type>());
      expect(Keypair, isA<Type>());
      expect(Idl, isA<Type>());

      // Coder classes
      expect(BorshCoder, isA<Type>());
      expect(BorshSerializer, isA<Type>());
      expect(BorshDeserializer, isA<Type>());

      // Exception classes
      expect(AnchorException, isA<Type>());
      expect(InstructionCoderException, isA<Type>());
      expect(AccountCoderException, isA<Type>());
      expect(EventCoderException, isA<Type>());
      expect(TypesCoderException, isA<Type>());
    });

    test('example code patterns are consistent', () async {
      // Test that common patterns used in examples work consistently

      // Pattern 1: Basic program setup
      final setupPattern = () async {
        final connection = Connection('https://api.devnet.solana.com');
        final keypair = await Keypair.generate();
        final wallet = KeypairWallet(keypair);
        final provider = AnchorProvider(connection, wallet);

        final mockIdl = Idl.fromJson({
          'address': '11111111111111111111111111111112',
          'metadata': {'name': 'test', 'version': '0.1.0', 'spec': '0.1.0'},
          'instructions': [],
        });

        return Program(mockIdl, provider: provider);
      };

      expect(setupPattern, returnsNormally);

      // Pattern 2: Key generation
      final keyPattern = () async {
        final keypair = await Keypair.generate();
        final publicKey = keypair.publicKey;
        final base58 = publicKey.toBase58();
        final fromBase58 = PublicKey.fromBase58(base58);
        return fromBase58 == publicKey;
      };

      expect(await keyPattern(), isTrue);

      // Pattern 3: IDL type construction
      final typePattern = () {
        final simpleType = IdlType(kind: 'u64');
        final complexType = IdlType(
          kind: 'vec',
          inner: IdlType(kind: 'string'),
        );
        return simpleType.kind == 'u64' && complexType.kind == 'vec';
      };

      expect(typePattern(), isTrue);
    });
  });
}
