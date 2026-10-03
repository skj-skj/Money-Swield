import 'dart:math' as math;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/data_version.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../core/recent_currencies.dart';

/// What the Home list shows. States don't override `==`, so every emitted
/// state reaches the screen.
sealed class ExpenseListState {
  const ExpenseListState();
}

final class ExpenseListLoading extends ExpenseListState {
  const ExpenseListLoading();
}

final class ExpenseListLoaded extends ExpenseListState {
  const ExpenseListLoaded({
    required this.expenses,
    required this.categories,
    required this.paymentMethods,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  /// Newest first.
  final List<Expense> expenses;

  /// By id, for the emoji on each row.
  final Map<int, Category> categories;
  final Map<int, PaymentMethod> paymentMethods;

  /// Whether another page may follow.
  final bool hasMore;

  /// A page is being loaded; further [ExpenseListCubit.loadMore] calls
  /// return at once.
  final bool loadingMore;

  /// The last page failed: the list keeps its rows and shows a retry row.
  final bool loadMoreFailed;

  ExpenseListLoaded copyWith({
    List<Expense>? expenses,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => ExpenseListLoaded(
    expenses: expenses ?? this.expenses,
    categories: categories,
    paymentMethods: paymentMethods,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

final class ExpenseListFailed extends ExpenseListState {
  const ExpenseListFailed(this.error);

  final Object error;
}

/// The Home tab's expense list: keyset pages of [pageSize], newest first
/// (phase-2.md §7.2).
class ExpenseListCubit extends CubitSignal<ExpenseListState> {
  ExpenseListCubit({
    required this._expenses,
    required this._categories,
    required this._paymentMethods,
    required this._dataVersion,
    this.pageSize = 30,
  }) : super(initialState: const ExpenseListLoading());

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final PaymentMethodRepository _paymentMethods;
  final DataVersion _dataVersion;
  final int pageSize;

  /// `DataVersion.value` when the rows shown were loaded.
  int? _loadedVersion;

  /// Bumped by every (re)load, so a page that was requested before it
  /// can't be appended to the fresh rows (which would duplicate them).
  /// [loadMore] also checks that the rows it continues are still the ones
  /// shown, which covers a page requested while a reload was running.
  int _generation = 0;

  /// Loads the first page and the categories / payment methods.
  Future<void> load() => _loadTop(pageSize);

  /// Reloads from the top as many rows as are loaded (at least a page), in
  /// one query, so the loaded rows and the scroll position stay.
  Future<void> reload() {
    final loaded = switch (value) {
      ExpenseListLoaded(:final expenses) => expenses.length,
      _ => 0,
    };
    return _loadTop(math.max(pageSize, loaded));
  }

  /// Called when the Home tab becomes visible again. Reloads only if
  /// something was written since the last load (P2-14): Manage may have
  /// renamed a category, Settings → Bin may have restored an expense.
  Future<void> reloadIfChanged() async {
    if (_dataVersion.value != _loadedVersion) await reload();
  }

  /// Loads the next page after the last loaded row. One request at a time.
  Future<void> loadMore() async {
    final state = value;
    if (state is! ExpenseListLoaded || !state.hasMore || state.loadingMore) {
      return;
    }
    final generation = _generation;
    final rows = state.expenses;
    // Whether the page still continues the rows on screen. A reload that
    // finished meanwhile replaced them (and may have shifted them, e.g.
    // after a delete), so the page would duplicate or skip rows; it is
    // dropped, and the list asks again from the new last row.
    bool stillCurrent(ExpenseListLoaded current) =>
        generation == _generation && identical(current.expenses, rows);
    _emitIfOpen(state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      // The cursor comes from the last loaded row, never from a counter.
      final page = await _expenses.page(
        after: rows.lastOrNull?.cursor,
        limit: pageSize,
      );
      final current = value;
      if (current is! ExpenseListLoaded || !stillCurrent(current)) return;
      _emitIfOpen(
        current.copyWith(
          expenses: [...current.expenses, ...page],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Loading more expenses failed: $error\n$stackTrace');
      final current = value;
      if (current is! ExpenseListLoaded || !stillCurrent(current)) return;
      _emitIfOpen(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  /// Undo for "Moved to bin": takes [id] out of the bin and reloads. Does
  /// nothing if it is no longer there (the bin was emptied meanwhile).
  /// Rethrows a failed write; the screen tells the user.
  Future<void> restore(int id) async {
    await _expenses.restore(id);
    await reload();
  }

  /// The currencies of the latest entered expenses, for the currency
  /// sheet's Recent section. Empty if they can't be read: the sheet still
  /// works without them.
  Future<List<String>> recentCurrencies() => recentCurrenciesOrEmpty(_expenses);

  Future<void> _loadTop(int limit) async {
    final generation = ++_generation;
    final version = _dataVersion.value;
    try {
      final expenses = await _expenses.page(limit: limit);
      final categories = await _categories.all();
      final paymentMethods = await _paymentMethods.all();
      if (generation != _generation) return;
      _loadedVersion = version;
      _emitIfOpen(
        ExpenseListLoaded(
          expenses: expenses,
          categories: {for (final c in categories) c.id: c},
          paymentMethods: {for (final m in paymentMethods) m.id: m},
          hasMore: expenses.length == limit,
        ),
      );
    } catch (error) {
      if (generation != _generation) return;
      // A failed reload keeps the rows on screen; only a first load shows
      // the error view.
      if (value is! ExpenseListLoaded) _emitIfOpen(ExpenseListFailed(error));
      debugPrint('Loading expenses failed: $error');
    }
  }

  // Every method keeps going across awaits, and the screen closes the
  // cubit when it goes away. Emitting after close() asserts in debug mode.
  void _emitIfOpen(ExpenseListState state) {
    if (!isClosed) emit(state);
  }
}
