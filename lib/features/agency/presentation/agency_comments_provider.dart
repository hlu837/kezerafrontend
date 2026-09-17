import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../jobs/domain/job.dart';
import '../data/agency_comments_repository.dart';
import '../domain/agency_comment.dart';

final agencyCommentsRepositoryProvider = Provider<AgencyCommentsRepository>((ref) {
  return AgencyCommentsRepository(ref.watch(apiClientProvider));
});

/// The public agency directory ("Agencies" tab) — a [StateNotifier]
/// rather than a plain `FutureProvider` since it supports search and
/// "load more" paging, same pattern as [AgencyCommentsNotifier] below.
final agencyDirectoryProvider =
    StateNotifierProvider<AgencyDirectoryNotifier, AsyncValue<AgencyDirectoryPage>>((ref) {
  return AgencyDirectoryNotifier(ref)..load();
});

class AgencyDirectoryNotifier extends StateNotifier<AsyncValue<AgencyDirectoryPage>> {
  AgencyDirectoryNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;
  String _search = '';

  AgencyCommentsRepository get _repository => _ref.read(agencyCommentsRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final page = await _repository.fetchAgencies(search: _search);
      state = AsyncValue.data(page);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Re-runs the search with a new query, from page 1.
  Future<void> search(String query) {
    _search = query.trim();
    return load();
  }

  /// Loads and appends the next page — used by a "Load more" action
  /// once the directory grows past one page.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;

    try {
      final next = await _repository.fetchAgencies(
        page: current.page + 1,
        search: _search,
      );
      state = AsyncValue.data(
        AgencyDirectoryPage(
          agencies: [...current.agencies, ...next.agencies],
          total: next.total,
          page: next.page,
          limit: next.limit,
        ),
      );
    } catch (_) {
      // A failed "load more" leaves the existing page visible rather
      // than replacing it with an error state.
    }
  }
}

/// One agency's public profile (bio/logo/name) — `.family` keyed by the
/// agency's user id so `AgencyProfileScreen` can watch just the one it
/// was opened for. A plain `FutureProvider`: unlike the comment feed
/// below, nothing on the screen mutates this in place.
final agencyPublicProfileProvider =
    FutureProvider.family<AgencyPublicProfile, String>((ref, agencyId) {
  return ref.watch(agencyCommentsRepositoryProvider).fetchPublicProfile(agencyId);
});

/// One agency's open job postings — `.family` keyed by agency id. Read
/// by `AgencyProfileScreen`'s "Jobs" section (GET /agencies/:agencyId/
/// jobs). A plain `FutureProvider`, same reasoning as
/// [agencyPublicProfileProvider]: nothing on that screen mutates this
/// list in place.
final agencyJobsProvider =
    FutureProvider.family<JobBrowseResult, String>((ref, agencyId) {
  return ref.watch(agencyCommentsRepositoryProvider).fetchJobs(agencyId);
});

/// One agency's comment feed — `.family` keyed by agency id. A
/// [StateNotifier] (not a plain `FutureProvider`) since posting or
/// deleting a comment updates the list in place, same pattern as
/// `NotificationsNotifier`.
final agencyCommentsProvider = StateNotifierProvider.family<AgencyCommentsNotifier,
    AsyncValue<AgencyCommentsPage>, String>((ref, agencyId) {
  return AgencyCommentsNotifier(ref, agencyId)..load();
});

class AgencyCommentsNotifier extends StateNotifier<AsyncValue<AgencyCommentsPage>> {
  AgencyCommentsNotifier(this._ref, this.agencyId) : super(const AsyncValue.loading());

  final Ref _ref;
  final String agencyId;

  AgencyCommentsRepository get _repository => _ref.read(agencyCommentsRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final page = await _repository.fetchComments(agencyId);
      state = AsyncValue.data(page);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Loads and appends the next page — used by a "Load more" action
  /// once the feed grows past one page.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;

    try {
      final next = await _repository.fetchComments(agencyId, page: current.page + 1);
      state = AsyncValue.data(
        AgencyCommentsPage(
          comments: [...current.comments, ...next.comments],
          total: next.total,
          page: next.page,
          limit: next.limit,
          averageRating: next.averageRating,
        ),
      );
    } catch (_) {
      // A failed "load more" leaves the existing page visible rather
      // than replacing it with an error state.
    }
  }

  /// Posts a new comment and inserts it at the top of the feed. Throws
  /// [ApiException] on failure so the composer UI can show the message
  /// inline; the feed itself is left untouched on failure.
  Future<void> addComment({required String body, int? rating}) async {
    final comment = await _repository.postComment(agencyId, body: body, rating: rating);

    final current = state.value;
    if (current == null) {
      await load();
      return;
    }
    state = AsyncValue.data(
      AgencyCommentsPage(
        comments: [comment, ...current.comments],
        total: current.total + 1,
        page: current.page,
        limit: current.limit,
        averageRating: current.averageRating,
      ),
    );
  }

  /// Removes a comment (the caller's own, or an admin's privilege) from
  /// the feed. Optimistic, same as `NotificationsNotifier`'s deletes —
  /// this is fired from a confirmed "Delete" action, so there's nothing
  /// useful to roll back to on failure beyond a reload.
  Future<void> deleteComment(String commentId) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      AgencyCommentsPage(
        comments: [
          for (final comment in current.comments)
            if (comment.id != commentId) comment,
        ],
        total: current.total - 1,
        page: current.page,
        limit: current.limit,
        averageRating: current.averageRating,
      ),
    );

    try {
      await _repository.deleteComment(agencyId, commentId);
    } catch (_) {
      await load();
    }
  }
}
