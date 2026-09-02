import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seeker_repository.dart';
import 'candidates_provider.dart' show seekerRepositoryProvider;
import '../domain/seeker.dart';

/// Bundles the active filter/page params with the async result, same
/// shape as `CandidatesState` in candidates_provider.dart — this is the
/// no-auth counterpart used by the public landing page's "Employee /
/// Expert" toggle (public_candidates_board_screen.dart).
class PublicCandidatesState {
  const PublicCandidatesState({required this.params, required this.result});

  final SearchSeekersParams params;
  final AsyncValue<SearchSeekersResult> result;

  PublicCandidatesState copyWith({
    SearchSeekersParams? params,
    AsyncValue<SearchSeekersResult>? result,
  }) =>
      PublicCandidatesState(
        params: params ?? this.params,
        result: result ?? this.result,
      );
}

/// Guest-facing candidate preview — hits `GET /seekers/public-search`
/// (no auth), a capped taster of the same pool the employer/agency-only
/// `candidatesProvider` searches.
final publicCandidatesProvider =
    StateNotifierProvider<PublicCandidatesNotifier, PublicCandidatesState>((ref) {
  return PublicCandidatesNotifier(ref.watch(seekerRepositoryProvider))..search();
});

class PublicCandidatesNotifier extends StateNotifier<PublicCandidatesState> {
  PublicCandidatesNotifier(this._repository)
      : super(
          const PublicCandidatesState(
            params: SearchSeekersParams(),
            result: AsyncValue.loading(),
          ),
        );

  final SeekerRepository _repository;

  Future<void> search({String? keyword, String? city, List<String>? skills}) {
    final params = state.params.copyWith(
      keyword: keyword,
      city: city,
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
      data: (r) => r.limitReached || r.seekers.length < r.limit,
      orElse: () => true,
    );
    if (atLastPage) return Future.value();
    return _run(state.params.copyWith(page: state.params.page + 1));
  }

  Future<void> _run(SearchSeekersParams params) async {
    state = state.copyWith(params: params, result: const AsyncValue.loading());
    try {
      final result = await _repository.publicSearchSeekers(params);
      state = state.copyWith(result: AsyncValue.data(result));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }
}
