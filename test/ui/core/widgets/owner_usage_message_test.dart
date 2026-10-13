import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/ui/core/widgets/move_dialog.dart';

import '../../../helpers/test_database.dart';

void main() {
  final en = l10nFor('en');

  test('expenses only', () {
    expect(
      ownerUsageMessage(en, 'Food', (active: 3, binned: 1, templates: 0)),
      '"Food" is used by 4 expenses (1 in the bin).',
    );
    expect(
      ownerUsageMessage(en, 'Food', (active: 1, binned: 0, templates: 0)),
      '"Food" is used by 1 expense.',
    );
  });

  test('items only, and both', () {
    expect(
      ownerUsageMessage(en, 'Food', (active: 0, binned: 0, templates: 1)),
      '"Food" is used by 1 recurring item. '
      'Its later payments use the one you pick.',
    );
    expect(
      ownerUsageMessage(en, 'Food', (active: 0, binned: 0, templates: 2)),
      '"Food" is used by 2 recurring items. '
      'Their later payments use the one you pick.',
    );
    expect(
      ownerUsageMessage(en, 'UPI', (active: 4, binned: 0, templates: 1)),
      '"UPI" is used by 4 expenses. It is also used by 1 recurring item: '
      'its later payments use the one you pick.',
    );
  });

  test('every language has every combination, grouped', () {
    for (final code in ['es', 'hi']) {
      final l10n = l10nFor(code);
      for (final usage in [
        (active: 0, binned: 0, templates: 1),
        (active: 1234, binned: 5, templates: 1000),
      ]) {
        final text = ownerUsageMessage(l10n, 'X', usage);
        expect(text, contains('X'));
        if (usage.templates == 1000) {
          expect(text, contains(code == 'hi' ? '1,000' : '1.000'));
        }
      }
    }
  });
}
