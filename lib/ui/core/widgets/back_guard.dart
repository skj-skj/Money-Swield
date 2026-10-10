import 'package:material_ui/material_ui.dart';

/// While [intercept] is true, Back (the system gesture, the button or the
/// app bar arrow) runs [onBack] instead of leaving: close a search or a
/// selection first, ask before discarding changes, or leave with a result.
/// Otherwise Back leaves as usual.
class BackGuard extends StatelessWidget {
  const BackGuard({
    super.key,
    this.intercept = true,
    required this.onBack,
    required this.child,
  });

  final bool intercept;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !intercept,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onBack();
    },
    child: child,
  );
}
