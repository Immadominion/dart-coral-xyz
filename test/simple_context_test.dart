/// Simple test to check basic imports and functionality
library;

import 'package:coral_xyz/coral_xyz_anchor.dart';
import 'package:test/test.dart';

void main() {
  test('simple context test', () {
    final accounts = DynamicAccounts();
    final context = Context<DynamicAccounts>(accounts: accounts);
    expect(context.accounts, isNotNull);
  });
}
