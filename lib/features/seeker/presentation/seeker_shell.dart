import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/responsive_shell.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../notifications/presentation/notifications_screen.dart';

/// Nav destinations for the seeker role — shows up in both the sidebar
/// (web) and bottom nav (mobile) automatically.
const seekerNavItems = [
  ShellNavItem(
    label: 'Dashboard',
    path: '/seeker/dashboard',
    icon: Icons.dashboard_outlined,
  ),
  ShellNavItem(
    label: 'Find jobs',
    path: '/seeker/jobs',
    icon: Icons.badge_outlined,
  ),
  ShellNavItem(
    label: 'My Applications',
    path: '/seeker/applications',
    icon: Icons.assignment_turned_in_outlined,
  ),
  ShellNavItem(
    label: 'Account',
    path: '/seeker/account',
    icon: Icons.person_outline,
  ),
];

const seekerBrandLabel = 'Job Seeker';

/// Narrow-screen app bar icons for the seeker role, shown where the
/// logout icon used to sit (sign out now lives on the "Account" tab
/// instead — see `SeekerAccountScreen`).
///
/// NOTIF-01: `_NotificationsButton` now opens the real in-app feed
/// (`NotificationsScreen`, backed by `GET /notifications`) instead of
/// the static "coming soon" bottom sheet this used to show.
const seekerHeaderActions = [
  _NotificationsButton(),
  _LanguageButton(),
];

class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton();

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
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ).then((_) => ref.invalidate(unreadNotificationsCountProvider)),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language_outlined),
      tooltip: 'Language',
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'am', child: Text('አማርኛ (Amharic)')),
      ],
      onSelected: (value) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('More languages are coming soon.')),
      ),
    );
  }
}
