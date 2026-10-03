import 'dart:ui' show Locale;

import 'app_theme_mode.dart';
import 'item_shape.dart';

/// An immutable snapshot of every setting the app uses, with defaults
/// already applied. Loaded by `SettingsRepository.load`.
class AppSettings {
  const AppSettings({
    required this.onboardingCompleted,
    required this.locale,
    required this.theme,
    required this.defaultCurrency,
    required this.defaultPaymentMethodId,
    this.tileShape = defaultTileShape,
    this.buttonShape = defaultButtonShape,
    this.timePickerKeyboard = false,
    this.datePickerKeyboard = false,
    this.themeSeed,
  });

  /// What the app uses before the settings are read from the database: the
  /// device language and theme, so the migration screen already shows in the
  /// user's language. The other values are placeholders that nothing reads
  /// before `load` replaces them.
  static const beforeLoad = AppSettings(
    onboardingCompleted: false,
    locale: null,
    theme: AppThemeMode.system,
    defaultCurrency: 'USD',
    defaultPaymentMethodId: null,
  );

  /// The look a fresh install has, and what Settings → Restore default
  /// look goes back to (with the wallpaper colors for the theme).
  static const defaultTileShape = ItemShape.rounded;
  static const defaultButtonShape = ItemShape.circle;

  final bool onboardingCompleted;

  /// The app language, or null to follow the device.
  final Locale? locale;

  final AppThemeMode theme;

  /// ISO 4217 code for new expenses, e.g. `INR`.
  final String defaultCurrency;

  /// Null only when there are no payment methods at all.
  final int? defaultPaymentMethodId;

  /// Shape of the category and event tiles in the pickers.
  final ItemShape tileShape;

  /// Shape of the pickers' Search / New / ⋯ buttons and search bar.
  final ItemShape buttonShape;

  /// Whether the time picker opens in keyboard mode: the mode the user
  /// last switched it to is remembered.
  final bool timePickerKeyboard;

  /// Same for the date picker (calendar or keyboard input).
  final bool datePickerKeyboard;

  /// The color the app's theme is built from, as ARGB, or null to use the
  /// wallpaper colors (Android 12+), falling back to `defaultSeedColor`.
  final int? themeSeed;

  /// A copy with the given values replaced. [locale] and [themeSeed] are
  /// set separately with [withLocale] and [withThemeSeed], because null is a
  /// meaningful value for them ("follow the device", "wallpaper colors")
  /// and couldn't be told apart from "keep the current one" here.
  AppSettings copyWith({
    bool? onboardingCompleted,
    AppThemeMode? theme,
    String? defaultCurrency,
    int? defaultPaymentMethodId,
    ItemShape? tileShape,
    ItemShape? buttonShape,
    bool? timePickerKeyboard,
    bool? datePickerKeyboard,
  }) => AppSettings(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    locale: locale,
    theme: theme ?? this.theme,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    defaultPaymentMethodId:
        defaultPaymentMethodId ?? this.defaultPaymentMethodId,
    tileShape: tileShape ?? this.tileShape,
    buttonShape: buttonShape ?? this.buttonShape,
    timePickerKeyboard: timePickerKeyboard ?? this.timePickerKeyboard,
    datePickerKeyboard: datePickerKeyboard ?? this.datePickerKeyboard,
    themeSeed: themeSeed,
  );

  /// A copy with the app language set to [locale] (null = follow the device).
  AppSettings withLocale(Locale? locale) => AppSettings(
    onboardingCompleted: onboardingCompleted,
    locale: locale,
    theme: theme,
    defaultCurrency: defaultCurrency,
    defaultPaymentMethodId: defaultPaymentMethodId,
    tileShape: tileShape,
    buttonShape: buttonShape,
    timePickerKeyboard: timePickerKeyboard,
    datePickerKeyboard: datePickerKeyboard,
    themeSeed: themeSeed,
  );

  /// A copy with the default look: wallpaper colors, rounded tiles and
  /// circle buttons.
  AppSettings withDefaultLook() => withThemeSeed(null)
      .copyWith(tileShape: defaultTileShape, buttonShape: defaultButtonShape);

  /// A copy with the theme color set to [seed] (null = wallpaper colors).
  AppSettings withThemeSeed(int? seed) => AppSettings(
    onboardingCompleted: onboardingCompleted,
    locale: locale,
    theme: theme,
    defaultCurrency: defaultCurrency,
    defaultPaymentMethodId: defaultPaymentMethodId,
    tileShape: tileShape,
    buttonShape: buttonShape,
    timePickerKeyboard: timePickerKeyboard,
    datePickerKeyboard: datePickerKeyboard,
    themeSeed: seed,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.locale == locale &&
      other.theme == theme &&
      other.defaultCurrency == defaultCurrency &&
      other.defaultPaymentMethodId == defaultPaymentMethodId &&
      other.tileShape == tileShape &&
      other.buttonShape == buttonShape &&
      other.timePickerKeyboard == timePickerKeyboard &&
      other.datePickerKeyboard == datePickerKeyboard &&
      other.themeSeed == themeSeed;

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    locale,
    theme,
    defaultCurrency,
    defaultPaymentMethodId,
    tileShape,
    buttonShape,
    timePickerKeyboard,
    datePickerKeyboard,
    themeSeed,
  );

  @override
  String toString() =>
      'AppSettings(onboardingCompleted: $onboardingCompleted, locale: $locale, theme: ${theme.name}, '
      'defaultCurrency: $defaultCurrency, defaultPaymentMethodId: $defaultPaymentMethodId, '
      'tileShape: ${tileShape.name}, buttonShape: ${buttonShape.name}, themeSeed: $themeSeed)';
}
