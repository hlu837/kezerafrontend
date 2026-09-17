import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../domain/employer.dart';

/// Talks to the logged-in employer's own `/employers` endpoints — profile
/// view/edit and logo upload. Mirrors `SeekerProfileRepository`
/// (features/seeker/data/seeker_profile_repository.dart).
class EmployerRepository {
  EmployerRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /employers/me
  Future<Employer> getMyProfile() => _guard(() async {
        final response =
            await _apiClient.dio.get<Map<String, dynamic>>('/employers/me');
        final data = response.data!['data'] as Map<String, dynamic>;
        return Employer.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /employers/profile — partial update. Only `company_name`,
  /// `backoffice_phone`, and `promo_details` are self-editable
  /// (employer.validator.js's updateProfileSchema); `logo_url` is set
  /// server-side via [uploadLogo] instead.
  Future<Employer> updateMyProfile({
    String? companyName,
    String? backofficePhone,
    String? promoDetails,
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          if (companyName != null) 'company_name': companyName,
          if (backofficePhone != null) 'backoffice_phone': backofficePhone,
          if (promoDetails != null) 'promo_details': promoDetails,
        };
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/employers/profile',
          data: body,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Employer.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /employers/logo — multipart/form-data, field name "logo".
  Future<Employer> uploadLogo(WalkInAttachment logo) => _guard(() async {
        final formData = FormData.fromMap({
          'logo': MultipartFile.fromBytes(logo.bytes, filename: logo.filename),
        });
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/employers/logo',
          data: formData,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Employer.fromJson(data['profile'] as Map<String, dynamic>);
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
