import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../domain/user_model.dart';

/// Talks to the `/verification` endpoints (verification.routes.js) —
/// business-license upload/re-upload and the pending->rejected->pending
/// resubmit cycle for employer/agency accounts. Split out from
/// [AuthRepository] because these calls happen both mid-registration
/// (register_screen.dart, once the account has a token) and later, from
/// an already-authenticated rejected account (verification_resubmit_screen.dart).
class VerificationRepository {
  VerificationRepository(this._apiClient);

  final ApiClient _apiClient;

  /// POST /verification/license — multipart/form-data, field name
  /// "businessLicense". Works while pending OR rejected, so it doubles as
  /// the initial upload (right after registration) and a resubmission.
  /// Returns the stored file's URL.
  Future<String> uploadLicense(WalkInAttachment license) => _guard(() async {
        final formData = FormData.fromMap({
          'businessLicense': MultipartFile.fromBytes(
            license.bytes,
            filename: license.filename,
          ),
        });
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/verification/license',
          data: formData,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return data['businessLicenseUrl'] as String;
      });

  /// POST /verification/resubmit — resets a rejected account back to
  /// `pending` once a corrected license has been uploaded. Returns the
  /// updated user so the caller can refresh cached auth state.
  Future<AuthUser> resubmit() => _guard(() async {
        final response =
            await _apiClient.dio.post<Map<String, dynamic>>('/verification/resubmit');
        final data = response.data!['data'] as Map<String, dynamic>;
        return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
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
