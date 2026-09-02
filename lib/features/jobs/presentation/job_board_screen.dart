import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/widgets/skill_tag_input.dart';
import '../../seeker/domain/job_category.dart';
import '../../seeker/presentation/seeker_profile_provider.dart';
import '../domain/job.dart';
import 'job_detail_screen.dart';
import 'jobs_provider.dart';
import 'saved_jobs_provider.dart';
import 'saved_jobs_screen.dart';
import 'widgets/job_apply_button.dart';

/// JS-03: seeker job board — browse/search/filter open jobs, and save a
/// search (with alert preferences) for later. Mirrors the shape of
/// `CandidatesScreen` on the employer side: a filter form over a paged
/// result list.
///
/// Doubles as the logged-out landing page's job list (see
/// `PublicJobBoardScreen`) when [isGuest] is true: browsing/searching stays
/// identical (GET /jobs never required a token — only the router used to
/// gate the page itself), but anything that needs an account — saved
/// searches, applying — is hidden or redirected instead of hitting the API
/// as a guest and failing on a 401.
class JobBoardScreen extends ConsumerStatefulWidget {
  const JobBoardScreen({
    super.key,
    this.isGuest = false,
    this.onApply,
    this.header,
    this.titleTrailing,
  });

  /// True on the public landing route, false on the authenticated
  /// `/seeker/jobs` route.
  final bool isGuest;

  /// Called when someone taps "Apply" on a job card while [isGuest] is
  /// true — sends the guest to `/register` (see
  /// `PublicJobBoardScreen._promptSignUp`). The authenticated
  /// `/seeker/jobs` route leaves this null: `_JobCard` applies directly
  /// via `jobBoardProvider.applyToJob` instead of going through a
  /// caller-supplied callback.
  final void Function(Job job)? onApply;

  /// Optional widget rendered above the "Find a job" filter card — e.g.
  /// the landing page's hero banner. Passed in rather than wrapping this
  /// screen in a second scroll view, since this screen's body is already
  /// a `ListView` (nesting two unbounded `ListView`s breaks layout).
  final Widget? header;

  /// Optional widget rendered on the right of the "Find a job" heading,
  /// next to (or instead of) the "Saved searches" button. Used by the
  /// public landing page for the guest-only "Employee / Expert" toggle —
  /// left null everywhere else.
  final Widget? titleTrailing;

  @override
  ConsumerState<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends ConsumerState<JobBoardScreen> {
  final _keywordController = TextEditingController();
  final _locationController = TextEditingController();
  JobType? _jobType;
  // JS-04: null means "any category" — the filter dropdown mirrors the
  // same closed taxonomy (kJobCategories) used on the SEEK-01 onboarding
  // screen and on job postings' own category field.
  String? _category;
  List<String> _skills = [];
  // Collapsed by default so the search card only shows the Search button
  // until someone actually wants to filter — expands on tap of the
  // "Filters" row below. Stays collapsed even after `_prefillFromProfile`
  // fills in a value, so the authenticated seeker view matches the
  // logged-out landing page's behavior instead of always popping open.
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the seeker's own profile — "so they can search what
    // they want easily" without retyping their city/category every
    // visit. Guest mode has no profile to read, and only runs once per
    // screen instance (a seeker who then clears the filters manually
    // shouldn't have them silently reapplied).
    if (!widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
    }
  }

  void _prefillFromProfile() {
    if (!mounted) return;
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile == null) return;

    final city = profile.city;
    final category = profile.preferredCategories.isNotEmpty
        ? profile.preferredCategories.first
        : null;
    if (city == null && category == null) return;

    setState(() {
      if (city != null && city.isNotEmpty) _locationController.text = city;
      _category = category;
    });
    _runSearch();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _runSearch() {
    ref.read(jobBoardProvider.notifier).search(
          keyword: _keywordController.text.trim(),
          location: _locationController.text.trim(),
          jobType: _jobType,
          clearJobType: _jobType == null,
          category: _category,
          clearCategory: _category == null,
          skills: _skills,
        );
  }

