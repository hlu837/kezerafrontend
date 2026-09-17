import 'package:equatable/equatable.dart';

/// Mirrors `src/validators/jobs.validator.js` JOB_TYPES / `Job.model.js`
/// JOB_STATUSES on the backend.
enum JobType { fullTime, contract, daily }

extension JobTypeWire on JobType {
  /// The exact string the backend sends/expects — not a Dart-style name.
  String get wireValue {
    switch (this) {
      case JobType.fullTime:
        return 'Full-Time';
      case JobType.contract:
        return 'Contract';
      case JobType.daily:
        return 'Daily';
    }
  }
}

JobType jobTypeFromWire(String value) => JobType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => JobType.fullTime,
    );

enum JobStatus { open, closed, draft }

JobStatus jobStatusFromWire(String value) => JobStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => JobStatus.draft,
    );

/// A posting account's public profile, attached to a [Job] server-side
/// (see `jobs.service.js#attachPosterInfo`) so the job board / job
/// detail screen can show who's hiring without a separate lookup.
/// `null` on a [Job] when the backend couldn't resolve a profile (e.g.
/// an old/mocked job) — callers should treat that as "no poster info",
/// not as an error.
class JobPoster extends Equatable {
  const JobPoster({
    required this.type,
    required this.name,
    this.city,
    this.logoUrl,
    this.agencyId,
  });

  /// 'employer' or 'agency' — mirrors [Job.creatorType].
  final String type;
  final String name;

  /// Agency's operating city — always null for an employer poster.
  final String? city;

  /// Employer's logo — always null for an agency poster (agencies have
  /// no `logoUrl` field on the backend).
  final String? logoUrl;

  /// The agency's *User* id (same value as [Job.creatorId] on this
  /// job) — always null for an employer poster. Lets a job card/detail
  /// screen link straight to GET /agencies/:agencyId/profile (+
  /// /jobs) without separately having to know that `creatorId` doubles
  /// as the agency id.
  final String? agencyId;

  bool get isAgency => type == 'agency';

  factory JobPoster.fromJson(Map<String, dynamic> json) => JobPoster(
        type: json['type'] as String,
        name: json['name'] as String,
        city: json['city'] as String?,
        logoUrl: json['logoUrl'] as String?,
        agencyId: json['agencyId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'city': city,
        'logoUrl': logoUrl,
        'agencyId': agencyId,
      };

  @override
  List<Object?> get props => [type, name, city, logoUrl, agencyId];
}

/// Mirrors `Job.model.js` `toJSON()` output.
class Job extends Equatable {
  const Job({
    required this.id,
    required this.creatorId,
    required this.creatorType,
    required this.title,
    required this.description,
    required this.location,
    required this.jobType,
    required this.skillsRequired,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.salaryRange,
    this.category,
    this.experienceLevel,
    this.applicationSummaryEnabled = false,
    this.poster,
  });

  final String id;
  final String creatorId;

  /// 'employer' or 'agency' — whoever posted the job.
  final String creatorType;
  final String title;
  final String description;
  final String location;
  final String? salaryRange;
  final JobType jobType;
  // JS-04: one of kJobCategories' keys, or null for jobs posted before
  // this field existed / left uncategorized. Optional everywhere it
  // appears (unlike jobType) for that reason.
  final String? category;
  final List<String> skillsRequired;
  // One of ExperienceLevel's wire keys ('entry'/'mid'/'senior'), or null
  // for jobs posted before this field existed / left unset. Drives the
  // "Experience" filter on the seeker job board, same "opt-in" contract
  // as [category].
  final String? experienceLevel;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Per-job opt-in for an AI-assisted summary of applicants (see
  // ApplicationSummary / applicationSummary.service.js on the
  // backend). Set at posting time or later via PATCH /jobs/:id.
  final bool applicationSummaryEnabled;
  // The posting agency's/employer's public profile — see [JobPoster].
  // Only present on jobs that came from the backend (job board /
  // my-jobs); absent on locally-built mock/placeholder jobs.
  final JobPoster? poster;

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        creatorId: json['creatorId'] as String,
        creatorType: json['creatorType'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        location: json['location'] as String,
        salaryRange: json['salaryRange'] as String?,
        jobType: jobTypeFromWire(json['jobType'] as String),
        category: json['category'] as String?,
        skillsRequired: (json['skillsRequired'] as List<dynamic>)
            .map((s) => s as String)
            .toList(),
        experienceLevel: json['experienceLevel'] as String?,
        status: jobStatusFromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        applicationSummaryEnabled:
            json['applicationSummaryEnabled'] as bool? ?? false,
        poster: json['poster'] == null
            ? null
            : JobPoster.fromJson(json['poster'] as Map<String, dynamic>),
      );

  /// Inverse of [Job.fromJson] — used to snapshot a job into on-device
  /// storage (see `SavedJobsNotifier`), not sent back to the backend.
  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'creatorType': creatorType,
        'title': title,
        'description': description,
        'location': location,
        'salaryRange': salaryRange,
        'jobType': jobType.wireValue,
        'category': category,
        'skillsRequired': skillsRequired,
        'experienceLevel': experienceLevel,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'applicationSummaryEnabled': applicationSummaryEnabled,
        'poster': poster?.toJson(),
      };

