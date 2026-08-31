import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skill_tag_input.dart';
import '../domain/seeker.dart';
import 'availability_badge.dart';
import 'candidates_provider.dart';

/// Mirrors `web-backoffice/src/app/employer/candidates/page.tsx` — a
/// keyword/city/skills filter form over `GET /seekers/search`, with
/// previous/next pagination.
class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  final _keywordController = TextEditingController();
  final _cityController = TextEditingController();
  List<String> _skills = [];

  @override
  void dispose() {
    _keywordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _runSearch() {
    ref.read(candidatesProvider.notifier).search(
          keyword: _keywordController.text.trim(),
          city: _cityController.text.trim(),
          skills: _skills,
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
          'Search available job seekers by skill, city, or keyword.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Keyword',
                    hintText: 'Name or bio',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'Addis Ababa',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
                const SizedBox(height: 12),
                SkillTagInput(
                  label: 'Skills',
                  skills: _skills,
                  onChanged: (skills) => setState(() => _skills = skills),
                  hintText: 'e.g. plumbing — press Enter',
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _runSearch,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
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
        Card(
          child: Column(
            children: [
              for (var i = 0; i < seekers.length; i++)
                _CandidateRow(
                  seeker: seekers[i],
                  showDivider: i != seekers.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
          const Icon(Icons.lock_outline, color: AppColors.greenDark, size: 20),
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

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.seeker, required this.showDivider});

  final Seeker seeker;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cvUrl = seeker.cvUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    const SizedBox(height: 2),
                    Text(
                      seeker.city ?? 'City not specified',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (cvUrl != null)
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(cvUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('View CV'),
                ),
            ],
          ),
          if (seeker.skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in seeker.skills.take(8))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(skill, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
          if (showDivider) const Divider(height: 24),
        ],
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
          const Icon(Icons.rocket_launch, size: 11, color: AppColors.greenDark),
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
