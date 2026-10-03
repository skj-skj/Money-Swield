import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../data/services/backup/pre_restore_copy.dart';
import '../domain/models/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/widgets/error_report_view.dart';
import '../ui/core/widgets/quiet_loading.dart';
import '../ui/features/backup/views/restore_screen.dart';
import '../ui/features/onboarding/views/onboarding_screen.dart';
import '../ui/features/settings/view_models/settings_cubit.dart';
import 'app_dependencies.dart';
import 'restore_tools.dart';
import 'shell.dart';
import 'startup_cubit.dart';

/// Shown once migrations are done: opens the database, loads the settings,
/// then shows onboarding or the shell (phase-1.md §5).
///
/// Finishing onboarding sets `onboardingCompleted`, which swaps onboarding
/// for the shell here, so there is no route back to it.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.openDependencies,
    this.restoreTools,
  });

  final Future<AppDependencies> Function() openDependencies;

  /// For "Undo last restore" when startup fails. Null: not offered.
  final RestoreTools? restoreTools;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final StartupCubit _cubit;

  @override
  void initState() {
    super.initState();
    final tools = widget.restoreTools;
    _cubit = StartupCubit(
      openDependencies: widget.openDependencies,
      settingsCubit: context.read<SettingsCubit>(),
      newestPreRestoreCopy: tools == null
          ? null
          : () async =>
                (await tools.appDatabase.preRestoreCopies()).firstOrNull,
    )..start();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  /// "Undo last restore" on the startup-failed screen: the database is
  /// already closed (StartupCubit closes it on failure), and there's no
  /// data to count.
  void _undoRestore(RestoreTools tools, PreRestoreCopy copy) =>
      RestoreScreen.open(
        context,
        tools: tools,
        closeLiveConnection: () async {},
        copy: copy,
      );

  void _restoreFromOnboarding(AppDependencies dependencies) =>
      RestoreScreen.open(
        context,
        tools: dependencies.restoreTools,
        closeLiveConnection: dependencies.database.close,
      );

  @override
  Widget build(BuildContext context) {
    final tools = widget.restoreTools;
    return BlocSignalBuilder<StartupCubit, StartupState>(
      bloc: _cubit,
      builder: (context, state) => switch (state) {
        // Opening the database and reading the settings takes a moment;
        // a spinner flashing by on every start looked alarming.
        StartupLoading() => const QuietLoading(),
        StartupFailed(:final undoCopy) => _StartupFailedScreen(
          failure: state,
          onRetry: _cubit.start,
          onUndoRestore: tools == null || undoCopy == null
              ? null
              : () => _undoRestore(tools, undoCopy),
        ),
        StartupReady(:final dependencies) =>
          BlocSignalBuilder<SettingsCubit, AppSettings>(
            buildWhen: (previous, current) =>
                previous.onboardingCompleted != current.onboardingCompleted,
            builder: (context, settings) => settings.onboardingCompleted
                ? Shell(dependencies: dependencies)
                : OnboardingScreen(
                    paymentMethods: dependencies.paymentMethods,
                    onRestoreFromBackup: () =>
                        _restoreFromOnboarding(dependencies),
                  ),
          ),
      },
    );
  }
}

class _StartupFailedScreen extends StatelessWidget {
  const _StartupFailedScreen({
    required this.failure,
    required this.onRetry,
    required this.onUndoRestore,
  });

  final StartupFailed failure;
  final VoidCallback onRetry;

  /// Offered when a pre-restore copy exists (P3-18): otherwise a restored
  /// database that can't start the app would leave the user stuck, as Undo
  /// normally lives in Settings.
  final VoidCallback? onUndoRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onUndo = onUndoRestore;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorReportView(
            title: l10n.startupFailedTitle,
            message: l10n.startupFailedMessage,
            report: failure.report,
            onRetry: onRetry,
            secondaryAction: onUndo == null
                ? null
                : TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo),
                    label: Text(l10n.undoLastRestore),
                  ),
          ),
        ),
      ),
    );
  }
}
