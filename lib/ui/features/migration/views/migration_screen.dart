import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/database/migration/migration_runner.dart';
import '../view_models/migration_view_model.dart';

/// Shows migration progress on app start and switches to [child] once the
/// database is up to date.
class MigrationGate extends StatelessWidget {
  const MigrationGate({super.key, required this.viewModel, required this.child});

  final MigrationViewModel viewModel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => viewModel.isDone ? child : MigrationScreen(viewModel: viewModel),
    );
  }
}

class MigrationScreen extends StatelessWidget {
  const MigrationScreen({super.key, required this.viewModel});

  final MigrationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final failure = viewModel.failure;
    final question = viewModel.question;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch ((failure, question)) {
            (final MigrationFailure failure, _) => _FailureView(failure: failure, onRetry: viewModel.run),
            (_, final MigrationQuestion question) => _QuestionView(
              key: ValueKey(question),
              question: question,
              onAnswer: viewModel.answer,
            ),
            _ => _ProgressView(progress: viewModel.progress),
          },
        ),
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
    final progress = this.progress;
    final isMigrating = progress != null && progress.total > 0;

    final (title, detail) = switch (progress?.stage) {
      null || MigrationStage.checking => ('Checking your data…', null),
      MigrationStage.backingUp => ('Backing up your data…', null),
      MigrationStage.migrating => (
        'Updating your data (${progress!.completed + 1} of ${progress.total})',
        progress.current?.name,
      ),
      MigrationStage.verifying => ('Verifying your data…', null),
      MigrationStage.done => ('Done', null),
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
            Text(detail, style: textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          LinearProgressIndicator(value: isMigrating ? progress.completed / progress.total : null),
          if (isMigrating) ...[
            const SizedBox(height: 16),
            Text('Please keep the app open.', style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _QuestionView extends StatefulWidget {
  const _QuestionView({super.key, required this.question, required this.onAnswer});

  final MigrationQuestion question;
  final ValueChanged<String> onAnswer;

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  late final _controller = TextEditingController(text: widget.question.initialValue ?? '');

  /// The picked option, for a choice.
  late String? _selected = widget.question.initialValue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.question.options;
    final selected = _selected;
    final canContinue = options == null || selected != null;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('One quick question', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(widget.question.text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (options != null)
              for (final option in options)
                ListTile(
                  leading: Icon(option == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
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
              onPressed: canContinue ? () => widget.onAnswer(options == null ? _controller.text : selected!) : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure, required this.onRetry});

  final MigrationFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final migration = failure.migration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline_rounded, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text('Updating your data failed', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Your data was not changed by the failed step. '
          'Please copy the report below and send it to us so we can fix it in the next update.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          migration == null ? failure.step : 'Failed migration: $migration',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                failure.report,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: failure.report));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied')));
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy error report'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
