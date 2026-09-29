/// Lets a migration ask the user something while it runs, e.g. which
/// currency their existing expenses are in.
///
/// The migration screen implements this; tests use a fake that returns
/// fixed answers.
abstract interface class MigrationPrompter {
  Future<String> askText(String question, {String initialValue = ''});

  Future<String> askChoice(String question, List<String> options);
}
