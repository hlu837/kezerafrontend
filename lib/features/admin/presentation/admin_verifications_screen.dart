import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _verificationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, status) async {
  final client = ref.watch(apiClientProvider);
  final response =
      await client.dio.get<Map<String, dynamic>>('/admin/verifications',
          queryParameters: {'status': status});
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(
      data['verifications'] as List<dynamic>);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/verifications` sidebar destination.
///
/// Unlike the other role dashboards' screens, this one keeps its own dark
/// container/card styling (rather than the ambient Material theme) since
/// that's how it shipped originally — it just no longer brings its own
/// [Scaffold]/[AppBar], since [ResponsiveShell] (via the sidebar in
/// admin_shell.dart) now provides the surrounding chrome.
class AdminVerificationsScreen extends ConsumerStatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  ConsumerState<AdminVerificationsScreen> createState() =>
      _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState
    extends ConsumerState<AdminVerificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
                  'Verification Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Approve or reject employer/agency accounts.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF7B8CDE),
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFF7B8CDE),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Pending'),
                    Tab(text: 'Approved'),
                    Tab(text: 'Rejected'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _VerificationList(status: 'pending', onRefresh: _refresh),
                _VerificationList(status: 'approved', onRefresh: _refresh),
                _VerificationList(status: 'rejected', onRefresh: _refresh),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refresh() {
    ref.invalidate(_verificationsProvider);
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _VerificationList extends ConsumerWidget {
  const _VerificationList({
    required this.status,
    required this.onRefresh,
  });

  final String status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_verificationsProvider(status));
    return asyncData.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B8CDE))),
      error: (err, _) => Center(
        child: Text(err.toString(),
            style: const TextStyle(color: Colors.red)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'No $status verifications',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _VerificationCard(
            data: items[i],
            status: status,
            onActionComplete: onRefresh,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _VerificationCard extends ConsumerWidget {
  const _VerificationCard({
    required this.data,
    required this.status,
    required this.onActionComplete,
  });

  final Map<String, dynamic> data;
  final String status;
  final VoidCallback onActionComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data['profile'] as Map<String, dynamic>?;
    final businessName = (profile?['companyName'] ??
        profile?['agencyName'] ??
        'Unknown') as String;
    final role = data['role'] as String? ?? '';
    final tinNumber = profile?['tinNumber'] as String? ?? 'N/A';
    final tier = profile?['subscriptionTier'] as String? ?? 'N/A';
    final licenseUrl = profile?['businessLicenseUrl'] as String?;
    final rejectionReason = data['verificationRejectionReason'] as String?;
    final userId = data['_id'] as String? ?? data['id'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'employer'
                      ? const Color(0xFF1A3A5C)
                      : const Color(0xFF1A4A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: role == 'employer'
                        ? const Color(0xFF64B5F6)
                        : const Color(0xFF81C784),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info grid
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _InfoItem(label: 'TIN Number', value: tinNumber),
              _InfoItem(label: 'Subscription', value: tier),
              _InfoItem(
                  label: 'Contact',
                  value: data['phone'] as String? ??
                      data['email'] as String? ??
                      'N/A'),
            ],
          ),

          // Rejection reason
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Rejection reason: $rejectionReason',
                style: const TextStyle(
                    color: Color(0xFFE57373), fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // License button + action buttons
          Row(
            children: [
              if (licenseUrl != null)
                _SmallButton(
                  label: 'View License',
                  icon: Icons.open_in_new_rounded,
                  color: const Color(0xFF2A2A4A),
                  textColor: const Color(0xFF7B8CDE),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Open: $licenseUrl')),
                    );
                  },
                )
              else
                Text('No license uploaded',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 12)),
              const Spacer(),
              if (status == 'pending') ...[
                _SmallButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  color: const Color(0xFF3A1A1A),
                  textColor: const Color(0xFFE57373),
                  onTap: () => _showRejectDialog(context, ref, userId),
                ),
                const SizedBox(width: 10),
                _SmallButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  color: const Color(0xFF1A3A1A),
                  textColor: const Color(0xFF81C784),
                  onTap: () => _approve(context, ref, userId),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, String userId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio
          .post<dynamic>('/admin/verifications/$userId/approve');
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account approved!'),
              backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showRejectDialog(
      BuildContext context, WidgetRef ref, String userId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Account',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Provide a clear reason that will be shown to the user.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. TIN number could not be verified...',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF7B8CDE))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57373),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _reject(context, ref, userId, controller.text);
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, String userId,
      String reason) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post<dynamic>('/admin/verifications/$userId/reject',
          data: {'reason': reason});
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account rejected.'),
              backgroundColor: Color(0xFFE57373)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
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
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
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
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
