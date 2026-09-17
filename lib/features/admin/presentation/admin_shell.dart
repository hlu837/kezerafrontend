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
/// "Dashboard", "Verifications", "Conversations", "Subscriptions", "Users",
/// "Job Listings", "Placements", "SMS Logs", and "Reports" are all backed
/// by real endpoints today (see backend/src/controllers/admin.controller.js).
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
    label: 'Conversations',
    path: '/admin/conversations',
    icon: Icons.forum_outlined,
  ),
  ShellNavItem(
    label: 'Subscriptions',
    path: '/admin/subscriptions',
    icon: Icons.workspace_premium_outlined,
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
