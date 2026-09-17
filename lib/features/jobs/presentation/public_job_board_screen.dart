import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/board_mode_toggle.dart';
import '../../../core/widgets/language_switcher_button.dart';
import '../domain/job.dart';
import 'job_board_screen.dart';
import 'public_agency_screen.dart';
import 'public_candidates_board_screen.dart';
import 'public_support_screen.dart';

/// The four bottom-nav destinations on the public landing page.
enum _LandingTab { home, jobs, agency, support }

/// Public landing page — the app's `initialLocation`. Anyone can browse
/// and search the open job list here without an account (GET /jobs never
/// needed a token; the old flow just never let a guest reach the screen
/// that calls it). Tapping "Apply" on a job is the one thing that's
/// gated: it sends guests to `/register` instead of letting them apply
/// anonymously.
///
/// A bottom nav bar (Home / Jobs / Agency / Support) switches between:
/// - Home: the full search filter card, then the Jobs/Experts board
///   (the original all-in-one landing content).
/// - Jobs: just the job board and its filter card, for a
///   faster path straight to searching. Jobs-only — no Jobs/Experts
///   toggle here (that lives on Home instead), since this tab's whole
///   point is a fast, single-purpose path to the job list.
/// - Agency: the public agency directory — every approved agency with
///   key stats (open roles, rating), each card linking into that
///   agency's profile and specific job listings, plus a CTA into
///   agency registration for agencies considering partnering.
/// - Support: FAQ plus a contact-support email link.
class PublicJobBoardScreen extends StatefulWidget {
  const PublicJobBoardScreen({super.key});

  @override
  State<PublicJobBoardScreen> createState() => _PublicJobBoardScreenState();
}

class _PublicJobBoardScreenState extends State<PublicJobBoardScreen> {
  BoardMode _mode = BoardMode.jobs;
  _LandingTab _tab = _LandingTab.home;

  void _promptSignUp(BuildContext context, Job job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Create a free account to apply for "${job.title}".')),
    );
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_tab) {
      case _LandingTab.home:
        body = _mode == BoardMode.jobs
            ? JobBoardScreen(
                isGuest: true,
                onApply: (job) => _promptSignUp(context, job),
                titleTrailing: BoardModeToggle(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              )
            : PublicCandidatesBoardScreen(
                mode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
              );
        break;
      case _LandingTab.jobs:
        // Jobs-only — no BoardModeToggle/titleTrailing here (see class
        // doc comment), so this ignores `_mode` entirely rather than
        // showing the Experts board if a guest happened to leave Home
        // in Experts mode.
        body = JobBoardScreen(
          isGuest: true,
          onApply: (job) => _promptSignUp(context, job),
        );
        break;
      case _LandingTab.agency:
        body = const PublicAgencyScreen();
        break;
      case _LandingTab.support:
        body = const PublicSupportScreen();
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 24,
        title: Row(
          children: [
            Icon(Icons.work_rounded, color: AppColors.green),
            const SizedBox(width: 8),
            Text(
              'Kezera',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
        actions: [
          const LanguageSwitcherButton(),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Log in'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/register'),
            child: const Text('Sign up'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _LandingTab.values.indexOf(_tab),
        onDestinationSelected: (index) =>
            setState(() => _tab = _LandingTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Agency',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}
