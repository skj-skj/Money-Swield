import 'package:material_ui/material_ui.dart';

import '../domain/models/recurring_item.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/widgets/back_guard.dart';
import '../ui/features/home/views/home_screen.dart';
import '../ui/features/manage/views/manage_screen.dart';
import '../ui/features/reports/views/report_screen.dart';
import '../ui/features/settings/views/settings_screen.dart';
import '../ui/features/sms/view_models/sms_cubit.dart';
import 'app_dependencies.dart';
import 'app_restart.dart';

/// The app after onboarding: Home · Reports · Manage · Settings in a
/// navigation bar (application-design §5, phase-8.md §8.1).
///
/// Tabs keep their state when switching (IndexedStack). Back on another tab
/// goes to Home; back on Home leaves the app.
class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.dependencies,
    this.recurringReport = GenerateReport.none,
  });

  final AppDependencies dependencies;

  /// What the recurring generator did at startup; Home says it.
  final GenerateReport recurringReport;

  @override
  State<Shell> createState() => _ShellState();
}

/// The tabs in bar order. An enum, not literal indexes: inserting a tab
/// shifted the numbers under the screens' `isVisible` (phase-8.md R1).
enum _Tab { home, reports, manage, settings }

class _ShellState extends State<Shell> {
  _Tab _tab = _Tab.home;

  /// Read once: the notice is cleared as it's read, and on the next
  /// restart.
  late final RestoreNotice? _restoreNotice = AppRestart.maybeOf(context)
      ?.takeNotice();

  /// SMS suggestions for the whole app (phase-9a.md §7.1): Home's icon,
  /// Settings → SMS and the backup's wait share it.
  late final SmsCubit _sms = SmsCubit(
    service: widget.dependencies.sms,
    scanner: widget.dependencies.smsScanner,
    repository: widget.dependencies.smsSuggestions,
    settings: widget.dependencies.settings,
    now: widget.dependencies.now,
  );

  /// Scans again when the app comes back to the front (at most once a
  /// minute, P9a-13).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _sms.resumed());
    // After the first frame (application-design §3 step 6): the scan reads
    // in the background and never delays Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sms.start();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sms.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = widget.dependencies;
    return BackGuard(
      intercept: _tab != _Tab.home,
      onBack: () => setState(() => _tab = _Tab.home),
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          // In _Tab's order.
          children: [
            HomeScreen(
              dependencies: deps,
              isVisible: _tab == _Tab.home,
              restoreNotice: _restoreNotice,
              recurringReport: widget.recurringReport,
              sms: _sms,
            ),
            ReportScreen(dependencies: deps, isVisible: _tab == _Tab.reports),
            ManageScreen(dependencies: deps, isVisible: _tab == _Tab.manage),
            SettingsScreen(
              dependencies: deps,
              isVisible: _tab == _Tab.settings,
              sms: _sms,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) =>
              setState(() => _tab = _Tab.values[index]),
          // In _Tab's order.
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: const Icon(Icons.pie_chart),
              label: l10n.navReports,
            ),
            NavigationDestination(
              icon: const Icon(Icons.folder_copy_outlined),
              selectedIcon: const Icon(Icons.folder_copy),
              label: l10n.navManage,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
