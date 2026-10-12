import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/owner_usage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../manage/view_models/item_form_cubit.dart';

/// The add/edit category form: the shared form ([ItemFormCubit]) plus delete,
/// or move the expenses then delete.
class CategoryFormCubit extends ItemFormCubit<Category> {
  /// [original] is the category being edited, or null to add one.
  /// [existing] is every category (the list screen already has them), used
  /// to refuse a duplicate name.
  CategoryFormCubit({
    required this._repository,
    required AppLocalizations l10n,
    required super.original,
    required List<Category> existing,
    // Only used when adding: the expense form's picker passes its search text,
    // so "chai" isn't typed twice.
    String initialName = '',
  }) : super(
         otherNames: [
           for (final category in existing)
             if (category.id != original?.id) categoryName(l10n, category),
         ],
         builtinName: switch (original?.builtinKey) {
           final String key => categoryBuiltinName(l10n, key),
           null => null,
         },
         hasDescription: true,
         initialState: ItemFormState(
           // A built-in shows its localized name, ready to be renamed.
           name: original == null ? initialName : categoryName(l10n, original),
           description: original?.description ?? '',
           emoji: original?.emoji ?? '',
         ),
       );

  final CategoryRepository _repository;

  @override
  Future<Category> addItem({
    required String name,
    required String? description,
    required String emoji,
  }) => _repository.add(name: name, description: description, emoji: emoji);

  @override
  Future<Category> updateItem(
    Category original, {
    required String? name,
    required String? description,
    required String emoji,
  }) => _repository.update(
    Category(
      id: original.id,
      builtinKey: original.builtinKey,
      name: name,
      description: description,
      emoji: emoji,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    ),
  );

  /// Deletes the category being edited. Only for an unused one: a used one
  /// goes through [moveExpensesAndDelete] (the FK would refuse it anyway).
  Future<void> delete() =>
      runBusy((original) => _repository.delete(original.id));

  /// How many expenses use the edited category, binned ones included.
  Future<OwnerUsage> usage() => _repository.usage(original!.id);

  /// Moves the edited category's expenses to [toId] and deletes it, in one
  /// transaction.
  Future<void> moveExpensesAndDelete(int toId) => runBusy(
    (original) => _repository.moveExpensesAndDelete(original.id, toId: toId),
  );
}
