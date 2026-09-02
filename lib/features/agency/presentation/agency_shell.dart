import 'package:flutter/material.dart';

import '../../../core/widgets/responsive_shell.dart';

/// Mirrors the web backoffice's `AGENCY_NAV` 1:1.
const agencyNavItems = [
  ShellNavItem(
    label: 'Dashboard',
    path: '/agency/dashboard',
    icon: Icons.dashboard_outlined,
  ),
  ShellNavItem(
    label: 'Registration',
    path: '/agency/walk-in',
    icon: Icons.person_add_alt_outlined,
  ),
  ShellNavItem(
    label: 'Placements',
    path: '/agency/placements',
    icon: Icons.assignment_turned_in_outlined,
  ),
  ShellNavItem(
    label: 'Account',
    path: '/agency/account',
    icon: Icons.person_outline,
  ),
];

const agencyBrandLabel = 'Agency Backoffice';
