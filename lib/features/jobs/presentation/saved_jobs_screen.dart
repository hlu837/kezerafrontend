import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../seeker/domain/job_category.dart';
import '../domain/job.dart';
import 'job_detail_screen.dart';
import 'jobs_provider.dart';
import 'saved_jobs_provider.dart';

/// A seeker's bookmarked jobs — reached via the bookmark icon on the
/// job board (see `JobBoardScreen`). Purely a view over
/// `savedJobsProvider`'s on-device snapshots (JS-03); nothing here
/// hits the backend except applying, same as the job board itself.
class SavedJobsScreen extends ConsumerWidget {
  const SavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedJobsProvider);
    final appliedJobIds = ref.watch(jobBoardProvider).appliedJobIds;
    // Most-recently-saved first — `savedJobsProvider`'s map preserves
    // insertion (save) order, oldest first.
    final jobs = saved.values.toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved jobs')),
      body: jobs.isEmpty
          ? const _EmptySavedState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _SavedJobTile(
                  job: job,
                  applied: appliedJobIds.contains(job.id),
                );
              },
            ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No saved jobs yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the bookmark icon on a job to save it here for later.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedJobTile extends ConsumerWidget {
  const _SavedJobTile({required this.job, required this.applied});

  final Job job;
  final bool applied;

  String _categoryLabel(String key) => kJobCategories
      .firstWhere(
        (c) => c.key == key,
        orElse: () => JobCategory(key: key, label: key, icon: Icons.label_outline),
      )
      .label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JobDetailScreen(job: job, isGuest: false, applied: applied),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (job.category != null)
                          Chip(
                            label: Text(_categoryLabel(job.category!)),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(job.jobType.wireValue),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                          ),
                        ),
                      ],
                    ),
                    if (applied) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Applied',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from saved',
                icon: const Icon(Icons.bookmark, size: 20),
                onPressed: () => ref.read(savedJobsProvider.notifier).remove(job.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
