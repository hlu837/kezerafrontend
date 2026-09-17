import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/jobs_repository.dart';
import '../domain/application.dart';
import '../domain/job.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(apiClientProvider));
});

/// The current employer/agency's own job postings. Loads on first watch;
/// `PostJobScreen` and `MyJobsBoard` (used by both `EmployerDashboardScreen`
/// and `AgencyDashboardScreen`) both read/act on this one instance so a
/// newly-posted job or a status toggle shows up everywhere without a
/// manual refetch.
final myJobsProvider =
    StateNotifierProvider<MyJobsNotifier, AsyncValue<List<Job>>>((ref) {
  return MyJobsNotifier(ref.watch(jobsRepositoryProvider))..load();
});

/// The reporting summary behind the employer/agency dashboard — see
/// [MyJobsStats]. A separate `FutureProvider` rather than derived from
/// [myJobsProvider] since the totals (applicant counts, recent
/// applicants) aren't computable from the job list alone; the
/// dashboard re-triggers this itself (pull-to-refresh) rather than
/// tying it to [myJobsProvider]'s lifecycle.
final myJobsStatsProvider = FutureProvider.autoDispose<MyJobsStats>((ref) {
  return ref.watch(jobsRepositoryProvider).fetchMyJobsStats();
});

/// JS-05: the direct applicants (with CV) for one of the current
/// employer/agency's own job postings — `JobApplicantsScreen` watches
/// one instance of this per job id it's opened for. `.family` (rather
/// than folding this into [myJobsProvider]) since it's fetched lazily,
/// only once an employer actually opens "View candidates" for a job.
/// A `StateNotifierProvider` (not a plain `FutureProvider`) so the
/// "Shortlist" action on `JobApplicantsScreen` can splice the updated
/// row back into the list in place, the same pattern as
/// [MyJobsNotifier.toggleStatus].
final jobApplicationsProvider = StateNotifierProvider.family<
    JobApplicationsNotifier, AsyncValue<List<JobApplication>>, String>(
  (ref, jobId) =>
      JobApplicationsNotifier(ref.watch(jobsRepositoryProvider), jobId)..load(),
);

class JobApplicationsNotifier extends StateNotifier<AsyncValue<List<JobApplication>>> {
  JobApplicationsNotifier(this._repository, this.jobId)
      : super(const AsyncValue.loading());

  final JobsRepository _repository;
  final String jobId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final applications = await _repository.fetchJobApplications(jobId);
      state = AsyncValue.data(applications);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Shortlists (or un-shortlists) [application] on the "View
  /// candidates" screen. Rethrows [ApiException] so the card can show
  /// its own error via a snackbar without losing the current list —
  /// same shape as [MyJobsNotifier.toggleStatus].
  Future<void> setShortlisted(JobApplication application, bool shortlisted) async {
    final updated = await _repository.updateApplicationStatus(
      jobId: jobId,
      applicationId: application.id,
      status: shortlisted ? ApplicationStatus.shortlisted : ApplicationStatus.viewed,
    );
    state = state.whenData(
      (applications) => [
        for (final existing in applications)
          if (existing.id == updated.id) updated else existing,
      ],
    );
  }

  /// Rejects [application] on the "View candidates" screen. Same
  /// splice-in-place pattern as [setShortlisted]; unlike shortlisting
  /// there's no "un-reject" toggle here — the card offers a separate
  /// way back to `viewed` if the employer changes their mind (see
  /// `JobApplicantsScreen`).
  Future<void> setRejected(JobApplication application) async {
    final updated = await _repository.updateApplicationStatus(
      jobId: jobId,
      applicationId: application.id,
      status: ApplicationStatus.rejected,
    );
    state = state.whenData(
      (applications) => [
        for (final existing in applications)
          if (existing.id == updated.id) updated else existing,
      ],
    );
  }
}

/// GET /jobs/:id/applications/summary — the AI-assisted applicant
/// summary shown on `JobApplicantsScreen` when the job's own
/// `applicationSummaryEnabled` toggle is on. A plain `FutureProvider`
/// (not a `StateNotifier` like [jobApplicationsProvider]) since this is
/// read-only — nothing on the summary screen mutates it in place, so
/// there's no in-place-splice state to manage, just refetch via
/// `ref.invalidate` if the applicant list changes underneath it.
///
/// Keyed by a `(jobId, sortBy)` record rather than just `jobId` so
/// switching the sort control on `ApplicationSummaryScreen` (recent /
/// gpa / experience) refetches under its own cache entry instead of
/// colliding with the default view — records get free `==`/`hashCode`,
/// which is all `.family` needs for this to work.
final applicationSummaryProvider = FutureProvider.family<ApplicationSummaryResult,
    ({String jobId, String sortBy})>((ref, params) {
  return ref
      .watch(jobsRepositoryProvider)
      .fetchApplicationSummary(params.jobId, sortBy: params.sortBy);
});

