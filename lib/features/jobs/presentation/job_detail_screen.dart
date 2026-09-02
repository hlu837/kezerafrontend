import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../seeker/domain/job_category.dart';
import '../domain/job.dart';
import 'saved_jobs_provider.dart';
import 'widgets/job_apply_button.dart';

/// Full job posting, opened by tapping a `_JobCard` on the job board.
/// The card itself only shows title/type/location/salary — everything
/// else (description, skills) lives here so the board stays scannable.
class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.isGuest,
    required this.applied,
    this.onApply,
  });

  final Job job;
  final bool isGuest;
  final bool applied;
  final void Function(Job job)? onApply;

  String _categoryLabel(String key) => kJobCategories
      .firstWhere(
        (c) => c.key == key,
        orElse: () => JobCategory(key: key, label: key, icon: Icons.label_outline),
      )
      .label;

  void _share() {
    final buffer = StringBuffer(job.title)
      ..writeln()
      ..writeln('${job.jobType.wireValue} · ${job.location}');
    if (job.salaryRange != null && job.salaryRange!.isNotEmpty) {
      buffer.writeln(job.salaryRange!);
    }
    buffer
      ..writeln()
      ..writeln(job.description);
    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: job.title));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = Theme.of(context).colorScheme.outline;
    // Guests can browse but have nothing to save to — the board never
    // shows guests the bookmark icon either, only Apply.
    final isSaved = !isGuest && ref.watch(savedJobsProvider).containsKey(job.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job details'),
        actions: [
          if (!isGuest)
            IconButton(
              tooltip: isSaved ? 'Unsave job' : 'Save job',
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () => ref.read(savedJobsProvider.notifier).toggle(job),
            ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (job.category != null)
                  Chip(label: Text(_categoryLabel(job.category!))),
                Chip(label: Text(job.jobType.wireValue)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: outline),
                const SizedBox(width: 6),
                Text(job.location, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline)),
              ],
            ),
            if (job.salaryRange != null && job.salaryRange!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.payments_outlined, size: 18, color: outline),
                  const SizedBox(width: 6),
                  Text(job.salaryRange!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline)),
                ],
              ),
            ],
            const Divider(height: 32),
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(job.description, style: Theme.of(context).textTheme.bodyMedium),
            if (job.skillsRequired.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Skills', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in job.skillsRequired) Chip(label: Text(skill)),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: JobApplyButton(
            job: job,
            isGuest: isGuest,
            applied: applied,
            onApply: onApply,
          ),
        ),
      ),
    );
  }
}
