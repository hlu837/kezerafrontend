import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_exception.dart';
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
  });

  final Job job;
  final bool isGuest;
  final bool applied;

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
}
