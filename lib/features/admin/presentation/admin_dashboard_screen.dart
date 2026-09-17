import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_provider.dart';

/// Pending-verification count for the overview card below. Reuses the same
/// `/admin/verifications` endpoint the Verifications page calls, since it
/// already returns exactly this count as a side effect of listing them.
final _pendingVerificationsCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/verifications',
    queryParameters: {'status': 'pending'},
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return (data['verifications'] as List<dynamic>).length;
});

/// The stat cards backed by `GET /admin/stats`
/// (admin.service.js#getPlatformStats). Used to be hardcoded `'—'`
/// placeholders with a "coming soon" note; the endpoint now exists.
class _PlatformStats {
  const _PlatformStats({
    required this.seekerCount,
    required this.employerAgencyCount,
    required this.activeJobListings,
    required this.placementsThisMonth,
  });

  final int seekerCount;
  final int employerAgencyCount;
  final int activeJobListings;
  final int placementsThisMonth;

  factory _PlatformStats.fromJson(Map<String, dynamic> json) => _PlatformStats(
        seekerCount: json['seekerCount'] as int,
        employerAgencyCount: json['employerAgencyCount'] as int,
        activeJobListings: json['activeJobListings'] as int,
        placementsThisMonth: json['placementsThisMonth'] as int,
      );
}

final _platformStatsProvider = FutureProvider<_PlatformStats>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>('/admin/stats');
  return _PlatformStats.fromJson(response.data!['data'] as Map<String, dynamic>);
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_pendingVerificationsCountProvider);
    final statsAsync = ref.watch(_platformStatsProvider);

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
                _StatCard(
                  label: 'Seekers',
                  value: statsAsync.when(
                    data: (stats) => '${stats.seekerCount}',
                    loading: () => '…',
                    error: (_, __) => '—',
                  ),
                  icon: Icons.person_outline,
                ),
                _StatCard(
                  label: 'Employers & Agencies',
                  value: statsAsync.when(
                    data: (stats) => '${stats.employerAgencyCount}',
                    loading: () => '…',
                    error: (_, __) => '—',
                  ),
                  icon: Icons.business_center_outlined,
                ),
                _StatCard(
                  label: 'Active Job Listings',
                  value: statsAsync.when(
                    data: (stats) => '${stats.activeJobListings}',
                    loading: () => '…',
                    error: (_, __) => '—',
                  ),
                  icon: Icons.work_outline,
                ),
                _StatCard(
                  label: 'Placements This Month',
                  value: statsAsync.when(
                    data: (stats) => '${stats.placementsThisMonth}',
                    loading: () => '…',
                    error: (_, __) => '—',
                  ),
                  icon: Icons.assignment_turned_in_outlined,
                ),
              ],
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
