import 'package:material_ui/material_ui.dart';

/// Shows [message] as a snackbar on [messenger], replacing the one showing
/// (else a new message waits behind an old one, and an old Undo outlives
/// the screen it was for).
///
/// [long] is for a message with more to read: 10 seconds and a close
/// button. With an [action] (Undo), the snackbar still goes away on its
/// own: one with an action stays until dismissed by default, and Undo is
/// only offered for a moment. [messenger] null (the screen is gone) shows
/// nothing.
void showMessage(
  ScaffoldMessengerState? messenger,
  String message, {
  bool long = false,
  SnackBarAction? action,
}) {
  messenger?.hideCurrentSnackBar();
  queueMessage(messenger, message, long: long, action: action);
}

/// Like [showMessage], but behind the snackbar showing instead of in its
/// place: for messages said together at once (the restore message, then
/// what the recurring generator did; phase-7a.md §7.5).
void queueMessage(
  ScaffoldMessengerState? messenger,
  String message, {
  bool long = false,
  SnackBarAction? action,
}) {
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: long ? longMessageDuration : shortMessageDuration,
      showCloseIcon: long,
      persist: false,
      action: action,
    ),
  );
}

/// How long a message shows: Material's default.
const shortMessageDuration = Duration(seconds: 4);

/// How long a [showMessage] `long` message shows.
const longMessageDuration = Duration(seconds: 10);
