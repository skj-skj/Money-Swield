import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/async_body.dart';
import '../../manage/views/manage_list_scaffold.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/payment_method_list_cubit.dart';
import 'payment_method_form_screen.dart';

/// Every payment method, sorted by name, with a "Default" badge on the
/// default one. Tap one to edit it; the button adds one.
class PaymentMethodListScreen extends StatefulWidget {
  const PaymentMethodListScreen({super.key, required this.repository});

  final PaymentMethodRepository repository;

  @override
  State<PaymentMethodListScreen> createState() =>
      _PaymentMethodListScreenState();
}

class _PaymentMethodListScreenState extends State<PaymentMethodListScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  PaymentMethodListCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= PaymentMethodListCubit(
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
    PaymentMethod? method,
    required List<PaymentMethod> all,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PaymentMethodFormScreen(
          repository: widget.repository,
          original: method,
          existing: all,
        ),
      ),
    );
    await _cubit?.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<PaymentMethodListCubit, PaymentMethodListState>(
      bloc: _cubit!,
      builder: (context, state) => ManageListScaffold(
        title: l10n.paymentMethodsTitle,
        addLabel: l10n.addPaymentMethod,
        phase: switch (state) {
          PaymentMethodListLoading() => LoadPhase.loading,
          PaymentMethodListFailed() => LoadPhase.failed,
          PaymentMethodListLoaded(:final paymentMethods)
              when paymentMethods.isEmpty =>
            LoadPhase.empty,
          PaymentMethodListLoaded() => LoadPhase.loaded,
        },
        onRetry: () => _cubit?.load(),
        onAdd: () =>
            _openForm(all: (state as PaymentMethodListLoaded).paymentMethods),
        emptyIcon: Icons.payments_outlined,
        emptyText: l10n.listEmpty,
        // The Default badge follows the setting at once.
        builder: (context) => BlocSignalBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) {
            final methods = (state as PaymentMethodListLoaded).paymentMethods;
            return ItemCardGrid(
              items: [
                for (final method in methods)
                  (
                    key: method.id,
                    emoji: method.emoji,
                    title: paymentMethodName(l10n, method),
                    description: null,
                    badge: method.id == settings.defaultPaymentMethodId
                        ? l10n.defaultBadge
                        : null,
                    onTap: () => _openForm(method: method, all: methods),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
