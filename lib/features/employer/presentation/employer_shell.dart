import 'package:flutter/material.dart';

import '../../../core/widgets/responsive_shell.dart';

/// Mirrors the web backoffice's `EMPLOYER_NAV` 1:1 so both surfaces offer
/// the same navigation, just rendered as a sidebar (web) or bottom nav
/// (mobile) by [ResponsiveShell].
const employerNavItems = [
  ShellNavItem(
    label: 'Dashboard',
    path: '/employer/dashboard',
    icon: Icons.dashboard_outlined,
  ),
  ShellNavItem(
    label: 'Post a Job',
    path: '/employer/jobs/new',
    icon: Icons.add_circle_outline,
  ),
  ShellNavItem(
    label: 'Candidates',
    path: '/employer/candidates',
    icon: Icons.people_outline,
  ),
  ShellNavItem(
    label: 'Messages',
    path: '/employer/messages',
    icon: Icons.chat_bubble_outline,
  ),
];

const employerBrandLabel = 'Employer Backoffice';
