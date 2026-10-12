/// An expense category.
class Category {
  const Category({
    required this.id,
    required this.builtinKey,
    required this.name,
    required this.description,
    required this.emoji,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Set for the seeded categories, e.g. `food`. Null for the user's own.
  final String? builtinKey;

  /// Null means "use the localized built-in name" (see `categoryName`).
  final String? name;

  final String? description;

  /// One grapheme, e.g. `🍽️`.
  final String emoji;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// A copy with the given values replaced. Passing null keeps a value, so
  /// [name] and [description] can't be cleared here; build a new [Category]
  /// for that (the form does).
  Category copyWith({
    String? name,
    String? description,
    String? emoji,
    DateTime? updatedAt,
  }) => Category(
    id: id,
    builtinKey: builtinKey,
    name: name ?? this.name,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.builtinKey == builtinKey &&
      other.name == name &&
      other.description == description &&
      other.emoji == emoji &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    builtinKey,
    name,
    description,
    emoji,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Category($id, ${builtinKey ?? '-'}, ${name ?? '-'}, $emoji)';
}
