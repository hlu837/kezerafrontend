import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/ads_repository.dart';
import '../domain/ad.dart';

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(ref.watch(apiClientProvider));
});

/// The current employer/agency's own ads (any status). Loads on first
/// watch; `EmployerAdvertiseScreen` reads/acts on this one instance so a
/// newly-created or newly-paid ad shows up immediately without a manual
/// refetch. Mirrors `myJobsProvider`.
final myAdsProvider = StateNotifierProvider<MyAdsNotifier, AsyncValue<List<Ad>>>((ref) {
  return MyAdsNotifier(ref.watch(adsRepositoryProvider))..load();
});

class MyAdsNotifier extends StateNotifier<AsyncValue<List<Ad>>> {
  MyAdsNotifier(this._repository) : super(const AsyncValue.loading());

  final AdsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final ads = await _repository.fetchMyAds();
      state = AsyncValue.data(ads);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Creates a draft ad and splices it into the current list so the
  /// "Create ad" sheet's caller can immediately move on to payment
  /// without waiting on a full [load] refetch.
  Future<Ad> createAd({
    required String title,
    required String subtitle,
    required AdIcon icon,
    String? linkUrl,
  }) async {
    final ad = await _repository.createAd(
      title: title,
      subtitle: subtitle,
      icon: icon,
      linkUrl: linkUrl,
    );
    final current = state.valueOrNull ?? const [];
    state = AsyncValue.data([ad, ...current]);
    return ad;
  }

  /// Returns the Chapa checkout URL for an existing draft/rejected ad —
  /// doesn't change local state itself; the ad's status only actually
  /// changes once Chapa's callback runs server-side, so callers should
  /// [load] again after the person returns from checkout.
  Future<String> initiateAdPayment(String adId) => _repository.initializeAdPayment(adId);
}
