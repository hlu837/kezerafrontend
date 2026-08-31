import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../jobs/data/jobs_repository.dart';
import '../../jobs/domain/placement.dart';
import '../../jobs/presentation/jobs_provider.dart';
import '../data/agency_repository.dart';
import '../domain/agency_models.dart';

final agencyRepositoryProvider = Provider<AgencyRepository>((ref) {
  return AgencyRepository(ref.watch(apiClientProvider));
});

/// Every candidate the matching engine has placed against one of this
/// agency's own job postings, across every job — the same aggregation
/// `web-backoffice/src/app/agency/placements/page.tsx` does client-side:
/// fetch this agency's jobs, then fetch suggested-seekers per job and
/// flatten the result, newest first.
final placementsProvider =
    StateNotifierProvider<PlacementsNotifier, AsyncValue<List<SuggestedSeeker>>>(
        (ref) {
  return PlacementsNotifier(
    jobsRepository: ref.watch(jobsRepositoryProvider),
    agencyRepository: ref.watch(agencyRepositoryProvider),
  )..load();
});

class PlacementsNotifier extends StateNotifier<AsyncValue<List<SuggestedSeeker>>> {
  PlacementsNotifier({
    required this.jobsRepository,
    required this.agencyRepository,
  }) : super(const AsyncValue.loading());

  final JobsRepository jobsRepository;
  final AgencyRepository agencyRepository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final jobs = await jobsRepository.fetchMyJobs();
      final agencyJobs =
          jobs.where((job) => job.creatorType == 'agency').toList();

      final perJobRows = await Future.wait([
        for (final job in agencyJobs)
          jobsRepository.fetchSuggestedSeekers(job.id, jobTitle: job.title),
      ]);

      final flattened = perJobRows
          .expand((rows) => rows)
          .cast<SuggestedSeeker>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = AsyncValue.data(flattened);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Dispatches a single matched candidate to the job's poster and, on
  /// success, flips that row's status to "sent" in place — same optimistic
  /// update the web version does — so the pipeline reflects it without a
  /// full reload.
  Future<void> dispatch(SuggestedSeeker row) async {
    final seekerId = row.seekerId;
    if (seekerId == null) return;

    await agencyRepository.dispatchCandidates(
      DispatchPayload(jobId: row.jobId, seekerIds: [seekerId]),
    );

    state = state.whenData(
      (rows) => [
        for (final existing in rows)
          if (existing.placementId == row.placementId)
            existing.copyWith(status: PlacementStatus.sent)
          else
            existing,
      ],
    );
  }

  /// Advances a placement past "sent" — to "interviewed", or straight to
  /// "hired"/"rejected" — and, on success, updates that row's status in
  /// place. The backend enforces which transitions are actually valid
  /// from the placement's current status; an invalid one surfaces as an
  /// [ApiException] the caller (the screen) catches and displays.
  Future<void> updateStatus(SuggestedSeeker row, PlacementStatus newStatus) async {
    await agencyRepository.updatePlacementStatus(row.placementId, newStatus.name);

    state = state.whenData(
      (rows) => [
        for (final existing in rows)
          if (existing.placementId == row.placementId)
            existing.copyWith(status: newStatus)
          else
            existing,
      ],
    );
  }
}
