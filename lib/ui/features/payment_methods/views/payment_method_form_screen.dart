import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/form_validation.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/emoji_picker_field.dart';
import '../../../core/widgets/save_error.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/payment_method_form_cubit.dart';

/// Adds a payment method, or edits [original] when it is set. Pops when
/// saved or deleted.
class PaymentMethodFormScreen extends StatefulWidget {
  const PaymentMethodFormScreen({
    super.key,
    required this.repository,
    required this.original,
    required this.existing,
  });

  final PaymentMethodRepository repository;
  final PaymentMethod? original;

  /// Every payment method, to refuse duplicate names.
  final List<PaymentMethod> existing;

  @override
  State<PaymentMethodFormScreen> createState() =>
      _PaymentMethodFormScreenState();
}

class _PaymentMethodFormScreenState extends State<PaymentMethodFormScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  PaymentMethodFormCubit? _cubit;
  late final TextEditingController _name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final cubit = PaymentMethodFormCubit(
      repository: widget.repository,
      settings: context.read<SettingsCubit>(),
      l10n: AppLocalizations.of(context),
      original: widget.original,
      existing: widget.existing,
    );
    _cubit = cubit;
    _name = TextEditingController(text: cubit.value.name);
  }

  @override
  void dispose() {
    _cubit?.close();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    PaymentMethod? saved;
    await saveOrShowError(context, () async => saved = await _cubit!.save());
    if (saved != null && mounted) Navigator.pop(context);
  }

  Future<void> _delete(String name) async {
    if (!await confirmDelete(context, name) || !mounted) return;
    final deleted = await saveOrShowError(context, () => _cubit!.delete());
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
    return BlocSignalBuilder<PaymentMethodFormCubit, PaymentMethodFormState>(
      bloc: cubit,
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            cubit.isEditing ? l10n.editPaymentMethod : l10n.addPaymentMethod,
          ),
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
            if (original != null)
              // Rebuilds when the default changes, e.g. after "Set as default".
              BlocSignalBuilder<SettingsCubit, AppSettings>(
                builder: (context, settings) {
                  final isDefault = cubit.isDefault;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      if (isDefault)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Chip(label: Text(l10n.defaultBadge)),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: state.saving
                              ? null
                              : () => saveOrShowError(
                                  context,
                                  cubit.setAsDefault,
                                ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(l10n.setAsDefault),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: state.saving || isDefault
                            ? null
                            : () => _delete(paymentMethodName(l10n, original)),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.delete),
                      ),
                      if (isDefault) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.cannotDeleteDefaultHint,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
