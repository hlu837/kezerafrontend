import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/service_requests_repository.dart';
import '../domain/service_request.dart';

final serviceRequestsRepositoryProvider = Provider<ServiceRequestsRepository>((ref) {
  return ServiceRequestsRepository(ref.watch(apiClientProvider));
});

/// "My Requests" — every booking the current account has made,
/// regardless of role, newest first. Plain `FutureProvider`; screens use
/// `ref.refresh(myServiceRequestsProvider.future)` for pull-to-refresh,
/// same convention as `myApplicationsProvider`.
final myServiceRequestsProvider = FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  final page = await ref.watch(serviceRequestsRepositoryProvider).fetchMyRequests();
  return page.requests;
});

/// "Incoming" — requests routed to the current account as an Expert
/// (seeker role) or Agency. Seeker/agency roles only; other roles never
/// watch this (see `ServiceRequestsScreen`, which hides the tab).
final incomingServiceRequestsProvider = FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  final page = await ref.watch(serviceRequestsRepositoryProvider).fetchIncomingRequests();
  return page.requests;
});
