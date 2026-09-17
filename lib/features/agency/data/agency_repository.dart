import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/agency_finance.dart';
import '../domain/agency_models.dart';

/// Talks to the `/agencies` endpoints used by walk-in registration and the
/// placement pipeline. Same shape as `JobsRepository` — callers only ever
/// deal with [ApiException] on failure.
class AgencyRepository {
  AgencyRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /agencies/me
  Future<AgencyProfile> getMyProfile() => _guard(() async {
        final response =
            await _apiClient.dio.get<Map<String, dynamic>>('/agencies/me');
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyProfile.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /agencies/profile — partial update. Only `agency_name`,
  /// `operational_city`, `backoffice_phone`, `address`, `bio`, and
  /// `founded_year` are self-editable (agency.validator.js's
  /// updateProfileSchema); `logo_url` is set server-side via
  /// [uploadLogo] instead.
  Future<AgencyProfile> updateMyProfile({
    String? agencyName,
    String? operationalCity,
    String? backofficePhone,
    String? address,
    String? bio,
    int? foundedYear,
    bool clearFoundedYear = false,
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          if (agencyName != null) 'agency_name': agencyName,
          if (operationalCity != null) 'operational_city': operationalCity,
          if (backofficePhone != null) 'backoffice_phone': backofficePhone,
          if (address != null) 'address': address,
          if (bio != null) 'bio': bio,
          if (foundedYear != null) 'founded_year': foundedYear,
          if (clearFoundedYear) 'founded_year': null,
        };
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/agencies/profile',
          data: body,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyProfile.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /agencies/logo — multipart/form-data, field name "logo".
  /// Mirrors `EmployerRepository.uploadLogo`.
  Future<AgencyProfile> uploadLogo(WalkInAttachment logo) => _guard(() async {
        final formData = FormData.fromMap({
          'logo': MultipartFile.fromBytes(logo.bytes, filename: logo.filename),
        });
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/agencies/logo',
          data: formData,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyProfile.fromJson(data['profile'] as Map<String, dynamic>);
      });

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

  /// GET /agencies/candidates — this agency's own roster: every seeker
  /// it has registered as a walk-in (see [registerWalkIn]), filterable
  /// the same way as the public "Find candidates" search, plus an
  /// availability tri-state. Unlike that search, this is NOT restricted
  /// to available seekers by default — an agency needs to see its whole
  /// roster, including candidates already placed elsewhere.
  Future<AgencyCandidatesResult> fetchCandidates(
    AgencyCandidatesParams params,
  ) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/agencies/candidates',
          queryParameters: params.toQuery(),
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyCandidatesResult.fromJson(data);
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

  /// POST /agencies/finance/ledger — records a commission or
  /// registration-fee entry and returns it, plus the agency's running
  /// balance after it was applied. Backs "Manage commission".
  Future<LedgerEntryResult> recordLedgerEntry(LedgerEntryPayload payload) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/agencies/finance/ledger',
          data: payload.toJson(),
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return LedgerEntryResult.fromJson(data);
      });

  /// GET /agencies/dashboard/stats — today's (or [date]'s) operational
  /// KPIs and the running ledger balance. [date] defaults to "today"
  /// server-side when omitted.
  Future<AgencyDashboardStats> fetchDashboardStats({DateTime? date}) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/agencies/dashboard/stats',
          queryParameters: {
            if (date != null) 'date': date.toIso8601String(),
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return AgencyDashboardStats.fromJson(data);
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
