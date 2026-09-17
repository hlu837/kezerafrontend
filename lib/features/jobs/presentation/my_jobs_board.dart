import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/utils/salary_formatter.dart';
import '../domain/job.dart';
import 'job_applicants_screen.dart';
import 'job_status_badge.dart';
import 'jobs_provider.dart';

/// The "my job postings" list — a header (open/closed counts + "Post a
/// job") over every job `myJobsProvider` returns, each with "View
/// candidates"/"Edit"/open-close-toggle actions. Identical for employer
/// and agency accounts (both just list whatever `GET /jobs/my-jobs`
/// returns for the signed-in creator), so both `EmployerJobsScreen`
/// (reached from `EmployerDashboardScreen`'s reporting overview) and
/// `AgencyDashboardScreen` render this one widget rather than keeping
/// two near-duplicate copies in sync.
///
/// [newJobPath]/[editJobPath] point at the role's own posting routes
/// (`/employer/jobs/new|edit` or `/agency/jobs/new|edit`) so "Post a
/// job"/"Edit" land back in the right role's section of the app.
class MyJobsBoard extends ConsumerWidget {
  const MyJobsBoard({
    super.key,
    required this.newJobPath,
    required this.editJobPath,
  });

  final String newJobPath;
  final String editJobPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(myJobsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(myJobsProvider.notifier).load(),
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
                        'Your job postings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jobsAsync.when(
                          data: (jobs) {
                            final open =
                                jobs.where((j) => j.status == JobStatus.open).length;
                            final closed = jobs
                                .where((j) => j.status == JobStatus.closed)
                                .length;
                            return '$open open · $closed closed';
                          },
                          loading: () => 'Loading…',
                          error: (_, __) => ' ',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go(newJobPath),
                  icon: const Icon(Icons.add),
                  label: const Text('Post a job'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            jobsAsync.when(
              data: (jobs) => jobs.isEmpty
                  ? const _EmptyJobsState()
                  : Column(
                      children: [
                        for (final job in jobs)
                          _JobListItem(job: job, editJobPath: editJobPath),
                      ],
                    ),
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
                            : 'Failed to load your jobs.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => ref.read(myJobsProvider.notifier).load(),
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

class _EmptyJobsState extends StatelessWidget {
  const _EmptyJobsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.work_outline,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No jobs posted yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Post your first job to start receiving matched candidates.',
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

class _JobListItem extends ConsumerStatefulWidget {
  const _JobListItem({required this.job, required this.editJobPath});

  final Job job;
  final String editJobPath;

  @override
  ConsumerState<_JobListItem> createState() => _JobListItemState();
}

class _JobListItemState extends ConsumerState<_JobListItem> {
  bool _isToggling = false;

  Future<void> _toggleStatus() async {
    setState(() => _isToggling = true);
    try {
      await ref.read(myJobsProvider.notifier).toggleStatus(widget.job);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final subtitle = [
      job.jobType.wireValue,
      job.location,
      if (job.salaryRange != null) formatSalary(job.salaryRange!),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          job.title,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      JobStatusBadge(status: job.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            if (job.skillsRequired.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in job.skillsRequired.take(6))
                    Chip(
                      label: Text(skill, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobApplicantsScreen(
                          jobId: job.id,
                          jobTitle: job.title,
                          applicationSummaryEnabled: job.applicationSummaryEnabled,
                        ),
                      ),
                    ),
                    child: const Text(
                      'View candidates',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () =>
                        context.push(widget.editJobPath, extra: job),
                    child: const Text(
                      'Edit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (job.status != JobStatus.draft) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: _isToggling ? null : _toggleStatus,
                      child: _isToggling
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              job.status == JobStatus.open
                                  ? 'Mark closed'
                                  : 'Reopen',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
