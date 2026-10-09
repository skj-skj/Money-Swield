import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_restart.dart';
import '../../../../app/restore_tools.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../domain/models/restore_candidate.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/widgets/error_report_view.dart';
import '../../migration/view_models/migration_cubit.dart';
import '../../migration/views/migration_screen.dart';
import '../view_models/restore_cubit.dart';
import 'backup_texts.dart';

/// One restore, from picking the file to the restart (phase-3.md §10).
///
/// Back cancels and deletes the candidate at every step but two: while the
/// candidate migrates (leaving would delete a file the runner still has
/// open) and while it's swapped in (P3-17).
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({
    super.key,
    required this.tools,
    required this.closeLiveConnection,
    this.currentExpenseCount,
    this.copy,
  });

  final RestoreTools tools;

  /// Closes the app's connection right before the swap.
  final Future<void> Function() closeLiveConnection;

  /// This phone's active expenses, for "All data on this phone (N
  /// expenses)". Null leaves that paragraph out (onboarding, a start that
  /// failed).
  final Future<int> Function()? currentExpenseCount;

  /// The pre-restore copy to go back to ("Undo last restore"); null picks a
  /// backup zip.
  final PreRestoreCopy? copy;

  /// Pushes the restore route.
  static Future<void> open(
    BuildContext context, {
    required RestoreTools tools,
    required Future<void> Function() closeLiveConnection,
    Future<int> Function()? currentExpenseCount,
    PreRestoreCopy? copy,
  }) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => RestoreScreen(
        tools: tools,
        closeLiveConnection: closeLiveConnection,
        currentExpenseCount: currentExpenseCount,
        copy: copy,
      ),
    ),
  );

  /// Message text for the report, in English: part of what the user sends
  /// us. The `Backup:` line of a failed migration points into
  /// `databases/restore/`, which leaving deletes.
  static const reportContext =
      'Context: restoring a backup; the paths below are deleted when leaving '
      'this screen';

  /// Whether Back may leave now (see the class).
  @visibleForTesting
  static bool canLeave(RestoreState state) => switch (state) {
    RestoreMigrating(:final migration) => migration.value is MigrationFailed,
    // Writing the photos leads straight into the swap: leaving then would
    // still swap after the screen closed.
    RestoreWritingPhotos() || RestoreSwapping() || RestoreDone() => false,
    RestoreFailed(:final needsRestart) => !needsRestart,
    _ => true,
  };

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  late final RestoreCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = RestoreCubit(
      tools: widget.tools,
      closeLiveConnection: widget.closeLiveConnection,
      // Migration questions use the device language, as on app start.
      locale: WidgetsBinding.instance.platformDispatcher.locale,
      currentExpenseCount: widget.currentExpenseCount,
    );
    final copy = widget.copy;
    copy == null ? _cubit.startFromZip() : _cubit.startFromCopy(copy);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _onState(BuildContext context, RestoreState state) {
    switch (state) {
      case RestoreConfirm():
        _confirm(state);
      case RestoreDone(:final settingsReset, :final failedPhotos):
        AppRestart.of(context).restart(
          notice: RestoreNotice(
            settingsReset: settingsReset,
            failedPhotos: failedPhotos,
          ),
        );
      case RestoreCancelled():
        Navigator.pop(context);
      default:
    }
  }

  Future<void> _confirm(RestoreConfirm state) async {
    final l10n = AppLocalizations.of(context);
    final lines = restoreSummary(
      l10n,
      locale: dateLocaleOf(context),
      candidate: state.candidate,
      currentExpenses: state.currentExpenses,
    );
    final candidate = state.candidate;
    // Photos that don't fit: "Restore without photos" instead of Restore
    // (P6-17); nothing else would be written.
    final withoutPhotos = candidate.includesPhotos && !candidate.photosFit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          state.candidate.source == RestoreSource.zip
              ? l10n.restoreConfirmTitle
              : l10n.undoConfirmTitle,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [for (final line in lines) Text(line)],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('restoreConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              withoutPhotos
                  ? l10n.restoreWithoutPhotos
                  : l10n.restoreBackupButton,
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    // Back or a tap outside the dialog is a cancel too.
    if (confirmed ?? false) {
      await _cubit.confirm(withPhotos: !withoutPhotos);
    } else {
      await _cubit.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<RestoreCubit, RestoreState>(
      bloc: _cubit,
      listener: _onState,
      child: BlocSignalBuilder<RestoreCubit, RestoreState>(
        bloc: _cubit,
        builder: (context, state) => switch (state) {
          RestoreMigrating(:final migration) => _MigrationStep(
            migration: migration,
            canLeave: RestoreScreen.canLeave,
            state: state,
          ),
          _ => PopScope(
            canPop: RestoreScreen.canLeave(state),
            child: _body(context, state),
          ),
        },
      ),
    );
  }

  Widget _body(BuildContext context, RestoreState state) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      RestorePicking() || RestoreCancelled() => const _Waiting(),
      RestoreValidating() ||
      RestoreConfirm() => _Waiting(text: l10n.checkingBackup),
      RestoreSwapping() ||
      RestoreDone() ||
      RestoreMigrating() => _Waiting(text: l10n.restoringData),
      RestoreWritingPhotos(:final done, :final total) => _Waiting(
        text: l10n.restoringPhotosProgress(done, total),
      ),
      RestoreFailedNoSpace() => _NoSpace(text: l10n.openBackupNoSpace),
      RestoreRefused(:final reason) => _Refused(reason: reason),
      RestoreFailed(:final report, :final needsRestart) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorReportView(
              title: l10n.restoreFailedTitle,
              message: needsRestart
                  ? l10n.restoreFailedRestartMessage
                  : l10n.restoreFailedMessage,
              report: report,
              retryLabel: needsRestart ? l10n.restartApp : l10n.ok,
              onRetry: needsRestart
                  ? () => AppRestart.of(context).restart()
                  : () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    };
  }
}

/// The candidate's migrations, on the usual migration screen; then the
/// "restoring" spinner while the cubit swaps it in.
class _MigrationStep extends StatelessWidget {
  const _MigrationStep({
    required this.migration,
    required this.canLeave,
    required this.state,
  });

  final MigrationCubit migration;
  final bool Function(RestoreState state) canLeave;
  final RestoreState state;

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<MigrationCubit>.value(
      value: migration,
      child: BlocSignalBuilder<MigrationCubit, MigrationState>(
        builder: (context, migrationState) => PopScope(
          // Rebuilt with each migration state, so Back unlocks on failure.
          canPop: canLeave(state),
          child: migrationState is MigrationDone
              ? _Waiting(text: AppLocalizations.of(context).restoringData)
              : MigrationScreen(
                  state: migrationState,
                  reportContext: RestoreScreen.reportContext,
                ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            const CircularProgressIndicator(),
            if (text != null) Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Refused extends StatelessWidget {
  const _Refused({required this.reason});

  final RestoreRejection reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.report_gmailerrorred_rounded,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.restoreRejectedTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(rejectionText(l10n, reason), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picked backup is larger than the free space (R2): said plainly,
/// with OK back to Backup & restore.
class _NoSpace extends StatelessWidget {
  const _NoSpace({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).ok),
            ),
          ],
        ),
      ),
    ),
  );
}
