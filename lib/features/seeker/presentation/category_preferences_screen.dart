import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/location/device_location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/job_category.dart';
import '../domain/seeker.dart';
import 'seeker_profile_provider.dart';

/// SEEK-01: Category & Preference Setup screen — the first thing a seeker
/// sees right after signing up (register_screen.dart navigates here on a
/// successful seeker registration). Also reused as the "Job preferences"
/// editor from the account screen for a returning seeker, via the same
/// `/seeker/onboarding/preferences` route (see app_router.dart) — in that
/// case the grid is pre-seeded with whatever categories are already saved
/// on `myProfileProvider`, so editing starts from the current selection
/// instead of a blank slate.
///
/// Collects at least one preferred job category so instant SMS job
/// alerts have something to match against, saved via
/// `PATCH /seekers/me/preferences`.
class CategoryPreferencesScreen extends ConsumerStatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  ConsumerState<CategoryPreferencesScreen> createState() =>
      _CategoryPreferencesScreenState();
}

class _CategoryPreferencesScreenState
    extends ConsumerState<CategoryPreferencesScreen> {
  final Set<String> _selectedCategories = {};
  bool _isSaving = false;
  bool _seededFromProfile = false;
  String? _errorMessage;

  bool get _canContinue => _selectedCategories.isNotEmpty && !_isSaving;

  @override
  void initState() {
    super.initState();
    // This screen doubles as the account screen's "Job preferences" editor
    // (see app_router.dart — both routes point here), not just first-run
    // onboarding. A brand-new seeker genuinely has no saved categories yet,
    // but a returning seeker's already-chosen ones need to show as
    // pre-selected — otherwise re-opening this screen looks like the
    // previous save was lost, and tapping "Save & Continue" from a blank
    // slate silently overwrites their real preferences with whatever
    // handful they happen to re-tap.
    //
    // `myProfileProvider` may already be loaded by the time this screen is
    // reached from the account screen, or may still be loading/unwatched
    // (fresh registration flow) — handle both by seeding immediately from
    // whatever state is available now, then again via `ref.listen` in
    // `build` if the data arrives after this frame.
    _seedFromProfile(ref.read(myProfileProvider));
  }

  void _seedFromProfile(AsyncValue<Seeker> profileState) {
    if (_seededFromProfile) return;
    profileState.whenData((seeker) {
      _seededFromProfile = true;
      if (seeker.preferredCategories.isEmpty) return;
      setState(() {
        _selectedCategories
          ..clear()
          ..addAll(seeker.preferredCategories);
      });
    });
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_selectedCategories.contains(key)) {
        _selectedCategories.remove(key);
      } else {
        _selectedCategories.add(key);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (!_canContinue) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // Best-effort device-GPS permission check — deliberately silent on
    // failure (denied permission, services off, no fix within the
    // timeout) so a seeker who doesn't want to share their location, or
    // is somewhere GPS can't resolve quickly, is never blocked from
    // finishing onboarding over it. `locationOptIn` reports whether this
    // actually succeeded, not just whether the person reached this screen.
    var locationGranted = false;
    try {
      await const DeviceLocationService().getCurrentLatLng();
      locationGranted = true;
    } on DeviceLocationException {
      // Left false — see comment above.
    } catch (_) {
      // Left false — see comment above.
    }

    try {
      await ref.read(myProfileProvider.notifier).savePreferences(
            categories: _selectedCategories.toList(),
            locationOptIn: locationGranted,
          );
      if (mounted) {
        // SEEK-01b: category/preferences are saved — next stop is the
        // Expert/Technician choice (CV vs Trade Technician), not the
        // dashboard directly.
        context.go('/seeker/onboarding/expert-choice');
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
      _showErrorSnack(e.message);
    } catch (_) {
      const fallback = 'Could not save your preferences. Please try again.';
      setState(() => _errorMessage = fallback);
      _showErrorSnack(fallback);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The `_errorMessage` banner lives near the TOP of this screen, above
  /// the category grid — but "Save & Continue" is at the bottom of a
  /// scrollable page, so a failure there was easy to miss entirely if
  /// the user was scrolled down to reach the button (looks exactly like
  /// "the button doesn't respond"). A SnackBar is always visible
  /// regardless of scroll position, so every failure now surfaces one
  /// in addition to the banner.
  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Catches the case where myProfileProvider was still loading when
    // initState ran (e.g. this screen reached first, before the profile
    // fetch resolves) — seeds the selection as soon as the data lands.
    ref.listen<AsyncValue<Seeker>>(myProfileProvider, (_, next) {
      _seedFromProfile(next);
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 20),
                  ],
                  _buildCategoryGrid(context),
                  const SizedBox(height: 32),
                  _buildBottomActionBar(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of work are you looking for?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Select your primary job category so we can send you instant '
          'SMS job alerts.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.inkMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: kJobCategories.length,
      itemBuilder: (context, index) {
        final category = kJobCategories[index];
        final isSelected = _selectedCategories.contains(category.key);
        return _CategoryCard(
          category: category,
          isSelected: isSelected,
          onTap: _isSaving ? null : () => _toggleCategory(category.key),
        );
      },
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return ElevatedButton(
      onPressed: _canContinue ? _saveAndContinue : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.inkFaint,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: _isSaving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text(
              'Save & Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final JobCategory category;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category.icon,
                  size: 28,
                  color: isSelected ? AppColors.greenDark : AppColors.inkMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  category.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.greenDark : AppColors.ink,
                      ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
