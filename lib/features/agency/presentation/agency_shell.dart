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
    label: 'Walk-in Registration',
    path: '/agency/walk-in',
    icon: Icons.person_add_alt_outlined,
  ),
  ShellNavItem(
    label: 'Placements',
    path: '/agency/placements',
    icon: Icons.assignment_turned_in_outlined,
  ),
];

const agencyBrandLabel = 'Agency Backoffice';
