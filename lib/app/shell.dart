import 'package:material_ui/material_ui.dart';

import '../domain/models/recurring_item.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/widgets/back_guard.dart';
import '../ui/features/home/views/home_screen.dart';
import '../ui/features/manage/views/manage_screen.dart';
import '../ui/features/settings/views/settings_screen.dart';
import 'app_dependencies.dart';
import 'app_restart.dart';

/// The app after onboarding: Home · Manage · Settings in a navigation bar.
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

class _ShellState extends State<Shell> {
  static const _home = 0;
  static const _settings = 2;

  int _index = _home;

  /// Read once: the notice is cleared as it's read, and on the next
  /// restart.
  late final RestoreNotice? _restoreNotice = AppRestart.maybeOf(context)
      ?.takeNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = widget.dependencies;
    return BackGuard(
      intercept: _index != _home,
      onBack: () => setState(() => _index = _home),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              dependencies: deps,
              isVisible: _index == _home,
              restoreNotice: _restoreNotice,
              recurringReport: widget.recurringReport,
            ),
            ManageScreen(dependencies: deps, isVisible: _index == 1),
            SettingsScreen(dependencies: deps, isVisible: _index == _settings),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
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
