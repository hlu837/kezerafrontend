import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/last_seen_formatter.dart';
import '../../ats/presentation/placement_chat_screen.dart';
import '../../seeker/presentation/availability_badge.dart';
import '../domain/application.dart';
import 'application_summary_screen.dart';
import 'jobs_provider.dart';

/// JS-05: "View candidates" for one job posting — every seeker who hit
/// Apply directly (as opposed to `PlacementsScreen`, which is the
/// agency matching-engine pipeline). Since applying is only possible
/// with a CV on file (see `applications.service.js#applyToJob`), every
/// row here is guaranteed to have one to show.
class JobApplicantsScreen extends ConsumerWidget {
  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    this.applicationSummaryEnabled = false,
  });

  final String jobId;
  final String jobTitle;
  // Job.applicationSummaryEnabled — whether this job's poster opted in to
  // the AI applicant summary (see PostJobScreen's toggle). Only when
  // true do we show the "AI Summary" action; the endpoint itself would
  // 400 rather than serve one otherwise.
  final bool applicationSummaryEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(jobApplicationsProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        title: Text(jobTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (applicationSummaryEnabled)
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: 'AI applicant summary',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ApplicationSummaryScreen(
                    jobId: jobId,
                    jobTitle: jobTitle,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(jobApplicationsProvider(jobId).notifier).load(),
        child: applicationsAsync.when(
          data: (applications) => applications.isEmpty
              ? _EmptyState(
                  onRefresh: () =>
                      ref.read(jobApplicationsProvider(jobId).notifier).load(),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: applications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ApplicantCard(
                    jobId: jobId,
                    jobTitle: jobTitle,
                    application: applications[index],
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is ApiException
                        ? error.message
                        : 'Failed to load applicants.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(jobApplicationsProvider(jobId).notifier).load(),
                    child: const Text('Try again'),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'No applicants yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seekers who apply directly to this job will show up '
                    'here with their CV.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
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

class _ApplicantCard extends ConsumerStatefulWidget {
  const _ApplicantCard({
    required this.jobId,
    required this.jobTitle,
    required this.application,
  });

  final String jobId;
  final String jobTitle;
  final JobApplication application;

  @override
  ConsumerState<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends ConsumerState<_ApplicantCard> {
  bool _updatingShortlist = false;
  bool _updatingReject = false;
  bool _startingChat = false;

  /// Opens (or starts) a chat thread with this applicant about the job
  /// they applied to. Unlike `CandidatesScreen._startConversation` (the
  /// "Find candidates" search, which browses seekers with no job
  /// context) there's no "which job?" picker needed here — the
  /// applicant already applied to `widget.jobId`, so this just upserts
  /// the Placement for that pair via the same `invite-candidate`
  /// endpoint and opens the resulting thread.
  Future<void> _startChat() async {
    final application = widget.application;
    final applicant = application.applicant;
    if (applicant == null) return;

    setState(() => _startingChat = true);
    try {
      final placementId = await ref.read(jobsRepositoryProvider).inviteCandidate(
            jobId: widget.jobId,
            seekerId: applicant.id,
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PlacementChatScreen(
            placementId: placementId,
            candidateName: applicant.fullName,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      // Belt-and-suspenders on top of JobsRepository._guard — see its
      // doc comment. Nothing here is left "stuck" the way
      // candidates_screen.dart's blocking loading dialog can be, since
      // `finally` below always resets `_startingChat`, but the employer
      // still deserves a message instead of a silently-swallowed error.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  Future<void> _toggleShortlist() async {
    final application = widget.application;
    final wasShortlisted = application.status == ApplicationStatus.shortlisted;

    setState(() => _updatingShortlist = true);
    try {
      await ref
          .read(jobApplicationsProvider(widget.jobId).notifier)
          .setShortlisted(application, !wasShortlisted);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _updatingShortlist = false);
    }
  }

  /// Rejects the applicant, after a confirmation dialog since — unlike
  /// shortlisting — there's no one-tap way back once the seeker sees
  /// their status change.
  Future<void> _reject() async {
    final applicant = widget.application.applicant;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this candidate?'),
        content: Text(
          '${applicant?.fullName ?? 'This candidate'} will be marked as '
          'rejected for this job. You can still view their application '
          'afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updatingReject = true);
    try {
      await ref
          .read(jobApplicationsProvider(widget.jobId).notifier)
          .setRejected(widget.application);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _updatingReject = false);
    }
  }

  /// Moves a rejected application back to `viewed` — the reverse of
  /// [_reject], reusing the same shortlist toggle plumbing since
  /// un-shortlisting already lands on `viewed` server-side.
  Future<void> _undoReject() async {
    setState(() => _updatingReject = true);
    try {
      await ref
          .read(jobApplicationsProvider(widget.jobId).notifier)
          .setShortlisted(widget.application, false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _updatingReject = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final applicant = application.applicant;
    final cvUrl = applicant?.cvUrl;
    final isShortlisted = application.status == ApplicationStatus.shortlisted;
    final isRejected = application.status == ApplicationStatus.rejected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              applicant?.fullName ?? 'Unknown candidate',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (applicant != null) ...[
                            const SizedBox(width: 8),
                            AvailabilityBadgeWidget(
                              available: applicant.availabilityStatus,
                            ),
                          ],
                          if (applicant?.isBoosted ?? false) ...[
                            const SizedBox(width: 6),
                            const _BoostedBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Applied for ${widget.jobTitle}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        applicant?.city ?? 'City not specified',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      if (formatLastSeen(applicant?.lastSeenAt) != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              isOnlineNow(applicant?.lastSeenAt)
                                  ? Icons.circle
                                  : Icons.schedule,
                              size: isOnlineNow(applicant?.lastSeenAt) ? 8 : 13,
                              color: isOnlineNow(applicant?.lastSeenAt)
                                  ? AppColors.greenDark
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatLastSeen(applicant?.lastSeenAt)!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isOnlineNow(applicant?.lastSeenAt)
                                        ? AppColors.greenDark
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(status: application.status),
              ],
            ),
            if (applicant != null && applicant.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in applicant.skills.take(8))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(skill, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Applied ${_formatDate(application.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            if (isRejected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _updatingReject ? null : _undoReject,
                  icon: _updatingReject
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo, size: 18),
                  label: const Text('Undo reject'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _updatingShortlist || _updatingReject
                          ? null
                          : _toggleShortlist,
                      style: isShortlisted
                          ? OutlinedButton.styleFrom(
                              foregroundColor: AppColors.greenDark,
                              side: BorderSide(color: AppColors.greenDark),
                            )
                          : null,
                      icon: _updatingShortlist
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isShortlisted ? Icons.star : Icons.star_border,
                              size: 18,
                            ),
                      label: Text(isShortlisted ? 'Shortlisted' : 'Shortlist'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _updatingShortlist || _updatingReject
                          ? null
                          : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                      ),
                      icon: _updatingReject
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (applicant == null || _startingChat)
                        ? null
                        : _startChat,
                    icon: _startingChat
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 10),
                if (cvUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(cvUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('View CV'),
                    ),
                  )
                else
                  // Shouldn't normally happen — applying requires a CV
                  // server-side — but keeps the card from looking broken
                  // if an older application predates that rule.
                  Expanded(
                    child: Text(
                      'No CV on file',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ApplicationStatus.applied => ('Applied', AppColors.background, AppColors.inkMuted),
      ApplicationStatus.viewed => ('Viewed', AppColors.background, AppColors.inkMuted),
      ApplicationStatus.shortlisted => ('Shortlisted', AppColors.greenSurface, AppColors.greenDark),
      ApplicationStatus.rejected => (
          'Rejected',
          AppColors.errorSurface,
          AppColors.error,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _BoostedBadge extends StatelessWidget {
  const _BoostedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: AppColors.greenDark),
          SizedBox(width: 2),
          Text(
            'Boosted',
            style: TextStyle(color: AppColors.greenDark, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
