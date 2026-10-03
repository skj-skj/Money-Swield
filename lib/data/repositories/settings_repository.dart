import 'dart:ui' show Locale;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_theme_mode.dart';
import '../../domain/models/item_shape.dart';

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

  /// Stored in `theme_color` for "use the wallpaper colors".
  static const _dynamicThemeColor = 'dynamic';

  /// Reads every setting once and applies the defaults.
  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    final values = {
      for (final row in rows) row['key']! as String: row['value'] as String?,
    };
    return AppSettings(
      onboardingCompleted: values[_onboardingCompletedKey] == '1',
      locale: _parseLocale(values[_localeKey]),
      theme:
          AppThemeMode.values.asNameMap()[values[_themeKey]] ??
          AppThemeMode.system,
      defaultCurrency:
          _nonEmpty(values[_defaultCurrencyKey]) ?? _deviceCurrency,
      defaultPaymentMethodId: await defaultPaymentMethodId(_db),
      // An unknown value (a newer app's shape after a downgrade) falls back
      // to the default, like the theme.
      tileShape:
          ItemShape.values.asNameMap()[values[_tileShapeKey]] ??
          AppSettings.defaultTileShape,
      buttonShape:
          ItemShape.values.asNameMap()[values[_buttonShapeKey]] ??
          AppSettings.defaultButtonShape,
      timePickerKeyboard: values[_timePickerKeyboardKey] == '1',
      datePickerKeyboard: values[_datePickerKeyboardKey] == '1',
      // Missing, 'dynamic' or unreadable all mean the wallpaper colors.
      themeSeed: int.tryParse(values[_themeColorKey] ?? ''),
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

  Future<void> setOnboardingCompleted() => _write(_onboardingCompletedKey, '1');

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
      _write(_timePickerKeyboardKey, keyboard ? '1' : '0');

  Future<void> setDatePickerKeyboard(bool keyboard) =>
      _write(_datePickerKeyboardKey, keyboard ? '1' : '0');

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
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Stored as epoch ms UTC, like every time in the database.
  Future<void> setLastBackupAt(DateTime at) =>
      _write(_lastBackupAtKey, '${at.millisecondsSinceEpoch}');

  Future<void> _write(String key, String? value) => _db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  static Locale? _parseLocale(String? languageCode) =>
      supportedLanguageCodes.contains(languageCode)
      ? Locale(languageCode!)
      : null;

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
