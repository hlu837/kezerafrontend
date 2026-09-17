import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/board_mode_toggle.dart';
import '../../../core/widgets/filter_card.dart';
import '../../seeker/domain/experience_level.dart';
import '../../seeker/domain/job_category.dart';
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
  ExperienceLevel? _experienceLevel;
  // JS-04-style category filter — mirrors the job board's own Category
  // dropdown (job_board_screen.dart) so filtering talent by profession
  // works the same way as filtering jobs by category. null = "any
  // category".
  String? _category;
  // Collapsed by default, same convention as JobBoardScreen's own
  // "Filters" card — a guest lands here wanting to search, not stare at
  // three open fields before they've typed anything.
  bool _filtersExpanded = false;

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
          category: _category,
          clearCategory: _category == null,
          experienceLevel: _experienceLevel,
          clearExperienceLevel: _experienceLevel == null,
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

  /// The actual sign-up trigger for a guest browsing expert cards —
  /// fires only when they act on a specific expert (tap Call or
  /// Message), not just for looking at the card. Named after the
  /// action so the prompt reads as a direct answer to what they just
  /// tried to do, instead of a generic "sign up to see more" nudge.
  void _promptContactSignUp(BuildContext context, {required String action, required String seekerName}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Create a free employer/agency account to $action $seekerName.'),
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
        const SizedBox(height: 12),
        // Two alternate ways into the skilled-trade side of "Find
        // talent", each with its own full-height screen (a map/list and
        // a category directory don't fit inside this filter card):
        // browse by trade category with counts, or jump straight to the
        // proximity map/list.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/experts/categories'),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('Browse experts by category'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/experts/nearby'),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('View nearby experts on map'),
            ),
          ],
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
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: 'Keyword',
                hintText: 'Name or bio',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runSearch(),
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
            onContactAttempt: (action, seekerName) =>
                _promptContactSignUp(context, action: action, seekerName: seekerName),
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
    required this.onContactAttempt,
  });

  final SearchSeekersResult result;
  final int page;
  final VoidCallback onSignUp;

  /// Fired when a guest taps Call or Message on a specific expert's
  /// card — `(action, seekerName)`, e.g. `('call', 'Abebe Kebede')` —
  /// so the resulting sign-up prompt can name what they were trying to
  /// do instead of a blanket "sign up to view".
  final void Function(String action, String seekerName) onContactAttempt;

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
        for (final seeker in seekers)
          _PublicCandidateCard(
            seeker: seeker,
            onContactAttempt: (action) => onContactAttempt(action, seeker.fullName),
          ),
        const SizedBox(height: 4),
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
          Icon(Icons.lock_outline, color: AppColors.greenDark, size: 20),
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

/// One expert's card in the guest "Find talent" results — collapsed by
/// default to just what's needed to scan and decide whether to look
/// closer (photo/icon, full name, title, location, experience level),
/// expandable in place to reveal skills and bio without leaving the
/// list. Mirrors the compact/expand pattern `_JobCard`
/// (job_board_screen.dart) established for the jobs side of this same
/// landing page.
///
/// Doesn't gate anything behind a passive "Sign up to view" label —
/// browsing and expanding a card is free. The sign-up prompt only
/// fires when the guest actually tries to act on an expert, via the
/// Call/Message buttons below (see [onContactAttempt]), so it reads as
/// a direct response to something they attempted rather than a wall
/// they hit just for looking.
class _PublicCandidateCard extends StatefulWidget {
  const _PublicCandidateCard({required this.seeker, required this.onContactAttempt});

  final Seeker seeker;

  /// Fired with 'call' or 'message' when the guest taps that action —
  /// this is the actual sign-up trigger now (see class doc), not
  /// looking at or expanding the card itself.
  final ValueChanged<String> onContactAttempt;

  @override
  State<_PublicCandidateCard> createState() => _PublicCandidateCardState();
}

class _PublicCandidateCardState extends State<_PublicCandidateCard> {
  bool _expanded = false;

  String _initials(String fullName) {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final seeker = widget.seeker;
    final outline = Theme.of(context).colorScheme.outline;
    // "Title" per the ask — the seeker's own most recent CV entry, same
    // source `CandidateDetailScreen`'s Experience section reads from.
    // Nothing to show for a seeker who hasn't filled in any experience
    // yet, which is common enough pre-CV-builder that this has to
    // degrade gracefully rather than assume it's always there.
    final title = seeker.experience.isNotEmpty ? seeker.experience.first.title : null;
    final hasExpandableContent =
        seeker.skills.isNotEmpty || (seeker.bio != null && seeker.bio!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasExpandableContent ? () => setState(() => _expanded = !_expanded) : null,
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
                    backgroundColor: AppColors.greenSurface,
                    backgroundImage:
                        seeker.photoUrl != null ? NetworkImage(seeker.photoUrl!) : null,
                    child: seeker.photoUrl == null
                        ? Text(
                            _initials(seeker.fullName),
                            style: TextStyle(
                              color: AppColors.greenDark,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              seeker.fullName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            AvailabilityBadgeWidget(available: seeker.availabilityStatus),
                            if (seeker.isBoosted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Boosted',
                                  style: TextStyle(
                                    color: AppColors.greenDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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
                                ?.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 4),
                        // Location + experience band on one wrapping
                        // line, each with its own small icon — same
                        // "scan facts" idea as the job card's meta row.
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _MetaIconText(
                              icon: Icons.place_outlined,
                              text: seeker.city ?? 'City not specified',
                              color: outline,
                            ),
                            if (seeker.experienceLevel != null)
                              _MetaIconText(
                                icon: Icons.workspace_premium_outlined,
                                text: seeker.experienceLevel!.label,
                                color: outline,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GuestContactButton(
                            icon: Icons.call_outlined,
                            tooltip: 'Call',
                            onPressed: () => widget.onContactAttempt('call'),
                          ),
                          const SizedBox(width: 4),
                          _GuestContactButton(
                            icon: Icons.chat_bubble_outline,
                            tooltip: 'Message',
                            onPressed: () => widget.onContactAttempt('message'),
                          ),
                        ],
                      ),
                      if (hasExpandableContent) ...[
                        const SizedBox(height: 2),
                        Icon(
                          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: outline,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: !_expanded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (seeker.skills.isNotEmpty)
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
                            if (seeker.bio != null && seeker.bio!.isNotEmpty) ...[
                              if (seeker.skills.isNotEmpty) const SizedBox(height: 10),
                              Text(
                                seeker.bio!,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small circular Call/Message icon button for a guest expert card.
/// Looks and sits exactly where a real contact action would (compare
/// `CallTextButtons`, used once a real phone number is available on
/// the authenticated candidate views) — tapping it is what actually
/// triggers the sign-up prompt now (see [_PublicCandidateCard]), rather
/// than the whole card being labeled "sign up to view" up front.
class _GuestContactButton extends StatelessWidget {
  const _GuestContactButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 17, color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

/// A small icon + label pair — location, experience band, etc. — used
/// in the collapsed header of [_PublicCandidateCard].
class _MetaIconText extends StatelessWidget {
  const _MetaIconText({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
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
