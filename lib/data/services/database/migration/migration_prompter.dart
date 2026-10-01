/// Lets a migration ask the user something while it runs, e.g. which
/// currency their existing expenses are in.
///
/// The migration screen implements this; tests use a fake that returns
/// fixed answers.
abstract interface class MigrationPrompter {
  Future<String> askText(String question, {String initialValue = ''});

  /// [initialValue], if given, is one of [options] and is shown already
  /// selected, so the user only has to confirm it.
  Future<String> askChoice(String question, List<String> options, {String? initialValue});
}
