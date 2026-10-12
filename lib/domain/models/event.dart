/// An event such as a trip or a birthday that expenses can be tagged with.
class Event {
  const Event({
    required this.id,
    required this.builtinKey,
    required this.name,
    required this.description,
    required this.emoji,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Set for the seeded events, e.g. `trip`. Null for the user's own.
  final String? builtinKey;

  /// Null means "use the localized built-in name" (see `eventName`).
  final String? name;

  final String? description;

  /// One grapheme, e.g. `🧳`.
  final String emoji;

  /// When the event was archived (hidden from the picker), or null.
  final DateTime? archivedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  /// A copy with the given values replaced. Passing null keeps a value, so
  /// [name], [description] and [archivedAt] can't be cleared here; build a
  /// new [Event] for that (the form does; archiving goes through
  /// `EventRepository.setArchived`).
  Event copyWith({
    String? name,
    String? description,
    String? emoji,
    DateTime? updatedAt,
  }) => Event(
    id: id,
    builtinKey: builtinKey,
    name: name ?? this.name,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
    archivedAt: archivedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Event &&
      other.id == id &&
      other.builtinKey == builtinKey &&
      other.name == name &&
      other.description == description &&
      other.emoji == emoji &&
      other.archivedAt == archivedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    builtinKey,
    name,
    description,
    emoji,
    archivedAt,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Event($id, ${builtinKey ?? '-'}, ${name ?? '-'}, $emoji${isArchived ? ', archived' : ''})';
}
