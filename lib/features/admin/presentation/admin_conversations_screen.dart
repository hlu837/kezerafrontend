import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';

// No `intl` dependency in this project (see pubspec.yaml) — a tiny
// manual formatter avoids adding one just for "MMM d, HH:mm" labels.
const _kMonthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatConversationTimestamp(String iso) {
  try {
    final date = DateTime.parse(iso).toLocal();
    final month = _kMonthAbbreviations[date.month - 1];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$month ${date.day}, $hh:$mm';
  } catch (_) {
    return '';
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// GET /admin/conversations — every placement with at least one message,
/// newest activity first. No pagination controls in this first cut; the
/// backend still accepts page/limit for when the list outgrows one screen.
final _conversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/conversations',
    queryParameters: {'limit': 100},
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['conversations'] as List<dynamic>);
});

/// GET /admin/conversations/:placementId/messages — full thread for one
/// conversation. Keyed by placementId so each opened thread caches
/// independently.
final _conversationThreadProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, placementId) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio
      .get<Map<String, dynamic>>('/admin/conversations/$placementId/messages');
  return response.data!['data'] as Map<String, dynamic>;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/conversations` sidebar destination —
/// admin's read-only window into every employer/agency <-> seeker
/// conversation on the platform. Renders inside [ResponsiveShell]'s
/// content area (via admin_shell.dart), so this brings no
/// [Scaffold]/[AppBar] of its own.
class AdminConversationsScreen extends ConsumerWidget {
  const AdminConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConversations = ref.watch(_conversationsProvider);

    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversations',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Every message thread between a company/agency and a candidate. '
              'Read-only — for oversight, not participation.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: asyncConversations.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    'Could not load conversations.',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Center(
                      child: Text(
                        'No conversations yet.',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(_conversationsProvider),
                    child: ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final convo = conversations[index];
                        return _ConversationRow(
                          conversation: convo,
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => _ConversationThreadDialog(
                              placementId: convo['placementId'] as String,
                              jobTitle: convo['jobTitle'] as String? ?? 'Unknown job',
                              posterName: convo['posterName'] as String? ?? 'Unknown',
                              seekerName: convo['seekerName'] as String? ?? 'Unknown',
                            ),
                          ),
                        );
                      },
                    ),
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

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jobTitle = conversation['jobTitle'] as String? ?? 'Unknown job';
    final posterName = conversation['posterName'] as String? ?? 'Unknown';
    final seekerName = conversation['seekerName'] as String? ?? 'Unknown';
    final messageCount = conversation['messageCount'] as int? ?? 0;
    final preview = conversation['lastMessagePreview'] as String? ?? '';
    final lastMessageAt = conversation['lastMessageAt'] as String?;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.greenSurface,
              child: Icon(Icons.forum_outlined, color: AppColors.green, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$posterName ↔ $seekerName',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    jobTitle,
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      style: TextStyle(color: AppColors.inkFaint, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastMessageAt != null)
                  Text(
                    _formatConversationTimestamp(lastMessageAt),
                    style: TextStyle(color: AppColors.inkFaint, fontSize: 11),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.greenSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$messageCount msg${messageCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.greenDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full read-only thread for one conversation, shown as a large dialog so
/// admin never leaves the conversations list behind it.
class _ConversationThreadDialog extends ConsumerWidget {
  const _ConversationThreadDialog({
    required this.placementId,
    required this.jobTitle,
    required this.posterName,
    required this.seekerName,
  });

  final String placementId;
  final String jobTitle;
  final String posterName;
  final String seekerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncThread = ref.watch(_conversationThreadProvider(placementId));

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$posterName ↔ $seekerName',
                          style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.inkMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: asyncThread.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Could not load this conversation.',
                      style: TextStyle(color: AppColors.error)),
                ),
                data: (thread) {
                  final messages =
                      List<Map<String, dynamic>>.from(thread['messages'] as List<dynamic>);
                  if (messages.isEmpty) {
                    return Center(
                      child: Text('No messages yet.',
                          style: TextStyle(color: AppColors.inkMuted)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final senderRole = message['senderRole'] as String? ?? 'seeker';
    final isSeeker = senderRole == 'seeker';
    final body = message['body'] as String? ?? '';
    final createdAt = message['createdAt'] as String?;

    final bubbleColor = isSeeker ? AppColors.background : AppColors.greenSurface;
    final align = isSeeker ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final label = isSeeker ? 'Seeker' : (senderRole == 'agency' ? 'Agency' : 'Company');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.inkFaint, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(body, style: TextStyle(color: AppColors.ink, fontSize: 14)),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 3),
            Text(
              _formatConversationTimestamp(createdAt),
              style: TextStyle(color: AppColors.inkFaint, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
