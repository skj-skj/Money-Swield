import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Common emojis offered in the picker grid. Anything else can be typed.
// Rows of space-separated emojis, so the formatter keeps them as a grid.
final curatedEmojis =
    '🍽️ 🍔 🍕 🍜 🍱 🥗 🍰 ☕ 🍵 🥤 🍺 🍷 '
            '🛒 🥦 🍎 🥛 🍞 🧂 🛍️ 👕 👗 👟 👜 💄 '
            '🚌 🚕 🚗 🛵 🚲 🚆 ✈️ ⛽ 🅿️ 🧳 🏨 🗺️ '
            '🏠 🏡 🛋️ 🔧 💡 💧 🔥 📶 📱 💻 🧾 🔁 '
            '💊 🏥 🦷 💪 🧘 💇 📚 🎓 ✏️ 🎬 🎮 🎵 '
            '⚽ 🎨 🎁 🎂 💍 🎉 🪔 🎄 👶 🐶 🐱 🌱 '
            '💵 💳 🏧 🏦 📈 💰 🪙 ❤️ ⭐ 📦'
        .split(' ');

/// Shows the chosen emoji large; tapping it opens [showEmojiPicker].
/// Validation is the form cubit's job; this only shows [errorText].
class EmojiPickerField extends StatelessWidget {
  const EmojiPickerField({
    super.key,
    required this.emoji,
    required this.onChanged,
    this.errorText,
  });

  final String emoji;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showEmojiPicker(context);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.fieldEmoji,
          errorText: errorText,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        isEmpty: emoji.isEmpty,
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

/// A dialog with the [curatedEmojis] grid and a text box for any other
/// emoji. Returns the chosen emoji, or null if dismissed.
Future<String?> showEmojiPicker(BuildContext context) => showDialog<String>(
  context: context,
  builder: (context) => const _EmojiPickerDialog(),
);

class _EmojiPickerDialog extends StatefulWidget {
  const _EmojiPickerDialog();

  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _useTyped() {
    final text = _typed.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.pickEmojiTitle),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GridView.extent(
                maxCrossAxisExtent: 48,
                shrinkWrap: true,
                children: [
                  for (final emoji in curatedEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(context, emoji),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typed,
              decoration: InputDecoration(
                labelText: l10n.typeAnyEmoji,
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  onPressed: _useTyped,
                  child: Text(l10n.useEmoji),
                ),
              ),
              onSubmitted: (_) => _useTyped(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
