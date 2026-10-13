import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:money_swield/data/services/database/app_database.dart';
import 'package:money_swield/domain/models/restore_candidate.dart';
import 'package:money_swield/ui/features/backup/view_models/restore_cubit.dart';
import 'package:money_swield/ui/features/backup/views/backup_texts.dart';
import 'package:money_swield/ui/features/backup/views/restore_screen.dart';
import 'package:money_swield/ui/features/migration/view_models/migration_cubit.dart';

import '../../../../helpers/fake_app_database.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = l10nFor('en');

  group('lastBackupText', () {
    final now = DateTime(2026, 10, 3, 0, 30);

    test('never', () {
      expect(lastBackupText(l10n, null, now), 'Never backed up');
    });

    test('counts calendar days: 23:59 yesterday is "yesterday" at 00:30', () {
      expect(
        lastBackupText(l10n, DateTime(2026, 10, 2, 23, 59), now),
        'Last backup: yesterday',
      );
      expect(
        lastBackupText(l10n, DateTime(2026, 10, 3, 0, 1), now),
        'Last backup: today',
      );
    });

    test('N days ago', () {
      expect(
        lastBackupText(l10n, DateTime(2026, 9, 21, 12), now),
        'Last backup: 12 days ago',
      );
    });

    test('a time in the future reads "today", never "-3 days ago"', () {
      expect(
        lastBackupText(l10n, DateTime(2026, 10, 6), now),
        'Last backup: today',
      );
    });

    test('a UTC time is compared in local dates', () {
      final local = DateTime(2026, 10, 2, 12);
      expect(
        lastBackupText(l10n, local.toUtc(), now),
        'Last backup: yesterday',
      );
    });
  });

  group('restoreSummary', () {
    RestoreCandidate candidate({
      RestoreSource source = RestoreSource.zip,
      DateTime? createdAt,
      int? active = 121,
      int? binned = 3,
      DateTime? latest,
      int? recurring,
    }) => RestoreCandidate(
      source: source,
      createdAt: createdAt,
      activeExpenses: active,
      binnedExpenses: binned,
      latestExpenseOn: latest,
      recurringItems: recurring,
    );

    List<String> summary(RestoreCandidate c, {int? current = 98}) =>
        restoreSummary(
          l10n,
          locale: 'en',
          candidate: c,
          currentExpenses: current,
        );

    test('running recurring items after the bin part; '
        '0 and none left out; grouped', () {
      String line(int? recurring, {int binned = 3}) => summary(
        candidate(
          binned: binned,
          recurring: recurring,
          latest: DateTime(2026, 10, 2),
        ),
      )[1];
      expect(
        line(4),
        '121 expenses, plus 3 in the bin, 4 recurring items. '
        'Latest on Oct 2, 2026',
      );
      expect(
        line(1, binned: 0),
        '121 expenses, 1 recurring item. Latest on Oct 2, 2026',
      );
      expect(line(0), '121 expenses, plus 3 in the bin. Latest on Oct 2, 2026');
      expect(
        line(null),
        '121 expenses, plus 3 in the bin. Latest on Oct 2, 2026',
      );
      expect(line(1000), contains('1,000 recurring items'));
    });

    test('the full dialog text', () {
      final lines = summary(
        candidate(
          createdAt: DateTime(2026, 10, 3, 14, 5),
          latest: DateTime(2026, 10, 2),
        ),
      );
      expect(lines, [
        'Backup from Oct 3, 2026 2:05 PM',
        '121 expenses, plus 3 in the bin. Latest on Oct 2, 2026',
        // A database-only backup says so.
        // ignore: no_adjacent_strings_in_list, one line of the dialog.
        "This backup has no photos. Photos this phone doesn't have will show "
            'as missing.',
        'All data on this phone (98 expenses) is replaced.',
        'A copy is kept, and you can undo the restore.',
      ]);
    });

    test('no expenses: "No expenses", no "Latest on"', () {
      final lines = summary(candidate(active: 0, binned: 0));
      expect(lines[1], 'No expenses');
    });

    test('an empty bin leaves out "plus N in the bin"', () {
      final lines = summary(
        candidate(active: 1, binned: 0, latest: DateTime(2026, 10, 2)),
      );
      expect(lines[1], '1 expense. Latest on Oct 2, 2026');
    });

    test('only binned expenses: no "Latest on"', () {
      final lines = summary(candidate(active: 0, binned: 2));
      expect(lines[1], 'No expenses, plus 2 in the bin');
    });

    test('from onboarding, the "All data on this phone" paragraph is left '
        'out', () {
      // Date, counts and the no-photos line.
      expect(summary(candidate(), current: null), hasLength(3));
    });

    test('an unreadable date and an older schema show "—"', () {
      final lines = summary(candidate(active: null, binned: null));
      expect(lines[0], 'Backup from —');
      expect(lines[1], '—');
    });

    test('Undo names the copy\'s time', () {
      final lines = summary(
        candidate(
          source: RestoreSource.preRestoreCopy,
          createdAt: DateTime(2026, 10, 3, 14, 20),
        ),
      );
      expect(
        lines[0],
        'Your data from before the restore on Oct 3, 2026 2:20 PM',
      );
    });

    test('this phone with no expenses', () {
      expect(
        summary(candidate(), current: 0)[3],
        'All data on this phone (no expenses) is replaced.',
      );
    });
  });

  test('every rejection has its own text', () {
    expect({
      for (final r in RestoreRejection.values) rejectionText(l10n, r),
    }, hasLength(RestoreRejection.values.length));
  });

  group('Back on the restore route', () {
    test('cancels at every step but migrating and swapping', () {
      expect(RestoreScreen.canLeave(const RestorePicking()), isTrue);
      expect(RestoreScreen.canLeave(const RestoreValidating()), isTrue);
      expect(
        RestoreScreen.canLeave(const RestoreRefused(RestoreRejection.damaged)),
        isTrue,
      );
      expect(RestoreScreen.canLeave(const RestoreSwapping()), isFalse);
      expect(RestoreScreen.canLeave(const RestoreDone()), isFalse);
    });

    test('while migrating only once the migration failed', () async {
      final running = cubitFor(
        FakeAppDatabase((prompter, onProgress) async {}),
      );
      expect(RestoreScreen.canLeave(RestoreMigrating(running)), isFalse);

      final failing = cubitFor(
        FakeAppDatabase((prompter, onProgress) async => throw StateError('x')),
      );
      await failing.run();
      expect(failing.value, isA<MigrationFailed>());
      expect(RestoreScreen.canLeave(RestoreMigrating(failing)), isTrue);
    });

    test('a failure that needs a restart can\'t be left with Back', () {
      expect(
        RestoreScreen.canLeave(const RestoreFailed('r', needsRestart: true)),
        isFalse,
      );
      expect(
        RestoreScreen.canLeave(const RestoreFailed('r', needsRestart: false)),
        isTrue,
      );
    });
  });

  test('a candidate database uses the app\'s migrations', () {
    final app = AppDatabase(databasePath: () async => 'live.db');
    final candidate = app.forFile('candidate.db');
    expect(candidate.knownMigrationVersions, app.knownMigrationVersions);
    expect(const Locale('en'), en);
  });
}
