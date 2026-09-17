import '../../seeker/domain/experience_level.dart';
import '../../seeker/domain/seeker.dart';

/// A picked file's bytes + filename, decoupled from `file_picker`'s own
/// `PlatformFile` type so the repository/data layer doesn't need to know
/// about the picker package. Bytes (not a path) work on every platform
/// `file_picker` supports, including web, where there is no filesystem
/// path to read from.
class WalkInAttachment {
  const WalkInAttachment({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

/// POST /agencies/walk-in — sent as multipart/form-data since it can carry
/// optional cv/photo attachments (see `agency.routes.js`). Every non-file
/// field arrives on the backend as a plain string, hence `skills` being a
/// comma-joined string here rather than a list — mirrors
/// `types/agency.ts`'s `WalkInPayload` / `walkInSchema`'s custom parser.
class WalkInPayload {
  const WalkInPayload({
    required this.fullName,
    required this.phone,
    this.email,
    this.city,
    this.bio,
    this.skills = const [],
    this.experienceLevel,
    this.preferredCategories = const [],
  });

  final String fullName;
  final String phone;
  final String? email;
  final String? city;
  final String? bio;
  final List<String> skills;
  // Wire format matches `skills`/`walkInSchema#experience_level` /
  // `#preferred_categories` on the backend — see agency.validator.js.
  final ExperienceLevel? experienceLevel;
  final List<String> preferredCategories;

  Map<String, String> toFields() => {
        'full_name': fullName,
        'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email!,
        if (city != null && city!.isNotEmpty) 'city': city!,
        if (bio != null && bio!.isNotEmpty) 'bio': bio!,
        if (skills.isNotEmpty) 'skills': skills.join(','),
        if (experienceLevel != null) 'experience_level': experienceLevel!.wireValue,
        if (preferredCategories.isNotEmpty)
          'preferred_categories': preferredCategories.join(','),
      };
}

/// Just the bit of the response the walk-in screen actually needs — the
/// full envelope also returns the created `user`, but the success message
/// only shows the registered candidate's name.
class WalkInResult {
  const WalkInResult({required this.fullName});

  final String fullName;

  factory WalkInResult.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>;
    return WalkInResult(fullName: profile['fullName'] as String? ?? '');
  }
}

/// POST /agencies/dispatch — sends a shortlist of matched candidates to
/// the job's poster. Mirrors `types/agency.ts`'s `DispatchPayload`.
class DispatchPayload {
  const DispatchPayload({required this.jobId, required this.seekerIds});

  final String jobId;
  final List<String> seekerIds;

  Map<String, dynamic> toJson() => {
        'job_id': jobId,
        'seeker_ids': seekerIds,
      };
}

/// GET /agencies/candidates query params — this agency's own roster
/// (every `Seeker` whose `agencyId` points at this agency, i.e. every
/// walk-in it has registered), mirrors `listCandidatesSchema` on the
/// backend. Unlike `SearchSeekersParams` (the public "Find candidates"
/// search) this isn't restricted to available seekers by default, so
/// [availabilityStatus] is a nullable tri-state (all / available /
/// unavailable) rather than always-true.
class AgencyCandidatesParams {
  const AgencyCandidatesParams({
    this.keyword,
    this.city,
    this.experienceLevel,
    this.availabilityStatus,
    this.page = 1,
    this.limit = 20,
  });

  final String? keyword;
  final String? city;
  final ExperienceLevel? experienceLevel;
  final bool? availabilityStatus;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (experienceLevel != null) 'experience_level': experienceLevel!.wireValue,
        if (availabilityStatus != null) 'availability_status': availabilityStatus,
        'page': page,
        'limit': limit,
      };

  /// [clearAvailabilityStatus] lets the filter reset the tri-state back
  /// to "All" — same reasoning as `SearchSeekersParams.copyWith`'s
  /// `clearCategory`: a plain `copyWith` can't tell "leave unchanged"
  /// apart from "set back to null" since both look like a null argument.
  AgencyCandidatesParams copyWith({
    String? keyword,
    String? city,
    ExperienceLevel? experienceLevel,
    bool clearExperienceLevel = false,
    bool? availabilityStatus,
    bool clearAvailabilityStatus = false,
    int? page,
  }) =>
      AgencyCandidatesParams(
        keyword: keyword ?? this.keyword,
        city: city ?? this.city,
        experienceLevel: clearExperienceLevel
            ? null
            : (experienceLevel ?? this.experienceLevel),
        availabilityStatus: clearAvailabilityStatus
            ? null
            : (availabilityStatus ?? this.availabilityStatus),
        page: page ?? this.page,
        limit: limit,
      );
}

/// GET /agencies/candidates response. Each row is wire-identical to a
/// `GET /seekers/search` row (both are `Seeker.toJSON()` plus
/// `lastSeenAt` — see `utils/attachLastSeen.js`), so it's parsed with
/// the existing [Seeker] model rather than a separate one, and a roster
/// row can be handed straight to `CandidateDetailScreen` unchanged.
class AgencyCandidatesResult {
  const AgencyCandidatesResult({
    required this.candidates,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<Seeker> candidates;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory AgencyCandidatesResult.fromJson(Map<String, dynamic> json) =>
      AgencyCandidatesResult(
        candidates: (json['candidates'] as List<dynamic>)
            .map((s) => Seeker.fromJson(s as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        limit: json['limit'] as int,
        total: json['total'] as int,
        totalPages: json['totalPages'] as int,
      );
}

/// Mirrors `src/models/Agency.model.js`'s `toJSON()` output — the agency
/// account screen's profile view/edit. Analogous to `Employer`
/// (features/employer/domain/employer.dart), fetched/edited via
/// `AgencyRepository`.
class AgencyProfile {
  const AgencyProfile({
    required this.id,
    required this.userId,
    required this.agencyName,
    required this.createdAt,
    required this.updatedAt,
    this.operationalCity,
    this.backofficePhone,
    this.address,
    this.tinNumber,
    this.businessLicenseUrl,
    this.bio,
    this.logoUrl,
    this.foundedYear,
    this.subscriptionTier = SubscriptionTier.basic,
  });

  final String id;
  final String userId;
  final String agencyName;
  final String? operationalCity;
  final String? backofficePhone;
  // Physical office address, shown alongside backofficePhone in the
  // public "Find agencies near you" quick-view sheet.
  final String? address;
  // Verification-time fields — set at registration, not editable from
  // the account screen (see agency.validator.js's updateProfileSchema,
  // which only accepts
  // agency_name/operational_city/backoffice_phone/address/bio/founded_year).
  final String? tinNumber;
  final String? businessLicenseUrl;
  // Public-profile fields. `bio` is self-editable via POST
  // /agencies/profile; `logoUrl` is only ever set server-side via
  // POST /agencies/logo (see AgencyRepository.uploadLogo). Having
  // either one is what satisfies the backend's "complete public
  // profile" gate on posting a job — see [hasPublicProfile].
  final String? bio;
  final String? logoUrl;
  // The year the agency itself was founded — shown as "X years in
  // business" on the directory card/public profile (see
  // Agency.model.js#foundedYear). Null when the agency hasn't set
  // this, same optional/degrade-gracefully treatment as bio/logoUrl.
  final int? foundedYear;
  final SubscriptionTier subscriptionTier;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Mirrors the backend's agency.service.js#hasPublicProfile — used to
  /// show a "complete your profile" nudge before the agency hits the
  /// hard block on posting a job for the first time.
  bool get hasPublicProfile =>
      (bio != null && bio!.trim().isNotEmpty) ||
      (logoUrl != null && logoUrl!.isNotEmpty);

  factory AgencyProfile.fromJson(Map<String, dynamic> json) => AgencyProfile(
        id: json['id'] as String,
        userId: json['userId'] as String,
        agencyName: json['agencyName'] as String,
        operationalCity: json['operationalCity'] as String?,
        backofficePhone: json['backofficePhone'] as String?,
        address: json['address'] as String?,
        tinNumber: json['tinNumber'] as String?,
        businessLicenseUrl: json['businessLicenseUrl'] as String?,
        bio: json['bio'] as String?,
        logoUrl: json['logoUrl'] as String?,
        foundedYear: json['foundedYear'] as int?,
        subscriptionTier:
            SubscriptionTier.fromWire(json['subscriptionTier'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

