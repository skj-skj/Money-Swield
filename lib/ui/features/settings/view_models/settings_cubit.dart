import 'dart:ui' show Locale;

import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/app_theme_mode.dart';
import '../../../../domain/models/item_shape.dart';

/// The app's settings, for the whole app's lifetime: `MaterialApp` reads
/// the language and theme from it.
///
/// Every setter writes to the database first and emits only after the
/// write succeeded. If the write throws, the state is unchanged and the
/// error reaches the caller, which tells the user.
class SettingsCubit extends CubitSignal<AppSettings> {
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
    _emitIfOpen(settings);
  }

  /// Null follows the device language.
  Future<void> setLocale(Locale? locale) async {
    await _settings.setLocale(locale);
    _emitIfOpen(value.withLocale(locale));
  }

  Future<void> setTheme(AppThemeMode theme) async {
    await _settings.setTheme(theme);
    _emitIfOpen(value.copyWith(theme: theme));
  }

  Future<void> setDefaultCurrency(String code) async {
    await _settings.setDefaultCurrency(code);
    _emitIfOpen(value.copyWith(defaultCurrency: code));
  }

  Future<void> setDefaultPaymentMethodId(int id) async {
    await _settings.setDefaultPaymentMethodId(id);
    _emitIfOpen(value.copyWith(defaultPaymentMethodId: id));
  }

  Future<void> setTileShape(ItemShape shape) async {
    await _settings.setTileShape(shape);
    _emitIfOpen(value.copyWith(tileShape: shape));
  }

  Future<void> setButtonShape(ItemShape shape) async {
    await _settings.setButtonShape(shape);
    _emitIfOpen(value.copyWith(buttonShape: shape));
  }

  Future<void> setTimePickerKeyboard(bool keyboard) async {
    await _settings.setTimePickerKeyboard(keyboard);
    _emitIfOpen(value.copyWith(timePickerKeyboard: keyboard));
  }

  Future<void> setDatePickerKeyboard(bool keyboard) async {
    await _settings.setDatePickerKeyboard(keyboard);
    _emitIfOpen(value.copyWith(datePickerKeyboard: keyboard));
  }

  /// [seed] as ARGB, or null for the wallpaper colors.
  Future<void> setThemeSeed(int? seed) async {
    await _settings.setThemeSeed(seed);
    _emitIfOpen(value.withThemeSeed(seed));
  }

  /// Theme color, tile shape and button shape back to their defaults.
  Future<void> restoreDefaultLook() async {
    await _settings.restoreDefaultLook();
    _emitIfOpen(value.withDefaultLook());
  }

  Future<void> setOnboardingCompleted() async {
    await _settings.setOnboardingCompleted();
    _emitIfOpen(value.copyWith(onboardingCompleted: true));
  }

  // Each method keeps going across an await, so the cubit may have been
  // closed by the time the write finishes. Emitting after close() asserts.
  void _emitIfOpen(AppSettings settings) {
    if (!isClosed) emit(settings);
  }
}
