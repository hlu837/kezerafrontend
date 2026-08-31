import 'package:equatable/equatable.dart';

/// CV-03: which of the 3 CV builder templates a seeker's generated CV was
/// last rendered with. Mirrors the `cvTemplate` enum on
/// `src/models/Seeker.model.js`.
enum CvTemplate {
  classic,
  modern,
  minimal;

  String get wireValue => name;

  static CvTemplate fromWire(String? value) => CvTemplate.values.firstWhere(
        (t) => t.wireValue == value,
        orElse: () => CvTemplate.classic,
      );
}

/// One work-experience entry in the CV builder. Dates are free-text
/// (`"Jan 2022"`, `"2019"`, ...) rather than a strict date type — CV
/// builders in this market see a mix of month/year, year-only, and
/// "Present", and forcing a date picker adds friction without adding
/// value to the generated PDF.
class CvExperience extends Equatable {
  const CvExperience({
    required this.title,
    required this.company,
    this.location,
    this.startDate,
    this.endDate,
    this.current = false,
    this.description,
  });

  final String title;
  final String company;
  final String? location;
  final String? startDate;
  final String? endDate;
  final bool current;
  final String? description;

  factory CvExperience.fromJson(Map<String, dynamic> json) => CvExperience(
        title: json['title'] as String? ?? '',
        company: json['company'] as String? ?? '',
        location: json['location'] as String?,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        current: json['current'] as bool? ?? false,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'company': company,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
        if (!current && endDate != null && endDate!.isNotEmpty) 'end_date': endDate,
        'current': current,
        if (description != null && description!.isNotEmpty) 'description': description,
      };

  CvExperience copyWith({
    String? title,
    String? company,
    String? location,
    String? startDate,
    String? endDate,
    bool? current,
    String? description,
  }) =>
      CvExperience(
        title: title ?? this.title,
        company: company ?? this.company,
        location: location ?? this.location,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        current: current ?? this.current,
        description: description ?? this.description,
      );

  @override
  List<Object?> get props =>
      [title, company, location, startDate, endDate, current, description];
}

/// One education entry in the CV builder.
class CvEducation extends Equatable {
  const CvEducation({
    required this.school,
    required this.degree,
    this.fieldOfStudy,
    this.startDate,
    this.endDate,
    this.current = false,
  });

  final String school;
  final String degree;
  final String? fieldOfStudy;
  final String? startDate;
  final String? endDate;
  final bool current;

  factory CvEducation.fromJson(Map<String, dynamic> json) => CvEducation(
        school: json['school'] as String? ?? '',
        degree: json['degree'] as String? ?? '',
        fieldOfStudy: json['fieldOfStudy'] as String?,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        current: json['current'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'school': school,
        'degree': degree,
        if (fieldOfStudy != null && fieldOfStudy!.isNotEmpty)
          'field_of_study': fieldOfStudy,
        if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
        if (!current && endDate != null && endDate!.isNotEmpty) 'end_date': endDate,
        'current': current,
      };

  CvEducation copyWith({
    String? school,
    String? degree,
    String? fieldOfStudy,
    String? startDate,
    String? endDate,
    bool? current,
  }) =>
      CvEducation(
        school: school ?? this.school,
        degree: degree ?? this.degree,
        fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        current: current ?? this.current,
      );

  @override
  List<Object?> get props =>
      [school, degree, fieldOfStudy, startDate, endDate, current];
}

/// A spoken/written language + self-rated proficiency for the CV builder.
enum CvLanguageLevel {
  basic('Basic'),
  conversational('Conversational'),
  fluent('Fluent'),
  native('Native');

  const CvLanguageLevel(this.label);
  final String label;

  static CvLanguageLevel fromWire(String? value) => CvLanguageLevel.values.firstWhere(
        (l) => l.label == value,
        orElse: () => CvLanguageLevel.conversational,
      );
}

class CvLanguage extends Equatable {
  const CvLanguage({required this.name, required this.level});

  final String name;
  final CvLanguageLevel level;

  factory CvLanguage.fromJson(Map<String, dynamic> json) => CvLanguage(
        name: json['name'] as String? ?? '',
        level: CvLanguageLevel.fromWire(json['level'] as String?),
      );

  Map<String, dynamic> toJson() => {'name': name, 'level': level.label};

