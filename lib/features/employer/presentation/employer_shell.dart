import 'package:flutter/material.dart';

import '../../../core/widgets/language_switcher_button.dart';
import '../../../core/widgets/responsive_shell.dart';
import '../../notifications/presentation/notifications_bell_button.dart';

/// Mirrors the web backoffice's `EMPLOYER_NAV` 1:1 so both surfaces offer
/// the same navigation, just rendered as a sidebar (web) or bottom nav
/// (mobile) by [ResponsiveShell]. "Post a Job" is kept as the middle (3rd
/// of 5) item deliberately — it's the primary action, and the middle slot
/// is the most prominent position in a bottom nav bar.
const employerNavItems = [
  ShellNavItem(
    label: 'Dashboard',
    path: '/employer/dashboard',
    icon: Icons.dashboard_outlined,
  ),
  ShellNavItem(
    label: 'Candidates',
    path: '/employer/candidates',
    icon: Icons.people_outline,
  ),
  ShellNavItem(
    label: 'Post a Job',
    path: '/employer/jobs/new',
    icon: Icons.add_circle_outline,
  ),
  ShellNavItem(
    label: 'Messages',
    path: '/employer/messages',
    icon: Icons.chat_bubble_outline,
  ),
  ShellNavItem(
    label: 'Account',
    path: '/employer/account',
    icon: Icons.person_outline,
  ),
];

const employerBrandLabel = 'Employer Backoffice';

/// Narrow-screen app bar icons for the employer role, shown where the
/// logout icon used to sit (sign out now lives on the "Account" tab
/// instead — see `EmployerAccountScreen`). Mirrors `seekerHeaderActions`.
const employerHeaderActions = [
  NotificationsBellButton(),
  LanguageSwitcherButton(),
];
