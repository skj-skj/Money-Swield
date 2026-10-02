import 'dart:ui' show Locale;

import 'app_theme_mode.dart';

/// An immutable snapshot of every setting the app uses, with defaults
/// already applied. Loaded by `SettingsRepository.load`.
class AppSettings {
  const AppSettings({
    required this.onboardingCompleted,
    required this.locale,
    required this.theme,
    required this.defaultCurrency,
    required this.defaultPaymentMethodId,
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

  final bool onboardingCompleted;

  /// The app language, or null to follow the device.
  final Locale? locale;

  final AppThemeMode theme;

  /// ISO 4217 code for new expenses, e.g. `INR`.
  final String defaultCurrency;

  /// Null only when there are no payment methods at all.
  final int? defaultPaymentMethodId;

  /// A copy with the given values replaced. [locale] is set separately with
  /// [withLocale], because null is a meaningful value for it ("follow the
  /// device") and couldn't be told apart from "keep the current one" here.
  AppSettings copyWith({
    bool? onboardingCompleted,
    AppThemeMode? theme,
    String? defaultCurrency,
    int? defaultPaymentMethodId,
  }) => AppSettings(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    locale: locale,
    theme: theme ?? this.theme,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    defaultPaymentMethodId:
        defaultPaymentMethodId ?? this.defaultPaymentMethodId,
  );

  /// A copy with the app language set to [locale] (null = follow the device).
  AppSettings withLocale(Locale? locale) => AppSettings(
    onboardingCompleted: onboardingCompleted,
    locale: locale,
    theme: theme,
    defaultCurrency: defaultCurrency,
    defaultPaymentMethodId: defaultPaymentMethodId,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.locale == locale &&
      other.theme == theme &&
      other.defaultCurrency == defaultCurrency &&
      other.defaultPaymentMethodId == defaultPaymentMethodId;

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    locale,
    theme,
    defaultCurrency,
    defaultPaymentMethodId,
  );

  @override
  String toString() =>
      'AppSettings(onboardingCompleted: $onboardingCompleted, locale: $locale, theme: ${theme.name}, '
      'defaultCurrency: $defaultCurrency, defaultPaymentMethodId: $defaultPaymentMethodId)';
}
