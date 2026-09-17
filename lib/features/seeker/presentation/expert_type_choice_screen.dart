import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';

/// SEEK-01c: shown right after [CategoryPreferencesScreen]'s "Save &
/// Continue", before the seeker ever reaches their dashboard — one step
/// ahead of the existing CV upload-or-build choice ([CvChoiceScreen]).
///
/// Separates the two ways a seeker-role account can be found and hired
/// (see `Technician.model.js`'s top-of-file note for the full
/// background on the split):
///   1. **Post my CV** — the formal, CV-driven path. Routes into the
///      existing `/seeker/onboarding/cv-choice` flow unchanged.
///   2. **Register as a Trade Technician** — the lightweight, on-demand
///      path for tradespeople (electricians, plumbers, etc.): a short
///      name/trade/skills/location/rate profile, no CV involved. Routes
///      to [TechnicianRegistrationScreen].
///
/// A seeker isn't limited to one or the other — both are reachable
/// again later from the account screen's "Job seeking" section — so
/// this screen's "Skip for now" just defers the choice rather than
/// locking one in.
///
/// Standalone route (`/seeker/onboarding/expert-choice`), outside the
/// `ShellRoute` — same reasoning as [CategoryPreferencesScreen] and
/// [CvChoiceScreen]: no sidebar/bottom-nav chrome while onboarding is
/// still in progress.
class ExpertTypeChoiceScreen extends StatelessWidget {
  const ExpertTypeChoiceScreen({super.key});

  void _goToDashboard(BuildContext context) {
    context.go(UserRole.seeker.dashboardPath);
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
                  Text(
                    'How do you want to be found?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can always set up the other one later from your '
                    'account page.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  _ExpertTypeCard(
                    icon: Icons.description_outlined,
                    title: 'Post my CV',
                    description:
                        'For formal, office-based roles. Upload or build a CV so '
                        'employers and agencies can find and apply to hire you.',
                    buttonLabel: 'Post my CV',
                    onTap: () => context.go('/seeker/onboarding/cv-choice'),
                  ),
                  const SizedBox(height: 16),
                  _ExpertTypeCard(
                    icon: Icons.handyman_outlined,
                    title: 'Register as a Trade Technician',
                    description:
                        'For electricians, plumbers, and other skilled trades. '
                        'List your trade, skills, and location so nearby customers '
                        'can find and book you directly — no CV needed.',
                    buttonLabel: 'Register as a Technician',
                    onTap: () => context.go('/seeker/onboarding/technician-registration'),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => _goToDashboard(context),
                      style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
                      child: const Text('Skip for now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpertTypeCard extends StatelessWidget {
  const _ExpertTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.greenSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.greenDark, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: BorderSide(color: AppColors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
