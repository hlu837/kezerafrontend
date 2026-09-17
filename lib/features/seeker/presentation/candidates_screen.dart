import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/call_text_buttons.dart';
import '../../../core/widgets/filter_card.dart';
import '../../ats/presentation/placement_chat_screen.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/presentation/jobs_provider.dart';
import '../../../core/utils/last_seen_formatter.dart';
import '../domain/experience_level.dart';
import '../domain/job_category.dart';
import '../domain/seeker.dart';
import 'availability_badge.dart';
import 'candidate_detail_screen.dart';
import 'candidates_provider.dart';

/// Mirrors `web-backoffice/src/app/employer/candidates/page.tsx` — a
/// category/city/experience filter form over `GET /seekers/search`, with
/// previous/next pagination. The filter card is collapsible (starts
/// expanded, via the shared `FilterCard` — same as `JobBoardScreen`'s
/// filter card) so it doesn't push the result list too far down once a
/// search has been run.
class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  final _cityController = TextEditingController();
  String? _category;
  ExperienceLevel? _experienceLevel;
  // Starts expanded (matches this screen's previous ExpansionTile
  // default) — toggled via the shared `FilterCard`, same as
  // `JobBoardScreen`'s filter card.
  bool _filtersExpanded = true;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _runSearch() {
    ref.read(candidatesProvider.notifier).search(
          city: _cityController.text.trim(),
          category: _category,
          clearCategory: _category == null,
          experienceLevel: _experienceLevel,
          clearExperienceLevel: _experienceLevel == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(candidatesProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Find candidates', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Search available job seekers by category, city, or experience.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 16),
        FilterCard(
          expanded: _filtersExpanded,
          onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
          footer: FilledButton(
            onPressed: _runSearch,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Search'),
          ),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Any category'),
                ),
                for (final category in kJobCategories)
                  DropdownMenuItem<String?>(
                    value: category.key,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'Addis Ababa',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runSearch(),
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
        const SizedBox(height: 16),
        state.result.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ErrorState(
            message: error is ApiException
                ? error.message
                : 'Failed to search candidates.',
            onRetry: _runSearch,
          ),
          data: (result) => _CandidatesResultList(
            result: result,
            page: state.params.page,
          ),
        ),
      ],
    );
  }
}

class _CandidatesResultList extends ConsumerWidget {
  const _CandidatesResultList({
    required this.result,
    required this.page,
  });

  final SearchSeekersResult result;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seekers = result.seekers;
    // Server-clamped page size for this tier, not what the client
    // asked for — see seeker.service.js#searchSeekers.
    final atLastPage = result.limitReached || seekers.length < result.limit;

    if (seekers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: result.limitReached
            ? _UpgradePrompt(tier: result.subscriptionTier)
            : const _EmptyState(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seeker in seekers) ...[
          _CandidateCard(key: ValueKey(seeker.id), seeker: seeker),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page $page · ${result.count} result${result.count == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: page == 1
                      ? null
                      : () => ref.read(candidatesProvider.notifier).previousPage(),
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: atLastPage
                      ? null
                      : () => ref.read(candidatesProvider.notifier).nextPage(),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
        if (result.limitReached) ...[
          const SizedBox(height: 12),
          _UpgradePrompt(tier: result.subscriptionTier),
        ],
      ],
    );
  }
}

/// Shown once a tier's candidate-visibility ceiling has been hit (see
/// `limitReached` on `SearchSeekersResult`). Enterprise has no ceiling,
/// so this never renders for it.
class _UpgradePrompt extends StatelessWidget {
  const _UpgradePrompt({required this.tier});

  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    final nextTier = tier == SubscriptionTier.basic ? 'Premium' : 'Enterprise';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.greenDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You've reached the candidate limit for your ${tier.label} plan. "
              'Upgrade to $nextTier to see more candidates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.greenDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({super.key, required this.seeker});

