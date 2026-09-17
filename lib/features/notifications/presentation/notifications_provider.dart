import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_item.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

/// How often the bell badge and the open notification feed poll for
/// new activity. There's no push/websocket transport anywhere in this
/// app (SMS/email cover the "you're not currently looking at the app"
/// case), so a lightweight poll on the existing cheap
/// `/notifications/unread-count` endpoint is what makes a new message
/// or event actually feel real-time instead of only showing up after
/// the user happens to navigate through the notifications screen.
const _pollInterval = Duration(seconds: 20);

/// The bell icon's badge count. Self-polling: every time the future
/// resolves, it schedules its own re-invalidation, so as long as
/// something in the tree keeps watching this (the shell header always
/// does, for every authenticated role), the badge keeps itself current
/// without the user needing to do anything. `ref.invalidate` after a
/// mark-read action still works exactly as before — it just short-
/// circuits the wait for the next scheduled tick.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) {
  final timer = Timer(_pollInterval, () {
    // Only reschedule if something is still watching — invalidating a
    // provider nobody's listening to would just have it recompute once
    // and immediately go idle again, but this keeps the loop honest if
    // that ever changes.
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return ref.watch(notificationsRepositoryProvider).fetchUnreadCount();
});

/// The full notification feed shown on `NotificationsScreen`. A
/// [StateNotifier] (not a plain `FutureProvider`) since the screen also
/// mutates it in place — marking one or all notifications read updates
/// the list optimistically instead of forcing a full refetch.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) {
  return NotificationsNotifier(ref)..load();
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsNotifier(this._ref) : super(const AsyncValue.loading()) {
    // While the feed screen is actually open, poll it directly too —
    // not just the badge count — so a message that arrives while the
    // user is looking at the list shows up without a manual pull-to-
    // refresh. Stops the moment the screen (and this notifier) is
    // disposed.
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshInBackground());
  }

  final Ref _ref;
  Timer? _pollTimer;

  NotificationsRepository get _repository => _ref.read(notificationsRepositoryProvider);

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final page = await _repository.fetchNotifications();
      state = AsyncValue.data(page.notifications);
      _ref.invalidate(unreadNotificationsCountProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Same fetch as [load], but silent: never flips the state to
  /// `AsyncValue.loading()` (which would blank the list and spinner-
  /// flash every 20s) and never surfaces an error state on failure — a
  /// background poll that misses once just tries again next tick.
  Future<void> _refreshInBackground() async {
    if (!mounted) return;
    try {
      final page = await _repository.fetchNotifications();
      if (!mounted) return;
      state = AsyncValue.data(page.notifications);
      _ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // Silent by design — see doc comment above.
    }
  }

  /// Marks a single notification read — optimistic, since this is
  /// usually fired by the user tapping the row to navigate away from
  /// the screen, and a failed PATCH shouldn't block that navigation or
  /// visibly revert the row underneath them.
  Future<void> markAsRead(String notificationId) async {
    final current = state.value;
    if (current == null) return;

    final alreadyRead = current
        .firstWhere((n) => n.id == notificationId, orElse: () => current.first)
        .isRead;
    if (alreadyRead) return;

    state = AsyncValue.data([
      for (final notification in current)
        if (notification.id == notificationId)
          notification.copyWith(isRead: true)
        else
          notification,
    ]);

    try {
      await _repository.markAsRead(notificationId);
    } finally {
      _ref.invalidate(unreadNotificationsCountProvider);
    }
  }

  /// "Mark all as read" toolbar action.
  Future<void> markAllAsRead() async {
    final current = state.value;
    if (current == null || current.every((n) => n.isRead)) return;

    state = AsyncValue.data([
      for (final notification in current) notification.copyWith(isRead: true),
    ]);

    try {
      await _repository.markAllAsRead();
    } finally {
      _ref.invalidate(unreadNotificationsCountProvider);
    }
  }

  /// Trash-icon toolbar action — clears the whole feed. Optimistic like
  /// the other actions here, so the list empties immediately rather
  /// than waiting on the round trip.
  Future<void> deleteAll() async {
    final current = state.value;
    if (current == null || current.isEmpty) return;

    state = const AsyncValue.data([]);

    try {
      await _repository.deleteAll();
    } finally {
      _ref.invalidate(unreadNotificationsCountProvider);
    }
  }
}
