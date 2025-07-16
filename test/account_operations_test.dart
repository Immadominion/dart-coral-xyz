import 'package:test/test.dart';
import 'package:coral_xyz_anchor/src/program/namespace/account_operations.dart';

void main() {
  group('AccountOperations Basic Types', () {
    test('can create IdlAccount', () {
      final idlAccount = IdlAccount(
        name: 'TestAccount',
        type: <String, dynamic>{'kind': 'struct', 'fields': <dynamic>[]},
        discriminator: [1, 2, 3, 4, 5, 6, 7, 8],
      );

      expect(idlAccount.name, equals('TestAccount'));
      expect(idlAccount.discriminator, equals([1, 2, 3, 4, 5, 6, 7, 8]));
    });

    test('can create AccountFilter', () {
      final filter = AccountFilter(
        field: 'amount',
        value: 1000,
        operator: 'gte',
      );

      expect(filter.field, equals('amount'));
      expect(filter.value, equals(1000));
      expect(filter.operator, equals('gte'));
    });

    test('can create AccountSubscriptionConfig', () {
      final config = AccountSubscriptionConfig(
        enabled: true,
        reconnectInterval: Duration(seconds: 30),
      );

      expect(config.enabled, equals(true));
      expect(config.reconnectInterval, equals(Duration(seconds: 30)));
    });

    test('AccountRelationshipType enum has all values', () {
      expect(AccountRelationshipType.values.length, greaterThan(0));
      expect(
          AccountRelationshipType.values
              .contains(AccountRelationshipType.owner),
          isTrue);
      expect(
          AccountRelationshipType.values
              .contains(AccountRelationshipType.authority),
          isTrue);
    });

    test('AccountOwnedByWrongProgramError can be created', () {
      final error = AccountOwnedByWrongProgramError('Test error message');
      expect(error.message, equals('Test error message'));
    });

    test('AccountDiscriminatorMismatchError can be created', () {
      final error =
          AccountDiscriminatorMismatchError('Test discriminator error');
      expect(error.message, equals('Test discriminator error'));
    });
  });
}
