import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/payment_method_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/domain/models/payment_method.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late TestClock clock;
  late SettingsRepository settings;
  late PaymentMethodRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock();
    settings = SettingsRepository(db, deviceCurrency: 'INR');
    repository = PaymentMethodRepository(
      db,
      settings: settings,
      now: clock.call,
    );
  });

  Future<PaymentMethod> builtin(String key) async =>
      (await repository.all()).firstWhere((m) => m.builtinKey == key);
  Future<PaymentMethod> byId(int id) async =>
      (await repository.all()).singleWhere((m) => m.id == id);

  test('all returns the 4 seeded built-ins', () async {
    expect((await repository.all()).map((m) => m.builtinKey), [
      'cash',
      'upi',
      'debit_card',
      'credit_card',
    ]);
  });

  group('add / update', () {
    test('add returns exactly what all() reads back', () async {
      final added = await repository.add(name: 'Bank credit card', emoji: '💳');
      expect(added.createdAt, clock.now);
      expect(await byId(added.id), added);
    });

    test('update saves name and emoji and moves updated_at only', () async {
      final upi = await builtin('upi');
      clock.advance(const Duration(minutes: 1));
      final saved = await repository.update(
        upi.copyWith(name: 'GPay', emoji: '📲'),
      );
      expect(saved.updatedAt, clock.now);
      expect(saved.createdAt, upi.createdAt);
      expect(await byId(upi.id), saved);
    });

    test('update throws when the method no longer exists', () async {
      final added = await repository.add(name: 'Wallet', emoji: '👛');
      await repository.delete(added.id);
      expect(() => repository.update(added), throwsStateError);
    });
  });

  group('delete', () {
    test('deletes a method that is not the default', () async {
      final upi = await builtin('upi');
      await repository.delete(upi.id);
      expect((await repository.all()).any((m) => m.id == upi.id), isFalse);
    });

    test('refuses the stored default', () async {
      final upi = await builtin('upi');
      await settings.setDefaultPaymentMethodId(upi.id);
      await expectLater(
        repository.delete(upi.id),
        throwsA(isA<CannotDeleteDefault>()),
      );
      expect(await byId(upi.id), upi, reason: 'nothing was deleted');
    });

    test(
      'refuses cash when nothing is stored, because cash is then the default',
      () async {
        final cash = await builtin('cash');
        await expectLater(
          repository.delete(cash.id),
          throwsA(isA<CannotDeleteDefault>()),
        );
      },
    );

    test('allows cash once another method is the default', () async {
      final cash = await builtin('cash');
      await settings.setDefaultPaymentMethodId((await builtin('upi')).id);
      await repository.delete(cash.id);
      expect((await repository.all()).any((m) => m.id == cash.id), isFalse);
    });

    test('with cash gone, refuses the fallback default (the first by id)', () async {
      final upi = await builtin('upi');
      await settings.setDefaultPaymentMethodId(upi.id);
      await repository.delete((await builtin('cash')).id);
      // Settings row now removed: the fallback becomes the first method by id.
      await db.delete('settings');
      await expectLater(
        repository.delete(upi.id),
        throwsA(isA<CannotDeleteDefault>()),
      );
    });

    test('the last remaining method can never be deleted', () async {
      final methods = await repository.all();
      final keep = methods.last;
      await settings.setDefaultPaymentMethodId(keep.id);
      for (final method in methods.where((m) => m.id != keep.id)) {
        await repository.delete(method.id);
      }
      await db.delete('settings'); // Even if the setting is lost.
      await expectLater(
        repository.delete(keep.id),
        throwsA(isA<CannotDeleteDefault>()),
      );
      expect(await repository.all(), hasLength(1));
    });

    test(
      'the setting and the table never disagree after a refused delete',
      () async {
        final upi = await builtin('upi');
        await settings.setDefaultPaymentMethodId(upi.id);
        await expectLater(
          repository.delete(upi.id),
          throwsA(isA<CannotDeleteDefault>()),
        );
        expect((await settings.load()).defaultPaymentMethodId, upi.id);
      },
    );
  });

  group('moveExpensesAndDelete', () {
    Future<List<int>> methodsOfExpenses() async => [
      for (final row in await db.query('expenses', orderBy: 'id'))
        row['payment_method_id']! as int,
    ];

    test('moves every expense, binned ones included, then deletes', () async {
      await insertExpenseRow(db, paymentMethodId: 2);
      await insertExpenseRow(db, paymentMethodId: 2, deletedAt: 5);
      await insertExpenseRow(db, paymentMethodId: 1);

      await repository.moveExpensesAndDelete(2, toId: 3);

      expect(await methodsOfExpenses(), [3, 3, 1]);
      expect((await repository.all()).any((m) => m.id == 2), isFalse);
    });

    test('refuses the default and changes nothing', () async {
      final cash = await builtin('cash');
      await insertExpenseRow(db, paymentMethodId: cash.id);
      await insertExpenseRow(db, paymentMethodId: cash.id, deletedAt: 5);

      await expectLater(
        repository.moveExpensesAndDelete(cash.id, toId: 2),
        throwsA(isA<CannotDeleteDefault>()),
      );
      expect(await methodsOfExpenses(), [cash.id, cash.id]);
      expect(await repository.all(), hasLength(4));
    });

    test('the default onto itself is an ArgumentError, checked before the '
        'default', () async {
      final cash = await builtin('cash');
      await expectLater(
        repository.moveExpensesAndDelete(cash.id, toId: cash.id),
        throwsArgumentError,
      );
      expect(await repository.all(), hasLength(4));
    });

    test('changes nothing when the target was deleted meanwhile', () async {
      await insertExpenseRow(db, paymentMethodId: 2);
      await repository.delete(3);

      await expectLater(
        repository.moveExpensesAndDelete(2, toId: 3),
        throwsA(isA<DatabaseException>()),
      );
      expect(await methodsOfExpenses(), [2]);
      expect((await repository.all()).any((m) => m.id == 2), isTrue);
    });
  });
}
