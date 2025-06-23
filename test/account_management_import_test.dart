import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('Account Management Import Test', () {
    test('should import AccountSubscriptionManager', () {
      expect(AccountSubscriptionManager, isNotNull);
    });

    test('should import AccountCacheManager', () {
      expect(AccountCacheManager, isNotNull);
    });

    test('should create AccountSubscriptionManager instance', () {
      final connection = Connection('http://localhost:8899');
      final manager = AccountSubscriptionManager(connection: connection);
      expect(manager, isNotNull);
    });

    test('should create AccountCacheManager instance', () {
      final cacheManager = AccountCacheManager();
      expect(cacheManager, isNotNull);
    });
  });
}
