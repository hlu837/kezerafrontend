import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/salary_formatter.dart';
import '../../../core/widgets/filter_card.dart';
import '../../seeker/domain/experience_level.dart';
import '../../seeker/domain/job_category.dart';
import '../../seeker/presentation/seeker_profile_provider.dart';
import '../domain/job.dart';
import 'job_detail_screen.dart';
import 'jobs_provider.dart';
import 'saved_jobs_provider.dart';
import 'saved_jobs_screen.dart';
import 'widgets/category_preferences_sheet.dart';
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
    this.showSearchCard = true,
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

  /// Hides the collapsible "Filters" card (source/keyword/location/job
  /// type/category/experience + the Search button) entirely.
  final bool showSearchCard;

  @override
  ConsumerState<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends ConsumerState<JobBoardScreen> {
  final _keywordController = TextEditingController();
  final _locationController = TextEditingController();
  final _scrollController = ScrollController();
  JobType? _jobType;
  // JS-04: null means "any category" — the filter dropdown mirrors the
  // same closed taxonomy (kJobCategories) used on the SEEK-01 onboarding
  // screen and on job postings' own category field. A manual pick here
  // overrides the JS-06 "For You" default below.
  String? _category;
  // JS-06: "For You" feed — the seeker's full `preferredCategories` set,
  // applied automatically (see `_prefillFromProfile`) whenever `_category`
  // hasn't been manually overridden. Empty for guests (no profile to
  // read) and for an authenticated seeker mid-load, before `build`'s own
  // gate (`_needsCategorySelection`) would otherwise have already
  // stopped them from reaching this screen with zero categories.
  List<String> _forYouCategories = const [];
  // Guards the auto-popup in `build` so the "select your categories"
  // sheet opens once per time the seeker lands on this tab with zero
  // saved categories, rather than re-showing itself on every rebuild
  // (filter changes, profile refetches, etc.) while they're still
  // deciding what to pick.
  bool _autoPromptScheduled = false;
  // Company jobs (employer) vs Agency jobs (staffing/recruiting agency)
  // vs All — the segmented toggle just under the "Find a job" heading.
  // null means "all jobs", mirroring the other optional filters.
  String? _creatorType;
  ExperienceLevel? _experienceLevel;
  // Collapsed by default so the search card only shows the Search button
  // until someone actually wants to filter — expands on tap of the
  // "Filters" row below. Stays collapsed even after `_prefillFromProfile`
  // fills in a value, so the authenticated seeker view matches the
  // logged-out landing page's behavior instead of always popping open.
  bool _filtersExpanded = false;

  // Matches `ResponsiveShell._wideBreakpoint` — below this width a
  // screen gets the phone-style bottom nav instead of a sidebar, so it's
  // also where this screen switches from Previous/Next buttons to
  // infinite scroll. The guest landing page (`isGuest`) always gets
  // infinite scroll regardless of width, per the "mobile/landing views"
  // ask — a signed-in seeker on a wide desktop window still gets the
  // paged Previous/Next controls.
  static const double _mobileBreakpoint = 900;

  bool get _useInfiniteScroll =>
      widget.isGuest || MediaQuery.sizeOf(context).width < _mobileBreakpoint;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Prefill from the seeker's own profile — "so they can search what
    // they want easily" without retyping their city/category every
    // visit. Guest mode has no profile to read, and only runs once per
    // screen instance (a seeker who then clears the filters manually
    // shouldn't have them silently reapplied).
    if (!widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
    }
  }

  /// Fires on every scroll frame of the outer list — cheap to check
  /// (just position math) since [_useInfiniteScroll] and the provider's
  /// own `isLoadingMore`/`hasMore` guards make repeat calls a no-op.
  void _onScroll() {
    if (!mounted) return;
    if (!_useInfiniteScroll) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Trigger a bit before the true end (400px) so the next page is
    // already loading by the time the seeker actually reaches the
    // bottom, instead of them hitting the end and waiting on a spinner.
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(jobBoardProvider.notifier).loadMore();
    }
  }

  void _prefillFromProfile() {
    if (!mounted) return;
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile == null) return;

    final city = profile.city;
    // JS-06: "For You" — the seeker's FULL preferred-category set (not
    // just the first one, unlike the old single-category convenience
    // prefill this replaces), so the default feed matches everything
    // they picked on `CategoryPreferencesScreen`, not one of them.
    if (city == null && profile.preferredCategories.isEmpty) return;

    setState(() {
      if (city != null && city.isNotEmpty) _locationController.text = city;
      _forYouCategories = profile.preferredCategories;
    });
    _runSearch();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() {
    // Manual dropdown pick overrides the JS-06 "For You" default —
    // only one of `category`/`categories` is ever sent, mirroring
    // jobs.service.js#browseJobs' own precedence server-side.
    final useForYou = _category == null && _forYouCategories.isNotEmpty;
    return ref.read(jobBoardProvider.notifier).search(
          keyword: _keywordController.text.trim(),
          location: _locationController.text.trim(),
          jobType: _jobType,
          clearJobType: _jobType == null,
          category: _category,
          clearCategory: _category == null,
          categories: useForYou ? _forYouCategories : null,
          clearCategories: !useForYou,
          creatorType: _creatorType,
          clearCreatorType: _creatorType == null,
          experienceLevel: _experienceLevel?.wireValue,
          clearExperienceLevel: _experienceLevel == null,
        );
  }

  /// Opens the "For You" category-setup sheet (see
  /// `CategoryPreferencesSheet`) — used both by the auto-popup when a
  /// seeker has zero categories saved and by the header's "Edit
  /// preferences" icon for anyone updating an existing selection.
  ///
  /// [isDismissible] is false for the first-time auto-popup (a fresh
  /// seeker shouldn't be able to swipe away the only prompt that gets
  /// them a feed at all — they can still bail via the empty-state's own
  /// CTA, which reopens this same sheet); it stays the default `true`
  /// for the on-demand editor, since a seeker with an existing feed
  /// tapping the icon by mistake should be able to just dismiss it.
  ///
  /// On save, splices the result straight into [_forYouCategories] and
  /// clears any manual `_category` filter override so the refreshed
  /// feed actually reflects the new selection (mirrors the precedence
  /// rule documented on [_runSearch]), then immediately re-runs the
  /// search — this is the "wire selections to an immediate feed
  /// refresh" behavior.
  Future<void> _openCategorySheet({
    required Set<String> initialSelected,
    bool isDismissible = true,
  }) async {
    final result = await showCategoryPreferencesSheet(
      context,
      initialSelected: initialSelected,
      isDismissible: isDismissible,
    );
    if (result == null || !mounted) return;
    setState(() {
      _forYouCategories = result;
      _category = null;
    });
    await _runSearch();
  }

  /// The seeker's currently-saved categories, read straight from
  /// `myProfileProvider` so the "Edit preferences" icon always opens
  /// pre-seeded with what's actually on file — not just whatever
  /// `_forYouCategories` happens to hold locally (e.g. before the
  /// first `_prefillFromProfile` run completes).
  Set<String> get _savedCategories =>
      ref.read(myProfileProvider).valueOrNull?.preferredCategories.toSet() ??
      _forYouCategories.toSet();

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
        final message = e.isValidationError ? 'No input, please try again.' : e.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // JS-06 hard rule: an authenticated seeker with zero preferred
    // categories never silently falls back to an unfiltered "All"
    // feed — they're stopped here and sent back to pick at least one
    // (same screen SEEK-01 onboarding uses, so "Save & Continue"
    // there enforces the same `min(1)` rule the backend's
    // `updatePreferencesSchema` does). Guests have no profile/
    // preferences at all, so this gate only applies once logged in.
    if (!widget.isGuest) {
      final profileState = ref.watch(myProfileProvider);
      final needsCategorySelection = profileState.maybeWhen(
        data: (seeker) => seeker.preferredCategories.isEmpty,
        orElse: () => false,
      );
      if (needsCategorySelection) {
        // Auto-trigger the category-setup sheet the moment a seeker
        // lands on this tab with zero saved categories, per the "For
        // You" empty/first-time state requirement — scheduled for the
        // next frame (can't show a sheet mid-`build`) and guarded so it
        // only fires once per arrival, not on every rebuild.
        if (!_autoPromptScheduled) {
          _autoPromptScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openCategorySheet(initialSelected: const {}, isDismissible: false);
            }
          });
        }
        return _ForYouCategoryGate(
          onSelectCategories: () =>
              _openCategorySheet(initialSelected: const {}, isDismissible: false),
        );
      }
    }

    final state = ref.watch(jobBoardProvider);
    final useInfiniteScroll = _useInfiniteScroll;

    return RefreshIndicator(
      onRefresh: _runSearch,
      child: ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
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
                      Text(
                        // JS-06: the tab's own label is "For You" —
                        // "Find a job" now only applies to the
                        // logged-out landing page, which has no
                        // personalization to show instead.
                        widget.isGuest ? 'Find a job' : 'For You',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (!widget.isGuest) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: 'Edit preferences',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openCategorySheet(
                            initialSelected: _savedCategories,
                          ),
                          // Distinct from the "Filters" card's tune_rounded
                          // icon just below — the two buttons open
                          // different things (this is the "For You"
                          // category picker, that toggles the filter
                          // form), so they shouldn't look identical.
                          icon: const Icon(Icons.category_outlined, size: 20),
                        ),
                      ],
                    ],
                  ),
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
        if (widget.showSearchCard) ...[
          FilterCard(
            expanded: _filtersExpanded,
            onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
            footer: Row(
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
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _creatorType,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'employer', child: Text('Company jobs')),
                  DropdownMenuItem(value: 'agency', child: Text('Agency jobs')),
                ],
                onChanged: (value) => setState(() => _creatorType = value),
              ),
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: 'Keyword',
                  hintText: 'Job title or description',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Addis Ababa, Bole',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
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
              DropdownButtonFormField<ExperienceLevel?>(
                initialValue: _experienceLevel,
                decoration: const InputDecoration(
                  labelText: 'Experience',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<ExperienceLevel?>(
                    value: null,
                    child: Text('Any experience'),
                  ),
                  for (final level in ExperienceLevel.values)
                    DropdownMenuItem<ExperienceLevel?>(
                      value: level,
                      child: Text(level.label),
                    ),
                ],
                onChanged: (value) => setState(() => _experienceLevel = value),
              ),
            ],
          ),
        ],
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
            useInfiniteScroll: useInfiniteScroll,
            isLoadingMore: state.isLoadingMore,
            hasMore: state.hasMore,
          ),
        ),
      ],
      ),
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

