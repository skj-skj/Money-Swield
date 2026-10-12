/// How many rows use a category or payment method: expenses, `active` and
/// `binned`, and recurring items, running and archived (`templates`). Every one
/// of them blocks the delete (RESTRICT) and is moved by "Move and delete".
typedef OwnerUsage = ({int active, int binned, int templates});

/// Nothing uses it: a plain confirm, then delete.
bool isUnused(OwnerUsage usage) =>
    usage.active + usage.binned + usage.templates == 0;
