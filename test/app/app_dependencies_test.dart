import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

ExpenseDraft _draft(String title) => ExpenseDraft(
  editingExpenseId: null,
  title: title,
  amountExpression: '',
  description: '',
  categoryId: null,
  eventIds: const {},
  paymentMethodId: 1,
  currencyCode: 'INR',
  pickedWallClock: null,
  touched: const {DraftField.title},
  itemizeLine: null,
  itemizeLabels: const [],
  itemizeTerms: const [],
  updatedAt: DateTime.utc(2026),
);

/// The draft parts of AppDependencies (phase-4.md §6.4, R10).
void main() {
  test('probe reads the draft slot and leaves a malformed row alone', () async {
    final db = await openMigratedDatabase();
    await db.insert('expense_draft', {
      'id': 1,
      'form_json': 'not json',
      'updated_at': 1,
    });
    await AppDependencies.probe(db, deviceCurrency: 'INR');
    expect(await db.query('expense_draft'), hasLength(1));
  });

  test('probe refuses a database without the draft table', () async {
    final db = await openMigratedDatabase();
    await db.execute('DROP TABLE expense_draft');
    await expectLater(
      AppDependencies.probe(db, deviceCurrency: 'INR'),
      throwsA(isA<DatabaseException>()),
    );
  });

  // That close() writes what is due first is in
  // expense_draft_repository_test ("close writes what is due").
  test('closeForRestore closes the drafts, then the database; a change '
      'after is refused without an error', () async {
    final deps = await openTestDependencies();
    deps.drafts.update(_draft('typed'));
    await deps.closeForRestore();
    expect(deps.database.isOpen, isFalse);
    // A change after the close is refused, never written anywhere.
    deps.drafts.update(_draft('after'));
    await deps.drafts.flush();
  });

  test('a restart builds a new draft repository: the old memory copy is '
      'not carried over', () async {
    final deps = await openTestDependencies();
    deps.drafts.update(_draft('old database'));
    final restarted = AppDependencies.forDatabase(
      deps.database,
      deviceCurrency: 'INR',
    );
    expect(identical(restarted.drafts, deps.drafts), isFalse);
    expect(await restarted.drafts.read(), isNull, reason: 'never flushed');
  });
}
