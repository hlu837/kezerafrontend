import 'package:equatable/equatable.dart';

/// Mirrors `src/models/Message.model.js` SENDER_ROLES.
///
/// Denormalized server-side off the sender's role at send time — never
/// something the client sets or sends (see `messaging.service.js#sendMessage`).
enum SenderRole { employer, agency, seeker }

SenderRole senderRoleFromWire(String value) => SenderRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => SenderRole.seeker,
    );

/// A single message in a placement's thread.
///
/// Mirrors `GET/POST /api/v1/placements/:placementId/messages`
/// (`messaging.service.js`). The placement itself is the conversation —
/// there's no separate conversation/thread id.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.placementId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.readAt,
  });

  final String id;
  final String placementId;
  final String senderId;
  final SenderRole senderRole;
  final String body;

  /// Null until the *other* participant opens the thread — see
  /// `messaging.service.js#listMessages`. There's deliberately no
  /// separate mark-as-read endpoint.
  final DateTime? readAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUnread => readAt == null;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        placementId: json['placementId'] as String,
        senderId: json['senderId'] as String,
        senderRole: senderRoleFromWire(json['senderRole'] as String),
        body: json['body'] as String,
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  /// Full round-trip serialization. Note: `POST .../messages` itself only
  /// accepts `{ body }` on the wire (see `sendMessageSchema`) — the rest of
  /// these fields are server-derived — so `AtsRepository.sendMessage` does
  /// not use this method to build its request payload.
  Map<String, dynamic> toJson() => {
        'id': id,
        'placementId': placementId,
        'senderId': senderId,
        'senderRole': senderRole.name,
        'body': body,
        'readAt': readAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        placementId,
        senderId,
        senderRole,
        body,
        readAt,
        createdAt,
        updatedAt,
      ];
}
