import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/job_category.dart';
import 'seeker_profile_provider.dart';

/// SEEK-01: Category & Preference Setup screen — the first thing a seeker
/// sees right after signing up (register_screen.dart navigates here on a
/// successful seeker registration).
///
/// Two jobs: (1) collect at least one preferred job category so instant
/// SMS job alerts have something to match against, and (2) ask for
/// location access up front so nearby-jobs search can work later. Both
/// are saved together via `PATCH /seekers/me/preferences`.
class CategoryPreferencesScreen extends ConsumerStatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  ConsumerState<CategoryPreferencesScreen> createState() =>
      _CategoryPreferencesScreenState();
}

enum _LocationBannerState { undecided, requesting, granted, skipped }

class _CategoryPreferencesScreenState
    extends ConsumerState<CategoryPreferencesScreen> {
  final Set<String> _selectedCategories = {};
  _LocationBannerState _locationState = _LocationBannerState.undecided;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _canContinue => _selectedCategories.isNotEmpty && !_isSaving;

  void _toggleCategory(String key) {
    setState(() {
      if (_selectedCategories.contains(key)) {
        _selectedCategories.remove(key);
      } else {
        _selectedCategories.add(key);
      }
    });
  }

  Future<void> _requestLocation() async {
    setState(() => _locationState = _LocationBannerState.requesting);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationState = _LocationBannerState.skipped);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      setState(() {
        _locationState =
            granted ? _LocationBannerState.granted : _LocationBannerState.skipped;
      });
    } catch (_) {
      // Permission plumbing differs across platforms (and isn't wired up
      // at all on desktop) — never let a location hiccup block onboarding.
      setState(() => _locationState = _LocationBannerState.skipped);
    }
  }

  void _skipLocation() {
    setState(() => _locationState = _LocationBannerState.skipped);
  }

  Future<void> _saveAndContinue() async {
    if (!_canContinue) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(myProfileProvider.notifier).savePreferences(
            categories: _selectedCategories.toList(),
            locationOptIn: _locationState == _LocationBannerState.granted,
          );
      if (mounted) {
        // SEEK-01b: category/preferences are saved — next stop is the CV
        // upload-or-build choice, not the dashboard directly.
        context.go('/seeker/onboarding/cv-choice');
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
                  const SizedBox(height: 24),
                  _buildLocationCard(context),
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
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
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

  Widget _buildLocationCard(BuildContext context) {
    final granted = _locationState == _LocationBannerState.granted;
    final skipped = _locationState == _LocationBannerState.skipped;
    final requesting = _locationState == _LocationBannerState.requesting;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted ? AppColors.green.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: granted ? AppColors.greenSurface : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.location_on : Icons.location_on_outlined,
              color: granted ? AppColors.green : AppColors.inkMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granted
                      ? 'Location enabled'
                      : 'Enable location to find jobs near you in your city.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (skipped) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You can turn this on later from your profile.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.inkFaint),
                  ),
                ],
                if (!granted) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: requesting || _isSaving ? null : _requestLocation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green,
                            side: const BorderSide(color: AppColors.green),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: requesting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Allow Location'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton(
                          onPressed: requesting || _isSaving ? null : _skipLocation,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.inkMuted,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Skip for Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
              const Positioned(
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
