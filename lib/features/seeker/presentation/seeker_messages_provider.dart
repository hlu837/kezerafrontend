import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ats/data/ats_repository.dart';
import '../../ats/domain/message.dart';
import '../../ats/presentation/placement_chat_screen.dart' show atsRepositoryProvider;
import '../../jobs/domain/placement.dart';
import '../data/seeker_profile_repository.dart';
import 'seeker_profile_provider.dart';

/// One entry in the seeker's chat inbox: a placement that has at least
/// one message in it, paired with the most recent message in that
/// thread — what the list screen actually needs to show a preview.
class ChatThread {
  const ChatThread({required this.placement, required this.lastMessage});

  final MyPlacement placement;
  final Message lastMessage;
}

/// The seeker's inbox: every placement thread that has at least one
/// message from either side, newest message first.
///
/// Built client-side by combining `GET /seekers/me/placements` with a
/// per-placement `GET /placements/:placementId/messages` call, since the
/// backend has no single "my conversations, with previews" endpoint —
/// same N+1 client-side aggregation `EmployerMessagesNotifier` already
/// does for the employer side (fetch the parent list, then fetch each
/// row's detail and flatten), just fetching messages instead of
/// suggested seekers.
///
/// Note: opening a thread's messages marks the other participant's
/// unread messages as read as a side effect
/// (`messaging.service.js#listMessages`), so loading this inbox reads
/// every thread — there's no way to show an "unread" badge here without
/// a dedicated preview endpoint that doesn't mark as read.
final seekerChatThreadsProvider = StateNotifierProvider<
    SeekerChatThreadsNotifier, AsyncValue<List<ChatThread>>>((ref) {
  return SeekerChatThreadsNotifier(
    seekerProfileRepository: ref.watch(seekerProfileRepositoryProvider),
    atsRepository: ref.watch(atsRepositoryProvider),
  )..load();
});

class SeekerChatThreadsNotifier
    extends StateNotifier<AsyncValue<List<ChatThread>>> {
  SeekerChatThreadsNotifier({
    required this.seekerProfileRepository,
    required this.atsRepository,
  }) : super(const AsyncValue.loading());

  final SeekerProfileRepository seekerProfileRepository;
  final AtsRepository atsRepository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final placements = await seekerProfileRepository.fetchMyPlacements();

      // Fetch each placement's messages independently rather than with a
      // plain Future.wait: a bare Future.wait fails the *entire* inbox
      // load if even one placement's request errors (e.g. a stale
      // placement whose job/seeker reference no longer resolves, a
      // one-off timeout) — surfacing "Failed to load messages" even
      // though every other thread loaded fine. Swallowing per-placement
      // failures here means one bad thread just doesn't show up, instead
      // of taking the whole tab down with it.
      final perPlacementMessages = await Future.wait([
        for (final placement in placements)
          atsRepository.getMessages(placement.placementId).catchError(
            (Object error, StackTrace stackTrace) {
              // ignore: avoid_print
              print(
                'seekerChatThreadsProvider: failed to load messages for '
                'placement ${placement.placementId}: $error',
              );
              return <Message>[];
            },
          ),
      ]);

      final threads = <ChatThread>[
        for (var i = 0; i < placements.length; i++)
          if (perPlacementMessages[i].isNotEmpty)
            ChatThread(
              placement: placements[i],
              lastMessage: perPlacementMessages[i].last,
            ),
      ]..sort(
          (a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt),
        );

      state = AsyncValue.data(threads);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
