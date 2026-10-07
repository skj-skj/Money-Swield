import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/async_body.dart';
import '../../manage/views/manage_list_scaffold.dart';
import '../view_models/category_list_cubit.dart';
import 'category_form_screen.dart';

/// Every category, sorted by name. Tap one to edit it; the button adds one.
class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key, required this.repository});

  final CategoryRepository repository;

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  CategoryListCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= CategoryListCubit(
      repository: widget.repository,
      l10n: AppLocalizations.of(context),
    )..load();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _openForm({
    Category? category,
    required List<Category> all,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CategoryFormScreen(
          repository: widget.repository,
          original: category,
          existing: all,
        ),
      ),
    );
    await _cubit?.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<CategoryListCubit, CategoryListState>(
      bloc: _cubit!,
      builder: (context, state) => ManageListScaffold(
        title: l10n.categoriesTitle,
        addLabel: l10n.addCategory,
        phase: switch (state) {
          CategoryListLoading() => LoadPhase.loading,
          CategoryListFailed() => LoadPhase.failed,
          CategoryListLoaded(:final categories) when categories.isEmpty =>
            LoadPhase.empty,
          CategoryListLoaded() => LoadPhase.loaded,
        },
        onRetry: () => _cubit?.load(),
        onAdd: () => _openForm(all: (state as CategoryListLoaded).categories),
        emptyIcon: Icons.category_outlined,
        emptyText: l10n.listEmpty,
        builder: (context) {
          final categories = (state as CategoryListLoaded).categories;
          return ItemCardGrid(
            items: [
              for (final category in categories)
                (
                  key: category.id,
                  emoji: category.emoji,
                  title: categoryName(l10n, category),
                  description: category.description,
                  badge: null,
                  onTap: () => _openForm(category: category, all: categories),
                ),
            ],
          );
        },
      ),
    );
  }
}
