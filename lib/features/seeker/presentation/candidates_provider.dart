import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/seeker_repository.dart';
import '../domain/experience_level.dart';
import '../domain/seeker.dart';

final seekerRepositoryProvider = Provider<SeekerRepository>((ref) {
  return SeekerRepository(ref.watch(apiClientProvider));
});

/// Bundles the active filter/page params with the async result of running
/// them, so the Candidates screen has one thing to watch.
class CandidatesState {
  const CandidatesState({required this.params, required this.result});

  final SearchSeekersParams params;
  final AsyncValue<SearchSeekersResult> result;

  CandidatesState copyWith({
    SearchSeekersParams? params,
    AsyncValue<SearchSeekersResult>? result,
  }) =>
      CandidatesState(
        params: params ?? this.params,
        result: result ?? this.result,
      );
}

/// Employer/agency candidate search — mirrors
/// `web-backoffice/src/app/employer/candidates/page.tsx`'s state: a filter
/// form (keyword/city/skills) that resets to page 1 on submit, plus
/// previous/next pagination that re-runs the same filters.
final candidatesProvider =
    StateNotifierProvider<CandidatesNotifier, CandidatesState>((ref) {
  return CandidatesNotifier(ref.watch(seekerRepositoryProvider))..search();
});

class CandidatesNotifier extends StateNotifier<CandidatesState> {
  CandidatesNotifier(this._repository)
      : super(
          const CandidatesState(
            params: SearchSeekersParams(),
            result: AsyncValue.loading(),
          ),
        );

  final SeekerRepository _repository;

  /// Runs a fresh search (page reset to 1) with the given filters. Called
  /// both on first load (with defaults) and whenever the filter form is
  /// submitted. Pass [category]/[experienceLevel] as `null` with the
  /// matching `clear...` flag set to reset a dropdown to "Any" — see
  /// `SearchSeekersParams.copyWith`.
  Future<void> search({
    String? keyword,
    String? city,
    List<String>? skills,
    String? category,
    bool clearCategory = false,
    ExperienceLevel? experienceLevel,
    bool clearExperienceLevel = false,
  }) {
    final params = state.params.copyWith(
      keyword: keyword,
      city: city,
      skills: skills,
      category: category,
      clearCategory: clearCategory,
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
    // Use the server's reported page size/limit rather than the
    // client-requested one — a Basic/Premium caller's `limit` gets
    // silently clamped down server-side (see
    // seeker.service.js#searchSeekers), and `limitReached` is the
    // authoritative "no more pages this plan can see" signal once a
    // tier's visibility ceiling has been hit.
    final atLastPage = state.result.maybeWhen(
      data: (r) => r.limitReached || r.seekers.length < r.limit,
      orElse: () => true,
    );
    if (atLastPage) return Future.value();
    return _run(state.params.copyWith(page: state.params.page + 1));
  }

  Future<void> _run(SearchSeekersParams params) async {
    state = state.copyWith(params: params, result: const AsyncValue.loading());
    try {
      final result = await _repository.searchSeekers(params);
      state = state.copyWith(result: AsyncValue.data(result));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }
}
