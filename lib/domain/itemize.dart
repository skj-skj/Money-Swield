/// The Itemize line: an expression's additive terms with a label after each,
/// `50 (potato) + 60 × 2 (onion)`.
library;

import 'amount_expression.dart';

/// The longest label, in characters.
const maxItemLabelLength = 40;

/// The line for [terms] (canonical, from [ExpressionValue.terms]) with
/// [labels] (one per term; empty or blank = none), in display form with
/// [decimalSeparator].
String buildItemizeLine(
  List<String> terms,
  List<String> labels,
  String decimalSeparator,
) {
  final out = StringBuffer();
  for (var i = 0; i < terms.length; i++) {
    out.write(displayExpression(terms[i], decimalSeparator));
    final label = i < labels.length ? labels[i].trim() : '';
    if (label.isNotEmpty) out.write(' ($label)');
  }
  return out.toString();
}

/// The labels of [line] when it is an Itemize line for [terms]: each
/// term's display form (either decimal separator), optionally followed by
/// ` (label)`, joined by the operators. Null when it isn't one, e.g. the
/// user edited it. A term without a label gets `''`.
List<String>? parseItemizeLine(String line, List<String> terms) {
  if (terms.isEmpty) return null;
  final pattern = StringBuffer('^');
  for (final term in terms) {
    final shown = RegExp.escape(displayExpression(term, '.'));
    pattern
      ..write(shown.replaceAll(r'\.', '[.,]'))
      ..write(r'(?: \((.+?)\))?');
  }
  pattern.write(r'$');
  final match = RegExp(pattern.toString()).firstMatch(line);
  if (match == null) return null;
  return [for (var i = 1; i <= terms.length; i++) match.group(i) ?? ''];
}

/// [description] with [line] as its first line. The old first line is
/// replaced when it equals [replaceable] (the Itemize line the form put
/// there and the user hasn't changed); otherwise [line] goes above it.
String putItemizeLine(String description, String line, String? replaceable) {
  if (description.isEmpty) return line;
  final first = firstLineOf(description);
  if (replaceable != null && first == replaceable) {
    return '$line${description.substring(first.length)}';
  }
  return '$line\n$description';
}

/// The first line of [description].
String firstLineOf(String description) {
  final newline = description.indexOf('\n');
  return newline < 0 ? description : description.substring(0, newline);
}

/// [term] (canonical, from [ExpressionValue.terms]) as the Itemize sheet
/// labels its row: `50`, `60 × 2`, `−10`. A `+` is left out; a `−` stays,
/// right against the number, since it marks a deduction.
String itemizeTermLabel(String term, String decimalSeparator) {
  final sign = term.startsWith('-') ? '−' : '';
  final unsigned = term.startsWith('+') || term.startsWith('-')
      ? term.substring(1)
      : term;
  return '$sign${displayExpression(unsigned, decimalSeparator)}';
}
