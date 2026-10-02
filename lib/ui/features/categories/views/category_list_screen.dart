import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/item_card.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/two_column_masonry.dart';
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
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(l10n.categoriesTitle)),
        floatingActionButton: state is CategoryListLoaded
            ? FloatingActionButton.extended(
                onPressed: () => _openForm(all: state.categories),
                icon: const Icon(Icons.add),
                label: Text(l10n.addCategory),
              )
            : null,
        body: switch (state) {
          CategoryListLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          CategoryListFailed() => LoadFailedView(onRetry: () => _cubit?.load()),
          CategoryListLoaded(:final categories) when categories.isEmpty =>
            Center(child: Text(l10n.listEmpty)),
          CategoryListLoaded(:final categories) => SingleChildScrollView(
            // Room for the floating button under the last row.
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            child: TwoColumnMasonry(
              children: [
                for (final category in categories)
                  ItemCard(
                    emoji: category.emoji,
                    title: categoryName(l10n, category),
                    description: category.description,
                    onTap: () => _openForm(category: category, all: categories),
                  ),
              ],
            ),
          ),
        },
      ),
    );
  }
}
