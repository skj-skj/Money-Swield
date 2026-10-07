import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';
import '../../../core/picker_order.dart';

/// The categories and events shown in the Customize tiles preview, by
/// name. Null while loading, or if loading failed (the preview is then
/// empty; the shape choices still work).
typedef TilePreviewItems = ({
  List<PickerItem> categories,
  List<PickerItem> events,
});

/// Loads the user's own categories and unarchived events for the preview,
/// so it looks like their Add expense screen.
class TilePreviewCubit extends CubitSignal<TilePreviewItems?>
    with EmitIfOpen<TilePreviewItems?> {
  TilePreviewCubit({
    required this._categories,
    required this._events,
    required this._l10n,
  }) : super(initialState: null);

  final CategoryRepository _categories;
  final EventRepository _events;
  final AppLocalizations _l10n;

  Future<void> load() async {
    try {
      final categories = [
        for (final c in await _categories.all())
          PickerItem(id: c.id, emoji: c.emoji, name: categoryName(_l10n, c)),
      ]..sort(_byName);
      final events = [
        for (final e in await _events.all())
          if (!e.isArchived)
            PickerItem(id: e.id, emoji: e.emoji, name: eventName(_l10n, e)),
      ]..sort(_byName);
      emitIfOpen((categories: categories, events: events));
    } catch (error) {
      // Only a preview: log and show it empty.
      debugPrint('Loading the tile preview failed: $error');
    }
  }

  static int _byName(PickerItem a, PickerItem b) =>
      compareNames(a.name, b.name);
}
