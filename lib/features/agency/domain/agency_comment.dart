import 'package:equatable/equatable.dart';

/// GET /agencies/:agencyId/profile — the public bio/logo/name a seeker
/// (or anyone else) sees on an agency's profile page, before deciding
/// whether to apply through it or comment on it. A trimmed-down,
/// read-only counterpart to `AgencyProfile` (which is the agency's own
/// backoffice view of the same record, plus fields no one else may see).
class AgencyPublicProfile extends Equatable {
  const AgencyPublicProfile({
    required this.id,
    required this.agencyName,
    this.operationalCity,
    this.bio,
    this.logoUrl,
    this.candidateCount = 0,
    this.foundedYear,
  });

  /// The agency's *User* id — same value as `Job.creatorId` on any job
  /// this agency has posted, so a job listing can link straight here.
  final String id;
  final String agencyName;
  final String? operationalCity;
  final String? bio;
  final String? logoUrl;

  /// Every seeker registered under this agency — mirrors
  /// `AgencyDirectoryEntry.candidateCount` below.
  final int candidateCount;

  /// The year this agency was founded, self-reported — null if unset.
  final int? foundedYear;

  /// How many years since [foundedYear], or null if that's unset.
  int? get yearsInBusiness => foundedYear == null ? null : DateTime.now().year - foundedYear!;

  factory AgencyPublicProfile.fromJson(Map<String, dynamic> json) =>
      AgencyPublicProfile(
        id: json['id'] as String,
        agencyName: json['agencyName'] as String,
        operationalCity: json['operationalCity'] as String?,
        bio: json['bio'] as String?,
        logoUrl: json['logoUrl'] as String?,
        candidateCount: json['candidateCount'] as int? ?? 0,
        foundedYear: json['foundedYear'] as int?,
      );

  @override
  List<Object?> get props =>
      [id, agencyName, operationalCity, bio, logoUrl, candidateCount, foundedYear];
}

/// One row in the public agency directory (GET /agencies) — the
/// "Agencies" tab on the landing page. A trimmed-down [AgencyPublicProfile]
/// plus the key stats a visitor scans before drilling into a profile:
/// how many open roles it's currently recruiting for, and however much
/// of a track record it has on [AgencyComment]s.
class AgencyDirectoryEntry extends Equatable {
  const AgencyDirectoryEntry({
    required this.id,
    required this.agencyName,
    required this.openJobsCount,
    required this.commentsCount,
    this.operationalCity,
    this.bio,
    this.logoUrl,
    this.averageRating,
    this.candidateCount = 0,
    this.foundedYear,
  });

  /// The agency's *User* id — same value `Job.creatorId` carries on any
  /// job this agency has posted, so tapping a card can open
  /// `AgencyProfileScreen` (and from there, this agency's job list)
  /// without a separate lookup.
  final String id;
  final String agencyName;
  final String? operationalCity;
  final String? bio;
  final String? logoUrl;

  /// Every currently-`open` job this agency has posted — same count
  /// `AgencyProfileScreen`'s own "Jobs" section would show.
  final int openJobsCount;
  final double? averageRating;
  final int commentsCount;

  /// Every seeker registered under this agency (walk-ins plus any
  /// self-registered seeker an agency later claims) — the "total
  /// registered candidates/workers" stat on the directory card.
  final int candidateCount;

  /// The year this agency was founded, as it self-reported it (see
  /// Agency.model.js#foundedYear) — null when never set, in which case
  /// the "years in business" stat is simply omitted from the card.
  final int? foundedYear;

  /// How many years since [foundedYear], or null if that's unset.
  int? get yearsInBusiness => foundedYear == null ? null : DateTime.now().year - foundedYear!;

  factory AgencyDirectoryEntry.fromJson(Map<String, dynamic> json) =>
      AgencyDirectoryEntry(
        id: json['id'] as String,
        agencyName: json['agencyName'] as String,
        operationalCity: json['operationalCity'] as String?,
        bio: json['bio'] as String?,
        logoUrl: json['logoUrl'] as String?,
        openJobsCount: json['openJobsCount'] as int? ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        commentsCount: json['commentsCount'] as int? ?? 0,
        candidateCount: json['candidateCount'] as int? ?? 0,
        foundedYear: json['foundedYear'] as int?,
      );

  @override
  List<Object?> get props => [
        id,
        agencyName,
        operationalCity,
        bio,
        logoUrl,
        openJobsCount,
        averageRating,
        commentsCount,
        candidateCount,
        foundedYear,
      ];
}

/// GET /agencies/nearby query params — "Find agencies near you". Mirrors
/// `NearbySeekersParams` (seeker.dart) minus the skills/category/trade
/// filters, which have no agency equivalent.
class NearbyAgenciesParams {
  const NearbyAgenciesParams({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 15,
    this.limit = 50,
  });

  final double latitude;
  final double longitude;
  final double radiusKm;
  final int limit;