  Future<void> _saveSearch() async {
    try {
      await ref
          .read(savedSearchesProvider.notifier)
          .saveCurrentFilters(ref.read(jobBoardProvider).params);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search saved — we\'ll alert you on new matches.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobBoardProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find a job', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            if (!widget.isGuest)
              IconButton(
                tooltip: 'Saved jobs',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SavedJobsScreen()),
                ),
                icon: const Icon(Icons.bookmark_outline),
              ),
            if (!widget.isGuest)
              OutlinedButton.icon(
                onPressed: () => _showSavedSearchesSheet(context),
                icon: const Icon(Icons.notifications_outlined, size: 18),
                label: const Text('Saved searches'),
              ),
            if (widget.titleTrailing != null) widget.titleTrailing!,
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filters',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(_filtersExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: !_filtersExpanded
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            TextField(
                              controller: _keywordController,
                              decoration: const InputDecoration(
                                labelText: 'Keyword',
                                hintText: 'Job title or description',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _runSearch(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                                hintText: 'Addis Ababa, Bole',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _runSearch(),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<JobType?>(
                              initialValue: _jobType,
                              decoration: const InputDecoration(
                                labelText: 'Job type',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Any')),
                                for (final type in JobType.values)
                                  DropdownMenuItem(value: type, child: Text(type.wireValue)),
                              ],
                              onChanged: (value) => setState(() => _jobType = value),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Any category')),
                                for (final category in kJobCategories)
                                  DropdownMenuItem(value: category.key, child: Text(category.label)),
                              ],
                              onChanged: (value) => setState(() => _category = value),
                            ),
                            const SizedBox(height: 12),
                            SkillTagInput(
                              label: 'Skills',
                              skills: _skills,
                              onChanged: (skills) => setState(() => _skills = skills),
                              hintText: 'e.g. plumbing — press Enter',
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _runSearch,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Search'),
                      ),
                    ),
                    if (!widget.isGuest) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _saveSearch,
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Save search'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        // Ad banner now sits below the search card/Search button, rather
        // than above the "Find a job" heading — see PublicJobBoardScreen's
        // `header`, which this slot renders.
        if (widget.header != null) ...[
          const SizedBox(height: 24),
          widget.header!,
        ],
        const SizedBox(height: 16),
        state.result.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : 'Failed to load jobs.',
            onRetry: _runSearch,
          ),
          data: (result) => _JobResultList(
            result: result,
            page: state.params.page,
            pageSize: state.params.limit,
            isGuest: widget.isGuest,
            appliedJobIds: state.appliedJobIds,
            onApply: widget.onApply,
          ),
        ),
      ],
    );
  }

  void _showSavedSearchesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SavedSearchesSheet(),
    );
  }
}

class _JobResultList extends ConsumerWidget {
  const _JobResultList({
    required this.result,
    required this.page,
    required this.pageSize,
    required this.isGuest,
    required this.appliedJobIds,
    this.onApply,
  });

  final JobBrowseResult result;
  final int page;
  final int pageSize;
  final bool isGuest;
  final Set<String> appliedJobIds;
  final void Function(Job job)? onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = result.jobs;

    if (jobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: _EmptyState(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.isMock) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sample listings — no real jobs posted yet. These are for preview only.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final job in jobs) ...[
          _JobCard(
            job: job,
            isGuest: isGuest,
            applied: appliedJobIds.contains(job.id),
            onApply: onApply,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: page > 1 ? () => ref.read(jobBoardProvider.notifier).previousPage() : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 12),
            Text('Page $page', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: jobs.length == pageSize
                  ? () => ref.read(jobBoardProvider.notifier).nextPage()
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Looks up a category key's display label from the shared taxonomy,
/// falling back to the raw key for forward-compat if the backend ever
/// adds a category this build doesn't know about yet.
String _categoryLabel(String key) => kJobCategories
    .firstWhere(
      (c) => c.key == key,
      orElse: () => JobCategory(key: key, label: key, icon: Icons.label_outline),
    )
    .label;

/// A job board row. Deliberately keeps only what's needed to scan and
/// decide whether to open it — title, type/category, location, salary.
/// Description and skills moved to `JobDetailScreen` (tap the card to
/// open it) so the board doesn't turn into a wall of text per listing.
class _JobCard extends ConsumerWidget {
  const _JobCard({
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

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(
          job: job,
          isGuest: isGuest,
          applied: applied,
          onApply: onApply,
        ),
      ),
    );
  }

  void _share() {
    final buffer = StringBuffer(job.title)
      ..writeln()
      ..writeln('${job.jobType.wireValue} · ${job.location}');
    if (job.salaryRange != null && job.salaryRange!.isNotEmpty) {
      buffer.writeln(job.salaryRange!);
    }
    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: job.title));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = Theme.of(context).colorScheme.outline;
    // Guests can browse but have nothing to save to — only show the
    // bookmark toggle once they're actually signed in as a seeker.
    final isSaved = !isGuest && ref.watch(savedJobsProvider).containsKey(job.id);

    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: outline),
                  const SizedBox(width: 4),
                  Text(job.location, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline)),
                  if (job.salaryRange != null && job.salaryRange!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.payments_outlined, size: 16, color: outline),
                    const SizedBox(width: 4),
                    Text(job.salaryRange!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline)),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!isGuest)
                    IconButton(
                      tooltip: isSaved ? 'Unsave job' : 'Save job',
                      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(savedJobsProvider.notifier).toggle(job),
                    ),
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: _share,
                  ),
                  const Spacer(),
                  JobApplyButton(
                    job: job,
                    isGuest: isGuest,
                    applied: applied,
                    onApply: onApply,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSearchesSheet extends ConsumerWidget {
  const _SavedSearchesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchesAsync = ref.watch(savedSearchesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved searches', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Toggle alerts on a saved search to get emailed when a new job matches.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: searchesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    error is ApiException ? error.message : 'Failed to load saved searches.',
                  ),
                ),
                data: (searches) {
                  if (searches.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No saved searches yet. Search for jobs, then tap "Save search".'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: searches.length,
                    itemBuilder: (context, index) {
                      final search = searches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(search.displaySummary),
                        subtitle: Text(
                          search.alertsEnabled ? 'Alerts on' : 'Alerts off',
                          style: TextStyle(
                            color: search.alertsEnabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: search.alertsEnabled,
                              onChanged: (_) => ref
                                  .read(savedSearchesProvider.notifier)
                                  .toggleAlerts(search),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  ref.read(savedSearchesProvider.notifier).delete(search.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.work_outline, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No jobs match your filters yet.', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
