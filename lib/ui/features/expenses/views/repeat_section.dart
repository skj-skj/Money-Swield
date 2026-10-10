import 'package:material_ui/material_ui.dart';

import '../../../../domain/periods.dart';
import '../../../../domain/recurrence.dart' show Schedule;
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/recurrence_text.dart';
import '../../../core/widgets/repeat_every_row.dart';
import '../../../core/widgets/repeat_number_field.dart';

/// The Repeats section at the end of the Add form (phase-7a.md §8.2): a
/// switch, then every N days / weeks / months / years, the rule in words,
/// the end (never or on a date), and what a Save adds.
///
/// Stateless: the form's cubit holds the settings; the screen owns the
/// Every field's controller like the form's other text fields, so typing
/// never moves the cursor.
class RepeatSection extends StatelessWidget {
  const RepeatSection({
    super.key,
    required this.repeat,
    required this.summary,
    required this.error,
    required this.startOn,
    required this.today,
    required this.defaultEndOn,
    required this.intervalController,
    required this.countController,
    required this.countFocus,
    required this.intervalFocus,
    required this.onToggled,
    required this.onFrequency,
    required this.onInterval,
    required this.onEnd,
    required this.onCount,
    required this.onPickEndDate,
  });

  /// Null while Repeats is off.
  final RepeatChoice? repeat;
  final RepeatSummary? summary;

  /// Shown after a Save attempt.
  final RepeatError? error;

  /// The first payment: the form's date.
  final String startOn;
  final String today;

  /// The date "On" ends on while none is picked (six months on): shown in
  /// its box, so the row says what choosing it means (it showed "—" on the
  /// Oppo; phase-7a.md §12a).
  final String defaultEndOn;

  final TextEditingController intervalController;

  /// The "After N payments" field (phase-7b.md §8.2), owned by the screen
  /// like Every's.
  final TextEditingController countController;

  /// Picking "After" focuses it, so the count can be typed at once.
  final FocusNode countFocus;

  /// Every's field; the screen keeps "Next …" in view while either has
  /// focus.
  final FocusNode intervalFocus;
  final ValueChanged<bool> onToggled;
  final ValueChanged<Frequency> onFrequency;
  final ValueChanged<String> onInterval;
  final ValueChanged<RepeatEnd> onEnd;
  final ValueChanged<String> onCount;

