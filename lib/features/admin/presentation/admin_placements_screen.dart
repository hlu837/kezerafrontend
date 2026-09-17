import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

String _titleCase(String s) => s.isEmpty
    ? s
    : s
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

String _formatDate(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

String _birr(num amount) => '${amount.toStringAsFixed(2)} ETB';

// ---------------------------------------------------------------------------
// Placements tab — providers
// ---------------------------------------------------------------------------

class _PlacementsQuery extends Equatable {
  const _PlacementsQuery({this.status});

  final String? status;

  @override
  List<Object?> get props => [status];
}

/// GET /admin/placements?status=&limit=100 — every row in the
/// matching-engine/agency-dispatch pipeline, platform-wide, read-only.
final _placementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _PlacementsQuery>((ref, query) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/placements',
    queryParameters: {
      if (query.status != null) 'status': query.status,
      'limit': 100,
    },
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['placements'] as List<dynamic>);
});

// ---------------------------------------------------------------------------
// Financial ledger tab — providers
// ---------------------------------------------------------------------------

class _LedgerQuery extends Equatable {
  const _LedgerQuery({this.transactionType});

  final String? transactionType;

  @override
  List<Object?> get props => [transactionType];
}

/// GET /admin/agency-ledger?transaction_type=&limit=100 — every
/// AgencyFinancial entry across every agency, read-only. There is no
/// per-agency equivalent of this listing today (an agency's own
/// commission screen only ever writes entries and shows aggregated
/// stats) — this is admin's one place to see the raw entries.
final _ledgerProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _LedgerQuery>((ref, query) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/agency-ledger',
    queryParameters: {
      if (query.transactionType != null) 'transaction_type': query.transactionType,
      'limit': 100,
    },
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['entries'] as List<dynamic>);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/placements` sidebar destination —
/// platform-wide, read-only oversight of the matching-engine/agency-
/// dispatch pipeline (Placements tab) and the agency financial ledger
/// behind it (Financial Ledger tab). Deliberately view-only — see
/// admin.service.js#listAllPlacementsForAdmin's doc comment for why
/// admin doesn't drive placement status transitions from here. Same
/// dark container/card styling as the rest of this admin section.
class AdminPlacementsScreen extends ConsumerStatefulWidget {
  const AdminPlacementsScreen({super.key});

  @override
  ConsumerState<AdminPlacementsScreen> createState() => _AdminPlacementsScreenState();
}

class _AdminPlacementsScreenState extends ConsumerState<AdminPlacementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Placements',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform-wide oversight of agency-brokered placements and financials. '
                  'Read-only — for oversight, not to drive the pipeline.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF7B8CDE),
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFF7B8CDE),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Placements'),
                    Tab(text: 'Financial Ledger'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [_PlacementsTab(), _LedgerTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placements tab
// ---------------------------------------------------------------------------

class _PlacementsTab extends ConsumerStatefulWidget {
  const _PlacementsTab();

  @override
  ConsumerState<_PlacementsTab> createState() => _PlacementsTabState();
}

class _PlacementsTabState extends ConsumerState<_PlacementsTab> {
  String? _status;

  static const _statuses = [null, 'matched', 'sent', 'interviewed', 'hired', 'rejected'];

  @override
  Widget build(BuildContext context) {
    final asyncPlacements = ref.watch(_placementsProvider(_PlacementsQuery(status: _status)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final status = _statuses[i];
                final selected = status == _status;
                return ChoiceChip(
                  label: Text(status == null ? 'All' : _titleCase(status)),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = status),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1A1A2E),
                  selectedColor: const Color(0xFF7B8CDE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: asyncPlacements.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7B8CDE))),
            error: (err, _) => Center(
              child: Text(err.toString(), style: const TextStyle(color: Colors.red)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text('No placements found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _PlacementCard(data: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlacementCard extends StatelessWidget {
  const _PlacementCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'matched';
    final jobTitle = data['jobTitle'] as String? ?? 'Unknown job';
    final seekerName = data['seekerName'] as String? ?? 'Unknown';
    final agencyName = data['agencyName'] as String?;
    final employerName = data['employerName'] as String?;
    final score = data['score'] as num?;
    final createdAt = data['createdAt'] as String?;

    final Color badgeBg;
    final Color badgeFg;
    switch (status) {
      case 'hired':
        badgeBg = const Color(0xFF1A3A1A);
        badgeFg = const Color(0xFF81C784);
        break;
      case 'rejected':
        badgeBg = const Color(0xFF3A1A1A);
        badgeFg = const Color(0xFFE57373);
        break;
      case 'interviewed':
        badgeBg = const Color(0xFF1A2A3A);
        badgeFg = const Color(0xFF7BA8DE);
        break;
      case 'sent':
        badgeBg = const Color(0xFF2A2A1A);
        badgeFg = const Color(0xFFE0C36A);
        break;
      default: // matched
        badgeBg = const Color(0xFF22222E);
        badgeFg = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _titleCase(status),
                  style: TextStyle(color: badgeFg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  jobTitle,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _InfoItem(label: 'Candidate', value: seekerName),
              _InfoItem(
                label: agencyName != null ? 'Agency' : 'Employer',
                value: agencyName ?? employerName ?? 'Unknown',
              ),
              if (score != null) _InfoItem(label: 'Match score', value: '${(score * 100).round()}%'),
              _InfoItem(label: 'Created', value: _formatDate(createdAt)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Financial ledger tab
// ---------------------------------------------------------------------------

class _LedgerTab extends ConsumerStatefulWidget {
  const _LedgerTab();

  @override
  ConsumerState<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<_LedgerTab> {
  String? _type;

  static const _types = [null, 'registration_fee', 'commission'];

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(_ledgerProvider(_LedgerQuery(transactionType: _type)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final type = _types[i];
                final selected = type == _type;
                return ChoiceChip(
                  label: Text(type == null ? 'All' : _titleCase(type)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = type),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1A1A2E),
                  selectedColor: const Color(0xFF7B8CDE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: asyncEntries.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7B8CDE))),
            error: (err, _) => Center(
              child: Text(err.toString(), style: const TextStyle(color: Colors.red)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text('No ledger entries found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                    ],
                  ),
                );
              }
              final total = items.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      'Total shown: ${_birr(total)} across ${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _LedgerCard(data: items[i]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final type = data['transactionType'] as String? ?? 'commission';
    final isCommission = type == 'commission';
    final agencyName = data['agencyName'] as String? ?? 'Unknown agency';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final description = data['description'] as String?;
    final date = data['date'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCommission ? const Color(0xFF1A3A1A) : const Color(0xFF1A2A3A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCommission ? Icons.percent : Icons.badge_outlined,
              color: isCommission ? const Color(0xFF81C784) : const Color(0xFF7BA8DE),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agencyName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_titleCase(type)}${description != null && description.isNotEmpty ? ' · $description' : ''}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _birr(amount),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(_formatDate(date), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widget
// ---------------------------------------------------------------------------

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
