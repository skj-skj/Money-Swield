import 'dart:ui' show Locale;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/services/sms_service.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../core/emit_if_open.dart';
import '../../settings/view_models/settings_cubit.dart';

/// The onboarding steps, in order. [sms] only in a build with SMS.
enum OnboardingStep { language, currency, paymentMethod, sms }

class OnboardingState {
  const OnboardingState({
    required this.step,
    required this.locale,
    required this.currency,
    required this.paymentMethodId,
    required this.paymentMethods,
    this.paymentMethodsFailed = false,
    this.busy = false,
    this.smsBuilt = false,
    this.smsOn = false,
    this.smsRefused = false,
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

  /// The build can read SMS: the fourth step shows.
  final bool smsBuilt;

  /// "Yes" was picked and the permission granted; "Not now" (the
  /// default) otherwise.
  final bool smsOn;

  /// The permission was refused: the step says how to turn it on later.
  final bool smsRefused;

  /// The steps this build shows, in order.
  List<OnboardingStep> get steps => [
    OnboardingStep.language,
    OnboardingStep.currency,
    OnboardingStep.paymentMethod,
    if (smsBuilt) OnboardingStep.sms,
  ];

  bool get isFirstStep => step == steps.first;
  bool get isLastStep => step == steps.last;

  OnboardingState copyWith({
    OnboardingStep? step,
    String? currency,
    int? paymentMethodId,
    List<PaymentMethod>? paymentMethods,
    bool? paymentMethodsFailed,
    bool? busy,
    bool? smsBuilt,
    bool? smsOn,
    bool? smsRefused,
  }) => OnboardingState(
    step: step ?? this.step,
    locale: locale,
    currency: currency ?? this.currency,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    paymentMethodsFailed: paymentMethodsFailed ?? this.paymentMethodsFailed,
    busy: busy ?? this.busy,
    smsBuilt: smsBuilt ?? this.smsBuilt,
    smsOn: smsOn ?? this.smsOn,
    smsRefused: smsRefused ?? this.smsRefused,
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
    smsBuilt: smsBuilt,
    smsOn: smsOn,
    smsRefused: smsRefused,
  );
}

/// The three onboarding steps: language, currency, default payment method.
///
/// Each choice is saved as soon as it's made, so killing the app midway
/// restarts onboarding with those choices preselected: the initial choices
/// come from the saved settings.
///
/// Depends on [SettingsCubit] on purpose (instead of writing through
/// `SettingsRepository`): it is the one owner of the settings the whole app
/// shows, and its write-then-emit is what makes a picked language apply at
/// once.
class OnboardingCubit extends CubitSignal<OnboardingState>
    with EmitIfOpen<OnboardingState> {
  OnboardingCubit({
    required this._settings,
    required this._paymentMethods,
    this._sms,
    this._setSmsEnabled,
  }) : super(
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

  /// The SMS permission; null: no SMS step.
  final SmsService? _sms;

  /// Writes `sms_enabled` (`SettingsRepository.setSmsEnabled`).
  final Future<void> Function(bool enabled)? _setSmsEnabled;

  /// Whether the build has SMS: adds the fourth step. A failure leaves it
  /// out (Settings → SMS still offers it if the build has it).
  Future<void> loadSms() async {
    try {
      final built = (await _sms?.status())?.built ?? false;
      emitIfOpen(value.copyWith(smsBuilt: built));
    } catch (error) {
      debugPrint('Reading the SMS status failed: $error');
    }
  }

  /// "Yes": asks for the permission; granted → on. Refused → stays "Not now"
  /// and the step says how to turn it on later; Get started works either way.
  /// Rethrows a failed write.
  Future<void> chooseSms(bool on) async {
    final sms = _sms;
    final setEnabled = _setSmsEnabled;
    if (sms == null || setEnabled == null || value.busy) return;
    if (!on) {
      if (value.smsOn) await setEnabled(false);
      emitIfOpen(value.copyWith(smsOn: false, smsRefused: false));
      return;
    }
    emitIfOpen(value.copyWith(busy: true));
    try {
      final granted = await sms.request();
      if (granted) await setEnabled(true);
      emitIfOpen(value.copyWith(smsOn: granted, smsRefused: !granted));
    } finally {
      emitIfOpen(value.copyWith(busy: false));
    }
  }

  /// Loads the payment methods for the last step. A failure sets
  /// [OnboardingState.paymentMethodsFailed]; calling this again retries.
  Future<void> loadPaymentMethods() async {
    emitIfOpen(value.copyWith(paymentMethodsFailed: false));
    try {
      final methods = await _paymentMethods.all();
      methods.sort((a, b) => a.id.compareTo(b.id));
      emitIfOpen(value.copyWith(paymentMethods: methods));
    } catch (error, stackTrace) {
      debugPrint('Loading payment methods failed: $error\n$stackTrace');
      emitIfOpen(value.copyWith(paymentMethodsFailed: true));
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
    final steps = value.steps;
    emitIfOpen(value.copyWith(step: steps[steps.indexOf(value.step) + 1]));
  }

  void back() {
    if (value.isFirstStep) return;
    final steps = value.steps;
    emitIfOpen(value.copyWith(step: steps[steps.indexOf(value.step) - 1]));
  }

  /// "Get started": writes the preselected choices the user didn't touch,
  /// then marks onboarding as done, which makes the app show the shell.
  /// Rethrows if a write fails; onboarding then stays open.
  Future<void> finish() async {
    final state = value;
    if (state.busy) return;
    emitIfOpen(state.copyWith(busy: true));
    try {
      await _settings.setDefaultCurrency(state.currency);
      final paymentMethodId = state.paymentMethodId;
      if (paymentMethodId != null) {
        await _settings.setDefaultPaymentMethodId(paymentMethodId);
      }
      // Last, so a failure above leaves onboarding open to retry.
      await _settings.setOnboardingCompleted();
    } finally {
      emitIfOpen(value.copyWith(busy: false));
    }
  }

  /// Saves a choice with [save], then shows it with [apply]. Choices made
  /// while another is saving are ignored, so they can't finish out of order.
  Future<void> _saving(
    Future<void> Function() save,
    OnboardingState Function(OnboardingState) apply,
  ) async {
    if (value.busy) return;
    emitIfOpen(value.copyWith(busy: true));
    try {
      await save();
      emitIfOpen(apply(value));
    } finally {
      emitIfOpen(value.copyWith(busy: false));
    }
  }
}
