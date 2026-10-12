import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/ui/core/byte_size_text.dart';

import '../../helpers/test_database.dart';

void main() {
  String en(int bytes) => byteSizeText(l10nFor('en'), 'en_IN', bytes);

  test('bytes, then one decimal from KB, 1024-based', () {
    expect(en(0), '0 B');
    expect(en(999), '999 B');
    expect(en(1023), '1,023 B');
    expect(en(1024), '1.0 KB');
    expect(en(1536), '1.5 KB');
    expect(en(1024 * 1024 - 1), '1.0 MB', reason: 'never 1024.0 KB');
    expect(en(1024 * 1024), '1.0 MB');
    expect(en((1.2 * 1024 * 1024 * 1024).round()), '1.2 GB');
    expect(en(1024 * 1024 * 1024 * 1024), '1,024.0 GB');
  });

  test('the largest int does not throw', () {
    expect(en(9223372036854775807), endsWith(' GB'));
  });

  test('es writes a decimal comma, hi a point', () {
    final gb = (1.2 * 1024 * 1024 * 1024).round();
    expect(byteSizeText(l10nFor('es'), 'es_ES', gb), '1,2 GB');
    expect(byteSizeText(l10nFor('es'), 'es', 1536), '1,5 KB');
    expect(byteSizeText(l10nFor('hi'), 'hi', gb), '1.2 GB');
  });
}
