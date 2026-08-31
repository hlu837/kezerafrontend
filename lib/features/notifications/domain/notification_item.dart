import 'package:equatable/equatable.dart';

/// Mirrors `backend-clean/src/models/Notification.model.js`'s
/// `NOTIFICATION_TYPES`. Used to pick an icon/color and to decide
/// where tapping a notification should navigate.
enum NotificationType {
  jobMatch,
  jobAlert,
  interviewScheduled,
  interviewRescheduled,
  interviewCancelled,
  newMessage,
  newApplication,
  unknown,
}

NotificationType notificationTypeFromWire(String value) {
  switch (value) {
    case 'job_match':
      return NotificationType.jobMatch;
    case 'job_alert':
      return NotificationType.jobAlert;
    case 'interview_scheduled':
      return NotificationType.interviewScheduled;
    case 'interview_rescheduled':
      return NotificationType.interviewRescheduled;
    case 'interview_cancelled':
      return NotificationType.interviewCancelled;
    case 'new_message':
      return NotificationType.newMessage;
    case 'new_application':
      return NotificationType.newApplication;
    default:
      return NotificationType.unknown;
  }
}

/// NOTIF-01: a single row from `GET /notifications` — the seeker's
/// in-app feed behind the bell icon. `data` carries whatever
/// deep-link IDs the backend attached for this `type` (e.g. `jobId`,
/// `placementId`), kept as a raw map since its shape varies by type
/// and the screen only reads the keys it needs.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: notificationTypeFromWire(json['type'] as String? ?? ''),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        data: (json['data'] as Map<String, dynamic>?) ?? const {},
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        data: data,
      );

  @override
  List<Object?> get props => [id, type, title, body, isRead, createdAt, data];
}
