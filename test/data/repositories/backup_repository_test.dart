import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/backup_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/data/services/backup/backup_archive.dart';
import 'package:my_expense_tracker_app/data/services/database/database_checks.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/file_database.dart';
import '../../helpers/test_database.dart';

void main() {
  late FileDatabases files;
  late Database live;

  final now = DateTime.utc(2026, 10, 3, 8, 35, 12);

  BackupRepository backupsFor(Database db) => BackupRepository(
    db,
    appDatabase: files.appDatabase(),
    settings: SettingsRepository(db, deviceCurrency: 'INR'),
    now: () => now,
  );

  /// Backs up [live] and extracts the zip's database to a file of its own.
  Future<({BackupFile zip, String copy})> backUp({Database? db}) async {
    final zip = await backupsFor(db ?? live)
        .createBackup(appVersion: '9.9.9+9');
    final copy = p.join(files.root.path, 'extracted-${zip.hashCode}.db');
    await BackupArchive.read(zip.path, extractDatabaseTo: copy);
    return (zip: zip, copy: copy);
  }

  /// Whether the cache/backup folder holds nothing but [allowed] files.
  List<String> backupFolderContents() {
    final folder = Directory(files.paths.backupWorkFolder);
    if (!folder.existsSync()) return [];
    return [for (final e in folder.listSync()) p.basename(e.path)];
  }

  group('with the real schema', () {
    setUp(() async {
      files = await FileDatabases.create();
      live = await files.openLive();
    });

    test('every table is copied row for row, with schema, indexes, '
        'user_version and valid foreign keys', () async {
      final active = await insertExpenseRow(live, eventIds: {1, 2});
      await insertExpenseRow(live, deletedAt: 1000, eventIds: {3});
      await live.insert('categories', {
        'name': 'Pets',
        'emoji': '🐶',
        'created_at': 1,
        'updated_at': 1,
      });
      await live.execute('PRAGMA user_version = 7');

      final backup = await backUp();

      final source = await dumpTables(live);
      final copied = await files.withDatabase(backup.copy, dumpTables);
      expect(copied.keys, containsAll(['expenses', 'schema_migrations']));
      expect(copied, source);
      expect(
        copied['expenses']!.where((r) => r['deleted_at'] != null),
        hasLength(1),
        reason: 'binned expenses are part of the backup',
      );
      expect(copied['expense_events'], hasLength(3));
      expect(active, 1);

      expect(await files.withDatabase(backup.copy, schemaOf), {
        ...await schemaOf(live),
      });
      await files.withDatabase(backup.copy, (db) async {
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          'AND sql IS NOT NULL',
        );
        expect(indexes, isNotEmpty);
        expect(
          (await db.rawQuery('PRAGMA user_version')).single.values.single,
          7,
        );
        await checkForeignKeys(db);
        await checkIntegrity(db);
      });
    });

    test(
      'F8: recurring items, prices, events and payment links are copied '
      'row for row; the copy keeps the SET NULL and the unique index',
      () async {
        final item = await insertRecurringRow(live, eventIds: {1, 2});
        await live.insert('recurring_amounts', {
          'recurring_expense_id': item,
          'amount_minor': 69900,
          'effective_from': '2027-01-31',
          'created_at': 1,
          'updated_at': 1,
        });
        final archived = await insertRecurringRow(live, archivedAt: 9);
        final payment = await insertExpenseRow(live, eventIds: {1});
        await live.update(
          'expenses',
          {'recurring_expense_id': item, 'recurring_due_on': '2026-01-31'},
          where: 'id = ?',
          whereArgs: [payment],
        );

        final backup = await backUp();

        final source = await dumpTables(live);
        final copied = await files.withDatabase(backup.copy, dumpTables);
        for (final table in [
          'recurring_expenses',
          'recurring_amounts',
          'recurring_expense_events',
          'expenses',
        ]) {
          expect(copied[table], source[table], reason: table);
        }
        expect(copied['recurring_expenses'], hasLength(2));
        await files.withDatabase(backup.copy, (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await checkForeignKeys(db);
          // The unique index came along: a second payment 0 is refused.
          await expectLater(
            db.insert('expenses', {
              'title': 'x',
              'amount_minor': 1,
              'currency_code': 'INR',
              'occurred_at': 0,
              'utc_offset_minutes': 0,
              'occurred_on': '2026-01-31',
              'category_id': 1,
              'payment_method_id': 1,
              'recurring_expense_id': item,
              'recurring_due_on': '2026-01-31',
              'created_at': 0,
              'updated_at': 0,
            }),
            throwsA(isA<DatabaseException>()),
          );
          // And SET NULL: deleting the item keeps its payment.
          await db.delete(
            'recurring_expenses',
            where: 'id = ?',
            whereArgs: [item],
          );
          final kept = await db.query(
            'expenses',
            where: 'id = ?',
            whereArgs: [payment],
          );
          expect(kept.single['recurring_expense_id'], isNull);
          expect(archived, isPositive);
        });
      },
    );

    test('the zip is in cache/backup, named by the local time', () async {
      final backup = await backUp();
      expect(p.dirname(backup.zip.path), files.paths.backupWorkFolder);
      expect(backup.zip.name, BackupRepository.backupFileName(now));
      expect(
        backup.zip.name,
        matches(RegExp(r'^expense-tracker-backup-\d{8}-\d{6}\.zip$')),
      );
    });

    test('the manifest records the newest migration and app version', () async {
      final zip = await backupsFor(live).createBackup(appVersion: '2.0.0+5');
      final manifest = await BackupArchive.read(
        zip.path,
        extractDatabaseTo: p.join(files.root.path, 'x.db'),
      );
      final newest = allMigrations
          .map((m) => m.version)
          .reduce((a, b) => a > b ? a : b);
      expect(manifest.schemaVersion, newest);
      expect(manifest.appVersion, '2.0.0+5');
      expect(manifest.createdAt, now);
    });

    test('a copy of a fresh database works', () async {
      final backup = await backUp();
      expect(
        await files.withDatabase(backup.copy, dumpTables),
        await dumpTables(live),
      );
    });

    test('AUTOINCREMENT counters survive: a permanently deleted id is not '
        'reused after a restore', () async {
      final ids = [for (var i = 0; i < 3; i++) await insertExpenseRow(live)];
      await live.delete('expenses', where: 'id = ?', whereArgs: [ids.last]);
      final categoryId = await live.insert('categories', {
        'name': 'Temp',
        'emoji': '🧪',
        'created_at': 1,
        'updated_at': 1,
      });
      await live.delete('categories', where: 'id = ?', whereArgs: [categoryId]);

      final backup = await backUp();

      final restored = await files.open(backup.copy);
      final newExpense = await insertExpenseRow(restored);
      expect(newExpense, ids.last + 1, reason: 'id ${ids.last} was reused');
      final newCategory = await restored.insert('categories', {
        'name': 'New',
        'emoji': '🆕',
        'created_at': 1,
        'updated_at': 1,
      });
      expect(newCategory, categoryId + 1);
    });

    test('an insert while the backup runs is fully in the copy or fully '
        'out: never an expense without its event rows', () async {
      final backup = backUp();
      // Queued while the backup runs; each is one transaction.
      final writes = [
        for (var i = 0; i < 40; i++)
          live.transaction((txn) => insertExpenseRow(txn, eventIds: {1, 2, 3})),
      ];
      final copy = (await backup).copy;
      await Future.wait(writes);

      await files.withDatabase(copy, (db) async {
        final expenses = await db.query('expenses');
        for (final expense in expenses) {
          final links = await db.query(
            'expense_events',
            where: 'expense_id = ?',
            whereArgs: [expense['id']],
          );
          expect(links, hasLength(3), reason: 'expense ${expense['id']}');
        }
        expect(
          await db.query('expense_events'),
          hasLength(expenses.length * 3),
        );
      });
    });

    test('a stale copy left in cache/backup by a backup cut short doesn\'t '
        'block the next one', () async {
      final stale = files.paths.backupCopy;
      await files.migrate(stale);
      await File('$stale-journal').writeAsString('leftover');
      expect(File(stale).existsSync(), isTrue);

      final backup = await backUp();

      expect(
        await files.withDatabase(backup.copy, dumpTables),
        await dumpTables(live),
      );
    });

    test('a second backup on the same connection works', () async {
      await insertExpenseRow(live);
      await backUp();
      await insertExpenseRow(live);
      final second = await backUp();
      expect(
        await files.withDatabase(second.copy, (db) => db.query('expenses')),
        hasLength(2),
      );
    });

    test('a trigger in the source fails the backup clearly and leaves '
        'nothing in cache/backup', () async {
      await live.execute(
        'CREATE TRIGGER t AFTER INSERT ON categories BEGIN SELECT 1; END',
      );
      await expectLater(
        backupsFor(live).createBackup(appVersion: '1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('trigger "t"'),
          ),
        ),
      );
      expect(backupFolderContents(), isEmpty);
    });

    test('a view in the source fails the backup too', () async {
      await live.execute('CREATE VIEW v AS SELECT * FROM categories');
      await expectLater(
        backupsFor(live).createBackup(appVersion: '1'),
        throwsA(isA<StateError>()),
      );
      expect(backupFolderContents(), isEmpty);
    });

    test(
      'a table named sqliteXdata is copied (catches a LIKE filter)',
      () async {
        await live.execute('CREATE TABLE sqliteXdata (v TEXT)');
        await live.insert('sqliteXdata', {'v': 'kept'});
        final backup = await backUp();
        expect(
          await files.withDatabase(
            backup.copy,
            (db) => db.query('sqliteXdata'),
          ),
          [
            {'v': 'kept'},
          ],
        );
      },
    );

    test('a copy that fails inside the transaction still detaches, and the '
        'connection keeps working', () async {
      // An expense pointing to a missing category, written with foreign
      // keys off. Copying it breaks the copy's (deferred) foreign keys. (A
      // broken CHECK row wouldn't do: INSERT … SELECT * between identical
      // tables copies raw records without re-checking CHECK constraints.)
      // Left to COMMIT, this used to kill the app's connection.
      await live.execute('PRAGMA foreign_keys = OFF');
      await insertExpenseRow(live, categoryId: 9999);
      await live.execute('PRAGMA foreign_keys = ON');

      await expectLater(
        backupsFor(live).createBackup(appVersion: '1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Foreign key check failed'),
          ),
        ),
      );

      final attached = await live.rawQuery('PRAGMA database_list');
      expect(attached.map((r) => r['name']), isNot(contains('backup')));
      final id = await insertExpenseRow(live);
      expect(
        await live.query('expenses', where: 'id = ?', whereArgs: [id]),
        hasLength(1),
      );
      expect(backupFolderContents(), isEmpty);

      // And the next backup fails for the same reason, not "database backup
      // is already in use".
      await expectLater(
        backupsFor(live).createBackup(appVersion: '1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Foreign key check failed'),
          ),
        ),
      );
    });

    test('active expense count leaves out the bin', () async {
      await insertExpenseRow(live);
      await insertExpenseRow(live);
      await insertExpenseRow(live, deletedAt: 5);
      expect(await backupsFor(live).activeExpenseCount(), 2);
    });

    test('deleteBackupFiles empties cache/backup', () async {
      await backUp();
      expect(backupFolderContents(), isNotEmpty);
      await backupsFor(live).deleteBackupFiles();
      expect(Directory(files.paths.backupWorkFolder).existsSync(), isFalse);
    });
  });

  group('like Android', () {
    setUp(() async {
      files = await FileDatabases.create(androidLike: true);
      live = await files.openLive();
    });

    test('android_metadata is in the source and Android adds it to the new '
        'copy: the backup works and keeps one row', () async {
      expect(await live.query('android_metadata'), hasLength(1));

      final backup = await backUp();

      final rows = await files.withDatabase(
        backup.copy,
        (db) => db.query('android_metadata'),
      );
      expect(rows, hasLength(1));
    });
  });
}
