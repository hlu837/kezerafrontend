import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/agency_models.dart';

/// Talks to the `/agencies` endpoints used by walk-in registration and the
/// placement pipeline. Same shape as `JobsRepository` — callers only ever
/// deal with [ApiException] on failure.
class AgencyRepository {
  AgencyRepository(this._apiClient);

  final ApiClient _apiClient;

  /// POST /agencies/walk-in — multipart/form-data, since cv/photo are
  /// optional file attachments (see backend's `upload.middleware.js`,
  /// which only accepts fields named `cv` and `photo`).
  Future<WalkInResult> registerWalkIn(
    WalkInPayload payload, {
    WalkInAttachment? cv,
    WalkInAttachment? photo,
  }) =>
      _guard(() async {
        final formData = FormData.fromMap(payload.toFields());
        if (cv != null) {
          formData.files.add(
            MapEntry(
              'cv',
              MultipartFile.fromBytes(cv.bytes, filename: cv.filename),
            ),
          );
        }
        if (photo != null) {
          formData.files.add(
            MapEntry(
              'photo',
              MultipartFile.fromBytes(photo.bytes, filename: photo.filename),
            ),
          );
        }

        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/agencies/walk-in',
          data: formData,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return WalkInResult.fromJson(data);
      });

  /// POST /agencies/dispatch — flips matched placements to "sent" and
  /// notifies the job poster.
  Future<void> dispatchCandidates(DispatchPayload payload) => _guard(() async {
        await _apiClient.dio.post<Map<String, dynamic>>(
          '/agencies/dispatch',
          data: payload.toJson(),
        );
      });

  /// PATCH /agencies/placements/:id/status — advances a placement past
  /// "sent" (to "interviewed", or straight to "hired"/"rejected"). The
  /// backend enforces which transitions are actually valid from the
  /// placement's current status; an invalid one comes back as a 409
  /// [ApiException].
  Future<void> updatePlacementStatus(
    String placementId,
    String newStatus,
  ) =>
      _guard(() async {
        await _apiClient.dio.patch<Map<String, dynamic>>(
          '/agencies/placements/$placementId/status',
          data: {'status': newStatus},
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
