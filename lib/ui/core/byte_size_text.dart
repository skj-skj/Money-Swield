import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// [bytes] for people (phase-6.md §5.4): `0 B`, `999 B`, `1.0 KB`,
/// `1.5 MB`, `1.2 GB`; 1024-based, one decimal from KB, with [locale]'s
/// decimal separator (`1,2 GB` in es) and grouping. A value that would
/// round up to 1024 of a unit is shown in the next one (`1.0 MB`, never
/// `1024.0 KB`). [locale] is the formatting locale (`formattingLocaleOf`).
String byteSizeText(AppLocalizations l10n, String locale, int bytes) {
  if (bytes < 1024) {
    return l10n.sizeBytes(NumberFormat.decimalPattern(locale).format(bytes));
  }
  final units = [l10n.sizeKilobytes, l10n.sizeMegabytes, l10n.sizeGigabytes];
  final format = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 1,
  );
  var value = bytes / 1024;
  var unit = 0;
  // Rounded as shown, so 1,048,575 bytes is 1.0 MB, not 1024.0 KB.
  while (unit < units.length - 1 && (value * 10).round() >= 10240) {
    value /= 1024;
    unit++;
  }
  return units[unit](format.format(value));
}
