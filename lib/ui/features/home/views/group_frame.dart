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

/// A subtotal on a frame top or a day header, for exactly what the filters
/// show:
///
/// - every currency on one line when it fits: `₹4,560.00 + $85.00`;
/// - otherwise a **Show subtotal** button that opens them in a dialog;
/// - nothing while it's read, then (after 300 ms) a small spinner;
/// - a retry icon when the read failed.
///
/// Asks the cubit for the subtotal when it is first painted, i.e. on screen:
/// built but off-screen headers read nothing.
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

  /// Nothing for the first 300 ms (subtotals usually take a few), then a 16 dp
  /// spinner.
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