/// JS-03: the seeker job board. Bundles the active filter/page params
/// with the async result, same shape as `CandidatesNotifier` on the
/// employer side — one thing for `JobBoardScreen` to watch.
class JobBoardState {
  const JobBoardState({
    required this.params,
    required this.result,
    this.appliedJobIds = const {},
    this.isLoadingMore = false,
  });

  final JobBrowseParams params;
  final AsyncValue<JobBrowseResult> result;

  // JS-05: job ids the current seeker has applied to during this
  // session, so `_JobCard` can show "Applied" instead of "Apply"
  // without a separate per-job lookup. Session-scoped, not persisted —
  // see `JobBoardNotifier.applyToJob`'s doc comment.
  final Set<String> appliedJobIds;

  // True while `loadMore` is fetching the next page for the infinite
  // scroll layout (mobile / landing — see `JobBoardScreen`). Kept
  // separate from `result`'s own loading state so the already-loaded
  // cards stay on screen with a trailing spinner underneath them,
  // rather than the whole list flashing to a full-screen loading state
  // the way a filter change or `nextPage`/`previousPage` does.
  final bool isLoadingMore;

  JobBoardState copyWith({
    JobBrowseParams? params,
    AsyncValue<JobBrowseResult>? result,
    Set<String>? appliedJobIds,
    bool? isLoadingMore,
  }) =>
      JobBoardState(
        params: params ?? this.params,
        result: result ?? this.result,
        appliedJobIds: appliedJobIds ?? this.appliedJobIds,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );

  /// Whether there's (probably) another page beyond what's currently
  /// loaded — same "did the last page come back full" heuristic
  /// `nextPage`/`loadMore` use to decide whether to bother fetching.
  bool get hasMore => result.maybeWhen(
        data: (r) => r.jobs.length >= params.limit,
        orElse: () => false,
      );
}

final jobBoardProvider =
    StateNotifierProvider<JobBoardNotifier, JobBoardState>((ref) {
  return JobBoardNotifier(ref.watch(jobsRepositoryProvider))..search();
});

class JobBoardNotifier extends StateNotifier<JobBoardState> {
  JobBoardNotifier(this._repository)
      : super(
          const JobBoardState(
            params: JobBrowseParams(),
            result: AsyncValue.loading(),
          ),
        );

  final JobsRepository _repository;

  /// Runs a fresh search (page reset to 1) with the given filters.
  Future<void> search({
    String? keyword,
    String? location,
    JobType? jobType,
    bool clearJobType = false,
    String? category,
    bool clearCategory = false,
    List<String>? categories,
    bool clearCategories = false,
    String? creatorType,
    bool clearCreatorType = false,
    String? experienceLevel,
    bool clearExperienceLevel = false,
  }) {
    final params = state.params.copyWith(
      keyword: keyword,
      location: location,
      jobType: jobType,
      clearJobType: clearJobType,
      category: category,
      clearCategory: clearCategory,
      categories: categories,
      clearCategories: clearCategories,
      creatorType: creatorType,
      clearCreatorType: clearCreatorType,
      experienceLevel: experienceLevel,
      clearExperienceLevel: clearExperienceLevel,
      page: 1,
    );
    return _run(params);
  }

  Future<void> previousPage() {
    if (state.params.page <= 1) return Future.value();
    return _run(state.params.copyWith(page: state.params.page - 1));
  }

  Future<void> nextPage() {
    final atLastPage = state.result.maybeWhen(
      data: (r) => r.jobs.length < state.params.limit,
      orElse: () => true,
    );
    if (atLastPage) return Future.value();
    return _run(state.params.copyWith(page: state.params.page + 1));
  }

