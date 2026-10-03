/// The plain-text report a user copies into a bug report: what was running,
/// the error and where it happened. English on purpose: it is sent to us,
/// not shown as UI text.
String errorReport(String step, Object error, StackTrace stackTrace) =>
    'Step: $step\nError: $error\n\n$stackTrace';
