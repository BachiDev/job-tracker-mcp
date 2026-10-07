/// Ownership discipline: every query scopes by `user_id` from JWT `sub`.
library;

/// Thrown when code attempts to expose a row to a different user.
/// The server enforces this in SQL (`WHERE user_id = $sub`); this guard is
/// defense-in-depth for decoded rows, and is unit-testable without a DB.
class CrossUserAccess implements Exception {
  CrossUserAccess(this.callerSub);
  final String callerSub;

  @override
  String toString() =>
      'CrossUserAccess: caller does not own the requested row';
}

/// Throws [CrossUserAccess] unless [rowUserId] equals [callerSub].
void requireOwner({required String callerSub, required String rowUserId}) {
  if (callerSub != rowUserId) throw CrossUserAccess(callerSub);
}
