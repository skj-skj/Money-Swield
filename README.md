# Money Swield

An offline expense tracker for Android, built with Flutter.

The data is stored in a SQLite database in the app's package directory,
`/sdcard/Android/data/<package-name>/` (app-specific external storage; Android
deletes it when the app is uninstalled).

## Getting started

```sh
flutter pub get
flutter run
```

## Running the tests

```sh
flutter test
```

Run a single file or folder by passing its path:

```sh
flutter test test/data/services/database/migration/migrator_test.dart
flutter test test/data/services/database/
```

The database tests use a real SQLite engine (through `sqflite_common_ffi`), so
they run on your development machine without a phone or emulator.

## Database migrations

The database schema is changed only through Rails-style migrations. Pending
migrations run when the app starts, behind a progress screen, after the
database has been backed up.

Create a new migration from the project root:

```sh
dart tool/new_migration.dart add_currency_to_expenses
```

This creates
`lib/data/services/database/migrations/<unix time>_add_currency_to_expenses.dart`
and registers it in `all_migrations.dart`. Fill in its `up` and `down` methods,
then run `flutter test`. The test suite checks that every migration is
registered and can run `up -> down -> up`.

Never edit or delete a migration that has already been released; write a new
one instead.

**Before writing a migration, read the
[database migrations guide](lib/data/services/database/migrations/README.md)**.
It lists every available operation, explains how to backfill data, and describes
how user data is protected.

## License

Copyright (C) 2026 skj-skj. Licensed under the
[GNU GPL v3.0 or later](LICENSE), with no warranty.

One exception: the `play` flavor uses Google's closed-source ML Kit, and
you're allowed to share builds that include it (GPL section 7).

The name "Money Swield" and its logo are not covered by the GPL; see
[TRADEMARKS.md](TRADEMARKS.md).
