/// A way of paying, such as cash or a card.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.builtinKey,
    required this.name,
    required this.emoji,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Set for the seeded methods, e.g. `cash`. Null for the user's own.
  final String? builtinKey;

  /// Null means "use the localized built-in name" (see `paymentMethodName`).
  final String? name;

  /// One grapheme, e.g. `💵`.
  final String emoji;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// A copy with the given values replaced. Passing null keeps a value, so
  /// [name] can't be cleared here; build a new [PaymentMethod] for that
  /// (the form does).
  PaymentMethod copyWith({String? name, String? emoji, DateTime? updatedAt}) =>
      PaymentMethod(
        id: id,
        builtinKey: builtinKey,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is PaymentMethod &&
      other.id == id &&
      other.builtinKey == builtinKey &&
      other.name == name &&
      other.emoji == emoji &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, builtinKey, name, emoji, createdAt, updatedAt);

  @override
  String toString() =>
      'PaymentMethod($id, ${builtinKey ?? '-'}, ${name ?? '-'}, $emoji)';
}
