import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/database/migration/migration_runner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/done_check.dart';
import '../../../core/widgets/error_report_view.dart';
import '../../../core/widgets/quiet_loading.dart';
import '../view_models/migration_cubit.dart';

/// Shows migration progress on app start and switches to [child] once the
/// database is up to date. Reads the [MigrationCubit] from the nearest
/// [BlocSignalProvider].
///
/// Nothing shows while it is only checking whether anything is pending
/// (the usual case: a few milliseconds and nothing to do). The progress
/// screen appears only when migrations really run, and then ends on
/// "Database initialized" / "Update done successfully" with Continue.
class MigrationGate extends StatelessWidget {
  const MigrationGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<MigrationCubit, MigrationState>(
      builder: (context, state) =>
          state is MigrationDone ? child : MigrationScreen(state: state),
    );
  }
}

class MigrationScreen extends StatelessWidget {
  const MigrationScreen({super.key, required this.state, this.reportContext});

  final MigrationState state;

  /// A first line for the failure report, e.g. that it happened while restoring
  /// a backup.
  final String? reportContext;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MigrationCubit>();
    if (_isOnlyChecking(state)) return const QuietLoading();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state) {
            MigrationFailed(:final failure) => _FailureView(
              failure: failure,
              reportContext: reportContext,
              onRetry: cubit.run,
            ),
            MigrationAsking(:final question) => _QuestionView(
              key: ValueKey(question),
              question: question,
              onAnswer: cubit.answer,
            ),
            MigrationInProgress(:final progress) => _ProgressView(
              progress: progress,
            ),
            MigrationSucceeded(:final outcome) => _SucceededView(
              outcome: outcome,
              onContinue: cubit.acknowledge,
            ),
            // MigrationGate shows the app instead; this only shows for the
            // single frame before it switches over.
            MigrationDone() => const _ProgressView(progress: null),
          },
        ),
      ),
    );
  }

  /// Before the runner knows whether anything is pending.
  static bool _isOnlyChecking(MigrationState state) => switch (state) {
    MigrationInProgress(:final progress) =>
      progress == null || progress.stage == MigrationStage.checking,
    _ => false,
  };
}

/// The end of a real migration run: a circle fills, a tick appears, then
/// Continue. So the user sees that it worked, instead of the app jumping
/// straight to onboarding or Home.
class _SucceededView extends StatefulWidget {
  const _SucceededView({required this.outcome, required this.onContinue});

  final MigrationOutcome outcome;
  final VoidCallback onContinue;

  @override
  State<_SucceededView> createState() => _SucceededViewState();
}

class _SucceededViewState extends State<_SucceededView> {
  var _ticked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final installed = widget.outcome == MigrationOutcome.installed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DoneCheck(onCompleted: () => setState(() => _ticked = true)),
          const SizedBox(height: 24),
          Text(
            installed
                ? l10n.migrationInstalledTitle
                : l10n.migrationUpdatedTitle,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            installed
                ? l10n.migrationInstalledMessage
                : l10n.migrationUpdatedMessage,
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Appears once the tick is drawn; keeps its space meanwhile so
          // nothing jumps.
          AnimatedOpacity(
            opacity: _ticked ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: FilledButton(
              onPressed: _ticked ? widget.onContinue : null,
              child: Text(l10n.continueButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress});

  final MigrationProgress? progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final progress = this.progress;
    final isMigrating = progress != null && progress.total > 0;

    final (title, detail) = switch (progress?.stage) {
      null || MigrationStage.checking => (l10n.migrationChecking, null),
      MigrationStage.backingUp => (l10n.migrationBackingUp, null),
      MigrationStage.migrating => (
        l10n.migrationUpdating(progress!.completed + 1, progress.total),
        progress.current?.name,
      ),
      MigrationStage.verifying => (l10n.migrationVerifying, null),
      MigrationStage.done => (l10n.migrationDone, null),
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storage_rounded, size: 56),
          const SizedBox(height: 24),
          Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: isMigrating ? progress.completed / progress.total : null,
          ),
          if (isMigrating) ...[
            const SizedBox(height: 16),
            Text(l10n.migrationKeepOpen, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _QuestionView extends StatefulWidget {
  const _QuestionView({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final MigrationQuestion question;
  final ValueChanged<String> onAnswer;

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  late final _controller = TextEditingController(
    text: widget.question.initialValue ?? '',
  );

  /// The picked option, for a choice.
  late String? _selected = widget.question.initialValue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = widget.question.options;
    final selected = _selected;
    final canContinue = options == null || selected != null;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.migrationQuestionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              widget.question.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (options != null)
              for (final option in options)
                ListTile(
                  leading: Icon(
                    option == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(option),
                  selected: option == selected,
                  onTap: () => setState(() => _selected = option),
                )
            else
              TextField(
                controller: _controller,
                autofocus: true,
                onSubmitted: widget.onAnswer,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canContinue
                  ? () => widget.onAnswer(
                      options == null ? _controller.text : selected!,
                    )
                  : null,
              child: Text(l10n.continueButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.failure,
    required this.reportContext,
    required this.onRetry,
  });

  final MigrationFailure failure;
  final String? reportContext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final migration = failure.migration;
    return ErrorReportView(
      title: l10n.migrationFailedTitle,
      message: l10n.migrationFailedMessage,
      // The step text (e.g. "Starting database") stays in English: it is
      // part of the report the user sends us.
      detail: migration == null
          ? failure.step
          : l10n.migrationFailedStep('$migration'),
      report: [?reportContext, failure.report].join('\n'),
      onRetry: onRetry,
    );
  }
}
