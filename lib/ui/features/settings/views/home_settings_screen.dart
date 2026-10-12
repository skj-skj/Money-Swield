import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/charts/charts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/choice_setting_tile.dart';
import '../../../core/widgets/confirm_then_save.dart';
import '../../home/views/trend_card.dart';
import '../view_models/settings_cubit.dart';

/// Settings → Home: the trend chart's style, where the trend card sits, the
/// first day of a week and how weeks are named. Each is a choice dialog; every
/// change applies at once, Home follows.
class HomeSettingsScreen extends StatelessWidget {
  const HomeSettingsScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsHome)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => ListView(
          children: [
            ChoiceSettingTile<TrendChartStyle>(
              icon: Icons.show_chart,
              title: l10n.settingTrendChart,
              values: TrendChartStyle.values,
              current: settings.trendChartStyle,
              label: (style) => chartStyleName(l10n, style),
              option: (style) => Row(
                children: [
                  SeriesChartPreview(
                    kind: chartKindOf(style),
                    sample: style == TrendChartStyle.runningTotal
                        ? const [0.1, 0.3, 0.4, 0.7, 0.8, 0.8, 1]
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(chartStyleName(l10n, style))),
                ],
              ),
              onSave: cubit.setTrendChartStyle,
            ),
            ChoiceSettingTile<TrendCardPosition>(
              icon: Icons.vertical_align_top,
              title: l10n.settingTrendCard,
              values: TrendCardPosition.values,
              current: settings.trendCardPosition,
              label: (position) => cardPositionName(l10n, position),
              onSave: cubit.setTrendCardPosition,
            ),
            ChoiceSettingTile<TrendCardSize>(
              icon: Icons.height,
              title: l10n.settingTrendCardSize,
              values: TrendCardSize.values.reversed.toList(),
              current: settings.trendCardSize,
              label: (size) => cardSizeName(l10n, size),
              onSave: cubit.setTrendCardSize,
            ),
            ChoiceSettingTile<WeekStart>(
              icon: Icons.calendar_view_week,
              title: l10n.settingWeekStart,
              values: WeekStart.values,
              current: settings.weekStart,
              label: (start) => weekStartName(locale, start),
              onSave: cubit.setWeekStart,
            ),
            ChoiceSettingTile<WeekLabel>(
              icon: Icons.label_outline,
              title: l10n.settingWeekNames,
              values: WeekLabel.values,
              current: settings.weekLabel,
              label: (label) => _weekExample(context, settings, label),
              onSave: cubit.setWeekLabel,
            ),
            ListTile(
              key: const ValueKey('restoreHomeDefaults'),
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(l10n.restoreHomeDefaults),
              subtitle: Text(l10n.restoreHomeDefaultsSubtitle),
              onTap: () => _restoreDefaults(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks first, like Restore default look, then puts the chart, the card
  /// and the weeks back to their defaults (owner, 2026-10-06).
  Future<void> _restoreDefaults(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    await confirmThenSave(
      context,
      title: l10n.restoreHomeDefaultsTitle,
      message: l10n.restoreHomeDefaultsMessage,
      confirmLabel: l10n.restore,
      action: cubit.restoreHomeDefaults,
    );
  }

  /// The current week named the [label] way: "Oct Week 2" or "Week 41".
  String _weekExample(
    BuildContext context,
    AppSettings settings,
    WeekLabel label,
  ) {
    final today = todayOn(dependencies.now());
    return PeriodNames.of(
      context,
      today: today,
      weekLabel: label,
    ).week(periodOf(today, Period.week, settings.weekStart));
  }
}

String chartStyleName(AppLocalizations l10n, TrendChartStyle style) =>
    switch (style) {
      TrendChartStyle.lineFilled => l10n.chartLineFilled,
      TrendChartStyle.line => l10n.chartLine,
      TrendChartStyle.bar => l10n.chartBars,
      TrendChartStyle.dots => l10n.chartDots,
      TrendChartStyle.runningTotal => l10n.chartRunningTotal,
    };

String cardSizeName(AppLocalizations l10n, TrendCardSize size) =>
    switch (size) {
      TrendCardSize.small => l10n.cardSizeSmall,
      TrendCardSize.medium => l10n.cardSizeMedium,
      TrendCardSize.large => l10n.cardSizeLarge,
    };

String cardHapticsName(AppLocalizations l10n, CardHaptics haptics) =>
    switch (haptics) {
      CardHaptics.off => l10n.hapticsOff,
      CardHaptics.light => l10n.hapticsLight,
      CardHaptics.medium => l10n.hapticsMedium,
      CardHaptics.strong => l10n.hapticsStrong,
    };

String cardPositionName(AppLocalizations l10n, TrendCardPosition position) =>
    switch (position) {
      TrendCardPosition.locked => l10n.trendCardLocked,
      TrendCardPosition.scrolls => l10n.trendCardScrolls,
    };

/// "Monday" / "Sunday" in the app's language, from intl, starting with a
/// capital letter (es gives `lunes`).
String weekStartName(String locale, WeekStart start) {
  // 5 Oct 2026 is a Monday, 4 Oct a Sunday.
  final day = start == WeekStart.monday
      ? DateTime.utc(2026, 10, 5)
      : DateTime.utc(2026, 10, 4);
  return toBeginningOfSentenceCase(DateFormat.EEEE(locale).format(day), locale);
}
