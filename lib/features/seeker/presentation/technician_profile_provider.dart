import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import 'nearby_experts_provider.dart' show technicianRepositoryProvider;
import '../data/technician_repository.dart';
import '../domain/technician.dart';

/// The signed-in seeker's own Technician profile, if they've registered
/// one. Loads on first watch; [TechnicianRegistrationScreen] (both the
/// onboarding "register" flow and the later "edit" entry from the
/// account screen) reads/writes this one instance.
///
/// Doesn't auto-load the way `myProfileProvider` (Seeker) does — a
/// fresh account almost certainly has no Technician profile yet (a 404
/// is the *expected* first load, not an error state to show), so
/// [TechnicianRegistrationScreen] calls [MyTechnicianProfileNotifier.load]
/// itself and treats "not found" as "show a blank registration form"
/// rather than an error banner.
final myTechnicianProfileProvider = StateNotifierProvider.autoDispose<
    MyTechnicianProfileNotifier, AsyncValue<Technician?>>((ref) {
  return MyTechnicianProfileNotifier(ref.watch(technicianRepositoryProvider));
});

class MyTechnicianProfileNotifier extends StateNotifier<AsyncValue<Technician?>> {
  MyTechnicianProfileNotifier(this._repository) : super(const AsyncValue.loading());

  final TechnicianRepository _repository;

  /// Loads the existing profile, if any. A 404 (no profile registered
  /// yet) resolves to `AsyncValue.data(null)` rather than
  /// `AsyncValue.error` — see this class's doc comment.
  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      if (error is ApiException && error.statusCode == 404) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  /// Rethrows on failure so the registration/edit form can show its own
  /// error instead of silently discarding what the person typed.
  Future<Technician> save({
    required String fullName,
    required String tradeCategory,
    List<String>? skills,
    String? bio,
    String? city,
    double? rateAmount,
    TechnicianRateUnit? rateUnit,
    bool clearRate = false,
  }) async {
    final updated = await _repository.upsertMyProfile(
      fullName: fullName,
      tradeCategory: tradeCategory,
      skills: skills,
      bio: bio,
      city: city,
      rateAmount: rateAmount,
      rateUnit: rateUnit,
      clearRate: clearRate,
    );
    state = AsyncValue.data(updated);
    return updated;
  }

  /// "Find a technician near you" registration/re-capture. Rethrows on
  /// failure so the caller can decide whether that's fatal (registration
  /// form) or safe to ignore (a background refresh).
  Future<Technician> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final updated = await _repository.updateLocation(
      latitude: latitude,
      longitude: longitude,
    );
    state = AsyncValue.data(updated);
    return updated;
  }

  /// Optimistically flips the switch, rolling back (and rethrowing) if
  /// the request fails — same shape as `MyProfileNotifier.toggleAvailability`
  /// (Seeker).
  Future<void> toggleAvailability(bool value) async {
    final previous = state;
    state = state.whenData((profile) => profile?.copyWith(availabilityStatus: value));
    try {
      final updated = await _repository.updateAvailability(value);
      state = AsyncValue.data(updated);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
