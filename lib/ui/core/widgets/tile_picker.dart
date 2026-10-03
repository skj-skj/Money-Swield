import 'package:material_ui/material_ui.dart';

import '../../../domain/models/item_shape.dart';
import '../../../l10n/app_localizations.dart';
import '../item_shapes.dart';
import '../picker_order.dart';
import 'picker_results_screen.dart';

/// The category / event picker of phase-2.md §6.2, also used by the move
/// dialog (§10.1). One shared widget, so every use looks and behaves the
/// same; the uses differ only in the items, single vs. multi select, and
/// whether **New** (and **None**) is offered.
///
/// Normal state: the [tiles] as 4 + 4, with Search and New in a narrow
/// column on the right. Search state: the first row becomes a search bar,
/// the second shows the first 4 matches, and New becomes ⋯ (all the other
/// matches on their own screen).
///
/// Switching between them is animated: the Search button itself widens
/// into the search bar, its fill fading to the field's background, while
/// the tiles shrink away and the matches grow in.
///
/// Whether it is searching belongs to the parent ([searching],
/// [onSearchingChanged]), so the parent's back handling can close it. The
/// query and the animation stay in here.
class TilePicker extends StatefulWidget {
  const TilePicker({
    super.key,
    required this.items,
    required this.tiles,
    required this.selectedIds,
    required this.multiSelect,
    required this.searching,
    required this.onSearchingChanged,
    required this.onTap,
    required this.searchHint,
    required this.allTitle,
    this.tileShape = ItemShape.rounded,
    this.buttonShape = ItemShape.rounded,
    this.emptyText,
    this.newLabel,
    this.onNew,
    this.noneLabel,
    this.onNone,
  });

  /// Every item that can be picked, most popular first. Search runs on it.
  final List<PickerItem> items;

  /// The tiles of the normal state, see `pickerTiles`: 8, or 7 with a
  /// [noneLabel] tile taking the first slot.
  final List<PickerItem> tiles;

  final Set<int> selectedIds;

  /// Tiles toggle (events) instead of selecting one (categories). Also
  /// decides whether tapping a search result leaves search mode.
  final bool multiSelect;

  final bool searching;
  final ValueChanged<bool> onSearchingChanged;

  /// Selects (single) or toggles (multi) the item with this id.
  final ValueChanged<int> onTap;

  /// e.g. "Search events…".
  final String searchHint;

  /// The ⋯ screen's title for an empty query, e.g. "All events".
  final String allTitle;

  /// Shape of the tiles, and of the buttons and search bar (Settings).
  final ItemShape tileShape;
  final ItemShape buttonShape;

  /// Shown in place of the tiles when there are no items at all.
  final String? emptyText;

  /// e.g. "New event". Shown with [onNew].
  final String? newLabel;

  /// Opens the create form with the name prefilled, and returns whether
  /// something was created (and selected by the caller). Null hides New.
  final Future<bool> Function(String initialName)? onNew;

  /// A "None" tile in the first slot, selected while nothing is; tapping it
  /// calls [onNone] to clear the selection. For multi-select pickers
  /// (events), where "no event" is a choice of its own.
  final String? noneLabel;
  final VoidCallback? onNone;

  static const tileHeight = 64.0;
  static const _gap = 8.0;
  static const _actionWidth = 48.0;
  static const _noneId = -1;

  /// Emoji of the None tile.
  static const noneEmoji = '🚫';

  @override
  State<TilePicker> createState() => _TilePickerState();
}

