import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../ats/presentation/placement_chat_screen.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/presentation/jobs_provider.dart';

/// A reporting overview of this employer's hiring activity — how many
/// jobs are posted (and their open/closed split), how many applicants
/// they've collected in total, and who's applied most recently (with
/// today's applicants called out). The individual job postings
/// themselves live one tap away on `EmployerJobsScreen` rather than on
/// this screen directly — see that widget's doc comment for why the
/// two are split.
///
/// Backed by `GET /jobs/my-jobs/stats` (see [MyJobsStats]) rather than
/// derived from `myJobsProvider`'s job list, since the totals here
/// (applicant counts, recent applicants) aren't computable client-side
/// from the jobs list alone.
class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(myJobsStatsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myJobsStatsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
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
                      Text(
                        'Employer Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'An overview of your hiring activity across every '
                        'job you\'ve posted.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/employer/jobs/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Post a job'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              data: (stats) => _DashboardBody(stats: stats),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        error is ApiException
                            ? error.message
                            : 'Failed to load your dashboard stats.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(myJobsStatsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats});

  final MyJobsStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              label: 'Total Jobs Posted',
              value: '${stats.totalJobs}',
              subtitle: '${stats.openJobs} open · ${stats.closedJobs} closed',
              icon: Icons.work_outline,
              onTap: () => context.go('/employer/jobs'),
            ),
            _StatCard(
              label: 'Total Applicants Collected',
              value: '${stats.totalApplicants}',
              subtitle: 'Across all of your job postings',
              icon: Icons.people_outline,
            ),
            _StatCard(
              label: 'New Applicants Today',
              value: '${stats.newApplicantsToday}',
              subtitle: 'Candidates who applied today',
              icon: Icons.person_add_alt_1_outlined,
              highlight: stats.newApplicantsToday > 0,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent applicants',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/employer/jobs'),
              child: const Text('View all job postings'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.recentApplicants.isEmpty)
          const _EmptyApplicantsState()
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < stats.recentApplicants.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _RecentApplicantTile(applicant: stats.recentApplicants[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyApplicantsState extends StatelessWidget {
  const _EmptyApplicantsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No applicants yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Candidates who apply to your jobs will show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentApplicantTile extends ConsumerStatefulWidget {
  const _RecentApplicantTile({required this.applicant});

  final RecentApplicant applicant;

  @override
  ConsumerState<_RecentApplicantTile> createState() =>
      _RecentApplicantTileState();
}

class _RecentApplicantTileState extends ConsumerState<_RecentApplicantTile> {
  bool _startingChat = false;

  /// Same "upsert the placement via invite-candidate, then open the
  /// resulting thread" flow as `job_applicants_screen.dart`'s
  /// `_startChat` — this tile is just a different entry point onto the
  /// same applicant/job pair. Requires `applicant.seekerId`, which is
  /// null only if the seeker account was deleted after applying (see
  /// `jobs.service.js#getMyJobsStats`); the tile falls back to a
  /// disabled, non-interactive row in that case.
  Future<void> _startChat() async {
    final applicant = widget.applicant;
    final seekerId = applicant.seekerId;
    if (seekerId == null || _startingChat) return;

    setState(() => _startingChat = true);
    try {
      final placementId = await ref.read(jobsRepositoryProvider).inviteCandidate(
            jobId: applicant.jobId,
            seekerId: seekerId,
          );
      if (!mounted) return;
      // Pushed on the root navigator, not this shell tab's nested one —
      // see `PlacementChatScreen`'s doc comment for why every full-screen
      // page reached from inside a shell needs this.
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PlacementChatScreen(
            placementId: placementId,
            candidateName: applicant.applicantName,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicant = widget.applicant;
    final canMessage = applicant.seekerId != null;

    return ListTile(
      onTap: canMessage ? _startChat : null,
      leading: CircleAvatar(
        child: Text(
          applicant.applicantName.isNotEmpty
              ? applicant.applicantName[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(applicant.applicantName),
      subtitle: Text(
        'Applied to ${applicant.jobTitle} · ${_relativeTime(applicant.appliedAt)}',
      ),
      trailing: _startingChat
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : applicant.isNewToday
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'New today',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : (canMessage
                  ? Icon(Icons.chevron_right,
                      color: Theme.of(context).colorScheme.outline)
                  : null),
    );
  }
}

/// Short "time ago" label for a recent applicant's apply time — coarser
/// than `formatLastSeen` (no "online now"/minutes granularity), since
/// this is about when an application came in, not live presence.
String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inHours < 1) {
    final minutes = diff.inMinutes;
    return minutes <= 0 ? 'just now' : '${minutes}m ago';
  }
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  return '${weeks}w ago';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Card(
        color: highlight ? colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: highlight
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: highlight ? colorScheme.onPrimaryContainer : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: highlight
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: highlight
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
