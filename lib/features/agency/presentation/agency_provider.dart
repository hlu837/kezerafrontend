import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../jobs/data/jobs_repository.dart';
import '../../jobs/domain/placement.dart';
import '../../jobs/presentation/jobs_provider.dart';
import '../../seeker/domain/experience_level.dart';
import '../data/agency_repository.dart';
import '../domain/agency_finance.dart';
import '../domain/agency_models.dart';

final agencyRepositoryProvider = Provider<AgencyRepository>((ref) {
  return AgencyRepository(ref.watch(apiClientProvider));
});

/// The logged-in agency's own profile. Loads on first watch; the account
/// screen's view and edit-profile dialog both read/act on this one
/// instance so a change shows up everywhere without a manual refetch.
/// Mirrors `myEmployerProfileProvider`
/// (features/employer/presentation/employer_profile_provider.dart).
final myAgencyProfileProvider =
    StateNotifierProvider<MyAgencyProfileNotifier, AsyncValue<AgencyProfile>>(
        (ref) {
  return MyAgencyProfileNotifier(ref.watch(agencyRepositoryProvider))..load();
});

class MyAgencyProfileNotifier extends StateNotifier<AsyncValue<AgencyProfile>> {
  MyAgencyProfileNotifier(this._repository) : super(const AsyncValue.loading());

  final AgencyRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Rethrows [ApiException] on failure so the edit dialog can show its
  /// own error instead of losing the currently-displayed profile.
  Future<void> updateProfile({
    String? agencyName,
    String? operationalCity,
    String? backofficePhone,
    String? address,
    String? bio,
    int? foundedYear,
    bool clearFoundedYear = false,
  }) async {
    final updated = await _repository.updateMyProfile(
      agencyName: agencyName,
      operationalCity: operationalCity,
      backofficePhone: backofficePhone,
      address: address,
      bio: bio,
      foundedYear: foundedYear,
      clearFoundedYear: clearFoundedYear,
    );
    state = AsyncValue.data(updated);
  }

  Future<void> uploadLogo(WalkInAttachment logo) async {
    final updated = await _repository.uploadLogo(logo);
    state = AsyncValue.data(updated);
  }
}

/// Bundles the active filter/page params with the async result, same
/// shape as `CandidatesState` (the employer "Find candidates" search) —
/// one thing for `AgencyCandidatesScreen` to watch.
class AgencyRosterState {
  const AgencyRosterState({required this.params, required this.result});

  final AgencyCandidatesParams params;
  final AsyncValue<AgencyCandidatesResult> result;

  AgencyRosterState copyWith({
    AgencyCandidatesParams? params,
    AsyncValue<AgencyCandidatesResult>? result,
  }) =>
      AgencyRosterState(
        params: params ?? this.params,
        result: result ?? this.result,
      );
}

/// This agency's own candidate roster (`GET /agencies/candidates`) —
/// every walk-in it has registered (see `registerWalkIn`), searchable by
/// keyword/city/experience level plus an availability filter. Backs
/// `AgencyCandidatesScreen`.
final agencyRosterProvider =
    StateNotifierProvider<AgencyRosterNotifier, AgencyRosterState>((ref) {
  return AgencyRosterNotifier(ref.watch(agencyRepositoryProvider))..search();
});

class AgencyRosterNotifier extends StateNotifier<AgencyRosterState> {
  AgencyRosterNotifier(this._repository)
      : super(
          const AgencyRosterState(
            params: AgencyCandidatesParams(),
            result: AsyncValue.loading(),
          ),
        );

  final AgencyRepository _repository;

  /// Runs a fresh search (page reset to 1) with the given filters. Called
  /// both on first load (with defaults) and whenever the filter form is
  /// submitted. Pass [availabilityStatus] as `null` with
  /// [clearAvailabilityStatus] set to reset the tri-state back to "All".
  Future<void> search({
    String? keyword,
    String? city,
    ExperienceLevel? experienceLevel,
    bool clearExperienceLevel = false,
    bool? availabilityStatus,
    bool clearAvailabilityStatus = false,
  }) {
    final params = state.params.copyWith(
      keyword: keyword,
      city: city,
      experienceLevel: experienceLevel,
      clearExperienceLevel: clearExperienceLevel,
      availabilityStatus: availabilityStatus,
      clearAvailabilityStatus: clearAvailabilityStatus,
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
      data: (r) => r.page >= r.totalPages,
      orElse: () => true,
    );
    if (atLastPage) return Future.value();
    return _run(state.params.copyWith(page: state.params.page + 1));
  }

  Future<void> _run(AgencyCandidatesParams params) async {
    state = state.copyWith(params: params, result: const AsyncValue.loading());
    try {
      final result = await _repository.fetchCandidates(params);
      state = state.copyWith(result: AsyncValue.data(result));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }
}

/// Bundles today's dashboard KPIs/ledger balance with whatever ledger
/// entries this agency has logged during the current session — there's
/// no GET endpoint to list historical entries (see
/// `agency.service.js#recordLedgerEntry`'s doc comment: only a create
/// + a same-day aggregate exist on the backend), so [recentEntries] is
/// purely a running local record of what was just added, most recent
/// first. Backs `AgencyCommissionScreen`.
class AgencyFinanceState {
  const AgencyFinanceState({
    required this.stats,
    this.recentEntries = const [],
  });

  final AsyncValue<AgencyDashboardStats> stats;
  final List<AgencyLedgerEntry> recentEntries;

  AgencyFinanceState copyWith({
    AsyncValue<AgencyDashboardStats>? stats,
    List<AgencyLedgerEntry>? recentEntries,
  }) =>
      AgencyFinanceState(
        stats: stats ?? this.stats,
        recentEntries: recentEntries ?? this.recentEntries,
      );
}

/// The logged-in agency's commission/registration-fee ledger — today's
/// KPIs (`GET /agencies/dashboard/stats`) plus the ability to log a new
/// entry (`POST /agencies/finance/ledger`). Loads on first watch.
final agencyFinanceProvider =
    StateNotifierProvider<AgencyFinanceNotifier, AgencyFinanceState>((ref) {
  return AgencyFinanceNotifier(ref.watch(agencyRepositoryProvider))..load();
});

class AgencyFinanceNotifier extends StateNotifier<AgencyFinanceState> {
  AgencyFinanceNotifier(this._repository)
      : super(const AgencyFinanceState(stats: AsyncValue.loading()));

  final AgencyRepository _repository;

  Future<void> load() async {
    state = state.copyWith(stats: const AsyncValue.loading());
    try {
      final stats = await _repository.fetchDashboardStats();
      state = state.copyWith(stats: AsyncValue.data(stats));
    } catch (error, stackTrace) {
      state = state.copyWith(stats: AsyncValue.error(error, stackTrace));
    }
  }

  /// Records a commission or registration-fee entry, adds it to the
  /// top of [AgencyFinanceState.recentEntries], and reloads today's
  /// stats so the revenue breakdown/balance reflect it immediately.
  /// Rethrows [ApiException] on failure so the form can show its own
  /// error without losing the current stats.
  Future<void> recordEntry(LedgerEntryPayload payload) async {
    final result = await _repository.recordLedgerEntry(payload);
    state = state.copyWith(
      recentEntries: [result.entry, ...state.recentEntries],
    );
    await load();
  }
}

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
