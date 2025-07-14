import 'package:coral_xyz_anchor/src/coder/borsh_utils.dart';
import 'package:coral_xyz_anchor/src/coder/discriminator_computer.dart';

void main() {
  print('Testing discriminator computation...');

  // Test with existing BorshUtils
  final existingAccount = BorshUtils.createAccountDiscriminator('Data');
  print('BorshUtils account discriminator for "Data": $existingAccount');

  final existingInstruction =
      BorshUtils.createInstructionDiscriminator('initialize');
  print(
      'BorshUtils instruction discriminator for "initialize": $existingInstruction',);

  // Test with new DiscriminatorComputer
  final newAccount = DiscriminatorComputer.computeAccountDiscriminator('Data');
  print('DiscriminatorComputer account discriminator for "Data": $newAccount');

  final newInstruction =
      DiscriminatorComputer.computeInstructionDiscriminator('initialize');
  print(
      'DiscriminatorComputer instruction discriminator for "initialize": $newInstruction',);

  // Test hex representation
  print(
      'BorshUtils account hex: ${BorshUtils.createAccountDiscriminator('Data').map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',);
  print(
      'DiscriminatorComputer account hex: ${DiscriminatorComputer.discriminatorToHex(newAccount)}',);
}
