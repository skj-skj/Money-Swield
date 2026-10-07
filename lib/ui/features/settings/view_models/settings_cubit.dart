import 'dart:ui' show Locale;

import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/app_theme_mode.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/models/item_shape.dart';
import '../../../../domain/periods.dart';
import '../../../core/emit_if_open.dart';

/// The app's settings, for the whole app's lifetime: `MaterialApp` reads
/// the language and theme from it.
///
/// Every setter writes to the database first and emits only after the
/// write succeeded. If the write throws, the state is unchanged and the
/// error reaches the caller, which tells the user.
class SettingsCubit extends CubitSignal<AppSettings>
    with EmitIfOpen<AppSettings> {
  SettingsCubit({required AppSettings initial}) : super(initialState: initial);

  /// Set by [load]. The cubit exists before the database is open (it gives
  /// the migration screen its language), so the repository comes later.
  SettingsRepository? _repository;

  SettingsRepository get _settings =>
      _repository ??
      (throw StateError(
        'SettingsCubit.load() must finish before settings are changed',
      ));

  /// Reads all settings once. Called by the startup gate after the database
  /// is open.
  Future<void> load(SettingsRepository repository) async {
    final settings = await repository.load();
    _repository = repository;
    emitIfOpen(settings);
  }

  /// Null follows the device language.
  Future<void> setLocale(Locale? locale) async {
    await _settings.setLocale(locale);
    emitIfOpen(value.withLocale(locale));
  }

  Future<void> setTheme(AppThemeMode theme) async {
    await _settings.setTheme(theme);
    emitIfOpen(value.copyWith(theme: theme));
  }

  Future<void> setDefaultCurrency(String code) async {
    await _settings.setDefaultCurrency(code);
    emitIfOpen(value.copyWith(defaultCurrency: code));
  }

  Future<void> setDefaultPaymentMethodId(int id) async {
    await _settings.setDefaultPaymentMethodId(id);
    emitIfOpen(value.copyWith(defaultPaymentMethodId: id));
  }

  Future<void> setTileShape(ItemShape shape) async {
    await _settings.setTileShape(shape);
    emitIfOpen(value.copyWith(tileShape: shape));
  }

  Future<void> setButtonShape(ItemShape shape) async {
    await _settings.setButtonShape(shape);
    emitIfOpen(value.copyWith(buttonShape: shape));
  }

  Future<void> setTimePickerKeyboard(bool keyboard) async {
    await _settings.setTimePickerKeyboard(keyboard);
    emitIfOpen(value.copyWith(timePickerKeyboard: keyboard));
  }

  Future<void> setDatePickerKeyboard(bool keyboard) async {
    await _settings.setDatePickerKeyboard(keyboard);
    emitIfOpen(value.copyWith(datePickerKeyboard: keyboard));
  }

  Future<void> setWeekStart(WeekStart start) async {
    await _settings.setWeekStart(start);
    emitIfOpen(value.copyWith(weekStart: start));
  }

  Future<void> setWeekLabel(WeekLabel label) async {
    await _settings.setWeekLabel(label);
    emitIfOpen(value.copyWith(weekLabel: label));
  }

  /// The trend card's period, set by swiping the card.
  Future<void> setCardPeriod(Period period) async {
    await _settings.setCardPeriod(period);
    emitIfOpen(value.copyWith(cardPeriod: period));
  }

  Future<void> setListGrouping(Period grouping) async {
    await _settings.setListGrouping(grouping);
    emitIfOpen(value.copyWith(listGrouping: grouping));
  }

  Future<void> setTrendChartStyle(TrendChartStyle style) async {
    await _settings.setTrendChartStyle(style);
    emitIfOpen(value.copyWith(trendChartStyle: style));
  }

  Future<void> setTrendCardPosition(TrendCardPosition position) async {
    await _settings.setTrendCardPosition(position);
    emitIfOpen(value.copyWith(trendCardPosition: position));
  }

  Future<void> setTrendCardSize(TrendCardSize size) async {
    await _settings.setTrendCardSize(size);
    emitIfOpen(value.copyWith(trendCardSize: size));
  }

  Future<void> setTrendCardHaptics(CardHaptics haptics) async {
    await _settings.setTrendCardHaptics(haptics);
    emitIfOpen(value.copyWith(trendCardHaptics: haptics));
  }

  /// [seed] as ARGB, or null for the wallpaper colors.
  Future<void> setThemeSeed(int? seed) async {
    await _settings.setThemeSeed(seed);
    emitIfOpen(value.withThemeSeed(seed));
  }

  /// Theme color, tile shape and button shape back to their defaults.
  Future<void> restoreDefaultLook() async {
    await _settings.restoreDefaultLook();
    emitIfOpen(value.withDefaultLook());
  }

  /// Settings → Home back to its defaults.
  Future<void> restoreHomeDefaults() async {
    await _settings.restoreHomeDefaults();
    emitIfOpen(value.withDefaultHome());
  }

  Future<void> setOnboardingCompleted() async {
    await _settings.setOnboardingCompleted();
    emitIfOpen(value.copyWith(onboardingCompleted: true));
  }
}
