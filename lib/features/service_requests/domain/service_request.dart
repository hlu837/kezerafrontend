import '../../auth/domain/user_model.dart';

/// Mirrors the backend's `SERVICE_REQUEST_TARGET_TYPES`
/// (`ServiceRequest.model.js`). Which kind of profile this request was
/// sent to from the map/directory.
enum ServiceRequestTargetType {
  seeker,
  technician,
  agency;

  static ServiceRequestTargetType fromWire(String value) =>
      ServiceRequestTargetType.values.firstWhere(
        (v) => v.name == value,
        orElse: () => ServiceRequestTargetType.seeker,
      );
}

/// Mirrors the backend's `SERVICE_REQUEST_STATUSES`
/// (`ServiceRequest.model.js`).
enum ServiceRequestStatus {
  pending,
  assigned,
  accepted,
  declined,
  completed,
  cancelled;

  static ServiceRequestStatus fromWire(String value) =>
      ServiceRequestStatus.values.firstWhere(
        (v) => v.name == value,
        orElse: () => ServiceRequestStatus.pending,
      );

  String get label => switch (this) {
        ServiceRequestStatus.pending => 'Pending',
        ServiceRequestStatus.assigned => 'Assigned',
        ServiceRequestStatus.accepted => 'Accepted',
        ServiceRequestStatus.declined => 'Declined',
        ServiceRequestStatus.completed => 'Completed',
        ServiceRequestStatus.cancelled => 'Cancelled',
      };
}

/// "Request Service" — a one-off booking made from the Experts/Agencies
/// map or directory (`POST /service-requests`), deliberately lighter
/// weight than a `Job`/`Placement`/`Application`: no job posting is
/// needed first, see `ServiceRequest.model.js`'s doc comment.
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.requesterId,
    required this.requesterRole,
    required this.targetType,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.createdAt,
    this.targetSeekerId,
    this.targetTechnicianId,
    this.targetAgencyId,
    this.assignedSeekerId,
    this.assignedTechnicianId,
    this.preferredDate,
    this.budget,
  });

  final String id;
  final String requesterId;
  final UserRole requesterRole;
  final ServiceRequestTargetType targetType;
  final String? targetSeekerId;
  final String? targetTechnicianId;
  final String? targetAgencyId;
  final String? assignedSeekerId;
  final String? assignedTechnicianId;
  final String category;
  final String title;
  final String description;
  final String location;
  final DateTime? preferredDate;
  final String? budget;
  final ServiceRequestStatus status;
  final DateTime createdAt;

  factory ServiceRequest.fromJson(Map<String, dynamic> json) => ServiceRequest(
        id: json['id'] as String,
        requesterId: json['requesterId'] as String,
        requesterRole: userRoleFromString(json['requesterRole'] as String),
        targetType: ServiceRequestTargetType.fromWire(json['targetType'] as String),
        targetSeekerId: json['targetSeekerId'] as String?,
        targetTechnicianId: json['targetTechnicianId'] as String?,
        targetAgencyId: json['targetAgencyId'] as String?,
        assignedSeekerId: json['assignedSeekerId'] as String?,
        assignedTechnicianId: json['assignedTechnicianId'] as String?,
        category: json['category'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        location: json['location'] as String,
        preferredDate: json['preferredDate'] != null
            ? DateTime.parse(json['preferredDate'] as String)
            : null,
        budget: json['budget'] as String?,
        status: ServiceRequestStatus.fromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A page of `GET /service-requests/mine` or `.../incoming` — same
/// `{ requests, page, limit, total }` shape both endpoints return.
class ServiceRequestsPage {
  const ServiceRequestsPage({
    required this.requests,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<ServiceRequest> requests;
  final int page;
  final int limit;
  final int total;

  factory ServiceRequestsPage.fromJson(Map<String, dynamic> json) => ServiceRequestsPage(
        requests: (json['requests'] as List<dynamic>)
            .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        limit: json['limit'] as int,
        total: json['total'] as int,
      );
}

/// POST /service-requests body — "Request Service" from the map/detail
/// sheet. Exactly one of [targetSeekerId]/[targetTechnicianId]/
/// [targetAgencyId] is set, matching [targetType] (see
/// `createServiceRequestSchema` on the backend).
class CreateServiceRequestPayload {
  const CreateServiceRequestPayload({
    required this.targetType,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    this.targetSeekerId,
    this.targetTechnicianId,
    this.targetAgencyId,
    this.preferredDate,
    this.budget,
  });

  final ServiceRequestTargetType targetType;
  final String? targetSeekerId;
  final String? targetTechnicianId;
  final String? targetAgencyId;
  final String category;
  final String title;
  final String description;
  final String location;
  final DateTime? preferredDate;
  final String? budget;

  Map<String, dynamic> toJson() => {
        'targetType': targetType.name,
        if (targetType == ServiceRequestTargetType.seeker) 'targetSeekerId': targetSeekerId,
        if (targetType == ServiceRequestTargetType.technician)
          'targetTechnicianId': targetTechnicianId,
        if (targetType == ServiceRequestTargetType.agency) 'targetAgencyId': targetAgencyId,
        'category': category,
        'title': title,
        'description': description,
        'location': location,
        if (preferredDate != null) 'preferredDate': preferredDate!.toIso8601String(),
        if (budget != null && budget!.isNotEmpty) 'budget': budget,
      };
}
