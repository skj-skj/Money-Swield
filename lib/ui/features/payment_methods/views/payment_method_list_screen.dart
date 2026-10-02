import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/item_card.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/two_column_masonry.dart';
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
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(l10n.paymentMethodsTitle)),
        floatingActionButton: state is PaymentMethodListLoaded
            ? FloatingActionButton.extended(
                onPressed: () => _openForm(all: state.paymentMethods),
                icon: const Icon(Icons.add),
                label: Text(l10n.addPaymentMethod),
              )
            : null,
        body: switch (state) {
          PaymentMethodListLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          PaymentMethodListFailed() => LoadFailedView(
            onRetry: () => _cubit?.load(),
          ),
          PaymentMethodListLoaded(:final paymentMethods)
              when paymentMethods.isEmpty =>
            Center(child: Text(l10n.listEmpty)),
          PaymentMethodListLoaded(:final paymentMethods) =>
            BlocSignalBuilder<SettingsCubit, AppSettings>(
              builder: (context, settings) => SingleChildScrollView(
                // Room for the floating button under the last row.
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                child: TwoColumnMasonry(
                  children: [
                    for (final method in paymentMethods)
                      ItemCard(
                        emoji: method.emoji,
                        title: paymentMethodName(l10n, method),
                        badge: method.id == settings.defaultPaymentMethodId
                            ? l10n.defaultBadge
                            : null,
                        onTap: () =>
                            _openForm(method: method, all: paymentMethods),
                      ),
                  ],
                ),
              ),
            ),
        },
      ),
    );
  }
}
