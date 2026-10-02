import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../l10n/app_localizations.dart';
import '../../categories/views/category_list_screen.dart';
import '../../events/views/event_list_screen.dart';
import '../../payment_methods/views/payment_method_list_screen.dart';
import '../view_models/manage_cubit.dart';

/// The Manage tab: categories, events and payment methods, with counts.
class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  late final ManageCubit _cubit = ManageCubit(
    categories: widget.dependencies.categories,
    events: widget.dependencies.events,
    paymentMethods: widget.dependencies.paymentMethods,
  )..load();

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
          ],
        ),
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
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
