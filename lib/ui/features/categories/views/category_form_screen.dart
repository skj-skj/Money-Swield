import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/picker_order.dart';
import '../../../core/widgets/move_dialog.dart';
import '../../manage/views/item_form_scaffold.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/category_form_cubit.dart';

/// Adds a category, or edits [original] when it is set. Pops when saved
/// (with the saved category) or deleted.
class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({
    super.key,
    required this.repository,
    required this.original,
    required this.existing,
    this.initialName = '',
  });

  final CategoryRepository repository;
  final Category? original;

  /// Every category, to refuse duplicate names.
  final List<Category> existing;

  /// The name a new category starts with; ignored when editing.
  final String initialName;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  CategoryFormCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= CategoryFormCubit(
      repository: widget.repository,
      l10n: AppLocalizations.of(context),
      original: widget.original,
      existing: widget.existing,
      initialName: widget.initialName,
    );
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  /// Delete: a plain confirm when no expense uses it; otherwise ask where
  /// to move its expenses, binned ones included, then move and delete in
  /// one transaction (D7, phase-2.md §10.1).
  Future<void> _delete(String name) async {
    final l10n = AppLocalizations.of(context);
    final original = widget.original!;
    final shapes = context.read<SettingsCubit>().value;
    final cubit = _cubit!;
    final deleted = await deleteOrMoveThenDelete(
      context,
      name: name,
      usage: cubit.usage,
      targets: [
        for (final other in widget.existing)
          if (other.id != original.id)
            PickerItem(
              id: other.id,
              emoji: other.emoji,
              name: categoryName(l10n, other),
            ),
      ],
      searchHint: l10n.searchCategories,
      allTitle: l10n.allCategories,
      tileShape: shapes.tileShape,
      buttonShape: shapes.buttonShape,
      delete: cubit.delete,
      moveAndDelete: cubit.moveExpensesAndDelete,
    );
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = _cubit!;
    return ItemFormScaffold<Category>(
      cubit: cubit,
      title: cubit.isEditing ? l10n.editCategory : l10n.addCategory,
      actions: (context, state) => [
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: state.saving
              ? null
              : () => _delete(categoryName(l10n, widget.original!)),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.delete),
        ),
      ],
    );
  }
}
