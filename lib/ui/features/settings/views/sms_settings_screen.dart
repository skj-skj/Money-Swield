import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../sms/view_models/sms_cubit.dart';
import '../../sms/views/sms_texts.dart';

/// Settings → SMS (phase-9a.md §8.5, P9a-29): the SMS suggestions switch
/// (the permission is asked when it is turned on), when the inbox was last
/// read, and what the app keeps. Turning it off keeps the suggestions
/// (until the 30-day purge).
class SmsSettingsScreen extends StatelessWidget {
  const SmsSettingsScreen({super.key, required this.sms});

  final SmsCubit sms;

  Future<void> _toggle(BuildContext context, bool on) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      await saveOrShowError(context, sms.disable);
      return;
    }
    var result = SmsEnableResult.enabled;
    await saveOrShowError(context, () async => result = await sms.enable());
    if (result == SmsEnableResult.refused) {
      showMessage(messenger, l10n.smsPermissionRefused, long: true);
    }
  }

  /// "Use on-device AI" (phase-9b.md §8): play with a model in or one that
  /// can come, SMS on. The help stays while the model downloads, so what
  /// it does and that nothing leaves the phone is always there.
  Widget _aiSwitch(BuildContext context, SmsState state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SwitchListTile(
      key: const ValueKey('smsAiSwitch'),
      title: Text(l10n.smsAiSetting),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.smsAiHelp),
          if (state.aiDownloading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.smsAiDownloading,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      value: state.aiSwitchOn,
      onChanged: (value) =>
          saveOrShowError(context, () => sms.setAiParsing(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.smsTile)),
      body: BlocSignalBuilder<SmsCubit, SmsState>(
        bloc: sms,
        builder: (context, state) {
          final on =
              state.availability == SmsAvailability.on ||
              state.availability == SmsAvailability.needsPermission;
          final lastScanAt = state.lastScanAt;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SwitchListTile(
                key: const ValueKey('smsSwitch'),
                title: Text(l10n.smsSuggestions),
                subtitle: state.availability == SmsAvailability.needsPermission
                    ? Text(l10n.smsPermissionOff)
                    : lastScanAt == null
                    ? null
                    : Text(smsLastCheckedText(context, lastScanAt)),
                value: on,
                onChanged: (value) => _toggle(context, value),
              ),
              if (state.showsAi) _aiSwitch(context, state),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(l10n.smsPrivacyNote, style: muted),
              ),
            ],
          );
        },
      ),
    );
  }
}
