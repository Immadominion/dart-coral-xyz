/// Simple test to check basic imports and functionality
import 'package:test/test.dart';
import '../lib/src/program/context.dart';

void main() {
  test('simple context test', () {
    const context = Context<DynamicAccounts>();
    expect(context.accounts, isNull);
  });
}
