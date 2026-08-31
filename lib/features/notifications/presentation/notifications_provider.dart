import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_item.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

/// The bell icon's badge count. A plain `FutureProvider` — cheap enough
/// to `ref.invalidate` after every mark-read action, and the shell
/// header rebuilds automatically wherever it's watched.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) {
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
  NotificationsNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  NotificationsRepository get _repository => _ref.read(notificationsRepositoryProvider);

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
