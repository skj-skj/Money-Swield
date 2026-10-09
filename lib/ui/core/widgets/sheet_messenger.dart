import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'show_message.dart';

/// Snackbars for a bottom sheet. Material's own show on the screen's
/// `Scaffold`, which a modal sheet covers, so nobody would see them; and a
/// `Scaffold` inside the sheet would make every sheet full height. This
/// floats the same snackbar (the theme's colours, text and shape) over the
/// bottom of [child], for [shortMessageDuration]; a new message replaces
/// the one showing, as [showMessage] does. TalkBack reads it out. It has
/// no action and lets taps through, so it never hides a photo's tap.
///
/// Show one with `SheetMessenger.of(context).show(text)` from inside
/// [child], or through a `GlobalKey<SheetMessengerState>`.
class SheetMessenger extends StatefulWidget {
  const SheetMessenger({super.key, required this.child});

  final Widget child;

  static SheetMessengerState of(BuildContext context) =>
      context.findAncestorStateOfType<SheetMessengerState>()!;

  @override
  State<SheetMessenger> createState() => SheetMessengerState();
}

class SheetMessengerState extends State<SheetMessenger> {
  String? _message;
  Timer? _timer;

  /// The message showing now, if any.
  String? get message => _message;

  void show(String message) {
    _timer?.cancel();
    setState(() => _message = message);
    _timer = Timer(shortMessageDuration, hide);
  }

  void hide() {
    _timer?.cancel();
    if (mounted && _message != null) setState(() => _message = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackTheme = theme.snackBarTheme;
    final message = _message;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 16,
          right: 16,
          // Above the navigation bar, which the sheet's content keeps
          // clear of with its own SafeArea.
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          // Taps go through to the photos under it: it has no action, and
          // a tap meant for a tile must never be lost to it (found by the
          // sheet's selection test: the tile under it didn't toggle).
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: message == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      key: ValueKey(message),
                      liveRegion: true,
                      container: true,
                      child: Material(
                        color:
                            snackTheme.backgroundColor ??
                            theme.colorScheme.inverseSurface,
                        elevation: snackTheme.elevation ?? 6,
                        shape:
                            snackTheme.shape ??
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                        // Full width between the margins, like a snackbar.
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            message,
                            key: const ValueKey('sheetMessage'),
                            style:
                                snackTheme.contentTextStyle ??
                                theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onInverseSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
