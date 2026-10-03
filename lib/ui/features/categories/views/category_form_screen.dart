import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/form_validation.dart';
import '../../../core/picker_order.dart';
import '../../../core/widgets/emoji_picker_field.dart';
import '../../../core/widgets/move_dialog.dart';
import '../../../core/widgets/save_error.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/category_form_cubit.dart';

/// Adds a category, or edits [original] when it is set. Pops when saved or
/// deleted.
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
  // Created in didChangeDependencies because they need the localizations.
  CategoryFormCubit? _cubit;
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final cubit = CategoryFormCubit(
      repository: widget.repository,
      l10n: AppLocalizations.of(context),
      original: widget.original,
      existing: widget.existing,
      initialName: widget.initialName,
    );
    _cubit = cubit;
    _name = TextEditingController(text: cubit.value.name);
    _description = TextEditingController(text: cubit.value.description);
  }

  @override
  void dispose() {
    _cubit?.close();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Category? saved;
    await saveOrShowError(context, () async => saved = await _cubit!.save());
    // Pops with the saved category, so the expense form can select it.
    if (saved != null && mounted) Navigator.pop(context, saved);
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

  void _resetName() {
    _cubit!.resetName();
    _name.text = _cubit!.value.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = _cubit!;
    final original = widget.original;
    return BlocSignalBuilder<CategoryFormCubit, CategoryFormState>(
      bloc: cubit,
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(cubit.isEditing ? l10n.editCategory : l10n.addCategory),
          actions: [
            TextButton(
              onPressed: state.saving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmojiPickerField(
              emoji: state.emoji,
              onChanged: cubit.emojiChanged,
              errorText: emojiErrorText(l10n, cubit.emojiError),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('name'),
              controller: _name,
              onChanged: cubit.nameChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: nameErrorText(l10n, cubit.nameError, state.name),
                border: const OutlineInputBorder(),
              ),
            ),
            if (cubit.canResetName)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _resetName,
                  child: Text(l10n.resetToDefaultName),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('description'),
              controller: _description,
              onChanged: cubit.descriptionChanged,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldDescription,
                errorText: descriptionErrorText(l10n, cubit.descriptionError),
                border: const OutlineInputBorder(),
              ),
            ),
            if (original != null) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: state.saving
                    ? null
                    : () => _delete(categoryName(l10n, original)),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
