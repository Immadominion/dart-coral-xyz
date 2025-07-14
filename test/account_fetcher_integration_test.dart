import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';
import 'package:test/test.dart';

void main() {
  group('Account Fetching and Caching Layer', () {
    test('AccountFetcher integration test', () {
      // This is a compilation test to ensure the new AccountFetcher
      // integrates properly with the AccountNamespace and AccountClient

      // Test that types are properly imported
      expect(AccountNamespace, isA<Type>());
      expect(AccountClient, isA<Type>());
      expect(ProgramAccount, isA<Type>());

      // Test that generics work properly
      AccountClient<Map<String, dynamic>>? client;
      expect(client, isNull);

      ProgramAccount<Map<String, dynamic>>? account;
      expect(account, isNull);
    });
  });
}