  final Seeker seeker;

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(seeker: seeker),
      ),
    );
  }

  /// The "Message" button. Chat is placement-based (see
  /// `PlacementChatScreen`/`/placements/:id/messages`), but a candidate
  /// browsed via search isn't attached to any job yet — so this asks
  /// which of the employer's own postings the conversation is about
  /// (skipping the question if there's only one), invites the candidate
  /// onto that job via `POST /jobs/:id/invite-candidate`, then opens the
  /// resulting chat thread.
  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final jobsAsync = ref.read(myJobsProvider);
    var jobs = jobsAsync.valueOrNull;

    if (jobs == null) {
      // Not loaded yet (e.g. this screen opened before the jobs list
      // finished its first fetch) — wait for it rather than telling the
      // employer to post a job they may already have.
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      jobs = await ref.read(myJobsProvider.notifier).load().then(
            (_) => ref.read(myJobsProvider).valueOrNull,
          );
      if (context.mounted) Navigator.pop(context);
    }

    final openJobs = (jobs ?? [])
        .where((job) => job.status == JobStatus.open)
        .toList();

    if (!context.mounted) return;

    if (openJobs.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Post a job to message candidates'),
          content: const Text(
            'Messaging a candidate starts a conversation about one of '
            'your job postings. Post an open job first, then you can '
            'message candidates about it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final Job? chosenJob = openJobs.length == 1
        ? openJobs.first
        : await showDialog<Job>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: Text('Message ${seeker.fullName} about which job?'),
              children: [
                for (final job in openJobs)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, job),
                    child: Text(job.title),
                  ),
              ],
            ),
          );

    if (chosenJob == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final placementId = await ref.read(jobsRepositoryProvider).inviteCandidate(
            jobId: chosenJob.id,
            seekerId: seeker.id,
          );
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss the loading dialog
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PlacementChatScreen(
            placementId: placementId,
            candidateName: seeker.fullName,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss the loading dialog
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      // Belt-and-suspenders on top of JobsRepository._guard: whatever
      // this was, the loading dialog above must not get left stuck on
      // screen — see _guard's doc comment for why that matters here.
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss the loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cvUrl = seeker.cvUrl;
    final photoUrl = seeker.photoUrl;
    final outline = Theme.of(context).colorScheme.outline;
    // Seeker's most recent CV entry — same source `CandidateDetailScreen`'s
    // Experience section reads from, and the same convention the guest
    // "Find talent" card (`public_candidates_board_screen.dart`) uses.
    // Nothing to show for a seeker who hasn't filled in any experience
    // yet, which has to degrade gracefully since it's common pre-CV-builder.
    final title = seeker.experience.isNotEmpty ? seeker.experience.first.title : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          _initials(seeker.fullName),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              seeker.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AvailabilityBadgeWidget(
                            available: seeker.availabilityStatus,
                          ),
                          if (seeker.isBoosted) ...[
                            const SizedBox(width: 6),
                            const _BoostedBadge(),
                          ],
                        ],
                      ),
                      if (title != null && title.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: outline, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 14, color: outline),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              seeker.city ?? 'City not specified',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: outline),
                            ),
                          ),
                        ],
                      ),
                      if (formatLastSeen(seeker.lastSeenAt) != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isOnlineNow(seeker.lastSeenAt)
                                  ? Icons.circle
                                  : Icons.schedule,
                              size: isOnlineNow(seeker.lastSeenAt) ? 8 : 14,
                              color: isOnlineNow(seeker.lastSeenAt)
                                  ? Colors.green
                                  : outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatLastSeen(seeker.lastSeenAt)!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isOnlineNow(seeker.lastSeenAt)
                                        ? Colors.green.shade700
                                        : outline,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (cvUrl != null)
                  IconButton(
                    tooltip: 'View CV',
                    icon: const Icon(Icons.description_outlined),
                    onPressed: () => launchUrl(
                      Uri.parse(cvUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ],
            ),
            if (seeker.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in seeker.skills.take(8))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(skill, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDetails(context),
                    child: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _startConversation(context, ref),
                    child: const Text('Message'),
                  ),
                ),
              ],
            ),
            if (seeker.phone != null) ...[
              const SizedBox(height: 8),
              CallTextButtons(phone: seeker.phone),
            ],
          ],
        ),
      ),
    );
  }
}

/// SEEK-xx: shown next to a candidate's name in employer/agency search
/// when they've paid to boost their profile (see
/// seeker.service.js#searchSeekers, which also ranks them first).
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
          Icon(Icons.rocket_launch, size: 11, color: AppColors.greenDark),
          const SizedBox(width: 3),
          Text(
            'Boosted',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.greenDark,
            ),
          ),
        ],
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
          Icon(Icons.person_search_outlined,
              size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No candidates found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try broadening your filters.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
