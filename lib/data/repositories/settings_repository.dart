import 'dart:ui' show Locale;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_theme_mode.dart';
import '../../domain/models/dashboard_options.dart';
import '../../domain/models/item_shape.dart';
import '../../domain/models/report_prefs.dart';
import '../../domain/periods.dart';
import '../../domain/photo_sizing.dart';
import '../../domain/report.dart';
import '../../domain/report_document.dart';
import '../../domain/report_filter.dart';
import '../../domain/report_range.dart';
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
  static const _cameraSizeKey = 'photo_camera_size';
  static const _cameraQualityKey = 'photo_camera_quality';
  static const _gallerySizeKey = 'photo_gallery_size';
  static const _galleryQualityKey = 'photo_gallery_quality';
  static const _reportChartKey = 'report_chart';
  static const _reportPeriodKey = 'report_period';
  static const _reportRangeKey = 'report_range';
  static const _reportExportGroupByKey = 'report_export_group_by';
  static const _reportExportChartKey = 'report_export_chart';
  static const _reportExportOthersKey = 'report_export_others';
  static const _reportExportFormatKey = 'report_export_format';
  static const _reportFilterKey = 'report_filter';

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
      cameraPhotos: _photoSizing(
        values[_cameraSizeKey],
        values[_cameraQualityKey],
      ),
      galleryPhotos: _photoSizing(
        values[_gallerySizeKey],
        values[_galleryQualityKey],
      ),
    );
  }

  /// What the Reports screen opens on (phase-8.md §4). Each value falls
  /// back to its default on its own when missing or unreadable; a filter
  /// that can't be read is no filter (logged by the caller, which sees
  /// [ReportPrefs.filter] empty while the row isn't).
  Future<({ReportPrefs prefs, bool filterUnreadable})> loadReport() async {
    final rows = await _db.query(
      'settings',
      where: 'key IN (?, ?, ?, ?, ?, ?, ?, ?)',
      whereArgs: [
        _reportChartKey,
        _reportPeriodKey,
        _reportRangeKey,
        _reportFilterKey,
        _reportExportGroupByKey,
        _reportExportChartKey,
        _reportExportOthersKey,
        _reportExportFormatKey,
      ],
    );
    final values = {
      for (final row in rows) row['key']! as String: row['value'] as String?,
    };
    final storedFilter = values[_reportFilterKey];
    final filter = ReportFilter.fromJson(storedFilter);
    return (
      prefs: ReportPrefs(
        chart: _enumOr(
          ReportChart.values,
          values[_reportChartKey],
          ReportChart.bars,
        ),
        period: _enumOr(
          ReportPeriod.values,
          values[_reportPeriodKey],
          ReportPeriod.month,
        ),
        range: decodeCustomRange(values[_reportRangeKey]),
        filter: filter ?? ReportFilter.none,
        export: ReportExportOptions(
          groupBy: _enumOr(
            ReportExportOptions.sectionDimensions,
            values[_reportExportGroupByKey],
            GroupDimension.category,
          ),
          chart: _enumOr(
            ExportChart.values,
            values[_reportExportChartKey],
            ExportChart.bars,
          ),
          // Missing or unknown: on (the default).
          groupOthers: values[_reportExportOthersKey] != '0',
          format: _enumOr(
            ReportExport.values,
            values[_reportExportFormatKey],
            ReportExport.pdf,
          ),
        ),
      ),
      filterUnreadable: storedFilter != null && filter == null,
    );
  }

  /// A photo size and quality as stored (§4.2): each falls back to its
  /// default on its own when missing or unknown, so a quality the app no
  /// longer offers doesn't reset the size.
  static PhotoSizing _photoSizing(String? size, String? quality) => (
    size: _enumOr(PhotoSize.values, size, defaultPhotoSizing.size),
    quality: switch (int.tryParse(quality ?? '')) {
      final int q when photoQualities.contains(q) => q,
      _ => defaultPhotoSizing.quality,
    },
  );

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

  /// The report card's face, set by swiping it.
  Future<void> setReportChart(ReportChart chart) =>
      _write(_reportChartKey, chart.name);

  Future<void> setReportPeriod(ReportPeriod period) =>
      _write(_reportPeriodKey, period.name);

  /// Range chosen in the dialog: the period and the range in one
  /// transaction, so the next start can't open on Range with an old range
  /// or the other way round.
  Future<void> setReportCustomRange(ReportRange range) => _writeAll({
    _reportPeriodKey: ReportPeriod.range.name,
    _reportRangeKey: encodeCustomRange(range),
  });

  /// The report's filter (null JSON deletes the row: no filter).
  Future<void> setReportFilter(ReportFilter filter) =>
      _writeAll({_reportFilterKey: filter.toJson()});

  /// The Generate sheet's options, in one transaction.
  Future<void> setReportExportOptions(ReportExportOptions options) =>
      _writeAll({
        _reportExportGroupByKey: options.groupBy.name,
        _reportExportChartKey: options.chart.name,
        _reportExportOthersKey: _bool(options.groupOthers),
        _reportExportFormatKey: options.format.name,
      });

  /// Writes every key of [values] in one transaction (null deletes a
  /// key's row: it then reads as its default).
  Future<void> _writeAll(Map<String, String?> values) =>
      _db.transaction((txn) async {
        for (final MapEntry(:key, :value) in values.entries) {
          if (value == null) {
            await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
          } else {
            await txn.insert('settings', {
              'key': key,
              'value': value,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });

  /// How camera photos are kept, both values in one transaction.
  Future<void> setCameraPhotos(PhotoSizing sizing) =>
      _writeSizing(_cameraSizeKey, _cameraQualityKey, sizing);

  /// How gallery photos are kept, both values in one transaction.
  Future<void> setGalleryPhotos(PhotoSizing sizing) =>
      _writeSizing(_gallerySizeKey, _galleryQualityKey, sizing);

  Future<void> _writeSizing(
    String sizeKey,
    String qualityKey,
    PhotoSizing sizing,
  ) => _db.transaction((txn) async {
    for (final (key, value) in [
      (sizeKey, sizing.size.name),
      (qualityKey, '${sizing.quality}'),
    ]) {
      await txn.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });

  /// Settings → Photos' Restore defaults: the four rows removed in one
  /// transaction, as for [restoreDefaultLook].
  Future<void> restorePhotoDefaults() => _deleteKeys([
    _cameraSizeKey,
    _cameraQualityKey,
    _gallerySizeKey,
    _galleryQualityKey,
  ]);

  /// Settings → Home's Restore defaults, in one transaction: chart style,
  /// card position and size, week start and week names (the card vibration
  /// has its own tile since owner 2026-10-11). Removing the rows
  /// is enough, as for [restoreDefaultLook]. The card's period and the
  /// list's grouping stay.
  Future<void> restoreHomeDefaults() => _deleteKeys([
    _trendChartStyleKey,
    _trendCardPositionKey,
    _trendCardSizeKey,
    _weekStartKey,
    _weekLabelKey,
  ]);

  /// Back to the default theme color and tile and button shapes, in one
  /// transaction. Removing the rows is enough: a missing row means "use the
  /// default", so the defaults live in one place only ([load]).
  Future<void> restoreDefaultLook() =>
      _deleteKeys([_themeColorKey, _tileShapeKey, _buttonShapeKey]);

  /// Removes the [keys]' rows in one transaction: each then reads as its
  /// default ([load]). Every Restore defaults goes through here.
  Future<void> _deleteKeys(List<String> keys) => _db.transaction((txn) async {
    for (final key in keys) {
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
    final ms = int.tryParse(await valueOf(_db, _lastBackupAtKey) ?? '');
    return ms == null ? null : utcFromEpochMs(ms);
  }

  /// Stored as epoch ms UTC, like every time in the database.
  Future<void> setLastBackupAt(DateTime at) =>
      _write(_lastBackupAtKey, '${at.millisecondsSinceEpoch}');

  /// Whether the user turned SMS suggestions on (phase-9a.md §4; `1` only
  /// after the permission was granted once). Not part of [AppSettings]: only
  /// `SmsCubit` reads it, and turning it on or off rebuilds nothing else.
  Future<bool> smsEnabled() async => _isTrue(await valueOf(_db, smsEnabledKey));

  Future<void> setSmsEnabled(bool enabled) =>
      _write(smsEnabledKey, _bool(enabled));

  /// `sms_enabled` (database.md §3.1).
  static const smsEnabledKey = 'sms_enabled';

  /// Whether the on-device model may read the SMS (phase-9b.md §4): on by
  /// default, so missing means on; only an explicit `0` turns it off.
  /// Matters only on play with a model on the phone. Not part of
  /// [AppSettings], like [smsEnabled].
  Future<bool> smsAiParsing() async =>
      await valueOf(_db, smsAiParsingKey) != '0';

  Future<void> setSmsAiParsing(bool on) => _write(smsAiParsingKey, _bool(on));

  /// `sms_ai_parsing` (database.md §3.1).
  static const smsAiParsingKey = 'sms_ai_parsing';

  /// `sms_last_scanned_at`: the SMS scan's cursor, epoch ms (phase-9a.md
  /// §6.3 step 7). Written and read only by `SmsSuggestionRepository`,
  /// inside the scan's transaction, so it is public here only as the name.
  static const smsCursorKey = 'sms_last_scanned_at';

  /// One setting's stored value through [db], or null when it isn't
  /// there. Public for the keys another repository owns (the SMS scan's
  /// cursor).
  static Future<String?> valueOf(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.firstOrNull?['value'] as String?;
  }

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
