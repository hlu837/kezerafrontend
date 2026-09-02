import 'package:equatable/equatable.dart';

/// Mirrors `src/models/Interview.model.js` INTERVIEW_MODES.
enum InterviewMode { inPerson, phone, video }

extension InterviewModeWire on InterviewMode {
  /// The exact string the backend sends/expects — not a Dart-style name.
  String get wireValue {
    switch (this) {
      case InterviewMode.inPerson:
        return 'in_person';
      case InterviewMode.phone:
        return 'phone';
      case InterviewMode.video:
        return 'video';
    }
  }
}

InterviewMode interviewModeFromWire(String value) =>
    InterviewMode.values.firstWhere(
      (mode) => mode.wireValue == value,
      orElse: () => InterviewMode.video,
    );

/// Mirrors `src/models/Interview.model.js` INTERVIEW_STATUSES.
///
/// 'scheduled' is the only non-terminal status — both 'completed' and
/// 'cancelled' are endpoints (see `INTERVIEW_STATUS_TRANSITIONS` on the
/// backend model).
enum InterviewStatus { scheduled, completed, cancelled }

InterviewStatus interviewStatusFromWire(String value) =>
    InterviewStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InterviewStatus.scheduled,
    );

/// One interview round for a [Placement]. Many-to-one with placement — a
/// candidate can go through multiple rounds, each its own [Interview].
///
/// Mirrors `POST/GET /api/v1/placements/:placementId/interviews` and the
/// id-keyed mutation endpoints `PATCH /api/v1/interviews/:id` (reschedule)
/// and `PATCH /api/v1/interviews/:id/status`.
class Interview extends Equatable {
  const Interview({
    required this.id,
    required this.placementId,
    required this.jobId,
    required this.seekerId,
    required this.scheduledById,
    required this.scheduledFor,
    required this.mode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.notes,
  });

  final String id;
  final String placementId;
  final String jobId;
  final String seekerId;
  final String scheduledById;
  final DateTime scheduledFor;
  final InterviewMode mode;

  /// Address for in_person, dial-in number for phone, meeting link for
  /// video — kept as free text since the shape differs per mode (matches
  /// the backend's own comment on `Interview.model.js`).
  final String? location;

  final String? notes;
  final InterviewStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Interview.fromJson(Map<String, dynamic> json) => Interview(
        id: json['id'] as String,
        placementId: json['placementId'] as String,
        jobId: json['jobId'] as String,
        seekerId: json['seekerId'] as String,
        scheduledById: json['scheduledById'] as String,
        scheduledFor: DateTime.parse(json['scheduledFor'] as String),
        mode: interviewModeFromWire(json['mode'] as String),
        location: json['location'] as String?,
        notes: json['notes'] as String?,
        status: interviewStatusFromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  /// Full round-trip serialization. `AtsRepository` builds its own
  /// narrower request bodies for reschedule/status-update rather than
  /// using this, since each endpoint accepts a different field subset
  /// (see `rescheduleInterviewSchema` / `updateInterviewStatusSchema`).
  Map<String, dynamic> toJson() => {
        'id': id,
        'placementId': placementId,
        'jobId': jobId,
        'seekerId': seekerId,
        'scheduledById': scheduledById,
        'scheduledFor': scheduledFor.toIso8601String(),
        'mode': mode.wireValue,
        'location': location,
        'notes': notes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Interview copyWith({
    DateTime? scheduledFor,
    InterviewMode? mode,
    String? location,
    String? notes,
    InterviewStatus? status,
  }) =>
      Interview(
        id: id,
        placementId: placementId,
        jobId: jobId,
        seekerId: seekerId,
        scheduledById: scheduledById,
        scheduledFor: scheduledFor ?? this.scheduledFor,
        mode: mode ?? this.mode,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        placementId,
        jobId,
        seekerId,
        scheduledById,
        scheduledFor,
        mode,
        location,
        notes,
        status,
        createdAt,
        updatedAt,
      ];
}
