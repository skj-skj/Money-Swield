/// The app's date and time pickers: every screen opens them the same way
/// (phase-7a.md review): the formatting locale, and the way the user last
/// left them (calendar or typing, dial or keyboard), remembered in the
/// settings.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/periods.dart';
import '../features/settings/view_models/settings_cubit.dart';
import 'formatting_locale.dart';

/// A day from the date picker, from [first] to [last] (`YYYY-MM-DD`),
/// opening on [initial] (moved into the range), or null when cancelled.
/// [helpText] replaces the picker's "Select date".
Future<String?> pickDay(
  BuildContext context, {
  required String initial,
  required String first,
  required String last,
  String? helpText,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final settings = context.read<SettingsCubit>();
  final from = _localDate(first);
  final to = _localDate(last);
  var opening = _localDate(initial);
  if (opening.isBefore(from)) opening = from;
  if (opening.isAfter(to)) opening = to;
  final picked = await showDatePicker(
    context: context,
    initialDate: opening,
    firstDate: from,
    lastDate: to,
    helpText: helpText,
    // The app language with the phone's country, like the rest of the
    // dates (and money).
    locale: formattingLocaleValueOf(context),
    initialEntryMode: settings.value.datePickerKeyboard
        ? DatePickerEntryMode.input
        : DatePickerEntryMode.calendar,
    onDatePickerModeChange: (mode) => _remember(
      () => settings.setDatePickerKeyboard(mode == DatePickerEntryMode.input),
    ),
  );
  return picked == null ? null : isoDay(picked);
}

/// A time of day from the time picker, opening on [hour]:[minute], or null
/// when cancelled.
Future<TimeOfDay?> pickTimeOfDay(
  BuildContext context, {
  required int hour,
  required int minute,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final settings = context.read<SettingsCubit>();
  return showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: hour, minute: minute),
    initialEntryMode: settings.value.timePickerKeyboard
        ? TimePickerEntryMode.input
        : TimePickerEntryMode.dial,
    onEntryModeChanged: (mode) => _remember(
      () => settings.setTimePickerKeyboard(mode == TimePickerEntryMode.input),
    ),
  );
}

/// [day] as a local midnight, which the date picker works in.
DateTime _localDate(String day) {
  final d = parseDay(day);
  return DateTime(d.year, d.month, d.day);
}

/// Remembering the picker mode is a convenience: a failed write is only
/// logged, it mustn't disturb picking the date or time.
void _remember(Future<void> Function() save) {
  save().catchError((Object error) {
    debugPrint('Remembering the picker mode failed: $error');
  });
}
