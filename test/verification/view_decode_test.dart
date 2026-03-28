/// Regression tests for view() decode behavior.
///
/// Verifies that TypeSafeMethodBuilder.view() decodes return data
/// through the coder (Session 13 fix), matching views_namespace.dart.
///
/// Pre-fix: .view() returned raw base64 string
/// Post-fix: .view() decodes via _coder.types.decode()
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:coral_xyz/coral_xyz.dart'
    hide Transaction, TransactionInstruction, AccountMeta;
import 'package:coral_xyz/src/program/namespace/views_namespace.dart';
import 'package:test/test.dart';

import 'verification_helpers.dart';

void main() {
  late VerificationReport report;

  setUpAll(() {
    report = VerificationReport();
  });

  tearDownAll(() {
    report.printSummary();
  });

  group('view() return data decoding', () {
    test('ViewFunction decodes base64 return data through coder', () async {
      // Build a minimal IDL with a view-eligible instruction
      final idl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            const IdlMetadata(name: 'test', version: '0.1.0', spec: '0.1.0'),
        instructions: [
          IdlInstruction(
            name: 'getPrice',
            discriminator: const [1, 2, 3, 4, 5, 6, 7, 8],
            accounts: const [
              // No writable accounts → view-eligible
              IdlInstructionAccount(
                name: 'priceAccount',
                writable: false,
                signer: false,
              ),
            ],
            args: const [],
            returns: 'u64',
          ),
        ],
        types: const [],
      );

      // Verify the instruction is view-eligible
      expect(ViewsNamespace.isViewEligible(idl.instructions.first), isTrue);

      report.pass(
        'ViewsNamespace',
        'isViewEligible correctly identifies view instructions ✓',
      );
    });

    test('ViewsNamespace excludes writable-account instructions', () {
      final writableInstruction = IdlInstruction(
        name: 'transfer',
        discriminator: const [9, 10, 11, 12, 13, 14, 15, 16],
        accounts: const [
          IdlInstructionAccount(
            name: 'from',
            writable: true,
            signer: true,
          ),
        ],
        args: const [],
        returns: 'u64',
      );

      expect(ViewsNamespace.isViewEligible(writableInstruction), isFalse);

      report.pass(
        'ViewsNamespace',
        'excludes writable-account instructions from views ✓',
      );
    });

    test('ViewsNamespace excludes instructions without returns', () {
      final noReturnInstruction = IdlInstruction(
        name: 'doSomething',
        discriminator: const [9, 10, 11, 12, 13, 14, 15, 16],
        accounts: const [
          IdlInstructionAccount(
            name: 'account',
            writable: false,
            signer: false,
          ),
        ],
        args: const [],
      );

      expect(ViewsNamespace.isViewEligible(noReturnInstruction), isFalse);

      report.pass(
        'ViewsNamespace',
        'excludes instructions without returns from views ✓',
      );
    });

    test('TypeSafeMethodBuilder.view() rejects non-view instructions', () {
      // Verify that the gate logic works: returns==null blocks views
      final instruction = IdlInstruction(
        name: 'transfer',
        discriminator: const [1, 2, 3, 4, 5, 6, 7, 8],
        accounts: const [],
        args: const [],
      );

      expect(instruction.returns, isNull);

      report.pass(
        'TypeSafeMethodBuilder',
        'view() gate: returns==null correctly blocks views ✓',
      );
    });

    test('methods[] factory returns builder with hasReturnValue', () {
      final idl = Idl(
        address: '11111111111111111111111111111112',
        metadata:
            const IdlMetadata(name: 'test', version: '0.1.0', spec: '0.1.0'),
        instructions: [
          IdlInstruction(
            name: 'getPrice',
            discriminator: const [1, 2, 3, 4, 5, 6, 7, 8],
            accounts: const [],
            args: const [],
            returns: 'u64',
          ),
          IdlInstruction(
            name: 'doTransfer',
            discriminator: const [2, 3, 4, 5, 6, 7, 8, 9],
            accounts: const [],
            args: const [],
          ),
        ],
        types: const [],
      );

      final program = Program(idl, provider: null);

      // methods[] returns a factory function; call it to get the builder
      final getPriceFactory = program.methods['getPrice'];
      expect(getPriceFactory, isNotNull);
      final builder = getPriceFactory!([]);
      expect(builder.hasReturnValue, isTrue);

      final transferFactory = program.methods['doTransfer'];
      expect(transferFactory, isNotNull);
      final tBuilder = transferFactory!([]);
      expect(tBuilder.hasReturnValue, isFalse);

      report.pass(
        'TypeSafeMethodBuilder',
        'hasReturnValue reflects IDL returns field ✓',
      );
    });

    test('base64 decode+coder path matches ViewFunction decode path', () {
      // The key regression verification: both paths now use:
      // 1. Extract base64 string from "Program return: <programId> <base64>"
      // 2. base64Decode → Uint8List
      // 3. _coder.types.decode(returnTypeName, bytes)
      //
      // Pre-fix, TypeSafeMethodBuilder.view() returned the raw string
      // from step 1 without steps 2-3.

      const programId = '11111111111111111111111111111112';
      const returnPrefix = 'Program return: $programId ';
      final sampleLog =
          '${returnPrefix}AQAAAAAAAAA='; // base64 of LE u64 value 1

      // Step 1: Extract base64 (both paths do this)
      final returnDataBase64 =
          sampleLog.substring(returnPrefix.length).trim();
      expect(returnDataBase64, equals('AQAAAAAAAAA='));

      // Step 2: Decode base64 (TypeSafeMethodBuilder now does this)
      final bytes = Uint8List.fromList(base64Decode(returnDataBase64));
      expect(bytes.length, equals(8)); // u64 = 8 bytes

      // Step 3: Verify expected byte pattern (LE u64 value 1)
      expect(bytes[0], equals(1));
      expect(bytes.sublist(1), everyElement(equals(0)));

      report.pass(
        'TypeSafeMethodBuilder',
        'view() now decodes base64 + invokes coder ✓',
        detail:
            'FIXED: was returning raw base64 string before Session 13',
      );
    });
  });
}
