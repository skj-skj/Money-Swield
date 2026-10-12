import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../domain/models/item_shape.dart';
import '../../../l10n/app_localizations.dart';
import '../item_shapes.dart';
import '../picker_order.dart';
import 'picker_results_screen.dart';

/// The category / event picker of the Add form, also used by the move
/// dialog. One shared widget, so every use looks and behaves the same; the uses
/// differ only in the items, single vs. multi select, and whether **New** (and
/// **None**) is offered.
///
/// Normal state: every item in two rows that scroll sideways together,
/// filled column by column (1 top, 2 under it, 3 top …), so the most
/// popular are at the start of both rows; 4 columns show at a time (2 with
/// a large font, see `_visibleColumns`). Search
/// and New stay in a narrow column on the right. Search state: the first
/// row becomes a search bar, the second shows the matches in one row that
/// scrolls on its own, and New becomes ⋯ (the matches after the first 4 on
/// their own screen). (owner, 2026-10-04: was a fixed 4 + 4 of the top 8.)
///
/// Tiles keep their place when picked; instead the rows scroll to a
/// selected tile that changed while off screen (an edited expense, a pick
/// from search, ⋯ or New, a title suggestion). Moving it to the front, as
/// the fixed grid did, would pull it from under the thumb.
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

  /// Every item that can be picked, most popular first: the tiles of the
  /// normal state, and what search runs on.
  final List<PickerItem> items;

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

  /// A "None" tile at the very start, selected while nothing is; tapping it
  /// calls [onNone] to clear the selection. For multi-select pickers
  /// (events), where "no event" is a choice of its own.
  final String? noneLabel;
  final VoidCallback? onNone;

  /// A tile row's height at the normal font; more at a large one (see
  /// `_rowHeight`).
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
  final _tilesScroll = ScrollController();
  final _resultsScroll = ScrollController();

  /// One column's width plus its gap, from the last layout.
  double _columnExtent = 0;

  /// Width of the scrolling rows, from the last layout.
  double _rowsWidth = 0;

  /// Set by a tap on a tile: that tile is in view, nothing to scroll to.
  bool _tappedInRows = false;

  late final AnimationController _search = AnimationController(
    vsync: this,
    value: widget.searching ? 1 : 0,
  )..addStatusListener(_onSearchStatus);

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChange);
    _revealAfterBuild(widget.selectedIds, animate: false);
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
    final added = widget.selectedIds.difference(oldWidget.selectedIds);
    if (_tappedInRows) {
      _tappedInRows = false;
    } else if (added.isNotEmpty) {
      _revealAfterBuild(added, animate: true);
    }
    if (widget.searching == oldWidget.searching) return;
    // The query is not kept between searches.
    _query.clear();
    if (widget.searching) {
      // A new search starts at the first match. The results row is gone
      // once search has fully closed, and comes back at 0; this is for
      // one reopened while the old row is still fading out. Not done on
      // closing: the fading row would jump.
      if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
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

  /// Scrolls the rows, once laid out, so the first of [ids] (in the rows'
  /// order) is fully in view; nothing if it already is.
  void _revealAfterBuild(Set<int> ids, {required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tilesScroll.hasClients || _columnExtent == 0) return;
      final index = _gridTiles.indexWhere((t) => ids.contains(t.id));
      if (index < 0) return;
      final offset = revealOffset(
        column: index ~/ 2,
        columnExtent: _columnExtent,
        viewport: _rowsWidth,
        current: _tilesScroll.offset,
        max: _tilesScroll.position.maxScrollExtent,
      );
      if (offset == _tilesScroll.offset) return;
      if (animate && _search.duration != Duration.zero) {
        _tilesScroll.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _tilesScroll.jumpTo(offset);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _tilesScroll.dispose();
    _resultsScroll.dispose();
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
      ...widget.items,
    ];
  }

  void _tapTile(int id) {
    _tappedInRows = true;
    // Consumed by didUpdateWidget in the next frame; cleared after it in
    // case the tap changed nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tappedInRows = false);
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
    final rowHeight = _rowHeight(context);
    final gridWidth = width - actionWidth - gap;
    // At 4 columns, the same tile size as the fixed 4 + 4 grid had. The
    // rows run on under the gap before the buttons, so the last column's
    // trailing gap doesn't make the columns in view scroll.
    final columns = _visibleColumns(context, gridWidth);
    final tileWidth = (gridWidth - gap * (columns - 1)) / columns;
    _columnExtent = tileWidth + gap;
    _rowsWidth = gridWidth + gap;
    final buttonHeight = widget.buttonShape == ItemShape.circle
        ? actionWidth
        : rowHeight;

    final grid = _gridTiles;
    final emptyText = widget.emptyText;
    final showEmpty = grid.isEmpty && emptyText != null;
    final results = growNew > 0 ? _results : const <PickerItem>[];

    return SizedBox(
      height: rowHeight * 2 + gap,
      child: Stack(
        children: [
          // Normal state: two rows of tiles (or "No categories yet"). Kept
          // (hidden) while searching, so the rows keep their scroll offset
          // and can scroll to a tile picked in search.
          Positioned(
            left: 0,
            top: 0,
            width: _rowsWidth,
            height: rowHeight * 2 + gap,
            child: Visibility(
              visible: shrinkOld > 0,
              maintainState: true,
              child: showEmpty
                  ? Opacity(
                      opacity: shrinkOld,
                      child: SizedBox(
                        width: gridWidth,
                        child: Center(child: Text(emptyText)),
                      ),
                    )
                  : _columns(grid, rowHeight, shrinkOld),
            ),
          ),
          // Search state: the matches in the second row.
          if (growNew > 0)
            Positioned(
              left: 0,
              top: rowHeight + gap,
              width: _rowsWidth,
              height: rowHeight,
              child: ListView.builder(
                controller: _resultsScroll,
                scrollDirection: Axis.horizontal,
                itemExtent: _columnExtent,
                itemCount: results.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: gap),
                  child: _tile(results[index], _tapResult, growNew, rowHeight),
                ),
              ),
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
                            rowHeight: rowHeight,
                            icon: Icons.add,
                            tooltip: widget.newLabel ?? '',
                            shape: widget.buttonShape,
                            onPressed: _new,
                          ),
                        ))
                : _scaled(
                    growNew,
                    _ActionButton(
                      rowHeight: rowHeight,
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
              rowHeight: rowHeight,
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

  /// Columns in view: 4, or 2 (so 2 + 2 tiles) when the font is so large
  /// that a quarter-wide tile would show only a few letters of a name
  /// (owner, 2026-10-05). Decided in logical pixels from the row's width
  /// and the scaled name size, so it is the same on any screen density.
  int _visibleColumns(BuildContext context, double gridWidth) {
    const gap = TilePicker._gap;
    final nameSize = MediaQuery.textScalerOf(context)
        .scale(Theme.of(context).textTheme.labelSmall?.fontSize ?? 11);
    // The name's room in a tile (4 of padding each side), against about 6
    // to 7 letters: a letter is roughly 0.6 of the font size. On a 360 dp
    // phone that keeps 4 columns up to 1.1x the font; on a 411 dp one up to
    // 1.5x.
    final nameRoom = (gridWidth - gap * 3) / 4 - 8;
    return nameRoom >= nameSize * 4 ? 4 : 2;
  }

  /// Each row's height: [TilePicker.tileHeight], or more when a tile's
  /// emoji (a circle tile's disc) and name need it, at a large font. They
  /// then keep their size; in 64 they were shrunk to fit, and a circle
  /// tile's disc looked small (owner, 2026-10-05). The name's line follows
  /// the font size, the emoji and disc don't.
  double _rowHeight(BuildContext context) {
    double lineHeight(String text, TextStyle? style, TextScaler scaler) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final name = lineHeight(
      'Ag',
      Theme.of(context).textTheme.labelSmall,
      MediaQuery.textScalerOf(context),
    );
    final top = widget.tileShape == ItemShape.circle
        ? _Tile._circleSize
        : lineHeight('🧾', _Tile._emojiStyle, TextScaler.noScaling);
    // The 2 between them, and 1 above and below.
    return math.max(TilePicker.tileHeight, top + 2 + name + 2);
  }

  /// The two rows, one column (top and bottom tile) per item of the list,
  /// each [rowHeight] tall and shrunk to [scale]. Built lazily: only the
  /// columns in view.
  Widget _columns(List<PickerItem> tiles, double rowHeight, double scale) {
    const gap = TilePicker._gap;
    return ListView.builder(
      controller: _tilesScroll,
      scrollDirection: Axis.horizontal,
      itemExtent: _columnExtent,
      itemCount: (tiles.length + 1) ~/ 2,
      itemBuilder: (context, column) {
        final top = column * 2;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: gap),
          child: Column(
            children: [
              SizedBox(
                height: rowHeight,
                child: _tile(tiles[top], _tapTile, scale, rowHeight),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: rowHeight,
                child: top + 1 < tiles.length
                    ? _tile(tiles[top + 1], _tapTile, scale, rowHeight)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(
    PickerItem item,
    ValueChanged<int> onTap,
    double scale,
    double height,
  ) => _scaled(
    scale,
    _Tile(
      item: item,
      height: height,
      selected: _isSelected(item.id),
      showCheck: widget.multiSelect && item.id != TilePicker._noneId,
      shape: widget.tileShape,
      onTap: () => onTap(item.id),
    ),
  );

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
    required this.rowHeight,
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

  /// The tile rows' height, for the matches row under the bar.
  final double rowHeight;
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
                    scrollPadding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + rowHeight + TilePicker._gap,
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
    // Its own node: the tooltip's label otherwise went to the picker's
    // node, and TalkBack's "Search" was the whole picker, a double-tap
    // landing on the tiles (Oppo, 2026-10-04).
    return closed
        ? Semantics(
            container: true,
            child: Tooltip(message: l10n.search, child: bar),
          )
        : bar;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.item,
    required this.height,
    required this.selected,
    required this.showCheck,
    required this.shape,
    required this.onTap,
  });

  final PickerItem item;

  /// The row's height (see `_rowHeight`), for the corner radius.
  final double height;

  final bool selected;

  /// Multi-select tiles mark selection with a check as well as the color.
  final bool showCheck;

  final ItemShape shape;
  final VoidCallback onTap;

  /// Diameter of a circle tile's emoji disc; the name goes under it.
  static const _circleSize = 44.0;

  static const _emojiStyle = TextStyle(fontSize: 22);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fill = selected
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    // An icon, so a fixed size like Material icons: following the font
    // size it left no room for the name (largest font, Oppo, 2026-10-05).
    final emoji = Text(
      item.emoji,
      style: _emojiStyle,
      textScaler: TextScaler.noScaling,
    );
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
      final disc = Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.square(
            dimension: _circleSize,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Center(child: emoji),
            ),
          ),
          if (showCheck && selected)
            PositionedDirectional(top: -2, end: -2, child: check),
        ],
      );
      return Semantics(
        // Its own node: the last column's lone tile otherwise merged into
        // the column's, two rows tall, and TalkBack's double-tap hit the
        // gap (Oppo, 2026-10-04).
        container: true,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          // The disc, the name under it (it wouldn't fit inside).
          child: _fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [disc, const SizedBox(height: 2), name],
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true, // See the circle tile above.
      selected: selected,
      button: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(shapeRadius(shape, height)),
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
                child: _fitted(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [emoji, const SizedBox(height: 2), name],
                  ),
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

/// [child] at the tile's width (so a long name still ends in "…"), shrunk
/// as a whole when it is taller than the tile, as with the largest font,
/// instead of overflowing it (owner, 2026-10-05). The tile keeps its size:
/// the rows and buttons around it are laid out for it.
Widget _fitted(Widget child) => LayoutBuilder(
  builder: (context, box) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(width: box.maxWidth, child: child),
  ),
);

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.rowHeight,
    required this.icon,
    required this.tooltip,
    required this.shape,
    required this.onPressed,
  });

  /// The tile rows' height: a non-circle button is as tall as a row.
  final double rowHeight;
  final IconData icon;
  final String tooltip;
  final ItemShape shape;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final height = shape == ItemShape.circle
        ? TilePicker._actionWidth
        : rowHeight;
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
