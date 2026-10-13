import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/ui/core/form_validation.dart';
import 'package:money_swield/ui/core/widgets/emoji_picker_field.dart';

void main() {
  test('offers about 80 emojis, none twice', () {
    expect(curatedEmojis.length, inInclusiveRange(70, 90));
    expect(curatedEmojis.toSet(), hasLength(curatedEmojis.length));
  });

  test('every offered emoji passes the form\'s one-emoji rule', () {
    for (final emoji in curatedEmojis) {
      expect(
        validateEmoji(emoji),
        isNull,
        reason: '"$emoji" from the grid would be refused',
      );
    }
  });

  test('every seeded emoji is offered in the grid', () {
    const seeded = [
      ...['🍽️', '🥤', '🛒', '🛍️', '👕', '🚌', '⛽', '🏠', '🏡', '🧾'],
      ...['💊', '📚', '🎬', '✈️', '🎁', '💇', '🔁', '🏦', '📈', '📦'],
      ...['💵', '📱', '🏧', '💳', '🎂', '💍', '🎉', '🪔', '🧳'],
    ];
    for (final emoji in seeded) {
      expect(curatedEmojis, contains(emoji));
    }
  });
}
