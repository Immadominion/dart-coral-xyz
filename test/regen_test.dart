import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/program_generator.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/account_generator.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/instruction_generator.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/error_generator.dart';
import 'package:build/build.dart';
import 'dart:io';

void main() {
  test('Generate correct code from IDL', () async {
    // Load the test IDL
    final idlJson = {
      "version": "0.1.0",
      "name": "test_program",
      "address": "11111111111111111111111111111112",
      "instructions": [
        {
          "name": "initialize",
          "accounts": [
            {"name": "user", "isMut": true, "isSigner": true},
            {"name": "systemProgram", "isMut": false, "isSigner": false}
          ],
          "args": [
            {"name": "amount", "type": "u64"}
          ]
        },
        {
          "name": "update",
          "accounts": [
            {"name": "user", "isMut": true, "isSigner": true},
            {"name": "account", "isMut": true, "isSigner": false}
          ],
          "args": [
            {"name": "newValue", "type": "string"}
          ]
        }
      ],
      "accounts": [
        {
          "name": "TestAccount",
          "type": {
            "kind": "struct",
            "fields": [
              {"name": "authority", "type": "publicKey"},
              {"name": "value", "type": "u64"},
              {"name": "name", "type": "string"}
            ]
          }
        }
      ],
      "errors": [
        {"code": 6000, "name": "InvalidAmount", "msg": "The amount is invalid"}
      ]
    };

    final idl = Idl.fromJson(idlJson);

    // Generate the code
    final buffer = StringBuffer();

    // Generate header
    _generateHeader(buffer, idl);

    final programGenerator = ProgramGenerator(idl, BuilderOptions.empty);
    buffer.writeln(programGenerator.generate());

    final accountGenerator = AccountGenerator(idl, BuilderOptions.empty);
    buffer.writeln(accountGenerator.generate());

    final instructionGenerator =
        InstructionGenerator(idl, BuilderOptions.empty);
    buffer.writeln(instructionGenerator.generate());

    final errorGenerator = ErrorGenerator(idl, BuilderOptions.empty);
    buffer.writeln(errorGenerator.generate());

    final generatedCode = buffer.toString();

    // Write to file
    final outputFile = 'test/codegen_test.anchor.dart';
    await File(outputFile).writeAsString(generatedCode);

    print('Generated code written to $outputFile');
    print('Code length: ${generatedCode.length} characters');

    // Basic validation
    expect(generatedCode, contains('TestProgramProgram'));
    expect(generatedCode, contains('InitializeInstructionBuilder'));
    expect(generatedCode, contains('UpdateInstructionBuilder'));
    expect(generatedCode, contains('TestAccount'));
    expect(generatedCode, contains('InvalidAmount'));
  });
}

void _generateHeader(StringBuffer buffer, Idl idl) {
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// Generated from IDL: ${idl.name ?? 'unknown'}');
  if (idl.version != null) {
    buffer.writeln('// Version: ${idl.version}');
  }
  buffer.writeln('// Generated at: ${DateTime.now().toIso8601String()}');
  buffer.writeln();

  // Add imports
  buffer.writeln('import \'dart:typed_data\';');
  buffer.writeln('import \'package:coral_xyz_anchor/coral_xyz_anchor.dart\';');
  buffer.writeln(
      'import \'package:coral_xyz_anchor/src/transaction/transaction_simulator.dart\';');
  buffer.writeln(
      'import \'package:coral_xyz_anchor/src/types/transaction.dart\' as tx;');
  buffer.writeln('import \'package:solana/solana.dart\' as solana;');
  buffer.writeln();

  // Add program ID constant if provided
  if (idl.address != null) {
    buffer.writeln('/// Program ID for ${idl.name ?? 'program'}');
    buffer.writeln('const String kProgramId = \'${idl.address}\';');
    buffer.writeln();
  }
}
