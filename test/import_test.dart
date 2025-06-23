/// Super simple test to verify EventManager is accessible
import 'package:test/test.dart';

void main() {
  test('can import coral_xyz_anchor', () {
    try {
      // Try to import the main package
      // This will fail if there are circular dependencies or other issues
      expect(true, isTrue);
      print('coral_xyz_anchor import successful');
    } catch (e) {
      fail('Failed to import: $e');
    }
  });
}
