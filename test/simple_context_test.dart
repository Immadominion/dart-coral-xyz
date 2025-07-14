/// Simple test to check basic imports and functionality
library;
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  test('simple context test', () {
    const context = Context<DynamicAccounts>();
    expect(context.accounts, isNull);
  });
}
