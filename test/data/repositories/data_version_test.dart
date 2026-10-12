import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';

import '../../helpers/test_database.dart';

/// The category, payment method and event writes bump the same `DataVersion` as
/// the expense writes. The expense repository's own writes are covered in its
/// test.
void main() {
  late AppDependencies deps;

  setUp(() async => deps = await openTestDependencies());

  Future<void> expectBump(String name, Future<void> Function() action) async {
    final before = deps.dataVersion.value;
    await action();
    expect(deps.dataVersion.value, greaterThan(before), reason: name);
  }

  Future<void> expectNoBump(String name, Future<void> Function() action) async {
    final before = deps.dataVersion.value;
    await action();
    expect(deps.dataVersion.value, before, reason: name);
  }

  test('category writes bump it; reads do not', () async {
    final categories = deps.categories;
    final food = (await categories.all()).first;
    await expectBump('add', () => categories.add(name: 'Pets', emoji: '🐶'));
    await expectBump('update', () => categories.update(food));
    await expectBump(
      'moveExpensesAndDelete',
      () => categories.moveExpensesAndDelete(food.id, toId: 2),
    );
    await expectBump('delete', () => categories.delete(3));
    await expectNoBump('all', categories.all);
    await expectNoBump('usage', () => categories.usage(2));
  });

  test('payment method writes bump it; reads do not', () async {
    final methods = deps.paymentMethods;
    final upi = (await methods.all()).firstWhere((m) => m.builtinKey == 'upi');
    await expectBump('add', () => methods.add(name: 'Wallet', emoji: '👛'));
    await expectBump('update', () => methods.update(upi));
    await expectBump(
      'moveExpensesAndDelete',
      () => methods.moveExpensesAndDelete(upi.id, toId: 3),
    );
    await expectBump('delete', () => methods.delete(4));
    await expectNoBump('all', methods.all);
    await expectNoBump('usage', () => methods.usage(3));
  });

  test('event writes bump it; reads do not', () async {
    final events = deps.events;
    final trip = (await events.all()).first;
    await expectBump('add', () => events.add(name: 'Wedding', emoji: '💒'));
    await expectBump('update', () => events.update(trip));
    await expectBump('setArchived', () => events.setArchived(trip.id, true));
    await expectBump('delete', () => events.delete(trip.id));
    await expectNoBump('all', events.all);
    await expectNoBump('usage', () => events.usage(2));
  });

  test('settings writes are not data changes', () async {
    await expectNoBump(
      'setDefaultCurrency',
      () => deps.settings.setDefaultCurrency('USD'),
    );
  });
}
