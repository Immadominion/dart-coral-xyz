/// Tests for Anchor Error Type Foundation
///
/// This test suite validates the error system implementation against TypeScript
/// behavior with comprehensive coverage of all error types and parsing scenarios.

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('ErrorCode', () {
    test('creates error code with string and number', () {
      const errorCode = ErrorCode(code: 'TestError', number: 6000);

      expect(errorCode.code, equals('TestError'));
      expect(errorCode.number, equals(6000));
      expect(errorCode.toString(), equals('TestError (6000)'));
    });

    test('supports equality comparison', () {
      const errorCode1 = ErrorCode(code: 'TestError', number: 6000);
      const errorCode2 = ErrorCode(code: 'TestError', number: 6000);
      const errorCode3 = ErrorCode(code: 'DifferentError', number: 6000);

      expect(errorCode1, equals(errorCode2));
      expect(errorCode1, isNot(equals(errorCode3)));
    });

    test('supports JSON serialization', () {
      const errorCode = ErrorCode(code: 'TestError', number: 6000);
      final json = errorCode.toJson();
      final restored = ErrorCode.fromJson(json);

      expect(restored, equals(errorCode));
    });
  });

  group('FileLine', () {
    test('creates file line with path and line number', () {
      const fileLine = FileLine(file: 'src/lib.rs', line: 42);

      expect(fileLine.file, equals('src/lib.rs'));
      expect(fileLine.line, equals(42));
      expect(fileLine.toString(), equals('src/lib.rs:42'));
    });

    test('supports JSON serialization', () {
      const fileLine = FileLine(file: 'src/lib.rs', line: 42);
      final json = fileLine.toJson();
      final restored = FileLine.fromJson(json);

      expect(restored, equals(fileLine));
    });
  });

  group('Origin', () {
    test('creates account name origin', () {
      final origin = Origin.accountName('test_account');

      expect(origin, isA<AccountNameOrigin>());
      expect(origin.toString(), equals('test_account'));
    });

    test('creates file line origin', () {
      const fileLine = FileLine(file: 'src/lib.rs', line: 42);
      final origin = Origin.fileLine(fileLine);

      expect(origin, isA<FileLineOrigin>());
      expect(origin.toString(), equals('src/lib.rs:42'));
    });

    test('supports JSON serialization for account name', () {
      final origin = Origin.accountName('test_account');
      final json = origin.toJson();
      final restored = Origin.fromJson(json);

      expect(restored, equals(origin));
    });

    test('supports JSON serialization for file line', () {
      const fileLine = FileLine(file: 'src/lib.rs', line: 42);
      final origin = Origin.fileLine(fileLine);
      final json = origin.toJson();
      final restored = Origin.fromJson(json);

      expect(restored, equals(origin));
    });
  });

  group('ComparedValues', () {
    test('creates compared account names', () {
      final compared = ComparedValues.accountNames(['left', 'right']);

      expect(compared, isA<ComparedAccountNames>());
      expect(compared.values, equals(['left', 'right']));
      expect(compared.toString(), equals('Left: left, Right: right'));
    });

    test('creates compared public keys', () {
      final pubkey1 = PublicKey.fromBase58('11111111111111111111111111111111');
      final pubkey2 = PublicKey.fromBase58('11111111111111111111111111111112');
      final compared = ComparedValues.publicKeys([pubkey1, pubkey2]);

      expect(compared, isA<ComparedPublicKeys>());
      expect(compared.values, equals([pubkey1.toBase58(), pubkey2.toBase58()]));
    });

    test('validates array length', () {
      expect(
        () => ComparedValues.accountNames(['only_one']),
        throwsArgumentError,
      );

      expect(
        () => ComparedValues.accountNames(['one', 'two', 'three']),
        throwsArgumentError,
      );
    });

    test('supports JSON serialization', () {
      final compared = ComparedValues.accountNames(['left', 'right']);
      final json = compared.toJson();
      final restored = ComparedValues.fromJson(json);

      expect(restored, isA<ComparedAccountNames>());
      expect(restored.values, equals(['left', 'right']));
    });
  });

  group('ProgramErrorStack', () {
    test('parses empty stack from empty logs', () {
      final stack = ProgramErrorStack.parse([]);

      expect(stack.stack, isEmpty);
      expect(stack.currentProgram, isNull);
      expect(stack.isEmpty, isTrue);
    });

    test('parses single program invocation', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program 11111111111111111111111111111111 success',
      ];

      final stack = ProgramErrorStack.parse(logs);

      expect(stack.stack, isEmpty); // Success removes from stack
      expect(stack.currentProgram, isNull);
    });

    test('parses failed program invocation', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final logs = [
        'Program ${pubkey.toBase58()} invoke [1]',
        'Program ${pubkey.toBase58()} failed: custom program error: 0x1',
      ];

      final stack = ProgramErrorStack.parse(logs);

      expect(stack.stack, hasLength(1));
      expect(stack.currentProgram, equals(pubkey));
      expect(stack.isEmpty, isFalse);
    });

    test('parses nested program calls with CPI', () {
      final pubkey1 = PublicKey.fromBase58('11111111111111111111111111111111');
      final pubkey2 = PublicKey.fromBase58('11111111111111111111111111111112');
      final logs = [
        'Program ${pubkey1.toBase58()} invoke [1]',
        'Program ${pubkey2.toBase58()} invoke [2]',
        'Program ${pubkey2.toBase58()} failed: custom program error: 0x1',
      ];

      final stack = ProgramErrorStack.parse(logs);

      expect(stack.stack, hasLength(2));
      expect(stack.currentProgram, equals(pubkey2));
      expect(stack.stack[0], equals(pubkey1));
      expect(stack.stack[1], equals(pubkey2));
    });

    test('handles malformed public keys gracefully', () {
      final logs = [
        'Program invalid_pubkey invoke [1]',
        'Program invalid_pubkey failed',
      ];

      final stack = ProgramErrorStack.parse(logs);

      expect(stack.stack, isEmpty);
    });

    test('supports JSON serialization', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final stack = ProgramErrorStack([pubkey]);
      final json = stack.toJson();
      final restored = ProgramErrorStack.fromJson(json);

      expect(restored.stack, equals([pubkey]));
    });
  });

  group('AnchorError.parse', () {
    test('returns null for empty logs', () {
      final result = AnchorError.parse(null);
      expect(result, isNull);

      final result2 = AnchorError.parse([]);
      expect(result2, isNull);
    });

    test('returns null when no AnchorError log found', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program log: Some other log',
        'Program 11111111111111111111111111111111 success',
      ];

      final result = AnchorError.parse(logs);
      expect(result, isNull);
    });

    test('parses basic AnchorError occurred format', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program log: AnchorError occurred. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program 11111111111111111111111111111111 failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs);

      expect(result, isNotNull);
      expect(result!.errorCode.code, equals('TestError'));
      expect(result.errorCode.number, equals(6000));
      expect(result.error.errorMessage, equals('Test error message'));
      expect(result.error.origin, isNull);
      expect(result.error.comparedValues, isNull);
    });

    test('parses AnchorError thrown in file format', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program log: AnchorError thrown in programs/test/src/lib.rs:42. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program 11111111111111111111111111111111 failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs);

      expect(result, isNotNull);
      expect(result!.error.origin, isA<FileLineOrigin>());
      final fileLineOrigin = result.error.origin as FileLineOrigin;
      expect(fileLineOrigin.fileLine!.file, equals('programs/test/src/lib.rs'));
      expect(fileLineOrigin.fileLine!.line, equals(42));
    });

    test('parses AnchorError caused by account format', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program log: AnchorError caused by account: test_account. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program 11111111111111111111111111111111 failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs);

      expect(result, isNotNull);
      expect(result!.error.origin, isA<AccountNameOrigin>());
      final accountOrigin = result.error.origin as AccountNameOrigin;
      expect(accountOrigin.accountName, equals('test_account'));
    });

    test('parses compared values with Left/Right pattern', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program log: AnchorError occurred. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program log: Left: value1',
        'Program log: Right: value2',
        'Program 11111111111111111111111111111111 failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs);

      expect(result, isNotNull);
      expect(result!.error.comparedValues, isA<ComparedAccountNames>());
      final compared = result.error.comparedValues as ComparedAccountNames;
      expect(compared.accountNames, equals(['value1', 'value2']));
    });

    test('parses compared values with Left:/Right: pubkey pattern', () {
      final pubkey1 = PublicKey.fromBase58('11111111111111111111111111111111');
      final pubkey2 = PublicKey.fromBase58('11111111111111111111111111111112');
      final logs = [
        'Program ${pubkey1.toBase58()} invoke [1]',
        'Program log: AnchorError occurred. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program log: Left:',
        'Program log: ${pubkey1.toBase58()}',
        'Program log: Right:',
        'Program log: ${pubkey2.toBase58()}',
        'Program ${pubkey1.toBase58()} failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs);

      expect(result, isNotNull);
      expect(result!.error.comparedValues, isA<ComparedPublicKeys>());
      final compared = result.error.comparedValues as ComparedPublicKeys;
      expect(compared.publicKeys, equals([pubkey1, pubkey2]));
    });

    test('handles malformed pubkeys in compared values gracefully', () {
      final logs = [
        'Program 11111111111111111111111111111111 invoke [1]',
        'Program log: AnchorError occurred. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program log: Left:',
        'Program log: invalid_pubkey',
        'Program log: Right:',
        'Program log: also_invalid',
        'Program 11111111111111111111111111111111 failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs);

      expect(result, isNotNull);
      expect(result!.error.comparedValues,
          isNull); // Should gracefully handle invalid pubkeys
    });
  });

  group('AnchorError properties', () {
    test('provides access to program and stack', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final logs = [
        'Program ${pubkey.toBase58()} invoke [1]',
        'Program log: AnchorError occurred. Error Code: TestError. Error Number: 6000. Error Message: Test error message.',
        'Program ${pubkey.toBase58()} failed: custom program error: 0x1770',
      ];

      final result = AnchorError.parse(logs)!;

      expect(result.program, equals(pubkey));
      expect(result.programErrorStack, equals([pubkey]));
      expect(result.message, equals('Test error message'));
      expect(result.errorCode.code, equals('TestError'));
    });

    test('throws error when accessing program with empty stack', () {
      final emptyStackError = AnchorError(
        error: ErrorInfo(
          errorCode: const ErrorCode(code: 'TestError', number: 6000),
          errorMessage: 'Test message',
        ),
        errorLogs: ['test log'],
        logs: [], // Empty logs = empty stack
      );

      expect(() => emptyStackError.program, throwsStateError);
    });

    test('formats toString correctly for different origins', () {
      // File line origin
      final fileLineError = AnchorError(
        error: ErrorInfo(
          errorCode: const ErrorCode(code: 'TestError', number: 6000),
          errorMessage: 'Test message',
          origin: Origin.fileLine(const FileLine(file: 'src/lib.rs', line: 42)),
        ),
        errorLogs: ['test log'],
        logs: ['Program 11111111111111111111111111111111 invoke [1]'],
      );

      expect(fileLineError.toString(),
          contains('AnchorError thrown in src/lib.rs:42'));
      expect(fileLineError.toString(), contains('Error Code: TestError'));
      expect(fileLineError.toString(), contains('Error Number: 6000'));
      expect(fileLineError.toString(), contains('Error Message: Test message'));

      // Account name origin
      final accountError = AnchorError(
        error: ErrorInfo(
          errorCode: const ErrorCode(code: 'TestError', number: 6000),
          errorMessage: 'Test message',
          origin: Origin.accountName('test_account'),
        ),
        errorLogs: ['test log'],
        logs: ['Program 11111111111111111111111111111111 invoke [1]'],
      );

      expect(accountError.toString(),
          contains('AnchorError caused by account: test_account'));

      // No origin
      final noOriginError = AnchorError(
        error: ErrorInfo(
          errorCode: const ErrorCode(code: 'TestError', number: 6000),
          errorMessage: 'Test message',
        ),
        errorLogs: ['test log'],
        logs: ['Program 11111111111111111111111111111111 invoke [1]'],
      );

      expect(noOriginError.toString(), contains('AnchorError occurred'));
    });
  });

  group('AnchorError JSON serialization', () {
    test('supports full JSON round-trip', () {
      final original = AnchorError(
        error: ErrorInfo(
          errorCode: const ErrorCode(code: 'TestError', number: 6000),
          errorMessage: 'Test message',
          origin: Origin.fileLine(const FileLine(file: 'src/lib.rs', line: 42)),
          comparedValues: ComparedValues.accountNames(['left', 'right']),
        ),
        errorLogs: ['error log'],
        logs: ['Program 11111111111111111111111111111111 invoke [1]'],
      );

      final json = original.toJson();
      final restored = AnchorError.fromJson(json);

      expect(restored.error.errorCode, equals(original.error.errorCode));
      expect(restored.error.errorMessage, equals(original.error.errorMessage));
      expect(restored.error.origin, equals(original.error.origin));
      expect(restored.error.comparedValues, isA<ComparedAccountNames>());
      expect(restored.errorLogs, equals(original.errorLogs));
      expect(restored.logs, equals(original.logs));
    });
  });

  group('Error Constants', () {
    test('provides correct error codes matching TypeScript', () {
      expect(LangErrorCode.instructionMissing, equals(100));
      expect(LangErrorCode.accountDiscriminatorMismatch, equals(3002));
      expect(LangErrorCode.constraintMut, equals(2000));
      expect(LangErrorCode.requireViolated, equals(2500));
    });

    test('provides error messages for all codes', () {
      expect(getErrorMessage(LangErrorCode.instructionMissing),
          equals('Instruction discriminator not provided'));
      expect(getErrorMessage(LangErrorCode.accountDiscriminatorMismatch),
          equals('Account discriminator did not match what was expected'));
      expect(getErrorMessage(9999), equals('Unknown error code: 9999'));
    });
  });

  group('ProgramError', () {
    test('creates program error with code and message', () {
      final error = ProgramError(
        code: 6000,
        msg: 'Custom error message',
      );

      expect(error.code, equals(6000));
      expect(error.msg, equals('Custom error message'));
      expect(error.toString(), equals('Custom error message'));
    });

    test('parses custom program error from error string', () {
      const errString = 'Transaction failed: custom program error: 0x1770';
      final idlErrors = <int, String>{6000: 'Custom error'};

      final error = ProgramError.parse(errString, idlErrors);

      expect(error, isNotNull);
      expect(error!.code, equals(6000)); // 0x1770 = 6000
      expect(error.msg, equals('Custom error'));
    });

    test('parses framework error when IDL error not found', () {
      const errString =
          'Transaction failed: custom program error: 0x64'; // 100 decimal
      final idlErrors = <int, String>{};

      final error = ProgramError.parse(errString, idlErrors);

      expect(error, isNotNull);
      expect(error!.code, equals(100));
      expect(error.msg, equals(getErrorMessage(100)));
    });

    test('parses JSON format error', () {
      const errString = 'RpcError {"Custom":6000}';
      final idlErrors = <int, String>{6000: 'Custom error'};

      final error = ProgramError.parse(errString, idlErrors);

      expect(error, isNotNull);
      expect(error!.code, equals(6000));
      expect(error.msg, equals('Custom error'));
    });

    test('returns null for unparseable errors', () {
      const errString = 'Some other error format';
      final idlErrors = <int, String>{};

      final error = ProgramError.parse(errString, idlErrors);

      expect(error, isNull);
    });

    test('handles program error stack from logs', () {
      final pubkey = PublicKey.fromBase58('11111111111111111111111111111111');
      final logs = [
        'Program ${pubkey.toBase58()} invoke [1]',
        'Program ${pubkey.toBase58()} failed: custom program error: 0x1770',
      ];

      final error = ProgramError(
        code: 6000,
        msg: 'Test error',
        logs: logs,
      );

      expect(error.program, equals(pubkey));
      expect(error.programErrorStack, equals([pubkey]));
    });

    test('supports JSON serialization', () {
      final error = ProgramError(
        code: 6000,
        msg: 'Test error',
        logs: ['test log'],
      );

      final json = error.toJson();
      final restored = ProgramError.fromJson(json);

      expect(restored.code, equals(error.code));
      expect(restored.msg, equals(error.msg));
      expect(restored.logs, equals(error.logs));
    });
  });

  group('translateError', () {
    test('returns AnchorError when logs contain AnchorError', () {
      final err = {
        'logs': [
          'Program 11111111111111111111111111111111 invoke [1]',
          'Program log: AnchorError occurred. Error Code: TestError. Error Number: 6000. Error Message: Test error.',
          'Program 11111111111111111111111111111111 failed',
        ]
      };

      final result = translateError(err, <int, String>{});

      expect(result, isA<AnchorError>());
      final anchorError = result as AnchorError;
      expect(anchorError.errorCode.code, equals('TestError'));
    });

    test('returns ProgramError when parseable as program error', () {
      const err = 'Transaction failed: custom program error: 0x1770';
      final idlErrors = <int, String>{6000: 'Custom error'};

      final result = translateError(err, idlErrors);

      expect(result, isA<ProgramError>());
      final programError = result as ProgramError;
      expect(programError.code, equals(6000));
    });

    test('adds program error stack to other errors with logs', () {
      final err = {
        'logs': [
          'Program 11111111111111111111111111111111 invoke [1]',
          'Program 11111111111111111111111111111111 failed',
        ],
        'message': 'Some other error'
      };

      final result = translateError(err, <int, String>{});

      // Should be wrapped with program error stack
      expect(result.toString(), equals(err.toString()));
    });

    test('returns original error when no transformation possible', () {
      const err = 'Simple string error';

      final result = translateError(err, <int, String>{});

      expect(result, equals(err));
    });
  });

  group('IdlError', () {
    test('creates IDL error with message', () {
      final error = IdlError('IDL parsing failed');

      expect(error.message, equals('IDL parsing failed'));
      expect(error.toString(), equals('IdlError: IDL parsing failed'));
    });
  });
}
