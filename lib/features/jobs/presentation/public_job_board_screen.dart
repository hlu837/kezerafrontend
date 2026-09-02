import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/board_mode_toggle.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../domain/job.dart';
import 'job_board_screen.dart';
import 'public_candidates_board_screen.dart';
import 'widgets/ad_carousel.dart';

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
/// - Home: the ad carousel plus the Jobs/Experts board (the original
///   all-in-one landing content).
/// - Jobs: just the job board, no ad banner, for a faster path straight
///   to searching (still hosts the Jobs/Experts toggle).
/// - Agency: placeholder for agency-partner content.
/// - Support: placeholder for help/contact content.
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
    // Was a static "Find your next job in Ethiopia" hero block; that's
    // now an ad slot instead — smaller, and self-advancing every couple
    // seconds like a normal ad carousel. Backed by mock cards
    // (see widgets/ad_carousel.dart) until there's a real sponsored
    // content feed to pull from. Shared by both the Jobs and Experts
    // sides of the toggle.
    final adBanner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppColors.surface,
      child: const AdCarousel(),
    );

    Widget body;
    switch (_tab) {
      case _LandingTab.home:
        body = _mode == BoardMode.jobs
            ? JobBoardScreen(
                isGuest: true,
                onApply: (job) => _promptSignUp(context, job),
                header: adBanner,
                titleTrailing: BoardModeToggle(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              )
            : PublicCandidatesBoardScreen(
                mode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
                header: adBanner,
              );
        break;
      case _LandingTab.jobs:
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
      case _LandingTab.agency:
        body = const ComingSoonScreen(title: 'Agency');
        break;
      case _LandingTab.support:
        body = const ComingSoonScreen(title: 'Support');
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
              'KezearaJobs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
        actions: [
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
