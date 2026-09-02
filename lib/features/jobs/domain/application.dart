import 'package:equatable/equatable.dart';

import 'job.dart';

/// Mirrors `src/models/Application.model.js` APPLICATION_STATUSES.
enum ApplicationStatus { applied, viewed, shortlisted, rejected }

ApplicationStatus applicationStatusFromWire(String value) =>
    ApplicationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ApplicationStatus.applied,
    );

/// The seeker fields the employer/agency application list needs, as
/// returned nested under `seeker` by `GET /jobs/:id/applications`
/// (`applications.service.js#getApplicationsForJob`'s populate select).
/// Deliberately its own type rather than reusing the full `Seeker` model
/// — the backend only ever selects this subset (no `userId`/timestamps),
/// so parsing it with `Seeker.fromJson` would throw on the missing
/// required fields.
class Applicant extends Equatable {
  const Applicant({
    required this.id,
    required this.fullName,
    required this.availabilityStatus,
    required this.skills,
    this.city,
    this.photoUrl,
    this.cvUrl,
    this.boostedUntil,
  });

  final String id;
  final String fullName;
  final String? city;
  final List<String> skills;
  final bool availabilityStatus;
  final String? photoUrl;
  // JS-05: the CV that was current on this seeker's profile — either
  // uploaded or built in-app — at the time they applied. Applying is
  // blocked server-side (see applications.service.js#applyToJob) unless
  // a CV is already set, so this is expected to always be present for
  // rows coming back from this endpoint.
  final String? cvUrl;
  final DateTime? boostedUntil;

  bool get isBoosted =>
      boostedUntil != null && boostedUntil!.isAfter(DateTime.now());

  factory Applicant.fromJson(Map<String, dynamic> json) => Applicant(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? 'Unknown candidate',
        city: json['city'] as String?,
        skills: (json['skills'] as List<dynamic>? ?? const [])
            .map((s) => s as String)
            .toList(),
        availabilityStatus: json['availabilityStatus'] as bool? ?? false,
        photoUrl: json['photoUrl'] as String?,
        cvUrl: json['cvUrl'] as String?,
        boostedUntil: json['boostedUntil'] != null
            ? DateTime.parse(json['boostedUntil'] as String)
            : null,
      );

  @override
  List<Object?> get props =>
      [id, fullName, city, skills, availabilityStatus, photoUrl, cvUrl, boostedUntil];
}

/// One row from `GET /jobs/:id/applications` — a seeker's direct "Apply"
/// against this job, with their profile (including CV) nested inline so
/// the employer/agency screen doesn't need a second round trip per row.
class JobApplication extends Equatable {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.status,
    required this.createdAt,
    this.applicant,
  });

  final String id;
  final String jobId;
  final ApplicationStatus status;
  final DateTime createdAt;
  final Applicant? applicant;

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
        id: json['id'] as String,
        jobId: json['jobId'] as String,
        status: applicationStatusFromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        applicant: json['seeker'] != null
            ? Applicant.fromJson(json['seeker'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [id, jobId, status, createdAt, applicant];
}

/// One row from `GET /seekers/me/applications` — the flip side of
/// [JobApplication]: a seeker's own "I applied to this" history, with
/// the job nested inline (`applications.service.js#getMyApplications`
/// populates `jobId` and reshapes it into a `job` key) instead of the
/// applicant. Kept as its own type rather than overloading
/// [JobApplication] with two optional nested objects that are never
/// both present at once.
class MyApplication extends Equatable {
  const MyApplication({
    required this.id,
    required this.status,
    required this.createdAt,
    this.job,
  });

  final String id;
  final ApplicationStatus status;
  final DateTime createdAt;
  final Job? job;

  factory MyApplication.fromJson(Map<String, dynamic> json) => MyApplication(
        id: json['id'] as String,
        status: applicationStatusFromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        job: json['job'] != null
            ? Job.fromJson(json['job'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [id, status, createdAt, job];
}
