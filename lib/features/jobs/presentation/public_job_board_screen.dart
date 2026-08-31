import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/job.dart';
import 'job_board_screen.dart';
import 'widgets/ad_carousel.dart';

/// Public landing page — the app's `initialLocation`. Anyone can browse
/// and search the open job list here without an account (GET /jobs never
/// needed a token; the old flow just never let a guest reach the screen
/// that calls it). Tapping "Apply" on a job is the one thing that's
/// gated: it sends guests to `/register` instead of letting them apply
/// anonymously.
class PublicJobBoardScreen extends StatelessWidget {
  const PublicJobBoardScreen({super.key});

  void _promptSignUp(BuildContext context, Job job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Create a free account to apply for "${job.title}".')),
    );
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
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
      body: JobBoardScreen(
        isGuest: true,
        onApply: (job) => _promptSignUp(context, job),
        // Was a static "Find your next job in Ethiopia" hero block; that's
        // now an ad slot instead — smaller, and self-advancing every couple
        // seconds like a normal ad carousel. Backed by mock cards
        // (see widgets/ad_carousel.dart) until there's a real sponsored
        // content feed to pull from.
        header: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: AppColors.surface,
          child: const AdCarousel(),
        ),
      ),
    );
  }
}
