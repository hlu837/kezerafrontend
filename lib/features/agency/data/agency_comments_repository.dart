import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../jobs/domain/job.dart';
import '../domain/agency_comment.dart';

/// Talks to the public `/agencies/:agencyId/profile` and
/// `/agencies/:agencyId/comments` endpoints (see
/// `agencyPublic.routes.js` on the backend). Unlike [AgencyRepository]
/// (the agency's own authenticated backoffice view), every read here
/// works for a logged-out guest too — [ApiClient] simply omits the
/// `Authorization` header when there's no token, which is all these
/// endpoints require.
///
/// `agencyId` throughout is the agency's *User* id — the same value as
/// `Job.creatorId` on any job the agency has posted (see
/// `AgencyComment.model.js`'s note on this), so callers coming from a
/// [Job] can pass `job.creatorId` straight through.
class AgencyCommentsRepository {
  AgencyCommentsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /agencies — the public agency directory ("Agencies" tab).
  /// [search] optionally filters by agency name or operational city.
  Future<AgencyDirectoryPage> fetchAgencies({
    int page = 1,
    int limit = 20,
    String? search,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/agencies',
          queryParameters: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyDirectoryPage.fromJson(data);
      });

  /// GET /agencies/nearby — no auth required. "Find agencies near you"
  /// map/list, mirroring `SeekerRepository.nearbySeekers`.
  Future<NearbyAgenciesResult> fetchNearbyAgencies(NearbyAgenciesParams params) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/agencies/nearby',
          queryParameters: params.toQuery(),
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return NearbyAgenciesResult.fromJson(data);
      });

  /// GET /agencies/:agencyId/profile
  Future<AgencyPublicProfile> fetchPublicProfile(String agencyId) =>
      _guard(() async {
        final response = await _apiClient.dio
            .get<Map<String, dynamic>>('/agencies/$agencyId/profile');
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyPublicProfile.fromJson(
          data['agency'] as Map<String, dynamic>,
        );
      });

  /// GET /agencies/:agencyId/comments
  Future<AgencyCommentsPage> fetchComments(
    String agencyId, {
    int page = 1,
    int limit = 20,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/agencies/$agencyId/comments',
          queryParameters: {'page': page, 'limit': limit},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyCommentsPage.fromJson(data);
      });

  /// POST /agencies/:agencyId/comments — requires being logged in as
  /// any role except this same agency; the backend enforces that, this
  /// just surfaces whatever [ApiException] it returns.
  Future<AgencyComment> postComment(
    String agencyId, {
    required String body,
    int? rating,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/agencies/$agencyId/comments',
          data: {
            'body': body,
            if (rating != null) 'rating': rating,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyComment.fromJson(data['comment'] as Map<String, dynamic>);
      });

  /// GET /agencies/:agencyId/jobs — every open job this agency has
  /// posted, newest first. Same response shape as GET /jobs, so this
  /// reuses [JobBrowseResult.fromJson] rather than a separate model.
  Future<JobBrowseResult> fetchJobs(
    String agencyId, {
    int page = 1,
    int limit = 20,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/agencies/$agencyId/jobs',
          queryParameters: {'page': page, 'limit': limit},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return JobBrowseResult.fromJson(data);
      });

  /// DELETE /agencies/:agencyId/comments/:commentId — only the
  /// comment's own author (or an admin) may call this successfully.
  Future<void> deleteComment(String agencyId, String commentId) =>
      _guard(() async {
        await _apiClient.dio
            .delete<void>('/agencies/$agencyId/comments/$commentId');
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
