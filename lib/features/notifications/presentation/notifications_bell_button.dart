import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_provider.dart';
import 'notifications_screen.dart';

/// The bell icon + unread-count badge used in every role's header
/// actions (seeker, employer, agency). Previously duplicated as a
/// private `_NotificationsButton` in each shell file — pulled out here
/// so agency (which had no bell at all) gets the same behavior as
/// seeker/employer for free, and so there's one place to fix if the
/// unread-badge logic ever needs to change.
class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return IconButton(
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ).then((_) => ref.invalidate(unreadNotificationsCountProvider)),
    );
  }
}
