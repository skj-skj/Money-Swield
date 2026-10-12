import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../domain/models/sms_suggestion.dart' show ScanProgress;
import '../../../../l10n/app_localizations.dart';
import '../../../core/byte_size_text.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/widgets/error_report_view.dart';
import '../../../core/widgets/show_message.dart';
import '../view_models/backup_cubit.dart';
import 'backup_texts.dart';
import 'restore_screen.dart';

/// Settings → Backup & restore (phase-3.md §10): when the last backup was,
/// Back up now, Restore from a backup, and Undo last restore when a
/// pre-restore copy exists.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.dependencies,
    this.runningSmsScan,
    this.smsProgress,
  });

  final AppDependencies dependencies;

  /// The SMS scan running now, or null: a backup waits for it (phase-9a.md
  /// §6.7).
  final Future<void>? Function()? runningSmsScan;

  /// That scan's count while the on-device model reads (phase-9b.md §6.2).
  final ValueListenable<ScanProgress?>? smsProgress;

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
      photoStats: _deps.expenses.photoStats,
      runningSmsScan: widget.runningSmsScan,
      smsProgress: widget.smsProgress,
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _backUp() async {
    final result = await _cubit.backUp();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final missing = _cubit.value.missingPhotos;
    final message = switch (result) {
      BackupResult.saved when missing > 0 => l10n.backupSavedMissingPhotos(
        missing,
      ),
      BackupResult.saved => l10n.backupSaved,
      BackupResult.noSpace => l10n.backupNoSpace,
      BackupResult.saveTargetFull => l10n.saveTargetNoSpace,
      BackupResult.cancelled ||
      BackupResult.failed ||
      BackupResult.ignored => null,
    };
    if (message != null) {
      showMessage(
        ScaffoldMessenger.of(context),
        message,
        long: result != BackupResult.saved || missing > 0,
      );
    }
  }

  Future<void> _restore({PreRestoreCopy? copy}) => RestoreScreen.open(
    context,
    tools: _deps.restoreTools,
    closeLiveConnection: _deps.closeForRestore,
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
              onCancelWait: _cubit.cancelWait,
              onIncludePhotos: _cubit.setIncludePhotos,
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
  /// "Include photos" (ticked each time, P6-16) with what they are; when
  /// unticked, what that means after a reinstall (§8.7).
  Widget _includePhotos(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = state.photoCount;
    final bytes = state.photoBytes;
    final summary = count == null || bytes == null || count == 0
        ? null
        : l10n.settingsTileSummary(
            l10n.photosCount(count),
            byteSizeText(l10n, formattingLocaleOf(context), bytes),
          );
    return CheckboxListTile(
      key: const ValueKey('includePhotos'),
      value: state.includePhotos,
      onChanged: state.backingUp
          ? null
          : (include) => onIncludePhotos(include ?? true),
      title: Text(l10n.includePhotos),
      subtitle: state.includePhotos
          ? (summary == null ? null : Text(summary))
          : Text(
              l10n.photosNotInBackup,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
    );
  }

  const _BackupList({
    required this.state,
    required this.now,
    required this.onBackUp,
    required this.onCancelWait,
    required this.onIncludePhotos,
    required this.onRestore,
    required this.onUndo,
  });

  final BackupState state;
  final DateTime now;
  final VoidCallback onBackUp;

  /// Cancel while the backup waits for an SMS scan.
  final VoidCallback onCancelWait;
  final ValueChanged<bool> onIncludePhotos;
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
              : Text(shortDateText(locale, lastBackupAt.toLocal())),
        ),
        _includePhotos(context),
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
            label: Text(switch (state) {
              BackupState(
                waitingForSms: true,
                smsProgress: (:final done, :final total),
              )
                  when total > 0 =>
                l10n.backupWaitingForSmsCount(done, total),
              BackupState(waitingForSms: true) => l10n.backupWaitingForSms,
              BackupState(
                backingUp: true,
                photosDone: final done?,
                photosTotal: final total?,
              )
                  when total > 0 =>
                l10n.backupPhotosProgress(done, total),
              BackupState(backingUp: true) => l10n.preparingBackup,
              _ => l10n.backUpNow,
            }),
          ),
        ),
        if (state.waitingForSms)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 16, bottom: 8),
              child: TextButton(
                key: const ValueKey('cancelSmsWait'),
                onPressed: onCancelWait,
                child: Text(l10n.cancel),
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