  Map<String, dynamic> toQuery() => {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'limit': limit,
      };

  NearbyAgenciesParams copyWith({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) =>
      NearbyAgenciesParams(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        radiusKm: radiusKm ?? this.radiusKm,
        limit: limit,
      );
}

/// One row of a `GET /agencies/nearby` response. Field names match
/// [AgencyDirectoryEntry] (agency_comment.dart) deliberately — `id` is
/// the agency's *User* id, same convention every other public agency
/// route uses — plus the coordinates and straight-line `distanceKm`
/// that only make sense in the context of a single nearby search, so
/// they don't belong on [AgencyDirectoryEntry] itself.
class NearbyAgency extends Equatable {
  const NearbyAgency({
    required this.id,
    required this.agencyName,
    required this.openJobsCount,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.operationalCity,
    this.bio,
    this.logoUrl,
    this.backofficePhone,
    this.address,
  });

  final String id;
  final String agencyName;
  final String? operationalCity;
  final String? bio;
  final String? logoUrl;
  final String? backofficePhone;
  final String? address;
  final int openJobsCount;
  final double latitude;
  final double longitude;
  final double distanceKm;

  factory NearbyAgency.fromJson(Map<String, dynamic> json) => NearbyAgency(
        id: json['id'] as String,
        agencyName: json['agencyName'] as String,
        operationalCity: json['operationalCity'] as String?,
        bio: json['bio'] as String?,
        logoUrl: json['logoUrl'] as String?,
        backofficePhone: json['backofficePhone'] as String?,
        address: json['address'] as String?,
        openJobsCount: json['openJobsCount'] as int? ?? 0,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        agencyName,
        operationalCity,
        bio,
        logoUrl,
        backofficePhone,
        address,
        openJobsCount,
        latitude,
        longitude,
        distanceKm,
      ];
}

class NearbyAgenciesResult {
  const NearbyAgenciesResult({
    required this.agencies,
    required this.count,
    required this.radiusKm,
  });

  final List<NearbyAgency> agencies;
  final int count;
  final double radiusKm;

  factory NearbyAgenciesResult.fromJson(Map<String, dynamic> json) =>
      NearbyAgenciesResult(
        agencies: (json['agencies'] as List<dynamic>)
            .map((a) => NearbyAgency.fromJson(a as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int? ?? 0,
        radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 0,
      );
}
class AgencyDirectoryPage extends Equatable {
  const AgencyDirectoryPage({
    required this.agencies,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AgencyDirectoryEntry> agencies;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;

  factory AgencyDirectoryPage.fromJson(Map<String, dynamic> json) =>
      AgencyDirectoryPage(
        agencies: (json['agencies'] as List<dynamic>)
            .map((a) => AgencyDirectoryEntry.fromJson(a as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        limit: json['limit'] as int,
      );

  @override
  List<Object?> get props => [agencies, total, page, limit];
}

/// A single comment/review on an agency's public profile. Mirrors
/// `AgencyComment.model.js` `toJSON()` output, plus the `authorName`
/// the backend resolves and attaches server-side (see
/// agencyComment.service.js#attachAuthorInfo) so the app never needs a
/// separate lookup just to show who wrote it.
class AgencyComment extends Equatable {
  const AgencyComment({
    required this.id,
    required this.agencyId,
    required this.authorId,
    required this.authorRole,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.rating,
  });

  final String id;
  final String agencyId;
  final String authorId;

  /// 'seeker' | 'employer' | 'agency' | 'admin'.
  final String authorRole;
  final String authorName;
  final String body;
  final int? rating;
  final DateTime createdAt;

  factory AgencyComment.fromJson(Map<String, dynamic> json) => AgencyComment(
        id: json['id'] as String,
        agencyId: json['agencyId'] as String,
        authorId: json['authorId'] as String,
        authorRole: json['authorRole'] as String,
        authorName: json['authorName'] as String? ?? 'User',
        body: json['body'] as String,
        rating: json['rating'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props =>
      [id, agencyId, authorId, authorRole, authorName, body, rating, createdAt];
}

/// GET /agencies/:agencyId/comments response — a page of comments plus
/// the running average of whatever ratings are on that page (see
/// agencyComment.service.js#listComments).
class AgencyCommentsPage extends Equatable {
  const AgencyCommentsPage({
    required this.comments,
    required this.total,
    required this.page,
    required this.limit,
    this.averageRating,
  });

  final List<AgencyComment> comments;
  final int total;
  final int page;
  final int limit;
  final double? averageRating;

  bool get hasMore => page * limit < total;

  factory AgencyCommentsPage.fromJson(Map<String, dynamic> json) =>
      AgencyCommentsPage(
        comments: (json['comments'] as List<dynamic>)
            .map((c) => AgencyComment.fromJson(c as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        limit: json['limit'] as int,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [comments, total, page, limit, averageRating];
}
