import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  // Debug output for key comparison
  // ignore: avoid_print
  print('System Program: ${PublicKey.systemProgram.toBase58()}');
  // ignore: avoid_print
  print('Default Pubkey: ${PublicKey.defaultPubkey.toBase58()}');
  // ignore: avoid_print
  print(
    'System == Default: ${PublicKey.systemProgram == PublicKey.defaultPubkey}',
  );

  // Test the isDefaultAddress function
  // ignore: avoid_print
  print(
    'isDefaultAddress(systemProgram): ${AddressValidator.isDefaultAddress(PublicKey.systemProgram)}',
  );
  // ignore: avoid_print
  print(
    'isDefaultAddress(defaultPubkey): ${AddressValidator.isDefaultAddress(PublicKey.defaultPubkey)}',
  );

  // Test the labelAddress function
  // ignore: avoid_print
  print(
    'labelAddress(systemProgram): ${AddressFormatter.labelAddress(PublicKey.systemProgram)}',
  );
  // ignore: avoid_print
  print(
    'labelAddress(defaultPubkey): ${AddressFormatter.labelAddress(PublicKey.defaultPubkey)}',
  );
}
