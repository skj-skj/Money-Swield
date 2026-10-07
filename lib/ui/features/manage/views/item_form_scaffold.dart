import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/form_validation.dart';
import '../../../core/widgets/emoji_picker_field.dart';
import '../../../core/widgets/save_error.dart';
import '../view_models/item_form_cubit.dart';

/// The add/edit screen the Manage forms share: Save in the app bar, then
/// the emoji, the name (with "Reset to default name" for a renamed
/// built-in), the description when [ItemFormCubit.hasDescription], and
/// [actions] under them when editing (delete, archive, set as default:
/// each form's own). Saving pops, with the saved item when
/// [popWithSaved] (so the expense form can select a new category or event).
class ItemFormScaffold<T> extends StatefulWidget {
  const ItemFormScaffold({
    super.key,
    required this.cubit,
    required this.title,
    required this.actions,
    this.popWithSaved = true,
  });

  /// Owned by the screen that made it (and closed there).
  final ItemFormCubit<T> cubit;

  /// "Add category", "Edit event" …
  final String title;

  /// Built under the fields, only when editing; rebuilt with the state, so
  /// the buttons can follow `saving`.
  final List<Widget> Function(BuildContext context, ItemFormState state)
  actions;

  /// Pops with the saved item; false pops with nothing (payment methods,
  /// opened only from their list).
  final bool popWithSaved;

  @override
  State<ItemFormScaffold<T>> createState() => _ItemFormScaffoldState<T>();
}

class _ItemFormScaffoldState<T> extends State<ItemFormScaffold<T>> {
  late final _name = TextEditingController(text: widget.cubit.value.name);
  late final _description = TextEditingController(
    text: widget.cubit.value.description,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    T? saved;
    await saveOrShowError(
      context,
      () async => saved = await widget.cubit.save(),
    );
    if (saved == null || !mounted) return;
    widget.popWithSaved
        ? Navigator.pop(context, saved)
        : Navigator.pop(context);
  }

  void _resetName() {
    widget.cubit.resetName();
    _name.text = widget.cubit.value.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = widget.cubit;
    return BlocSignalBuilder<ItemFormCubit<T>, ItemFormState>(
      bloc: cubit,
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
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
            if (cubit.hasDescription) ...[
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
            ],
            if (cubit.isEditing) ...widget.actions(context, state),
          ],
        ),
      ),
    );
  }
}
