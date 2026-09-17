import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// GET /admin/accounts?role=... — every employer/agency account (any
/// verificationStatus), unlike `_verificationsProvider` in
/// admin_verifications_screen.dart which only sees the pending queue.
final _accountsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
        (ref, role) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/accounts',
    queryParameters: {if (role != null) 'role': role},
  );
  final data = response.data!['data'] as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['accounts'] as List<dynamic>);
});

/// GET /admin/subscription-plans — every admin-authored plan (however
/// many admin has decided to have), each with its own name, price,
/// benefits list, and the limits behind it. Fully admin-owned: unlike
/// the old fixed basic/premium/enterprise set, plans here can be
/// created, edited, deleted, and reordered.
final _plansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response =
      await client.dio.get<Map<String, dynamic>>('/admin/subscription-plans');
  final data = response.data!['data'] as Map<String, dynamic>;
  final plans = List<Map<String, dynamic>>.from(data['plans'] as List<dynamic>);
  // `key` is required server-side for every plan created through the
  // admin API (see subscriptionPlan.service.js#validatePlanFields), but
  // this list isn't guaranteed to only ever contain plans created that
  // way — a handful of widgets below (`_PlanCard`, `_PlanDropdown`,
  // `_reorder`) do an unguarded `p['key'] as String`, and a plan
  // lacking a usable key can't be edited/deleted/assigned through this
  // screen anyway, so drop it here rather than let it crash the whole
  // page. Filtering once at the source is simpler than null-guarding
  // every downstream cast site individually.
  plans.removeWhere((p) {
    final key = p['key'];
    return key is! String || key.isEmpty;
  });
  plans.sort((a, b) =>
      ((a['sortOrder'] as num?) ?? 0).compareTo((b['sortOrder'] as num?) ?? 0));
  return plans;
});

