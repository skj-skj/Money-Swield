import 'package:sqflite/sqflite.dart';

import '../../domain/models/category.dart';
import '../../domain/models/event.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/report.dart';
import '../../domain/report_filter.dart';
import '../../domain/report_range.dart';
import 'category_repository.dart';
import 'event_repository.dart';
import 'expense_filter_sql.dart';
import 'payment_method_repository.dart';

/// What a report is built from: the rows, and the categories, events (archived
/// too) and payment methods they point at, read in one snapshot. Models, not
/// names: names are made in the UI layer, so a language switch needs no read.
final class ReportData {
  const ReportData({
    required this.rows,
    required this.categories,
    required this.events,
    required this.paymentMethods,
  });

  final List<ReportRow> rows;
  final Map<int, Category> categories;
  final Map<int, Event> events;
  final Map<int, PaymentMethod> paymentMethods;
}

/// Reads a report's rows. Writes nothing.
class ReportRepository {
  ReportRepository(this._db);

  final Database _db;

  /// The active expenses of [range] that pass [filter]'s SQL part (all of it
  /// but the text, which `buildReport` matches in Dart), in report order, with
  /// the three name maps, in **one transaction** so names and rows come from
  /// one moment. Everything inside goes through the transaction's executor: a
  /// call to the database itself there would wait for the transaction and never
  /// return. The transaction holds the write lock while it reads: a Save
  /// meanwhile waits, it doesn't fail.
  ///
  /// Descriptions only with [withDescriptions] (a text filter matches them;
  /// nothing else shows them): at 10,000 rows with 1,000-character descriptions
  /// the read took 1.2 s on the Oppo, holding the write lock meanwhile.
  Future<ReportData> read(
    ReportRange range,
    ReportFilter filter, {
    bool withDescriptions = false,
  }) => _db.transaction((txn) async {
    final rows = await txn.rawQuery(
      reportSql(range, filter, withDescriptions: withDescriptions),
      [
        if (!range.isAllTime) ...[range.from, range.to],
      ],
    );
    final categories = await CategoryRepository.allOn(txn);
    final events = await EventRepository.allOn(txn);
    final methods = await PaymentMethodRepository.allOn(txn);
    return ReportData(
      rows: [for (final row in rows) _fromRow(row)],
      categories: {for (final c in categories) c.id: c},
      events: {for (final e in events) e.id: e},
      paymentMethods: {for (final m in methods) m.id: m},
    );
  });

  /// The report's query. The date range searches the date index; All time scans it in
  /// index order. Payment methods are written `+payment_method_id`, so 3.22
  /// keeps the date index instead of the payment-method index and a temp
  /// B-tree. At most two bound variables; ids as literals.
  static String reportSql(
    ReportRange range,
    ReportFilter filter, {
    bool withDescriptions = true,
  }) {
    final where = [
      '+deleted_at IS NULL',
      if (!range.isAllTime) 'occurred_on BETWEEN ? AND ?',
      ...expenseFilterSql(filter.base.withoutText),
      if (filter.paymentMethodIds.isNotEmpty)
        '+payment_method_id IN (${sqlIdList(filter.paymentMethodIds)})',
    ];
    final description = withDescriptions
        ? 'description'
        : 'NULL AS description';
    return 'SELECT id, title, $description, amount_minor, currency_code, '
        'occurred_at, utc_offset_minutes, occurred_on, category_id, '
        'payment_method_id, recurring_expense_id, '
        '(SELECT group_concat(event_id) FROM expense_events '
        'WHERE expense_id = expenses.id) AS event_ids '
        'FROM expenses WHERE ${where.join(' AND ')} '
        'ORDER BY occurred_on, occurred_at, id';
  }

  static ReportRow _fromRow(Map<String, Object?> row) => ReportRow(
    id: row['id']! as int,
    title: row['title']! as String,
    description: row['description'] as String?,
    amountMinor: row['amount_minor']! as int,
    currencyCode: row['currency_code']! as String,
    occurredAtMs: row['occurred_at']! as int,
    utcOffsetMinutes: row['utc_offset_minutes']! as int,
    day: row['occurred_on']! as String,
    categoryId: row['category_id']! as int,
    paymentMethodId: row['payment_method_id']! as int,
    eventIds: parseIdSet(row['event_ids'] as String?),
    recurring: row['recurring_expense_id'] != null,
  );

  /// `group_concat`'s comma-separated ids as a set: its order is unspecified.
  /// NULL (no events) is empty.
  static Set<int> parseIdSet(String? joined) =>
      joined == null ? {} : {for (final id in joined.split(',')) int.parse(id)};
}
