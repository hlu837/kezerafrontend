import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/expert_trade_category.dart';
import '../domain/seeker.dart';
import 'expert_categories_provider.dart';

/// "Experts" directory — the landing page for browsing skilled trade
/// workers (electricians, plumbers, ...) by category rather than by
/// map/radius straight away. Each card shows a trade with a live count
/// of currently-available experts (`GET /seekers/trade-categories`, see
/// [expertCategoryCountsProvider]); tapping one jumps into
/// [NearbyExpertsMapScreen] pre-filtered to that trade
/// (`/experts/nearby?trade=...`, wired in app_router.dart), where the
/// person can view results as a map or list and adjust the trade/radius
/// filter further.
///
/// Reachable from the guest landing page's "Experts" tab (see
/// public_candidates_board_screen.dart's "Browse experts by category"
/// button) — no auth, same guest-preview contract as the rest of that
/// tab.
class ExpertCategoriesScreen extends ConsumerWidget {
  const ExpertCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(expertCategoryCountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Experts')),
      body: counts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.invalidate(expertCategoryCountsProvider),
        ),
        data: (categories) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 190,
            child: _CategoryList(categories: categories),
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<ExpertCategoryCount> categories;

  @override
  Widget build(BuildContext context) {
    // Server-provided counts keyed by category, so a trade the backend
    // hasn't returned yet (shouldn't happen — every taxonomy key is
    // always included) still renders with a 0 count instead of being
    // silently dropped from the list.
    final countByKey = {for (final c in categories) c.key: c.count};

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: kExpertTradeCategories.length,
      itemBuilder: (context, index) {
        final trade = kExpertTradeCategories[index];
        final count = countByKey[trade.key] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            width: 160,
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/experts/nearby?trade=${trade.key}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.greenSurface,
                        child: Icon(trade.icon, color: AppColors.greenDark),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        trade.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('$count available'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load expert categories.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
