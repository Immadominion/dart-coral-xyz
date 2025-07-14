import 'dart:convert';

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/src/transaction/simulation_result_processor.dart';
import 'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart';

void main() {
  group('SimulationResultProcessor Tests', () {
    late SimulationResultProcessor processor;

    setUp(() {
      processor = SimulationResultProcessor();
    });

    group('Basic Result Processing', () {
      test('should process successful simulation result', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: [
            'Program log: Hello World',
            'Program data: SGVsbG8gV29ybGQ=', // "Hello World" in base64
            'Program invoke [1]',
            'Program 11111111111111111111111111111112 success',
          ],
          unitsConsumed: 150000,
        );

        final result = await processor.processResult(simulationResult);

        expect(result.isSuccess, true);
        expect(result.eventCount, greaterThan(0));
        expect(result.originalResult, equals(simulationResult));
        expect(result.processingTime.inMicroseconds, greaterThan(0));
      });

      test('should process failed simulation result', () async {
        final simulationResult = const TransactionSimulationResult(
          success: false,
          logs: [
            'Program log: Processing instruction',
            'Program log: Error: Insufficient funds',
            'Program failed to complete',
          ],
          error: TransactionSimulationError(
            type: 'InstructionError',
            instructionIndex: 0,
            customErrorCode: 3001,
          ),
          unitsConsumed: 50000,
        );

        final result = await processor.processResult(simulationResult);

        expect(result.isSuccess, false);
        expect(result.errorAnalysis.hasErrors, true);
        expect(result.errorAnalysis.errorType, equals('InstructionError'));
        expect(result.errorAnalysis.instructionIndex, equals(0));
        expect(result.errorAnalysis.suggestions, isNotEmpty);
      });
    });

    group('Event Extraction', () {
      test('should extract program log events', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: [
            'Program log: Initialize account',
            'Program log: Transfer 1000 lamports',
            'Program log: Account created successfully',
          ],
        );

        final result = await processor.processResult(simulationResult);

        expect(result.events.length, equals(3));

        final textEvents = result.getEventsByType(EventType.text);
        expect(textEvents.length, equals(3));
        expect(textEvents[0].textData, equals('Initialize account'));
        expect(textEvents[1].textData, equals('Transfer 1000 lamports'));
        expect(textEvents[2].textData, equals('Account created successfully'));
      });

      test('should extract program data events', () async {
        final testData = 'Hello World';
        final encodedData = base64.encode(utf8.encode(testData));

        final simulationResult = TransactionSimulationResult(
          success: true,
          logs: [
            'Program data: $encodedData',
            'Program data: invalid-base64-data',
          ],
        );

        final result = await processor.processResult(simulationResult);

        expect(result.events.length, equals(2));

        final structuredEvents = result.getEventsByType(EventType.structured);
        expect(structuredEvents.length, equals(1));
        expect(structuredEvents[0].decodedData, isNotNull);
        expect(utf8.decode(structuredEvents[0].decodedData!), equals(testData));

        final textEvents = result.getEventsByType(EventType.text);
        expect(textEvents.length, equals(1));
        expect(textEvents[0].textData, equals('invalid-base64-data'));
      });

      test('should extract CPI events', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: [
            'Program 11111111111111111111111111111112 invoke [1]',
            'Program log: Transfer initiated',
            'Program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA invoke [2]',
            'Program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA success',
            'Program 11111111111111111111111111111112 success',
          ],
        );

        final result = await processor.processResult(simulationResult);

        final cpiEvents = result.getCpiEvents();
        expect(cpiEvents.length, equals(4));

        // Check invoke events
        final invokeEvents = result.getEventsByType(EventType.cpiInvoke);
        expect(invokeEvents.length, equals(2));
        expect(invokeEvents[0].cpiInfo!.programId,
            equals('11111111111111111111111111111112'),);
        expect(invokeEvents[0].cpiInfo!.depth, equals(1));
        expect(invokeEvents[1].cpiInfo!.programId,
            equals('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),);
        expect(invokeEvents[1].cpiInfo!.depth, equals(2));

        // Check success events
        final resultEvents = result.getEventsByType(EventType.cpiResult);
        expect(resultEvents.length, equals(2));
        expect(resultEvents[0].cpiInfo!.status, equals(CpiStatus.success));
        expect(resultEvents[1].cpiInfo!.status, equals(CpiStatus.success));
      });
    });

    group('Account Change Analysis', () {
      test('should analyze account changes', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Account updated'],
          accounts: {
            '11111111111111111111111111111112': {
              'lamports': 1000000,
              'owner': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
              'executable': false,
              'rentEpoch': 361,
              'data': [1, 2, 3, 4, 5],
            },
            'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA': {
              'lamports': 2000000,
              'owner': '11111111111111111111111111111111',
              'executable': true,
              'rentEpoch': 361,
              'data': [],
            },
          },
        );

        final result = await processor.processResult(simulationResult);

        expect(result.accountChanges.hasChanges, true);
        expect(result.accountChanges.changedAccounts.length, equals(2));
        expect(result.accountChanges.totalAccounts, equals(2));

        final firstAccount = result.accountChanges.changedAccounts[0];
        expect(firstAccount.lamports, equals(1000000));
        expect(firstAccount.executable, false);
        expect(firstAccount.dataLength, equals(5));

        final secondAccount = result.accountChanges.changedAccounts[1];
        expect(secondAccount.lamports, equals(2000000));
        expect(secondAccount.executable, true);
        expect(secondAccount.dataLength, equals(0));
      });

      test('should handle no account changes', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Read-only operation'],
        );

        final result = await processor.processResult(simulationResult);

        expect(result.accountChanges.hasChanges, false);
        expect(result.accountChanges.changedAccounts.isEmpty, true);
        expect(result.accountChanges.totalAccounts, equals(0));
      });
    });

    group('Return Data Analysis', () {
      test('should process return data', () async {
        final returnData = 'Hello World';
        final encodedData = base64.encode(utf8.encode(returnData));

        final simulationResult = TransactionSimulationResult(
          success: true,
          logs: ['Program log: Returning data'],
          returnData: TransactionReturnData(
            programId: '11111111111111111111111111111112',
            data: encodedData,
          ),
        );

        final result = await processor.processResult(simulationResult);

        expect(result.returnDataAnalysis.hasReturnData, true);
        expect(result.returnDataAnalysis.programId,
            equals('11111111111111111111111111111112'),);
        expect(result.returnDataAnalysis.rawData, equals(encodedData));
        expect(result.returnDataAnalysis.decodedData, isNotNull);
        expect(utf8.decode(result.returnDataAnalysis.decodedData!),
            equals(returnData),);
        expect(
            result.returnDataAnalysis.dataLength, equals(encodedData.length),);
        expect(result.returnDataAnalysis.analysis,
            contains('Return Data Analysis'),);
      });

      test('should handle non-base64 return data', () async {
        final returnData = 'plain text data';

        final simulationResult = TransactionSimulationResult(
          success: true,
          logs: ['Program log: Returning plain text'],
          returnData: TransactionReturnData(
            programId: '11111111111111111111111111111112',
            data: returnData,
          ),
        );

        final result = await processor.processResult(simulationResult);

        expect(result.returnDataAnalysis.hasReturnData, true);
        expect(result.returnDataAnalysis.rawData, equals(returnData));
        expect(result.returnDataAnalysis.decodedData, isNull);
        expect(result.returnDataAnalysis.analysis,
            contains('Data type: String/Text'),);
      });
    });

    group('Debug Information Extraction', () {
      test('should extract debug information', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: [
            'Program log: Starting execution',
            'Program log: DEBUG: Variable x = 42',
            'Program log: TRACE: Function called',
            'Program log: WARNING: Deprecated feature used',
            'Program log: Operation completed',
          ],
          unitsConsumed: 250000,
        );

        final result = await processor.processResult(simulationResult);

        expect(result.debugInfo.hasDebugInfo, true);
        expect(result.debugInfo.debugLogs, isNotNull);
        expect(result.debugInfo.debugLogs!.length, equals(2));
        expect(result.debugInfo.warnings, isNotNull);
        expect(result.debugInfo.warnings!.length, equals(1));
        expect(result.debugInfo.performanceMetrics, isNotNull);
        expect(result.debugInfo.performanceMetrics!['computeUnitsConsumed'],
            equals(250000),);
        expect(result.debugInfo.recommendations, isNotNull);
      });

      test('should generate performance recommendations', () async {
        final simulationResult = TransactionSimulationResult(
          success: false,
          logs: List.generate(60, (i) => 'Program log: Operation $i'),
          error: const TransactionSimulationError(
            type: 'ComputeBudgetExceeded',
          ),
          unitsConsumed: 850000,
        );

        final result = await processor.processResult(simulationResult);

        expect(result.debugInfo.recommendations, isNotNull);
        expect(
            result.debugInfo.recommendations!
                .any((r) => r.contains('compute unit')),
            true,);
        expect(result.debugInfo.recommendations!.any((r) => r.contains('logs')),
            true,);
        expect(
            result.debugInfo.recommendations!.any((r) => r.contains('failed')),
            true,);
      });
    });

    group('Error Analysis', () {
      test('should analyze instruction errors', () async {
        final simulationResult = const TransactionSimulationResult(
          success: false,
          logs: [
            'Program log: Processing instruction 0',
            'Program log: Error: Insufficient funds for rent',
            'Program failed: Instruction error',
          ],
          error: TransactionSimulationError(
            type: 'InstructionError',
            instructionIndex: 0,
            customErrorCode: 3001,
          ),
        );

        final result = await processor.processResult(simulationResult);

        expect(result.errorAnalysis.hasErrors, true);
        expect(result.errorAnalysis.errorType, equals('InstructionError'));
        expect(result.errorAnalysis.instructionIndex, equals(0));
        expect(result.errorAnalysis.errorCode, equals(3001));
        expect(result.errorAnalysis.errorSummary, contains('InstructionError'));
        expect(result.errorAnalysis.errorContext,
            contains('Failed at instruction: 0'),);
        expect(result.errorAnalysis.suggestions, isNotEmpty);
        expect(result.errorAnalysis.relatedLogs, isNotEmpty);
      });

      test('should provide error-specific suggestions', () async {
        final testCases = [
          ('InsufficientFundsForRent', 'rent exemption'),
          ('InvalidAccountData', 'account data format'),
          ('ProgramFailedToComplete', 'compute budget'),
        ];

        for (final testCase in testCases) {
          final errorType = testCase.$1;
          final expectedSuggestion = testCase.$2;

          final simulationResult = TransactionSimulationResult(
            success: false,
            logs: ['Program log: Error occurred'],
            error: TransactionSimulationError(type: errorType),
          );

          final result = await processor.processResult(simulationResult);

          expect(result.errorAnalysis.suggestions, isNotEmpty);
          expect(
            result.errorAnalysis.suggestions!
                .any((s) => s.contains(expectedSuggestion)),
            true,
            reason:
                'Expected suggestion containing "$expectedSuggestion" for error type "$errorType"',
          );
        }
      });
    });

    group('Caching', () {
      test('should cache processed results', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test'],
        );

        // Process with cache key
        final result1 = await processor.processResult(
          simulationResult,
          cacheKey: 'test_key',
        );

        // Process again with same cache key
        final result2 = await processor.processResult(
          simulationResult,
          cacheKey: 'test_key',
        );

        expect(identical(result1, result2), true);

        final stats = processor.getCacheStats();
        expect(stats['cacheSize'], equals(1));
        expect(stats['cacheHitRate'], greaterThan(0));
      });

      test('should respect cache size limits', () async {
        final config = const SimulationProcessingConfig(maxCacheSize: 2);
        final limitedProcessor = SimulationResultProcessor(config: config);

        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test'],
        );

        // Fill cache beyond limit
        await limitedProcessor.processResult(simulationResult,
            cacheKey: 'key1',);
        await limitedProcessor.processResult(simulationResult,
            cacheKey: 'key2',);
        await limitedProcessor.processResult(simulationResult,
            cacheKey: 'key3',);

        final stats = limitedProcessor.getCacheStats();
        expect(stats['cacheSize'], equals(2));
      });
    });

    group('Result Comparison', () {
      test('should compare identical results', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test'],
          unitsConsumed: 100000,
        );

        final result1 = await processor.processResult(simulationResult);
        final result2 = await processor.processResult(simulationResult);

        final comparison = processor.compareResults(result1, result2);

        expect(comparison.areIdentical, true);
        expect(comparison.overallSimilarity, equals(1.0));
        expect(comparison.similarities, isNotEmpty);
        expect(comparison.differences.isEmpty, true);
      });

      test('should compare different results', () async {
        final result1 =
            await processor.processResult(const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test 1'],
          unitsConsumed: 100000,
        ),);

        final result2 =
            await processor.processResult(const TransactionSimulationResult(
          success: false,
          logs: ['Program log: Test 2', 'Program log: Error'],
          unitsConsumed: 200000,
        ),);

        final comparison = processor.compareResults(result1, result2);

        expect(comparison.areIdentical, false);
        expect(comparison.overallSimilarity, lessThan(1.0));
        expect(comparison.differences, isNotEmpty);
        expect(comparison.differences.any((d) => d.contains('Success status')),
            true,);
        expect(comparison.differences.any((d) => d.contains('Compute units')),
            true,);
      });
    });

    group('Processing Options', () {
      test('should respect minimal processing options', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test'],
          unitsConsumed: 100000,
          accounts: {
            '11111111111111111111111111111112': {
              'lamports': 1000000,
              'owner': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
              'executable': false,
            },
          },
          returnData: TransactionReturnData(
            programId: '11111111111111111111111111111112',
            data: 'test',
          ),
        );

        final result = await processor.processResult(
          simulationResult,
          options: ProcessingOptions.minimal(),
        );

        expect(result.events.isEmpty, true);
        expect(result.accountChanges.hasChanges, false);
        expect(result.returnDataAnalysis.hasReturnData, false);
        expect(result.debugInfo.hasDebugInfo, false);
        expect(result.errorAnalysis.hasErrors, false); // No errors to analyze
      });

      test('should respect custom processing options', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test'],
          accounts: {
            '11111111111111111111111111111112': {
              'lamports': 1000000,
              'owner': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
              'executable': false,
            },
          },
        );

        final result = await processor.processResult(
          simulationResult,
          options: const ProcessingOptions(
            analyzeAccountChanges: false,
            processReturnData: false,
            extractDebugInfo: false,
            analyzeErrors: false,
          ),
        );

        expect(result.events, isNotEmpty);
        expect(result.accountChanges.hasChanges, false);
        expect(result.returnDataAnalysis.hasReturnData, false);
        expect(result.debugInfo.hasDebugInfo, false);
      });
    });

    group('Summary Generation', () {
      test('should generate comprehensive summary', () async {
        final simulationResult = const TransactionSimulationResult(
          success: true,
          logs: ['Program log: Test operation'],
          unitsConsumed: 125000,
          accounts: {
            '11111111111111111111111111111112': {
              'lamports': 1000000,
              'owner': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
              'executable': false,
            },
          },
          returnData: TransactionReturnData(
            programId: '11111111111111111111111111111112',
            data: 'test-data',
          ),
        );

        final result = await processor.processResult(simulationResult);
        final summary = result.generateSummary();

        expect(summary, contains('Success'));
        expect(summary, contains('Events extracted'));
        expect(summary, contains('Account changes'));
        expect(summary, contains('Processing time'));
        expect(summary, contains('Compute units: 125000'));
        expect(summary, contains('Return data'));
      });
    });
  });
}
