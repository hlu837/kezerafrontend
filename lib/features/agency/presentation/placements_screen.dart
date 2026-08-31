import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../jobs/domain/placement.dart';
import '../../jobs/presentation/placement_status_badge.dart';
import '../../ats/presentation/placement_chat_screen.dart';
import 'agency_provider.dart';

const _statusTabs = <(PlacementStatus?, String)>[
  (null, 'All'),
  (PlacementStatus.matched, 'Matched'),
  (PlacementStatus.sent, 'Sent'),
  (PlacementStatus.interviewed, 'Interviewed'),
  (PlacementStatus.hired, 'Hired'),
  (PlacementStatus.rejected, 'Rejected'),
];

/// Mirrors `web-backoffice/src/app/agency/placements/page.tsx` — status
/// tabs over the flattened suggested-seekers-per-job list, with a
/// one-tap "Dispatch" action on rows still in the `matched` state.
class PlacementsScreen extends ConsumerStatefulWidget {
  const PlacementsScreen({super.key});

  @override
  ConsumerState<PlacementsScreen> createState() => _PlacementsScreenState();
}

class _PlacementsScreenState extends ConsumerState<PlacementsScreen> {
  PlacementStatus? _activeTab;
  String? _dispatchingPlacementId;
  String? _updatingPlacementId;
  String? _error;

  Future<void> _handleDispatch(SuggestedSeeker row) async {
    setState(() {
      _dispatchingPlacementId = row.placementId;
      _error = null;
    });
    try {
      await ref.read(placementsProvider.notifier).dispatch(row);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to dispatch candidate.');
    } finally {
      if (mounted) setState(() => _dispatchingPlacementId = null);
    }
  }

  Future<void> _handleStatusUpdate(
    SuggestedSeeker row,
    PlacementStatus newStatus,
  ) async {
    setState(() {
      _updatingPlacementId = row.placementId;
      _error = null;
    });
    try {
      await ref.read(placementsProvider.notifier).updateStatus(row, newStatus);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to update placement status.');
    } finally {
      if (mounted) setState(() => _updatingPlacementId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placementsAsync = ref.watch(placementsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(placementsProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Placement pipeline', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Candidates matched to jobs your agency has posted.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          placementsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Failed to load placements.',
              onRetry: () => ref.read(placementsProvider.notifier).load(),
            ),
            data: (rows) => _PlacementsBody(
              rows: rows,
              activeTab: _activeTab,
              onTabSelected: (tab) => setState(() => _activeTab = tab),
              dispatchingPlacementId: _dispatchingPlacementId,
              onDispatch: _handleDispatch,
              updatingPlacementId: _updatingPlacementId,
              onStatusUpdate: _handleStatusUpdate,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementsBody extends StatelessWidget {
  const _PlacementsBody({
    required this.rows,
    required this.activeTab,
    required this.onTabSelected,
    required this.dispatchingPlacementId,
    required this.onDispatch,
    required this.updatingPlacementId,
    required this.onStatusUpdate,
  });

  final List<SuggestedSeeker> rows;
  final PlacementStatus? activeTab;
  final ValueChanged<PlacementStatus?> onTabSelected;
  final String? dispatchingPlacementId;
  final ValueChanged<SuggestedSeeker> onDispatch;
  final String? updatingPlacementId;
  final void Function(SuggestedSeeker row, PlacementStatus newStatus) onStatusUpdate;

  @override
  Widget build(BuildContext context) {
    final counts = <PlacementStatus, int>{
      for (final status in PlacementStatus.values) status: 0,
    };
    for (final row in rows) {
      counts[row.status] = (counts[row.status] ?? 0) + 1;
    }

    final visibleRows = activeTab == null
        ? rows
        : rows.where((r) => r.status == activeTab).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (status, label) in _statusTabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      status == null ? label : '$label (${counts[status]})',
                    ),
                    selected: activeTab == status,
                    onSelected: (_) => onTabSelected(status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (visibleRows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: _EmptyState(),
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < visibleRows.length; index++)
                  _PlacementRow(
                    row: visibleRows[index],
                    isDispatching:
                        dispatchingPlacementId == visibleRows[index].placementId,
                    onDispatch: () => onDispatch(visibleRows[index]),
                    isUpdating:
                        updatingPlacementId == visibleRows[index].placementId,
                    onStatusUpdate: (newStatus) =>
                        onStatusUpdate(visibleRows[index], newStatus),
                    showDivider: index != visibleRows.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlacementRow extends StatelessWidget {
  const _PlacementRow({
    required this.row,
    required this.isDispatching,
    required this.onDispatch,
    required this.isUpdating,
    required this.onStatusUpdate,
    required this.showDivider,
  });

  final SuggestedSeeker row;
  final bool isDispatching;
  final VoidCallback onDispatch;
  final bool isUpdating;
  final ValueChanged<PlacementStatus> onStatusUpdate;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fullName ?? 'Unnamed candidate',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      row.city ?? 'City unknown',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              PlacementStatusBadgeWidget(status: row.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.jobTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (row.skills.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in row.skills.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                row.score != null
                    ? 'Match ${(row.score! * 100).toStringAsFixed(0)}%'
                    : 'Match —',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (row.status == PlacementStatus.matched)
                FilledButton(
                  onPressed: isDispatching ? null : onDispatch,
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(isDispatching ? 'Dispatching…' : 'Dispatch'),
                )
              else if (row.status == PlacementStatus.sent ||
                  row.status == PlacementStatus.interviewed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Message ${row.fullName ?? 'candidate'}',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlacementChatScreen(
                              placementId: row.placementId,
                              candidateName: row.fullName ?? 'Candidate',
                              placementStatus: row.status,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: isUpdating
                          ? null
                          : () => onStatusUpdate(PlacementStatus.rejected),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: isUpdating
                          ? null
                          : () => onStatusUpdate(
                                row.status == PlacementStatus.sent
                                    ? PlacementStatus.interviewed
                                    : PlacementStatus.hired,
                              ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isUpdating
                            ? 'Updating…'
                            : row.status == PlacementStatus.sent
                                ? 'Mark Interviewed'
                                : 'Mark Hired',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (showDivider) const Divider(height: 24),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'No placements here',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Post a job and let matching run, or dispatch from the '
              'Matched tab once candidates are found.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
