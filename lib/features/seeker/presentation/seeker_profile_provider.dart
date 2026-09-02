import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../../auth/presentation/auth_provider.dart';
import '../../jobs/domain/application.dart';
import '../data/seeker_profile_repository.dart';
import '../domain/experience_level.dart';
import '../domain/seeker.dart';

final seekerProfileRepositoryProvider =
    Provider<SeekerProfileRepository>((ref) {
  return SeekerProfileRepository(ref.watch(apiClientProvider));
});

/// The logged-in seeker's own profile. Loads on first watch; the dashboard
/// screen's view, edit-profile dialog, availability switch, and upload
/// buttons all read/act on this one instance so a change from any of them
/// shows up everywhere without a manual refetch.
final myProfileProvider =
    StateNotifierProvider<MyProfileNotifier, AsyncValue<Seeker>>((ref) {
  return MyProfileNotifier(ref.watch(seekerProfileRepositoryProvider))
    ..load();
});

/// JS-05: "My Applications" — the jobs this seeker has applied to, with
/// status. A plain `FutureProvider` (no notifier) since nothing on this
/// screen mutates it; `ref.refresh(myApplicationsProvider.future)`
/// covers pull-to-refresh.
final myApplicationsProvider = FutureProvider<List<MyApplication>>((ref) {
  return ref.watch(seekerProfileRepositoryProvider).fetchMyApplications();
});

class MyProfileNotifier extends StateNotifier<AsyncValue<Seeker>> {  MyProfileNotifier(this._repository) : super(const AsyncValue.loading());

  final SeekerProfileRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Rethrows [ApiException] on failure so the edit dialog (or the CV
  /// review screen, for `skills`/`city`) can show its own error instead of
  /// losing the currently-displayed profile.
  Future<void> updateProfile({
    String? fullName,
    String? bio,
    List<String>? skills,
    String? city,
    ExperienceLevel? experienceLevel,
    bool clearExperienceLevel = false,
  }) async {
    final updated = await _repository.updateMyProfile(
      fullName: fullName,
      bio: bio,
      skills: skills,
      city: city,
      experienceLevel: experienceLevel,
      clearExperienceLevel: clearExperienceLevel,
    );
    state = AsyncValue.data(updated);
  }

  /// SEEK-01 onboarding screen's "Save & Continue". Rethrows
  /// [ApiException] on failure so the screen can show its own error
  /// instead of navigating forward on a failed save.
  Future<Seeker> savePreferences({
    required List<String> categories,
    required bool locationOptIn,
  }) async {
    final updated = await _repository.updatePreferences(
      categories: categories,
      locationOptIn: locationOptIn,
    );
    state = AsyncValue.data(updated);
    return updated;
  }

  /// Optimistically flips the switch so it feels immediate, then rolls
  /// back to the previous state (and rethrows) if the request fails.
  Future<void> toggleAvailability(bool value) async {
    final previous = state;
    state = state.whenData(
      (profile) => profile.copyWith(availabilityStatus: value),
    );
    try {
      final updated = await _repository.updateAvailability(value);
      state = AsyncValue.data(updated);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Returns the post-upload profile so callers (the CV upload flow, in
  /// particular) can diff it against the profile they had beforehand to
  /// figure out which fields the backend's CV auto-fill actually changed —
  /// see cv_review_screen.dart.
  Future<Seeker> uploadFiles({
    WalkInAttachment? cv,
    WalkInAttachment? photo,
  }) async {
    final updated = await _repository.uploadFiles(cv: cv, photo: photo);
    state = AsyncValue.data(updated);
    return updated;
  }

  /// CV-03 wizard's "Save & exit" — persists builder progress without
  /// generating a PDF. Rethrows [ApiException] so the wizard can show its
  /// own error instead of losing the in-progress draft.
  Future<Seeker> saveCvBuilderData({
    List<CvExperience>? experience,
    List<CvEducation>? education,
    List<CvLanguage>? languages,
    CvTemplate? template,
  }) async {
    final updated = await _repository.saveCvBuilderData(
      experience: experience,
      education: education,
      languages: languages,
      template: template,
    );
    state = AsyncValue.data(updated);
    return updated;
  }

  /// CV-03 wizard's final "Generate CV" step. Rethrows [ApiException] so
  /// the review step can show its own error instead of silently failing.
  Future<Seeker> generateCv({
    required CvTemplate template,
    required List<CvExperience> experience,
    required List<CvEducation> education,
    required List<CvLanguage> languages,
  }) async {
    final updated = await _repository.generateCv(
      template: template,
      experience: experience,
      education: education,
      languages: languages,
    );
    state = AsyncValue.data(updated);
    return updated;
  }

  /// SEEK-xx "Boost my profile" card's CTA. Returns the Chapa checkout
  /// URL to open — unlike every other mutation on this notifier, this
  /// doesn't update [state] itself: `boostedUntil` is only set
  /// server-side once the payment is verified (see payment.routes.js's
  /// /verify-callback), so there's nothing to reflect optimistically.
  /// Call [load] after the person returns from checkout to pick up the
  /// new value.
  Future<String> initiateBoost() => _repository.initializeBoost();
}
