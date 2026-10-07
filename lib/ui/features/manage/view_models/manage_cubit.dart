import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../core/emit_if_open.dart';

/// How many rows each list on the Manage tab has.
typedef ManageCounts = ({int categories, int events, int paymentMethods});

/// The counts shown on the Manage tab. Null until loaded, or if loading
/// failed (the tab then shows no counts; the lists still open).
class ManageCubit extends CubitSignal<ManageCounts?>
    with EmitIfOpen<ManageCounts?> {
  ManageCubit({
    required this._categories,
    required this._events,
    required this._paymentMethods,
  }) : super(initialState: null);

  final CategoryRepository _categories;
  final EventRepository _events;
  final PaymentMethodRepository _paymentMethods;

  /// Loads (or reloads, after a list was edited) the counts.
  Future<void> load() async {
    try {
      final counts = (
        categories: (await _categories.all()).length,
        events: (await _events.all()).length,
        paymentMethods: (await _paymentMethods.all()).length,
      );
      emitIfOpen(counts);
    } catch (error, stackTrace) {
      // The counts are a convenience: keep showing the last ones and only
      // log the error. (No BlocSignalObserver is installed, so addError
      // would drop it silently.)
      debugPrint('Loading the Manage counts failed: $error\n$stackTrace');
    }
  }
}
