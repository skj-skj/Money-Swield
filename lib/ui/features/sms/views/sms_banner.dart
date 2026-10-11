import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/sms_suggestion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/widgets/form_banner.dart';
import 'sms_texts.dart';

/// Above an Add form filled from an SMS (phase-9a.md §8.4, P9a-20): "From
/// SMS · VM-ABCBNK-S · 9 Oct, 2:05 pm". Sender and time only: the text
/// isn't kept (P9a-19).
class SmsBanner extends StatelessWidget {
  const SmsBanner({super.key, required this.sms});

  final SmsSuggestion sms;

  @override
  Widget build(BuildContext context) => FormBanner(
    icon: Icons.sms_outlined,
    text: AppLocalizations.of(context)
        .smsFromBanner(sms.sender, smsMomentText(dateLocaleOf(context), sms)),
  );
}
