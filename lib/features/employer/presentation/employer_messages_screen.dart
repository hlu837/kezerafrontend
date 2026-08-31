import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../ats/presentation/placement_chat_screen.dart';
import '../../jobs/domain/placement.dart';
import '../../jobs/presentation/placement_status_badge.dart';
import 'employer_messages_provider.dart';

/// EMP-02 (employer side): candidates matched to jobs this employer has
/// posted, one row per placement, with a tap-through to the in-app chat
/// thread for that placement (`PlacementChatScreen` — already built and
/// working on the agency side; this screen is the employer's entry point
/// to the exact same feature). Deliberately simpler than the agency's
/// `PlacementsScreen`: no dispatch/status-transition actions, since those
/// endpoints are agency-only — this is just "who am I matched with, and
/// can I message them."
class EmployerMessagesScreen extends ConsumerWidget {
  const EmployerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(employerMessagesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(employerMessagesProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Messages', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Chat with candidates matched to your job postings.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          messagesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Failed to load messages.',
              onRetry: () => ref.read(employerMessagesProvider.notifier).load(),
            ),
            data: (rows) => rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: _EmptyState(),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (var index = 0; index < rows.length; index++)
                          _CandidateThreadRow(
                            row: rows[index],
                            showDivider: index != rows.length - 1,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CandidateThreadRow extends StatelessWidget {
  const _CandidateThreadRow({required this.row, required this.showDivider});

  final SuggestedSeeker row;
  final bool showDivider;

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlacementChatScreen(
          placementId: row.placementId,
          candidateName: row.fullName ?? 'Candidate',
          placementStatus: row.status,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openChat(context),
      child: Padding(
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
                      Text(
                        row.fullName ?? 'Unnamed candidate',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        row.city ?? 'City unknown',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                PlacementStatusBadgeWidget(status: row.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              row.jobTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            if (row.skills.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in row.skills.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(skill, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  row.score != null
                      ? 'Match ${(row.score! * 100).toStringAsFixed(0)}%'
                      : 'Match —',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _openChat(context),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (showDivider) const Divider(height: 24),
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
          Icon(Icons.forum_outlined,
              size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Once the matching engine finds candidates for your job '
              'postings, you can message them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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