/// JS-06: blocks the job board until an authenticated seeker has at
/// least one preferred category saved — see `JobBoardScreen.build`'s
/// `needsCategorySelection` check. `build` also auto-opens
/// `CategoryPreferencesSheet` over this on first arrival; this screen
/// is what's left showing behind it (or after it's dismissed without
/// saving), so its CTA re-opens the same sheet rather than duplicating
/// the flow. Mirrors the empty-state screens below
/// (`_EmptyState`/`_ErrorState`) visually, just with that CTA instead
/// of a retry action.
class _ForYouCategoryGate extends StatelessWidget {
  const _ForYouCategoryGate({required this.onSelectCategories});

  final VoidCallback onSelectCategories;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Personalize your "For You" feed',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select at least one job category so we can show you jobs '
              "that actually match what you're looking for.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onSelectCategories,
              child: const Text('Choose categories'),
            ),
          ],
        ),
      ),
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
    required this.useInfiniteScroll,
    required this.isLoadingMore,
    required this.hasMore,
    this.onApply,
  });

  final JobBrowseResult result;
  final int page;
  final int pageSize;
  final bool isGuest;
  final Set<String> appliedJobIds;
  final void Function(Job job)? onApply;

  /// True on the mobile-width and landing (guest) layouts — renders a
  /// trailing loading/"end of results" row instead of the desktop
  /// Previous/Next buttons; the actual scroll-triggered fetch lives in
  /// `_JobBoardScreenState._onScroll`.
  final bool useInfiniteScroll;
  final bool isLoadingMore;
  final bool hasMore;

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
          const Divider(height: 1),
        ],
        const SizedBox(height: 8),
        if (useInfiniteScroll)
          _InfiniteScrollFooter(isLoadingMore: isLoadingMore, hasMore: hasMore)
        else
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

