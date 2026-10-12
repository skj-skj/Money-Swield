/// The SMS text as the rules read it. Pure Dart.
library;

final _lineBreaks = RegExp(r'\r\n?');
final _spaceRun = RegExp(r'[^\S\n]+');
final _spacesAroundBreak = RegExp(r' ?\n ?');
final _breakRun = RegExp(r'\n+');

/// [body] with every run of whitespace made one space, except that line
/// breaks are kept, one per run (some banks put the payee on its own line);
/// `\r\n` and `\r` count as line breaks. Trimmed. Nothing else is replaced:
/// the text keeps its case and words (rewriting `inr` to `rs.` would turn
/// "pinrest" into "prs.est").
String smsText(String body) => body
    .replaceAll(_lineBreaks, '\n')
    .replaceAll(_spaceRun, ' ')
    .replaceAll(_spacesAroundBreak, '\n')
    .replaceAll(_breakRun, '\n')
    .trim();

/// Where a bank's "it wasn't you?" footer starts. Footers name numbers to call
/// ("to 9000000000") and words like "requested", which the payee and candidate
/// rules must not see.
///
/// The doc names only `not you` / `if not you`; its own test case "a footer 'if
/// not requested by you' after a real debit → yes" needs the other wordings
/// too.
final _footer = RegExp(
  r'\b(?:if\s+)?(not you|not requested by you|not done by you|not initiated by you|'
  r'not made by you|if you did not|if you have not|did not do this|'
  r"didn't do this)",
  caseSensitive: false,
);

/// [text] up to its footer (see [_footer]), trimmed; all of it when there
/// is none.
String withoutFooter(String text) {
  final match = _footer.firstMatch(text);
  return match == null ? text : text.substring(0, match.start).trim();
}
