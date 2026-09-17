import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../agency/domain/agency_models.dart';
import '../../agency/presentation/agency_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/service_request.dart';
import 'service_requests_provider.dart';

/// "My Requests" / "Incoming" — the inbox counterpart to the "Request
/// Service" action on the Experts/Agencies map (`request_service_sheet.dart`).
/// "My Requests" (bookings this account has made) is available to every
/// role; "Incoming" (bookings routed *to* this account) only makes sense
/// for a seeker with a trade or an agency — matches
/// `serviceRequests.service.js#listIncomingRequests`'s 403 for any other
/// role, so the tab is simply hidden rather than shown-then-erroring.
class ServiceRequestsScreen extends ConsumerStatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  ConsumerState<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends ConsumerState<ServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  bool _hasIncomingTab(UserRole? role) => role == UserRole.seeker || role == UserRole.agency;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider.select((state) => state.user?.role));
    final showIncoming = _hasIncomingTab(role);
    final length = showIncoming ? 2 : 1;

    if (_tabController == null || _tabController!.length != length) {
      _tabController?.dispose();
      _tabController = TabController(length: length, vsync: this);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests'),
        bottom: length > 1
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'My Requests'),
                  Tab(text: 'Incoming'),
                ],
              )
            : null,
      ),
      body: TabBarView(
        controller: _tabController,
        physics: length > 1 ? null : const NeverScrollableScrollPhysics(),
        children: [
          const _MyRequestsTab(),
          if (showIncoming) _IncomingRequestsTab(role: role!),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}

class _MyRequestsTab extends ConsumerWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myServiceRequestsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myServiceRequestsProvider.future),
      child: requestsAsync.when(
        data: (requests) => requests.isEmpty
            ? const _EmptyState(
                icon: Icons.handyman_outlined,
                title: 'No requests yet',
                message: "Bookings you send from the Experts or Agencies map will show up here.",
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _RequestCard(
                  request: requests[index],
                  mode: _CardMode.mine,
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(myServiceRequestsProvider),
        ),
      ),
    );
  }
}

class _IncomingRequestsTab extends ConsumerWidget {
  const _IncomingRequestsTab({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingServiceRequestsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(incomingServiceRequestsProvider.future),
      child: requestsAsync.when(
        data: (requests) => requests.isEmpty
            ? _EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No incoming requests',
                message: role == UserRole.agency
                    ? "Requests homeowners/businesses send to your agency will show up here."
                    : "Requests sent to you as an Expert will show up here. Make sure you're listed under a trade category in your profile.",
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _RequestCard(
                  request: requests[index],
                  mode: role == UserRole.agency ? _CardMode.incomingAgency : _CardMode.incomingSeeker,
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(incomingServiceRequestsProvider),
        ),
      ),
    );
  }
}

enum _CardMode { mine, incomingSeeker, incomingAgency }

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, required this.mode});

  final ServiceRequest request;
  final _CardMode mode;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _acting = false;

  void _invalidateLists() {
    ref.invalidate(myServiceRequestsProvider);
    ref.invalidate(incomingServiceRequestsProvider);
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      _invalidateLists();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _pickRosterSeeker(BuildContext context) async {
    final repository = ref.read(agencyRepositoryProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FutureBuilder<AgencyCandidatesResult>(
          future: repository.fetchCandidates(const AgencyCandidatesParams(limit: 100)),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final candidates = snapshot.data?.candidates ?? const [];
            if (candidates.isEmpty) {
              return const SizedBox(
                height: 160,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No candidates on your roster yet. Register one as a walk-in first.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Assign to which roster member?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final seeker in candidates)
                    ListTile(
                      title: Text(seeker.fullName),
                      subtitle: seeker.city != null ? Text(seeker.city!) : null,
                      onTap: () => Navigator.of(sheetContext).pop(seeker.id),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    await _act(() => ref
        .read(serviceRequestsRepositoryProvider)
        .assignToSeeker(widget.request.id, result));
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.description),
            if (request.budget != null && request.budget!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Budget: ${request.budget}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (request.preferredDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Preferred date: ${_formatDate(request.preferredDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (_acting)
              const Center(child: CircularProgressIndicator())
            else
              _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final request = widget.request;
    final actions = <Widget>[];

    switch (widget.mode) {
      case _CardMode.incomingSeeker:
        // The currently-assigned Expert accepting/declining a request
        // (direct, or already handed to them by their agency) — only
        // while it's still awaiting a response.
        if (request.status == ServiceRequestStatus.assigned) {
          actions.addAll([
            Expanded(
              child: OutlinedButton(
                onPressed: () => _act(() => ref
                    .read(serviceRequestsRepositoryProvider)
                    .respondToRequest(request.id, accept: false)),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => _act(() => ref
                    .read(serviceRequestsRepositoryProvider)
                    .respondToRequest(request.id, accept: true)),
                child: const Text('Accept'),
              ),
            ),
          ]);
        } else if (request.status == ServiceRequestStatus.accepted) {
          actions.add(
            Expanded(
              child: FilledButton(
                onPressed: () => _act(() => ref
                    .read(serviceRequestsRepositoryProvider)
                    .updateStatus(request.id, completed: true)),
                child: const Text('Mark completed'),
              ),
            ),
          );
        }
        break;

      case _CardMode.incomingAgency:
        // An agency-routed request still waiting to be handed to a
        // roster member.
        if (request.targetType == ServiceRequestTargetType.agency &&
            request.assignedSeekerId == null &&
            request.status == ServiceRequestStatus.pending) {
          actions.add(
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pickRosterSeeker(context),
                icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                label: const Text('Assign to roster'),
              ),
            ),
          );
        }
        break;

      case _CardMode.mine:
        // The requester can cancel anything still active.
        if ([
          ServiceRequestStatus.pending,
          ServiceRequestStatus.assigned,
          ServiceRequestStatus.accepted,
        ].contains(request.status)) {
          actions.add(
            Expanded(
              child: OutlinedButton(
                onPressed: () => _act(() => ref
                    .read(serviceRequestsRepositoryProvider)
                    .updateStatus(request.id, completed: false)),
                child: const Text('Cancel request'),
              ),
            ),
          );
        }
        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(children: actions);
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ServiceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ServiceRequestStatus.pending => (AppColors.background, AppColors.inkMuted),
      ServiceRequestStatus.assigned => (AppColors.background, AppColors.inkMuted),
      ServiceRequestStatus.accepted => (AppColors.greenSurface, AppColors.greenDark),
      ServiceRequestStatus.completed => (AppColors.greenSurface, AppColors.greenDark),
      ServiceRequestStatus.declined => (AppColors.errorSurface, AppColors.error),
      ServiceRequestStatus.cancelled => (AppColors.errorSurface, AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error is ApiException
                  ? (error as ApiException).message
                  : 'Failed to load service requests.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
