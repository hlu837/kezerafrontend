import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/seeker.dart' show ExpertCategoryCount;
import '../domain/technician.dart';

/// Talks to the `/technicians` endpoints — the Trade Technician
/// counterpart to [SeekerRepository]: the guest-facing map/directory
/// reads (Phase 4) plus the signed-in seeker's own profile
/// registration/editing (Phase 5, `/technicians/me`).
class TechnicianRepository {
  TechnicianRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /technicians/nearby — no auth required. "Find a technician
  /// near you": given a search center, returns technicians within
  /// `params.radiusKm`, nearest first, each with a `distanceKm` label —
  /// see technician.service.js#nearbyTechnicians.
  Future<NearbyTechniciansResult> nearbyTechnicians(NearbyTechniciansParams params) =>
      _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/technicians/nearby',
          queryParameters: params.toQuery(),
        );
        return NearbyTechniciansResult.fromJson(
          response.data!['data'] as Map<String, dynamic>,
        );
      });

  /// GET /technicians/trade-categories — no auth required. "Trade
  /// Technicians" directory landing page: every trade category with
  /// how many currently-available technicians are listed under it.
  /// Same `{ key, label, count }` row shape as
  /// `SeekerRepository.expertCategoryCounts`, so [ExpertCategoryCount]
  /// is reused rather than duplicated.
  Future<List<ExpertCategoryCount>> tradeCategoryCounts() => _guard(() async {
        final response = await _apiClient.dio
            .get<Map<String, dynamic>>('/technicians/trade-categories');
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['categories'] as List<dynamic>)
            .map((c) => ExpertCategoryCount.fromJson(c as Map<String, dynamic>))
            .toList();
      });

  /// GET /technicians/me (seeker-role auth required). The signed-in
  /// user's own Technician profile, if they've registered one —
  /// 404s (surfaced as an [ApiException]) if they haven't yet.
  Future<Technician> getMyProfile() => _guard(() async {
        final response =
            await _apiClient.dio.get<Map<String, dynamic>>('/technicians/me');
        final data = response.data!['data'] as Map<String, dynamic>;
        return Technician.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /technicians/me — upsert: creates the profile on first call
  /// (registration), updates it on every call after (editing). See
  /// `updateProfileSchema` on the backend — `fullName`/`tradeCategory`
  /// are always required (unlike Seeker's optional `tradeCategory`, a
  /// Technician profile has no sensible "not a tradesperson" default).
  /// `rateAmount`/`rateUnit` are both-or-neither; pass `clearRate: true`
  /// to explicitly wipe a previously-set rate.
  Future<Technician> upsertMyProfile({
    required String fullName,
    required String tradeCategory,
    List<String>? skills,
    String? bio,
    String? city,
    double? rateAmount,
    TechnicianRateUnit? rateUnit,
    bool clearRate = false,
  }) =>
      _guard(() async {
        final body = <String, dynamic>{
          'full_name': fullName,
          'trade_category': tradeCategory,
          if (skills != null) 'skills': skills,
          if (bio != null) 'bio': bio,
          if (city != null) 'city': city,
          if (clearRate) ...{
            'rate_amount': null,
            'rate_unit': null,
          } else if (rateAmount != null && rateUnit != null) ...{
            'rate_amount': rateAmount,
            'rate_unit': rateUnit.wireValue,
          },
        };
        final response = await _apiClient.dio
            .patch<Map<String, dynamic>>('/technicians/me', data: body);
        final data = response.data!['data'] as Map<String, dynamic>;
        return Technician.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /technicians/me/availability — "step away" toggle without
  /// deleting the profile.
  Future<Technician> updateAvailability(bool availabilityStatus) => _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/technicians/me/availability',
          data: {'availability_status': availabilityStatus},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Technician.fromJson(data['profile'] as Map<String, dynamic>);
      });

  /// PATCH /technicians/me/location — "Find a technician near you"
  /// registration/re-capture. Both fields are required together
  /// server-side, same reasoning as the Seeker equivalent.
  Future<Technician> updateLocation({
    required double latitude,
    required double longitude,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/technicians/me/location',
          data: {'latitude': latitude, 'longitude': longitude},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Technician.fromJson(data['profile'] as Map<String, dynamic>);
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
