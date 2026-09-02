import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ats/domain/message.dart';
import '../../ats/presentation/placement_chat_screen.dart';
import '../../auth/presentation/auth_provider.dart';
import 'seeker_messages_provider.dart';

/// The seeker's chat inbox: every placement thread that has a message in
/// it, newest first, with a preview of the last message — the page shown
/// when the seeker taps the "Messages" icon in the bottom nav.
///
/// Tapping a row pushes the same [PlacementChatScreen] the employer and
/// agency sides already use for their own placements — messaging is
/// placement-scoped, not role-scoped, so this is the seeker's half of
/// exactly the same threads they'd see.
class SeekerMessagesScreen extends ConsumerWidget {
  const SeekerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(seekerChatThreadsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(seekerChatThreadsProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Messages', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Conversations with employers and agencies about jobs '
            'you\'ve been matched to.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          threadsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorState(
              onRetry: () => ref.read(seekerChatThreadsProvider.notifier).load(),
            ),
            data: (threads) => threads.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: _EmptyState(),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < threads.length; i++)
                          _ChatThreadRow(
                            thread: threads[i],
                            showDivider: i != threads.length - 1,
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

class _ChatThreadRow extends ConsumerWidget {
  const _ChatThreadRow({required this.thread, required this.showDivider});

  final ChatThread thread;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).user?.id;
    final message = thread.lastMessage;
    final fromMe = currentUserId != null && message.senderId == currentUserId;
    final senderLabel = fromMe ? 'You' : _senderRoleLabel(message.senderRole);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlacementChatScreen(
            placementId: thread.placement.placementId,
            candidateName: thread.placement.jobTitle ?? 'Chat',
            placementStatus: thread.placement.status,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    thread.placement.jobTitle ?? 'Untitled job',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(message.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$senderLabel: ${message.body}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            if (showDivider) const Divider(height: 20),
          ],
        ),
      ),
    );
  }
}

String _senderRoleLabel(SenderRole role) => switch (role) {
      SenderRole.employer => 'Employer',
      SenderRole.agency => 'Agency',
      SenderRole.seeker => 'You',
    };

String _formatTimestamp(DateTime utc) {
  final dt = utc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diffDays = today.difference(target).inDays;

  if (diffDays == 0) {
    final hour24 = dt.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
  if (diffDays == 1) return 'Yesterday';
  if (diffDays < 7) return '${diffDays}d ago';
  return '${dt.month}/${dt.day}/${dt.year}';
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
              'Once an employer or agency messages you about a job '
              'you\'ve been matched to, it\'ll show up here.',
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
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Text('Failed to load messages.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
