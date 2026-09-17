/// Formats a seeker's `lastSeenAt` (see `Seeker.lastSeenAt` /
/// `Applicant.lastSeenAt`, sourced server-side from
/// `utils/attachLastSeen.js`) into the short strings the
/// employer/agency-facing candidate screens show — "Online now",
/// "Last seen 3h ago", etc.
library;

/// Below this, a candidate is shown as actively online rather than with
/// a "last seen" timestamp — mirrors the backend's own presence-touch
/// window (see `middleware/auth.middleware.js`'s `LAST_ACTIVE_STALE_MS`),
/// so a candidate who is still within that window reads as "online" on
/// both ends rather than immediately showing a stale-looking timestamp.
const _onlineWindow = Duration(minutes: 5);

/// Returns null when there's nothing to show (never seen), so callers
/// can decide whether to render a fallback like "New candidate" or
/// simply omit the row.
String? formatLastSeen(DateTime? lastSeenAt) {
  if (lastSeenAt == null) {
    return null;
  }

  final diff = DateTime.now().difference(lastSeenAt);

  if (diff <= _onlineWindow) {
    return 'Online now';
  }
  if (diff.inMinutes < 60) {
    return 'Last seen ${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return 'Last seen ${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return 'Last seen ${diff.inDays}d ago';
  }
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return 'Last seen ${weeks}w ago';
  }
  return 'Last seen on ${lastSeenAt.day}/${lastSeenAt.month}/${lastSeenAt.year}';
}

/// Whether [lastSeenAt] falls inside the "online now" window — lets a
/// card show a green dot without re-deriving the threshold logic above.
bool isOnlineNow(DateTime? lastSeenAt) {
  if (lastSeenAt == null) return false;
  return DateTime.now().difference(lastSeenAt) <= _onlineWindow;
}
