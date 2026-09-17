import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../seeker/presentation/seeker_profile_provider.dart';
import '../../domain/job.dart';
import '../jobs_provider.dart';

/// The "Apply" / "Applied" control shown on both `_JobCard` (job board)
/// and `JobDetailScreen`. Pulled out of `_JobCard` so the two surfaces
/// can't drift — CV-required enforcement (JS-05), the mock-listing guard,
/// and the guest redirect all live in exactly one place.
class JobApplyButton extends ConsumerStatefulWidget {
  const JobApplyButton({
    super.key,
    required this.job,
    required this.isGuest,
    required this.applied,
    this.onApply,
    this.dense = false,
  });

  final Job job;
  final bool isGuest;
  final bool applied;

  /// When true, renders as a small rounded "Easy Apply" pill (bolt icon
  /// + label) instead of the full-size button — used by the job board's
  /// list card, which needs something compact enough to sit next to a
  /// "posted Xd ago" label rather than the full-width button
  /// `JobDetailScreen` uses. Same tap handler and CV/guest/mock guards
  /// either way — this only changes presentation.
  final bool dense;

  /// Guest-only: sends the visitor to `/register` (see
  /// `PublicJobBoardScreen._promptSignUp`). The authenticated seeker
  /// path below doesn't use this — it applies directly.
  final void Function(Job job)? onApply;

  @override
  ConsumerState<JobApplyButton> createState() => _JobApplyButtonState();
}

class _JobApplyButtonState extends ConsumerState<JobApplyButton> {
  bool _isApplying = false;

  Future<void> _handleApply() async {
    if (widget.isGuest) {
      widget.onApply?.call(widget.job);
      return;
    }

    // Mock listings (see mock_jobs.dart) aren't real backend records —
    // applying to one would just 404. Tell the seeker plainly instead of
    // spinning and failing.
    if (widget.job.id.startsWith('mock-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is a sample listing — check back once real jobs are posted.',
          ),
        ),
      );
      return;
    }

    // JS-05: applying is always "with a CV" — the backend rejects the
    // apply outright if `Seeker.cvUrl` isn't set yet (see
    // applications.service.js#applyToJob). Catch that up front with a
    // clear prompt into the CV setup flow, rather than letting the
    // seeker hit "Apply", wait on a spinner, and then read the same
    // thing back as a generic error snackbar.
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile != null && (profile.cvUrl == null || profile.cvUrl!.isEmpty)) {
      await _promptForCv();
      return;
    }

    setState(() => _isApplying = true);
    try {
      final alreadyApplied =
          await ref.read(jobBoardProvider.notifier).applyToJob(widget.job);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyApplied
                ? 'You already applied to this job.'
                : 'Applied! The employer will be notified.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  /// Shown when a seeker taps "Apply" with no CV on file yet (or when
  /// `myProfileProvider` hasn't loaded and the backend catches it
  /// instead — see the `ApiException` branch above). Routes to the same
  /// upload-or-build choice screen SEEK-01b uses right after signup.
  Future<void> _promptForCv() async {
    final shouldSetUpCv = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a CV to apply'),
        content: const Text(
          'You need a CV on your profile before you can apply. Upload one '
          'you already have, or build one in the app — it only takes a '
          'couple of minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add CV'),
          ),
        ],
      ),
    );
    if (shouldSetUpCv == true && mounted) {
      context.push('/seeker/onboarding/cv-choice');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dense) return _buildDense(context);

    return widget.applied
        ? OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Applied'),
          )
        : FilledButton(
            onPressed: _isApplying ? null : _handleApply,
            child: _isApplying
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Apply'),
          );
  }

  Widget _buildDense(BuildContext context) {
    if (widget.applied) {
      return _DensePill(
        icon: Icons.check_rounded,
        label: 'Applied',
        background: AppColors.surface,
        foreground: AppColors.inkMuted,
        onTap: null,
      );
    }

    return _DensePill(
      icon: Icons.bolt_rounded,
      label: 'Easy Apply',
      background: AppColors.greenSurface,
      foreground: AppColors.greenDark,
      onTap: _isApplying ? null : _handleApply,
      loading: _isApplying,
    );
  }
}

class _DensePill extends StatelessWidget {
  const _DensePill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        // Shrunk from 12/7 — the job board card is a compact scan list,
        // not a detail page, so this pill only needs to read as tappable,
        // not command as much visual weight as the rest of the row.
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                height: 11,
                width: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
