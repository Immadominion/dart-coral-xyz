import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

/// Test suite for Anchor error handling system
///
/// Tests comprehensive error parsing and representation to ensure
/// it matches the behavior of the TypeScript Anchor SDK.
void main() {
  group('Error Handling System', () {
    test('ProgramErrorStack parses execution stack correctly', () {
      final logs = [
        'Program 11111111111111111111111111111112 invoke [1]',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [2]',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 success',
        'Program 11111111111111111111111111111112 success',
      ];

      final stack = ProgramErrorStack.parse(logs);

      expect(stack.stack, isEmpty);
      expect(stack.currentProgram, isNull);
    });

    test('ProgramErrorStack tracks nested program calls', () {
      final logs = [
        'Program 11111111111111111111111111111112 invoke [1]',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [2]',
        // No success for inner program - simulates error
      ];

      final stack = ProgramErrorStack.parse(logs);

      expect(stack.stack.length, equals(2));
      expect(stack.stack[0].toBase58(),
          equals('11111111111111111111111111111112'));
      expect(stack.stack[1].toBase58(),
          equals('J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54'));
      expect(stack.currentProgram?.toBase58(),
          equals('J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54'));
    });

    test('AnchorError.parse handles basic error format', () {
      final logs = [
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
        'Program log: AnchorError occurred. Error Code: ConstraintMut. Error Number: 2000. Error Message: A mut constraint was violated.',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 consumed 123456 of 200000 compute units',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x7d0',
      ];

      final error = AnchorError.parse(logs);

      expect(error, isNotNull);
      expect(error!.errorCode.code, equals('ConstraintMut'));
      expect(error.errorCode.number, equals(2000));
      expect(error.errorMessage, equals('A mut constraint was violated.'));
      expect(error.origin, isNull);
      expect(error.comparedValues, isNull);
      expect(error.program?.toBase58(),
          equals('J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54'));
    });

    test('AnchorError.parse handles file location format', () {
      final logs = [
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
        'Program log: AnchorError thrown in src/lib.rs:42. Error Code: RequireViolated. Error Number: 2500. Error Message: A require expression was violated.',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x9c4',
      ];

      final error = AnchorError.parse(logs);

      expect(error, isNotNull);
      expect(error!.errorCode.code, equals('RequireViolated'));
      expect(error.errorCode.number, equals(2500));
      expect(error.errorMessage, equals('A require expression was violated.'));
      expect(error.origin, isNotNull);
      expect(error.origin!.fileLine, isNotNull);
      expect(error.origin!.fileLine!.file, equals('src/lib.rs'));
      expect(error.origin!.fileLine!.line, equals(42));
    });

    test('AnchorError.parse handles account name format', () {
      final logs = [
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
        'Program log: AnchorError caused by account: user_account. Error Code: ConstraintSigner. Error Number: 2002. Error Message: A signer constraint was violated.',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x7d2',
      ];

      final error = AnchorError.parse(logs);

      expect(error, isNotNull);
      expect(error!.errorCode.code, equals('ConstraintSigner'));
      expect(error.errorCode.number, equals(2002));
      expect(error.errorMessage, equals('A signer constraint was violated.'));
      expect(error.origin, isNotNull);
      expect(error.origin!.accountName, equals('user_account'));
      expect(error.origin!.fileLine, isNull);
    });

    test('AnchorError.parse handles compared public keys', () {
      final logs = [
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
        'Program log: AnchorError occurred. Error Code: RequireKeysEqViolated. Error Number: 2502. Error Message: A require_keys_eq expression was violated.',
        'Program log: Left:',
        'Program log: 11111111111111111111111111111111',
        'Program log: Right:',
        'Program log: J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x9c6',
      ];

      final error = AnchorError.parse(logs);

      expect(error, isNotNull);
      expect(error!.errorCode.code, equals('RequireKeysEqViolated'));
      expect(error.comparedValues, isNotNull);
      expect(error.comparedValues!.publicKeys, isNotNull);
      expect(error.comparedValues!.publicKeys!.length, equals(2));
      expect(error.comparedValues!.publicKeys![0].toBase58(),
          equals('11111111111111111111111111111111'));
      expect(error.comparedValues!.publicKeys![1].toBase58(),
          equals('J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54'));
    });

    test('AnchorError.parse handles compared values', () {
      final logs = [
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
        'Program log: AnchorError occurred. Error Code: RequireEqViolated. Error Number: 2501. Error Message: A require_eq expression was violated.',
        'Program log: Left: 100',
        'Program log: Right: 200',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x9c5',
      ];

      final error = AnchorError.parse(logs);

      expect(error, isNotNull);
      expect(error!.errorCode.code, equals('RequireEqViolated'));
      expect(error.comparedValues, isNotNull);
      expect(error.comparedValues!.accountNames, isNotNull);
      expect(error.comparedValues!.accountNames!.length, equals(2));
      expect(error.comparedValues!.accountNames![0], equals('100'));
      expect(error.comparedValues!.accountNames![1], equals('200'));
    });

    test('AnchorError.parse returns null for non-anchor errors', () {
      final logs = [
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
        'Program log: Regular program log message',
        'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x1',
      ];

      final error = AnchorError.parse(logs);
      expect(error, isNull);
    });

    test('ProgramError.parse handles custom program error format', () {
      final mockError = MockError(
        'Error: custom program error: 6000',
        [
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x1770'
        ],
      );

      final idlErrors = <int, String>{
        6000: 'Custom user error message',
      };

      final error = ProgramError.parse(mockError, idlErrors);

      expect(error, isNotNull);
      expect(error!.code, equals(6000));
      expect(error.message, equals('Custom user error message'));
      expect(error.program?.toBase58(),
          equals('J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54'));
    });

    test('ProgramError.parse handles JSON error format', () {
      final mockError = MockError(
        'Error: {"Custom":2000}',
        [
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed'
        ],
      );

      final error = ProgramError.parse(mockError, {});

      expect(error, isNotNull);
      expect(error!.code, equals(2000));
      expect(error.message, equals('A mut constraint was violated'));
    });

    test('ProgramError.parse returns null for unparseable errors', () {
      final mockError = MockError('Some random error message', []);
      final error = ProgramError.parse(mockError, {});
      expect(error, isNull);
    });

    test('translateError prioritizes AnchorError over ProgramError', () {
      final mockError = MockError(
        'Error: custom program error: 2000',
        [
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
          'Program log: AnchorError occurred. Error Code: ConstraintMut. Error Number: 2000. Error Message: A mut constraint was violated.',
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x7d0',
        ],
      );

      final translatedError = translateError(mockError, {});

      expect(translatedError, isA<AnchorError>());
      expect((translatedError as AnchorError).errorCode.code,
          equals('ConstraintMut'));
    });

    test('translateError falls back to ProgramError when no AnchorError', () {
      final mockError = MockError(
        'Error: custom program error: 6000',
        [
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 invoke [1]',
          'Program J2XMGdW2qQLx7rAdwWtSZpTXDgAQ988BLP9QTgUZvm54 failed: custom program error: 0x1770',
        ],
      );

      final idlErrors = <int, String>{6000: 'Custom error'};
      final translatedError = translateError(mockError, idlErrors);

      expect(translatedError, isA<ProgramError>());
      expect((translatedError as ProgramError).code, equals(6000));
      expect(translatedError.message, equals('Custom error'));
    });

    test('createIdlErrorMap builds error map from IDL', () {
      final idl = Idl(
        address: '11111111111111111111111111111112',
        metadata: IdlMetadata(
          name: 'test_program',
          version: '1.0.0',
          spec: '0.1.0',
        ),
        instructions: [],
        errors: [
          IdlErrorCode(
              code: 6000, name: 'CustomError1', msg: 'First custom error'),
          IdlErrorCode(
              code: 6001, name: 'CustomError2', msg: 'Second custom error'),
          IdlErrorCode(code: 6002, name: 'CustomError3'), // No message
        ],
      );

      final errorMap = createIdlErrorMap(idl);

      expect(errorMap.length, equals(2)); // Only errors with messages
      expect(errorMap[6000], equals('First custom error'));
      expect(errorMap[6001], equals('Second custom error'));
      expect(errorMap.containsKey(6002), isFalse); // No message
    });

    test('Error toString methods produce readable output', () {
      final errorCode = ErrorCode(code: 'TestError', number: 1234);
      expect(errorCode.toString(), equals('TestError (1234)'));

      final fileLine = FileLine(file: 'src/lib.rs', line: 42);
      expect(fileLine.toString(), equals('src/lib.rs:42'));

      final origin = ErrorOrigin.accountName('user_account');
      expect(origin.toString(), equals('user_account'));

      final comparedValues = ComparedValues.accountNames(['100', '200']);
      expect(comparedValues.toString(), equals('Left: 100, Right: 200'));
    });

    test('LangErrorMessage contains all framework error codes', () {
      // Test a few key framework error messages
      expect(
          LangErrorMessage
              .langErrorMessages[LangErrorMessage.instructionMissing],
          equals('Instruction discriminator not provided'));
      expect(LangErrorMessage.langErrorMessages[LangErrorMessage.constraintMut],
          equals('A mut constraint was violated'));
      expect(
          LangErrorMessage
              .langErrorMessages[LangErrorMessage.accountDidNotDeserialize],
          equals('Failed to deserialize the account'));
      expect(
          LangErrorMessage.langErrorMessages[LangErrorMessage.requireViolated],
          equals('A require expression was violated'));
    });
  });
}

/// Mock error class for testing error parsing
class MockError {
  final String message;
  final List<String> logs;

  MockError(this.message, this.logs);

  @override
  String toString() => message;
}
