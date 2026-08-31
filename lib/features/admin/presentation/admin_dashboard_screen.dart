import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_provider.dart';

/// Pending-verification count for the overview card below. Reuses the same
/// `/admin/verifications` endpoint the Verifications page calls — there's
/// no separate stats endpoint yet, so this is the one real number we can
/// show on the dashboard today.
final _pendingVerificationsCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/verifications',
    queryParameters: {'status': 'pending'},
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return (data['verifications'] as List<dynamic>).length;
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_pendingVerificationsCountProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Platform-wide oversight: verifications, users, listings, '
              'and activity.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  label: 'Pending Verifications',
                  value: pendingAsync.when(
                    data: (count) => '$count',
                    loading: () => '…',
                    error: (_, __) => '—',
                  ),
                  icon: Icons.verified_outlined,
                  onTap: () => context.go('/admin/verifications'),
                ),
                const _StatCard(
                  label: 'Total Users',
                  value: '—',
                  icon: Icons.people_alt_outlined,
                ),
                const _StatCard(
                  label: 'Active Job Listings',
                  value: '—',
                  icon: Icons.work_outline,
                ),
                const _StatCard(
                  label: 'Placements This Month',
                  value: '—',
                  icon: Icons.assignment_turned_in_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coming soon',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'User/job/placement counts, SMS delivery health, and '
                      'revenue reporting will populate here once their '
                      'backend endpoints are built out. Verifications '
                      '(above) is already live — approve or reject '
                      'employer/agency accounts from the Verifications tab.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
