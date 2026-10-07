import 'package:material_ui/material_ui.dart';

import 'load_failed_view.dart';

/// Where a screen's data is: being read, failed, read but empty, or read.
enum LoadPhase { loading, failed, empty, loaded }

/// A screen's body for each [LoadPhase]: a spinner, `LoadFailedView` with
/// [onRetry], [empty], or what [builder] builds. The list screens map
/// their cubit's state to a phase, so all of them wait, fail and show
/// "nothing here" the same way.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.phase,
    required this.onRetry,
    required this.empty,
    required this.builder,
  });

  final LoadPhase phase;
  final VoidCallback onRetry;
  final Widget empty;

  /// Called only in [LoadPhase.loaded].
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => switch (phase) {
    LoadPhase.loading => const Center(child: CircularProgressIndicator()),
    LoadPhase.failed => LoadFailedView(onRetry: onRetry),
    LoadPhase.empty => empty,
    LoadPhase.loaded => builder(context),
  };
}
