import 'dart:math' as math;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/expense_draft_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/repositories/sms_suggestion_repository.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/sms_suggestion.dart';
import '../../../../domain/sms/sms_groups.dart';
import '../../../core/emit_if_open.dart';

/// What the SMS screen shows. States don't override `==`, so every emitted
/// state reaches the screen.
sealed class SmsListState {
  const SmsListState();
}

final class SmsListLoading extends SmsListState {
  const SmsListLoading();
}

final class SmsListFailed extends SmsListState {
  const SmsListFailed();
}

final class SmsListLoaded extends SmsListState {
  SmsListLoaded({
    required this.rows,
    required this.hasMore,
    this.methods = const {},
    this.loadingMore = false,
    this.loadMoreFailed = false,
  }) : months = smsGroups(rows, hasMore: hasMore);

  /// Pending suggestions, newest first.
  final List<SmsSuggestion> rows;

  /// [rows] as month frames and days.
  final List<SmsMonth> months;

  /// The payment methods by built-in key, so a card shows a renamed one's
  /// name and emoji; a key without its row shows the built-in name.
  final Map<String, PaymentMethod> methods;

  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  SmsListLoaded copyWith({
    List<SmsSuggestion>? rows,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => SmsListLoaded(
    rows: rows ?? this.rows,
    hasMore: hasMore ?? this.hasMore,
    methods: methods,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// The SMS screen's pending suggestions, 60 a page (keyset), the dismiss icon
/// with Undo, and the draft slot for opening the form.
class SmsListCubit extends CubitSignal<SmsListState>
    with EmitIfOpen<SmsListState> {
  SmsListCubit({
    required this._repository,
    required this._drafts,
    required this._paymentMethods,
    this.pageSize = 60,
  }) : super(initialState: const SmsListLoading());

  final SmsSuggestionRepository _repository;
  final ExpenseDraftRepository _drafts;
  final PaymentMethodRepository _paymentMethods;
  final int pageSize;

  /// Bumped by every (re)load, so a page requested before it is dropped.
  int _generation = 0;

  /// The last dismissed suggestion: Undo brings back this one only.
  int? _lastDismissed;

  Future<void> load() => _loadTop(pageSize);

  /// Reloads at least as many rows as are shown, so the place stays: after the
  /// form closes, and when a scan stored rows.
  Future<void> reload() {
    final shown = switch (value) {
      SmsListLoaded(:final rows) => rows.length,
      _ => 0,
    };
    return _loadTop(math.max(shown, pageSize));
  }

  Future<void> _loadTop(int limit) async {
    final generation = ++_generation;
    try {
      final rows = await _repository.pendingPage(limit: limit);
      final methods = {
        for (final m in await _paymentMethods.all()) ?m.builtinKey: m,
      };
      if (generation != _generation) return;
      emitIfOpen(
        SmsListLoaded(
          rows: rows,
          hasMore: rows.length == limit,
          methods: methods,
        ),
      );
    } catch (error) {
      debugPrint('Loading the SMS suggestions failed: $error');
      if (generation != _generation) return;
      if (value is! SmsListLoaded) emitIfOpen(const SmsListFailed());
    }
  }

  /// The next page; one at a time, never onto rows a reload replaced.
  Future<void> loadMore() async {
    final state = value;
    if (state is! SmsListLoaded ||
        !state.hasMore ||
        state.loadingMore ||
        state.rows.isEmpty) {
      return;
    }
    final generation = _generation;
    emitIfOpen(state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.pendingPage(
        after: state.rows.last.pageKey,
        limit: pageSize,
      );
      final current = value;
      if (generation != _generation || current is! SmsListLoaded) return;
      emitIfOpen(
        current.copyWith(
          rows: [...current.rows, ...page],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ),
      );
    } catch (error) {
      debugPrint('Loading more SMS suggestions failed: $error');
      final current = value;
      if (generation != _generation || current is! SmsListLoaded) return;
      emitIfOpen(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  /// The dismiss icon: the card leaves at once. Whether it was dismissed
  /// (false when it was added or gone meanwhile: the list reloads).
  Future<bool> dismiss(int id) async {
    final state = value;
    if (state is SmsListLoaded) {
      emitIfOpen(
        state.copyWith(
          rows: [
            for (final r in state.rows)
              if (r.id != id) r,
          ],
        ),
      );
    }
    try {
      final changed = await _repository.dismiss(id);
      if (changed) {
        _lastDismissed = id;
      } else {
        await reload();
      }
      return changed;
    } catch (error) {
      debugPrint('Dismissing the SMS suggestion failed: $error');
      await reload();
      return false;
    }
  }

  /// Undo of the last [dismiss] only (a second dismiss replaced the first
  /// one's snackbar): it comes back in its place.
  Future<void> undo(int id) async {
    if (_lastDismissed != id) return;
    _lastDismissed = null;
    try {
      await _repository.undismiss(id);
    } catch (error) {
      debugPrint('Bringing back the SMS suggestion failed: $error');
    }
    await reload();
  }

  /// The draft slot, for the opener.
  Future<ExpenseDraft?> pendingDraft() => _drafts.readOrNull();

  /// The dialog's Dismiss draft: the slot emptied for good. Its new photos go
  /// at the next start's sweep.
  Future<void> dismissDraft() => _drafts.clear();
}
