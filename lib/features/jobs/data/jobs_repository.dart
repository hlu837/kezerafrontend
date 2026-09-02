import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/application.dart';
import '../domain/job.dart';
import '../domain/placement.dart';
import 'mock_jobs.dart';

/// Talks to the `/jobs` endpoints. Knows nothing about state management —
/// same shape as `AuthRepository`, so callers only ever deal with
/// [ApiException] on failure.
class JobsRepository {
  JobsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// POST /jobs/create
  Future<Job> createJob(CreateJobPayload payload) => _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/jobs/create',
          data: payload.toJson(),
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Job.fromJson(data['job'] as Map<String, dynamic>);
      });

  /// GET /jobs/my-jobs — jobs posted by the current employer/agency.
  Future<List<Job>> fetchMyJobs() => _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/jobs/my-jobs',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['jobs'] as List<dynamic>)
            .map((json) => Job.fromJson(json as Map<String, dynamic>))
            .toList();
      });

  /// PATCH /jobs/:id — used here just to flip open ⇄ closed, but takes any
  /// status the backend allows.
  Future<Job> updateJobStatus(String jobId, JobStatus status) =>
      _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/jobs/$jobId',
          data: {'status': status.name},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Job.fromJson(data['job'] as Map<String, dynamic>);
      });

  /// GET /jobs/:id/suggested-seekers — candidates the matching engine has
  /// placed against this job, one row per [Placement].
  Future<List<SuggestedSeeker>> fetchSuggestedSeekers(
    String jobId, {
    required String jobTitle,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/jobs/$jobId/suggested-seekers',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['seekers'] as List<dynamic>)
            .map(
              (json) => SuggestedSeeker.fromJson(
                json as Map<String, dynamic>,
                jobTitle: jobTitle,
              ),
            )
            .toList();
      });

  /// GET /jobs (JS-03) — the seeker-facing job board, filterable/paginated.
  ///
  /// Falls back to `MockJobs` (filtered the same way real results would
  /// be) whenever the live board is empty on page 1 — i.e. no real jobs
  /// have been posted yet — so the board isn't just a blank state during
  /// preview/early launch. `isMock` on the result tells the UI to label
  /// these as sample listings. A real posted job makes this fallback moot
  /// automatically, since the live query then returns actual results.
  Future<JobBrowseResult> browseJobs(JobBrowseParams params) => _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/jobs',
          queryParameters: params.toQuery(),
        );
        final result = JobBrowseResult.fromJson(
          response.data!['data'] as Map<String, dynamic>,
        );
        if (result.jobs.isNotEmpty || params.page != 1) return result;

        final mockMatches = MockJobs.filtered(params);
        return JobBrowseResult(
          jobs: mockMatches,
          page: 1,
          limit: params.limit,
          count: mockMatches.length,
          isMock: true,
        );
      });

  /// POST /jobs/:id/apply — JS-05: a seeker applying directly to a job.
  /// Idempotent on the backend, so a repeat call on an already-applied
  /// job just comes back with `alreadyApplied: true` rather than an
  /// error — see `JobApplyResult`.
  Future<JobApplyResult> applyToJob(String jobId) => _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/jobs/$jobId/apply',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return JobApplyResult(
          alreadyApplied: data['already_applied'] as bool? ?? false,
        );
      });

  /// GET /jobs/:id/applications — employer/agency-facing "who applied
  /// directly to this job" list (JS-05), newest first, each row with the
  /// applicant's profile — including the CV they applied with — nested
  /// inline. Restricted to the job's own creator server-side.
  Future<List<JobApplication>> fetchJobApplications(String jobId) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/jobs/$jobId/applications',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['applications'] as List<dynamic>)
            .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
            .toList();
      });

  /// GET /seekers/saved-searches
  Future<List<SavedSearch>> fetchSavedSearches() => _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/seekers/saved-searches',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['saved_searches'] as List<dynamic>)
            .map((json) => SavedSearch.fromJson(json as Map<String, dynamic>))
            .toList();
      });

  /// POST /seekers/saved-searches
  Future<SavedSearch> createSavedSearch(CreateSavedSearchPayload payload) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/seekers/saved-searches',
          data: payload.toJson(),
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return SavedSearch.fromJson(data['saved_search'] as Map<String, dynamic>);
      });

  /// PATCH /seekers/saved-searches/:id — used here to flip the alert
  /// preference on/off, but accepts any updatable field.
  Future<SavedSearch> updateSavedSearch(
    String id, {
    bool? alertsEnabled,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/seekers/saved-searches/$id',
          data: {
            if (alertsEnabled != null) 'alerts_enabled': alertsEnabled,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return SavedSearch.fromJson(data['saved_search'] as Map<String, dynamic>);
      });

  /// DELETE /seekers/saved-searches/:id
  Future<void> deleteSavedSearch(String id) => _guard(() async {
        await _apiClient.dio.delete<Map<String, dynamic>>(
          '/seekers/saved-searches/$id',
        );
      });

  /// POST /jobs/:id/invite-candidate — the "Message" button on the
  /// employer/agency "Find candidates" search (`CandidatesScreen`),
  /// which browses seekers independent of any job. Turns [seekerId]
  /// into a Placement against [jobId] (creating one if none already
  /// exists) so there's something for `/placements/:placementId/messages`
  /// to attach to, then hands back that placement's id to open chat with.
  Future<String> inviteCandidate({
    required String jobId,
    required String seekerId,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/jobs/$jobId/invite-candidate',
          data: {'seeker_id': seekerId},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return data['placement_id'] as String;
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is ApiException) throw apiError;
      throw ApiException(message: e.message ?? 'Something went wrong.');
    }
  }
}