class _TilePickerState extends State<TilePicker>
    with SingleTickerProviderStateMixin {
  final _query = TextEditingController();
  final _searchFocus = FocusNode();

  late final AnimationController _search = AnimationController(
    vsync: this,
    value: widget.searching ? 1 : 0,
  )..addStatusListener(_onSearchStatus);

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _search.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    if (widget.searching && _search.isCompleted) _focusSearchAfterBuild();
  }

  @override
  void didUpdateWidget(TilePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching == oldWidget.searching) return;
    // The query is not kept between searches.
    _query.clear();
    if (widget.searching) {
      _search.forward();
    } else {
      _searchFocus.unfocus();
      _search.reverse();
    }
  }

  /// Focus goes to the field once it has fully opened. `autofocus` isn't
  /// enough: it does nothing while another field (e.g. the amount just
  /// typed) still has focus, and typing then went nowhere (found on a
  /// device).
  void _onSearchStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.searching) {
      _searchFocus.requestFocus();
    }
  }

  void _focusSearchAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.searching) _searchFocus.requestFocus();
    });
  }

  // The bar's border follows the focus.
  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _search.dispose();
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PickerItem> get _results => searchPickerItems(widget.items, _query.text);

  void _tapResult(int id) {
    widget.onTap(id);
    if (!widget.multiSelect) widget.onSearchingChanged(false);
  }

  Future<void> _openMore() async {
    final query = _query.text.trim();
    final onNew = widget.onNew;
    final leaveSearch = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PickerResultsScreen(
          title: query.isEmpty ? widget.allTitle : query,
          items: _results.skip(4).toList(),
          selectedIds: widget.selectedIds,
          multiSelect: widget.multiSelect,
          onTap: widget.onTap,
          newLabel: widget.newLabel,
          onNew: onNew == null ? null : () => onNew(query),
        ),
      ),
    );
    if (leaveSearch ?? false) widget.onSearchingChanged(false);
  }

  Future<void> _new() async {
    await widget.onNew?.call('');
  }

  /// The normal-state tiles, with the None tile first when there is one.
  List<PickerItem> get _gridTiles {
    final noneLabel = widget.noneLabel;
    return [
      if (noneLabel != null)
        PickerItem(
          id: TilePicker._noneId,
          emoji: TilePicker.noneEmoji,
          name: noneLabel,
        ),
      ...widget.tiles,
    ];
  }

  void _tapTile(int id) {
    if (id == TilePicker._noneId) {
      widget.onNone?.call();
    } else {
      widget.onTap(id);
    }
  }

  bool _isSelected(int id) => id == TilePicker._noneId
      ? widget.selectedIds.isEmpty
      : widget.selectedIds.contains(id);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _search,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) =>
            _build(context, constraints.maxWidth),
      ),
    );
  }

  Widget _build(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final t = _search.value;
    // The bar widens over the whole animation; the old tiles shrink away in
    // the first half and the matches grow in during the second.
    final widen = Curves.easeInOutCubic.transform(t);
    final shrinkOld = 1 - Curves.easeIn.transform((t * 2).clamp(0.0, 1.0));
    final growNew = Curves.easeOut.transform((t * 2 - 1).clamp(0.0, 1.0));

    const actionWidth = TilePicker._actionWidth;
    const gap = TilePicker._gap;
    const rowHeight = TilePicker.tileHeight;
    final gridWidth = width - actionWidth - gap;
    final buttonHeight = widget.buttonShape == ItemShape.circle
        ? actionWidth
        : rowHeight;

    final grid = _gridTiles;
    final emptyText = widget.emptyText;
    final showEmpty = grid.isEmpty && emptyText != null;

    return SizedBox(
      height: rowHeight * 2 + gap,
      child: Stack(
        children: [
          // Normal state: two rows of tiles (or "No categories yet").
          if (shrinkOld > 0)
            Positioned(
              left: 0,
              top: 0,
              width: gridWidth,
              height: rowHeight * 2 + gap,
              child: showEmpty
                  ? Opacity(
                      opacity: shrinkOld,
                      child: Center(child: Text(emptyText)),
                    )
                  : Column(
                      children: [
                        _row(grid.take(4).toList(), _tapTile, shrinkOld),
                        const SizedBox(height: gap),
                        _row(
                          grid.skip(4).take(4).toList(),
                          _tapTile,
                          shrinkOld,
                        ),
                      ],
                    ),
            ),
          // Search state: the first matches in the second row.
          if (growNew > 0)
            Positioned(
              left: 0,
              top: rowHeight + gap,
              width: gridWidth,
              height: rowHeight,
              child: _row(_results.take(4).toList(), _tapResult, growNew),
            ),
          // New shrinking away, then ⋯ growing in.
          Positioned(
            right: 0,
            top: rowHeight + gap,
            width: actionWidth,
            height: rowHeight,
            child: shrinkOld > 0
                ? (widget.onNew == null
                      ? const SizedBox.shrink()
                      : _scaled(
                          shrinkOld,
                          _ActionButton(
                            icon: Icons.add,
                            tooltip: widget.newLabel ?? '',
                            shape: widget.buttonShape,
                            onPressed: _new,
                          ),
                        ))
                : _scaled(
                    growNew,
                    _ActionButton(
                      icon: Icons.more_horiz,
                      tooltip: l10n.moreResults,
                      shape: widget.buttonShape,
                      onPressed: _openMore,
                    ),
                  ),
          ),
          // The Search button, widening into the search bar over row one.
          Positioned(
            right: 0,
            top: (rowHeight - buttonHeight) / 2,
            height: buttonHeight,
            width: actionWidth + (width - actionWidth) * widen,
            child: _SearchBar(
              progress: widen,
              shape: widget.buttonShape,
              height: buttonHeight,
              controller: _query,
              focusNode: _searchFocus,
              hint: widget.searchHint,
              onOpen: () => widget.onSearchingChanged(true),
              onClose: () => widget.onSearchingChanged(false),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  /// One row of 4 slots, each tile shrunk to [scale]; missing items leave
  /// their slot empty, so the grid keeps its shape.
  Widget _row(List<PickerItem> items, ValueChanged<int> onTap, double scale) {
    return SizedBox(
      height: TilePicker.tileHeight,
      child: Row(
        children: [
          for (var slot = 0; slot < 4; slot++) ...[
            if (slot > 0) const SizedBox(width: TilePicker._gap),
            Expanded(
              child: slot < items.length
                  ? _scaled(
                      scale,
                      _Tile(
                        item: items[slot],
                        selected: _isSelected(items[slot].id),
                        showCheck:
                            widget.multiSelect &&
                            items[slot].id != TilePicker._noneId,
                        shape: widget.tileShape,
                        onTap: () => onTap(items[slot].id),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _scaled(double scale, Widget child) =>
      scale >= 1 ? child : Transform.scale(scale: scale, child: child);
}

/// The Search button and the search bar are one widget, so the button can
/// grow into the bar: at [progress] 0 it is the button (tap to open), at 1
/// the bar (field and ✕). In between its fill fades from the button's color
/// to the field's background and the bar's border fades in.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.progress,
    required this.shape,
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onOpen,
    required this.onClose,
    required this.onChanged,
  });

  final double progress;
  final ItemShape shape;
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final closed = progress == 0;
    final buttonColor = colors.secondaryContainer;
    final focused = focusNode.hasFocus;
    final borderColor = focused ? colors.primary : colors.outline;
    // The field appears once the bar is wide enough to hold it.
    final fieldOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);

    final bar = Material(
      color: Color.lerp(
        buttonColor,
        buttonColor.withValues(alpha: 0),
        progress,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeRadius(shape, height)),
        side: BorderSide(
          color: borderColor.withValues(alpha: borderColor.a * progress),
          width: focused ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: closed ? onOpen : null,
        child: Row(
          children: [
            // At the button's width (48) this centers the icon; it then
            // stays at the bar's start as the bar widens.
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              color: Color.lerp(
                colors.onSecondaryContainer,
                colors.onSurfaceVariant,
                progress,
              ),
            ),
            if (fieldOpacity > 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: fieldOpacity,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: onChanged,
                    // Scroll far enough that the matches under the bar stay
                    // above the keyboard, not just the bar itself.
                    scrollPadding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + TilePicker.tileHeight + TilePicker._gap,
                    ),
                    decoration: InputDecoration.collapsed(hintText: hint),
                  ),
                ),
              ),
              Opacity(
                opacity: fieldOpacity,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.closeSearch,
                  onPressed: onClose,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return closed ? Tooltip(message: l10n.search, child: bar) : bar;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.item,
    required this.selected,
    required this.showCheck,
    required this.shape,
    required this.onTap,
  });

  final PickerItem item;
  final bool selected;

  /// Multi-select tiles mark selection with a check as well as the color.
  final bool showCheck;

  final ItemShape shape;
  final VoidCallback onTap;

  /// Diameter of a circle tile's emoji disc; the name goes under it.
  static const _circleSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fill = selected
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final emoji = Text(item.emoji, style: const TextStyle(fontSize: 22));
    final check = Icon(Icons.check_circle, size: 16, color: colors.primary);
    final name = Text(
      item.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: !selected
            ? null
            : shape == ItemShape.circle
            ? colors.primary
            : colors.onPrimaryContainer,
      ),
    );

    if (shape == ItemShape.circle) {
      // A disc with the emoji, the name under it (it wouldn't fit inside).
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox.square(
                    dimension: _circleSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fill,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: emoji),
                    ),
                  ),
                  if (showCheck && selected)
                    PositionedDirectional(top: -2, end: -2, child: check),
                ],
              ),
              const SizedBox(height: 2),
              name,
            ],
          ),
        ),
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(
          shapeRadius(shape, TilePicker.tileHeight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // StackFit.expand gives the column the tile's full width, so the
          // emoji and name are centered in it (a loose Stack left them at
          // the start, found on a device).
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [emoji, const SizedBox(height: 2), name],
                ),
              ),
              if (showCheck && selected)
                PositionedDirectional(top: 2, end: 2, child: check),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.shape,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final ItemShape shape;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final height = shape == ItemShape.circle
        ? TilePicker._actionWidth
        : TilePicker.tileHeight;
    return Center(
      child: SizedBox(
        height: height,
        width: TilePicker._actionWidth,
        child: IconButton.filledTonal(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(shapeRadius(shape, height)),
            ),
          ),
        ),
      ),
    );
  }
}