String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/subscriptions` sidebar destination:
/// admin's full control over what plans exist (name/price/benefits/
/// limits — `_PlansPanel`) and each individual account's assigned plan
/// plus whether it's currently active (`_AccountList`/`_AccountCard`,
/// backed by `PATCH /admin/accounts/:userId/subscription` and
/// `PATCH /admin/accounts/:userId/status`).
class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _roles = [null, 'employer', 'agency'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    for (final role in _roles) {
      ref.invalidate(_accountsProvider(role));
    }
    ref.invalidate(_plansProvider);
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
                    const Expanded(
                      child: Text(
                        'Subscriptions & Services',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    _SmallButton(
                      label: 'Add plan',
                      icon: Icons.add_rounded,
                      color: const Color(0xFF7B8CDE),
                      textColor: Colors.white,
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => _PlanEditDialog(onSaved: () => ref.invalidate(_plansProvider)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Decide how many plans exist, what each one costs, and what it entitles '
                  'employers/agencies to. Suspend or reactivate individual accounts below.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 20),
                const _PlansPanel(),
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
                    Tab(text: 'Employers'),
                    Tab(text: 'Agencies'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _roles
                  .map((role) => _AccountList(role: role, onRefresh: _refresh))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plans panel — admin fully owns how many plans exist & what they mean
// ---------------------------------------------------------------------------

class _PlansPanel extends ConsumerWidget {
  const _PlansPanel();

  Future<void> _reorder(WidgetRef ref, List<Map<String, dynamic>> plans, int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= plans.length) return;
    final keys = plans.map((p) => p['key'] as String).toList();
    final moved = keys.removeAt(index);
    keys.insert(newIndex, moved);
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.patch<dynamic>(
        '/admin/subscription-plans/reorder',
        data: {'orderedKeys': keys},
      );
      ref.invalidate(_plansProvider);
    } catch (e) {
      // Silent best-effort — the panel will just show the old order if
      // this fails; not worth a dialog for a reorder click.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlans = ref.watch(_plansProvider);

    return asyncPlans.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B8CDE)),
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Could not load plans: $err',
            style: const TextStyle(color: Color(0xFFE57373), fontSize: 13)),
      ),
      data: (plans) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < plans.length; i++)
            _PlanCard(
              plan: plans[i],
              canMoveLeft: i > 0,
              canMoveRight: i < plans.length - 1,
              canDelete: plans.length > 1 && plans[i]['isDefault'] != true,
              onMoveLeft: () => _reorder(ref, plans, i, -1),
              onMoveRight: () => _reorder(ref, plans, i, 1),
              onChanged: () => ref.invalidate(_plansProvider),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.canDelete,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onChanged,
  });

  final Map<String, dynamic> plan;
  final bool canMoveLeft;
  final bool canMoveRight;
  final bool canDelete;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filtered upstream in `_plansProvider`, but guarded again here too
    // — this card shouldn't be the thing that takes the whole page down
    // if a malformed plan ever slips through some other path into it.
    final key = plan['key'] as String? ?? '';
    final name = plan['name'] as String? ?? _titleCase(key);
    final price = (plan['price'] as num?) ?? 0;
    final currency = plan['currency'] as String? ?? 'ETB';
    final billingCycle = plan['billingCycle'] as String? ?? 'monthly';
    final isDefault = plan['isDefault'] == true;
    final isActive = plan['isActive'] != false;
    final features = List<String>.from(plan['features'] as List<dynamic>? ?? const []);
    final maxOpenJobs = plan['maxOpenJobs'];
    final canAdvertise = plan['canAdvertise'] == true;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? const Color(0xFF7B8CDE) : Colors.white.withOpacity(0.08),
          width: isDefault ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Move earlier',
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                color: Colors.white38,
                visualDensity: VisualDensity.compact,
                onPressed: canMoveLeft ? onMoveLeft : null,
              ),
              IconButton(
                tooltip: 'Move later',
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                color: Colors.white38,
                visualDensity: VisualDensity.compact,
                onPressed: canMoveRight ? onMoveRight : null,
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isDefault) const _Badge(text: 'DEFAULT', bg: Color(0xFF2A2A5C), fg: Color(0xFF7B8CDE)),
              if (!isActive) const _Badge(text: 'INACTIVE', bg: Color(0xFF3A1A1A), fg: Color(0xFFE57373)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            price == 0 ? 'Free' : '$currency ${price.toStringAsFixed(0)} / $billingCycle',
            style: const TextStyle(color: Color(0xFF81C784), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            maxOpenJobs == null ? '• Unlimited open jobs' : '• Up to $maxOpenJobs open jobs',
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5),
          ),
          Text(
            canAdvertise ? '• Can run promoted ads' : '• Cannot run promoted ads',
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5),
          ),
          for (final f in features.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $f',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallButton(
                label: 'Edit',
                icon: Icons.edit_rounded,
                color: const Color(0xFF1A1A2E),
                textColor: const Color(0xFF7B8CDE),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _PlanEditDialog(existingPlan: plan, onSaved: onChanged),
                ),
              ),
              if (!isDefault)
                _SmallButton(
                  label: 'Make default',
                  icon: Icons.star_outline_rounded,
                  color: const Color(0xFF1A1A2E),
                  textColor: const Color(0xFF81C784),
                  onTap: () async {
                    try {
                      final client = ref.read(apiClientProvider);
                      await client.dio.post<dynamic>('/admin/subscription-plans/$key/set-default');
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              if (canDelete)
                _SmallButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFF3A1A1A),
                  textColor: const Color(0xFFE57373),
                  onTap: () => _confirmDelete(context, ref, key, name),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String key, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "$name"? Any account currently on this plan will be moved to the default plan.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
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
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(apiClientProvider);
                await client.dio.delete<dynamic>('/admin/subscription-plans/$key');
                onChanged();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit plan dialog
// ---------------------------------------------------------------------------

class _PlanEditDialog extends ConsumerStatefulWidget {
  const _PlanEditDialog({this.existingPlan, required this.onSaved});

  /// Null = creating a brand-new plan. Non-null = editing this one.
  final Map<String, dynamic>? existingPlan;
  final VoidCallback onSaved;

  @override
  ConsumerState<_PlanEditDialog> createState() => _PlanEditDialogState();
}

class _PlanEditDialogState extends ConsumerState<_PlanEditDialog> {
  late final bool _isEditing = widget.existingPlan != null;
  late final _keyController =
      TextEditingController(text: widget.existingPlan?['key'] as String? ?? '');
  late final _nameController =
      TextEditingController(text: widget.existingPlan?['name'] as String? ?? '');
  late final _descController =
      TextEditingController(text: widget.existingPlan?['description'] as String? ?? '');
  late final _priceController = TextEditingController(
      text: ((widget.existingPlan?['price'] as num?) ?? 0).toString());
  late final _maxOpenJobsController = TextEditingController(
      text: widget.existingPlan?['maxOpenJobs']?.toString() ?? '');
  late bool _unlimitedJobs = widget.existingPlan == null
      ? false
      : widget.existingPlan!['maxOpenJobs'] == null;
  late bool _canAdvertise = widget.existingPlan?['canAdvertise'] == true;
  late String _billingCycle = widget.existingPlan?['billingCycle'] as String? ?? 'monthly';
  late String _audience = widget.existingPlan?['audience'] as String? ?? 'both';
  late bool _isActive = widget.existingPlan?['isActive'] != false;
  late final List<TextEditingController> _featureControllers = [
    for (final f in List<String>.from(widget.existingPlan?['features'] as List<dynamic>? ?? const []))
      TextEditingController(text: f),
  ];
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _maxOpenJobsController.dispose();
    for (final c in _featureControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final key = _keyController.text.trim().toLowerCase();
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Plan name is required.');
      return;
    }
    if (!_isEditing && (key.isEmpty || !RegExp(r'^[a-z0-9-]+$').hasMatch(key))) {
      setState(() => _error = 'Key is required — lowercase letters, numbers, and hyphens only.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'Enter a valid price of 0 or more.');
      return;
    }
    int? maxOpenJobs;
    if (!_unlimitedJobs) {
      maxOpenJobs = int.tryParse(_maxOpenJobsController.text.trim());
      if (maxOpenJobs == null || maxOpenJobs < 0) {
        setState(() => _error = 'Enter a whole number of 0 or more, or mark unlimited.');
        return;
      }
    }
    final features = _featureControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final body = {
      'name': name,
      'description': _descController.text.trim(),
      'audience': _audience,
      'price': price,
      'billingCycle': _billingCycle,
      'features': features,
      'maxOpenJobs': _unlimitedJobs ? null : maxOpenJobs,
      'canAdvertise': _canAdvertise,
      'isActive': _isActive,
      if (!_isEditing) 'key': key,
    };

    try {
      final client = ref.read(apiClientProvider);
      if (_isEditing) {
        await client.dio.patch<dynamic>('/admin/subscription-plans/${widget.existingPlan!['key']}', data: body);
      } else {
        await client.dio.post<dynamic>('/admin/subscription-plans', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: const Color(0xFF0F0F1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white, fontSize: 14);
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_isEditing ? 'Edit "${widget.existingPlan!['name']}"' : 'Add a new plan',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isEditing) ...[
                TextField(controller: _keyController, style: textStyle, decoration: _decoration('Key (e.g. "gold")')),
                const SizedBox(height: 10),
              ],
              TextField(controller: _nameController, style: textStyle, decoration: _decoration('Plan name')),
              const SizedBox(height: 10),
              TextField(controller: _descController, style: textStyle, maxLines: 2, decoration: _decoration('Description (optional)')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: textStyle,
                      decoration: _decoration('Price (ETB)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _billingCycle,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: textStyle,
                      decoration: _decoration('Billing cycle'),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (v) => setState(() => _billingCycle = v ?? 'monthly'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _audience,
                dropdownColor: const Color(0xFF1A1A2E),
                style: textStyle,
                decoration: _decoration('Available to'),
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('Employers & agencies')),
                  DropdownMenuItem(value: 'employer', child: Text('Employers only')),
                  DropdownMenuItem(value: 'agency', child: Text('Agencies only')),
                ],
                onChanged: (v) => setState(() => _audience = v ?? 'both'),
              ),
              const SizedBox(height: 16),
              Text('Benefits shown on this plan', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 6),
              for (var i = 0; i < _featureControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _featureControllers[i],
                          style: textStyle,
                          decoration: _decoration('e.g. "Priority support"'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: Colors.white38,
                        onPressed: () => setState(() => _featureControllers.removeAt(i).dispose()),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _featureControllers.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF7B8CDE)),
                label: const Text('Add benefit', style: TextStyle(color: Color(0xFF7B8CDE))),
              ),
              const Divider(color: Colors.white12, height: 24),
              Text('Limits enforced by this plan', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxOpenJobsController,
                      enabled: !_unlimitedJobs,
                      keyboardType: TextInputType.number,
                      style: textStyle,
                      decoration: _decoration('Max open jobs'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _unlimitedJobs,
                        activeColor: const Color(0xFF7B8CDE),
                        onChanged: (c) => setState(() => _unlimitedJobs = c ?? false),
                      ),
                      Text('Unlimited', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _canAdvertise,
                    activeColor: const Color(0xFF7B8CDE),
                    onChanged: (c) => setState(() => _canAdvertise = c ?? false),
                  ),
                  Text('Can run promoted ads', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    activeColor: const Color(0xFF7B8CDE),
                    onChanged: (c) => setState(() => _isActive = c ?? true),
                  ),
                  Expanded(
                    child: Text('Active (selectable for new subscriptions)',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFE57373), fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF7B8CDE))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B8CDE),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? 'Save' : 'Create plan'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account list
// ---------------------------------------------------------------------------

class _AccountList extends ConsumerWidget {
  const _AccountList({required this.role, required this.onRefresh});

  final String? role;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_accountsProvider(role));
    return asyncData.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFF7B8CDE))),
      error: (err, _) => Center(
        child: Text(err.toString(), style: const TextStyle(color: Colors.red)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'No accounts found',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) =>
              _AccountCard(data: items[i], onActionComplete: onRefresh),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.data, required this.onActionComplete});

  final Map<String, dynamic> data;
  final VoidCallback onActionComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data['profile'] as Map<String, dynamic>?;
    final businessName =
        (profile?['companyName'] ?? profile?['agencyName'] ?? 'Unknown') as String;
    final role = data['role'] as String? ?? '';
    final tier = (profile?['subscriptionTier'] as String?) ?? 'basic';
    final verificationStatus = data['verificationStatus'] as String? ?? 'N/A';
    final accountStatus = data['accountStatus'] as String? ?? 'active';
    final accountStatusReason = data['accountStatusReason'] as String?;
    final userId = data['_id'] as String? ?? data['id'] as String? ?? '';
    final isSuspended = accountStatus == 'suspended';

    final limits = data['limits'] as Map<String, dynamic>?;
    final maxOpenJobs = limits?['maxOpenJobs'];
    final jobsLimitText = maxOpenJobs == null ? 'Unlimited' : '$maxOpenJobs open at a time';

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
              _Badge(
                text: role.toUpperCase(),
                bg: role == 'employer' ? const Color(0xFF1A3A5C) : const Color(0xFF1A4A2E),
                fg: role == 'employer' ? const Color(0xFF64B5F6) : const Color(0xFF81C784),
              ),
              const SizedBox(width: 8),
              _Badge(
                text: isSuspended ? 'SUSPENDED' : 'ACTIVE',
                bg: isSuspended ? const Color(0xFF3A1A1A) : const Color(0xFF1A3A1A),
                fg: isSuspended ? const Color(0xFFE57373) : const Color(0xFF81C784),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  businessName,
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
              _InfoItem(label: 'Verification', value: verificationStatus),
              _InfoItem(label: 'Job posting limit', value: jobsLimitText),
              _InfoItem(
                label: 'Contact',
                value: data['phone'] as String? ?? data['email'] as String? ?? 'N/A',
              ),
            ],
          ),
          if (isSuspended && accountStatusReason != null && accountStatusReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Suspension reason: $accountStatusReason',
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Wrap (not Row) so the plan dropdown + action button drop to
          // a second line on narrow screens instead of overflowing —
          // plan names are now admin-authored and can be long/plural.
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PlanDropdown(
                currentTier: tier,
                onChanged: (newTier) => _updateSubscription(context, ref, userId, newTier),
              ),
              _SmallButton(
                label: isSuspended ? 'Reactivate' : 'Suspend',
                icon: isSuspended ? Icons.play_arrow_rounded : Icons.block_rounded,
                color: isSuspended ? const Color(0xFF1A3A1A) : const Color(0xFF3A1A1A),
                textColor: isSuspended ? const Color(0xFF81C784) : const Color(0xFFE57373),
                onTap: () => isSuspended
                    ? _reactivate(context, ref, userId)
                    : _showSuspendDialog(context, ref, userId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateSubscription(
      BuildContext context, WidgetRef ref, String userId, String tier) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.patch<dynamic>(
        '/admin/accounts/$userId/subscription',
        data: {'tier': tier},
      );
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan updated to ${_titleCase(tier)}.'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref, String userId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.patch<dynamic>(
        '/admin/accounts/$userId/status',
        data: {'status': 'active'},
      );
      onActionComplete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account reactivated.'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: const Text('Suspend Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This blocks job posting, candidate search, and messaging until '
              'reactivated. Provide a reason shown to the account.',
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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

  Future<void> _suspend(
      BuildContext context, WidgetRef ref, String userId, String reason) async {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Dropdown of every live plan (fetched from `_plansProvider`, not a
/// hardcoded list) an account can be moved to. Constrained to a max
/// width with ellipsis text so a long admin-authored plan name can
/// never push this — or the button next to it — off-screen.
class _PlanDropdown extends ConsumerWidget {
  const _PlanDropdown({required this.currentTier, required this.onChanged});

  final String currentTier;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlans = ref.watch(_plansProvider);

    return asyncPlans.when(
      loading: () => _shell(child: const SizedBox(
        height: 16, width: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B8CDE)),
      )),
      error: (_, __) => _shell(
        child: Text(_titleCase(currentTier), style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
      data: (plans) {
        final keys = plans.map((p) => p['key'] as String).toList();
        final value = keys.contains(currentTier) ? currentTier : (keys.isNotEmpty ? keys.first : currentTier);
        return _shell(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: keys.contains(value) ? value : null,
              hint: Text(_titleCase(currentTier), style: const TextStyle(color: Colors.white, fontSize: 13)),
              dropdownColor: const Color(0xFF1A1A2E),
              iconEnabledColor: const Color(0xFF7B8CDE),
              isDense: true,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              items: plans
                  .map((p) => DropdownMenuItem(
                        value: p['key'] as String,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text('${p['name'] ?? _titleCase(p['key'] as String)} plan',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null && v != currentTier) onChanged(v);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _shell({required Widget child}) => Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: child,
      );
}

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
      child: Text(
        text,
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
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
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
