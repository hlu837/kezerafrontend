import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/board_mode_toggle.dart';
import '../../../core/widgets/skill_tag_input.dart';
import '../../seeker/domain/seeker.dart';
import '../../seeker/presentation/availability_badge.dart';
import '../../seeker/presentation/public_candidates_provider.dart';

/// Guest landing page, "Experts" side of the Jobs/Experts toggle
/// (see `PublicJobBoardScreen`). Aimed at an employer/agency visitor who
/// came here to look for talent rather than a job — browses a capped
/// preview of available seekers via `GET /seekers/public-search` (no
/// login required), with a "Sign up" prompt instead of a "View CV" link
/// since the full profile/CV stays a gated action for guests, same as
/// "Apply" is on the jobs side.
class PublicCandidatesBoardScreen extends ConsumerStatefulWidget {
  const PublicCandidatesBoardScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.header,
  });

  final BoardMode mode;
  final ValueChanged<BoardMode> onModeChanged;

  /// Same ad-banner slot as `JobBoardScreen.header`, rendered below the
  /// search card, above the results.
  final Widget? header;

  @override
  ConsumerState<PublicCandidatesBoardScreen> createState() =>
      _PublicCandidatesBoardScreenState();
}

class _PublicCandidatesBoardScreenState
    extends ConsumerState<PublicCandidatesBoardScreen> {
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
    ref.read(publicCandidatesProvider.notifier).search(
          keyword: _keywordController.text.trim(),
          city: _cityController.text.trim(),
          skills: _skills,
        );
  }

  void _promptSignUp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create a free employer/agency account to view full profiles and contact talent.'),
      ),
    );
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicCandidatesProvider);

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
                  Text('Find talent', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            BoardModeToggle(mode: widget.mode, onChanged: widget.onModeChanged),
          ],
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
                  hintText: 'e.g. flutter, react — press Enter',
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
            message: error is ApiException ? error.message : 'Failed to load talent.',
            onRetry: _runSearch,
          ),
          data: (result) => _PublicCandidateResultList(
            result: result,
            page: state.params.page,
            onSignUp: () => _promptSignUp(context),
          ),
        ),
      ],
    );
  }
}

class _PublicCandidateResultList extends ConsumerWidget {
  const _PublicCandidateResultList({
    required this.result,
    required this.page,
    required this.onSignUp,
  });

  final SearchSeekersResult result;
  final int page;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seekers = result.seekers;
    final atLastPage = result.limitReached || seekers.length < result.limit;

    if (seekers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text('No matching talent right now. Try a different search.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Column(
            children: [
              for (var i = 0; i < seekers.length; i++)
                _PublicCandidateRow(
                  seeker: seekers[i],
                  showDivider: i != seekers.length - 1,
                  onSignUp: onSignUp,
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
                      : () => ref.read(publicCandidatesProvider.notifier).previousPage(),
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: atLastPage
                      ? null
                      : () => ref.read(publicCandidatesProvider.notifier).nextPage(),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
        if (result.limitReached) ...[
          const SizedBox(height: 12),
          _SignUpPrompt(onSignUp: onSignUp),
        ],
      ],
    );
  }
}

/// Shown once the guest preview's fixed visibility cap is hit — pushes
/// toward signing up to search the full candidate pool (mirrors
/// `_UpgradePrompt` on the authenticated Candidates screen).
class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.onSignUp});

  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
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
              "You've reached the preview limit. Sign up as an employer or agency to search the full candidate pool.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.greenDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onSignUp, child: const Text('Sign up')),
        ],
      ),
    );
  }
}

class _PublicCandidateRow extends StatelessWidget {
  const _PublicCandidateRow({
    required this.seeker,
    required this.showDivider,
    required this.onSignUp,
  });

  final Seeker seeker;
  final bool showDivider;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
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
                        AvailabilityBadgeWidget(available: seeker.availabilityStatus),
                        if (seeker.isBoosted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Boosted',
                              style: TextStyle(
                                color: AppColors.greenDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
              OutlinedButton(
                onPressed: onSignUp,
                child: const Text('Sign up to view'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(skill, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
          if (showDivider) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
          ],
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
