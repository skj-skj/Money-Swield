import 'dart:ui' show Locale;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/payment_method.dart';
import '../../settings/view_models/settings_cubit.dart';

/// The onboarding steps, in order.
enum OnboardingStep { language, currency, paymentMethod }

class OnboardingState {
  const OnboardingState({
    required this.step,
    required this.locale,
    required this.currency,
    required this.paymentMethodId,
    required this.paymentMethods,
    this.paymentMethodsFailed = false,
    this.busy = false,
  });

  final OnboardingStep step;

  /// The chosen language, or null for the device's.
  final Locale? locale;

  /// The chosen currency's ISO code.
  final String currency;

  /// The chosen default payment method.
  final int? paymentMethodId;

  /// The methods to pick from, in seed order (Cash first). Null while
  /// loading, or if loading failed.
  final List<PaymentMethod>? paymentMethods;

  /// Loading [paymentMethods] failed; the last step offers Try again.
  final bool paymentMethodsFailed;

  /// A choice is being saved, or "Get started" is running.
  final bool busy;

  bool get isFirstStep => step == OnboardingStep.values.first;
  bool get isLastStep => step == OnboardingStep.values.last;

  OnboardingState copyWith({
    OnboardingStep? step,
    String? currency,
    int? paymentMethodId,
    List<PaymentMethod>? paymentMethods,
    bool? paymentMethodsFailed,
    bool? busy,
  }) => OnboardingState(
    step: step ?? this.step,
    locale: locale,
    currency: currency ?? this.currency,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    paymentMethodsFailed: paymentMethodsFailed ?? this.paymentMethodsFailed,
    busy: busy ?? this.busy,
  );

  /// A copy with the language set to [locale] (null = the device's). Apart
  /// from [copyWith] because null is a real choice here.
  OnboardingState withLocale(Locale? locale) => OnboardingState(
    step: step,
    locale: locale,
    currency: currency,
    paymentMethodId: paymentMethodId,
    paymentMethods: paymentMethods,
    paymentMethodsFailed: paymentMethodsFailed,
    busy: busy,
  );
}

/// The three onboarding steps (phase-1.md §9.1): language, currency,
/// default payment method.
///
/// Each choice is saved as soon as it's made, so killing the app midway
/// restarts onboarding with those choices preselected: the initial choices
/// come from the saved settings.
///
/// Depends on [SettingsCubit] on purpose (instead of writing through
/// `SettingsRepository`): it is the one owner of the settings the whole app
/// shows, and its write-then-emit is what makes a picked language apply at
/// once.
class OnboardingCubit extends CubitSignal<OnboardingState> {
  OnboardingCubit({required this._settings, required this._paymentMethods})
    : super(
        initialState: OnboardingState(
          step: OnboardingStep.language,
          locale: _settings.value.locale,
          currency: _settings.value.defaultCurrency,
          paymentMethodId: _settings.value.defaultPaymentMethodId,
          paymentMethods: null,
        ),
      );

  final SettingsCubit _settings;
  final PaymentMethodRepository _paymentMethods;

  /// Loads the payment methods for the last step. A failure sets
  /// [OnboardingState.paymentMethodsFailed]; calling this again retries.
  Future<void> loadPaymentMethods() async {
    _emitIfOpen(value.copyWith(paymentMethodsFailed: false));
    try {
      final methods = await _paymentMethods.all();
      methods.sort((a, b) => a.id.compareTo(b.id));
      _emitIfOpen(value.copyWith(paymentMethods: methods));
    } catch (error, stackTrace) {
      debugPrint('Loading payment methods failed: $error\n$stackTrace');
      _emitIfOpen(value.copyWith(paymentMethodsFailed: true));
    }
  }

  /// Applies the language at once (the next steps already show in it) and
  /// saves it. Rethrows if saving fails; the choice is then not taken.
  Future<void> selectLanguage(Locale? locale) => _saving(
    () => _settings.setLocale(locale),
    (state) => state.withLocale(locale),
  );

  Future<void> selectCurrency(String code) => _saving(
    () => _settings.setDefaultCurrency(code),
    (state) => state.copyWith(currency: code),
  );

  Future<void> selectPaymentMethod(int id) => _saving(
    () => _settings.setDefaultPaymentMethodId(id),
    (state) => state.copyWith(paymentMethodId: id),
  );

  void next() {
    if (value.isLastStep) return;
    _emitIfOpen(
      value.copyWith(step: OnboardingStep.values[value.step.index + 1]),
    );
  }

  void back() {
    if (value.isFirstStep) return;
    _emitIfOpen(
      value.copyWith(step: OnboardingStep.values[value.step.index - 1]),
    );
  }

  /// "Get started": writes the preselected choices the user didn't touch,
  /// then marks onboarding as done, which makes the app show the shell.
  /// Rethrows if a write fails; onboarding then stays open.
  Future<void> finish() async {
    final state = value;
    if (state.busy) return;
    _emitIfOpen(state.copyWith(busy: true));
    try {
      await _settings.setDefaultCurrency(state.currency);
      final paymentMethodId = state.paymentMethodId;
      if (paymentMethodId != null) {
        await _settings.setDefaultPaymentMethodId(paymentMethodId);
      }
      // Last, so a failure above leaves onboarding open to retry.
      await _settings.setOnboardingCompleted();
    } finally {
      _emitIfOpen(value.copyWith(busy: false));
    }
  }

  /// Saves a choice with [save], then shows it with [apply]. Choices made
  /// while another is saving are ignored, so they can't finish out of order.
  Future<void> _saving(
    Future<void> Function() save,
    OnboardingState Function(OnboardingState) apply,
  ) async {
    if (value.busy) return;
    _emitIfOpen(value.copyWith(busy: true));
    try {
      await save();
      _emitIfOpen(apply(value));
    } finally {
      _emitIfOpen(value.copyWith(busy: false));
    }
  }

  // The screen goes away (and closes this cubit) as soon as onboarding is
  // marked done, while finish() is still running. Emitting after close()
  // asserts in debug mode.
  void _emitIfOpen(OnboardingState state) {
    if (!isClosed) emit(state);
  }
}
