/// Test suite for RPC Error Parsing Engine
///
/// Comprehensive tests validating RPC error parsing capabilities
/// and ensuring compatibility with TypeScript Anchor client behavior.
library;

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('RpcErrorParser', () {
    group('parse', () {
      test('should return original error when logs are empty', () {
        final error = {'message': 'test error'};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNull);
        expect(result.programError, isNull);
        expect(result.originalError, equals(error));
        expect(result.hasParsedError, isFalse);
      });

      test('should return original error when no logs available', () {
        final error = {'message': 'test error', 'code': 500};
        final result = RpcErrorParser.parse(error);

        expect(result.originalError, equals(error));
        expect(result.hasParsedError, isFalse);
      });

      test('should return enhanced error when logs present but no anchor error',
          () {
        final error = {
          'message': 'test error',
          'logs': [
            'Program 11111111111111111111111111111112 invoke',
            'Program 11111111111111111111111111111112 success',
          ],
        };

        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNull);
        expect(result.programError, isNull);
        expect(result.originalError, isA<EnhancedError>());

        final enhancedError = result.originalError as EnhancedError;
        expect(enhancedError.logs, hasLength(2));
        expect(enhancedError.programStack, isEmpty);
      });
    });

    group('AnchorError parsing', () {
      test('should parse AnchorError with no additional info', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError occurred. Error Code: AccountDiscriminatorMismatch. Error Number: 3002. Error Message: Account discriminator did not match what was expected.',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
          'Program 11111111111111111111111111111112 failed: custom program error: 0xbba',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNotNull);
        expect(result.anchorError!.errorCode.code,
            equals('AccountDiscriminatorMismatch'),);
        expect(result.anchorError!.errorCode.number, equals(3002));
        expect(result.anchorError!.message,
            equals('Account discriminator did not match what was expected'),);
        expect(result.anchorError!.origin, isNull);
        expect(result.anchorError!.comparedValues, isNull);
        expect(result.anchorError!.errorLogs, hasLength(1));
      });

      test('should parse AnchorError with file and line info', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError thrown in programs/test/src/lib.rs:42. Error Code: ConstraintSigner. Error Number: 3012. Error Message: A signer constraint was violated.',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
          'Program 11111111111111111111111111111112 failed: custom program error: 0xbc4',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNotNull);
        expect(result.anchorError!.errorCode.code, equals('ConstraintSigner'));
        expect(result.anchorError!.errorCode.number, equals(3012));
        expect(result.anchorError!.message,
            equals('A signer constraint was violated'),);

        expect(result.anchorError!.origin, isA<FileLineOrigin>());
        final fileLineOrigin = result.anchorError!.origin as FileLineOrigin;
        expect(
            fileLineOrigin.fileLine!.file, equals('programs/test/src/lib.rs'),);
        expect(fileLineOrigin.fileLine!.line, equals(42));

        expect(result.anchorError!.comparedValues, isNull);
      });

      test('should parse AnchorError with account name info', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError caused by account: user_account. Error Code: AccountOwnedByWrongProgram. Error Number: 3007. Error Message: The given account is owned by a different program than expected.',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
          'Program 11111111111111111111111111111112 failed: custom program error: 0xbbf',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNotNull);
        expect(result.anchorError!.errorCode.code,
            equals('AccountOwnedByWrongProgram'),);
        expect(result.anchorError!.errorCode.number, equals(3007));
        expect(
            result.anchorError!.message,
            equals(
                'The given account is owned by a different program than expected',),);

        expect(result.anchorError!.origin, isA<AccountNameOrigin>());
        final accountNameOrigin =
            result.anchorError!.origin as AccountNameOrigin;
        expect(accountNameOrigin.accountName, equals('user_account'));

        expect(result.anchorError!.comparedValues, isNull);
      });

      test('should parse AnchorError with separated public key compared values',
          () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError occurred. Error Code: ConstraintAddress. Error Number: 2006. Error Message: An address constraint was violated.',
          'Program log: Left:',
          'Program log: So11111111111111111111111111111111111111112',
          'Program log: Right:',
          'Program log: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
          'Program 11111111111111111111111111111112 failed: custom program error: 0x7d6',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNotNull);
        expect(result.anchorError!.comparedValues, isA<ComparedPublicKeys>());

        final comparedPubkeys =
            result.anchorError!.comparedValues as ComparedPublicKeys;
        expect(comparedPubkeys.publicKeys![0].toBase58(),
            equals('So11111111111111111111111111111111111111112'),);
        expect(comparedPubkeys.publicKeys![1].toBase58(),
            equals('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),);
        expect(result.anchorError!.errorLogs, hasLength(5));
      });

      test('should parse AnchorError with inline compared values', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError occurred. Error Code: RequireEqViolated. Error Number: 2501. Error Message: A require_eq expression was violated.',
          'Program log: Left: expected_value',
          'Program log: Right: actual_value',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
          'Program 11111111111111111111111111111112 failed: custom program error: 0x9c5',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNotNull);
        expect(result.anchorError!.comparedValues, isA<ComparedAccountNames>());

        final comparedValues =
            result.anchorError!.comparedValues as ComparedAccountNames;
        expect(comparedValues.accountNames![0], equals('expected_value'));
        expect(comparedValues.accountNames![1], equals('actual_value'));
        expect(result.anchorError!.errorLogs, hasLength(3));
      });

      test('should return null for malformed anchor error log', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError malformed log line',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNull);
        expect(result.originalError, isA<EnhancedError>());
      });

      test('should handle invalid public key in compared values gracefully',
          () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError occurred. Error Code: ConstraintAddress. Error Number: 2006. Error Message: An address constraint was violated.',
          'Program log: Left:',
          'Program log: invalid_public_key',
          'Program log: Right:',
          'Program log: 22222222222222222222222222222222',
        ];

        final error = {'logs': logs};
        final result = RpcErrorParser.parse(error, debugMode: true);

        expect(result.anchorError, isNotNull);
        // Should have parsed the error without compared values due to invalid pubkey
        expect(result.anchorError!.comparedValues, isNull);
      });
    });

    group('ProgramError parsing', () {
      test('should parse custom program error from error string', () {
        final error = {
          'message': 'Transaction failed: custom program error: 42',
          'logs': [
            'Program 11111111111111111111111111111112 invoke',
            'Program 11111111111111111111111111111112 consumed 5000 compute units',
            'Program 11111111111111111111111111111112 failed: custom program error: 42',
          ],
        };

        final idlErrors = {42: 'Custom error message from IDL'};
        final result = RpcErrorParser.parse(error, idlErrors: idlErrors);

        expect(result.programError, isNotNull);
        expect(result.programError!.code, equals(42));
        expect(
            result.programError!.msg, equals('Custom error message from IDL'),);
        expect(result.programError!.logs, isNotNull);
      });

      test('should parse JSON format program error', () {
        final error = {
          'message': '{"Custom":123}',
          'logs': [
            'Program 11111111111111111111111111111112 invoke',
            'Program 11111111111111111111111111111112 consumed 5000 compute units',
            'Program 11111111111111111111111111111112 failed: {"Custom":123}',
          ],
        };

        final result = RpcErrorParser.parse(error);

        expect(result.programError, isNotNull);
        expect(result.programError!.code, equals(123));
        expect(result.programError!.logs, isNotNull);
      });

      test('should prefer AnchorError over ProgramError when both present', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError occurred. Error Code: AccountDiscriminatorMismatch. Error Number: 3002. Error Message: Account discriminator did not match what was expected.',
          'Program 11111111111111111111111111111112 consumed 5000 compute units',
          'Program 11111111111111111111111111111112 failed: custom program error: 0xbba',
        ];

        final error = {
          'message': 'Transaction failed: custom program error: 3002',
          'logs': logs,
        };

        final result = RpcErrorParser.parse(error);

        expect(result.anchorError, isNotNull);
        expect(result.programError, isNull);
        expect(result.anchorError!.errorCode.number, equals(3002));
      });
    });

    group('EnhancedError', () {
      test('should create enhanced error with program stack', () {
        final originalError = {'message': 'test error'};
        final logs = [
          'Program So11111111111111111111111111111111111111112 invoke',
          'Program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA invoke',
          'Program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA success',
          'Program So11111111111111111111111111111111111111112 failed',
        ];

        final programErrorStack = ProgramErrorStack.parse(logs);
        final enhancedError = EnhancedError(
          originalError: originalError,
          programErrorStack: programErrorStack,
          logs: logs,
        );

        expect(enhancedError.originalError, equals(originalError));
        expect(enhancedError.logs, equals(logs));
        expect(enhancedError.programStack, hasLength(1));
        expect(enhancedError.program?.toBase58(),
            equals('So11111111111111111111111111111111111111112'),);
        expect(enhancedError.toString(), equals(originalError.toString()));

        final detailedString = enhancedError.toDetailedString();
        expect(detailedString, contains('Enhanced Error'));
        expect(detailedString, contains('Program Stack'));
        expect(detailedString, contains('Logs: 4 lines'));
      });

      test('should handle empty program stack', () {
        final originalError = {'message': 'test error'};
        final logs = <String>[];

        final programErrorStack = ProgramErrorStack.parse(logs);
        final enhancedError = EnhancedError(
          originalError: originalError,
          programErrorStack: programErrorStack,
          logs: logs,
        );

        expect(enhancedError.program, isNull);
        expect(enhancedError.programStack, isEmpty);
      });
    });

    group('translateRpcError', () {
      test('should return best available error', () {
        final logs = [
          'Program 11111111111111111111111111111112 invoke',
          'Program log: AnchorError occurred. Error Code: AccountDiscriminatorMismatch. Error Number: 3002. Error Message: Account discriminator did not match what was expected.',
          'Program 11111111111111111111111111111112 failed: custom program error: 0xbba',
        ];

        final error = {'logs': logs};
        final result = translateRpcError(error);

        expect(result, isA<AnchorError>());
        final anchorError = result as AnchorError;
        expect(anchorError.errorCode.number, equals(3002));
      });

      test('should return program error when no anchor error', () {
        final error = {
          'message': 'Transaction failed: custom program error: 42',
          'logs': [
            'Program 11111111111111111111111111111112 invoke',
            'Program 11111111111111111111111111111112 failed: custom program error: 42',
          ],
        };

        final idlErrors = {42: 'Custom IDL error'};
        final result = translateRpcError(error, idlErrors: idlErrors);

        expect(result, isA<ProgramError>());
        final programError = result as ProgramError;
        expect(programError.code, equals(42));
        expect(programError.msg, equals('Custom IDL error'));
      });

      test('should return enhanced error when no specific parsing succeeds',
          () {
        final error = {
          'message': 'Generic error',
          'logs': [
            'Program 11111111111111111111111111111112 invoke',
            'Program 11111111111111111111111111111112 success',
          ],
        };

        final result = translateRpcError(error);

        expect(result, isA<EnhancedError>());
        final enhancedError = result as EnhancedError;
        expect(enhancedError.logs, hasLength(2));
      });

      test('should return original error when no logs available', () {
        final error = {'message': 'test error'};
        final result = translateRpcError(error);

        expect(result, equals(error));
      });

      test('should support debug mode', () {
        final error = {'message': 'test error'};

        // Should not throw in debug mode
        expect(
            () => translateRpcError(error, debugMode: true), returnsNormally,);
      });
    });

    group('RpcErrorParseResult', () {
      test('should report correct parsed error status', () {
        final anchorError = AnchorError(
          error: const ErrorInfo(
            errorCode: ErrorCode(code: 'TestError', number: 1000),
            errorMessage: 'Test message',
          ),
          errorLogs: ['test log'],
          logs: ['test log'],
        );

        final result1 = RpcErrorParseResult(
          anchorError: anchorError,
          originalError: {'test': 'error'},
        );
        expect(result1.hasParsedError, isTrue);
        expect(result1.bestError, equals(anchorError));

        final result2 = const RpcErrorParseResult(
          originalError: {'test': 'error'},
        );
        expect(result2.hasParsedError, isFalse);
        expect(result2.bestError, equals({'test': 'error'}));
      });
    });
  });
}
