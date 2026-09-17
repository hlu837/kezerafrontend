import 'package:flutter/material.dart';

import '../../../core/widgets/language_switcher_button.dart';
import '../../../core/widgets/responsive_shell.dart';
import '../../notifications/presentation/notifications_bell_button.dart';

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
    label: 'Messages',
    path: '/seeker/messages',
    icon: Icons.chat_bubble_outline,
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
  NotificationsBellButton(),
  LanguageSwitcherButton(),
];
