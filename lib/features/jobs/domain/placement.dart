import 'package:equatable/equatable.dart';

/// Mirrors `src/models/Placement.model.js` PLACEMENT_STATUSES.
enum PlacementStatus { matched, sent, interviewed, hired, rejected }

PlacementStatus placementStatusFromWire(String value) =>
    PlacementStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PlacementStatus.matched,
    );

/// Flattened shape returned by `GET /jobs/:id/suggested-seekers`
/// (`placements.service.js#getSuggestedSeekers`) — placement fields plus
/// the joined seeker's public profile fields. `jobTitle` isn't part of the
/// wire response; it's stitched on client-side once fetched per-job, same
/// as the web backoffice's `PlacementRow` in `agency/placements/page.tsx`.
class SuggestedSeeker extends Equatable {
  const SuggestedSeeker({
    required this.placementId,
    required this.jobId,
    required this.status,
    required this.skills,
    required this.createdAt,
    required this.jobTitle,
    this.seekerId,
    this.agencyId,
    this.score,
    this.fullName,
    this.city,
    this.cvUrl,
    this.photoUrl,
  });

  final String placementId;
  final String jobId;
  final String? seekerId;
  final String? agencyId;
  final PlacementStatus status;
  final double? score;
  final DateTime createdAt;
  final String? fullName;
  final String? city;
  final List<String> skills;
  final String? cvUrl;
  final String? photoUrl;

  /// Stitched on after fetch — not part of the wire payload.
  final String jobTitle;

  factory SuggestedSeeker.fromJson(
    Map<String, dynamic> json, {
    required String jobTitle,
  }) =>
      SuggestedSeeker(
        placementId: json['placementId'] as String,
        jobId: json['jobId'] as String,
        seekerId: json['seekerId'] as String?,
        agencyId: json['agencyId'] as String?,
        status: placementStatusFromWire(json['status'] as String),
        score: (json['score'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        fullName: json['fullName'] as String?,
        city: json['city'] as String?,
        skills: (json['skills'] as List<dynamic>? ?? const [])
            .map((s) => s as String)
            .toList(),
        cvUrl: json['cvUrl'] as String?,
        photoUrl: json['photoUrl'] as String?,
        jobTitle: jobTitle,
      );

  SuggestedSeeker copyWith({PlacementStatus? status}) => SuggestedSeeker(
        placementId: placementId,
        jobId: jobId,
        seekerId: seekerId,
        agencyId: agencyId,
        status: status ?? this.status,
        score: score,
        createdAt: createdAt,
        fullName: fullName,
        city: city,
        skills: skills,
        cvUrl: cvUrl,
        photoUrl: photoUrl,
        jobTitle: jobTitle,
      );

  @override
  List<Object?> get props => [
        placementId,
        jobId,
        seekerId,
        agencyId,
        status,
        score,
        createdAt,
        fullName,
        city,
        skills,
        cvUrl,
        photoUrl,
        jobTitle,
      ];
}

/// The seeker's own view of one of their placements, as returned by
/// `GET /seekers/me/placements` (`seeker.service.js#getMyPlacements`) —
/// the job side of the match, since (unlike `SuggestedSeeker`) the caller
/// already knows who *they* are; what they need is which job and whether
/// they can message about it (`/placements/:placementId/messages`, open
/// to any participant — see `utils/placementAccess.js`).
class MyPlacement extends Equatable {
  const MyPlacement({
    required this.placementId,
    required this.status,
    required this.createdAt,
    this.jobId,
    this.jobTitle,
    this.jobLocation,
    this.jobType,
  });

  final String placementId;
  final String? jobId;
  final String? jobTitle;
  final String? jobLocation;
  final String? jobType;
  final PlacementStatus status;
  final DateTime createdAt;

  factory MyPlacement.fromJson(Map<String, dynamic> json) => MyPlacement(
        placementId: json['placementId'] as String,
        jobId: json['jobId'] as String?,
        jobTitle: json['jobTitle'] as String?,
        jobLocation: json['jobLocation'] as String?,
        jobType: json['jobType'] as String?,
        status: placementStatusFromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [
        placementId,
        jobId,
        jobTitle,
        jobLocation,
        jobType,
        status,
        createdAt,
      ];
}
