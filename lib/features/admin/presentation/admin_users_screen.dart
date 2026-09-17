import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Query params for [_usersProvider] — a plain role filter plus whatever's
/// currently in the search box. Equatable so Riverpod's `.family` only
/// refetches when one of the two actually changes, not on every rebuild.
class _UsersQuery extends Equatable {
  const _UsersQuery({this.role, this.search = ''});

  final String? role;
  final String search;

  @override
  List<Object?> get props => [role, search];
}

/// GET /admin/users?role=...&search=... — every account on the platform,
/// unlike `_accountsProvider` in admin_subscriptions_screen.dart which is
/// scoped to employer/agency.
final _usersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _UsersQuery>(
        (ref, query) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/users',
    queryParameters: {
      if (query.role != null) 'role': query.role,
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
    },
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['users'] as List<dynamic>);
});

String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/users` sidebar destination: search + browse
/// every account on the platform by role, and suspend/reactivate any
/// seeker/employer/agency account (admin accounts are excluded — see
/// admin.service.js#setAccountStatus).
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _search = '';

  static const _roles = [null, 'seeker', 'employer', 'agency', 'admin'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _roles.length, vsync: this);
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
    for (final role in _roles) {
      ref.invalidate(_usersProvider(_UsersQuery(role: role, search: _search)));
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
                  'Users',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search, view, and suspend seeker, employer, and agency accounts.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _runSearch(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or phone…',
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
                    Tab(text: 'Seekers'),
                    Tab(text: 'Employers'),
                    Tab(text: 'Agencies'),
                    Tab(text: 'Admins'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _roles
                  .map((role) => _UserList(
                        query: _UsersQuery(role: role, search: _search),
                        onRefresh: _refresh,
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

class _UserList extends ConsumerWidget {
  const _UserList({required this.query, required this.onRefresh});

  final _UsersQuery query;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(_usersProvider(query));
    return asyncUsers.when(
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
                Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('No users found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _UserCard(data: items[i], onActionComplete: onRefresh),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.data, required this.onActionComplete});

  final Map<String, dynamic> data;
  final VoidCallback onActionComplete;

  static const _roleColors = {
    'seeker': (bg: Color(0xFF3A1A4A), fg: Color(0xFFBA68C8)),
    'employer': (bg: Color(0xFF1A3A5C), fg: Color(0xFF64B5F6)),
    'agency': (bg: Color(0xFF1A4A2E), fg: Color(0xFF81C784)),
    'admin': (bg: Color(0xFF4A3A1A), fg: Color(0xFFE0AC4E)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data['profile'] as Map<String, dynamic>?;
    final role = data['role'] as String? ?? '';
    final name = (profile?['fullName'] ?? profile?['companyName'] ?? profile?['agencyName']) as String? ??
        (data['email'] as String? ?? 'Unknown');
    final email = data['email'] as String? ?? 'N/A';
    final phone = data['phone'] as String?;
    final verificationStatus = data['verificationStatus'] as String?;
    final accountStatus = data['accountStatus'] as String? ?? 'active';
    final accountStatusReason = data['accountStatusReason'] as String?;
    final userId = data['_id'] as String? ?? data['id'] as String? ?? '';
    final isSuspended = accountStatus == 'suspended';
    // Admin accounts can't be suspended from this console (see
    // admin.service.js#setAccountStatus) — no action row for them.
    final canSuspend = role != 'admin';
    final colors = _roleColors[role] ?? (bg: const Color(0xFF2A2A4A), fg: const Color(0xFF7B8CDE));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSuspended ? const Color(0xFFE57373).withOpacity(0.4) : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(text: role.toUpperCase(), bg: colors.bg, fg: colors.fg),
              const SizedBox(width: 8),
              if (canSuspend)
                _Badge(
                  text: isSuspended ? 'SUSPENDED' : 'ACTIVE',
                  bg: isSuspended ? const Color(0xFF3A1A1A) : const Color(0xFF1A3A1A),
                  fg: isSuspended ? const Color(0xFFE57373) : const Color(0xFF81C784),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
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
              _InfoItem(label: 'Email', value: email),
              _InfoItem(label: 'Phone', value: phone ?? 'N/A'),
              if (verificationStatus != null) _InfoItem(label: 'Verification', value: _titleCase(verificationStatus)),
              if (profile?['city'] != null) _InfoItem(label: 'City', value: profile!['city'] as String),
            ],
          ),
          if (isSuspended && accountStatusReason != null && accountStatusReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF3A1A1A), borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Suspension reason: $accountStatusReason',
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
            ),
          ],
          if (canSuspend) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                _SmallButton(
                  label: isSuspended ? 'Reactivate' : 'Suspend',
                  icon: isSuspended ? Icons.play_arrow_rounded : Icons.block_rounded,
                  color: isSuspended ? const Color(0xFF1A3A1A) : const Color(0xFF3A1A1A),
                  textColor: isSuspended ? const Color(0xFF81C784) : const Color(0xFFE57373),
                  onTap: () =>
                      isSuspended ? _reactivate(context, ref, userId) : _showSuspendDialog(context, ref, userId),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref, String userId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.patch<dynamic>('/admin/accounts/$userId/status', data: {'status': 'active'});
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account reactivated.'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showSuspendDialog(BuildContext context, WidgetRef ref, String userId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Suspend Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This blocks the account from using the platform until reactivated. '
              'Provide a reason shown to the account.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Repeated policy violations...',
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
              if (reason.isEmpty) return;
              Navigator.of(ctx).pop();
              await _suspend(context, ref, userId, reason);
            },
            child: const Text('Confirm Suspension'),
          ),
        ],
      ),
    );
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref, String userId, String reason) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.patch<dynamic>(
        '/admin/accounts/$userId/status',
        data: {'status': 'suspended', 'reason': reason},
      );
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account suspended.'), backgroundColor: Color(0xFFE57373)),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
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
