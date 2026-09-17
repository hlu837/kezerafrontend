import 'package:flutter/material.dart';

import '../../../core/widgets/language_switcher_button.dart';
import '../../../core/widgets/responsive_shell.dart';
import '../../notifications/presentation/notifications_bell_button.dart';

/// Mostly mirrors the web backoffice's `AGENCY_NAV`. The "Registration"
/// tab (`AgencyRegistrationScreen`) combines the walk-in form with the
/// resulting roster (`GET /agencies/candidates`) as two sub-tabs —
/// register a candidate, then see them under "Registered" — rather than
/// splitting registration and the roster across separate nav items.
///
/// "Candidates" is a separate, later addition: the platform-wide
/// hiring-pool search (`GET /seekers/search`, shared with
/// `EmployerNavItems`'s own "Candidates" tab via `CandidatesScreen`) —
/// every available seeker on Kezera, not just this agency's own
/// roster. Distinct from "Registration"'s roster in the same way an
/// employer's "Candidates" tab is distinct from an agency's roster: one
/// is "everyone I could reach out to", the other is "who I've actually
/// registered/placed".
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
    label: 'Post a Job',
    path: '/agency/jobs/new',
    icon: Icons.add_circle_outline,
  ),
  ShellNavItem(
    label: 'Candidates',
    path: '/agency/candidates',
    icon: Icons.people_outline,
  ),
  ShellNavItem(
    label: 'Placements',
    path: '/agency/placements',
    icon: Icons.assignment_turned_in_outlined,
  ),
  ShellNavItem(
    label: 'Commission',
    path: '/agency/commission',
    icon: Icons.account_balance_wallet_outlined,
  ),
  ShellNavItem(
    label: 'Account',
    path: '/agency/account',
    icon: Icons.person_outline,
  ),
];

const agencyBrandLabel = 'Agency Backoffice';

/// Agency previously had no header actions at all, which meant no way
/// to see in-app notifications despite the backend already writing
/// `new_message` rows for agencies (they're a valid placement
/// participant — see `messaging.service.js#sendMessage`'s
/// `senderRole`/`job.creatorType` handling) as well as verification and
/// account-status notifications. Mirrors `seekerHeaderActions`/
/// `employerHeaderActions`.
const agencyHeaderActions = [
  NotificationsBellButton(),
  LanguageSwitcherButton(),
];
