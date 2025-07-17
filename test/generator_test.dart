import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/program_generator.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/instruction_generator.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/account_generator.dart';
import 'package:coral_xyz_anchor/src/codegen/generators/error_generator.dart';
import 'package:build/build.dart';

void main() {
  test('Test updated generators', () {
    // Create a simple test IDL
    const testIdl = Idl(
      address: '11111111111111111111111111111112',
      metadata: IdlMetadata(
        name: 'TestProgram',
        version: '0.1.0',
        spec: 'anchor-idl/0.0.1',
      ),
      instructions: [
        IdlInstruction(
          name: 'initialize',
          accounts: [
            IdlInstructionAccount(
              name: 'user',
              writable: true,
              signer: true,
            ),
          ],
          args: [
            IdlField(name: 'amount', type: IdlType(kind: 'u64')),
          ],
          discriminator: [],
        ),
      ],
      accounts: [
        IdlAccount(
          name: 'TestAccount',
          discriminator: [],
          type: IdlTypeDefType(
            kind: 'struct',
            fields: [
              IdlField(name: 'authority', type: IdlType(kind: 'publicKey')),
              IdlField(name: 'value', type: IdlType(kind: 'u64')),
            ],
          ),
        ),
      ],
    );

    final options = BuilderOptions.empty;

    // Test program generator
    final programGenerator = ProgramGenerator(testIdl, options);
    final programCode = programGenerator.generate();
    print('Program code:');
    print(programCode);

    // Test instruction generator
    final instructionGenerator = InstructionGenerator(testIdl, options);
    final instructionCode = instructionGenerator.generate();
    print('Instruction code:');
    print(instructionCode);

    // Test account generator
    final accountGenerator = AccountGenerator(testIdl, options);
    final accountCode = accountGenerator.generate();
    print('Account code:');
    print(accountCode);

    expect(programCode, isNotEmpty);
    expect(instructionCode, isNotEmpty);
    expect(accountCode, isNotEmpty);
  });
}
