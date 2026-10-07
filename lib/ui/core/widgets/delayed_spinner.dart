import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A spinner that appears only after [delay]: most waits are a few
/// milliseconds, and a spinner flashing by on each is noise (or, on the
/// startup screens, alarming). Until then it takes its [size] but draws
/// nothing; null [size] fills what it is given, as a centred spinner.
class DelayedSpinner extends StatefulWidget {
  const DelayedSpinner({
    super.key,
    required this.delay,
    this.size,
    this.strokeWidth = 4,
  });

  final Duration delay;
  final double? size;
  final double strokeWidth;

  @override
  State<DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<DelayedSpinner> {
  late final Timer _timer;
  var _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinner = _shown
        ? CircularProgressIndicator(strokeWidth: widget.strokeWidth)
        : const SizedBox.shrink();
    final size = widget.size;
    return size == null
        ? Center(child: spinner)
        : SizedBox.square(dimension: size, child: spinner);
  }
}
