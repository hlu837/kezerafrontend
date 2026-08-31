import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/seeker.dart';

/// Talks to the `/seekers` endpoints. For now just the employer/agency-only
/// search used by the Candidates page — same shape as `JobsRepository` /
/// `AgencyRepository`.
class SeekerRepository {
  SeekerRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /seekers/search (employer/agency only)
  Future<SearchSeekersResult> searchSeekers(SearchSeekersParams params) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/seekers/search',
          queryParameters: params.toQuery(),
        );
        return SearchSeekersResult.fromJson(
          response.data!['data'] as Map<String, dynamic>,
        );
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
