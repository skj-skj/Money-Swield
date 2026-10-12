import 'package:material_ui/material_ui.dart';

/// Restarts everything below `MaterialApp` after a restore swapped the database
/// file. Every repository holds the closed connection and every screen holds
/// repositories, so patching them one by one would miss something; rebuilding
/// the tree can't. What Home says once after a restart that followed a restore:
/// "Backup restored", that its settings were missing or unreadable (so it was
/// restored with default settings), or that some photos couldn't be restored
/// and show as missing.
class RestoreNotice {
  const RestoreNotice({this.settingsReset = false, this.failedPhotos = 0});

  final bool settingsReset;
  final int failedPhotos;
}

class AppRestartController {
  AppRestartController(this._restart);

  final void Function() _restart;

  RestoreNotice? _notice;

  /// Runs migrations and startup again on a fresh tree. [notice] is what
  /// Home says once after it.
  void restart({RestoreNotice? notice}) {
    // Set on every restart, so a notice nobody read can't show up after a
    // later, unrelated one.
    _notice = notice;
    _restart();
  }

  /// The notice once after a restart that followed a restore, then null.
  RestoreNotice? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }
}

/// Gives the widgets below it the [AppRestartController].
class AppRestart extends InheritedWidget {
  const AppRestart({super.key, required this.controller, required super.child});

  final AppRestartController controller;

  /// The controller, or null outside an [AppRestart] (some widget tests).
  /// Doesn't make [context] depend on it: the controller never changes.
  static AppRestartController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppRestart>()?.controller;

  static AppRestartController of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(AppRestart oldWidget) =>
      controller != oldWidget.controller;
}
