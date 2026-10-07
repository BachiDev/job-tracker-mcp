/// Application stage machine (v1 fixed enum per PLAN §3).
///
/// Stale defaults (days, null = never stale):
/// applied 7d, screening 5d, interview 3d, offer 7d, saved none.
enum AppStage {
  saved,
  applied,
  screening,
  interview,
  offer,
  accepted,
  rejected,
  withdrawn,
}

/// Days after which a stage is considered stale (null = never).
const Map<AppStage, int?> staleAfterDays = {
  AppStage.saved: null,
  AppStage.applied: 7,
  AppStage.screening: 5,
  AppStage.interview: 3,
  AppStage.offer: 7,
  AppStage.accepted: null,
  AppStage.rejected: null,
  AppStage.withdrawn: null,
};

/// Terminal stages: no forward transitions expected.
const Set<AppStage> terminalStages = {
  AppStage.accepted,
  AppStage.rejected,
  AppStage.withdrawn,
};

/// Parse a stage name (exact match, case-sensitive). Returns null if unknown.
AppStage? parseStage(String name) {
  for (final s in AppStage.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// True when the application in [stage] last touched at [touchedAt]
/// is stale as of [now].
bool isStale(AppStage stage, DateTime touchedAt, DateTime now) {
  final days = staleAfterDays[stage];
  if (days == null) return false;
  return now.difference(touchedAt).inDays >= days;
}
