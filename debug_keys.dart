import 'lib/coral_xyz_anchor.dart';

void main() {
  print('System Program: ${PublicKey.systemProgram.toBase58()}');
  print('Default Pubkey: ${PublicKey.defaultPubkey.toBase58()}');
  print(
      'System == Default: ${PublicKey.systemProgram == PublicKey.defaultPubkey}');

  // Test the isDefaultAddress function
  print(
      'isDefaultAddress(systemProgram): ${AddressValidator.isDefaultAddress(PublicKey.systemProgram)}');
  print(
      'isDefaultAddress(defaultPubkey): ${AddressValidator.isDefaultAddress(PublicKey.defaultPubkey)}');

  // Test the labelAddress function
  print(
      'labelAddress(systemProgram): ${AddressFormatter.labelAddress(PublicKey.systemProgram)}');
  print(
      'labelAddress(defaultPubkey): ${AddressFormatter.labelAddress(PublicKey.defaultPubkey)}');
}
