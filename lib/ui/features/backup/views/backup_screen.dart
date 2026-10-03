import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/widgets/error_report_view.dart';
import '../view_models/backup_cubit.dart';
import 'backup_texts.dart';
import 'restore_screen.dart';

/// Settings → Backup & restore (phase-3.md §10): when the last backup was,
/// Back up now, Restore from a backup, and Undo last restore when a
/// pre-restore copy exists.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupCubit _cubit;

  AppDependencies get _deps => widget.dependencies;

  @override
  void initState() {
    super.initState();
    _cubit = BackupCubit(
      backups: _deps.backups,
      documents: _deps.restoreTools.documents,
      appDatabase: _deps.restoreTools.appDatabase,
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _backUp() async {
    final result = await _cubit.backUp();
    if (result != BackupResult.saved || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.backupSaved)));
  }

  Future<void> _restore({PreRestoreCopy? copy}) => RestoreScreen.open(
    context,
    tools: _deps.restoreTools,
    closeLiveConnection: _deps.database.close,
    currentExpenseCount: _deps.backups.activeExpenseCount,
    copy: copy,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<BackupCubit, BackupState>(
      bloc: _cubit,
      builder: (context, state) => PopScope(
        // Back is blocked while a backup runs: leaving and coming back would
        // let a second backup start on another cubit, and both share one
        // cache/backup/ folder. It takes well under a second, and the save
        // dialog covers the screen after that.
        canPop: !state.backingUp,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.backupAndRestore)),
          body: switch (state.failureReport) {
            final report? => Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorReportView(
                title: l10n.backupFailedTitle,
                message: l10n.backupFailedMessage,
                report: report,
                onRetry: _backUp,
              ),
            ),
            null => _BackupList(
              state: state,
              now: _deps.now(),
              onBackUp: _backUp,
              onRestore: _restore,
              onUndo: (copy) => _restore(copy: copy),
            ),
          },
        ),
      ),
    );
  }
}

class _BackupList extends StatelessWidget {
  const _BackupList({
    required this.state,
    required this.now,
    required this.onBackUp,
    required this.onRestore,
    required this.onUndo,
  });

  final BackupState state;
  final DateTime now;
  final VoidCallback onBackUp;
  final VoidCallback onRestore;
  final ValueChanged<PreRestoreCopy> onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final lastBackupAt = state.lastBackupAt;
    final copy = state.newestCopy;
    return ListView(
      children: [
        ListTile(
          // A calendar, not a clock: the restore row below has the
          // clock-with-arrow icon.
          leading: const Icon(Icons.event_available_outlined),
          title: Text(lastBackupText(l10n, lastBackupAt, now)),
          subtitle: lastBackupAt == null
              ? null
              : Text(DateFormat.yMMMd(locale).format(lastBackupAt.toLocal())),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: state.backingUp ? null : onBackUp,
            icon: state.backingUp
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_outlined),
            label: Text(
              state.backingUp ? l10n.preparingBackup : l10n.backUpNow,
            ),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(l10n.restoreFromBackup),
          subtitle: Text(l10n.restoreFromBackupSubtitle),
          enabled: !state.backingUp,
          onTap: onRestore,
        ),
        if (copy != null)
          ListTile(
            leading: const Icon(Icons.undo),
            title: Text(l10n.undoLastRestore),
            subtitle: Text(
              l10n.undoLastRestoreSubtitle(
                dateTimeText(locale, copy.createdAt),
              ),
            ),
            enabled: !state.backingUp,
            onTap: () => onUndo(copy),
          ),
      ],
    );
  }
}
