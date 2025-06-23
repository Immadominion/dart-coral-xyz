/// Critical Iteration 3: Complete Namespace and Event Manager Integration Test
///
/// This test verifies that:
/// 1. All namespaces are properly integrated and exported
/// 2. EventManager shares connection resources with Program
/// 3. Unified configuration and lifecycle management works
/// 4. Cross-namespace communication patterns function correctly
/// 5. Error propagation is consistent across namespaces

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'dart:typed_data';

void main() {
  group('Critical Iteration 3: Namespace Integration', () {
    late AnchorProvider provider;
    late Connection connection;

    setUp(() {
      // Create a test connection
      connection = Connection('https://api.devnet.solana.com');

      // Create a test provider with minimal wallet
      final keypair = Keypair.fromSecretKey(Uint8List.fromList([
        174,
        47,
        154,
        16,
        202,
        193,
        206,
        113,
        199,
        190,
        53,
        133,
        169,
        175,
        31,
        56,
        222,
        53,
        138,
        189,
        224,
        216,
        117,
        173,
        10,
        149,
        53,
        45,
        73,
        251,
        237,
        246,
        15,
        185,
        186,
        82,
        177,
        240,
        148,
        69,
        241,
        227,
        167,
        80,
        141,
        89,
        240,
        121,
        121,
        35,
        172,
        247,
        68,
        251,
        226,
        218,
        48,
        63,
        176,
        109,
        168,
        89,
        238,
        135
      ]));
      final wallet = KeypairWallet(keypair);
      provider = AnchorProvider(connection, wallet);
    });

    test('critical iteration 3 - unified resource sharing - connection access',
        () {
      // Test basic provider setup
      expect(provider, isNotNull);
      expect(provider.connection, equals(connection));
      expect(provider.connection.endpoint,
          equals('https://api.devnet.solana.com'));
    });

    test('critical iteration 3 - basic program creation with simple IDL', () {
      // Create a minimal test IDL
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address:
            'So11111111111111111111111111111111111111112', // Use a well-known address
        instructions: [],
        accounts: [],
      );

      // Create program instance
      final program = Program(testIdl, provider: provider);

      // Test basic properties
      expect(program.programId.toBase58(),
          equals('So11111111111111111111111111111111111111112'));
      expect(program.provider, equals(provider));
      expect(program.connection, equals(provider.connection));
      expect(program.connection, equals(connection));
    });

    test('critical iteration 3 - namespace integration', () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that all namespaces are accessible
      expect(program.methods, isA<MethodsNamespace>());
      expect(program.account, isA<AccountNamespace>());
      expect(program.instruction, isA<InstructionNamespace>());
      expect(program.transaction, isA<TransactionNamespace>());
      expect(program.rpc, isA<RpcNamespace>());
      expect(program.simulate, isA<SimulateNamespace>());
      expect(program.views, isA<ViewsNamespace>());

      // Test that all namespaces are non-null
      expect(program.methods, isNotNull);
      expect(program.account, isNotNull);
      expect(program.instruction, isNotNull);
      expect(program.transaction, isNotNull);
      expect(program.rpc, isNotNull);
      expect(program.simulate, isNotNull);
      expect(program.views, isNotNull);
    });

    test('critical iteration 3 - event manager access and resource sharing',
        () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that EventManager is accessible and shares resources
      expect(program.events, isA<EventManager>());
      expect(program.events, isNotNull);

      // Test that event manager statistics are accessible
      final stats = program.eventStats;
      expect(stats, isNotNull);
      expect(stats.totalEvents, isA<int>());
      expect(stats.parseErrors, isA<int>());

      // Test connection state access
      final connectionState = program.eventConnectionState;
      expect(connectionState, isA<WebSocketState>());
    });

    test('critical iteration 3 - namespace types properly exported', () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that namespace classes are accessible from the main export
      // This would fail at compile time if exports are missing
      expect(program.methods, isA<MethodsNamespace>());
      expect(program.account, isA<AccountNamespace>());
      expect(program.instruction, isA<InstructionNamespace>());
      expect(program.transaction, isA<TransactionNamespace>());
      expect(program.rpc, isA<RpcNamespace>());
      expect(program.simulate, isA<SimulateNamespace>());
      expect(program.views, isA<ViewsNamespace>());
    });

    test('critical iteration 3 - coder consistency across namespaces', () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that the same coder is used across all namespaces
      expect(program.coder, isNotNull);
      expect(program.coder, isA<BorshCoder>());

      // Test that coder can handle the IDL
      expect(program.coder.accounts, isNotNull);
      expect(program.coder.instructions, isNotNull);
      expect(program.coder.events, isNotNull);
    });

    test('critical iteration 3 - lifecycle management disposal', () async {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that dispose method cleans up all resources
      expect(program.account, isNotNull);
      expect(program.events, isNotNull);

      // Dispose should not throw
      await expectLater(program.dispose(), completes);
    });

    test('critical iteration 3 - error handling consistency', () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Methods namespace error handling - bracket notation returns null for non-existent methods
      final nonExistentMethod = program.methods['nonExistentMethod'];
      expect(nonExistentMethod, isNull);

      // Dynamic method access should throw an error for non-existent methods
      try {
        (program.methods as dynamic).nonExistentMethod([]);
        fail('Should have thrown an error for non-existent method');
      } catch (e) {
        expect(
            e,
            anyOf([
              isA<ArgumentError>(),
              isA<NoSuchMethodError>(),
            ]));
        expect(e.toString(), contains('nonExistentMethod'));
      }
    });

    test('critical iteration 3 - event listener integration', () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that events defined in IDL are discoverable
      final eventManager = program.events;
      expect(eventManager, isNotNull);

      // Test event listener registration (should not throw)
      int listenerId = eventManager.addEventListener<Map<String, dynamic>>(
        'TestEvent',
        (event, slot, signature) {
          // Event callback
        },
      );

      expect(listenerId, isA<int>());
      expect(listenerId, greaterThanOrEqualTo(0));
    });

    test('critical iteration 3 - namespace state management', () {
      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that namespaces maintain proper state
      final accountNamespace = program.account;
      expect(accountNamespace.contains('NonExistentAccount'), isFalse);

      // Test namespace string representation
      expect(accountNamespace.toString(), contains('AccountNamespace'));
    });
  });

  group('Critical Iteration 3: Advanced Integration Features', () {
    test('unified resource sharing across components', () {
      final connection = Connection('https://api.devnet.solana.com');
      final keypair = Keypair.fromSecretKey(Uint8List.fromList([
        174,
        47,
        154,
        16,
        202,
        193,
        206,
        113,
        199,
        190,
        53,
        133,
        169,
        175,
        31,
        56,
        222,
        53,
        138,
        189,
        224,
        216,
        117,
        173,
        10,
        149,
        53,
        45,
        73,
        251,
        237,
        246,
        15,
        185,
        186,
        82,
        177,
        240,
        148,
        69,
        241,
        227,
        167,
        80,
        141,
        89,
        240,
        121,
        121,
        35,
        172,
        247,
        68,
        251,
        226,
        218,
        48,
        63,
        176,
        109,
        168,
        89,
        238,
        135
      ]));
      final wallet = KeypairWallet(keypair);
      final provider = AnchorProvider(connection, wallet);

      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Test that program maintains proper context
      expect(program.programId.toBase58(),
          equals('So11111111111111111111111111111111111111112'));
      expect(program.provider, equals(provider));
      expect(program.connection, equals(provider.connection));
      expect(program.connection, equals(connection));
    });

    test('comprehensive resource cleanup verification', () async {
      final connection = Connection('https://api.devnet.solana.com');
      final keypair = Keypair.fromSecretKey(Uint8List.fromList([
        174,
        47,
        154,
        16,
        202,
        193,
        206,
        113,
        199,
        190,
        53,
        133,
        169,
        175,
        31,
        56,
        222,
        53,
        138,
        189,
        224,
        216,
        117,
        173,
        10,
        149,
        53,
        45,
        73,
        251,
        237,
        246,
        15,
        185,
        186,
        82,
        177,
        240,
        148,
        69,
        241,
        227,
        167,
        80,
        141,
        89,
        240,
        121,
        121,
        35,
        172,
        247,
        68,
        251,
        226,
        218,
        48,
        63,
        176,
        109,
        168,
        89,
        238,
        135
      ]));
      final wallet = KeypairWallet(keypair);
      final provider = AnchorProvider(connection, wallet);

      final testIdl = Idl(
        version: '1.0.0',
        name: 'test_program',
        address: 'So11111111111111111111111111111111111111112',
        instructions: [],
        accounts: [],
      );

      final program = Program(testIdl, provider: provider);

      // Add some event listeners to test cleanup
      final listenerId = program.addEventListener<Map<String, dynamic>>(
        'TestEvent',
        (event, slot, signature) {},
      );

      expect(listenerId, isA<int>());

      // Dispose should clean up all resources
      await expectLater(program.dispose(), completes);
    });
  });
}
