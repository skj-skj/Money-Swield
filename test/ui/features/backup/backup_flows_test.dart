import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/app/restore_tools.dart';
import 'package:my_expense_tracker_app/app/shell.dart';
import 'package:my_expense_tracker_app/data/repositories/backup_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/data/services/backup/pre_restore_copy.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:my_expense_tracker_app/ui/features/backup/views/backup_screen.dart';
import 'package:my_expense_tracker_app/ui/features/backup/views/restore_screen.dart';
import 'package:my_expense_tracker_app/ui/features/migration/view_models/migration_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/onboarding/views/onboarding_screen.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/services/database/migration/test_helpers.dart';
import '../../../helpers/fake_document_service.dart';
import '../../../helpers/file_database.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// Backup and restore through the whole app, on real database files
/// (phase-3.md §12, Widgets).
void main() {
  late FileDatabases files;
  late FakeDocumentService documents;
  late RestoreTools tools;

  /// Real files and the real app, with the dialogs faked. [prepare] fills
  /// the live database before the app starts.
  Future<void> setUpFiles(
    WidgetTester tester, {
    List<Migration>? migrations,
    Future<void> Function(Database db)? prepare,
  }) async {
    await tester.runAsync(() async {
      files = await FileDatabases.create(noIsolate: true);
      documents = FakeDocumentService();
      tools = RestoreTools(
        appDatabase: files.appDatabase(migrations: migrations),
        documents: documents,
        deviceCurrency: 'INR',
      );
      await files.migrate(files.livePath, migrations: migrations);
      if (prepare != null) await files.withDatabase(files.livePath, prepare);
    });
  }

  /// Pumps the app the way main() builds it, on the files above.
  Future<void> pumpFileApp(WidgetTester tester, Finder until) async {
    final settings = SettingsCubit(initial: AppSettings.beforeLoad);
    final migration = MigrationCubit(
      database: tools.appDatabase,
      locale: const Locale('en', 'IN'),
    );
    addTearDown(() async {
      await migration.close();
      await settings.close();
    });
    await tester.pumpWidget(
      App(
        migrationCubit: migration,
        settingsCubit: settings,
        restoreTools: tools,
        openDependencies: () => AppDependencies.open(tools),
      ),
    );
    unawaited(migration.run());
    await pumpUntilFound(tester, until);
  }

  /// The app's connection stays open for the app's lifetime; closed here so
  /// the temporary folder can be deleted (Windows can't delete open files).
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final db = await tools.appDatabase.open(); // The same single instance.
      await db.close();
    });
  }

  Future<void> addExpense(Database db, String title, {int? deletedAt}) async {
    final id = await insertExpenseRow(db, deletedAt: deletedAt);
    await db.update(
      'expenses',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> completeOnboarding(Database db) =>
      SettingsRepository(db, deviceCurrency: 'INR').setOnboardingCompleted();

  Future<void> openBackupScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Backup & restore'), 200);
    await tester.tap(find.text('Backup & restore'));
    await pumpUntilFound(tester, find.text('Back up now'));
  }

  /// Taps "Restore" in the confirm dialog and waits for the app to come
  /// back on Home.
  Future<void> confirmRestore(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await pumpUntilFound(tester, find.byType(Shell));
    await tester.pump();
  }

  testWidgets('back up, add an expense, restore: the expense is gone and '
      'Home says "Backup restored"; Undo brings it back', (tester) async {
    await setUpFiles(
      tester,
      prepare: (db) async {
        await completeOnboarding(db);
        await addExpense(db, 'Lunch');
      },
    );
    await pumpFileApp(tester, find.text('Lunch'));

    // Back up.
    await openBackupScreen(tester);
    expect(
      find.descendant(
        of: find.byType(BackupScreen),
        matching: find.text('Never backed up'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back up now'));
    await pumpUntilFound(tester, find.text('Backup saved'));
    expect(documents.savedName, startsWith('expense-tracker-backup-'));
    expect(find.text('Last backup: today'), findsOneWidget);

    // Back on Settings, the row says so without reopening the tab.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Last backup: today'), findsOneWidget);

    // An expense added after the backup.
    await tester.runAsync(() async {
      final picked = p.join(files.root.path, 'saved.zip');
      await File(picked).writeAsBytes(documents.savedBytes!);
      documents.pickedFile = picked;
      await files.withDatabase(
        files.livePath,
        (db) => addExpense(db, 'Dinner'),
      );
    });

    // Restore.
    await tester.tap(find.text('Backup & restore'));
    await pumpUntilFound(tester, find.text('Restore from a backup'));
    await tester.tap(find.text('Restore from a backup'));
    await pumpUntilFound(tester, find.text('Restore this backup?'));
    expect(find.textContaining('1 expense.'), findsOneWidget);
    expect(
      find.text('All data on this phone (2 expenses) is replaced.'),
      findsOneWidget,
    );
    await confirmRestore(tester);

    expect(find.text('Backup restored'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsNothing);

    // Undo.
    await openBackupScreen(tester);
    // Shown once the screen has listed the pre-restore copies.
    await pumpUntilFound(tester, find.text('Undo last restore'));
    await tester.tap(find.text('Undo last restore'));
    await pumpUntilFound(tester, find.text('Undo the last restore?'));
    expect(find.textContaining('2 expenses.'), findsOneWidget);
    await confirmRestore(tester);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('fresh install → onboarding → Restore from a backup → Home in '
      "the backup's language and theme, with its expenses", (tester) async {
    await setUpFiles(tester);
    // A backup made on another phone: Hindi, dark, one expense.
    await tester.runAsync(() async {
      final source = p.join(files.root.path, 'other-phone', 'other.db');
      await files.migrate(source);
      final db = await files.open(source);
      final settings = SettingsRepository(db, deviceCurrency: 'INR');
      await settings.setOnboardingCompleted();
      await settings.setLocale(hi);
      await settings.setTheme(AppThemeMode.dark);
      await addExpense(db, 'Chai');
      final zip = await BackupRepository(
        db,
        appDatabase: files.appDatabase(path: source),
        settings: settings,
      ).createBackup(appVersion: 'x');
      final picked = p.join(files.root.path, 'other-phone.zip');
      await File(zip.path).copy(picked);
      documents.pickedFile = picked;
      await db.close();
    });
    await pumpFileApp(tester, find.byType(OnboardingScreen));

    await tester.tap(find.text('Restore from a backup'));
    await pumpUntilFound(tester, find.text('Restore this backup?'));
    expect(
      find.textContaining('All data on this phone'),
      findsNothing,
      reason: 'from onboarding there is only the seed data',
    );
    await confirmRestore(tester);

    expect(find.text('Chai'), findsOneWidget);
    expect(find.text('होम'), findsOneWidget, reason: 'in Hindi');
    expect(find.text('बैकअप रीस्टोर हो गया'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    // A pre-restore copy of the onboarding data was made too (P3-21).
    expect(
      await tester.runAsync(tools.appDatabase.preRestoreCopies),
      hasLength(1),
    );

    await closeApp(tester);
  });

  testWidgets('a start that fails after a restore offers "Undo last '
      'restore", which opens the old data', (tester) async {
    await setUpFiles(
      tester,
      prepare: (db) async {
        await completeOnboarding(db);
        await addExpense(db, 'Before the restore');
      },
    );
    // The good data became a pre-restore copy; the restored file can't be
    // read (its settings table is gone).
    await tester.runAsync(() async {
      final copy = p.join(
        files.paths.preRestoreFolder,
        PreRestoreCopy.fileName(1, DateTime.utc(2026, 10, 3, 8, 50)),
      );
      await Directory(files.paths.preRestoreFolder).create(recursive: true);
      await File(files.livePath).copy(copy);
      await files.withDatabase(
        files.livePath,
        (db) => db.execute('DROP TABLE settings'),
      );
    });
    await pumpFileApp(tester, find.text("Your data couldn't be opened"));

    await tester.tap(find.text('Undo last restore'));
    await pumpUntilFound(tester, find.text('Undo the last restore?'));
    await confirmRestore(tester);

    expect(find.text('Before the restore'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Back on the confirm dialog cancels and deletes the candidate', (
    tester,
  ) async {
    await setUpFiles(tester, prepare: completeOnboarding);
    await tester.runAsync(() async {
      final db = await files.open(files.livePath);
      final zip = await BackupRepository(
        db,
        appDatabase: files.appDatabase(),
        settings: SettingsRepository(db, deviceCurrency: 'INR'),
      ).createBackup(appVersion: 'x');
      final picked = p.join(files.root.path, 'picked.zip');
      await File(zip.path).copy(picked);
      documents.pickedFile = picked;
      await db.close();
    });
    await pumpFileApp(tester, find.byType(Shell));
    await openBackupScreen(tester);
    await tester.tap(find.text('Restore from a backup'));
    await pumpUntilFound(tester, find.text('Restore this backup?'));
    expect(
      await tester.runAsync(
        () => Directory(files.paths.candidateFolder).exists(),
      ),
      isTrue,
    );

    await tester.binding.handlePopRoute();
    await pumpUntilGone(tester, find.byType(RestoreScreen));
    // The candidate is deleted by the cubit's close(), on real I/O.
    await pumpUntil(
      tester,
      () => !Directory(files.paths.candidateFolder).existsSync(),
      description: 'candidate deleted',
    );

    expect(find.text('Restore this backup?'), findsNothing);
    expect(find.text('Back up now'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => Directory(files.paths.candidateFolder).exists(),
      ),
      isFalse,
    );
    await closeApp(tester);
  });

  testWidgets('Back does nothing while the candidate migrates', (tester) async {
    // This app has one more migration than the backup, and it asks a
    // question: the restore waits on the migration screen.
    final asking = TestMigration(9000000000, 'asks_a_question', (m) async {
      await m.askText('Name your wallet', initialValue: 'Main');
    });
    final migrations = [...allMigrations, asking];
    late String picked;
    await setUpFiles(
      tester,
      migrations: migrations,
      prepare: completeOnboarding,
    );
    await tester.runAsync(() async {
      final source = p.join(files.root.path, 'older', 'older.db');
      await files.migrate(source);
      final db = await files.open(source);
      await SettingsRepository(
        db,
        deviceCurrency: 'INR',
      ).setOnboardingCompleted();
      final zip = await BackupRepository(
        db,
        appDatabase: files.appDatabase(path: source),
        settings: SettingsRepository(db, deviceCurrency: 'INR'),
      ).createBackup(appVersion: 'x');
      picked = p.join(files.root.path, 'older.zip');
      await File(zip.path).copy(picked);
      documents.pickedFile = picked;
      await db.close();
    });
    await pumpFileApp(tester, find.byType(Shell));
    await openBackupScreen(tester);
    await tester.tap(find.text('Restore from a backup'));
    await pumpUntilFound(tester, find.text('Restore this backup?'));
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await pumpUntilFound(tester, find.text('Name your wallet'));

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.text('Name your wallet'),
      findsOneWidget,
      reason: 'Back ignored',
    );
    expect(
      await tester.runAsync(() => File(files.paths.candidate).exists()),
      isTrue,
    );

    await tester.tap(find.text('Continue'));
    // "Update done successfully" + Continue (once its tick is drawn), then
    // the swap and restart.
    await pumpUntilFound(tester, find.text('Update done successfully'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await pumpUntilFound(tester, find.text('Backup restored'));
    expect(find.byType(Shell), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a backup whose settings are missing is restored with default '
      'settings, and Home says so', (tester) async {
    await setUpFiles(tester, prepare: completeOnboarding);
    // A backup made from data whose settings table is gone.
    await tester.runAsync(() async {
      final source = p.join(files.root.path, 'no-settings', 'source.db');
      await files.migrate(source);
      final db = await files.open(source);
      await addExpense(db, 'Rent');
      await db.execute('DROP TABLE settings');
      final zip = await BackupRepository(
        db,
        appDatabase: files.appDatabase(path: source),
        settings: SettingsRepository(db, deviceCurrency: 'INR'),
      ).createBackup(appVersion: 'x');
      final picked = p.join(files.root.path, 'no-settings.zip');
      await File(zip.path).copy(picked);
      documents.pickedFile = picked;
      await db.close();
    });
    await pumpFileApp(tester, find.byType(Shell));
    await openBackupScreen(tester);
    await tester.tap(find.text('Restore from a backup'));
    await pumpUntilFound(tester, find.text('Restore this backup?'));
    await confirmRestore(tester);

    expect(find.text('Rent'), findsOneWidget);
    expect(find.textContaining('default settings are used'), findsOneWidget);
    expect(find.text('Backup restored'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('Back is blocked while a backup runs (a second backup could '
      'start from a new screen and share its folder)', (tester) async {
    await setUpFiles(tester, prepare: completeOnboarding);
    final release = Completer<bool>();
    documents.onSave = (_) => release.future;
    await pumpFileApp(tester, find.byType(Shell));
    await openBackupScreen(tester);

    await tester.tap(find.text('Back up now'));
    await pumpUntil(
      tester,
      () => documents.saveCalls == 1,
      description: 'save dialog requested',
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BackupScreen), findsOneWidget, reason: 'Back ignored');

    release.complete(false);
    await pumpUntilFound(tester, find.text('Back up now'));
    await tester.binding.handlePopRoute();
    await pumpUntilGone(tester, find.byType(BackupScreen));
    await closeApp(tester);
  });
}
