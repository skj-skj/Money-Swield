import 'dart:ui' show Locale;

import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/app_theme_mode.dart';

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
