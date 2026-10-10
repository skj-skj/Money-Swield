import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../l10n/app_localizations.dart';
import '../../categories/views/category_list_screen.dart';
import '../../events/views/event_list_screen.dart';
import '../../payment_methods/views/payment_method_list_screen.dart';
import '../../recurring/views/recurring_list_screen.dart';
import '../view_models/manage_cubit.dart';

/// The Manage tab: categories, events, payment methods and recurring
/// items, with counts.
class ManageScreen extends StatefulWidget {
  const ManageScreen({
    super.key,
    required this.dependencies,
    this.isVisible = true,
  });

  final AppDependencies dependencies;

  /// Whether this tab is the one shown. The shell keeps it alive while
  /// hidden, so its counts are read again when it comes back: a repeating
  /// expense saved on Home left "None running" (Oppo, phase-7a.md §12a).
  final bool isVisible;

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  late final ManageCubit _cubit = ManageCubit(
    categories: widget.dependencies.categories,
    events: widget.dependencies.events,
    paymentMethods: widget.dependencies.paymentMethods,
    recurring: widget.dependencies.recurring,
  )..load();

  @override
  void didUpdateWidget(ManageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _cubit.load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = widget.dependencies;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navManage)),
      body: BlocSignalBuilder<ManageCubit, ManageCounts?>(
        bloc: _cubit,
        builder: (context, counts) => ListView(
          children: [
            _ManageTile(
              icon: Icons.category_outlined,
              title: l10n.categoriesTitle,
              count: counts?.categories,
              onTap: () =>
                  _open(CategoryListScreen(repository: deps.categories)),
            ),
            _ManageTile(
              icon: Icons.event_outlined,
              title: l10n.eventsTitle,
              count: counts?.events,
              onTap: () => _open(EventListScreen(repository: deps.events)),
            ),
            _ManageTile(
              icon: Icons.payments_outlined,
              title: l10n.paymentMethodsTitle,
              count: counts?.paymentMethods,
              onTap: () => _open(
                PaymentMethodListScreen(repository: deps.paymentMethods),
              ),
            ),
            _ManageTile(
              key: const ValueKey('manageRecurring'),
              icon: Icons.repeat,
              title: l10n.recurringTitle,
              count: null,
              countText: switch (counts) {
                final c? => l10n.recurringRunning(c.recurring),
                null => null,
              },
              onTap: () => _open(RecurringListScreen(dependencies: deps)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
    this.countText,
  });

  final IconData icon;
  final String title;
  final int? count;

  /// Shown under the title instead of [count]: "3 running". Not trailing:
  /// a trailing text that long took the whole tile at font 2.0 (Spanish
  /// "Ninguno activo"; phase-7a.md §12a).
  final String? countText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final countText = this.countText;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: countText == null ? null : Text(countText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count != null)
            Text('$count', style: Theme.of(context).textTheme.bodyLarge),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
