import 'package:material_ui/material_ui.dart';

import 'delayed_spinner.dart';

/// An empty screen in the app's background color for short waits at
/// startup (checking for migrations, opening the database). They usually
/// take a few milliseconds, and a "Checking your data…" screen flashing by
/// on every start looked alarming. A spinner appears only if the wait
/// lasts longer than [delay].
class QuietLoading extends StatelessWidget {
  const QuietLoading({super.key, this.delay = const Duration(seconds: 1)});

  final Duration delay;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: DelayedSpinner(delay: delay));
}
