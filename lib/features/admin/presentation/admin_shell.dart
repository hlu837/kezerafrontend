import 'package:flutter/material.dart';

import '../../../core/widgets/responsive_shell.dart';

/// Nav destinations for the `admin` role's own backoffice surface.
///
/// Previously `admin` had no UI of its own and was routed into the agency
/// shell (see the now-removed `UserRole.admin => agencyNavItems` branch in
/// app_router.dart) since the backend grants it agency-equivalent access.
/// This gives admin a dedicated sidebar instead, scoped to the
/// platform-oversight surfaces an admin actually needs day to day.
///
/// Only "Dashboard" and "Verifications" are backed by real endpoints today
/// (see backend/src/controllers/admin.controller.js). The rest are wired
/// into routing/navigation now so the shape of the admin panel is settled,
/// with their screens showing a "coming soon" placeholder until the
/// matching backend endpoints exist.
const adminNavItems = [
  ShellNavItem(
    label: 'Dashboard',
    path: '/admin/dashboard',
    icon: Icons.dashboard_outlined,
  ),
  ShellNavItem(
    label: 'Verifications',
    path: '/admin/verifications',
    icon: Icons.verified_outlined,
  ),
  ShellNavItem(
    label: 'Users',
    path: '/admin/users',
    icon: Icons.people_alt_outlined,
  ),
  ShellNavItem(
    label: 'Job Listings',
    path: '/admin/jobs',
    icon: Icons.work_outline,
  ),
  ShellNavItem(
    label: 'Placements',
    path: '/admin/placements',
    icon: Icons.assignment_turned_in_outlined,
  ),
  ShellNavItem(
    label: 'SMS Logs',
    path: '/admin/sms-logs',
    icon: Icons.sms_outlined,
  ),
  ShellNavItem(
    label: 'Reports',
    path: '/admin/reports',
    icon: Icons.insights_outlined,
  ),
];

const adminBrandLabel = 'Admin Panel';
