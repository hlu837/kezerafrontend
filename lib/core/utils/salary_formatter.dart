/// Prefixes a job's free-text salary range with "ETB" when the poster
/// didn't already include a currency. `PostJobScreen`'s salary field only
/// *hints* at "e.g. ETB 8,000 – 12,000 / month" — it doesn't enforce it —
/// so plenty of listings are just "8,000 - 12,000" with no currency at
/// all. Every job on this board is ETB-denominated (no multi-currency
/// support anywhere else in the app), so this is a safe default rather
/// than a guess. Case-insensitive check so a range that already says
/// "ETB" (any casing) isn't double-prefixed.
///
/// Used everywhere a job's `salaryRange` is shown or shared — job cards,
/// the job detail screen, and both of their "share this job" texts —
/// rather than each caller re-deciding whether to prefix it.
String formatSalary(String raw) {
  final trimmed = raw.trim();
  return trimmed.toLowerCase().contains('etb') ? trimmed : 'ETB $trimmed';
}
