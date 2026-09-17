import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/utils/last_seen_formatter.dart';
import '../../../core/widgets/call_text_buttons.dart';
import '../../../core/widgets/filter_card.dart';
import '../../seeker/domain/experience_level.dart';
import '../../seeker/domain/seeker.dart';
import '../../seeker/presentation/availability_badge.dart';
import '../../seeker/presentation/candidate_detail_screen.dart';
import '../domain/agency_models.dart';
import 'agency_provider.dart';

/// This agency's own roster — every candidate it has registered via the
/// "Registration" (walk-in) screen. Distinct from the employer/agency
/// "Find candidates" search (`CandidatesScreen`): that browses the whole
/// public seeker pool, this is scoped to just the seekers *this* agency
/// registered (`GET /agencies/candidates`, filtered server-side by
/// `agencyId`).
class AgencyCandidatesScreen extends ConsumerStatefulWidget {
  const AgencyCandidatesScreen({super.key});

  @override
  ConsumerState<AgencyCandidatesScreen> createState() =>
      _AgencyCandidatesScreenState();
}

class _AgencyCandidatesScreenState
    extends ConsumerState<AgencyCandidatesScreen> {
  final _keywordController = TextEditingController();
  final _cityController = TextEditingController();
  ExperienceLevel? _experienceLevel;
  // null = all, true = available only, false = unavailable only.
  bool? _availabilityStatus;
  // Starts expanded, matching this card's previous `ExpansionTile`
  // default — same collapsible `FilterCard` every other filter card in
  // the app uses now, rather than `ExpansionTile` (see `FilterCard`'s
  // doc comment for why).
  bool _filtersExpanded = true;

  @override
  void dispose() {
    _keywordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _runSearch() {
    ref.read(agencyRosterProvider.notifier).search(
          keyword: _keywordController.text.trim(),
          city: _cityController.text.trim(),
          experienceLevel: _experienceLevel,
          clearExperienceLevel: _experienceLevel == null,
          availabilityStatus: _availabilityStatus,
          clearAvailabilityStatus: _availabilityStatus == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyRosterProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Your candidates', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Everyone you\'ve registered on the "Registration" screen — '
          'search your own roster by name, city, or experience.',
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
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: 'Name or bio',
                hintText: 'Search by keyword',
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
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _availabilityStatus == null,
                    onSelected: (_) =>
                        setState(() => _availabilityStatus = null),
                  ),
                  ChoiceChip(
                    label: const Text('Available'),
                    selected: _availabilityStatus == true,
                    onSelected: (_) =>
                        setState(() => _availabilityStatus = true),
                  ),
                  ChoiceChip(
                    label: const Text('Unavailable'),
                    selected: _availabilityStatus == false,
                    onSelected: (_) =>
                        setState(() => _availabilityStatus = false),
                  ),
                ],
              ),
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
                : 'Failed to load your candidates.',
            onRetry: _runSearch,
          ),
          data: (result) => _RosterResultList(result: result),
        ),
      ],
    );
  }
}

class _RosterResultList extends ConsumerWidget {
  const _RosterResultList({required this.result});

  final AgencyCandidatesResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = result.candidates;
    final atLastPage = result.page >= result.totalPages;

    if (candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: _EmptyState(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final candidate in candidates) ...[
          _RosterCard(seeker: candidate),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${result.page} of ${result.totalPages} · '
              '${result.total} candidate${result.total == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: result.page <= 1
                      ? null
                      : () => ref.read(agencyRosterProvider.notifier).previousPage(),
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: atLastPage
                      ? null
                      : () => ref.read(agencyRosterProvider.notifier).nextPage(),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.seeker});

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

  @override
  Widget build(BuildContext context) {
    final cvUrl = seeker.cvUrl;
    final photoUrl = seeker.photoUrl;
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context),
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
                          ],
                        ),
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
              if (seeker.phone != null) ...[
                const SizedBox(height: 12),
                CallTextButtons(phone: seeker.phone),
              ],
            ],
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
    return Center(
      child: Column(
        children: [
          Icon(Icons.groups_outlined,
              size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No candidates yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Register a walk-in candidate to start building your roster, '
            'or try broadening your filters.',
            textAlign: TextAlign.center,
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
