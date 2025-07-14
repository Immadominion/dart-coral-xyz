

import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Coral XYZ Anchor', () {
    test('package version is defined', () {
      expect(packageVersion, isNotNull);
      expect(packageVersion, '0.1.0');
    });

    test('supported IDL version is defined', () {
      expect(supportedIdlVersion, isNotNull);
      expect(supportedIdlVersion, '0.1.0');
    });
  });
}
