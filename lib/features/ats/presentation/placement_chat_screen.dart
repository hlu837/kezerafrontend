import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../jobs/domain/placement.dart';
import '../../jobs/presentation/placement_status_badge.dart';
import '../data/ats_repository.dart';
import '../domain/message.dart';

/// Repository provider for the ATS/messaging feature. Lives here (rather
/// than a standalone `ats_provider.dart`) since this screen is currently
/// the feature's only consumer — same reasoning as keeping a screen and
/// its state in one file elsewhere in this codebase. Split it out the
/// moment a second screen needs `AtsRepository`.
///
/// Shared across roles: both the agency (`PlacementsScreen`) and the
/// employer (`EmployerMessagesScreen`) push this same screen for their
/// own placements — messaging is placement-scoped, not role-scoped (see
/// `utils/placementAccess.js#resolvePlacementForParticipant` — any
/// participant, poster or seeker, can read/write a thread regardless of
/// whether the poster is an employer or an agency).
final atsRepositoryProvider = Provider<AtsRepository>((ref) {
  return AtsRepository(ref.watch(apiClientProvider));
});

/// The message thread for a single placement.
///
/// Note on [placementStatus]: `AtsRepository` has no "get one placement"
/// endpoint — status only ever comes back joined onto other resources
/// (e.g. `SuggestedSeeker`, `PlacementRow`). Whoever pushes this screen
/// already has that row in hand, so it's passed in here rather than
/// re-fetched. If it's omitted the badge in the AppBar is simply hidden.
class PlacementChatScreen extends ConsumerStatefulWidget {
  const PlacementChatScreen({
    super.key,
    required this.placementId,
    required this.candidateName,
    this.placementStatus,
  });

  final String placementId;
  final String candidateName;
  final PlacementStatus? placementStatus;

  @override
  ConsumerState<PlacementChatScreen> createState() =>
      _PlacementChatScreenState();
}

class _PlacementChatScreenState extends ConsumerState<PlacementChatScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();

  List<Message> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// Shared by the initial load and pull-to-refresh — [RefreshIndicator]
  /// needs the returned future to resolve either way, so this doesn't
  /// short-circuit differently for the two call sites.
  Future<void> _loadMessages() async {
    if (_messages.isEmpty) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final messages = await ref
          .read(atsRepositoryProvider)
          .getMessages(widget.placementId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _loadError = null;
      });
      _scrollToBottom(animate: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load messages.';
      });
    }
  }

  Future<void> _handleSend() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final sent = await ref
          .read(atsRepositoryProvider)
          .sendMessage(widget.placementId, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _sending = false;
      });
      _inputController.clear();
      // Keep the keyboard open so a rapid back-and-forth doesn't require
      // re-tapping the field after every send.
      _inputFocusNode.requestFocus();
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnack('Message failed to send. Try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom({bool animate = true}) {
    // Wait a frame so the new bubble/list is actually laid out before we
    // measure maxScrollExtent — jumping/animating in the same frame the
    // item was inserted can under-scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.candidateName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.placementStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child:
                    PlacementStatusBadgeWidget(status: widget.placementStatus!),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(currentUserId)),
            _MessageInputBar(
              controller: _inputController,
              focusNode: _inputFocusNode,
              sending: _sending,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String? currentUserId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _messages.isEmpty) {
      return _ErrorState(message: _loadError!, onRetry: _loadMessages);
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: _messages.isEmpty
          ? ListView(
              // RefreshIndicator's pull gesture needs a scrollable child
              // even when there's nothing to show yet.
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 72),
                  child: _EmptyState(),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine =
                    currentUserId != null && message.senderId == currentUserId;
                final showDateDivider = index == 0 ||
                    !_isSameDay(
                      _messages[index - 1].createdAt,
                      message.createdAt,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDateDivider) _DateDivider(date: message.createdAt),
                    _MessageBubble(message: message, isMine: isMine),
                  ],
                );
              },
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor = isMine ? AppColors.green : AppColors.surface;
    final textColor = isMine ? Colors.white : AppColors.ink;
    final timeColor = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.inkFaint;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: isMine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMine ? 14 : 2),
              bottomRight: Radius.circular(isMine ? 2 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.body,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: timeColor,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isUnread ? Icons.done : Icons.done_all,
                      size: 13,
                      color: timeColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: 5000,
                textInputAction: TextInputAction.newline,
                enabled: !sending,
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(sending: sending, onPressed: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onPressed});

  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.green,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: sending ? null : onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            _formatDateLabel(date),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Send the first message to start the conversation about this '
              'placement.',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 36,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// No `intl` dependency in this project (see pubspec.yaml), so these are
/// hand-rolled rather than pulled in just for chat timestamps.
String _formatTime(DateTime utc) {
  final dt = utc.toLocal();
  final hour24 = dt.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

String _formatDateLabel(DateTime utc) {
  final dt = utc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
