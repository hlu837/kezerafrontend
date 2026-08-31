import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/presentation/job_applicants_screen.dart';
import '../../jobs/presentation/job_status_badge.dart';
import '../../jobs/presentation/jobs_provider.dart';

/// Mirrors `web-backoffice/src/app/employer/dashboard/page.tsx` — the
/// employer's own job postings, with an open/closed toggle per job and a
/// shortcut into the posting form. "View candidates" opens
/// [JobApplicantsScreen] — JS-05's list of seekers who applied directly
/// to this specific job, each with the CV they applied with. (Not to be
/// confused with `/employer/candidates`, which is a keyword/skills
/// search across every seeker on the platform, applied or not.)
class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

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
                  onPressed: () => context.go('/employer/jobs/new'),
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
                        for (final job in jobs) _JobListItem(job: job),
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
  const _JobListItem({required this.job});

  final Job job;

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
      if (job.salaryRange != null) job.salaryRange!,
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
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobApplicantsScreen(
                        jobId: job.id,
                        jobTitle: job.title,
                      ),
                    ),
                  ),
                  child: const Text('View candidates'),
                ),
                const SizedBox(width: 8),
                if (job.status != JobStatus.draft)
                  FilledButton.tonal(
                    onPressed: _isToggling ? null : _toggleStatus,
                    child: _isToggling
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(job.status == JobStatus.open
                            ? 'Mark closed'
                            : 'Reopen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
