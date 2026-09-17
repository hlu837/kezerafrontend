import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../../auth/presentation/auth_provider.dart';
import '../data/employer_repository.dart';
import '../domain/employer.dart';

final employerRepositoryProvider = Provider<EmployerRepository>((ref) {
  return EmployerRepository(ref.watch(apiClientProvider));
});

/// The logged-in employer's own company profile. Loads on first watch;
/// the account screen's view, edit-profile dialog, and logo picker all
/// read/act on this one instance so a change from any of them shows up
/// everywhere without a manual refetch. Mirrors `myProfileProvider`
/// (features/seeker/presentation/seeker_profile_provider.dart).
final myEmployerProfileProvider =
    StateNotifierProvider<MyEmployerProfileNotifier, AsyncValue<Employer>>(
        (ref) {
  return MyEmployerProfileNotifier(ref.watch(employerRepositoryProvider))
    ..load();
});

class MyEmployerProfileNotifier extends StateNotifier<AsyncValue<Employer>> {
  MyEmployerProfileNotifier(this._repository)
      : super(const AsyncValue.loading());

  final EmployerRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Rethrows [ApiException] on failure so the edit dialog can show its
  /// own error instead of losing the currently-displayed profile.
  Future<void> updateProfile({
    String? companyName,
    String? backofficePhone,
    String? promoDetails,
  }) async {
    final updated = await _repository.updateMyProfile(
      companyName: companyName,
      backofficePhone: backofficePhone,
      promoDetails: promoDetails,
    );
    state = AsyncValue.data(updated);
  }

  Future<void> uploadLogo(WalkInAttachment logo) async {
    final updated = await _repository.uploadLogo(logo);
    state = AsyncValue.data(updated);
  }
}
