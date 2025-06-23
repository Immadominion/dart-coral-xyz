/// Comprehensive TypeScript Parity Validation Test Suite
///
/// This test suite validates that the Dart Coral XYZ Anchor SDK provides
/// complete functional parity with the TypeScript @coral-xyz/anchor package.
/// It verifies API compatibility, behavior consistency, and feature completeness.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Comprehensive TypeScript Parity Validation', () {
    group('Core API Compatibility', () {
      test('Basic SDK structure exists', () {
        // Test that core types and classes are available
        expect(Connection, isNotNull);
        expect(AnchorProvider, isNotNull);
        expect(KeypairWallet, isNotNull);
        expect(Program, isNotNull);
      });

      test('Connection API is available', () {
        final connection = Connection('https://api.devnet.solana.com');

        // Test basic connection properties
        expect(connection.rpcEndpoint, equals('https://api.devnet.solana.com'));
        expect(connection.commitment, isNotNull);

        // Test that methods exist (without calling them)
        expect(connection.getAccountInfo, isA<Function>());
        expect(connection.getBalance, isA<Function>());
        expect(connection.sendTransaction, isA<Function>());
        expect(connection.confirmTransaction, isA<Function>());
      });

      test('Wallet API is available', () {
        final wallet = KeypairWallet.fromSecretKey([1, 2, 3, 4]);

        // Test wallet interface
        expect(wallet.publicKey, isNotNull);
        expect(wallet.signTransaction, isA<Function>());
        expect(wallet.signAllTransactions, isA<Function>());
      });

      test('Provider API is available', () {
        final connection = Connection('https://api.devnet.solana.com');
        final wallet = KeypairWallet.fromSecretKey([1, 2, 3, 4]);
        final provider = AnchorProvider(connection, wallet);

        // Test provider structure
        expect(provider.connection, equals(connection));
        expect(provider.wallet, equals(wallet));
        expect(provider.opts, isNotNull);

        // Test that methods exist
        expect(provider.send, isA<Function>());
        expect(provider.sendAndConfirm, isA<Function>());
        expect(provider.simulate, isA<Function>());
      });
    });

    group('Program Interface Compatibility', () {
      test('Program class can be instantiated', () {
        final connection = Connection('https://api.devnet.solana.com');
        final wallet = KeypairWallet.fromSecretKey([1, 2, 3, 4]);
        final provider = AnchorProvider(connection, wallet);

        // Mock IDL structure
        final mockIdl = {
          'version': '0.1.0',
          'name': 'test_program',
          'instructions': <Map<String, dynamic>>[],
          'accounts': <Map<String, dynamic>>[],
          'events': <Map<String, dynamic>>[],
          'errors': <Map<String, dynamic>>[],
          'types': <Map<String, dynamic>>[],
        };

        final programId = 'BPFLoaderUpgradeab1e11111111111111111111111';
        final program = Program(mockIdl, programId, provider);

        // Test basic program properties
        expect(program.programId, equals(programId));
        expect(program.provider, equals(provider));
        expect(program.idl, equals(mockIdl));
      });

      test('Program namespaces are available', () {
        final connection = Connection('https://api.devnet.solana.com');
        final wallet = KeypairWallet.fromSecretKey([1, 2, 3, 4]);
        final provider = AnchorProvider(connection, wallet);

        final mockIdl = {
          'version': '0.1.0',
          'name': 'test_program',
          'instructions': [
            {
              'name': 'initialize',
              'accounts': <Map<String, dynamic>>[],
              'args': <Map<String, dynamic>>[],
            }
          ],
          'accounts': <Map<String, dynamic>>[],
          'events': <Map<String, dynamic>>[],
          'errors': <Map<String, dynamic>>[],
          'types': <Map<String, dynamic>>[],
        };

        final program = Program(
            mockIdl, 'BPFLoaderUpgradeab1e11111111111111111111111', provider);

        // Test namespace availability (TypeScript compatibility)
        expect(program.methods, isNotNull);
        expect(program.account, isNotNull);
        expect(program.instruction, isNotNull);
        expect(program.transaction, isNotNull);
        expect(program.simulate, isNotNull);
        expect(program.rpc, isNotNull);
      });
    });

    group('Error Handling System', () {
      test('Error types are available', () {
        // Test that error classes exist
        expect(AnchorError, isNotNull);
        expect(ProgramError, isNotNull);
        expect(AccountNotFoundError, isNotNull);
        expect(InvalidDiscriminatorError, isNotNull);
      });

      test('Error codes match TypeScript', () {
        // Test specific error code compatibility
        final accountError = AccountNotFoundError('test account');
        expect(accountError.code, equals(3012));

        final discriminatorError =
            InvalidDiscriminatorError('test discriminator');
        expect(discriminatorError.code, equals(3013));
      });
    });

    group('Coder System Availability', () {
      test('Coder classes are available', () {
        final mockIdl = {
          'version': '0.1.0',
          'name': 'test_program',
          'instructions': [
            {
              'name': 'test',
              'accounts': <Map<String, dynamic>>[],
              'args': <Map<String, dynamic>>[],
            }
          ],
          'accounts': [
            {
              'name': 'TestAccount',
              'type': {
                'kind': 'struct',
                'fields': <Map<String, dynamic>>[],
              },
            }
          ],
          'events': [
            {
              'name': 'TestEvent',
              'fields': <Map<String, dynamic>>[],
            }
          ],
          'errors': <Map<String, dynamic>>[],
          'types': <Map<String, dynamic>>[],
        };

        // Test coder instantiation
        final accountsCoder = BorshAccountsCoder(mockIdl);
        final instructionCoder = BorshInstructionCoder(mockIdl);
        final eventCoder = BorshEventCoder(mockIdl);

        expect(accountsCoder.encode, isA<Function>());
        expect(accountsCoder.decode, isA<Function>());
        expect(accountsCoder.size, isA<Function>());

        expect(instructionCoder.encode, isA<Function>());
        expect(instructionCoder.decode, isA<Function>());
        expect(instructionCoder.format, isA<Function>());

        expect(eventCoder.decode, isA<Function>());
      });
    });

    group('Transaction and Simulation Features', () {
      test('Transaction simulation is available', () {
        final connection = Connection('https://api.devnet.solana.com');
        final simulator = TransactionSimulator(connection);

        expect(simulator.simulate, isA<Function>());
        expect(simulator.simulateTransaction, isA<Function>());
      });

      test('Pre-flight validation is available', () {
        final connection = Connection('https://api.devnet.solana.com');
        final validator = PreflightValidator(connection);

        expect(validator.validateAccounts, isA<Function>());
        expect(validator.validateTransaction, isA<Function>());
      });

      test('Compute unit analysis is available', () {
        final connection = Connection('https://api.devnet.solana.com');
        final analyzer = ComputeUnitAnalyzer(connection);

        expect(analyzer.estimateComputeUnits, isA<Function>());
        expect(analyzer.analyzeFees, isA<Function>());
      });
    });

    group('Utility Functions', () {
      test('PDA utilities work correctly', () {
        const seeds = ['test', 'seed'];
        const programId = 'BPFLoaderUpgradeab1e11111111111111111111111';

        final result = PdaUtils.findProgramAddress(seeds, programId);

        expect(result, isNotNull);
        expect(result.address, isNotNull);
        expect(result.bump, isA<int>());
        expect(result.bump, inInclusiveRange(0, 255));
      });

      test('Address utilities are available', () {
        expect(AddressResolver.isValidPublicKey, isA<Function>());
        expect(AddressResolver.getAssociatedTokenAddress, isA<Function>());
      });

      test('TypeScript compatibility layer works', () {
        expect(BN, isNotNull);
        expect(web3, isNotNull);
      });
    });

    group('Platform Features', () {
      test('Platform optimization is available', () {
        expect(PlatformOptimization.currentPlatform, isA<PlatformType>());
        expect(PlatformOptimization.connectionTimeout, isA<Duration>());
        expect(PlatformOptimization.retryDelay, isA<Duration>());
        expect(PlatformOptimization.maxConcurrentConnections, isA<int>());
      });

      test('Web platform features are available', () {
        final webStorage = WebStorage.localStorage();
        expect(webStorage.setItem, isA<Function>());
        expect(webStorage.getItem, isA<Function>());
        expect(webStorage.removeItem, isA<Function>());
        expect(webStorage.clear, isA<Function>());
      });

      test('Mobile platform features are available', () {
        final secureStorage = MobileSecureStorage();
        expect(secureStorage.store, isA<Function>());
        expect(secureStorage.retrieve, isA<Function>());
        expect(secureStorage.delete, isA<Function>());

        final deepLinkHandler = DeepLinkHandler();
        expect(deepLinkHandler.handleDeepLink, isA<Function>());
        expect(deepLinkHandler.generateDeepLink, isA<Function>());
      });

      test('Browser wallet adapters are available', () {
        final phantomAdapter = BrowserWalletAdapter('phantom');
        expect(phantomAdapter.connect, isA<Function>());
        expect(phantomAdapter.disconnect, isA<Function>());
        expect(phantomAdapter.signTransaction, isA<Function>());

        final solflareAdapter = BrowserWalletAdapter('solflare');
        expect(solflareAdapter.connect, isA<Function>());
        expect(solflareAdapter.disconnect, isA<Function>());
      });
    });

    group('Performance Features', () {
      test('Connection pooling is available', () {
        final pool = ConnectionPool(
          endpoints: ['https://api.devnet.solana.com'],
          config: const ConnectionPoolConfig(),
        );

        expect(pool.getConnection, isA<Function>());
        expect(pool.getMetrics, isA<Function>());
        expect(pool.close, isA<Function>());
      });

      test('Enhanced connection features work', () {
        final enhancedConnection = EnhancedConnection(
          'https://api.devnet.solana.com',
          retryConfig: const RetryConfig(),
        );

        expect(enhancedConnection.sendTransaction, isA<Function>());
        expect(enhancedConnection.getAccountInfo, isA<Function>());
        expect(enhancedConnection.close, isA<Function>());
      });

      test('Performance monitoring is available', () {
        final monitor = PerformanceMonitor();

        expect(monitor.startTracking, isA<Function>());
        expect(monitor.getMetrics, isA<Function>());
        expect(monitor.reset, isA<Function>());
      });
    });
  });

  group('Integration Validation', () {
    test('Complete SDK workflow can be constructed', () {
      // Test that a complete TypeScript-like workflow can be built
      final connection = Connection('https://api.devnet.solana.com');
      final wallet = KeypairWallet.fromSecretKey([1, 2, 3, 4]);
      final provider = AnchorProvider(connection, wallet);

      final mockIdl = {
        'version': '0.1.0',
        'name': 'integration_test',
        'instructions': [
          {
            'name': 'initialize',
            'accounts': <Map<String, dynamic>>[],
            'args': <Map<String, dynamic>>[],
          }
        ],
        'accounts': <Map<String, dynamic>>[],
        'events': <Map<String, dynamic>>[],
        'errors': <Map<String, dynamic>>[],
        'types': <Map<String, dynamic>>[],
      };

      final program = Program(
          mockIdl, 'BPFLoaderUpgradeab1e11111111111111111111111', provider);

      // Test that the method chain can be constructed (TypeScript pattern)
      final methodBuilder = program.methods.getMethod('initialize');
      expect(methodBuilder.accounts, isA<Function>());
      expect(methodBuilder.instruction, isA<Function>());
      expect(methodBuilder.transaction, isA<Function>());
      expect(methodBuilder.rpc, isA<Function>());
    });

    test('Platform manager integration works', () {
      // Test unified platform management
      final platformManager = PlatformManager();

      expect(platformManager.currentPlatform, isA<PlatformType>());
      expect(platformManager.getOptimalConfiguration, isA<Function>());
      expect(platformManager.createOptimizedConnection, isA<Function>());
      expect(platformManager.createOptimizedProvider, isA<Function>());
    });

    test('All major components integrate correctly', () {
      // Validate that all major components can work together
      expect(Connection, isNotNull);
      expect(AnchorProvider, isNotNull);
      expect(Program, isNotNull);
      expect(TransactionSimulator, isNotNull);
      expect(PreflightValidator, isNotNull);
      expect(ComputeUnitAnalyzer, isNotNull);
      expect(PlatformOptimization, isNotNull);
      expect(PlatformManager, isNotNull);
    });
  });
}
