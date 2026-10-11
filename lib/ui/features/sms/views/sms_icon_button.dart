import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../view_models/sms_cubit.dart';

/// Home's SMS icon, first in the icon row (phase-9a.md §8.1, P9a-6): hidden
/// while SMS is off or not built; a count badge in the tertiary colour
/// while suggestions wait (not the filter dot's colour); `sms_failed`
/// without a badge when the permission is off. Never greyed by Home's
/// filters (P9a-7): the SMS screen ignores them.
class SmsIconButton extends StatelessWidget {
  const SmsIconButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final SmsState state;
  final VoidCallback onPressed;

  /// Whether [state] shows the icon at all.
  static bool showsFor(SmsState state) =>
      state.availability == SmsAvailability.on ||
      state.availability == SmsAvailability.needsPermission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final needsPermission =
        state.availability == SmsAvailability.needsPermission;
    final count = needsPermission ? 0 : state.pendingCount;
    // Room for a wide badge ("99+") so it doesn't run over the next icon,
    // and its text scaled at most 1.3×: at the Oppo's largest font the
    // badge covered the filter icon (phase-9a.md §12a).
    return Padding(
      padding: EdgeInsetsDirectional.only(end: count > 9 ? 14 : 0),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: badgeMaxTextScale,
        child: _button(l10n, scheme, needsPermission, count),
      ),
    );
  }

  /// The badge's largest text scale.
  static const badgeMaxTextScale = 1.3;

  Widget _button(
    AppLocalizations l10n,
    ColorScheme scheme,
    bool needsPermission,
    int count,
  ) {
    return IconButton(
      key: const ValueKey('smsButton'),
      tooltip: needsPermission
          ? l10n.smsPermissionOff
          : count > 0
          ? l10n.smsNewCount(count)
          : l10n.smsSuggestions,
      onPressed: onPressed,
      icon: Badge.count(
        // Its default is 999 (phase-9a.md §8.1).
        maxCount: 99,
        count: count,
        isLabelVisible: count > 0,
        backgroundColor: scheme.tertiary,
        textColor: scheme.onTertiary,
        child: Icon(
          needsPermission ? Icons.sms_failed_outlined : Icons.sms_outlined,
        ),
      ),
    );
  }
}
