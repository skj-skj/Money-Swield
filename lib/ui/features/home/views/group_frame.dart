import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/totals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/money_formatter.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/delayed_spinner.dart';
import '../view_models/expense_list_cubit.dart';

/// Where a frame's side lines are, from the screen's edges (phase-5.md
/// §8.3).
const frameMargin = 16.0;

/// From a side line to the text inside the frame.
const frameInset = 12.0;

const _radius = 12.0;

/// The outline of one group (phase-5.md §8.3, P5-30): side lines and, once
/// the group has ended, the rounded bottom. The top is drawn by the
/// group's frame top ([FrameTop]), which covers this part, pinned or not.
/// Painted by `DecoratedSliver` for the whole group, offset by how far it
/// has scrolled, so the corners stay where the group really ends.
class FrameDecoration extends Decoration {
  const FrameDecoration({required this.color, required this.open});

  final Color color;

  /// More pages may still add to the group: no bottom yet.
  final bool open;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _FramePainter(this);

  @override
  bool operator ==(Object other) =>
      other is FrameDecoration && other.color == color && other.open == open;

  @override
  int get hashCode => Object.hash(color, open);
}

class _FramePainter extends BoxPainter {
  _FramePainter(this.decoration);

  final FrameDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final left = offset.dx + frameMargin;
    final right = offset.dx + size.width - frameMargin;
    final top = offset.dy;
    final bottom = offset.dy + size.height;
    final path = Path()..moveTo(left, top);
    if (decoration.open) {
      path
        ..lineTo(left, bottom)
        ..moveTo(right, bottom)
        ..lineTo(right, top);
    } else {
      path
        ..lineTo(left, bottom - _radius)
        ..arcToPoint(
          Offset(left + _radius, bottom),
          radius: const Radius.circular(_radius),
          clockwise: false,
        )
        ..lineTo(right - _radius, bottom)
        ..arcToPoint(
          Offset(right, bottom - _radius),
          radius: const Radius.circular(_radius),
          clockwise: false,
        )
        ..lineTo(right, top);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = decoration.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// A frame's top, sticky while its group is on screen (P5-12): the
/// group's name on the border at the left and its subtotal from the middle
/// to the right, on a page-coloured strip with the frame's top and side
/// lines, so it still reads as the frame's top when pinned.
class FrameTop extends StatelessWidget {
  const FrameTop({
    super.key,
    required this.name,
    required this.subtotalKey,
    required this.cubit,
    required this.defaultCurrency,
  });

  final String name;
  final SubtotalKey subtotalKey;
  final ExpenseListCubit cubit;
  final String defaultCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = theme.colorScheme.surface;
    return ColoredBox(
      color: page,
      child: CustomPaint(
        painter: _FrameTopPainter(theme.colorScheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: frameMargin + frameInset - 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Two equal halves: the name on the left one, the subtotal
              // from the middle to the right. Their page-coloured
              // background cuts the border line. The name is read by
              // TalkBack with the subtotal (SubtotalView).
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ExcludeSemantics(
                    child: ColoredBox(
                      color: page,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ColoredBox(
                    color: page,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SubtotalView(
                        cubit: cubit,
                        subtotalKey: subtotalKey,
                        title: name,
                        defaultCurrency: defaultCurrency,
                        style: theme.textTheme.titleSmall,
                        semanticsName: name,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameTopPainter extends CustomPainter {
  _FrameTopPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const left = frameMargin;
    final right = size.width - frameMargin;
    final path = Path()
      ..moveTo(left, size.height)
      ..lineTo(left, mid + _radius)
      ..arcToPoint(
        Offset(left + _radius, mid),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(right - _radius, mid)
      ..arcToPoint(
        Offset(right, mid + _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(right, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FrameTopPainter old) => old.color != color;
}

/// A subtotal on a frame top or a day header (phase-5.md §8.3), for
/// exactly what the filters show:
///
/// - every currency on one line when it fits: `₹4,560.00 + $85.00`;
/// - otherwise a **Show subtotal** button that opens them in a dialog;
/// - nothing while it's read, then (after 300 ms) a small spinner;
/// - a retry icon when the read failed.
///
/// Asks the cubit for the subtotal when it is first painted, i.e. on
/// screen (P5-26): built but off-screen headers read nothing.
class SubtotalView extends StatelessWidget {
  const SubtotalView({
    super.key,
    required this.cubit,
    required this.subtotalKey,
    required this.title,
    required this.defaultCurrency,
    required this.style,
    required this.semanticsName,
    this.prefix,
  });

  final ExpenseListCubit cubit;
  final SubtotalKey subtotalKey;

  /// The dialog's title: the group's or the day's name.
  final String title;

  final String defaultCurrency;
  final TextStyle? style;

  /// Read by TalkBack before the amount.
  final String semanticsName;

  /// Text before the amounts on the same line ("Sat, 17 Oct – "), for a day
  /// header; kept when the amounts become a button.
  final String Function(String amounts)? prefix;

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<ExpenseListCubit, ExpenseListState>(
      bloc: cubit,
      buildWhen: (previous, current) => _entry(previous) != _entry(current),
      builder: (context, state) {
        final entry = _entry(state);
        return _RequestOnPaint(
          wanted: entry == null,
          onShown: () => cubit.requestSubtotal(subtotalKey),
          child: switch (entry) {
            null => _withPrefix(context, const SizedBox(width: 16)),
            SubtotalLoading() => _loading(context),
            SubtotalFailed() => _failed(context),
            SubtotalReady(:final totals) => _ready(context, totals),
          },
        );
      },
    );
  }

  SubtotalState? _entry(ExpenseListState state) => switch (state) {
    ExpenseListLoaded(:final subtotals) => subtotals[subtotalKey],
    _ => null,
  };

  /// [amounts] (a spinner, a retry icon or a button) after the day's date,
  /// or on a frame top, with the group's name for TalkBack.
  Widget _withPrefix(BuildContext context, Widget amounts) {
    final prefix = this.prefix;
    if (prefix == null) {
      return Semantics(label: semanticsName, child: amounts);
    }
    // The button goes under the date when both don't fit (a large font
    // on a narrow phone).
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(title, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        amounts,
      ],
    );
  }

  /// Nothing for the first 300 ms (subtotals usually take a few, phase-5.md
  /// §6.4), then a 16 dp spinner.
  Widget _loading(BuildContext context) => _withPrefix(
    context,
    const DelayedSpinner(
      delay: Duration(milliseconds: 300),
      size: 16,
      strokeWidth: 2,
    ),
  );

  Widget _failed(BuildContext context) => _withPrefix(
    context,
    SizedBox.square(
      dimension: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: const Icon(Icons.refresh),
        tooltip: AppLocalizations.of(context).subtotalLoadFailed,
        onPressed: () => cubit.retrySubtotal(subtotalKey),
      ),
    ),
  );

  Widget _ready(BuildContext context, CurrencyTotals totals) {
    final l10n = AppLocalizations.of(context);
    final formatter = MoneyFormatter.of(context);
    final amounts = totalsText(l10n, formatter, totals, defaultCurrency);
    final spoken = totalsText(
      l10n,
      formatter,
      totals,
      defaultCurrency,
      spoken: true,
    );
    final prefix = this.prefix;
    final line = prefix == null ? amounts : prefix(amounts);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: line, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        if (fits) {
          return Semantics(
            label: prefix == null
                ? l10n.groupSubtotalSemantics(semanticsName, spoken)
                : l10n.daySubtotalSemantics(semanticsName, spoken),
            excludeSemantics: true,
            child: Text(line, style: style, maxLines: 1, softWrap: false),
          );
        }
        return _withPrefix(
          context,
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => showSubtotalDialog(
              context,
              title: title,
              totals: totals,
              defaultCurrency: defaultCurrency,
            ),
            child: Text(l10n.showSubtotal),
          ),
        );
      },
    );
  }
}

/// Every currency's subtotal, one per line, default first, then by code.
Future<void> showSubtotalDialog(
  BuildContext context, {
  required String title,
  required CurrencyTotals totals,
  required String defaultCurrency,
}) {
  final l10n = AppLocalizations.of(context);
  final formatter = MoneyFormatter.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (code, minor) in orderedTotals(totals, defaultCurrency))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  totalText(l10n, formatter, code, minor),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

/// Calls [onShown] after a frame in which it was painted while [wanted]:
/// the list's slivers build every loaded header, but the viewport paints
/// only those on screen, so this is what makes subtotals lazy.
class _RequestOnPaint extends SingleChildRenderObjectWidget {
  const _RequestOnPaint({
    required this.wanted,
    required this.onShown,
    super.child,
  });

  final bool wanted;
  final VoidCallback onShown;

  @override
  _RenderRequestOnPaint createRenderObject(BuildContext context) =>
      _RenderRequestOnPaint(wanted: wanted, onShown: onShown);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRequestOnPaint renderObject,
  ) {
    renderObject
      ..wanted = wanted
      ..onShown = onShown;
  }
}

class _RenderRequestOnPaint extends RenderProxyBox {
  _RenderRequestOnPaint({required this._wanted, required this.onShown});

  VoidCallback onShown;
  bool _scheduled = false;

  bool _wanted;
  set wanted(bool value) {
    if (value == _wanted) return;
    _wanted = value;
    // Painted again so a header on screen asks again.
    if (value) markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_wanted || _scheduled) return;
    _scheduled = true;
    // Never during paint: the request emits, which rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (attached && _wanted) onShown();
    });
  }
}
