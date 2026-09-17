import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/service_request.dart';

/// Talks to the `/service-requests` endpoints — "Request Service" from
/// the Experts/Agencies map, plus the resulting My Requests / Incoming
/// inbox screens. Same `_guard`-wrapped shape as `AgencyRepository`:
/// callers only ever deal with [ApiException] on failure.
class ServiceRequestsRepository {
  ServiceRequestsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// POST /service-requests — booking a one-off job from an Expert or
  /// Agency found via the guest-facing map/directory.
  Future<ServiceRequest> createServiceRequest(CreateServiceRequestPayload payload) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/service-requests',
          data: payload.toJson(),
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceRequest.fromJson(data['serviceRequest'] as Map<String, dynamic>);
      });

  /// GET /service-requests/mine — the caller's own booking history,
  /// any role.
  Future<ServiceRequestsPage> fetchMyRequests({
    ServiceRequestStatus? status,
    int page = 1,
    int limit = 50,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/service-requests/mine',
          queryParameters: {
            if (status != null) 'status': status.name,
            'page': page,
            'limit': limit,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceRequestsPage.fromJson(data);
      });

  /// GET /service-requests/incoming — an Expert's (seeker role) or
  /// Agency's inbox of requests routed to them.
  Future<ServiceRequestsPage> fetchIncomingRequests({
    ServiceRequestStatus? status,
    int page = 1,
    int limit = 50,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/service-requests/incoming',
          queryParameters: {
            if (status != null) 'status': status.name,
            'page': page,
            'limit': limit,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceRequestsPage.fromJson(data);
      });

  /// POST /service-requests/:id/assign — an agency handing an
  /// agency-routed request to one of its own roster seekers.
  Future<ServiceRequest> assignToSeeker(String requestId, String seekerId) => _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/service-requests/$requestId/assign',
          data: {'seekerId': seekerId},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceRequest.fromJson(data['serviceRequest'] as Map<String, dynamic>);
      });

  /// POST /service-requests/:id/respond — the currently-assigned Expert
  /// accepting or declining. [accept] false sends 'decline'.
  Future<ServiceRequest> respondToRequest(String requestId, {required bool accept}) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/service-requests/$requestId/respond',
          data: {'action': accept ? 'accept' : 'decline'},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceRequest.fromJson(data['serviceRequest'] as Map<String, dynamic>);
      });

  /// PATCH /service-requests/:id/status — mark 'completed' or
  /// 'cancelled'. Open to the requester, the assigned Expert, or the
  /// target Agency (enforced server-side).
  Future<ServiceRequest> updateStatus(String requestId, {required bool completed}) =>
      _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/service-requests/$requestId/status',
          data: {'status': completed ? 'completed' : 'cancelled'},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceRequest.fromJson(data['serviceRequest'] as Map<String, dynamic>);
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
