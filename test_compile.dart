// Simple test file to check compilation
import 'package:logging/logging.dart';

import 'lib/coral_xyz_anchor.dart' as anchor;

final _logger = Logger('TestCompile');

void main() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  _logger.info('Library compiles successfully!');
  _logger.info('Anchor library loaded: ${anchor.AnchorProvider}');
}
