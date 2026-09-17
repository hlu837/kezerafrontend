import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../jobs/domain/application.dart';
import '../../jobs/presentation/job_status_badge.dart';
import 'seeker_profile_provider.dart';

/// JS-05: "My Applications" — a seeker's own view of every job they've
/// tapped Apply on, newest first, with per-application status (applied
/// / viewed / shortlisted / rejected). The counterpart to
/// `JobApplicantsScreen`, which is the same underlying data seen from
/// the employer's side of a single job.
class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myApplicationsProvider.future),
        child: applicationsAsync.when(
          data: (applications) => applications.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: applications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _ApplicationCard(application: applications[index]),
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
                        : 'Failed to load your applications.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(myApplicationsProvider),
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
  const _EmptyState();

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
                  Icon(Icons.work_outline,
                      size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'No applications yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jobs you apply to from the job board will show up here.',
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

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});

  final MyApplication application;

  @override
  Widget build(BuildContext context) {
    final job = application.job;

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
                      Text(
                        job?.title ?? 'Job posting removed',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job?.location ?? '—',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                if (job != null) JobStatusBadge(status: job.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ApplicationStatusChip(status: application.status),
                const Spacer(),
                Text(
                  'Applied ${_formatDate(application.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
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

class _ApplicationStatusChip extends StatelessWidget {
  const _ApplicationStatusChip({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ApplicationStatus.applied => ('Applied', AppColors.background, AppColors.inkMuted),
      ApplicationStatus.viewed => ('Viewed', AppColors.background, AppColors.inkMuted),
      ApplicationStatus.shortlisted => (
          'Shortlisted',
          AppColors.greenSurface,
          AppColors.greenDark,
        ),
      ApplicationStatus.rejected => (
          'Not selected',
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
