import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:money_swield/app/restore_tools.dart';
import 'package:money_swield/data/repositories/restore_repository.dart';
import 'package:money_swield/data/repositories/settings_repository.dart';
import 'package:money_swield/data/services/backup/pre_restore_copy.dart';
import 'package:money_swield/data/services/database/migration/migration_runner.dart';
import 'package:money_swield/data/services/database/migrations/all_migrations.dart';
import 'package:money_swield/data/services/document_service.dart';
import 'package:money_swield/domain/models/app_settings.dart';
import 'package:money_swield/domain/models/app_theme_mode.dart';
import 'package:money_swield/domain/models/restore_candidate.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/file_database.dart';
import '../../helpers/test_database.dart';
import '../services/backup/zip_test_helpers.dart';
import '../services/database/migration/test_helpers.dart';

/// The first schema: settings, categories, payment methods, events.
final firstSchemaMigrations = allMigrations.take(4).toList();

void main() {
  late FileDatabases files;
  late RestoreRepository repo;

  Future<void> setUpFiles({bool androidLike = false}) async {
    files = await FileDatabases.create(androidLike: androidLike);
    repo = RestoreTools(
      appDatabase: files.appDatabase(),
      documents: const ChannelDocumentService(),
      deviceCurrency: 'INR',
    ).repository;
  }

  /// A migrated database file at a path of its own, filled by [fill].
  Future<String> sourceDatabase({
    List<dynamic>? migrations,
    Future<void> Function(Database db)? fill,
  }) async {
    final path = p.join(files.root.path, 'source', 'source.db');
    await files.migrate(path, migrations: migrations?.cast());
    if (fill != null) await files.withDatabase(path, fill);
    return path;
  }

  /// Puts a zip of [databasePath] (with [manifest] overrides) where the open
  /// dialog would have copied the picked file.
  Future<void> pick(
    String databasePath, {
    Map<String, Object?> manifest = const {},
  }) async {
    await Directory(files.paths.restoreWorkFolder).create(recursive: true);
    await File(files.paths.pickedZip).writeAsBytes(
      buildZip([
        textEntry('manifest.json', manifestJson(manifest)),
        entry('money_swield.db', await File(databasePath).readAsBytes()),
      ]),
    );
  }

  bool candidateLeft() => Directory(files.paths.candidateFolder).existsSync();

  Future<void> expectRejected(RestoreRejection reason) async {
    await expectLater(
      repo.prepareFromZip(),
      throwsA(isA<RestoreRejected>().having((e) => e.reason, 'reason', reason)),
    );
    expect(candidateLeft(), isFalse, reason: 'candidate left behind');
    expect(File(files.paths.pickedZip).existsSync(), isFalse);
  }

  group('prepareFromZip', () {
    setUp(setUpFiles);

    test(
      'a valid backup gives a candidate with what the dialog shows',
      () async {
        final source = await sourceDatabase(
          fill: (db) async {
            await insertExpenseRow(db);
            await db.update('expenses', {'occurred_on': '2026-10-02'});
            await insertExpenseRow(db);
            await insertExpenseRow(db, deletedAt: 5);
            // A binned expense newer than every active one isn't "latest".
            await db.update('expenses', {
              'occurred_on': '2026-12-31',
            }, where: 'deleted_at IS NOT NULL');
          },
        );
        await pick(source);

        final candidate = await repo.prepareFromZip();

        expect(candidate.source, RestoreSource.zip);
        expect(candidate.createdAt, DateTime.utc(2026, 10, 3, 8, 35, 12));
        expect(candidate.activeExpenses, 2);
        expect(candidate.binnedExpenses, 1);
        expect(candidate.latestExpenseOn, DateTime(2026, 10, 2));
        expect(candidate.stampsLastBackup, isTrue);
        expect(File(files.paths.candidate).existsSync(), isTrue);
        // Kept until the restore ends: its photos are written after the
        // confirm.
        expect(File(files.paths.pickedZip).existsSync(), isTrue);
        await repo.deletePickedZip();
        expect(File(files.paths.pickedZip).existsSync(), isFalse);
      },
    );

    test('validation opens the candidate read-only: it stays byte-equal, no '
        'android_metadata is added', () async {
      await setUpFiles(androidLike: true);
      final source = await sourceDatabase();
      // Without android_metadata, as if made by the FFI tests' SQLite.
      await files.withDatabase(
        source,
        (db) => db.execute('DROP TABLE android_metadata'),
      );
      await pick(source);

      await repo.prepareFromZip();

      expect(
        await File(files.paths.candidate).readAsBytes(),
        await File(source).readAsBytes(),
      );
    });

    group('counts', () {
      test('no expenses', () async {
        await pick(await sourceDatabase());
        final candidate = await repo.prepareFromZip();
        expect(candidate.activeExpenses, 0);
        expect(candidate.binnedExpenses, 0);
        expect(candidate.latestExpenseOn, isNull);
      });

      test('only binned expenses', () async {
        await pick(
          await sourceDatabase(
            fill: (db) async {
              await insertExpenseRow(db, deletedAt: 1);
              await insertExpenseRow(db, deletedAt: 2);
            },
          ),
        );
        final candidate = await repo.prepareFromZip();
        expect(candidate.activeExpenses, 0);
        expect(candidate.binnedExpenses, 2);
        expect(candidate.latestExpenseOn, isNull);
      });

      test(
        'a first-schema backup (no expenses table) still validates',
        () async {
          await pick(await sourceDatabase(migrations: firstSchemaMigrations));
          final candidate = await repo.prepareFromZip();
          expect(candidate.activeExpenses, isNull);
          expect(candidate.binnedExpenses, isNull);
          expect(candidate.latestExpenseOn, isNull);
          // Counted before the candidate is migrated: no table, no count.
          expect(candidate.recurringItems, isNull);
        },
      );

      test('running recurring items are counted, archived ones not', () async {
        await pick(
          await sourceDatabase(
            fill: (db) async {
              await insertRecurringRow(db, title: 'A');
              await insertRecurringRow(db, title: 'B');
              await insertRecurringRow(db, title: 'C', archivedAt: 5);
            },
          ),
        );
        final candidate = await repo.prepareFromZip();
        expect(candidate.recurringItems, 2);
      });
    });

    test('a backup from an older build (create_expenses applied, no '
        'recurring schema) is refused, nothing changed', () async {
      await pick(
        await sourceDatabase(
          fill: (db) async {
            await insertExpenseRow(db);
            await db.execute('PRAGMA foreign_keys = OFF');
            await db.execute(
              'CREATE TABLE old_expenses AS SELECT id, title, description, '
              'amount_minor, amount_expression, currency_code, occurred_at, '
              'utc_offset_minutes, occurred_on, category_id, '
              'payment_method_id, deleted_at, created_at, updated_at '
              'FROM expenses',
            );
            await db.execute('DROP TABLE expenses');
            await db.execute('ALTER TABLE old_expenses RENAME TO expenses');
            for (final table in [
              'recurring_expense_events',
              'recurring_amounts',
              'recurring_expenses',
            ]) {
              await db.execute('DROP TABLE $table');
            }
          },
        ),
      );
      await expectRejected(RestoreRejection.damaged);
    });

    group('rejects', () {
      test('a file that isn\'t a zip', () async {
        await Directory(files.paths.restoreWorkFolder).create(recursive: true);
        await File(files.paths.pickedZip).writeAsString('just text');
        await expectRejected(RestoreRejection.notABackup);
      });

      // Missing manifest, another app's, format 2 and the other
      // archive-level rejections: backup_archive_test. The one above
      // shows they reach the caller.

      test('corrupted database pages (integrity check)', () async {
        final source = await sourceDatabase(
          fill: (db) async {
            for (var i = 0; i < 50; i++) {
              await insertExpenseRow(db);
            }
          },
        );
        final bytes = await File(source).readAsBytes();
        // Garbage over the middle of every page but the first (the header).
        for (var page = 4096; page < bytes.length; page += 4096) {
          for (var i = page + 100; i < page + 400; i++) {
            bytes[i] = 0xA5;
          }
        }
        await File(source).writeAsBytes(bytes);
        await pick(source);
        await expectRejected(RestoreRejection.damaged);
      });

      test('a file that isn\'t SQLite at all inside the zip', () async {
        final path = p.join(files.root.path, 'junk.db');
        await File(path).writeAsString('not a database ' * 100);
        await pick(path);
        await expectRejected(RestoreRejection.damaged);
      });

      test('a foreign key violation', () async {
        final source = await sourceDatabase(
          fill: (db) async {
            await db.execute('PRAGMA foreign_keys = OFF');
            await insertExpenseRow(db, categoryId: 999);
          },
        );
        await pick(source);
        await expectRejected(RestoreRejection.damaged);
      });

      test('an unknown migration version is "newer version"', () async {
        final source = await sourceDatabase(
          fill: (db) => db.insert(MigrationRunner.historyTable, {
            'version': 9999999999,
            'name': 'from_the_future',
            'applied_at': 0,
          }),
        );
        await pick(source);
        await expectRejected(RestoreRejection.tooNew);
      });

      test('no schema_migrations table', () async {
        final source = await sourceDatabase(
          fill: (db) => db.execute('DROP TABLE schema_migrations'),
        );
        await pick(source);
        await expectRejected(RestoreRejection.damaged);
      });

      test('an empty schema_migrations (every migration would run and '
          'replace the data with an empty database)', () async {
        final source = await sourceDatabase(
          fill: (db) => db.delete('schema_migrations'),
        );
        await pick(source);
        await expectRejected(RestoreRejection.damaged);
      });

      test('a plain SQLite file that isn\'t ours', () async {
        final path = p.join(files.root.path, 'other.db');
        await files.withDatabase(path, (db) async {
          await db.execute('CREATE TABLE notes (text TEXT)');
          await db.insert('notes', {'text': 'hello'});
        });
        await pick(path);
        await expectRejected(RestoreRejection.damaged);
      });
    });

    test('a candidate left by an earlier attempt is replaced', () async {
      await Directory(files.paths.candidateFolder).create(recursive: true);
      await File(files.paths.candidate).writeAsString('stale');
      await File('${files.paths.candidate}-journal').writeAsString('stale');
      await pick(await sourceDatabase());

      await repo.prepareFromZip();

      expect(File('${files.paths.candidate}-journal').existsSync(), isFalse);
    });
  });

  group('checkOpensAsApp', () {
    setUp(setUpFiles);

    test('refuses a candidate whose expenses table is gone (but with a '
        'complete migration history), before any swap', () async {
      final live = await files.openLive();
      final liveBytes = await File(files.livePath).readAsBytes();
      await live.close();
      final source = await sourceDatabase(
        fill: (db) async {
          await db.execute('DROP TABLE expense_events');
          await db.execute('DROP TABLE expenses');
        },
      );
      await pick(source);
      await repo.prepareFromZip();

      await expectLater(
        repo.checkOpensAsApp(),
        throwsA(
          isA<RestoreRejected>().having(
            (e) => e.reason,
            'reason',
            RestoreRejection.damaged,
          ),
        ),
      );
      expect(await File(files.livePath).readAsBytes(), liveBytes);
    });

    test('refuses a candidate whose -wal is left non-empty (a WAL-mode '
        'candidate another connection keeps from checkpointing)', () async {
      await pick(await sourceDatabase());
      await repo.prepareFromZip();
      // (A stray -wal next to a rollback-mode file is deleted by SQLite
      // itself on open; the danger is a WAL-mode candidate.)
      final other = await files.factory.openDatabase(
        files.paths.candidate,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await other.rawQuery('PRAGMA journal_mode = WAL');
      await other.rawQuery('PRAGMA wal_autocheckpoint = 0');
      await other.insert('settings', {'key': 'probe', 'value': 'x'});

      await expectLater(repo.checkOpensAsApp(), throwsA(isA<StateError>()));
      await other.close();
    });

    test('accepts an empty -journal (what TRUNCATE mode leaves)', () async {
      await pick(await sourceDatabase());
      await repo.prepareFromZip();
      await File('${files.paths.candidate}-journal').writeAsBytes([]);

      await repo.checkOpensAsApp();
    });
  });

  group('repairSettings', () {
    setUp(setUpFiles);

    Future<String?> settingsSql(String path) => files.withDatabase(
      path,
      (db) async =>
          (await db.rawQuery(
                "SELECT sql FROM sqlite_master WHERE name = 'settings'",
              )).firstOrNull?['sql']
              as String?,
    );

    Future<AppSettings> candidateSettings() => files.withDatabase(
      files.paths.candidate,
      (db) => SettingsRepository(db, deviceCurrency: 'INR').load(),
    );

    test('readable settings are left exactly as they are', () async {
      await pick(
        await sourceDatabase(
          fill: (db) => SettingsRepository(
            db,
            deviceCurrency: 'INR',
          ).setTheme(AppThemeMode.dark),
        ),
      );
      await repo.prepareFromZip();

      expect(await repo.repairSettings(), isFalse);
      final settings = await candidateSettings();
      expect(settings.theme, AppThemeMode.dark);
      expect(settings.onboardingCompleted, isFalse, reason: 'not touched');
    });

    // Each a way the settings can be missing or unreadable while the
    // expenses are fine.
    final broken = <String, Future<void> Function(Database db)>{
      'the table is gone': (db) => db.execute('DROP TABLE settings'),
      // `RENAME COLUMN` needs SQLite 3.25; the tests run Android 10's 3.22, so
      // the rename is a rebuild by hand. The columns are CreateSettings' with
      // `value` called `v`.
      'a column was renamed by hand': (db) async {
        await db.execute(
          'CREATE TABLE settings_new '
          '("key" TEXT NOT NULL, v TEXT, PRIMARY KEY ("key"))',
        );
        await db.execute(
          'INSERT INTO settings_new ("key", v) SELECT "key", value '
          'FROM settings',
        );
        await db.execute('DROP TABLE settings');
        await db.execute('ALTER TABLE settings_new RENAME TO settings');
      },
      "a value isn't text": (db) => db.insert('settings', {
        'key': 'theme',
        'value': Uint8List.fromList([1, 2, 3]),
      }),
    };
    for (final MapEntry(key: name, value: breakIt) in broken.entries) {
      test('$name: rebuilt empty with the migration\'s schema, onboarding '
          'done, the expenses kept', () async {
        final fresh = p.join(files.root.path, 'fresh', 'fresh.db');
        await files.migrate(fresh);
        final expected = await settingsSql(fresh);
        await pick(
          await sourceDatabase(
            fill: (db) async {
              await insertExpenseRow(db);
              await breakIt(db);
            },
          ),
        );
        await repo.prepareFromZip();

        expect(await repo.repairSettings(), isTrue);

        expect(await settingsSql(files.paths.candidate), expected);
        final settings = await candidateSettings();
        expect(settings.onboardingCompleted, isTrue);
        expect(settings.theme, AppThemeMode.system, reason: 'the default');
        await files.withDatabase(files.paths.candidate, (db) async {
          expect(await db.query('expenses'), hasLength(1));
        });
        // And the app can start on it.
        await repo.checkOpensAsApp();
      });
    }
  });

  group('stamp', () {
    setUp(setUpFiles);

    Future<DateTime?> candidateLastBackup() => files.withDatabase(
      files.paths.candidate,
      (db) => SettingsRepository(db, deviceCurrency: 'INR').lastBackupAt(),
    );

    test(
      'a zip restore writes the manifest time into last_backup_at',
      () async {
        await pick(await sourceDatabase());
        final candidate = await repo.prepareFromZip();
        await repo.stamp(candidate);
        expect(
          await candidateLastBackup(),
          DateTime.utc(2026, 10, 3, 8, 35, 12),
        );
      },
    );

    test('an unreadable created_at validates, shows no date, stamps '
        'nothing', () async {
      final source = await sourceDatabase(
        fill: (db) => SettingsRepository(
          db,
          deviceCurrency: 'INR',
        ).setLastBackupAt(DateTime.utc(2020)),
      );
      await pick(source, manifest: {'created_at': 'soon'});
      final candidate = await repo.prepareFromZip();
      expect(candidate.createdAt, isNull);
      await repo.stamp(candidate);
      expect(await candidateLastBackup(), DateTime.utc(2020));
    });
  });

  group('prepareFromCopy', () {
    setUp(setUpFiles);

    test('carries the copy\'s -wal: a committed expense only in the -wal '
        'is in the candidate', () async {
      final copyPath = p.join(
        files.paths.preRestoreFolder,
        PreRestoreCopy.fileName(1, DateTime.utc(2026, 10, 3, 8, 50)),
      );
      final work = await sourceDatabase();
      // A WAL-mode database copied with its -wal while still open, so the
      // expense isn't checkpointed into the .db yet.
      final db = await files.factory.openDatabase(
        work,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.rawQuery('PRAGMA journal_mode = WAL');
      await db.rawQuery('PRAGMA wal_autocheckpoint = 0');
      final id = await insertExpenseRow(db);
      await Directory(files.paths.preRestoreFolder).create(recursive: true);
      await File(work).copy(copyPath);
      await File('$work-wal').copy('$copyPath-wal');
      await db.close();
      expect(File('$copyPath-wal').lengthSync(), greaterThan(0));

      final candidate = await repo.prepareFromCopy(
        PreRestoreCopy.parse(copyPath)!,
      );

      expect(candidate.source, RestoreSource.preRestoreCopy);
      expect(candidate.createdAt, DateTime.utc(2026, 10, 3, 8, 50));
      expect(candidate.activeExpenses, 1);
      expect(candidate.stampsLastBackup, isFalse);
      await repo.checkOpensAsApp();
      final rows = await files.withDatabase(
        files.paths.candidate,
        (db) => db.query('expenses'),
      );
      expect(rows.single['id'], id);
      // Copied, not moved: the copy survives a failed attempt.
      expect(File(copyPath).existsSync(), isTrue);
      expect(File('$copyPath-wal').existsSync(), isTrue);
    });
  });

  test('an older backup migrates forward with its data intact', () async {
    await setUpFiles();
    final source = await sourceDatabase(
      migrations: firstSchemaMigrations,
      fill: (db) => db.insert('categories', {
        'name': 'Old category',
        'emoji': '📦',
        'created_at': 1,
        'updated_at': 1,
      }),
    );
    await pick(source);
    await repo.prepareFromZip();

    await MigrationRunner(
      databaseFactory: files.factory,
      databasePath: files.paths.candidate,
      migrations: allMigrations,
      locale: const Locale('en', 'IN'),
      prompter: FakePrompter(),
    ).migrate();
    await repo.checkOpensAsApp();

    await files.withDatabase(files.paths.candidate, (db) async {
      expect(
        (await MigrationRunner.appliedVersions(db)).length,
        allMigrations.length,
      );
      expect(
        await db.query('categories', where: "name = 'Old category'"),
        hasLength(1),
      );
    });
  });

  group('cleanUpLeftovers', () {
    setUp(setUpFiles);

    test('deletes cut-short backup and restore files, keeps complete '
        'pre-restore copies', () async {
      final paths = files.paths;
      final complete = p.join(
        paths.preRestoreFolder,
        PreRestoreCopy.fileName(1, DateTime.utc(2026)),
      );
      final partial = p.join(
        paths.preRestoreFolder,
        '${PreRestoreCopy.fileName(2, DateTime.utc(2026))}.partial',
      );
      final orphanWal = p.join(
        paths.preRestoreFolder,
        '${PreRestoreCopy.fileName(3, DateTime.utc(2026))}-wal',
      );
      final migrationBackup = p.join(
        paths.preRestoreFolder,
        'money_swield.db.2026-01-01T00-00-00Z.bak',
      );
      for (final path in [
        paths.backupCopy,
        paths.pickedZip,
        paths.candidate,
        complete,
        '$complete-wal',
        partial,
        orphanWal,
        migrationBackup,
      ]) {
        await File(path).create(recursive: true);
      }

      await repo.cleanUpLeftovers();

      expect(Directory(paths.backupWorkFolder).existsSync(), isFalse);
      expect(Directory(paths.restoreWorkFolder).existsSync(), isFalse);
      expect(Directory(paths.candidateFolder).existsSync(), isFalse);
      expect(File(partial).existsSync(), isFalse);
      expect(File(orphanWal).existsSync(), isFalse);
      expect(File(complete).existsSync(), isTrue);
      expect(File('$complete-wal').existsSync(), isTrue);
      expect(File(migrationBackup).existsSync(), isTrue);
    });

    test('with nothing to clean up, does nothing', () async {
      await repo.cleanUpLeftovers();
    });
  });
}
