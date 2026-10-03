import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/item_shape.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/item_shapes.dart';
import '../../../core/picker_order.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/tile_picker.dart';
import '../view_models/settings_cubit.dart';
import '../view_models/tile_preview_cubit.dart';

/// Settings → Customize tiles: the shape of the picker tiles and of their
/// buttons, each picked from three options shown at once, above a preview
/// of the Add expense pickers with the user's own categories and events.
/// Every pick applies at once.
class CustomizeTilesScreen extends StatefulWidget {
  const CustomizeTilesScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<CustomizeTilesScreen> createState() => _CustomizeTilesScreenState();
}

class _CustomizeTilesScreenState extends State<CustomizeTilesScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  TilePreviewCubit? _preview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preview ??= TilePreviewCubit(
      categories: widget.dependencies.categories,
      events: widget.dependencies.events,
      l10n: AppLocalizations.of(context),
    )..load();
  }

  @override
  void dispose() {
    _preview?.close();
    super.dispose();
  }

  SettingsCubit get _settings => context.read<SettingsCubit>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingCustomizeTiles)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        buildWhen: (previous, current) =>
            previous.tileShape != current.tileShape ||
            previous.buttonShape != current.buttonShape,
        builder: (context, settings) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _ShapeChoice(
              title: l10n.settingTileShape,
              selected: settings.tileShape,
              onChanged: (shape) =>
                  saveOrShowError(context, () => _settings.setTileShape(shape)),
            ),
            const SizedBox(height: 24),
            _ShapeChoice(
              title: l10n.settingButtonShape,
              selected: settings.buttonShape,
              onChanged: (shape) => saveOrShowError(
                context,
                () => _settings.setButtonShape(shape),
              ),
            ),
            const SizedBox(height: 32),
            Text(l10n.preview, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            BlocSignalBuilder<TilePreviewCubit, TilePreviewItems?>(
              bloc: _preview!,
              builder: (context, items) =>
                  _PickersPreview(settings: settings, items: items),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Add expense pickers as a picture: the real `TilePicker`, so it looks
/// exactly the same, but nothing in it reacts to taps (no selection, no
/// search, no animation) and screen readers skip it. It shows a fresh
/// form: no category picked, "None" for the events.
class _PickersPreview extends StatelessWidget {
  const _PickersPreview({required this.settings, required this.items});

  final AppSettings settings;
  final TilePreviewItems? items;

  static void _ignore(Object? _) {}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = items?.categories ?? const <PickerItem>[];
    final events = items?.events ?? const <PickerItem>[];
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.fieldCategory, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TilePicker(
              items: categories,
              tiles: pickerTiles(categories, const {}, multiSelect: false),
              selectedIds: const {},
              multiSelect: false,
              tileShape: settings.tileShape,
              buttonShape: settings.buttonShape,
              searching: false,
              onSearchingChanged: _ignore,
              onTap: _ignore,
              searchHint: l10n.searchCategories,
              allTitle: l10n.allCategories,
              emptyText: l10n.noCategoriesYet,
              newLabel: l10n.newCategory,
              // Shown so the New button appears; never called.
              onNew: (_) async => false,
            ),
            const SizedBox(height: 24),
            Text(l10n.fieldEvents, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TilePicker(
              items: events,
              tiles: pickerTiles(
                events,
                const {},
                multiSelect: true,
                size: pickerGridSize - 1,
              ),
              selectedIds: const {},
              multiSelect: true,
              tileShape: settings.tileShape,
              buttonShape: settings.buttonShape,
              noneLabel: l10n.noneEvent,
              onNone: () {},
              searching: false,
              onSearchingChanged: _ignore,
              onTap: _ignore,
              searchHint: l10n.searchEvents,
              allTitle: l10n.allEvents,
              newLabel: l10n.newEvent,
              onNew: (_) async => false,
            ),
          ],
        ),
      ),
    );
  }
}

/// The three shapes side by side, one tap to pick (no dropdown: there are
/// only three, so they all fit on screen at once).
class _ShapeChoice extends StatelessWidget {
  const _ShapeChoice({
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final ItemShape selected;
  final ValueChanged<ItemShape> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // Cards with the shape above its name, not a SegmentedButton: its
        // icon-beside-label layout broke "Rounded square" over three lines
        // on a phone (found on a device).
        // One height for the three, whichever label wraps.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, shape) in ItemShape.values.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ShapeOption(
                    label: shapeName(l10n, shape),
                    shape: shape,
                    selected: shape == selected,
                    onTap: () => onChanged(shape),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShapeOption extends StatelessWidget {
  const _ShapeOption({
    required this.label,
    required this.shape,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ItemShape shape;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShapePreview(shape),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? colors.onSecondaryContainer : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
