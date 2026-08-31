import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../../jobs/domain/application.dart';
import '../domain/seeker.dart';

/// Talks to the logged-in seeker's own `/seekers/me` endpoints — profile
/// view/edit, availability toggle, and CV/photo upload.
///
/// Deliberately separate from `SeekerRepository`
/// (features/seeker/data/seeker_repository.dart), which only covers the
/// employer/agency-facing `GET /seekers/search` endpoint — different
/// caller, different role, different auth guard on the backend
/// (`seeker.routes.js` registers `/search` under `authorizeRoles('employer',
/// 'agency')` before the blanket `authorizeRoles('seeker')` below it).
class SeekerProfileRepository {
  SeekerProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /seekers/me
  Future<Seeker> getMyProfile() => _guard(() async {
        final response =
            await _apiClient.dio.get<Map<String, dynamic>>('/seekers/me');
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /seekers/me — partial update. `full_name`/`bio` are always
  /// self-editable; `skills`/`city` are also accepted (CV-02) so the CV
  /// review screen can save corrections to what the CV auto-fill set on
  /// upload — only send those two when the caller actually means to
  /// overwrite them (a `null` here should mean "leave as-is", so callers
  /// pass the seeker's already-edited full list/value, never a partial one).
  Future<Seeker> updateMyProfile({
    String? fullName,
    String? bio,
    List<String>? skills,
    String? city,
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          if (fullName != null) 'full_name': fullName,
          if (bio != null) 'bio': bio,
          if (skills != null) 'skills': skills,
          if (city != null) 'city': city,
        };
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/seekers/me',
          data: body,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /seekers/me/availability
  Future<Seeker> updateAvailability(bool availabilityStatus) =>
      _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/seekers/me/availability',
          data: {'availability_status': availabilityStatus},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /seekers/me/preferences — SEEK-01 onboarding screen. Saves
  /// the seeker's chosen category keys (see `domain/job_category.dart`)
  /// and whether they granted location access.
  Future<Seeker> updatePreferences({
    required List<String> categories,
    required bool locationOptIn,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/seekers/me/preferences',
          data: {
            'categories': categories,
            'location_opt_in': locationOptIn,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /seekers/upload — multipart/form-data. Unlike the agency
  /// walk-in upload (which allows zero files), the backend's
  /// `validateUploadedFiles` here requires at least one of cv/photo.
  Future<Seeker> uploadFiles({
    WalkInAttachment? cv,
    WalkInAttachment? photo,
  }) =>
      _guard(() async {
        final formData = FormData();
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
          '/seekers/upload',
          data: formData,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /seekers/me/cv-builder — saves the CV builder's draft data
  /// (experience/education/languages + chosen template) WITHOUT
  /// (re)generating the PDF. Used for "Save & exit" partway through the
  /// wizard, so a seeker who backs out keeps their progress.
  Future<Seeker> saveCvBuilderData({
    List<CvExperience>? experience,
    List<CvEducation>? education,
    List<CvLanguage>? languages,
    CvTemplate? template,
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          if (experience != null)
            'experience': experience.map((e) => e.toJson()).toList(),
          if (education != null)
            'education': education.map((e) => e.toJson()).toList(),
          if (languages != null)
            'languages': languages.map((e) => e.toJson()).toList(),
          if (template != null) 'template': template.wireValue,
        };
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/seekers/me/cv-builder',
          data: body,
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /seekers/me/cv-builder/generate — CV-03. Saves the full CV
  /// builder payload (personal details are sent separately via the
  /// regular `updateMyProfile` call, same as every other profile edit)
  /// and renders it into a PDF server-side using the chosen `template`,
  /// then stores the result as this seeker's `cvUrl` — same field a
  /// plain file upload would set, so the rest of the app (dashboard's
  /// "CV / Resume" row, employer/agency candidate views) doesn't need to
  /// know a CV was builder-generated rather than uploaded.
  Future<Seeker> generateCv({
    required CvTemplate template,
    required List<CvExperience> experience,
    required List<CvEducation> education,
    required List<CvLanguage> languages,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/seekers/me/cv-builder/generate',
          data: {
            'template': template.wireValue,
            'experience': experience.map((e) => e.toJson()).toList(),
            'education': education.map((e) => e.toJson()).toList(),
            'languages': languages.map((e) => e.toJson()).toList(),
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Seeker.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// POST /payments/initialize-boost — SEEK-xx: pay a flat fee via Chapa
  /// to boost this seeker's visibility in employer/agency candidate
  /// search for a fixed window. Mirrors register_screen.dart's
  /// employer/agency subscription Chapa flow, but scoped to the
  /// already-authenticated seeker — no plan selection, boost is a single
  /// flat-rate product (see payment.routes.js's BOOST_PRICE).
  Future<String> initializeBoost() => _guard(() async {
        final response =
            await _apiClient.dio.post<Map<String, dynamic>>('/payments/initialize-boost');
        final data = response.data!['data'] as Map<String, dynamic>;
        return data['checkoutUrl'] as String;
      });

  /// GET /seekers/me/applications — JS-05: this seeker's own "jobs I've
  /// applied to" history, newest first, each with the job posting
  /// nested inline (`applications.service.js#getMyApplications`).
  Future<List<MyApplication>> fetchMyApplications() => _guard(() async {
        final response =
            await _apiClient.dio.get<Map<String, dynamic>>('/seekers/me/applications');
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['applications'] as List<dynamic>)
            .map((json) => MyApplication.fromJson(json as Map<String, dynamic>))
            .toList();
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
