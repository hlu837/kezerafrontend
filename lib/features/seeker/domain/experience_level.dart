/// Seniority band shown on the employer/agency "Find candidates" filter
/// and (eventually) settable on a seeker's own profile. Mirrors the
/// backend's `EXPERIENCE_LEVEL_KEYS`
/// (`backend/src/utils/experienceLevels.taxonomy.js`) — keep the `key`s
/// (via [wireValue]) in sync with the backend's, since
/// `GET /seekers/search` rejects anything outside that enum.
enum ExperienceLevel {
  entry('entry', 'Entry Level (0–2 yrs)'),
  mid('mid', 'Mid Level (2–5 yrs)'),
  senior('senior', 'Senior Level (5+ yrs)');

  const ExperienceLevel(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ExperienceLevel? fromWire(String? value) {
    if (value == null) return null;
    for (final level in ExperienceLevel.values) {
      if (level.wireValue == value) return level;
    }
    return null;
  }
}
