/// Typing in the amount field (phase-4.md §5.3): the system keyboard's
/// edits ([filterKeyboardEdit]) and the operator row's keys
/// ([applyRowKey]). Pure functions on the text and its selection offsets,
/// so they are tested without widgets; the field's `TextInputFormatter`
/// and the row only call them.
library;

import 'dart:math' show max, min;

import 'amount_expression.dart';

/// The operator row's keys (P4-19).
enum RowKey { plus, minus, times, divide, decimal }

/// Text and selection of the amount field after an edit. `base` and
/// `extent` are selection offsets; -1 means no selection.
typedef FieldEdit = ({String text, int base, int extent});

/// What a [RowKey] inserts, in field form. The decimal key's text is the
/// locale's separator, passed in.
const _rowKeyText = {
  RowKey.plus: '+',
  RowKey.minus: '−',
  RowKey.times: '×',
  RowKey.divide: '÷',
};

const _fieldOperators = '+−×÷';
const _separators = '.,';
final _digit = RegExp('[0-9]');

bool _isFieldOperator(String char) =>
    char.isNotEmpty && _fieldOperators.contains(char);

/// The amount field's text after a keyboard edit, or null to refuse the
/// edit (the field keeps its old text).
///
/// `-` → `−`; `*`, `x`, `X` → `×`; `/` → `÷`; spaces are dropped; digits,
/// `.`, `,` and `+ − × ÷` are kept. Any other character refuses the whole
/// edit, as Phase 2's filter did, and so does going over
/// [maxExpressionLength], unless the text is still shorter than
/// [previousLength] (the text before the edit): a text already over the
/// limit (a damaged draft keeps it, phase-4.md §7.5) can still be deleted
/// down. It never reorders or fixes the structure: `5++2` stays as typed
/// and the result line says it is invalid. Each kept character maps to
/// one, so the selection moves only past dropped spaces.
FieldEdit? filterKeyboardEdit(FieldEdit edit, {int previousLength = 0}) {
  final text = edit.text;
  final out = StringBuffer();
  // Spaces dropped before each offset, to move the selection with the text.
  final droppedBefore = List<int>.filled(text.length + 1, 0);
  var dropped = 0;
  for (var i = 0; i < text.length; i++) {
    droppedBefore[i] = dropped;
    final char = text[i];
    if (char == ' ') {
      dropped++;
      continue;
    }
    final mapped = _keyboardChar(char);
    if (mapped == null) return null;
    out.write(mapped);
  }
  droppedBefore[text.length] = dropped;

  final result = out.toString();
  if (result.length > maxExpressionLength && result.length >= previousLength) {
    return null;
  }
  int move(int offset) => offset < 0 || offset > text.length
      ? offset
      : offset - droppedBefore[offset];
  return (text: result, base: move(edit.base), extent: move(edit.extent));
}

String? _keyboardChar(String char) => switch (char) {
  '-' => '−',
  '*' || 'x' || 'X' => '×',
  '/' => '÷',
  '+' || '.' || ',' || '−' || '×' || '÷' => char,
  _ when _digit.hasMatch(char) => char,
  _ => null,
};

/// [edit] after tapping [key] on the operator row, at the cursor,
/// replacing a selection, or null when the key does nothing there.
/// [decimalSeparator] is the formatting locale's (`.` or `,`).
///
/// - `+ − × ÷`: at the very start, ignored (no negative amounts); an
///   operator right before or right after the cursor is replaced
///   (`50|+60` then `×` → `50×|60`), so the key never makes `5×+6`;
///   otherwise inserted.
/// - decimal: ignored if the number at the cursor already has a separator;
///   at the start or right after an operator, inserts `0` first; otherwise
///   inserted.
/// - Ignored when the text would grow past [maxExpressionLength].
///
/// The cursor ends, collapsed, after what was inserted.
FieldEdit? applyRowKey(FieldEdit edit, RowKey key, String decimalSeparator) {
  final text = edit.text;
  final valid = edit.base >= 0 && edit.extent >= 0;
  // No cursor yet (the field was never tapped): type at the end.
  final start = valid ? min(edit.base, edit.extent) : text.length;
  final end = valid ? max(edit.base, edit.extent) : text.length;
  var before = text.substring(0, start);
  var after = text.substring(end);

  final String insert;
  if (key == RowKey.decimal) {
    if (_numberHasSeparator(before, after)) return null;
    final atNumberStart =
        before.isEmpty || _isFieldOperator(before[before.length - 1]);
    insert = atNumberStart ? '0$decimalSeparator' : decimalSeparator;
  } else {
    if (before.isNotEmpty && _isFieldOperator(before[before.length - 1])) {
      before = before.substring(0, before.length - 1);
    }
    if (before.isEmpty) return null;
    if (after.isNotEmpty && _isFieldOperator(after[0])) {
      after = after.substring(1);
    }
    insert = _rowKeyText[key]!;
  }

  final result = '$before$insert$after';
  if (result.length > maxExpressionLength) return null;
  final cursor = before.length + insert.length;
  return (text: result, base: cursor, extent: cursor);
}

/// Whether the number the cursor is in (between [before] and [after], up to
/// the nearest operators) already has a `.` or `,`.
bool _numberHasSeparator(String before, String after) {
  for (var i = before.length - 1; i >= 0; i--) {
    if (_isFieldOperator(before[i])) break;
    if (_separators.contains(before[i])) return true;
  }
  for (var i = 0; i < after.length; i++) {
    if (_isFieldOperator(after[i])) break;
    if (_separators.contains(after[i])) return true;
  }
  return false;
}
