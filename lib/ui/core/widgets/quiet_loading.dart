import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// An empty screen in the app's background color for short waits at
/// startup (checking for migrations, opening the database). They usually
/// take a few milliseconds, and a "Checking your data…" screen flashing by
/// on every start looked alarming. A spinner appears only if the wait
/// lasts longer than [delay].
class QuietLoading extends StatefulWidget {
  const QuietLoading({super.key, this.delay = const Duration(seconds: 1)});

  final Duration delay;

  @override
  State<QuietLoading> createState() => _QuietLoadingState();
}

class _QuietLoadingState extends State<QuietLoading> {
  late final Timer _timer;
  var _showSpinner = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () => setState(() => _showSpinner = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showSpinner
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink(),
    );
  }
}