  /// Opens the date picker for the end.
  final VoidCallback onPickEndDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repeat = this.repeat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        SwitchListTile(
          key: const ValueKey('repeatsSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.repeat),
          title: Text(l10n.repeats),
          value: repeat != null,
          onChanged: onToggled,
        ),
        if (repeat != null) ..._settings(context, l10n, repeat),
      ],
    );
  }

  List<Widget> _settings(
    BuildContext context,
    AppLocalizations l10n,
    RepeatChoice repeat,
  ) {
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final interval = repeat.interval;
    final summary = this.summary;
    final error = this.error;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return [
      RepeatEveryRow(
        frequency: repeat.frequency,
        interval: interval,
        controller: intervalController,
        focusNode: intervalFocus,
        onInterval: onInterval,
        onFrequency: onFrequency,
        showError: error == RepeatError.intervalRange,
      ),
      if (interval != null) ...[
        const SizedBox(height: 4),
        // Each line its own node: merged, TalkBack read the rule, "Ends"
        // and "Next" as one, before the radio buttons (Oppo, §12a).
        Semantics(
          container: true,
          child: Text(
            // The rule only: not scheduleFor, which throws while After N
            // isn't valid yet ("After 1" typed; phase-7b.md §12a).
            scheduleText(
              l10n,
              locale,
              Schedule(
                frequency: repeat.frequency,
                interval: interval,
                startOn: startOn,
              ),
            ),
            key: const ValueKey('repeatSchedule'),
            style: muted,
          ),
        ),
      ],
      const SizedBox(height: 12),
      Semantics(
        container: true,
        header: true,
        child: Text(l10n.repeatEnds, style: theme.textTheme.titleSmall),
      ),
      RadioGroup<RepeatEnd>(
        groupValue: repeat.end,
        onChanged: (end) {
          if (end == null) return;
          onEnd(end);
          switch (end) {
            // Picking "On" asks for the date at once (§8.2).
            case RepeatEnd.onDate:
              onPickEndDate();
            // Picking "After" puts the cursor in its field, the count
            // selected, so typing replaces it (phase-7b.md §8.2).
            case RepeatEnd.afterCount:
              countFocus.requestFocus();
              // After the frame: the default count reaches the field
              // through the cubit first.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                countController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: countController.text.length,
                );
              });
            case RepeatEnd.never:
              break;
          }
        },
        child: Column(
          children: [
            RadioListTile<RepeatEnd>(
              key: const ValueKey('repeatEndsNever'),
              contentPadding: EdgeInsets.zero,
              value: RepeatEnd.never,
              title: Text(l10n.repeatEndsNever),
            ),
            RadioListTile<RepeatEnd>(
              key: const ValueKey('repeatEndsOn'),
              contentPadding: EdgeInsets.zero,
              value: RepeatEnd.onDate,
              title: _endOnRow(context, l10n, repeat, locale),
            ),
            RadioListTile<RepeatEnd>(
              key: const ValueKey('repeatEndsAfter'),
              contentPadding: EdgeInsets.zero,
              value: RepeatEnd.afterCount,
              title: _afterRow(l10n, repeat),
            ),
          ],
        ),
      ),
      if (_endErrorText(l10n, locale, error) case final text?)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      if (summary != null) ..._summaryLines(context, l10n, locale, summary),
    ];
  }

  /// "On [ 9 Apr 2027 ]": the date box opens the picker too.
  Widget _endOnRow(
    BuildContext context,
    AppLocalizations l10n,
    RepeatChoice repeat,
    String locale,
  ) {
    final endOn = repeat.endOn ?? defaultEndOn;
    final dateText = shortDateText(locale, parseDay(endOn));
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(l10n.repeatEndsOn),
        Semantics(
          container: true,
          button: true,
          label:
              '${l10n.repeatEndDate}: '
              '${longDateText(locale, parseDay(endOn))}',
          excludeSemantics: true,
          child: OutlinedButton.icon(
            key: const ValueKey('repeatEndDate'),
            onPressed: onPickEndDate,
            icon: const Icon(Icons.event, size: 18),
            label: Text(dateText),
          ),
        ),
      ],
    );
  }

  /// "After [ 12 ] payments" (phase-7b.md §8.2): the field takes three
  /// digits; its error ("2 to 999") shows under it after a Save attempt.
  /// A Wrap, so a large font puts the words under the field.
  Widget _afterRow(AppLocalizations l10n, RepeatChoice repeat) {
    final showError = error == RepeatError.countRange;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        ExcludeSemantics(child: Text(l10n.repeatEndsAfter)),
        RepeatNumberField(
          fieldKey: const ValueKey('repeatCount'),
          // TalkBack: "Number of payments, 12".
          label: l10n.repeatCountLabel,
          hint: defaultRepeatCountText,
          controller: countController,
          focusNode: countFocus,
          onChanged: onCount,
          maxDigits: 3,
          width: 88,
          errorText: showError
              ? l10n.repeatCountError(2, maxRepeatCount)
              : null,
        ),
        ExcludeSemantics(
          // The plural of what is typed, "1" too (refused at Save): "After
          // 1 payment", not "1 payments".
          child: Text(
            l10n.repeatEndsAfterUnit(int.tryParse(repeat.countText) ?? 2),
          ),
        ),
      ],
    );
  }

  String? _endErrorText(
    AppLocalizations l10n,
    String locale,
    RepeatError? error,
  ) => switch (error) {
    RepeatError.endMissing => l10n.repeatEndMissing,
    RepeatError.endBeforeStart => l10n.repeatEndBeforeStart(
      shortDateText(locale, parseDay(startOn)),
    ),
    // After N: the N-th payment would fall after the last date allowed.
    RepeatError.endTooLate when repeat?.end == RepeatEnd.afterCount =>
      l10n.repeatCountTooLate(shortDateText(locale, parseDay(lastEndOn))),
    RepeatError.endTooLate => l10n.repeatEndTooLate(
      shortDateText(locale, parseDay(lastEndOn)),
    ),
    RepeatError.intervalRange ||
    RepeatError.countRange ||
    RepeatError.tooManyPast ||
    null => null,
  };

  /// The earlier payments a Save adds (or that there are too many), then
  /// the next payment. A live region: TalkBack reads a change.
  List<Widget> _summaryLines(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    RepeatSummary summary,
  ) {
    final theme = Theme.of(context);
    final tooMany = summary.pastCount > maxPastPayments;
    return [
      const SizedBox(height: 8),
      if (tooMany)
        _line(
          context,
          icon: Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          text: l10n.repeatTooManyPast(summary.pastCount, maxPastPayments),
          key: const ValueKey('repeatTooMany'),
        )
      else if (summary.past.isNotEmpty)
        _line(
          context,
          icon: Icons.info_outline,
          color: theme.colorScheme.onSurfaceVariant,
          text: l10n.repeatAlsoAdds(
            summary.past.length,
            daysListText(l10n, locale, summary.past, today: today),
          ),
          key: const ValueKey('repeatAlsoAdds'),
        ),
      if (!tooMany)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              [
                nextText(l10n, locale, summary.next, today: today),
                // With an end, its last payment too (phase-7b.md §8.2).
                if (summary.last case final last? when summary.next != null)
                  l10n.repeatLast(dayText(locale, last, today: today)),
              ].join(' · '),
              key: const ValueKey('repeatNext'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
    ];
  }

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
    required Key key,
  }) => Semantics(
    container: true,
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            key: key,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
