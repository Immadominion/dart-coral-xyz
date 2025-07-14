import 'dart:typed_data';

import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  // Test that DataConverter is available from the main export
  final testData = Uint8List.fromList([1, 2, 3, 4]);
  final hex = DataConverter.encodeHex(testData);
  print('DataConverter working: $hex');

  // Test that AddressValidator is available
  final isValid =
      AddressValidator.isValidBase58('11111111111111111111111111111111');
  print('AddressValidator working: $isValid');
}
