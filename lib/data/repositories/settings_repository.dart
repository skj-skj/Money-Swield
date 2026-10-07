import 'dart:ui' show Locale;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_theme_mode.dart';
import '../../domain/models/dashboard_options.dart';
import '../../domain/models/item_shape.dart';
import '../../domain/periods.dart';
import '../services/database/sql_helpers.dart';

/// Language codes the app is translated into. A stored language outside
/// this list (e.g. from a newer app after a downgrade) means "follow the
/// device".
const supportedLanguageCodes = ['en', 'es', 'hi'];

/// Reads and writes the `settings` table (database.md §3.1). Owns the list
/// of keys and their defaults: a missing row means "use the default".
class SettingsRepository {
  SettingsRepository(this._db, {required this._deviceCurrency});

  final Database _db;

  /// The default currency when none is stored, from the device's locale.
  /// Passed in so this class doesn't depend on platform code.
  final String _deviceCurrency;

  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _localeKey = 'locale';
  static const _themeKey = 'theme';
  static const _defaultCurrencyKey = 'default_currency';
  static const _defaultPaymentMethodIdKey = 'default_payment_method_id';
  static const _tileShapeKey = 'tile_shape';
  static const _buttonShapeKey = 'button_shape';
  static const _timePickerKeyboardKey = 'time_picker_keyboard';
  static const _datePickerKeyboardKey = 'date_picker_keyboard';
  static const _themeColorKey = 'theme_color';
  static const _lastBackupAtKey = 'last_backup_at';
  static const _weekStartKey = 'week_start';
  static const _weekLabelKey = 'week_label';
  static const _cardPeriodKey = 'dashboard_period';
  static const _listGroupingKey = 'list_grouping';
  static const _trendChartStyleKey = 'trend_chart_style';
  static const _trendCardPositionKey = 'trend_card_position';
  static const _trendCardSizeKey = 'trend_card_size';
  static const _trendCardHapticsKey = 'trend_card_haptics';

  /// The stored values of `trend_chart_style` (database.md §3.1).
  static const _chartStyleNames = {
    TrendChartStyle.lineFilled: 'line_filled',
    TrendChartStyle.line: 'line',
    TrendChartStyle.bar: 'bar',
    TrendChartStyle.dots: 'dots',
    TrendChartStyle.runningTotal: 'running_total',
  };

  /// The card shows a week, month or year, never a day.
  static const _cardPeriods = [Period.week, Period.month, Period.year];

  /// Stored in `theme_color` for "use the wallpaper colors".
  static const _dynamicThemeColor = 'dynamic';

