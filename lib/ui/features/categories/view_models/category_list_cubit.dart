import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';

/// What the categories screen shows. States don't override `==`, so every
/// emitted state reaches the screen.
sealed class CategoryListState {
  const CategoryListState();
}

final class CategoryListLoading extends CategoryListState {
  const CategoryListLoading();
}

final class CategoryListLoaded extends CategoryListState {
  const CategoryListLoaded(this.categories);

  /// Sorted by display name.
  final List<Category> categories;
}

final class CategoryListFailed extends CategoryListState {
  const CategoryListFailed(this.error);

  final Object error;
}

/// Loads the categories for the list screen, sorted by display name in the
/// current language. (Sorting by popularity comes with expenses, Phase 2.)
class CategoryListCubit extends CubitSignal<CategoryListState>
    with EmitIfOpen<CategoryListState> {
  CategoryListCubit({required this._repository, required this._l10n})
    : super(initialState: const CategoryListLoading());

  final CategoryRepository _repository;

  /// The language the names are sorted in, fixed for this screen's life.
  /// The in-app language switch is only reachable after popping the screen.
  /// With "System default", a device language change can reach it while
  /// open; the cards then show the new names in the old order until the
  /// next reload (after any edit). Harmless, so not handled.
  final AppLocalizations _l10n;

  /// Loads (or reloads) the list. A reload keeps showing the old list until
  /// the new one is ready, so the screen doesn't flash a spinner.
  Future<void> load() async {
    try {
      final categories = await _repository.all();
      categories.sort((a, b) {
        final byName = compareNames(
          categoryName(_l10n, a),
          categoryName(_l10n, b),
        );
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
      emitIfOpen(CategoryListLoaded(categories));
    } catch (error) {
      emitIfOpen(CategoryListFailed(error));
    }
  }
}
