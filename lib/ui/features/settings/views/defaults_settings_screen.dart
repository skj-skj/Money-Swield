import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/currency_labels.dart';
import '../../../core/item_labels.dart';
import '../../../core/recent_currencies.dart';
import '../../../core/widgets/choice_dialog.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../payment_methods/view_models/payment_method_list_cubit.dart';
import '../view_models/settings_cubit.dart';

/// Settings → Defaults (phase-5.md §8.5): the default currency and payment
/// method for new expenses, the rows of the former Settings list, moved
/// with their behaviour unchanged.
class DefaultsSettingsScreen extends StatefulWidget {
  const DefaultsSettingsScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<DefaultsSettingsScreen> createState() => _DefaultsSettingsScreenState();
}

class _DefaultsSettingsScreenState extends State<DefaultsSettingsScreen> {
  PaymentMethodListCubit? _paymentMethodList;
  AppLocalizations? _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sorted by name in one language.
    final l10n = AppLocalizations.of(context);
    if (l10n == _l10n) return;
    _l10n = l10n;
    _paymentMethodList?.close();
    _paymentMethodList = PaymentMethodListCubit(
      repository: widget.dependencies.paymentMethods,
      l10n: l10n,
    )..load();
  }

  @override
  void dispose() {
    _paymentMethodList?.close();
    super.dispose();
  }

  SettingsCubit get _settings => context.read<SettingsCubit>();

  Future<void> _pickCurrency(AppSettings settings) async {
    final recent = await recentCurrenciesOrEmpty(widget.dependencies.expenses);
    if (!mounted) return;
    final code = await showCurrencyPicker(
      context,
      selected: settings.defaultCurrency,
      recent: recent,
    );
    if (code == null || !mounted) return;
    await saveOrShowError(context, () => _settings.setDefaultCurrency(code));
  }

  Future<void> _pickPaymentMethod(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    // Fresh, in case one was added or renamed meanwhile.
    await _paymentMethodList!.load();
    if (!mounted) return;
    final list = _paymentMethodList!.value;
    if (list is! PaymentMethodListLoaded) {
      // The row now says so too; tapping it again retries.
      showMessage(ScaffoldMessenger.of(context), l10n.loadFailed);
      return;
    }
    final methods = list.paymentMethods;
    final index = await showChoiceDialog(
      context,
      title: l10n.settingDefaultPaymentMethod,
      options: [
        for (final method in methods) Text(paymentMethodLabel(l10n, method)),
      ],
      selectedIndex: methods.indexWhere(
        (m) => m.id == settings.defaultPaymentMethodId,
      ),
    );
    if (index == null || !mounted) return;
    await saveOrShowError(
      context,
      () => _settings.setDefaultPaymentMethodId(methods[index].id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDefaults)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(l10n.settingDefaultCurrency),
              subtitle: Text(currencyLabel(settings.defaultCurrency)),
              onTap: () => _pickCurrency(settings),
            ),
            BlocSignalBuilder<PaymentMethodListCubit, PaymentMethodListState>(
              bloc: _paymentMethodList!,
              builder: (context, list) {
                final method = findPaymentMethod(
                  list,
                  settings.defaultPaymentMethodId,
                );
                return ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(l10n.settingDefaultPaymentMethod),
                  subtitle: list is PaymentMethodListFailed
                      ? Text(l10n.loadFailed)
                      : method == null
                      ? null
                      : Text(paymentMethodLabel(l10n, method)),
                  onTap: () => _pickPaymentMethod(settings),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The payment method [id] in [list], or null while loading or missing.
PaymentMethod? findPaymentMethod(PaymentMethodListState list, int? id) =>
    switch (list) {
      PaymentMethodListLoaded(:final paymentMethods) =>
        paymentMethods.where((m) => m.id == id).firstOrNull,
      _ => null,
    };