  /// Reads every setting once and applies the defaults.
  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    final values = {
      for (final row in rows) row['key']! as String: row['value'] as String?,
    };
    return AppSettings(
      onboardingCompleted: _isTrue(values[_onboardingCompletedKey]),
      locale: _parseLocale(values[_localeKey]),
      theme: _enumOr(
        AppThemeMode.values,
        values[_themeKey],
        AppThemeMode.system,
      ),
      defaultCurrency:
          _nonEmpty(values[_defaultCurrencyKey]) ?? _deviceCurrency,
      defaultPaymentMethodId: await defaultPaymentMethodId(_db),
      // An unknown value (a newer app's shape after a downgrade) falls back
      // to the default, like the theme.
      tileShape: _enumOr(
        ItemShape.values,
        values[_tileShapeKey],
        AppSettings.defaultTileShape,
      ),
      buttonShape: _enumOr(
        ItemShape.values,
        values[_buttonShapeKey],
        AppSettings.defaultButtonShape,
      ),
      timePickerKeyboard: _isTrue(values[_timePickerKeyboardKey]),
      datePickerKeyboard: _isTrue(values[_datePickerKeyboardKey]),
      // Missing, 'dynamic' or unreadable all mean the wallpaper colors.
      themeSeed: int.tryParse(values[_themeColorKey] ?? ''),
      // Home (phase-5.md §4.2). Missing or unknown → the default.
      weekStart: _enumOr(
        WeekStart.values,
        values[_weekStartKey],
        AppSettings.defaultWeekStart,
      ),
      weekLabel: _enumOr(
        WeekLabel.values,
        values[_weekLabelKey],
        AppSettings.defaultWeekLabel,
      ),
      cardPeriod: _enumOr(_cardPeriods, values[_cardPeriodKey], Period.month),
      listGrouping: _enumOr(
        Period.values,
        values[_listGroupingKey],
        Period.week,
      ),
      trendChartStyle:
          _chartStyleNames.entries
              .where((e) => e.value == values[_trendChartStyleKey])
              .map((e) => e.key)
              .firstOrNull ??
          AppSettings.defaultTrendChartStyle,
      trendCardPosition: _enumOr(
        TrendCardPosition.values,
        values[_trendCardPositionKey],
        AppSettings.defaultTrendCardPosition,
      ),
      trendCardSize: _enumOr(
        TrendCardSize.values,
        values[_trendCardSizeKey],
        AppSettings.defaultTrendCardSize,
      ),
      trendCardHaptics: _enumOr(
        CardHaptics.values,
        values[_trendCardHapticsKey],
        AppSettings.defaultTrendCardHaptics,
      ),
    );
  }

  /// The default payment method's id: the stored one if that row still
  /// exists, else the `cash` row, else the first payment method by id. Null
  /// only when there are no payment methods.
  ///
  /// Takes the executor so `PaymentMethodRepository.delete` can check it in
  /// the same transaction as the delete.
  Future<int?> defaultPaymentMethodId(DatabaseExecutor db) async {
    final stored = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_defaultPaymentMethodIdKey],
    );
    final storedId = int.tryParse(
      stored.firstOrNull?['value'] as String? ?? '',
    );
    if (storedId != null) {
      final row = await db.query(
        'payment_methods',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [storedId],
      );
      if (row.isNotEmpty) return storedId;
    }
    final cash = await db.query(
      'payment_methods',
      columns: ['id'],
      where: 'builtin_key = ?',
      whereArgs: ['cash'],
    );
    if (cash.isNotEmpty) return cash.first['id']! as int;
    final first = await db.query(
      'payment_methods',
      columns: ['id'],
      orderBy: 'id',
      limit: 1,
    );
    return first.firstOrNull?['id'] as int?;
  }

  Future<void> setOnboardingCompleted() =>
      _write(_onboardingCompletedKey, _bool(true));

  /// Null means "follow the device".
  Future<void> setLocale(Locale? locale) =>
      _write(_localeKey, locale?.languageCode);

  Future<void> setTheme(AppThemeMode theme) => _write(_themeKey, theme.name);

  Future<void> setDefaultCurrency(String code) =>
      _write(_defaultCurrencyKey, code);

  Future<void> setDefaultPaymentMethodId(int id) =>
      _write(_defaultPaymentMethodIdKey, '$id');

  Future<void> setTileShape(ItemShape shape) =>
      _write(_tileShapeKey, shape.name);

  Future<void> setButtonShape(ItemShape shape) =>
      _write(_buttonShapeKey, shape.name);

  Future<void> setTimePickerKeyboard(bool keyboard) =>
      _write(_timePickerKeyboardKey, _bool(keyboard));

  Future<void> setDatePickerKeyboard(bool keyboard) =>
      _write(_datePickerKeyboardKey, _bool(keyboard));

  Future<void> setWeekStart(WeekStart start) =>
      _write(_weekStartKey, start.name);

  Future<void> setWeekLabel(WeekLabel label) =>
      _write(_weekLabelKey, label.name);

  /// The trend card's period; never [Period.day].
  Future<void> setCardPeriod(Period period) {
    assert(period != Period.day, 'the card has no Day face');
    return _write(_cardPeriodKey, period.name);
  }

  Future<void> setListGrouping(Period grouping) =>
      _write(_listGroupingKey, grouping.name);

  Future<void> setTrendChartStyle(TrendChartStyle style) =>
      _write(_trendChartStyleKey, _chartStyleNames[style]);

  Future<void> setTrendCardPosition(TrendCardPosition position) =>
      _write(_trendCardPositionKey, position.name);

  Future<void> setTrendCardSize(TrendCardSize size) =>
      _write(_trendCardSizeKey, size.name);

  Future<void> setTrendCardHaptics(CardHaptics haptics) =>
      _write(_trendCardHapticsKey, haptics.name);

  /// Settings → Home's Restore defaults, in one transaction: chart style,
  /// card position, size and vibration, week start and week names. Removing the rows
  /// is enough, as for [restoreDefaultLook]. The card's period and the
  /// list's grouping stay.
  Future<void> restoreHomeDefaults() => _db.transaction((txn) async {
    for (final key in [
      _trendChartStyleKey,
      _trendCardPositionKey,
      _trendCardSizeKey,
      _trendCardHapticsKey,
      _weekStartKey,
      _weekLabelKey,
    ]) {
      await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
    }
  });

  /// Back to the default theme color and tile and button shapes, in one
  /// transaction. Removing the rows is enough: a missing row means "use the
  /// default", so the defaults live in one place only ([load]).
  Future<void> restoreDefaultLook() => _db.transaction((txn) async {
    for (final key in [_themeColorKey, _tileShapeKey, _buttonShapeKey]) {
      await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
    }
  });

  /// [seed] as ARGB, or null for the wallpaper colors.
  Future<void> setThemeSeed(int? seed) =>
      _write(_themeColorKey, seed?.toString() ?? _dynamicThemeColor);

  /// When the last backup was saved, or null if never. Not part of
  /// [AppSettings], so a backup doesn't rebuild `MaterialApp` (phase-3.md
  /// §3). An unreadable value reads as "never".
  Future<DateTime?> lastBackupAt() async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_lastBackupAtKey],
    );
    final ms = int.tryParse(rows.firstOrNull?['value'] as String? ?? '');
    return ms == null ? null : utcFromEpochMs(ms);
  }

  /// Stored as epoch ms UTC, like every time in the database.
  Future<void> setLastBackupAt(DateTime at) =>
      _write(_lastBackupAtKey, '${at.millisecondsSinceEpoch}');

  Future<void> _write(String key, String? value) => _db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// The [values] entry named [stored]; [fallback] when it is missing or
  /// unknown (a newer app's value after a downgrade, or a typo).
  static T _enumOr<T extends Enum>(
    List<T> values,
    String? stored,
    T fallback,
  ) => values.asNameMap()[stored] ?? fallback;

  /// Booleans are stored as `'1'` / `'0'`; anything else reads as false.
  static String _bool(bool value) => value ? '1' : '0';

  static bool _isTrue(String? stored) => stored == '1';

  static Locale? _parseLocale(String? languageCode) =>
      supportedLanguageCodes.contains(languageCode)
      ? Locale(languageCode!)
      : null;

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
