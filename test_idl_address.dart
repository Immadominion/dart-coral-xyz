import 'lib/coral_xyz_anchor.dart';

void main() async {
  // Test with a known program ID
  final programId = PublicKey.fromBase58('11111111111111111111111111111112');

  // Calculate IDL address using our fixed implementation
  final idlAddress = await IdlUtils.getIdlAddress(programId);
  print('Program ID: ${programId.toBase58()}');
  print('IDL Address: ${idlAddress.toBase58()}');

  // Also test with a different program ID
  final programId2 =
      PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
  final idlAddress2 = await IdlUtils.getIdlAddress(programId2);
  print('Program ID 2: ${programId2.toBase58()}');
  print('IDL Address 2: ${idlAddress2.toBase58()}');
}
