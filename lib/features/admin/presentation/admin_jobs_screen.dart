import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Query params for [_jobsProvider] — status tab plus whatever's currently
/// in the search box. Equatable so `.family` only refetches when one of the
/// two actually changes, same convention as admin_users_screen.dart's
/// `_UsersQuery`.
class _JobsQuery extends Equatable {
  const _JobsQuery({this.status, this.search = ''});

  final String? status;
  final String search;

  @override
  List<Object?> get props => [status, search];
}

/// GET /admin/jobs?status=&search=&limit=100 — every job on the platform
/// regardless of status, unlike the seeker-facing job board (open-only) or
/// an employer/agency's own "my jobs" dashboard. No pagination controls
/// yet, mirroring admin_conversations_screen.dart's "first cut" note; the
/// backend still accepts page/limit for when this outgrows one screen.
final _jobsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _JobsQuery>((ref, query) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/jobs',
    queryParameters: {
      if (query.status != null) 'status': query.status,
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      'limit': 100,
    },
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['jobs'] as List<dynamic>);
});

String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _formatDate(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/jobs` sidebar destination — browse/search
/// every job listing on the platform by status, and close or remove any of
/// them regardless of who posted it. Follows the same dark
/// container/card styling as admin_users_screen.dart and
/// admin_verifications_screen.dart rather than the ambient Material theme
/// (see those files' notes on why this admin section keeps its own look).
class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _search = '';

  // null = "All". Order matches the tabs below.
  static const _statuses = [null, 'open', 'closed', 'draft', 'removed'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
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
    for (final status in _statuses) {
      ref.invalidate(_jobsProvider(_JobsQuery(status: status, search: _search)));
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
                const Text(
                  'Job Listings',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Every job posted by an employer or agency. Close a listing to end it '
                  'early, or remove one that violates policy.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _runSearch(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by title or location…',
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
                    Tab(text: 'Open'),
                    Tab(text: 'Closed'),
                    Tab(text: 'Draft'),
                    Tab(text: 'Removed'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _statuses
                  .map((status) => _JobList(
                        query: _JobsQuery(status: status, search: _search),
                        onActionComplete: _refresh,
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

class _JobList extends ConsumerWidget {
  const _JobList({required this.query, required this.onActionComplete});

  final _JobsQuery query;
  final VoidCallback onActionComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJobs = ref.watch(_jobsProvider(query));
    return asyncJobs.when(
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
                Icon(Icons.work_outline, size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('No job listings found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _JobCard(data: items[i], onActionComplete: onActionComplete),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.data, required this.onActionComplete});

  final Map<String, dynamic> data;
  final VoidCallback onActionComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobId = data['id'] as String;
    final title = data['title'] as String? ?? 'Untitled';
    final status = data['status'] as String? ?? 'open';
    final location = data['location'] as String? ?? '';
    final jobType = data['jobType'] as String?;
    final applicationCount = data['applicationCount'] as int? ?? 0;
    final createdAt = data['createdAt'] as String?;
    final removedReason = data['removedReason'] as String?;
    final poster = data['poster'] as Map<String, dynamic>?;
    final posterName = poster?['name'] as String? ?? 'Unknown poster';
    final posterType = poster?['type'] as String? ?? (data['creatorType'] as String? ?? '');

    final canModerate = status == 'open' || status == 'closed' || status == 'draft';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: status),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _InfoItem(label: 'Posted by', value: '$posterName (${_titleCase(posterType)})'),
              _InfoItem(label: 'Location', value: location.isEmpty ? 'N/A' : location),
              if (jobType != null) _InfoItem(label: 'Type', value: jobType),
              _InfoItem(label: 'Applicants', value: '$applicationCount'),
              _InfoItem(label: 'Posted', value: _formatDate(createdAt)),
            ],
          ),
          if (status == 'removed' && removedReason != null && removedReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF3A1A1A), borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Removal reason: $removedReason',
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
            ),
          ],
          if (canModerate) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                if (status != 'closed')
                  _SmallButton(
                    label: 'Close',
                    icon: Icons.stop_circle_outlined,
                    color: const Color(0xFF2A2A1A),
                    textColor: const Color(0xFFE0C36A),
                    onTap: () => _close(context, ref, jobId),
                  ),
                const SizedBox(width: 10),
                _SmallButton(
                  label: 'Remove',
                  icon: Icons.delete_outline,
                  color: const Color(0xFF3A1A1A),
                  textColor: const Color(0xFFE57373),
                  onTap: () => _showRemoveDialog(context, ref, jobId),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _close(BuildContext context, WidgetRef ref, String jobId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post<dynamic>('/admin/jobs/$jobId/close');
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing closed.'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref, String jobId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Listing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This takes the listing down for a policy violation. Unlike closing it, '
              'the poster cannot reopen a removed listing themselves. Provide a reason '
              '— it will be visible to the poster.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Misleading job description...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7B8CDE))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57373),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final reason = controller.text.trim();
              Navigator.of(ctx).pop();
              await _remove(context, ref, jobId, reason);
            },
            child: const Text('Confirm Removal'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String jobId, String reason) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post<dynamic>('/admin/jobs/$jobId/remove', data: {'reason': reason});
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing removed.'), backgroundColor: Color(0xFFE57373)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'open':
        bg = const Color(0xFF1A3A1A);
        fg = const Color(0xFF81C784);
        break;
      case 'closed':
        bg = const Color(0xFF2A2A1A);
        fg = const Color(0xFFE0C36A);
        break;
      case 'removed':
        bg = const Color(0xFF3A1A1A);
        fg = const Color(0xFFE57373);
        break;
      default: // draft
        bg = const Color(0xFF22222E);
        fg = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        _titleCase(status),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
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
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
