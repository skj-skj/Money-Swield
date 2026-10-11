import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/sms_suggestion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';

/// When [sms] came, for the form's banner: "9 Oct, 2:05 pm" on the clock
/// where it was scanned ([SmsSuggestion.wallClock]), like its card.
String smsMomentText(String locale, SmsSuggestion sms) =>
    '${cachedDateFormat('MMMd', locale).format(sms.wallClock)}, '
    '${timeText(locale, sms.wallClock)}';

/// "Checked 14:05": when the inbox was last read ([at], a moment), on the
/// SMS screen's empty state and Settings → SMS.
String smsLastCheckedText(BuildContext context, DateTime at) =>
    AppLocalizations.of(context)
        .smsLastChecked(timeText(dateLocaleOf(context), at.toLocal()));
