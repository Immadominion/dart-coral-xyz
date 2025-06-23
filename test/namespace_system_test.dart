import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/program/type_safe_method_builder.dart';

void main() {
  group('Namespace Generation System Tests', () {
    late Idl testIdl;
    late Program program;

    setUp(() {
      // Create a simple test IDL
      testIdl = const Idl(
        address: '11111111111111111111111111111111',
        metadata: IdlMetadata(
          name: 'test_program',
          version: '0.1.0',
          spec: '0.1.0',
        ),
        instructions: [
          IdlInstruction(
            name: 'initialize',
            discriminator: [175, 175, 109, 31, 13, 152, 155, 237],
            accounts: [
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'data',
                writable: true, // Changed from isMut
                signer: true, // Changed from isSigner
              ),
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'user',
                writable: false, // Changed from isMut
                signer: true, // Changed from isSigner
              ),
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'system_program',
                writable: false, // Changed from isMut
                signer: false, // Changed from isSigner
              ),
            ],
            args: [
              IdlField(
                name: 'value',
                type: IdlType(kind: 'u64'),
              ),
            ],
          ),
          IdlInstruction(
            name: 'update',
            discriminator: [219, 200, 88, 176, 158, 63, 253, 127],
            accounts: [
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'data',
                writable: true, // Changed from isMut
                signer: false, // Changed from isSigner
              ),
              IdlInstructionAccount(
                // Changed from IdlInstructionAccountItem
                name: 'user',
                writable: false, // Changed from isMut
                signer: true, // Changed from isSigner
              ),
            ],
            args: [
              IdlField(
                name: 'new_value',
                type: IdlType(kind: 'u64'),
              ),
            ],
          ),
        ],
        accounts: [
          IdlAccount(
            name: 'TestAccount',
            discriminator: [123, 153, 151, 118, 126, 71, 73, 92],
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'value',
                  type: IdlType(kind: 'u64'),
                ),
                IdlField(
                  name: 'authority',
                  type: IdlType(kind: 'pubkey'),
                ),
              ],
            ),
          ),
        ],
        types: [
          IdlTypeDef(
            name: 'TestAccount',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'value',
                  type: IdlType(kind: 'u64'),
                ),
                IdlField(
                  name: 'authority',
                  type: IdlType(kind: 'pubkey'),
                ),
              ],
            ),
          ),
          IdlTypeDef(
            name: 'TestEvent',
            type: IdlTypeDefType(
              kind: 'struct',
              fields: [
                IdlField(
                  name: 'data',
                  type: IdlType(kind: 'u64'),
                ),
              ],
            ),
          ),
        ],
        events: [
          IdlEvent(
            name: 'TestEvent',
            discriminator: [82, 21, 49, 86, 87, 54, 132, 103],
            fields: [
              IdlField(
                name: 'data',
                type: IdlType(kind: 'u64'),
              ),
            ],
          ),
        ],
      );

      // Create program instance
      program = Program(testIdl);
    });

    test('should create all namespaces correctly', () {
      expect(program.instruction, isA<InstructionNamespace>());
      expect(program.transaction, isA<TransactionNamespace>());
      expect(program.rpc, isA<RpcNamespace>());
      expect(program.account, isA<AccountNamespace>());
      expect(program.simulate, isA<SimulateNamespace>());
      expect(program.methods, isA<MethodsNamespace>());
    });

    test('instruction namespace should contain all instructions', () {
      expect(program.instruction.contains('initialize'), isTrue);
      expect(program.instruction.contains('update'), isTrue);
      expect(program.instruction.contains('nonexistent'), isFalse);

      expect(program.instruction.names.length, equals(2));
      expect(program.instruction.names, containsAll(['initialize', 'update']));
    });

    test('transaction namespace should contain all instructions', () {
      expect(program.transaction.contains('initialize'), isTrue);
      expect(program.transaction.contains('update'), isTrue);
      expect(program.transaction.contains('nonexistent'), isFalse);

      expect(program.transaction.names.length, equals(2));
      expect(program.transaction.names, containsAll(['initialize', 'update']));
    });

    test('rpc namespace should contain all instructions', () {
      expect(program.rpc.contains('initialize'), isTrue);
      expect(program.rpc.contains('update'), isTrue);
      expect(program.rpc.contains('nonexistent'), isFalse);

      expect(program.rpc.names.length, equals(2));
      expect(program.rpc.names, containsAll(['initialize', 'update']));
    });

    test('account namespace should contain all accounts', () {
      expect(program.account.contains('TestAccount'), isTrue);
      expect(program.account.contains('NonexistentAccount'), isFalse);

      expect(program.account.names.length, equals(1));
      expect(program.account.names, contains('TestAccount'));
    });

    test('simulate namespace should contain all instructions', () {
      expect(program.simulate.contains('initialize'), isTrue);
      expect(program.simulate.contains('update'), isTrue);
      expect(program.simulate.contains('nonexistent'), isFalse);

      expect(program.simulate.names.length, equals(2));
      expect(program.simulate.names, containsAll(['initialize', 'update']));
    });

    test('methods namespace should contain all instructions', () {
      expect(program.methods.contains('initialize'), isTrue);
      expect(program.methods.contains('update'), isTrue);
      expect(program.methods.contains('nonexistent'), isFalse);

      expect(program.methods.names.length, equals(2));
      expect(program.methods.names, containsAll(['initialize', 'update']));
    });

    test('should access individual namespace builders', () {
      final initializeBuilder = program.instruction['initialize'];
      expect(initializeBuilder, isNotNull);
      expect(initializeBuilder!.name, equals('initialize'));

      final updateBuilder = program.transaction['update'];
      expect(updateBuilder, isNotNull);
      expect(updateBuilder!.name, equals('update'));

      final rpcFunction = program.rpc['initialize'];
      expect(rpcFunction, isNotNull);
      expect(rpcFunction!.name, equals('initialize'));
    });

    test('account client should provide account operations', () {
      final accountClient = program.account['TestAccount'];
      expect(accountClient, isNotNull);
      expect(accountClient!.name, equals('TestAccount'));

      // Test account client properties
      expect(accountClient.size, isA<int>());
      expect(accountClient.discriminator, isA<List<int>>());
    });

    test('methods builder should support fluent interface', () {
      final methodsBuilder = program.methods['initialize'];
      expect(methodsBuilder, isNotNull);
      expect(methodsBuilder!.name, equals('initialize'));

      // Test fluent interface (just that methods return the builder)
      final builder = methodsBuilder.call([42]) // Initialize with value 42
          .accounts({
        'data': program.programId,
        'user': program.programId,
        'system_program': program.programId,
      }).signers([]);

      expect(builder, isA<TypeSafeMethodBuilder>());
      expect(builder.name, equals('initialize'));
    });

    test('namespace toString methods should work', () {
      expect(program.instruction.toString(), contains('InstructionNamespace'));
      expect(program.transaction.toString(), contains('TransactionNamespace'));
      expect(program.rpc.toString(), contains('RpcNamespace'));
      expect(program.account.toString(), contains('AccountNamespace'));
      expect(program.simulate.toString(), contains('SimulateNamespace'));
      expect(program.methods.toString(), contains('MethodsNamespace'));
    });
  });
}