  CvLanguage copyWith({String? name, CvLanguageLevel? level}) =>
      CvLanguage(name: name ?? this.name, level: level ?? this.level);

  @override
  List<Object?> get props => [name, level];
}

/// Mirrors `src/models/Seeker.model.js` `toJSON()` output.
class Seeker extends Equatable {
  const Seeker({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.availabilityStatus,
    required this.skills,
    required this.createdAt,
    required this.updatedAt,
    this.cvUrl,
    this.photoUrl,
    this.bio,
    this.city,
    this.agencyId,
    this.preferredCategories = const [],
    this.locationOptIn = false,
    this.onboardingCompletedAt,
    this.experience = const [],
    this.education = const [],
    this.languages = const [],
    this.cvTemplate = CvTemplate.classic,
    this.boostedUntil,
  });

  final String id;
  final String userId;
  final String fullName;
  final String? cvUrl;
  final String? photoUrl;
  final bool availabilityStatus;
  final String? bio;
  final List<String> skills;
  final String? city;
  final String? agencyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  // SEEK-01: Category & Preference Setup screen fields.
  final List<String> preferredCategories;
  final bool locationOptIn;
  final DateTime? onboardingCompletedAt;
  // CV-03: CV builder fields — feed both the in-app "Build your CV" wizard
  // and the server-rendered PDF (see cv_builder_screen.dart).
  final List<CvExperience> experience;
  final List<CvEducation> education;
  final List<CvLanguage> languages;
  final CvTemplate cvTemplate;
  // SEEK-xx "Boost my profile" — set by the backend once a boost
  // payment is verified (see payment.routes.js's /verify-callback).
  // `isBoosted` (not this field directly) is what UI should check, same
  // as the backend never trusts a raw stored "boosted" flag either.
  final DateTime? boostedUntil;

  /// Whether this seeker has been through the SEEK-01 onboarding screen
  /// at least once — drives the post-registration redirect in
  /// register_screen.dart.
  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  /// Whether the CV builder has ever been used to generate a CV, as
  /// opposed to `cvUrl` only ever being set by a plain file upload.
  bool get hasBuilderData =>
      experience.isNotEmpty || education.isNotEmpty || languages.isNotEmpty;

  /// Mirrors the backend's own `isBoosted` computation (see
  /// Seeker.model.js's toJSON transform) — recomputed client-side too
  /// rather than trusting a stale server value across a long session.
  bool get isBoosted =>
      boostedUntil != null && boostedUntil!.isAfter(DateTime.now());

