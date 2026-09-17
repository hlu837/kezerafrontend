import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/job.dart';
import 'jobs_provider.dart';

/// AI-assisted "who applied" breakdown for one job — reached from
/// `JobApplicantsScreen`'s AI Summary action, only shown when the job's
/// own `applicationSummaryEnabled` opt-in is on. Two parts, in the same
/// order the backend documents them (see
/// `applicationSummary.service.js`):
///   1. Structured stats — always available, covers every applicant.
///   2. Per-candidate AI write-up — capped by subscription tier; shows
///      an upgrade nudge once [ApplicationSummaryResult.summaryLimitReached].
///
/// `ConsumerStatefulWidget` (rather than the previous `ConsumerWidget`)
/// so the sort control below can hold which of recent/gpa/experience is
/// selected and re-key `applicationSummaryProvider` accordingly.
class ApplicationSummaryScreen extends ConsumerStatefulWidget {
  const ApplicationSummaryScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  final String jobId;
  final String jobTitle;

  @override
  ConsumerState<ApplicationSummaryScreen> createState() =>
      _ApplicationSummaryScreenState();
}

class _ApplicationSummaryScreenState
    extends ConsumerState<ApplicationSummaryScreen> {
  String _sortBy = 'recent';

  ({String jobId, String sortBy}) get _params =>
      (jobId: widget.jobId, sortBy: _sortBy);

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(applicationSummaryProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI applicant summary'),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(applicationSummaryProvider(_params).future),
        child: summaryAsync.when(
          data: (summary) => _SummaryBody(
            jobTitle: widget.jobTitle,
            summary: summary,
            sortBy: _sortBy,
            onSortChanged: (value) => setState(() => _sortBy = value),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error is ApiException
                              ? error.message
                              : 'Failed to load the applicant summary.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(applicationSummaryProvider(_params)),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control for `sortBy` — placed above "Candidate summaries"
/// since it governs which applicants get an AI write-up first when the
/// subscription tier can't cover everyone, not just their display order.
class _SortBySelector extends StatelessWidget {
  const _SortBySelector({required this.sortBy, required this.onChanged});

  final String sortBy;
  final ValueChanged<String> onChanged;

  static const _options = [
    (value: 'recent', label: 'Recent', icon: Icons.schedule),
    (value: 'gpa', label: 'GPA', icon: Icons.school_outlined),
    (value: 'experience', label: 'Experience', icon: Icons.work_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final option in _options)
          ButtonSegment(
            value: option.value,
            label: Text(option.label),
            icon: Icon(option.icon, size: 16),
          ),
      ],
      selected: {sortBy},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.jobTitle,
    required this.summary,
    required this.sortBy,
    required this.onSortChanged,
  });

  final String jobTitle;
  final ApplicationSummaryResult summary;
  final String sortBy;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final stats = summary.structuredStats;

    if (stats.totalApplicants == 0) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No applicants yet for "$jobTitle" — a summary will '
                  'appear here once people start applying.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text('${stats.totalApplicants} applicant${stats.totalApplicants == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          jobTitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 20),
        if (stats.byExperienceLevel.isNotEmpty)
          _TallyCard(title: 'Experience level', entries: stats.byExperienceLevel),
        if (stats.topSkills.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TallyCard(title: 'Top skills', entries: stats.topSkills),
        ],
        if (stats.byCity.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TallyCard(title: 'By city', entries: stats.byCity),
        ],
        if (stats.gpa.reportedCount > 0) ...[
          const SizedBox(height: 12),
          _GpaCard(gpa: stats.gpa, totalApplicants: stats.totalApplicants),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Candidate summaries',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _SortBySelector(sortBy: sortBy, onChanged: onSortChanged),
        ),
        const SizedBox(height: 12),
        if (!summary.aiAvailable)
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'AI summaries aren\'t available right now. The candidate '
                'stats above are still accurate — try again shortly for '
                'individual write-ups.',
              ),
            ),
          )
        else if (summary.aiSummaries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No candidate summaries to show yet.'),
          )
        else
          for (final entry in summary.aiSummaries) ...[
            _AiSummaryCard(entry: entry),
            const SizedBox(height: 10),
          ],
        if (summary.summaryLimitReached) ...[
          const SizedBox(height: 8),
          Card(
            color: AppColors.greenSurface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, color: AppColors.greenDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Showing AI summaries for ${summary.summaryLimit} of '
                      '${stats.totalApplicants} applicants on your current '
                      '${summary.subscriptionTier} plan${sortBy != 'recent' ? ' (ranked by ${sortBy == 'gpa' ? 'GPA' : 'experience'})' : ''}. '
                      'Upgrade to summarize the rest.',
                      style: TextStyle(color: AppColors.greenDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TallyCard extends StatelessWidget {
  const _TallyCard({required this.title, required this.entries});

  final String title;
  final List<SummaryTally> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in entries)
                  Chip(
                    label: Text('${entry.value} · ${entry.count}'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// GPA breakdown card — only rendered when at least one applicant has
/// entered a GPA (see `ApplicationSummaryStats.gpa.reportedCount`).
/// Shows the pool average among those who reported one plus a top-5
/// leaderboard, so an employer can see "who's strongest by GPA" without
/// needing to switch the sort control just to check.
class _GpaCard extends StatelessWidget {
  const _GpaCard({required this.gpa, required this.totalApplicants});

  final GpaBreakdown gpa;
  final int totalApplicants;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('GPA', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${gpa.reportedCount} of $totalApplicants reported',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            if (gpa.average != null) ...[
              const SizedBox(height: 4),
              Text(
                'Average: ${gpa.average!.toStringAsFixed(2)} / 4.0',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (gpa.topApplicants.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final applicant in gpa.topApplicants)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(applicant.fullName)),
                      Text(
                        applicant.gpa.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.entry});

  final ApplicantAiSummary entry;

  Color _fitColor(BuildContext context) {
    switch (entry.fitScore) {
      case 'strong':
        return AppColors.greenDark;
      case 'weak':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.fullName,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (entry.gpa != null) ...[
                  Icon(Icons.school_outlined,
                      size: 14, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 3),
                  Text(
                    'GPA ${entry.gpa!.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (entry.fitScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _fitColor(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.fitScore!,
                      style: TextStyle(
                        color: _fitColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (entry.summary != null && entry.summary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.summary!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (entry.strengths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final strength in entry.strengths)
                    Chip(
                      label: Text(strength, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
