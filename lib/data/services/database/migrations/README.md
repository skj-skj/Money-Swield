# Database migrations

Rails-style migrations for the app's SQLite database. They run on app start,
behind the migration screen.

## Create one

```sh
dart tool/new_migration.dart add_currency_to_expenses
```

This creates `<unix time>_add_currency_to_expenses.dart` here and registers it
in `all_migrations.dart`. Fill in `up` and `down`.

**Never edit or delete a migration that has been released.** Write a new one.

## Cheat sheet (`m` is the `Migrator`)

```dart
// Tables
await m.createTable('expenses', (t) {          // adds `id` automatically
  t.text('title', nullable: false);
  t.real('amount', nullable: false, defaultValue: 0);
  t.integer('spent_at', nullable: false);      // epoch milliseconds
  t.text('receipt_number', unique: true);
  t.references('category_id', toTable: 'categories', onDelete: ForeignKeyAction.cascade);
  t.index(['spent_at']);
});
await m.createTable('tags_expenses', id: false, (t) { ...; t.primaryKey(['tag_id', 'expense_id']); });
await m.dropTable('expenses');

// Columns (each rebuilds the table and keeps all rows)
await m.addColumn('expenses', 'currency', SqliteType.text);
await m.removeColumn('expenses', 'note');
await m.renameColumn('expenses', 'note', 'description');
await m.changeColumn('expenses', 'amount', SqliteType.integer, nullable: false);

// Several changes, one rebuild
await m.changeTable('expenses', (t) {
  t.renameColumn('note', 'description');
  t.addColumn('paid', SqliteType.integer, nullable: false, defaultValue: true);
  t.removeIndex(columns: ['title']);
});

// References and indexes
await m.addReference('expenses', 'account_id', toTable: 'accounts');
await m.removeReference('expenses', 'account_id');
await m.addIndex('expenses', ['category_id', 'spent_at'], unique: true);
await m.removeIndex('expenses', columns: ['category_id', 'spent_at']);

// Data, for backfills (`where` matches by equality; null means IS NULL)
final rows = await m.select('expenses', columns: ['id', 'amount'], where: {'currency': null});
await m.insert('monthly_spend', {'month': '2026-09', 'total': 120.5});
await m.update('expenses', {'currency': 'INR'}, where: {'id': 7});
await m.delete('expenses', where: {'amount': 0});
await m.count('expenses');

// Asking the device and the user
m.locale.countryCode;                                    // e.g. 'IN'
await m.askChoice('Which currency are your expenses in?', ['INR', 'USD']);
await m.askText('Name for your default account?', initialValue: 'Cash');
```

## Adding a required column to a table that has rows

SQLite can't invent values for existing rows, so do it in three steps:

```dart
await m.addColumn('expenses', 'currency', SqliteType.text);          // 1. nullable
final currency = await m.askChoice('Which currency...?', ['INR', 'USD']);
await m.update('expenses', {'currency': currency});                  // 2. backfill
await m.changeColumn('expenses', 'currency', SqliteType.text, nullable: false); // 3. require it
```

## What protects the data

- The database file is copied to `databases/backups/` before any pending
  migration runs. The copy is deleted only after every migration and SQLite's
  integrity check pass.
- Each migration runs in its own transaction: if it throws, none of its
  changes are kept, and the screen shows which migration failed.
- Foreign keys are checked before each migration commits.
- An older app refuses to open a database changed by a newer one.
- `test/data/services/database/migrations/all_migrations_test.dart` runs every
  migration `up -> down -> up` and checks each file is registered.
