import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/app_theme_mode.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/languages.dart';
import '../../../core/widgets/choice_dialog.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/save_error.dart';
import '../../payment_methods/view_models/payment_method_list_cubit.dart';
import '../view_models/settings_cubit.dart';

/// The Settings tab: language, theme, default currency and default payment
/// method. Every change applies at once.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.paymentMethods,
    required this.isVisible,
  });

  final PaymentMethodRepository paymentMethods;

  /// Whether this tab is the one shown. The shell keeps the tab alive while
  /// hidden, and payment methods may be renamed meanwhile on the Manage tab,
  /// so they are reloaded each time the tab comes back.
  final bool isVisible;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PaymentMethodListCubit? _paymentMethodList;
  AppLocalizations? _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The list is sorted by name in one language, so it is rebuilt when
    // the user switches language on this very screen.
    final l10n = AppLocalizations.of(context);
    if (l10n == _l10n) return;
    _l10n = l10n;
    _paymentMethodList?.close();
    _paymentMethodList = PaymentMethodListCubit(
      repository: widget.paymentMethods,
      l10n: l10n,
    )..load();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _paymentMethodList?.load();
  }

  @override
  void dispose() {
    _paymentMethodList?.close();
    super.dispose();
  }

  SettingsCubit get _settings => context.read<SettingsCubit>();

  Future<void> _pickLanguage(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final locales = [null, for (final code in languageNames.keys) Locale(code)];
    final index = await showChoiceDialog(
      context,
      title: l10n.settingLanguage,
      options: [
        Text(l10n.languageSystem),
        for (final name in languageNames.values) Text(name),
      ],
      selectedIndex: locales.indexWhere(
        (l) => l?.languageCode == settings.locale?.languageCode,
      ),
    );
    if (index == null || !mounted) return;
    await saveOrShowError(context, () => _settings.setLocale(locales[index]));
  }

  Future<void> _pickTheme(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    const themes = AppThemeMode.values;
    final index = await showChoiceDialog(
      context,
      title: l10n.settingTheme,
      options: [for (final theme in themes) Text(_themeName(l10n, theme))],
      selectedIndex: themes.indexOf(settings.theme),
    );
    if (index == null || !mounted) return;
    await saveOrShowError(context, () => _settings.setTheme(themes[index]));
  }

  Future<void> _pickCurrency(AppSettings settings) async {
    final code = await showCurrencyPicker(
      context,
      selected: settings.defaultCurrency,
    );
    if (code == null || !mounted) return;
    await saveOrShowError(context, () => _settings.setDefaultCurrency(code));
  }

  Future<void> _pickPaymentMethod(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    // Fresh, in case one was added or renamed since the tab was shown.
    await _paymentMethodList!.load();
    if (!mounted) return;
    final list = _paymentMethodList!.value;
    if (list is! PaymentMethodListLoaded) {
      // The row now says so too; tapping it again retries.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
      return;
    }
    final methods = list.paymentMethods;
    final index = await showChoiceDialog(
      context,
      title: l10n.settingDefaultPaymentMethod,
      options: [
        for (final method in methods)
          Text('${method.emoji}  ${paymentMethodName(l10n, method)}'),
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
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.settingLanguage),
              subtitle: Text(
                languageNames[settings.locale?.languageCode] ??
                    l10n.languageSystem,
              ),
              onTap: () => _pickLanguage(settings),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(l10n.settingTheme),
              subtitle: Text(_themeName(l10n, settings.theme)),
              onTap: () => _pickTheme(settings),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(l10n.settingDefaultCurrency),
              subtitle: Text(currencyLabel(settings.defaultCurrency)),
              onTap: () => _pickCurrency(settings),
            ),
            BlocSignalBuilder<PaymentMethodListCubit, PaymentMethodListState>(
              bloc: _paymentMethodList!,
              builder: (context, list) {
                final method = _findMethod(
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
                      : Text(
                          '${method.emoji}  ${paymentMethodName(l10n, method)}',
                        ),
                  onTap: () => _pickPaymentMethod(settings),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static PaymentMethod? _findMethod(PaymentMethodListState list, int? id) =>
      switch (list) {
        PaymentMethodListLoaded(:final paymentMethods) =>
          paymentMethods.where((m) => m.id == id).firstOrNull,
        _ => null,
      };

  static String _themeName(AppLocalizations l10n, AppThemeMode theme) =>
      switch (theme) {
        AppThemeMode.system => l10n.themeSystem,
        AppThemeMode.light => l10n.themeLight,
        AppThemeMode.dark => l10n.themeDark,
      };
}