  Job copyWith({JobStatus? status, bool? applicationSummaryEnabled}) => Job(
        id: id,
        creatorId: creatorId,
        creatorType: creatorType,
        title: title,
        description: description,
        location: location,
        salaryRange: salaryRange,
        jobType: jobType,
        category: category,
        skillsRequired: skillsRequired,
        experienceLevel: experienceLevel,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        applicationSummaryEnabled:
            applicationSummaryEnabled ?? this.applicationSummaryEnabled,
        poster: poster,
      );

  @override
  List<Object?> get props => [
        id,
        creatorId,
        creatorType,
        title,
        description,
        location,
        salaryRange,
        jobType,
        category,
        skillsRequired,
        experienceLevel,
        status,
        createdAt,
        updatedAt,
        applicationSummaryEnabled,
        poster,
      ];
}

/// POST /jobs/:id/apply response — just enough to tell the UI whether
/// this was a fresh apply or a no-op repeat of an existing one.
class JobApplyResult {
  const JobApplyResult({required this.alreadyApplied});

  final bool alreadyApplied;
}

/// GET /jobs (JS-03 job board) query params — wire format mirrors
/// `browseJobsSchema` on the backend.
class JobBrowseParams {
  const JobBrowseParams({
    this.keyword,
    this.location,
    this.jobType,
    this.category,
    this.categories = const [],
    this.creatorType,
    this.experienceLevel,
    this.page = 1,
    this.limit = 20,
  });

  final String? keyword;
  final String? location;
  final JobType? jobType;
  // JS-04: one of kJobCategories' keys, or null for "any category" —
  // the seeker job board's manual single-category filter dropdown.
  final String? category;
  // JS-06: "For You" feed — the seeker's full `preferredCategories`
  // set (a job matching ANY of these is included), or empty for "no
  // personalization applied" (falls back to [category]/"any category"
  // — see `toQuery`). Takes priority over [category] when non-empty,
  // mirroring jobs.service.js#browseJobs' own precedence.
  final List<String> categories;
  // "Company jobs" (employer) vs "Agency jobs" (agency) toggle on the
  // job board — 'employer', 'agency', or null for "all jobs". Mirrors
  // `Job.creatorType` / the backend's `creator_type` filter exactly.
  final String? creatorType;
  // One of ExperienceLevel's wire keys, or null for "any experience".
  final String? experienceLevel;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (jobType != null) 'job_type': jobType!.wireValue,
        // `categories` (the For You set) takes priority over the
        // single `category` filter — same precedence
        // jobs.service.js#browseJobs applies server-side.
        if (categories.isNotEmpty)
          'categories': categories.join(',')
        else if (category != null && category!.isNotEmpty)
          'category': category,
        if (creatorType != null && creatorType!.isNotEmpty)
          'creator_type': creatorType,
        if (experienceLevel != null && experienceLevel!.isNotEmpty)
          'experience_level': experienceLevel,
        'page': page,
        'limit': limit,
      };

  JobBrowseParams copyWith({
    String? keyword,
    String? location,
    JobType? jobType,
    String? category,
    List<String>? categories,
    String? creatorType,
    String? experienceLevel,
    int? page,
    bool clearJobType = false,
    bool clearCategory = false,
    bool clearCategories = false,
    bool clearCreatorType = false,
    bool clearExperienceLevel = false,
  }) =>
      JobBrowseParams(
        keyword: keyword ?? this.keyword,
        location: location ?? this.location,
        jobType: clearJobType ? null : (jobType ?? this.jobType),
        category: clearCategory ? null : (category ?? this.category),
        categories:
            clearCategories ? const [] : (categories ?? this.categories),
        creatorType:
            clearCreatorType ? null : (creatorType ?? this.creatorType),
        experienceLevel: clearExperienceLevel
            ? null
            : (experienceLevel ?? this.experienceLevel),
        page: page ?? this.page,
        limit: limit,
      );
}

