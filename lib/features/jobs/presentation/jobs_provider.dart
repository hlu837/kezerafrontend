import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/jobs_repository.dart';
import '../domain/application.dart';
import '../domain/job.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(apiClientProvider));
});

/// The current employer/agency's own job postings. Loads on first watch;
/// `PostJobScreen` and `EmployerDashboardScreen` both read/act on this one
/// instance so a newly-posted job or a status toggle shows up everywhere
/// without a manual refetch.
final myJobsProvider =
    StateNotifierProvider<MyJobsNotifier, AsyncValue<List<Job>>>((ref) {
  return MyJobsNotifier(ref.watch(jobsRepositoryProvider))..load();
});

/// JS-05: the direct applicants (with CV) for one of the current
/// employer/agency's own job postings — `JobApplicantsScreen` watches
/// one instance of this per job id it's opened for. `.family` (rather
/// than folding this into [myJobsProvider]) since it's fetched lazily,
/// only once an employer actually opens "View candidates" for a job.
final jobApplicationsProvider =
    FutureProvider.family<List<JobApplication>, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).fetchJobApplications(jobId);
});

/// JS-03: the seeker job board. Bundles the active filter/page params
/// with the async result, same shape as `CandidatesNotifier` on the
/// employer side — one thing for `JobBoardScreen` to watch.
class JobBoardState {
  const JobBoardState({
    required this.params,
    required this.result,
    this.appliedJobIds = const {},
  });

  final JobBrowseParams params;
  final AsyncValue<JobBrowseResult> result;

  // JS-05: job ids the current seeker has applied to during this
  // session, so `_JobCard` can show "Applied" instead of "Apply"
  // without a separate per-job lookup. Session-scoped, not persisted —
  // see `JobBoardNotifier.applyToJob`'s doc comment.
  final Set<String> appliedJobIds;

  JobBoardState copyWith({
    JobBrowseParams? params,
    AsyncValue<JobBrowseResult>? result,
    Set<String>? appliedJobIds,
  }) =>
      JobBoardState(
        params: params ?? this.params,
        result: result ?? this.result,
        appliedJobIds: appliedJobIds ?? this.appliedJobIds,
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
    List<String>? skills,
  }) {
    final params = state.params.copyWith(
      keyword: keyword,
      location: location,
      jobType: jobType,
      clearJobType: clearJobType,
      category: category,
      clearCategory: clearCategory,
      skills: skills,
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