  /// Infinite-scroll counterpart to [nextPage] — used by the mobile and
  /// landing-page layouts (see `JobBoardScreen`) instead of the Previous
  /// / Next buttons. Fetches the next page and appends it to the jobs
  /// already on screen rather than replacing them, and tracks its own
  /// [JobBoardState.isLoadingMore] flag instead of putting `result` back
  /// into `AsyncValue.loading()` — that would blank out everything
  /// already loaded just to show a couple more cards.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final currentJobs = state.result.valueOrNull?.jobs ?? const <Job>[];
    final nextParams = state.params.copyWith(page: state.params.page + 1);
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextResult = await _repository.browseJobs(nextParams);
      if (!mounted) return;
      state = state.copyWith(
        params: nextParams,
        result: AsyncValue.data(
          JobBrowseResult(
            jobs: [...currentJobs, ...nextResult.jobs],
            page: nextResult.page,
            limit: nextResult.limit,
            count: nextResult.count,
            isMock: nextResult.isMock,
          ),
        ),
        isLoadingMore: false,
      );
    } catch (_) {
      // Leave the already-loaded cards in place on failure — surfacing
      // a full error state here would throw away a scroll's worth of
      // jobs the seeker can already see just because one "load more"
      // request failed. Dropping `isLoadingMore` lets the same scroll
      // trigger (or a manual retry, once one exists) try again.
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> _run(JobBrowseParams params) async {
    state = state.copyWith(params: params, result: const AsyncValue.loading());
    try {
      final result = await _repository.browseJobs(params);
      state = state.copyWith(result: AsyncValue.data(result));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }

  /// JS-05: applies to [job] on behalf of the current seeker. Rethrows
  /// [ApiException] so the job card can show its own error via a
  /// snackbar rather than losing the current result list. On success,
  /// marks the job as applied in-memory only (not re-fetched from the
  /// server) — the same session-scoped tracking a fresh screen instance
  /// won't have, but the backend's own idempotent apply means tapping
  /// "Apply" again after a reload is always safe regardless.
  Future<bool> applyToJob(Job job) async {
    final result = await _repository.applyToJob(job.id);
    state = state.copyWith(
      appliedJobIds: {...state.appliedJobIds, job.id},
    );
    return result.alreadyApplied;
  }
}

/// JS-03: a seeker's saved searches + alert preferences.
final savedSearchesProvider =
    StateNotifierProvider<SavedSearchesNotifier, AsyncValue<List<SavedSearch>>>(
        (ref) {
  return SavedSearchesNotifier(ref.watch(jobsRepositoryProvider))..load();
});

class SavedSearchesNotifier extends StateNotifier<AsyncValue<List<SavedSearch>>> {
  SavedSearchesNotifier(this._repository) : super(const AsyncValue.loading());

  final JobsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final searches = await _repository.fetchSavedSearches();
      state = AsyncValue.data(searches);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Saves the job board's current filters as a new saved search, and
  /// prepends it to the in-memory list on success.
  Future<void> saveCurrentFilters(JobBrowseParams params) async {
    final saved = await _repository
        .createSavedSearch(CreateSavedSearchPayload.fromBrowseParams(params));
    state = state.whenData((searches) => [saved, ...searches]);
  }

  /// Flips a saved search's alert-preference toggle.
  Future<void> toggleAlerts(SavedSearch savedSearch) async {
    final updated = await _repository.updateSavedSearch(
      savedSearch.id,
      alertsEnabled: !savedSearch.alertsEnabled,
    );
    state = state.whenData(
      (searches) => [
        for (final existing in searches)
          if (existing.id == updated.id) updated else existing,
      ],
    );
  }

  Future<void> delete(String id) async {
    await _repository.deleteSavedSearch(id);
    state = state.whenData(
      (searches) => searches.where((s) => s.id != id).toList(),
    );
  }
}

class MyJobsNotifier extends StateNotifier<AsyncValue<List<Job>>> {
  MyJobsNotifier(this._repository) : super(const AsyncValue.loading());

  final JobsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final jobs = await _repository.fetchMyJobs();
      state = AsyncValue.data(jobs);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Creates the job on the backend and, on success, prepends it to the
  /// in-memory list so the dashboard reflects it immediately. Rethrows on
  /// failure so the posting form can show its own error message.
  Future<void> createJob(CreateJobPayload payload) async {
    final job = await _repository.createJob(payload);
    state = state.whenData((jobs) => [job, ...jobs]);
  }

  /// Saves edits to an existing job's content (title, description,
  /// location, salary, job type, category, skills, experience level).
  /// Rethrows
  /// [ApiException] on failure so the edit form can show its own error
  /// without losing what the employer typed. Splices the updated job
  /// back into the in-memory list in place, same pattern as
  /// [toggleStatus].
  Future<void> updateJob(String jobId, UpdateJobPayload payload) async {
    final updated = await _repository.updateJob(jobId, payload);
    state = state.whenData(
      (jobs) => [
        for (final existing in jobs)
          if (existing.id == updated.id) updated else existing,
      ],
    );
  }

  /// Flips a job between open/closed. Rethrows [ApiException] on failure
  /// so the dashboard can surface it without losing the current list.
  Future<void> toggleStatus(Job job) async {
    final nextStatus =
        job.status == JobStatus.open ? JobStatus.closed : JobStatus.open;
    final updated = await _repository.updateJobStatus(job.id, nextStatus);
    state = state.whenData(
      (jobs) => [
        for (final existing in jobs)
          if (existing.id == updated.id) updated else existing,
      ],
    );
  }
}
