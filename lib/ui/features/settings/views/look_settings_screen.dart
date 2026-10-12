import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/app_theme_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/choice_setting_tile.dart';
import '../../../core/widgets/confirm_then_save.dart';
import '../../../core/widgets/save_error.dart';
import '../view_models/settings_cubit.dart';
import 'customize_tiles_screen.dart';
import 'theme_color_dialog.dart';

/// Settings → Look: theme, theme colour, tile shapes and Restore default look,
/// the rows of the former Settings list, moved with their behaviour unchanged.
/// Every change applies at once.
class LookSettingsScreen extends StatelessWidget {
  const LookSettingsScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  Future<void> _pickThemeColor(
    BuildContext context,
    AppSettings settings,
  ) async {
    final choice = await showThemeColorDialog(
      context,
      current: settings.themeSeed,
      wallpaperSeed: dependencies.wallpaperSeed,
    );
    if (choice == null || !context.mounted) return;
    final cubit = context.read<SettingsCubit>();
    await saveOrShowError(context, () => cubit.setThemeSeed(choice.seed));
  }

  Future<void> _restoreDefaultLook(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    await confirmThenSave(
      context,
      title: l10n.restoreDefaultLookTitle,
      message: l10n.restoreDefaultLookMessage,
      confirmLabel: l10n.restore,
      action: cubit.restoreDefaultLook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLook)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => ListView(
          children: [
            ChoiceSettingTile<AppThemeMode>(
              icon: Icons.brightness_6_outlined,
              title: l10n.settingTheme,
              values: AppThemeMode.values,
              current: settings.theme,
              label: (theme) => themeModeName(l10n, theme),
              onSave: context.read<SettingsCubit>().setTheme,
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.settingThemeColor),
              subtitle: Text(
                themeColorName(
                  l10n,
                  seed: settings.themeSeed,
                  wallpaperSeed: dependencies.wallpaperSeed,
                ),
              ),
              onTap: () => _pickThemeColor(context, settings),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: Text(l10n.settingCustomizeTiles),
              subtitle: Text(l10n.settingCustomizeTilesSubtitle),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomizeTilesScreen(dependencies: dependencies),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(l10n.restoreDefaultLook),
              subtitle: Text(l10n.restoreDefaultLookSubtitle),
              onTap: () => _restoreDefaultLook(context),
            ),
          ],
        ),
      ),
    );
  }
}

String themeModeName(AppLocalizations l10n, AppThemeMode theme) =>
    switch (theme) {
      AppThemeMode.system => l10n.themeSystem,
      AppThemeMode.light => l10n.themeLight,
      AppThemeMode.dark => l10n.themeDark,
    };
