import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/services/photo_store.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/photos.dart';
import '../../../../domain/selection.dart';
import '../../../core/emit_if_open.dart';

/// A binned expense's photos, read-only: shown in the Bin detail, selectable,
/// and saved to Pictures before the expense is purged (30 days). Nothing here
/// edits the expense.
class ExpensePhotosState {
  const ExpensePhotosState({
    this.photos = const [],
    this.loaded = false,
    this.selection,
    this.saving = false,
  });

  final List<SavedPhoto> photos;
  final bool loaded;

  /// Selected indexes; null when not selecting.
  final Set<int>? selection;

  /// A Save to Pictures is running.
  final bool saving;

  ExpensePhotosState copyWith({
    List<SavedPhoto>? photos,
    bool? loaded,
    Set<int>? Function()? selection,
    bool? saving,
  }) => ExpensePhotosState(
    photos: photos ?? this.photos,
    loaded: loaded ?? this.loaded,
    selection: selection == null ? this.selection : selection(),
    saving: saving ?? this.saving,
  );
}

class ExpensePhotosCubit extends CubitSignal<ExpensePhotosState>
    with EmitIfOpen<ExpensePhotosState> {
  ExpensePhotosCubit({
    required this._expenses,
    required this._store,
    required this._expense,
    required this._fallbackTitle,
  }) : super(initialState: const ExpensePhotosState());

  final ExpenseRepository _expenses;
  final PhotoStore _store;
  final Expense _expense;
  final String _fallbackTitle;

  PhotoStore get store => _store;

  /// Reads the photos; a failure shows none (the detail still works).
  Future<void> load() async {
    if (_expense.photoCount == 0) {
      emitIfOpen(value.copyWith(loaded: true));
      return;
    }
    try {
      final photos = await _expenses.photosOf(_expense.id);
      emitIfOpen(value.copyWith(photos: photos, loaded: true));
    } catch (error) {
      debugPrint('Reading the binned expense\'s photos failed: $error');
      emitIfOpen(value.copyWith(loaded: true));
    }
  }

  void startSelection(int index) =>
      emitIfOpen(value.copyWith(selection: () => {index}));

  void toggleSelected(int index) {
    final selection = value.selection;
    if (selection == null) return;
    emitIfOpen(
      value.copyWith(selection: () => toggledSelection(selection, index)),
    );
  }

  void selectAll() {
    if (value.selection == null) return;
    emitIfOpen(
      value.copyWith(
        selection: () => {for (var i = 0; i < value.photos.length; i++) i},
      ),
    );
  }

  void clearSelection() => emitIfOpen(value.copyWith(selection: () => null));

  /// The selected photos to Pictures; selection stays.
  Future<SaveToPicturesResult?> saveSelected() {
    final selection = value.selection;
    if (selection == null) return Future.value();
    return save(selection.toList()..sort());
  }

  /// Photos at [indexes] to Pictures, named and dated by this expense. A
  /// second call while one runs is ignored.
  Future<SaveToPicturesResult?> save(List<int> indexes) async {
    if (value.saving) return null;
    emitIfOpen(value.copyWith(saving: true));
    try {
      return await _store.saveToPictures([
        for (final i in indexes) pictureOf(_expense, value.photos[i]),
      ], fallbackTitle: _fallbackTitle);
    } finally {
      emitIfOpen(value.copyWith(saving: false));
    }
  }
}
