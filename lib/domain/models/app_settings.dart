import 'dart:ui' show Locale;

import '../periods.dart';
import '../photo_sizing.dart';
import 'app_theme_mode.dart';
import 'dashboard_options.dart';
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
    this.weekStart = defaultWeekStart,
    this.weekLabel = defaultWeekLabel,
    this.cardPeriod = Period.month,
    this.listGrouping = Period.week,
    this.trendChartStyle = defaultTrendChartStyle,
    this.trendCardPosition = defaultTrendCardPosition,
    this.trendCardSize = defaultTrendCardSize,
    this.trendCardHaptics = defaultTrendCardHaptics,
    this.cameraPhotos = defaultPhotoSizing,
    this.galleryPhotos = defaultPhotoSizing,
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

  /// Settings → Home's defaults, what its Restore defaults goes back to
  /// (owner, 2026-10-06).
  static const defaultTrendChartStyle = TrendChartStyle.lineFilled;
  static const defaultTrendCardPosition = TrendCardPosition.locked;
  static const defaultTrendCardSize = TrendCardSize.medium;
  static const defaultTrendCardHaptics = CardHaptics.light;
  static const defaultWeekStart = WeekStart.monday;
  static const defaultWeekLabel = WeekLabel.month;

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

  /// The first day of a week in Home's groups and card (Monday unless changed,
  /// not from the locale).
  final WeekStart weekStart;

  /// How weeks are named: "Oct Week 3" (default) or "Week 41".
  final WeekLabel weekLabel;

  /// The trend card's period: week, month or year, set by swiping it. Never
  /// [Period.day].
  final Period cardPeriod;

  /// How Home's list is grouped: day, week, month or year.
  final Period listGrouping;

  final TrendChartStyle trendChartStyle;
  final TrendCardPosition trendCardPosition;
  final TrendCardSize trendCardSize;

  /// The tick of the card's reel at each face (owner, 2026-10-07).
  final CardHaptics trendCardHaptics;

  /// How photos taken with the camera are kept: larger than the size, resized
  /// to it at the quality; 1080p / 85 by default.
  final PhotoSizing cameraPhotos;

  /// The same for photos picked from the gallery (owner rev 7: also 1080p).
  final PhotoSizing galleryPhotos;

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
    WeekStart? weekStart,
    WeekLabel? weekLabel,
    Period? cardPeriod,
    Period? listGrouping,
    TrendChartStyle? trendChartStyle,
    TrendCardPosition? trendCardPosition,
    TrendCardSize? trendCardSize,
    CardHaptics? trendCardHaptics,
    PhotoSizing? cameraPhotos,
    PhotoSizing? galleryPhotos,
  }) => _copy(
    onboardingCompleted: onboardingCompleted,
    theme: theme,
    defaultCurrency: defaultCurrency,
    defaultPaymentMethodId: defaultPaymentMethodId,
    tileShape: tileShape,
    buttonShape: buttonShape,
    timePickerKeyboard: timePickerKeyboard,
    datePickerKeyboard: datePickerKeyboard,
    weekStart: weekStart,
    weekLabel: weekLabel,
    cardPeriod: cardPeriod,
    listGrouping: listGrouping,
    trendChartStyle: trendChartStyle,
    trendCardPosition: trendCardPosition,
    trendCardSize: trendCardSize,
    trendCardHaptics: trendCardHaptics,
    cameraPhotos: cameraPhotos,
    galleryPhotos: galleryPhotos,
  );

  /// A copy with the app language set to [locale] (null = follow the device).
  AppSettings withLocale(Locale? locale) => _copy(locale: () => locale);

  /// A copy with the default look: wallpaper colors, rounded tiles and circle
  /// buttons. Home's settings (chart, card, weeks) aren't part of the look and
  /// stay.
  AppSettings withDefaultLook() => withThemeSeed(null)
      .copyWith(tileShape: defaultTileShape, buttonShape: defaultButtonShape);

  /// A copy with Settings → Home's defaults: chart, card position and
  /// size, week start and week names. The card vibration has its own tile
  /// (owner, 2026-10-11) and stays. The card's period and the
  /// list's grouping are set on Home itself and stay.
  AppSettings withDefaultHome() => copyWith(
    trendChartStyle: defaultTrendChartStyle,
    trendCardPosition: defaultTrendCardPosition,
    trendCardSize: defaultTrendCardSize,
    weekStart: defaultWeekStart,
    weekLabel: defaultWeekLabel,
  );

  /// A copy with Settings → Photos' defaults. Not part of the default look or
  /// Home's defaults.
  AppSettings withDefaultPhotos() => copyWith(
    cameraPhotos: defaultPhotoSizing,
    galleryPhotos: defaultPhotoSizing,
  );

  /// A copy with the theme color set to [seed] (null = wallpaper colors).
  AppSettings withThemeSeed(int? seed) => _copy(themeSeed: () => seed);

  /// The one place that rebuilds the object field by field, so a new field
  /// can't be forgotten in one of the copies and silently reset to its default
  /// on a language or colour change. [locale] and [themeSeed] are functions
  /// because null is a value for them.
  AppSettings _copy({
    bool? onboardingCompleted,
    Locale? Function()? locale,
    AppThemeMode? theme,
    String? defaultCurrency,
    int? defaultPaymentMethodId,
    ItemShape? tileShape,
    ItemShape? buttonShape,
    bool? timePickerKeyboard,
    bool? datePickerKeyboard,
    int? Function()? themeSeed,
    WeekStart? weekStart,
    WeekLabel? weekLabel,
    Period? cardPeriod,
    Period? listGrouping,
    TrendChartStyle? trendChartStyle,
    TrendCardPosition? trendCardPosition,
    TrendCardSize? trendCardSize,
    CardHaptics? trendCardHaptics,
    PhotoSizing? cameraPhotos,
    PhotoSizing? galleryPhotos,
  }) => AppSettings(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    locale: locale == null ? this.locale : locale(),
    theme: theme ?? this.theme,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    defaultPaymentMethodId:
        defaultPaymentMethodId ?? this.defaultPaymentMethodId,
    tileShape: tileShape ?? this.tileShape,
    buttonShape: buttonShape ?? this.buttonShape,
    timePickerKeyboard: timePickerKeyboard ?? this.timePickerKeyboard,
    datePickerKeyboard: datePickerKeyboard ?? this.datePickerKeyboard,
    themeSeed: themeSeed == null ? this.themeSeed : themeSeed(),
    weekStart: weekStart ?? this.weekStart,
    weekLabel: weekLabel ?? this.weekLabel,
    cardPeriod: cardPeriod ?? this.cardPeriod,
    listGrouping: listGrouping ?? this.listGrouping,
    trendChartStyle: trendChartStyle ?? this.trendChartStyle,
    trendCardPosition: trendCardPosition ?? this.trendCardPosition,
    trendCardSize: trendCardSize ?? this.trendCardSize,
    trendCardHaptics: trendCardHaptics ?? this.trendCardHaptics,
    cameraPhotos: cameraPhotos ?? this.cameraPhotos,
    galleryPhotos: galleryPhotos ?? this.galleryPhotos,
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
      other.themeSeed == themeSeed &&
      other.weekStart == weekStart &&
      other.weekLabel == weekLabel &&
      other.cardPeriod == cardPeriod &&
      other.listGrouping == listGrouping &&
      other.trendChartStyle == trendChartStyle &&
      other.trendCardPosition == trendCardPosition &&
      other.trendCardSize == trendCardSize &&
      other.trendCardHaptics == trendCardHaptics &&
      other.cameraPhotos == cameraPhotos &&
      other.galleryPhotos == galleryPhotos;

  @override
  int get hashCode => Object.hashAll([
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
    weekStart,
    weekLabel,
    cardPeriod,
    listGrouping,
    trendChartStyle,
    trendCardPosition,
    trendCardSize,
    trendCardHaptics,
    cameraPhotos,
    galleryPhotos,
  ]);

  @override
  String toString() =>
      'AppSettings(onboardingCompleted: $onboardingCompleted, locale: $locale, theme: ${theme.name}, '
      'defaultCurrency: $defaultCurrency, defaultPaymentMethodId: $defaultPaymentMethodId, '
      'tileShape: ${tileShape.name}, buttonShape: ${buttonShape.name}, '
      'timePickerKeyboard: $timePickerKeyboard, datePickerKeyboard: $datePickerKeyboard, '
      'themeSeed: $themeSeed, weekStart: ${weekStart.name}, weekLabel: ${weekLabel.name}, '
      'cardPeriod: ${cardPeriod.name}, listGrouping: ${listGrouping.name}, '
      'trendChartStyle: ${trendChartStyle.name}, trendCardPosition: ${trendCardPosition.name}, '
      'trendCardSize: ${trendCardSize.name}, '
      'trendCardHaptics: ${trendCardHaptics.name}, '
      'cameraPhotos: ${cameraPhotos.size.name}/${cameraPhotos.quality}, '
      'galleryPhotos: ${galleryPhotos.size.name}/${galleryPhotos.quality})';
}
