import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/picker_order.dart';
import '../../../core/widgets/move_dialog.dart';
import '../../../core/widgets/save_error.dart';
import '../../manage/views/item_form_scaffold.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= PaymentMethodFormCubit(
      repository: widget.repository,
      settings: context.read<SettingsCubit>(),
      l10n: AppLocalizations.of(context),
      original: widget.original,
      existing: widget.existing,
    );
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  /// Delete (never offered for the default, which the repository refuses
  /// as well): a plain confirm when no expense uses it; otherwise ask where
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
              name: paymentMethodName(l10n, other),
            ),
      ],
      searchHint: l10n.search,
      allTitle: l10n.paymentMethodsTitle,
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
    return ItemFormScaffold<PaymentMethod>(
      cubit: cubit,
      title: cubit.isEditing ? l10n.editPaymentMethod : l10n.addPaymentMethod,
      // Opened only from the list, which reloads on return.
      popWithSaved: false,
      actions: (context, state) => [
        // Rebuilds when the default changes, e.g. after "Set as default".
        BlocSignalBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) {
            final isDefault = cubit.isDefault;
            final original = widget.original!;
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
                        : () => saveOrShowError(context, cubit.setAsDefault),
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
    );
  }
}