/// GET /jobs response payload.
class JobBrowseResult {
  const JobBrowseResult({
    required this.jobs,
    required this.page,
    required this.limit,
    required this.count,
    this.isMock = false,
  });

  final List<Job> jobs;
  final int page;
  final int limit;
  final int count;

  /// True when [jobs] are `MockJobs` placeholders rather than real
  /// postings — see `JobsRepository.browseJobs`. Lets the UI show a
  /// "sample listings" banner instead of passing these off as real jobs.
  final bool isMock;

  factory JobBrowseResult.fromJson(Map<String, dynamic> json) =>
      JobBrowseResult(
        jobs: (json['jobs'] as List<dynamic>)
            .map((j) => Job.fromJson(j as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        limit: json['limit'] as int,
        count: json['count'] as int,
      );
}

/// A seeker's saved search (JS-03), with alert-preference toggle.
/// Mirrors `SavedSearch.model.js` `toJSON()` output.
class SavedSearch extends Equatable {
  const SavedSearch({
    required this.id,
    required this.seekerId,
    required this.alertsEnabled,
    required this.createdAt,
    this.name,
    this.keyword,
    this.location,
    this.jobType,
    this.experienceLevel,
    this.lastAlertedAt,
  });

  final String id;
  final String seekerId;
  final String? name;
  final String? keyword;
  final String? location;
  final JobType? jobType;
  // One of ExperienceLevel's wire keys, or null for "any experience".
  final String? experienceLevel;
  final bool alertsEnabled;
  final DateTime? lastAlertedAt;
  final DateTime createdAt;

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
        id: json['id'] as String,
        seekerId: json['seekerId'] as String,
        name: json['name'] as String?,
        keyword: json['keyword'] as String?,
        location: json['location'] as String?,
        jobType: json['jobType'] == null
            ? null
            : jobTypeFromWire(json['jobType'] as String),
        experienceLevel: json['experienceLevel'] as String?,
        alertsEnabled: json['alertsEnabled'] as bool,
        lastAlertedAt: json['lastAlertedAt'] == null
            ? null
            : DateTime.parse(json['lastAlertedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Human-readable label when no `name` was set — summarizes whatever
  /// criteria was saved, e.g. "Full-Time · Addis Ababa".
  String get displaySummary {
    if (name != null && name!.isNotEmpty) return name!;
    final parts = <String>[
      if (keyword != null && keyword!.isNotEmpty) keyword!,
      if (jobType != null) jobType!.wireValue,
      if (location != null && location!.isNotEmpty) location!,
      if (experienceLevel != null && experienceLevel!.isNotEmpty)
        experienceLevel!,
    ];
    return parts.isEmpty ? 'All jobs' : parts.join(' · ');
  }

  @override
  List<Object?> get props => [
        id,
        seekerId,
        name,
        keyword,
        location,
        jobType,
        experienceLevel,
        alertsEnabled,
        lastAlertedAt,
        createdAt,
      ];
}

/// POST /seekers/saved-searches body — wire format matches
/// `createSavedSearchSchema` on the backend.
class CreateSavedSearchPayload {
  const CreateSavedSearchPayload({
    this.name,
    this.keyword,
    this.location,
    this.jobType,
    this.experienceLevel,
    this.alertsEnabled = true,
  });

  final String? name;
  final String? keyword;
  final String? location;
  final JobType? jobType;
  final String? experienceLevel;
  final bool alertsEnabled;

  /// Builds a saved-search payload directly from the current job-board
  /// filter params — "save this search" always snapshots whatever the
  /// seeker just browsed with.
  factory CreateSavedSearchPayload.fromBrowseParams(JobBrowseParams params) =>
      CreateSavedSearchPayload(
        keyword: params.keyword,
        location: params.location,
        jobType: params.jobType,
        experienceLevel: params.experienceLevel,
      );

  Map<String, dynamic> toJson() => {
        if (name != null && name!.isNotEmpty) 'name': name,
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (jobType != null) 'job_type': jobType!.wireValue,
        if (experienceLevel != null && experienceLevel!.isNotEmpty)
          'experience_level': experienceLevel,
        'alerts_enabled': alertsEnabled,
      };
}

/// POST /jobs/create body — wire format (snake_case), matches
/// `createJobSchema` on the backend exactly. `status` is deliberately
/// absent: the backend always creates jobs as `open`.
class CreateJobPayload {
  const CreateJobPayload({
    required this.title,
    required this.description,
    required this.location,
    required this.jobType,
    required this.skillsRequired,
    this.salaryRange,
    this.category,
    this.experienceLevel,
    this.applicationSummaryEnabled = false,
  });

  final String title;
  final String description;
  final String location;
  final String? salaryRange;
  final JobType jobType;
  final String? category;
  final List<String> skillsRequired;
  // One of ExperienceLevel's wire keys, or null to leave unset.
  final String? experienceLevel;
  // Per-job opt-in, set at posting time — see Job.applicationSummaryEnabled.
  final bool applicationSummaryEnabled;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        if (salaryRange != null && salaryRange!.isNotEmpty)
          'salary_range': salaryRange,
        'job_type': jobType.wireValue,
        if (category != null && category!.isNotEmpty) 'category': category,
        'skills_required': skillsRequired,
        if (experienceLevel != null && experienceLevel!.isNotEmpty)
          'experience_level': experienceLevel,
        'application_summary_enabled': applicationSummaryEnabled,
      };
}

/// PATCH /jobs/:id body — wire format matches `updateJobSchema` on the
/// backend. Unlike [CreateJobPayload] every field is optional (a partial
/// update), but `PostJobScreen`'s edit mode always sends the full set of
/// editable fields since the form re-collects every value on submit.
/// `status` is deliberately absent here — the open/closed toggle on the
/// dashboard already covers that via `JobsRepository.updateJobStatus`,
/// so this payload only ever carries the "editable content" fields.
class UpdateJobPayload {
  const UpdateJobPayload({
    this.title,
    this.description,
    this.location,
    this.salaryRange,
    this.jobType,
    this.category,
    this.skillsRequired,
    this.experienceLevel,
    this.applicationSummaryEnabled,
  });

  final String? title;
  final String? description;
  final String? location;
  final String? salaryRange;
  final JobType? jobType;
  final String? category;
  final List<String>? skillsRequired;
  final String? experienceLevel;
  final bool? applicationSummaryEnabled;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        // An explicitly-cleared salary range still needs to reach the
        // backend as an empty string (allowed by `updateJobSchema`), not
        // be dropped the way an absent field would be.
        if (salaryRange != null) 'salary_range': salaryRange,
        if (jobType != null) 'job_type': jobType!.wireValue,
        if (category != null) 'category': category,
        if (skillsRequired != null) 'skills_required': skillsRequired,
        if (experienceLevel != null) 'experience_level': experienceLevel,
        if (applicationSummaryEnabled != null)
          'application_summary_enabled': applicationSummaryEnabled,
      };
}

/// One `{value, count}` bucket from `GET /jobs/:id/applications/summary`'s
/// `structuredStats` breakdowns (by experience level / skill / city).
/// Mirrors `tally()`'s output shape in
/// `applicationSummary.service.js`.
class SummaryTally extends Equatable {
  const SummaryTally({required this.value, required this.count});

  final String value;
  final int count;

  factory SummaryTally.fromJson(Map<String, dynamic> json) => SummaryTally(
        value: json['value'] as String,
        count: json['count'] as int,
      );

  @override
  List<Object?> get props => [value, count];
}

/// One applicant in the GPA leaderboard (`ApplicationSummaryStats.gpa.topApplicants`).
class GpaApplicant extends Equatable {
  const GpaApplicant({
    required this.seekerId,
    required this.fullName,
    required this.gpa,
  });

  final String seekerId;
  final String fullName;
  final double gpa;

  factory GpaApplicant.fromJson(Map<String, dynamic> json) => GpaApplicant(
        seekerId: json['seekerId'] as String,
        fullName: json['fullName'] as String,
        gpa: (json['gpa'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [seekerId, fullName, gpa];
}

/// GPA-specific slice of the structured stats. `average` and
/// `topApplicants` only cover applicants who actually entered a GPA on
/// their profile (see Seeker.education[].gpa) — `reportedCount` tells
/// the employer how many of `totalApplicants` that was.
class GpaBreakdown extends Equatable {
  const GpaBreakdown({
    required this.reportedCount,
    required this.average,
    required this.topApplicants,
  });

  final int reportedCount;
  final double? average;
  final List<GpaApplicant> topApplicants;

  factory GpaBreakdown.fromJson(Map<String, dynamic> json) => GpaBreakdown(
        reportedCount: json['reportedCount'] as int? ?? 0,
        average: (json['average'] as num?)?.toDouble(),
        topApplicants: (json['topApplicants'] as List<dynamic>? ?? [])
            .map((a) => GpaApplicant.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [reportedCount, average, topApplicants];
}

/// The always-available half of `GET /jobs/:id/applications/summary` —
/// computed over every applicant regardless of subscription tier.
class ApplicationSummaryStats extends Equatable {
  const ApplicationSummaryStats({
    required this.totalApplicants,
    required this.byExperienceLevel,
    required this.topSkills,
    required this.byCity,
    required this.gpa,
  });

  final int totalApplicants;
  final List<SummaryTally> byExperienceLevel;
  final List<SummaryTally> topSkills;
  final List<SummaryTally> byCity;
  final GpaBreakdown gpa;

  factory ApplicationSummaryStats.fromJson(Map<String, dynamic> json) =>
      ApplicationSummaryStats(
        totalApplicants: json['totalApplicants'] as int,
        byExperienceLevel: (json['byExperienceLevel'] as List<dynamic>? ?? [])
            .map((t) => SummaryTally.fromJson(t as Map<String, dynamic>))
            .toList(),
        topSkills: (json['topSkills'] as List<dynamic>? ?? [])
            .map((t) => SummaryTally.fromJson(t as Map<String, dynamic>))
            .toList(),
        gpa: json['gpa'] != null
            ? GpaBreakdown.fromJson(json['gpa'] as Map<String, dynamic>)
            : const GpaBreakdown(reportedCount: 0, average: null, topApplicants: []),
        byCity: (json['byCity'] as List<dynamic>? ?? [])
            .map((t) => SummaryTally.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props =>
      [totalApplicants, byExperienceLevel, topSkills, byCity, gpa];
}

/// One candidate's entry in `aiSummaries` — only present for the subset
/// of applicants the caller's subscription tier covers (see
/// `ApplicationSummaryResult.summaryLimitReached`).
class ApplicantAiSummary extends Equatable {
  const ApplicantAiSummary({
    required this.seekerId,
    required this.fullName,
    this.summary,
    this.strengths = const [],
    this.fitScore,
    this.gpa,
  });

  final String seekerId;
  final String fullName;
  final String? summary;
  final List<String> strengths;
  // 'strong' | 'moderate' | 'weak', or null if the AI call didn't cover
  // this candidate (see ApplicationSummaryResult.aiAvailable).
  final String? fitScore;
  // The candidate's highest reported GPA (see Seeker.education[].gpa),
  // or null if they haven't entered one.
  final double? gpa;

  factory ApplicantAiSummary.fromJson(Map<String, dynamic> json) =>
      ApplicantAiSummary(
        seekerId: json['seekerId'] as String,
        fullName: json['fullName'] as String,
        summary: json['summary'] as String?,
        strengths: (json['strengths'] as List<dynamic>? ?? [])
            .map((s) => s as String)
            .toList(),
        fitScore: json['fitScore'] as String?,
        gpa: (json['gpa'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props =>
      [seekerId, fullName, summary, strengths, fitScore, gpa];
}

/// GET /jobs/:id/applications/summary response. Mirrors
/// `applicationSummary.service.js#summarizeApplicationsForJob`'s return
/// shape exactly.
class ApplicationSummaryResult extends Equatable {
  const ApplicationSummaryResult({
    required this.structuredStats,
    required this.aiSummaries,
    required this.aiAvailable,
    required this.subscriptionTier,
    required this.summaryLimit,
    required this.summaryLimitReached,
    this.sortBy = 'recent',
    this.aiError,
  });

  final ApplicationSummaryStats structuredStats;
  final List<ApplicantAiSummary> aiSummaries;
  // False if ANTHROPIC_API_KEY isn't configured or the API call failed
  // server-side — structuredStats is still always usable regardless.
  final bool aiAvailable;
  final String? aiError;
  final String subscriptionTier;
  // Max applicants the caller's tier will run through the AI summarizer;
  // null means unlimited (enterprise).
  final int? summaryLimit;
  // True when there are more applicants than summaryLimit — the UI's
  // cue to show an upgrade prompt.
  final bool summaryLimitReached;
  // 'recent' | 'gpa' | 'experience' — which order aiSummaries came back
  // in, echoing whatever was requested via `?sortBy=` (see
  // JobsRepository.getApplicationSummary).
  final String sortBy;

  factory ApplicationSummaryResult.fromJson(Map<String, dynamic> json) =>
      ApplicationSummaryResult(
        structuredStats: ApplicationSummaryStats.fromJson(
          json['structuredStats'] as Map<String, dynamic>,
        ),
        aiSummaries: (json['aiSummaries'] as List<dynamic>? ?? [])
            .map((s) => ApplicantAiSummary.fromJson(s as Map<String, dynamic>))
            .toList(),
        sortBy: json['sortBy'] as String? ?? 'recent',
        aiAvailable: json['aiAvailable'] as bool? ?? false,
        aiError: json['aiError'] as String?,
        subscriptionTier: json['subscriptionTier'] as String? ?? 'basic',
        summaryLimit: json['summaryLimit'] as int?,
        summaryLimitReached: json['summaryLimitReached'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        structuredStats,
        aiSummaries,
        aiAvailable,
        aiError,
        subscriptionTier,
        summaryLimit,
        summaryLimitReached,
        sortBy,
      ];
}

/// One row in `MyJobsStats.recentApplicants` — a lightweight,
/// cross-job "who just applied" feed for the dashboard, as opposed to
/// [JobApplication] which is scoped to a single job's full applicant
/// list (with the seeker's CV/skills/etc. nested in for the "View
/// candidates" screen). Only carries what the dashboard actually
/// shows: who, for which job, and whether it happened today.
class RecentApplicant extends Equatable {
  const RecentApplicant({
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.applicantName,
    required this.appliedAt,
    required this.isNewToday,
    this.seekerId,
  });

  final String applicationId;
  final String jobId;
  final String jobTitle;
  final String applicantName;
  final DateTime appliedAt;
  final bool isNewToday;

  /// Null if the seeker account was deleted after applying (see
  /// `jobs.service.js#getMyJobsStats`) — that row just can't be
  /// messaged from the dashboard; everywhere else still works.
  final String? seekerId;

  factory RecentApplicant.fromJson(Map<String, dynamic> json) =>
      RecentApplicant(
        applicationId: json['applicationId'] as String,
        jobId: json['jobId'] as String,
        jobTitle: json['jobTitle'] as String,
        applicantName: json['applicantName'] as String,
        appliedAt: DateTime.parse(json['appliedAt'] as String),
        isNewToday: json['isNewToday'] as bool? ?? false,
        seekerId: json['seekerId'] as String?,
      );

  @override
  List<Object?> get props => [
        applicationId,
        jobId,
        jobTitle,
        applicantName,
        appliedAt,
        isNewToday,
        seekerId,
      ];
}

/// GET /jobs/my-jobs/stats response — the reporting summary behind the
/// employer/agency dashboard: how many jobs this account has posted
/// (by status), how many applicants have come in across all of them,
/// how many arrived today, and a short recent-applicants feed.
/// Deliberately separate from [Job]/[JobApplication] — nothing here is
/// scoped to a single job, it's the account-wide totals `myJobsProvider`
/// alone can't answer without fetching every job's applications.
class MyJobsStats extends Equatable {
  const MyJobsStats({
    required this.totalJobs,
    required this.openJobs,
    required this.closedJobs,
    required this.draftJobs,
    required this.totalApplicants,
    required this.newApplicantsToday,
    required this.recentApplicants,
  });

  final int totalJobs;
  final int openJobs;
  final int closedJobs;
  final int draftJobs;
  final int totalApplicants;
  final int newApplicantsToday;
  final List<RecentApplicant> recentApplicants;

  factory MyJobsStats.fromJson(Map<String, dynamic> json) => MyJobsStats(
        totalJobs: json['totalJobs'] as int? ?? 0,
        openJobs: json['openJobs'] as int? ?? 0,
        closedJobs: json['closedJobs'] as int? ?? 0,
        draftJobs: json['draftJobs'] as int? ?? 0,
        totalApplicants: json['totalApplicants'] as int? ?? 0,
        newApplicantsToday: json['newApplicantsToday'] as int? ?? 0,
        recentApplicants: (json['recentApplicants'] as List<dynamic>? ?? [])
            .map((a) => RecentApplicant.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        totalJobs,
        openJobs,
        closedJobs,
        draftJobs,
        totalApplicants,
        newApplicantsToday,
        recentApplicants,
      ];
}
