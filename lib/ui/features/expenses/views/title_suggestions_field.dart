import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/money.dart';
import '../../../../domain/title_suggestions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/money_formatter.dart';

/// The title field with its suggestions dropdown: up to 5 past titles under the
/// field, each with its last amount and category emoji. Shown while the field
/// has focus and [suggestions] isn't empty; the form empties it after a pick
/// and on back.
///
/// An [OverlayPortal] following the field, so the dropdown covers the form
/// instead of pushing it down, and scrolls with the field.
class TitleSuggestionsField extends StatefulWidget {
  const TitleSuggestionsField({
    super.key,
    required this.field,
    required this.focusNode,
    required this.suggestions,
    required this.categoryEmoji,
    required this.onPick,
  });

  /// The title [TextField] itself.
  final Widget field;
  final FocusNode focusNode;
  final List<TitleSuggestion> suggestions;
  final String? Function(int categoryId) categoryEmoji;
  final ValueChanged<TitleSuggestion> onPick;

  @override
  State<TitleSuggestionsField> createState() => _TitleSuggestionsFieldState();
}

class _TitleSuggestionsFieldState extends State<TitleSuggestionsField> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(TitleSuggestionsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_update);
      widget.focusNode.addListener(_update);
    }
    // Shown or hidden after this frame: OverlayPortal can't change while
    // building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final show = widget.focusNode.hasFocus && widget.suggestions.isNotEmpty;
    if (show == _portal.isShowing) return;
    show ? _portal.show() : _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: LayoutBuilder(
        builder: (context, constraints) => OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => _dropdown(constraints.maxWidth),
          child: widget.field,
        ),
      ),
    );
  }

  Widget _dropdown(double width) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = MoneyFormatter.of(context);
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      showWhenUnlinked: false,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        // A tap on a row isn't a tap outside the field: the keyboard stays.
        child: TextFieldTapRegion(
          child: SizedBox(
            width: width,
            child: Semantics(
              container: true,
              label: l10n.titleSuggestionsLabel,
              child: Material(
                elevation: 4,
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final suggestion in widget.suggestions)
                      ListTile(
                        key: ValueKey('suggestion-${suggestion.title}'),
                        dense: true,
                        leading: Text(
                          widget.categoryEmoji(suggestion.categoryId) ?? '',
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          suggestion.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          money.format(
                            Money(
                              suggestion.amountMinor,
                              suggestion.currencyCode,
                            ),
                          ),
                        ),
                        onTap: () => widget.onPick(suggestion),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
