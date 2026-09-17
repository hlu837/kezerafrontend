import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Query params for [_smsLogsProvider] — matched/unmatched tab plus whatever's
/// currently in the search box. Equatable so `.family` only refetches when
/// one of the two actually changes, same convention as
/// admin_jobs_screen.dart's `_JobsQuery`.
class _SmsLogsQuery extends Equatable {
  const _SmsLogsQuery({this.matched, this.search = ''});

  /// null = "All", true = "Matched", false = "Unmatched" — mirrors whether
  /// InboundSmsEvent.seekerId got set (see smsInbound.service.js
  /// #findSeekerByPhone), not whether a placement was also found.
  final bool? matched;
  final String search;

  @override
  List<Object?> get props => [matched, search];
}

/// GET /admin/sms-logs?matched=&search=&limit=100 — every inbound SMS
/// webhook delivery recorded platform-wide (InboundSmsEvent.model.js).
/// There is currently no outbound-SMS log to pair it with — see
/// admin.service.js#listSmsLogsForAdmin. No pagination controls yet,
/// mirroring admin_jobs_screen.dart's "first cut" note; the backend still
/// accepts page/limit for when this outgrows one screen.
final _smsLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _SmsLogsQuery>((ref, query) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/sms-logs',
    queryParameters: {
      if (query.matched != null) 'matched': query.matched,
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      'limit': 100,
    },
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['events'] as List<dynamic>);
});

String _formatDateTime(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  } catch (_) {
    return '';
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/sms-logs` sidebar destination —
/// platform-wide, read-only view into inbound SMS traffic for debugging
/// the SMS-based flows (job-alert reply "YES"/"1" acceptances, primarily).
/// Same dark container/card styling as the rest of this admin section.
class AdminSmsLogsScreen extends ConsumerStatefulWidget {
  const AdminSmsLogsScreen({super.key});

  @override
  ConsumerState<AdminSmsLogsScreen> createState() => _AdminSmsLogsScreenState();
}

class _AdminSmsLogsScreenState extends ConsumerState<AdminSmsLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _search = '';

  // null = "All". Order matches the tabs below.
  static const _matchedValues = [null, true, false];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _matchedValues.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() => _search = _searchController.text);
  }

  void _refresh() {
    for (final matched in _matchedValues) {
      ref.invalidate(_smsLogsProvider(_SmsLogsQuery(matched: matched, search: _search)));
    }
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
                Row(
                  children: [
                    const Text(
                      'SMS Logs',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Inbound SMS activity for debugging the SMS-based flows — job-alert '
                  'replies matched (or not) to a seeker and their latest placement. '
                  'Outbound sends aren\'t logged yet.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _runSearch(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by phone number…',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
                    Tab(text: 'All'),
                    Tab(text: 'Matched'),
                    Tab(text: 'Unmatched'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _matchedValues
                  .map((matched) => _SmsLogList(
                        query: _SmsLogsQuery(matched: matched, search: _search),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _SmsLogList extends ConsumerWidget {
  const _SmsLogList({required this.query});

  final _SmsLogsQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(_smsLogsProvider(query));

    return asyncEvents.when(
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
                Icon(Icons.sms_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('No SMS activity found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _SmsLogCard(data: items[i]),
        );
      },
    );
  }
}

class _SmsLogCard extends StatelessWidget {
  const _SmsLogCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final provider = data['provider'] as String? ?? 'unknown';
    final fromPhone = data['fromPhone'] as String? ?? 'Unknown number';
    final body = data['body'] as String?;
    final seekerName = data['seekerName'] as String?;
    final jobTitle = data['jobTitle'] as String?;
    final placementStatus = data['placementStatus'] as String?;
    final createdAt = data['createdAt'] as String?;
    final matched = seekerName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: matched ? const Color(0xFF1A3A1A) : const Color(0xFF3A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  matched ? Icons.sms_outlined : Icons.sms_failed_outlined,
                  color: matched ? const Color(0xFF81C784) : const Color(0xFFE57373),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fromPhone,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: matched ? const Color(0xFF1A3A1A) : const Color(0xFF3A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  matched ? 'Matched' : 'Unmatched',
                  style: TextStyle(
                    color: matched ? const Color(0xFF81C784) : const Color(0xFFE57373),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$body"',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              if (seekerName != null) _InfoItem(label: 'Seeker', value: seekerName),
              if (jobTitle != null) _InfoItem(label: 'Job', value: jobTitle),
              if (placementStatus != null) _InfoItem(label: 'Placement status', value: placementStatus),
              _InfoItem(label: 'Received', value: _formatDateTime(createdAt)),
            ],
          ),
        ],
      ),
    );
  }
}

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
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
