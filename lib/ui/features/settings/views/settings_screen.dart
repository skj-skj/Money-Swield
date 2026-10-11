import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/byte_size_text.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/languages.dart';
import '../../../core/widgets/choice_dialog.dart';
import '../../../core/widgets/reel_card.dart';
import '../../../core/widgets/save_error.dart';
import '../../backup/views/backup_screen.dart';
import '../../backup/views/backup_texts.dart';
import '../../bin/views/bin_screen.dart';
import '../../payment_methods/view_models/payment_method_list_cubit.dart';
import '../../sms/view_models/sms_cubit.dart';
import '../view_models/settings_cubit.dart';
import '../view_models/settings_summary_cubit.dart';
import 'defaults_settings_screen.dart';
import 'home_settings_screen.dart';
import 'look_settings_screen.dart';
import 'photo_settings_screen.dart';
import 'sms_settings_screen.dart';
import 'theme_color_dialog.dart';

/// The Settings tab (phase-5.md §8.5, P5-16): a two-column grid of tiles,
/// each with an icon, a title and one muted summary line. Language opens
/// its dialog; the others open their screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.dependencies,
    required this.isVisible,
    this.sms,
  });

  final AppDependencies dependencies;

  /// The app-level SMS state (phase-9a.md §8.5): the SMS tile shows only in
  /// a build with SMS. Null: no tile.
  final SmsCubit? sms;

  /// Whether this tab is the one shown. The shell keeps the tab alive while
  /// hidden, and payment methods may be renamed meanwhile on the Manage tab,
  /// so they are reloaded each time the tab comes back.
  final bool isVisible;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// For the Defaults tile's summary.
  PaymentMethodListCubit? _paymentMethodList;
  AppLocalizations? _l10n;

  /// The Backup & restore and Photos tiles' summaries. Not part of the
  /// settings cubit (a backup mustn't rebuild the app), so read by their own
  /// cubit (phase-6.md R15): on start, when the tab comes back, and when a
  /// sub-screen closes.
  late final _summary = SettingsSummaryCubit(
    backups: widget.dependencies.backups,
    expenses: widget.dependencies.expenses,
  )..load();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The list is sorted by name in one language, so it is rebuilt when
    // the user switches language on this very screen.
    final l10n = AppLocalizations.of(context);
    if (l10n == _l10n) return;
    _l10n = l10n;
    _paymentMethodList?.close();
    _paymentMethodList = PaymentMethodListCubit(
      repository: widget.dependencies.paymentMethods,
      l10n: l10n,
    )..load();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _paymentMethodList?.load();
      _summary.load();
    }
  }

  @override
  void dispose() {
    _paymentMethodList?.close();
    _summary.close();
    super.dispose();
  }

  Future<void> _pickLanguage(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final locales = [null, for (final code in languageNames.keys) Locale(code)];
    final index = await showChoiceDialog(
      context,
      title: l10n.settingLanguage,
      options: [
        Text(l10n.languageSystem),
        for (final name in languageNames.values) Text(name),
      ],
      selectedIndex: locales.indexWhere(
        (l) => l?.languageCode == settings.locale?.languageCode,
      ),
    );
    if (index == null || !mounted) return;
    final cubit = context.read<SettingsCubit>();
    await saveOrShowError(context, () => cubit.setLocale(locales[index]));
  }

  /// The tick both cards' reels give at each face (its own tile since the
  /// owner's change of 2026-10-11; it was in Settings → Home). Felt once
  /// when picked, so the choice can be judged.
  Future<void> _pickVibration(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final index = await showChoiceDialog(
      context,
      title: l10n.settingCardHaptics,
      options: [
        for (final haptics in CardHaptics.values)
          Text(cardHapticsName(l10n, haptics)),
      ],
      selectedIndex: settings.trendCardHaptics.index,
    );
    if (index == null || !mounted) return;
    final haptics = CardHaptics.values[index];
    final cubit = context.read<SettingsCubit>();
    final saved = await saveOrShowError(
      context,
      () => cubit.setTrendCardHaptics(haptics),
    );
    if (saved) cardHaptic(haptics);
  }

  /// Opens [screen]; back here, the summaries are read again (a payment
  /// method renamed, a backup saved).
  Future<void> _open(Widget screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    await _paymentMethodList?.load();
    await _summary.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dependencies = widget.dependencies;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) =>
            BlocSignalBuilder<SettingsSummaryCubit, SettingsSummary>(
              bloc: _summary,
              builder: (context, summary) =>
                  BlocSignalBuilder<
                    PaymentMethodListCubit,
                    PaymentMethodListState
                  >(
                    bloc: _paymentMethodList!,
                    builder: (context, methods) => _withSms((sms) {
                      final tiles = [
                        _SettingsTile(
                          key: const ValueKey('settingsLanguage'),
                          icon: Icons.language,
                          title: l10n.settingLanguage,
                          summary:
                              languageNames[settings.locale?.languageCode] ??
                              l10n.languageSystem,
                          onTap: () => _pickLanguage(settings),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsLook'),
                          icon: Icons.palette_outlined,
                          title: l10n.settingsLook,
                          summary: l10n.settingsTileSummary(
                            themeModeName(l10n, settings.theme),
                            themeColorName(
                              l10n,
                              seed: settings.themeSeed,
                              wallpaperSeed: dependencies.wallpaperSeed,
                            ),
                          ),
                          onTap: () => _open(
                            LookSettingsScreen(dependencies: dependencies),
                          ),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsHome'),
                          icon: Icons.insights,
                          title: l10n.settingsHome,
                          summary: _homeSummary(l10n, settings),
                          onTap: () => _open(
                            HomeSettingsScreen(dependencies: dependencies),
                          ),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsVibration'),
                          icon: Icons.vibration,
                          title: l10n.settingCardHaptics,
                          summary: cardHapticsName(
                            l10n,
                            settings.trendCardHaptics,
                          ),
                          onTap: () => _pickVibration(settings),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsDefaults'),
                          icon: Icons.tune,
                          title: l10n.settingsDefaults,
                          summary: _defaultsSummary(l10n, settings, methods),
                          onTap: () => _open(
                            DefaultsSettingsScreen(dependencies: dependencies),
                          ),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsBackup'),
                          icon: Icons.backup_outlined,
                          title: l10n.backupAndRestore,
                          summary: lastBackupText(
                            l10n,
                            summary.lastBackupAt,
                            dependencies.now(),
                          ),
                          onTap: () => _open(
                            BackupScreen(
                              dependencies: dependencies,
                              runningSmsScan: widget.sms?.runningScan,
                            ),
                          ),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsPhotos'),
                          icon: Icons.photo_library_outlined,
                          title: l10n.photos,
                          summary: _photosSummary(l10n, settings, summary),
                          onTap: () =>
                              _open(PhotoSettingsScreen(summary: _summary)),
                        ),
                        _SettingsTile(
                          key: const ValueKey('settingsBin'),
                          icon: Icons.delete_outline,
                          title: l10n.bin,
                          summary: l10n.binTileSummary,
                          onTap: () =>
                              _open(BinScreen(dependencies: dependencies)),
                        ),
                        ?_smsTile(l10n, sms),
                      ];
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (var i = 0; i < tiles.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              // Both tiles of a row as tall as the taller one; an
                              // odd count leaves the last tile at the left.
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: tiles[i]),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: i + 1 < tiles.length
                                          ? tiles[i + 1]
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
            ),
      ),
    );
  }

  /// [build] with what the SMS tile shows, rebuilt only when that changes
  /// (a scan starting or ending doesn't); null without SMS or in a build
  /// without it.
  Widget _withSms(Widget Function(_SmsTileData? sms) build) =>
      switch (widget.sms) {
        final sms? => BlocSignalSelector<SmsCubit, SmsState, _SmsTileData?>(
          bloc: sms,
          selector: (state) => state.isBuilt
              ? (
                  on: state.availability != SmsAvailability.off,
                  count: state.pendingCount,
                )
              : null,
          builder: (context, data) => build(data),
        ),
        null => build(null),
      };

  /// The SMS tile when the build has SMS (§8.5): "On · 3 waiting" /
  /// "Off".
  Widget? _smsTile(AppLocalizations l10n, _SmsTileData? data) {
    final sms = widget.sms;
    if (sms == null || data == null) return null;
    return _SettingsTile(
      key: const ValueKey('settingsSms'),
      icon: Icons.sms_outlined,
      title: l10n.smsTile,
      summary: data.on ? l10n.smsTileOn(data.count) : l10n.smsTileOff,
      onTap: () => _open(SmsSettingsScreen(sms: sms)),
    );
  }

  /// "Camera 1080p · Gallery 1080p · 1.2 GB" (phase-6.md §8.6).
  String _photosSummary(
    AppLocalizations l10n,
    AppSettings settings,
    SettingsSummary summary,
  ) {
    final sizes = l10n.settingsTileSummary(
      l10n.photosTileCamera(
        photoSizeShortName(l10n, settings.cameraPhotos.size),
      ),
      l10n.photosTileGallery(
        photoSizeShortName(l10n, settings.galleryPhotos.size),
      ),
    );
    final bytes = summary.photoBytes;
    return bytes == null || summary.photoCount == 0
        ? sizes
        : l10n.settingsTileSummary(
            sizes,
            byteSizeText(l10n, formattingLocaleOf(context), bytes),
          );
  }

  /// "Smooth line, filled · Locked · Monday".
  String _homeSummary(AppLocalizations l10n, AppSettings settings) =>
      l10n.settingsTileSummary(
        l10n.settingsTileSummary(
          chartStyleName(l10n, settings.trendChartStyle),
          switch (settings.trendCardPosition) {
            TrendCardPosition.locked => l10n.trendCardLockedShort,
            TrendCardPosition.scrolls => l10n.trendCardScrollsShort,
          },
        ),
        weekStartName(dateLocaleOf(context), settings.weekStart),
      );

  /// "INR · 💵 Cash".
  String _defaultsSummary(
    AppLocalizations l10n,
    AppSettings settings,
    PaymentMethodListState methods,
  ) {
    final method = findPaymentMethod(methods, settings.defaultPaymentMethodId);
    if (method == null) return settings.defaultCurrency;
    return l10n.settingsTileSummary(
      settings.defaultCurrency,
      paymentMethodLabel(l10n, method),
    );
  }
}

/// One tile of the grid: an icon, a title and a muted summary.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                // Long names (a user's payment method) are cut, so a tile
                // never runs away; the full value is on its screen.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the SMS tile shows: on (or waiting for the permission) or off, and
/// how many suggestions wait.
typedef _SmsTileData = ({bool on, int count});
