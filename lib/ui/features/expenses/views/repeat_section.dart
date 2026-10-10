import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/periods.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/recurrence_text.dart';

/// What the section says under the rule: the earlier payments a Save adds,
/// how many in all, and the next payment after them.
typedef RepeatSummary = ({List<String> past, int pastCount, String? next});

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
    required this.onToggled,
    required this.onFrequency,
    required this.onInterval,
    required this.onEnd,
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
  final ValueChanged<bool> onToggled;
  final ValueChanged<Frequency> onFrequency;
  final ValueChanged<String> onInterval;
  final ValueChanged<RepeatEnd> onEnd;

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
      _everyRow(context, l10n, repeat),
      if (interval != null) ...[
        const SizedBox(height: 4),
        // Each line its own node: merged, TalkBack read the rule, "Ends"
        // and "Next" as one, before the radio buttons (Oppo, §12a).
        Semantics(
          container: true,
          child: Text(
            scheduleText(l10n, locale, scheduleFor(repeat, startOn)),
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
          // Picking "On" asks for the date at once (§8.2).
          if (end == RepeatEnd.onDate) onPickEndDate();
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

  /// "Every [ 1 ] [ month ▾ ]". A Wrap, so at a large font the dropdown
  /// goes under the field instead of being cut (§8.2).
  Widget _everyRow(
    BuildContext context,
    AppLocalizations l10n,
    RepeatChoice repeat,
  ) {
    final count = repeat.interval ?? 1;
    final showError = error == RepeatError.intervalRange;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        // The field carries the label for TalkBack ("Every, 1").
        ExcludeSemantics(child: Text(l10n.repeatEvery)),
        SizedBox(
          width: 72,
          child: TextField(
            key: const ValueKey('repeatInterval'),
            controller: intervalController,
            onChanged: onInterval,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              labelText: l10n.repeatEvery,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              // The label is for TalkBack; the text before the field shows
              // it. A hint keeps it out of an empty field's way.
              hintText: '1',
              errorText: showError
                  ? l10n.repeatIntervalError(maxRepeatInterval)
                  : null,
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        DropdownButton<Frequency>(
          key: const ValueKey('repeatFrequency'),
          value: repeat.frequency,
          onChanged: (f) {
            if (f != null) onFrequency(f);
          },
          items: [
            for (final f in Frequency.values)
              DropdownMenuItem(value: f, child: Text(unitText(l10n, f, count))),
          ],
        ),
      ],
    );
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

  String? _endErrorText(
    AppLocalizations l10n,
    String locale,
    RepeatError? error,
  ) => switch (error) {
    RepeatError.endMissing => l10n.repeatEndMissing,
    RepeatError.endBeforeStart => l10n.repeatEndBeforeStart(
      shortDateText(locale, parseDay(startOn)),
    ),
    RepeatError.endTooLate => l10n.repeatEndTooLate(
      shortDateText(locale, parseDay(lastEndOn)),
    ),
    RepeatError.intervalRange || RepeatError.tooManyPast || null => null,
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
              nextText(l10n, locale, summary.next, today: today),
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
