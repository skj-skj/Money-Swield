import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';

/// What the payment methods screen shows. States don't override `==`, so
/// every emitted state reaches the screen.
sealed class PaymentMethodListState {
  const PaymentMethodListState();
}

final class PaymentMethodListLoading extends PaymentMethodListState {
  const PaymentMethodListLoading();
}

final class PaymentMethodListLoaded extends PaymentMethodListState {
  const PaymentMethodListLoaded(this.paymentMethods);

  /// Sorted by display name.
  final List<PaymentMethod> paymentMethods;
}

final class PaymentMethodListFailed extends PaymentMethodListState {
  const PaymentMethodListFailed(this.error);

  final Object error;
}

/// Loads the payment methods, sorted by display name in the current
/// language. Used by the payment methods screen and the Settings screen.
class PaymentMethodListCubit extends CubitSignal<PaymentMethodListState> {
  PaymentMethodListCubit({required this._repository, required this._l10n})
    : super(initialState: const PaymentMethodListLoading());

  final PaymentMethodRepository _repository;

  /// The language the names are sorted in. Recreate the cubit when the
  /// language changes.
  final AppLocalizations _l10n;

  /// Loads (or reloads) the list. A reload keeps showing the old list until
  /// the new one is ready, so the screen doesn't flash a spinner.
  Future<void> load() async {
    try {
      final methods = await _repository.all();
      methods.sort((a, b) {
        final byName = compareNames(
          paymentMethodName(_l10n, a),
          paymentMethodName(_l10n, b),
        );
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
      if (!isClosed) emit(PaymentMethodListLoaded(methods));
    } catch (error) {
      if (!isClosed) emit(PaymentMethodListFailed(error));
    }
  }
}
