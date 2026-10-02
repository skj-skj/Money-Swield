import 'package:characters/characters.dart';

import '../../l10n/app_localizations.dart';

// Validation shared by the category, event and payment method forms
// (phase-1.md §8). Lengths count graphemes (what the user sees as one
// character), so an emoji or a Hindi conjunct counts once.

const maxNameLength = 40;
const maxDescriptionLength = 200;

enum NameError { required, tooLong, duplicate }

enum EmojiError { required, notSingle }

enum DescriptionError { tooLong }

/// Checks a name against the display names of the other rows of the same
/// table ([otherNames], the row being edited excluded). Duplicates are found
/// case-insensitively and ignoring surrounding spaces.
NameError? validateName(String name, Iterable<String> otherNames) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return NameError.required;
  if (trimmed.characters.length > maxNameLength) return NameError.tooLong;
  final lower = trimmed.toLowerCase();
  if (otherNames.any((other) => other.trim().toLowerCase() == lower)) {
    return NameError.duplicate;
  }
  return null;
}

/// An emoji must be exactly one grapheme, e.g. `👨‍👩‍👧` (several code
/// points) is fine, `🍕🍔` is not.
EmojiError? validateEmoji(String emoji) {
  final trimmed = emoji.trim();
  if (trimmed.isEmpty) return EmojiError.required;
  if (trimmed.characters.length != 1) return EmojiError.notSingle;
  return null;
}

DescriptionError? validateDescription(String description) =>
    description.trim().characters.length > maxDescriptionLength
    ? DescriptionError.tooLong
    : null;

/// The description to store: trimmed, and null when empty.
String? descriptionToStore(String description) {
  final trimmed = description.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The message shown under the name field for [error].
String? nameErrorText(AppLocalizations l10n, NameError? error, String name) =>
    switch (error) {
      null => null,
      NameError.required => l10n.errorNameRequired,
      NameError.tooLong => l10n.errorTooLong(maxNameLength),
      NameError.duplicate => l10n.errorNameDuplicate(name.trim()),
    };

String? emojiErrorText(AppLocalizations l10n, EmojiError? error) =>
    switch (error) {
      null => null,
      EmojiError.required => l10n.errorEmojiRequired,
      EmojiError.notSingle => l10n.errorEmojiNotSingle,
    };

String? descriptionErrorText(AppLocalizations l10n, DescriptionError? error) =>
    switch (error) {
      null => null,
      DescriptionError.tooLong => l10n.errorTooLong(maxDescriptionLength),
    };
