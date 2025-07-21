import 'package:logging/logging.dart';

import 'lib/coral_xyz_anchor.dart';

final _logger = Logger('TestIdlAddress');

void main() async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  // Test with a known program ID
  final programId = PublicKey.fromBase58('11111111111111111111111111111112');

  // Calculate IDL address using our fixed implementation
  final idlAddress = await IdlUtils.getIdlAddress(programId);
  _logger.info('Program ID: ${programId.toBase58()}');
  _logger.info('IDL Address: ${idlAddress.toBase58()}');

  // Also test with a different program ID
  final programId2 =
      PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
  final idlAddress2 = await IdlUtils.getIdlAddress(programId2);
  _logger.info('Program ID 2: ${programId2.toBase58()}');
  _logger.info('IDL Address 2: ${idlAddress2.toBase58()}');
}
