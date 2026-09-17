import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/ad.dart';

/// Talks to the current employer/agency's own `/ads` endpoints plus the
/// ad-specific payment initializer — same shape/guard pattern as
/// `EmployerRepository`/`JobsRepository`.
class AdsRepository {
  AdsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /ads/mine — every ad this account owns, any status.
  Future<List<Ad>> fetchMyAds() => _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>('/ads/mine');
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['ads'] as List<dynamic>)
            .map((json) => Ad.fromJson(json as Map<String, dynamic>))
            .toList();
      });

  /// POST /ads — creates a `draft` ad. Rejected with a clear message
  /// (ads.service.js#assertCanAdvertise) if this account's plan tier
  /// doesn't currently allow advertising.
  Future<Ad> createAd({
    required String title,
    required String subtitle,
    required AdIcon icon,
    String? linkUrl,
  }) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/ads',
          data: {
            'title': title,
            'subtitle': subtitle,
            'icon': icon.wireValue,
            if (linkUrl != null && linkUrl.isNotEmpty) 'link_url': linkUrl,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Ad.fromJson(data['ad'] as Map<String, dynamic>);
      });

  /// POST /payments/initialize-ad { adId } — returns the Chapa checkout
  /// URL to open externally, same pattern as
  /// SeekerProfileRepository.initializeBoost. Once Chapa confirms
  /// payment, /payments/verify-callback moves the ad to
  /// `pending_review`; it only shows up in the public carousel after
  /// an admin approves it from there.
  Future<String> initializeAdPayment(String adId) => _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/payments/initialize-ad',
          data: {'adId': adId},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return data['checkoutUrl'] as String;
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
