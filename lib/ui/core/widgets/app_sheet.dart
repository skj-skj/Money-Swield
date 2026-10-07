import 'package:material_ui/material_ui.dart';

/// Opens a bottom sheet the way every sheet of the app opens: as tall as
/// its content needs (up to the screen), with a drag handle, and below the
/// status bar and notch. The sheet itself handles the keyboard
/// (`MediaQuery.viewInsetsOf`). Back, a swipe down or a tap outside
/// closes it.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: builder,
);
