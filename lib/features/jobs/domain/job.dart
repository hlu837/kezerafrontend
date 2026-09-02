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
  final JobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

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
        status: jobStatusFromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
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
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Job copyWith({JobStatus? status}) => Job(
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
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt,
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
        status,
        createdAt,
        updatedAt,
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
    this.skills = const [],
    this.page = 1,
    this.limit = 20,
  });

  final String? keyword;
  final String? location;
  final JobType? jobType;
  // JS-04: one of kJobCategories' keys, or null for "any category".
  final String? category;
  final List<String> skills;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (jobType != null) 'job_type': jobType!.wireValue,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (skills.isNotEmpty) 'skills': skills.join(','),
        'page': page,
        'limit': limit,
      };

  JobBrowseParams copyWith({
    String? keyword,
    String? location,
    JobType? jobType,
    String? category,
    List<String>? skills,
    int? page,
    bool clearJobType = false,
    bool clearCategory = false,
  }) =>
      JobBrowseParams(
        keyword: keyword ?? this.keyword,
        location: location ?? this.location,
        jobType: clearJobType ? null : (jobType ?? this.jobType),
        category: clearCategory ? null : (category ?? this.category),
        skills: skills ?? this.skills,
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
    required this.skills,
    required this.createdAt,
    this.name,
    this.keyword,
    this.location,
    this.jobType,
    this.lastAlertedAt,
  });

  final String id;
  final String seekerId;
  final String? name;
  final String? keyword;
  final String? location;
  final JobType? jobType;
  final List<String> skills;
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
        skills: (json['skills'] as List<dynamic>? ?? [])
            .map((s) => s as String)
            .toList(),
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
      if (skills.isNotEmpty) skills.join(', '),
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
        skills,
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
    this.skills = const [],
    this.alertsEnabled = true,
  });

  final String? name;
  final String? keyword;
  final String? location;
  final JobType? jobType;
  final List<String> skills;
  final bool alertsEnabled;

  /// Builds a saved-search payload directly from the current job-board
  /// filter params — "save this search" always snapshots whatever the
  /// seeker just browsed with.
  factory CreateSavedSearchPayload.fromBrowseParams(JobBrowseParams params) =>
      CreateSavedSearchPayload(
        keyword: params.keyword,
        location: params.location,
        jobType: params.jobType,
        skills: params.skills,
      );

  Map<String, dynamic> toJson() => {
        if (name != null && name!.isNotEmpty) 'name': name,
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (jobType != null) 'job_type': jobType!.wireValue,
        if (skills.isNotEmpty) 'skills': skills,
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
  });

  final String title;
  final String description;
  final String location;
  final String? salaryRange;
  final JobType jobType;
  final String? category;
  final List<String> skillsRequired;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        if (salaryRange != null && salaryRange!.isNotEmpty)
          'salary_range': salaryRange,
        'job_type': jobType.wireValue,
        if (category != null && category!.isNotEmpty) 'category': category,
        'skills_required': skillsRequired,
      };
}
