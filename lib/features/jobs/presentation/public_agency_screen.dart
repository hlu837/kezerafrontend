import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../agency/domain/agency_comment.dart';
import '../../agency/presentation/agency_comments_provider.dart';
import '../../agency/presentation/agency_profile_screen.dart';

/// Public "Agency" bottom-nav tab on the landing page
/// (public_job_board_screen.dart) — the agency directory: every
/// approved, active agency on the platform, with the key stats a
/// visitor scans before drilling in (open roles, rating), and a card
/// tap into that agency's own public profile (`AgencyProfileScreen`),
/// which in turn lists that agency's specific open job postings. This
/// is guest-facing browse content, not the logged-in agency backoffice
/// (that's agency_shell.dart, a completely separate route tree behind
/// auth) — registration is still offered, just as a footer CTA rather
/// than the whole screen.
class PublicAgencyScreen extends ConsumerStatefulWidget {
  const PublicAgencyScreen({super.key});

  @override
  ConsumerState<PublicAgencyScreen> createState() => _PublicAgencyScreenState();
}

class _PublicAgencyScreenState extends ConsumerState<PublicAgencyScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Only rebuilds this screen to toggle the search field's clear
    // icon — the actual query re-fetch happens on submit/clear below,
    // not on every keystroke.
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(agencyDirectoryProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(agencyDirectoryProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Recruitment agencies',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Browse verified agencies partnered with Kezera and see what '
            "they're currently recruiting for.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/agencies/nearby'),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('View nearby agencies on map'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) =>
                ref.read(agencyDirectoryProvider.notifier).search(value),
            decoration: InputDecoration(
              hintText: 'Search by agency name or city',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(agencyDirectoryProvider.notifier).search('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 20),
          directoryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                error is ApiException ? error.message : 'Could not load agencies.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            data: (page) {
              if (page.agencies.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No agencies found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${page.total} agenc${page.total == 1 ? 'y' : 'ies'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkFaint,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final agency in page.agencies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AgencyCard(agency: agency),
                    ),
                  if (page.hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: () =>
                            ref.read(agencyDirectoryProvider.notifier).loadMore(),
                        child: const Text('Load more'),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _RegisterAgencyBanner(),
        ],
      ),
    );
  }
}

/// One row in the agency directory — logo, name, city, and the key
/// stats (open roles, rating) that motivate a tap into the full
/// profile. Tapping opens `AgencyProfileScreen`, whose own "Jobs"
/// section (`agencyJobsProvider`) is where the agency's specific
/// listings live — this card only shows the *count*, not the jobs
/// themselves, so the directory stays scannable.
class _AgencyCard extends StatelessWidget {
  const _AgencyCard({required this.agency});

  final AgencyDirectoryEntry agency;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AgencyProfileScreen(
            agencyId: agency.id,
            agencyName: agency.agencyName,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.greenSurface,
              backgroundImage: agency.logoUrl != null && agency.logoUrl!.isNotEmpty
                  ? NetworkImage(agency.logoUrl!)
                  : null,
              child: agency.logoUrl == null || agency.logoUrl!.isEmpty
                  ? Icon(Icons.groups_outlined, color: AppColors.greenDark)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agency.agencyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                  ),
                  if (agency.operationalCity != null &&
                      agency.operationalCity!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.inkFaint),
                        const SizedBox(width: 3),
                        Text(
                          agency.operationalCity!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkFaint,
                              ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatChip(
                        icon: Icons.work_outline,
                        label: '${agency.openJobsCount} open '
                            '${agency.openJobsCount == 1 ? 'role' : 'roles'}',
                      ),
                      if (agency.candidateCount > 0)
                        _StatChip(
                          icon: Icons.groups_outlined,
                          label: '${agency.candidateCount} '
                              '${agency.candidateCount == 1 ? 'candidate' : 'candidates'}',
                        ),
                      if (agency.yearsInBusiness != null && agency.yearsInBusiness! > 0)
                        _StatChip(
                          icon: Icons.calendar_today_outlined,
                          label: '${agency.yearsInBusiness} '
                              '${agency.yearsInBusiness == 1 ? 'year' : 'years'} in business',
                        ),
                      if (agency.averageRating != null)
                        _StatChip(
                          icon: Icons.star,
                          iconColor: Colors.amber,
                          label: '${agency.averageRating} · ${agency.commentsCount} '
                              '${agency.commentsCount == 1 ? 'review' : 'reviews'}',
                        )
                      else if (agency.commentsCount > 0)
                        _StatChip(
                          icon: Icons.chat_bubble_outline,
                          label: '${agency.commentsCount} '
                              '${agency.commentsCount == 1 ? 'comment' : 'comments'}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? AppColors.inkFaint),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}

/// Footer CTA into agency registration — the whole point of this
/// screen before the restructure; now a compact banner under the
/// directory rather than the entire tab.
class _RegisterAgencyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: AppColors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Run a recruitment agency?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Register candidates, submit them for open roles, and earn '
            'commission on every placement — all from one dashboard.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/register?role=agency'),
                  child: const Text('Register your agency'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Log in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
