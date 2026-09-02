import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/data/jobs_repository.dart';
import '../../jobs/domain/placement.dart';
import '../../jobs/presentation/jobs_provider.dart';

/// Every candidate the matching engine has placed against one of this
/// employer's own job postings, across every job — same client-side
/// aggregation `PlacementsNotifier` (agency side) does: fetch this
/// account's jobs, then fetch suggested-seekers per job and flatten the
/// result, newest first.
///
/// Unlike the agency pipeline, there's no dispatch/status-transition step
/// here (`POST /agencies/dispatches` and `PATCH
/// /agencies/placements/:id/status` are agency-only routes — see
/// `agency.routes.js`) — an employer's own jobs go straight to the
/// matching engine's output, so every row an employer sees is already
/// something they can act on directly, starting with messaging the
/// candidate (`/placements/:placementId/messages`, open to any
/// participant regardless of role — see
/// `utils/placementAccess.js#resolvePlacementForParticipant`).
final employerMessagesProvider =
    StateNotifierProvider<EmployerMessagesNotifier, AsyncValue<List<SuggestedSeeker>>>(
        (ref) {
  return EmployerMessagesNotifier(
    jobsRepository: ref.watch(jobsRepositoryProvider),
  )..load();
});

class EmployerMessagesNotifier
    extends StateNotifier<AsyncValue<List<SuggestedSeeker>>> {
  EmployerMessagesNotifier({required this.jobsRepository})
      : super(const AsyncValue.loading());

  final JobsRepository jobsRepository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final jobs = await jobsRepository.fetchMyJobs();
      final employerJobs =
          jobs.where((job) => job.creatorType == 'employer').toList();

      final perJobRows = await Future.wait([
        for (final job in employerJobs)
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
}
