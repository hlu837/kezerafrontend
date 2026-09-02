import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_item.dart';

/// One page of `GET /notifications`, plus the unread count returned
/// alongside it (same round trip refreshes both the list and the
/// bell's badge — see `notification.service.js#listForUser`).
class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.total,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;
}

/// Talks to `/api/v1/notifications` — the in-app notification feed
/// shared by every role (seeker, employer, agency, admin); scoping to
/// "whoever is signed in" happens server-side off the JWT, not off any
/// role-specific path segment, so this repository has no seeker-only
/// naming despite currently only being wired up on the seeker side.
class NotificationsRepository {
  NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /notifications?page=&limit=&unread_only=
  Future<NotificationPage> fetchNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: {
            'page': page,
            'limit': limit,
            'unread_only': unreadOnly,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        final notifications = (data['notifications'] as List<dynamic>)
            .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
            .toList();
        return NotificationPage(
          notifications: notifications,
          total: data['total'] as int? ?? notifications.length,
          unreadCount: data['unreadCount'] as int? ?? 0,
        );
      });

  /// GET /notifications/unread-count — cheap poll for the bell badge,
  /// without pulling the full feed.
  Future<int> fetchUnreadCount() => _guard(() async {
        final response =
            await _apiClient.dio.get<Map<String, dynamic>>('/notifications/unread-count');
        final data = response.data!['data'] as Map<String, dynamic>;
        return data['unreadCount'] as int? ?? 0;
      });

  /// PATCH /notifications/:id/read
  Future<void> markAsRead(String notificationId) => _guard(() async {
        await _apiClient.dio.patch<Map<String, dynamic>>('/notifications/$notificationId/read');
      });

  /// PATCH /notifications/read-all
  Future<void> markAllAsRead() => _guard(() async {
        await _apiClient.dio.patch<Map<String, dynamic>>('/notifications/read-all');
      });

  /// DELETE /notifications — clears the signed-in user's entire feed.
  Future<void> deleteAll() => _guard(() async {
        await _apiClient.dio.delete<Map<String, dynamic>>('/notifications');
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is ApiException) throw apiError;
      throw ApiException(message: e.message ?? 'Something went wrong.');
    }
  }
}