/// Bottom-of-list indicator for the infinite-scroll layout: a small
/// spinner while [isLoadingMore] fetches the next page, or a quiet
/// "you've reached the end" note once [hasMore] is false. Renders
/// nothing in between (more likely to load) so a fast scroller doesn't
/// see a flash of empty space between cards and the next fetch kicking
/// in.
class _InfiniteScrollFooter extends StatelessWidget {
  const _InfiniteScrollFooter({required this.isLoadingMore, required this.hasMore});

  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            "You've reached the end of the list",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guests can browse but have nothing to save to — only show the
    // bookmark toggle once they're actually signed in as a seeker.
    final isSaved = !isGuest && ref.watch(savedJobsProvider).containsKey(job.id);
    final companyName = job.poster == null
        ? (job.creatorType == 'agency' ? 'Agency' : 'Company')
        : job.poster!.isAgency
            ? '${job.poster!.name} · Agency'
            : job.poster!.name;

    return InkWell(
      onTap: () => _openDetail(context),
      child: Padding(
        // Tightened from 14 to 10 — with the meta row now carrying job
        // type + location + salary on one line instead of two stacked
        // lines, the card needs less vertical breathing room to still
        // read cleanly.
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company row: small logo + name, bookmark pinned to the
            // far right — kept light so the eye lands on the title next.
            Row(
              children: [
                _CompanyLogo(logoUrl: job.poster?.logoUrl, isAgency: job.poster?.isAgency ?? false),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                ),
                if (!isGuest)
                  InkWell(
                    onTap: () => ref.read(savedJobsProvider.notifier).toggle(job),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 26,
                        color: isSaved ? AppColors.green : AppColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // Matches the reference design: a bold, full-ink title that
              // reads as the card's headline rather than secondary text.
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            // Location and salary on their own stacked lines, matching
            // the app's job-card reference design.
            _JobMetaRow(job: job),
            const SizedBox(height: 10),
            Row(
              children: [
                JobApplyButton(
                  job: job,
                  isGuest: isGuest,
                  applied: applied,
                  onApply: onApply,
                  dense: true,
                ),
                const Spacer(),
                Text(
                  _postedAgo(job.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The location / salary lines under a job card's title. Pulled out of
/// `_JobCard.build` because it's the one piece of layout that has to
/// gracefully handle "salary not set" — a single widget with its own
/// small helper is easier to read than an inline conditional list
/// spliced into a `Column`'s `children`.
class _JobMetaRow extends StatelessWidget {
  const _JobMetaRow({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final hasSalary = job.salaryRange != null && job.salaryRange!.isNotEmpty;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job.location,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
        if (hasSalary) ...[
          const SizedBox(height: 2),
          Text(formatSalary(job.salaryRange!), style: style?.copyWith(color: AppColors.inkMuted)),
        ],
      ],
    );
  }
}

/// Company/agency avatar shown at the left of a job card — the poster's
/// `logoUrl` when there is one (employer postings only; agencies have no
/// logo field on the backend), otherwise a generic building/agency icon
/// so the card layout never has an empty gap where the logo would go.
class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.logoUrl, required this.isAgency});

  final String? logoUrl;
  final bool isAgency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() => Center(
        child: Icon(
          isAgency ? Icons.groups_outlined : Icons.business_outlined,
          size: 14,
          color: AppColors.inkMuted,
        ),
      );
}

/// Short "posted X ago" label for a job card's bottom-right corner —
/// deliberately terser than `formatLastSeen` (e.g. "3d" not "Last seen
/// 3d ago") since it's sitting next to an icon in a tight row, not
/// standing alone on a profile.
String _postedAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 30) return '${diff.inDays}d';
  final months = (diff.inDays / 30).floor();
  return '${months}mo';
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
