import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/widgets/error_report_view.dart';
import '../ui/features/onboarding/views/onboarding_screen.dart';
import '../ui/features/settings/view_models/settings_cubit.dart';
import 'app_dependencies.dart';
import 'shell.dart';
import 'startup_cubit.dart';

/// Shown once migrations are done: opens the database, loads the settings,
/// then shows onboarding or the shell (phase-1.md §5).
///
/// Finishing onboarding sets `onboardingCompleted`, which swaps onboarding
/// for the shell here, so there is no route back to it.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.openDependencies});

  final Future<AppDependencies> Function() openDependencies;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final StartupCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = StartupCubit(
      openDependencies: widget.openDependencies,
      settingsCubit: context.read<SettingsCubit>(),
    )..start();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<StartupCubit, StartupState>(
      bloc: _cubit,
      builder: (context, state) => switch (state) {
        StartupLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        StartupFailed() => _StartupFailedScreen(
          failure: state,
          onRetry: _cubit.start,
        ),
        StartupReady(:final dependencies) =>
          BlocSignalBuilder<SettingsCubit, AppSettings>(
            buildWhen: (previous, current) =>
                previous.onboardingCompleted != current.onboardingCompleted,
            builder: (context, settings) => settings.onboardingCompleted
                ? Shell(dependencies: dependencies)
                : OnboardingScreen(paymentMethods: dependencies.paymentMethods),
          ),
      },
    );
  }
}

class _StartupFailedScreen extends StatelessWidget {
  const _StartupFailedScreen({required this.failure, required this.onRetry});

  final StartupFailed failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorReportView(
            title: l10n.startupFailedTitle,
            message: l10n.startupFailedMessage,
            report: failure.report,
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