  factory Seeker.fromJson(Map<String, dynamic> json) => Seeker(
        id: json['id'] as String,
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        cvUrl: json['cvUrl'] as String?,
        photoUrl: json['photoUrl'] as String?,
        availabilityStatus: json['availabilityStatus'] as bool? ?? false,
        bio: json['bio'] as String?,
        skills: (json['skills'] as List<dynamic>? ?? const [])
            .map((s) => s as String)
            .toList(),
        city: json['city'] as String?,
        agencyId: json['agencyId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        preferredCategories:
            (json['preferredCategories'] as List<dynamic>? ?? const [])
                .map((c) => c as String)
                .toList(),
        locationOptIn: json['locationOptIn'] as bool? ?? false,
        onboardingCompletedAt: json['onboardingCompletedAt'] != null
            ? DateTime.parse(json['onboardingCompletedAt'] as String)
            : null,
        experience: (json['experience'] as List<dynamic>? ?? const [])
            .map((e) => CvExperience.fromJson(e as Map<String, dynamic>))
            .toList(),
        education: (json['education'] as List<dynamic>? ?? const [])
            .map((e) => CvEducation.fromJson(e as Map<String, dynamic>))
            .toList(),
        languages: (json['languages'] as List<dynamic>? ?? const [])
            .map((e) => CvLanguage.fromJson(e as Map<String, dynamic>))
            .toList(),
        cvTemplate: CvTemplate.fromWire(json['cvTemplate'] as String?),
        boostedUntil: json['boostedUntil'] != null
            ? DateTime.parse(json['boostedUntil'] as String)
            : null,
      );

  Seeker copyWith({
    String? fullName,
    String? cvUrl,
    String? photoUrl,
    bool? availabilityStatus,
    String? bio,
    List<String>? skills,
    String? city,
    DateTime? updatedAt,
    List<String>? preferredCategories,
    bool? locationOptIn,
    DateTime? onboardingCompletedAt,
    List<CvExperience>? experience,
    List<CvEducation>? education,
    List<CvLanguage>? languages,
    CvTemplate? cvTemplate,
    DateTime? boostedUntil,
  }) =>
      Seeker(
        id: id,
        userId: userId,
        fullName: fullName ?? this.fullName,
        cvUrl: cvUrl ?? this.cvUrl,
        photoUrl: photoUrl ?? this.photoUrl,
        availabilityStatus: availabilityStatus ?? this.availabilityStatus,
        bio: bio ?? this.bio,
        skills: skills ?? this.skills,
        city: city ?? this.city,
        agencyId: agencyId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        preferredCategories: preferredCategories ?? this.preferredCategories,
        locationOptIn: locationOptIn ?? this.locationOptIn,
        onboardingCompletedAt:
            onboardingCompletedAt ?? this.onboardingCompletedAt,
        experience: experience ?? this.experience,
        education: education ?? this.education,
        languages: languages ?? this.languages,
        cvTemplate: cvTemplate ?? this.cvTemplate,
        boostedUntil: boostedUntil ?? this.boostedUntil,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        cvUrl,
        photoUrl,
        availabilityStatus,
        bio,
        skills,
        city,
        agencyId,
        createdAt,
        updatedAt,
        preferredCategories,
        locationOptIn,
        onboardingCompletedAt,
        experience,
        education,
        languages,
        cvTemplate,
        boostedUntil,
      ];
}

/// GET /seekers/search query params — `skills` is sent as a comma-separated
/// string on the wire (`searchSeekersSchema` splits it), same convention
/// as the agency candidates/walk-in endpoints.
class SearchSeekersParams {
  const SearchSeekersParams({
    this.keyword,
    this.city,
    this.skills = const [],
    this.page = 1,
    this.limit = 20,
  });

  final String? keyword;
  final String? city;
  final List<String> skills;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (skills.isNotEmpty) 'skills': skills.join(','),
        'page': page,
        'limit': limit,
      };

  SearchSeekersParams copyWith({
    String? keyword,
    String? city,
    List<String>? skills,
    int? page,
  }) =>
      SearchSeekersParams(
        keyword: keyword ?? this.keyword,
        city: city ?? this.city,
        skills: skills ?? this.skills,
        page: page ?? this.page,
        limit: limit,
      );
}

/// Employer/agency subscription tier, as stored on `Employer.model.js` /
/// `Agency.model.js`. Drives how much of the candidate pool
/// `GET /seekers/search` returns — see `seeker.service.js#searchSeekers`.
enum SubscriptionTier {
  basic,
  premium,
  enterprise;

  static SubscriptionTier fromWire(String? value) => SubscriptionTier.values.firstWhere(
        (t) => t.name == value,
        orElse: () => SubscriptionTier.basic,
      );

  String get label => switch (this) {
        SubscriptionTier.basic => 'Basic',
        SubscriptionTier.premium => 'Premium',
        SubscriptionTier.enterprise => 'Enterprise',
      };
}

class SearchSeekersResult {
  const SearchSeekersResult({
    required this.seekers,
    required this.page,
    required this.limit,
    required this.count,
    this.subscriptionTier = SubscriptionTier.basic,
    this.limitReached = false,
  });

  final List<Seeker> seekers;
  final int page;
  final int limit;
  final int count;
  // The caller's plan, and whether this page has hit that plan's
  // visibility ceiling — the Candidates screen uses this to show an
  // upgrade prompt instead of a dead-end "Next" button.
  final SubscriptionTier subscriptionTier;
  final bool limitReached;

  factory SearchSeekersResult.fromJson(Map<String, dynamic> json) =>
      SearchSeekersResult(
        seekers: (json['seekers'] as List<dynamic>)
            .map((s) => Seeker.fromJson(s as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        limit: json['limit'] as int,
        count: json['count'] as int,
        subscriptionTier:
            SubscriptionTier.fromWire(json['subscriptionTier'] as String?),
        limitReached: json['limitReached'] as bool? ?? false,
      );
}
