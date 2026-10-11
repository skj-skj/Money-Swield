import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/services/sms_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/languages.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/onboarding_cubit.dart';

/// First-run setup: language, currency, default payment method. When it
/// finishes, the startup gate replaces it with the shell, so there is no
/// way back to it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.paymentMethods,
    this.onRestoreFromBackup,
    this.sms,
    this.setSmsEnabled,
  });

  final PaymentMethodRepository paymentMethods;

  /// The SMS step (phase-9a.md §8.6), shown only in a build with SMS.
  final SmsService? sms;
  final Future<void> Function(bool enabled)? setSmsEnabled;

  /// "Restore from a backup" under the language list (phase-3.md §6.7).
  /// Hidden when null.
  final VoidCallback? onRestoreFromBackup;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit =
        OnboardingCubit(
            settings: context.read<SettingsCubit>(),
            paymentMethods: widget.paymentMethods,
            sms: widget.sms,
            setSmsEnabled: widget.setSmsEnabled,
          )
          ..loadPaymentMethods()
          ..loadSms();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocSignalBuilder<OnboardingCubit, OnboardingState>(
      bloc: _cubit,
      builder: (context, state) {
        final stepCount = state.steps.length;
        final stepNumber = state.steps.indexOf(state.step) + 1;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    l10n.onboardingStep(stepNumber, stepCount),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LinearProgressIndicator(value: stepNumber / stepCount),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: switch (state.step) {
                    OnboardingStep.language => _LanguageStep(
                      state: state,
                      cubit: _cubit,
                      onRestoreFromBackup: widget.onRestoreFromBackup,
                    ),
                    OnboardingStep.currency => _StepPage(
                      title: l10n.onboardingCurrencyTitle,
                      subtitle: l10n.onboardingCurrencySubtitle,
                      child: CurrencySearchList(
                        selected: state.currency,
                        onSelected: (code) => saveOrShowError(
                          context,
                          () => _cubit.selectCurrency(code),
                        ),
                      ),
                    ),
                    OnboardingStep.paymentMethod => _PaymentMethodStep(
                      state: state,
                      cubit: _cubit,
                    ),
                    OnboardingStep.sms => _SmsStep(state: state, cubit: _cubit),
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (!state.isFirstStep)
                        TextButton(
                          onPressed: _cubit.back,
                          child: Text(l10n.back),
                        ),
                      const Spacer(),
                      if (state.isLastStep)
                        FilledButton(
                          onPressed: state.busy
                              ? null
                              : () => saveOrShowError(context, _cubit.finish),
                          child: Text(l10n.getStarted),
                        )
                      else
                        FilledButton(
                          onPressed: _cubit.next,
                          child: Text(l10n.next),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Suggest expenses from bank SMS?" (§8.6, P9a-28): Not now (the
/// default, highlighted) or Yes, which asks for the permission. Refused:
/// how to turn it on later; Get started works either way.
class _SmsStep extends StatelessWidget {
  const _SmsStep({required this.state, required this.cubit});

  final OnboardingState state;
  final OnboardingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StepPage(
      title: l10n.smsOnboardingQuestion,
      subtitle: l10n.smsPrivacyNote,
      child: ListView(
        children: [
          _ChoiceTile(
            key: const ValueKey('smsNotNow'),
            title: Text(l10n.smsNotNow),
            selected: !state.smsOn,
            onTap: () => saveOrShowError(context, () => cubit.chooseSms(false)),
          ),
          _ChoiceTile(
            key: const ValueKey('smsYes'),
            title: Text(l10n.smsYes),
            selected: state.smsOn,
            onTap: () => saveOrShowError(context, () => cubit.chooseSms(true)),
          ),
          if (state.smsRefused)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                l10n.smsPermissionRefused,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(title, style: textTheme.headlineSmall),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(subtitle, style: textTheme.bodyMedium),
          ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.state,
    required this.cubit,
    required this.onRestoreFromBackup,
  });

  final OnboardingState state;
  final OnboardingCubit cubit;
  final VoidCallback? onRestoreFromBackup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detected =
        languageNames[systemLanguageCode(
          View.of(context).platformDispatcher.locales,
        )]!;
    final selectedCode = state.locale?.languageCode;

    Widget option(String label, Locale? locale) => _ChoiceTile(
      title: Text(label),
      selected: selectedCode == locale?.languageCode,
      onTap: () => saveOrShowError(context, () => cubit.selectLanguage(locale)),
    );

    return _StepPage(
      title: l10n.onboardingLanguageTitle,
      child: ListView(
        children: [
          option(l10n.languageSystemDetected(detected), null),
          for (final MapEntry(key: code, value: name) in languageNames.entries)
            option(name, Locale(code)),
          if (onRestoreFromBackup case final onRestore?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.restoreFromBackup),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodStep extends StatelessWidget {
  const _PaymentMethodStep({required this.state, required this.cubit});

  final OnboardingState state;
  final OnboardingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final methods = state.paymentMethods;
    return _StepPage(
      title: l10n.onboardingPaymentMethodTitle,
      subtitle: l10n.onboardingPaymentMethodSubtitle,
      child: state.paymentMethodsFailed
          // "Get started" still works meanwhile, with the preselected default.
          ? LoadFailedView(onRetry: cubit.loadPaymentMethods)
          : methods == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final method in methods)
                  _ChoiceTile(
                    leading: Text(
                      method.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(paymentMethodName(l10n, method)),
                    selected: method.id == state.paymentMethodId,
                    onTap: () => saveOrShowError(
                      context,
                      () => cubit.selectPaymentMethod(method.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A list row with a radio mark, like the migration screen's choices.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    leading: leading,
    title: title,
    trailing: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
    ),
    selected: selected,
    onTap: onTap,
  );
}
